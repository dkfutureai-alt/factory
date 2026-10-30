import 'package:flutter/material.dart';

import 'design_system.dart';

/// Data-only operational KPI. Displayed values must be sourced from authorized
/// reporting responses, never hard-coded demo statistics in a connected app.
class FactoryMetricCard extends StatelessWidget {
  const FactoryMetricCard({
    required this.label,
    required this.value,
    required this.icon,
    this.detail,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      container: true,
      label: [
        label,
        value,
        if (detail != null && detail!.isNotEmpty) detail!,
      ].join(', '),
      child: ExcludeSemantics(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(FactorySpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(icon, color: scheme.primary, size: 22),
                    const SizedBox(width: FactorySpacing.xs),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: FactorySpacing.sm),
                Text(
                  value,
                  softWrap: true,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
                if (detail != null && detail!.isNotEmpty) ...[
                  const SizedBox(height: FactorySpacing.xs),
                  Text(
                    detail!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum FactoryNoticeTone { information, success, warning, danger }

/// Warnings always include words and an icon, not color-only meaning.
/// This widget represents a state; it does NOT acknowledge a database write.
class FactoryStatusLabel extends StatelessWidget {
  const FactoryStatusLabel({
    required this.label,
    required this.tone,
    super.key,
  });

  final String label;
  final FactoryNoticeTone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, color) = switch (tone) {
      FactoryNoticeTone.information => (Icons.info_outline, scheme.primary),
      FactoryNoticeTone.success => (
          Icons.check_circle_outline,
          FactoryColors.success,
        ),
      FactoryNoticeTone.warning => (
          Icons.warning_amber_rounded,
          FactoryColors.warning,
        ),
      FactoryNoticeTone.danger => (
          Icons.error_outline,
          scheme.error,
        ),
    };
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(FactoryRadius.sm),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: FactorySpacing.sm,
              vertical: FactorySpacing.xs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: FactorySpacing.xs),
                Flexible(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum FactoryViewState { loading, empty, error, offline, forbidden }

/// Human-readable state with an optional explicit retry action.
/// Retry must be connected to an actual data reload, not an unsafe replay
/// of a dispatch, payment, cylinder issue or stock mutation.
class FactoryStatePanel extends StatelessWidget {
  const FactoryStatePanel({
    required this.state,
    required this.message,
    this.onRetry,
    super.key,
  });

  final FactoryViewState state;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final icon = switch (state) {
      FactoryViewState.loading => Icons.hourglass_empty_rounded,
      FactoryViewState.empty => Icons.inbox_outlined,
      FactoryViewState.error => Icons.error_outline,
      FactoryViewState.offline => Icons.wifi_off_outlined,
      FactoryViewState.forbidden => Icons.lock_outline,
    };
    return Semantics(
      liveRegion: state == FactoryViewState.error ||
          state == FactoryViewState.offline,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(FactorySpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: scheme.onSurfaceVariant, size: 40),
                const SizedBox(height: FactorySpacing.md),
                Text(message, textAlign: TextAlign.center),
                if (state == FactoryViewState.loading) ...[
                  const SizedBox(height: FactorySpacing.md),
                  const CircularProgressIndicator(),
                ],
                if (onRetry != null) ...[
                  const SizedBox(height: FactorySpacing.md),
                  OutlinedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
