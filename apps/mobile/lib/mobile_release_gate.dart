import 'package:factoryos_core/factoryos_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Read-only policy check before authentication. A policy never grants roles or
/// writes to manufacturing/warehouse ledgers.
class MobileReleaseState {
  const MobileReleaseState({
    required this.action,
    this.notes = '',
    this.downloadUrl,
    this.checkFailed = false,
  });

  final FactoryReleaseAction action;
  final String notes;
  final Uri? downloadUrl;
  final bool checkFailed;
}

class MobileReleaseGate extends StatefulWidget {
  const MobileReleaseGate({
    required this.child,
    this.checkPolicy,
    this.openUpdateLink,
    super.key,
  });

  final Widget child;

  /// Dependency injection is used only for deterministic widget tests.
  final Future<MobileReleaseState> Function()? checkPolicy;
  final Future<void> Function(Uri)? openUpdateLink;

  @override
  State<MobileReleaseGate> createState() => _MobileReleaseGateState();
}

class _MobileReleaseGateState extends State<MobileReleaseGate>
    with WidgetsBindingObserver {
  MobileReleaseState? _state;
  bool _checking = true;
  bool _optionalDismissed = false;
  bool _allowUnavailable = false;
  int _epoch = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    _epoch++;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Do not reset active forms during a background/resume policy refresh.
    if (state == AppLifecycleState.resumed && !_checking) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    final epoch = ++_epoch;
    setState(() => _checking = true);
    MobileReleaseState next;
    try {
      next = await (widget.checkPolicy ?? _loadPolicy)();
    } catch (_) {
      // A network failure is not the same as "no release policy".
      next = const MobileReleaseState(
        action: FactoryReleaseAction.current,
        checkFailed: true,
      );
    }
    if (!mounted || epoch != _epoch) return;
    setState(() {
      _state = next;
      _checking = false;
      if (next.action == FactoryReleaseAction.forceUpdate ||
          next.action == FactoryReleaseAction.maintenance) {
        _optionalDismissed = false;
        _allowUnavailable = false;
      }
      if (!next.checkFailed) _allowUnavailable = false;
    });
  }

  Future<MobileReleaseState> _loadPolicy() async {
    // Package identity comes from the *installed* binary, not a user-supplied
    // organization ID or a mutable factory field.
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return const MobileReleaseState(action: FactoryReleaseAction.current);
    }
    final package = await PackageInfo.fromPlatform();
    final installed = FactoryAppVersion.tryParse(
      '${package.version}+${package.buildNumber}',
    );
    if (installed == null) throw const FormatException('Invalid app version.');
    final platform =
        defaultTargetPlatform == TargetPlatform.android ? 'android' : 'ios';
    final response = await Supabase.instance.client
        .rpc(
          'get_mobile_release_policy',
          params: {
            'p_application_id': package.packageName,
            'p_platform': platform,
          },
        )
        .timeout(const Duration(seconds: 8));
    if (response == null) {
      return const MobileReleaseState(action: FactoryReleaseAction.current);
    }
    final policy = FactoryReleasePolicy.fromMap(
      Map<String, dynamic>.from(response as Map),
    );
    return MobileReleaseState(
      action: policy.evaluate(installed),
      downloadUrl: policy.downloadUrl,
      notes: policy.notes,
    );
  }

  Future<void> _openUpdate(Uri uri) async {
    try {
      if (widget.openUpdateLink != null) {
        await widget.openUpdateLink!(uri);
      } else {
        if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          throw StateError('Could not open update link');
        }
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot open the update link. Contact support.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _state;
    if (result == null) {
      return const Scaffold(
        body: SafeArea(
          child: FactoryStatePanel(
            state: FactoryViewState.loading,
            message: 'Checking application compatibility…',
          ),
        ),
      );
    }

    // Existing forms and role-gated workspaces remain mounted while a refresh
    // is in flight; the new policy is applied as soon as it arrives.
    if (result.checkFailed) {
      if (_allowUnavailable) return widget.child;
      return _screen(
        icon: Icons.wifi_off_outlined,
        title: 'Update check unavailable',
        detail: 'We could not verify the latest app requirements. '
            'Retry when connected. Continuing may use an outdated version.',
        retry: true,
        secondaryLabel: 'Continue for now',
        onSecondary: () => setState(() => _allowUnavailable = true),
      );
    }
    switch (result.action) {
      case FactoryReleaseAction.current:
        return widget.child;
      case FactoryReleaseAction.optionalUpdate:
        if (_optionalDismissed) return widget.child;
        return _screen(
          icon: Icons.system_update_alt,
          title: 'Update available',
          detail: 'A newer version of FactoryOS is available.',
          notes: result.notes,
          updateUrl: result.downloadUrl,
          retry: true,
          secondaryLabel: 'Not now',
          onSecondary: () => setState(() => _optionalDismissed = true),
        );
      case FactoryReleaseAction.forceUpdate:
        return _screen(
          icon: Icons.system_update_alt,
          title: 'Update required',
          detail: 'This installed version is no longer supported. '
              'Update before accessing factory operations.',
          notes: result.notes,
          updateUrl: result.downloadUrl,
          retry: true,
        );
      case FactoryReleaseAction.maintenance:
        return _screen(
          icon: Icons.construction_outlined,
          title: 'Scheduled maintenance',
          detail: 'FactoryOS is temporarily unavailable. '
              'Retry when maintenance is complete.',
          notes: result.notes,
          retry: true,
        );
    }
  }

  Widget _screen({
    required IconData icon,
    required String title,
    required String detail,
    String notes = '',
    Uri? updateUrl,
    bool retry = false,
    String? secondaryLabel,
    VoidCallback? onSecondary,
  }) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false, title: const Text('FactoryOS')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(FactorySpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 56, color: theme.colorScheme.primary),
                  const SizedBox(height: FactorySpacing.lg),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: FactorySpacing.md),
                  Text(detail, textAlign: TextAlign.center),
                  if (notes.isNotEmpty) ...[
                    const SizedBox(height: FactorySpacing.md),
                    Text(notes, textAlign: TextAlign.center),
                  ],
                  const SizedBox(height: FactorySpacing.lg),
                  if (updateUrl != null)
                    FilledButton.icon(
                      onPressed: () => _openUpdate(updateUrl),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Open update page'),
                    ),
                  if (retry) ...[
                    const SizedBox(height: FactorySpacing.sm),
                    OutlinedButton.icon(
                      onPressed: _checking ? null : _refresh,
                      icon: const Icon(Icons.refresh),
                      label: Text(_checking ? 'Checking…' : 'Check again'),
                    ),
                  ],
                  if (onSecondary != null && secondaryLabel != null)
                    TextButton(
                      onPressed: onSecondary,
                      child: Text(secondaryLabel),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
