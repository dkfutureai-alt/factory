import 'package:factoryos_core/factoryos_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment();
  if (config.isConfigured) {
    await Supabase.initialize(
      url: config.supabaseUrl,
      publishableKey: config.publishableKey,
    );
  }
  runApp(FactoryAdminApp(config: config));
}

class AppConfig {
  const AppConfig({required this.supabaseUrl, required this.publishableKey});

  factory AppConfig.fromEnvironment() {
    const url = String.fromEnvironment('SUPABASE_URL');
    const currentKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
    const legacyKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    return AppConfig(
      supabaseUrl: url,
      publishableKey: currentKey.isNotEmpty ? currentKey : legacyKey,
    );
  }

  final String supabaseUrl;
  final String publishableKey;

  bool get isConfigured => supabaseUrl.isNotEmpty && publishableKey.isNotEmpty;
}

class FactoryAdminApp extends StatelessWidget {
  const FactoryAdminApp({required this.config, super.key});
  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FactoryOS Admin',
      debugShowCheckedModeBanner: false,
      theme: FactoryTheme.light(),
      home: config.isConfigured ? const AuthGate() : const MissingConfigPage(),
    );
  }
}

class MissingConfigPage extends StatelessWidget {
  const MissingConfigPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: const Card(
            child: Padding(
              padding: EdgeInsets.all(FactorySpacing.xl),
              child: Text(
                'FactoryOS backend is not configured. Provide SUPABASE_URL and '
                'SUPABASE_PUBLISHABLE_KEY using --dart-define.',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;
    return StreamBuilder<AuthState>(
      stream: client.auth.onAuthStateChange,
      initialData: AuthState(
        AuthChangeEvent.initialSession,
        client.auth.currentSession,
      ),
      builder: (context, snapshot) {
        final session = snapshot.data?.session;
        return session == null
            ? const SignInPage()
            : AdminBootstrap(user: session.user);
      },
    );
  }
}

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool busy = false;
  String? error;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> signIn() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email.text.trim(),
        password: password.text,
      );
    } on AuthException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(FactorySpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'FactoryOS',
                    style: Theme.of(context)
                        .textTheme
                        .headlineLarge
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: FactorySpacing.xs),
                  const Text('Factory administration'),
                  const SizedBox(height: FactorySpacing.lg),
                  TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: FactorySpacing.md),
                  TextField(
                    controller: password,
                    obscureText: true,
                    onSubmitted: (_) => signIn(),
                    decoration: const InputDecoration(labelText: 'Password'),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: FactorySpacing.sm),
                    Text(
                      error!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: FactorySpacing.lg),
                  FilledButton(
                    onPressed: busy ? null : signIn,
                    child: Text(busy ? 'Signing in…' : 'Sign in'),
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

class AdminData {
  const AdminData({
    required this.organizationId,
    required this.organizationName,
    required this.organizationCode,
    required this.legalName,
    required this.countryCode,
    required this.timezone,
    required this.currencyCode,
    required this.role,
    required this.factories,
    required this.memberCount,
    required this.modules,
  });

  final String organizationId;
  final String organizationName;
  final String organizationCode;
  final String? legalName;
  final String countryCode;
  final String timezone;
  final String currencyCode;
  final AppRole role;
  final List<Map<String, dynamic>> factories;
  final int memberCount;
  final List<AppModule> modules;
}

class FactoryDraft {
  const FactoryDraft({
    required this.name,
    required this.code,
    required this.addressLine1,
    required this.city,
    required this.state,
    required this.postalCode,
    required this.countryCode,
    required this.timezone,
  });

  final String name;
  final String code;
  final String addressLine1;
  final String city;
  final String state;
  final String postalCode;
  final String countryCode;
  final String timezone;

  Map<String, dynamic> toMap() => {
        'name': name.trim(),
        'code': code.trim().toUpperCase(),
        'address_line1': _nullable(addressLine1),
        'city': _nullable(city),
        'state': _nullable(state),
        'postal_code': _nullable(postalCode),
        'country_code': countryCode.trim().toUpperCase(),
        'timezone': timezone.trim(),
      };
}

class OrganizationDraft {
  const OrganizationDraft({
    required this.name,
    required this.legalName,
    required this.countryCode,
    required this.timezone,
    required this.currencyCode,
  });

  final String name;
  final String legalName;
  final String countryCode;
  final String timezone;
  final String currencyCode;

  Map<String, dynamic> toMap() => {
        'name': name.trim(),
        'legal_name': _nullable(legalName),
        'country_code': countryCode.trim().toUpperCase(),
        'timezone': timezone.trim(),
        'currency_code': currencyCode.trim().toUpperCase(),
      };
}

String? _nullable(String value) {
  final cleaned = value.trim();
  return cleaned.isEmpty ? null : cleaned;
}

class AdminRepository {
  AdminRepository(this.client);
  final SupabaseClient client;

  Future<AdminData> load(User user) async {
    final memberships = await client
        .from('organization_members')
        .select(
          'organization_id, role, organizations('
          'id,name,code,legal_name,country_code,timezone,currency_code)',
        )
        .eq('user_id', user.id)
        .eq('is_active', true)
        .limit(1);

    if (memberships.isEmpty) {
      throw StateError('No active organization membership found.');
    }

    final membership = Map<String, dynamic>.from(memberships.first);
    final role = AppRole.fromWireName(membership['role'] as String);
    if (!role.canUseAdminPortal) {
      throw StateError('Your role does not have access to the admin portal.');
    }

    final organizationId = membership['organization_id'] as String;
    final organization = Map<String, dynamic>.from(
      membership['organizations'] as Map,
    );
    final factories = await client
        .from('factories')
        .select(
          'id,name,code,address_line1,city,state,postal_code,'
          'country_code,timezone,is_active',
        )
        .eq('organization_id', organizationId)
        .eq('is_active', true)
        .order('name');
    final members = await client
        .from('organization_members')
        .select('id')
        .eq('organization_id', organizationId)
        .eq('is_active', true);
    final moduleRows = await client
        .from('organization_modules')
        .select('app_modules(key,name,sort_order)')
        .eq('organization_id', organizationId)
        .eq('is_enabled', true);

    final modules = moduleRows
        .map((row) => Map<String, dynamic>.from(row['app_modules'] as Map))
        .map(AppModule.fromMap)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return AdminData(
      organizationId: organizationId,
      organizationName: organization['name'] as String,
      organizationCode: organization['code'] as String,
      legalName: organization['legal_name'] as String?,
      countryCode: organization['country_code'] as String,
      timezone: organization['timezone'] as String,
      currencyCode: organization['currency_code'] as String,
      role: role,
      factories: List<Map<String, dynamic>>.from(factories),
      memberCount: members.length,
      modules: modules,
    );
  }

  Future<void> updateOrganization(
    String organizationId,
    OrganizationDraft draft,
  ) async {
    await client
        .from('organizations')
        .update(draft.toMap())
        .eq('id', organizationId);
  }

  Future<void> createFactory(String organizationId, FactoryDraft draft) async {
    await client.from('factories').insert({
      'organization_id': organizationId,
      ...draft.toMap(),
    });
  }

  Future<void> updateFactory(String factoryId, FactoryDraft draft) async {
    await client.from('factories').update(draft.toMap()).eq('id', factoryId);
  }

  Future<void> deactivateFactory(String factoryId) async {
    await client.from('factories').update({'is_active': false}).eq('id', factoryId);
  }
}

class AdminBootstrap extends StatefulWidget {
  const AdminBootstrap({required this.user, super.key});
  final User user;

  @override
  State<AdminBootstrap> createState() => _AdminBootstrapState();
}

class _AdminBootstrapState extends State<AdminBootstrap> {
  late Future<AdminData> future;

  @override
  void initState() {
    super.initState();
    future = AdminRepository(Supabase.instance.client).load(widget.user);
  }

  void retry() {
    setState(() {
      future = AdminRepository(Supabase.instance.client).load(widget.user);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AdminData>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(FactorySpacing.lg),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lock_outline, size: 44),
                        const SizedBox(height: FactorySpacing.md),
                        Text('${snapshot.error}', textAlign: TextAlign.center),
                        const SizedBox(height: FactorySpacing.md),
                        Wrap(
                          spacing: FactorySpacing.sm,
                          children: [
                            OutlinedButton(
                              onPressed: retry,
                              child: const Text('Retry'),
                            ),
                            FilledButton(
                              onPressed: () =>
                                  Supabase.instance.client.auth.signOut(),
                              child: const Text('Sign out'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }
        return AdminDashboard(data: snapshot.requireData, onRefresh: retry);
      },
    );
  }
}

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({
    required this.data,
    required this.onRefresh,
    super.key,
  });

  final AdminData data;
  final VoidCallback onRefresh;

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  AdminRepository get repository => AdminRepository(Supabase.instance.client);

  Future<void> editOrganization() async {
    final draft = await showDialog<OrganizationDraft>(
      context: context,
      builder: (_) => OrganizationDialog(data: widget.data),
    );
    if (draft == null || !mounted) return;

    try {
      await repository.updateOrganization(widget.data.organizationId, draft);
      if (!mounted) return;
      _showMessage('Organization settings updated.');
      widget.onRefresh();
    } on PostgrestException catch (error) {
      if (!mounted) return;
      _showMessage(error.message, isError: true);
    }
  }

  Future<void> createFactory() async {
    final draft = await showDialog<FactoryDraft>(
      context: context,
      builder: (_) => const FactoryDialog(),
    );
    if (draft == null || !mounted) return;

    try {
      await repository.createFactory(widget.data.organizationId, draft);
      if (!mounted) return;
      _showMessage('Factory created.');
      widget.onRefresh();
    } on PostgrestException catch (error) {
      if (!mounted) return;
      _showMessage(error.message, isError: true);
    }
  }

  Future<void> editFactory(Map<String, dynamic> factory) async {
    final draft = await showDialog<FactoryDraft>(
      context: context,
      builder: (_) => FactoryDialog(initial: factory),
    );
    if (draft == null || !mounted) return;

    try {
      await repository.updateFactory(factory['id'] as String, draft);
      if (!mounted) return;
      _showMessage('Factory updated.');
      widget.onRefresh();
    } on PostgrestException catch (error) {
      if (!mounted) return;
      _showMessage(error.message, isError: true);
    }
  }

  Future<void> deactivateFactory(Map<String, dynamic> factory) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Deactivate factory?'),
        content: Text(
          '${factory['name']} will be hidden from active factory lists. '
          'Historical records remain intact.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await repository.deactivateFactory(factory['id'] as String);
      if (!mounted) return;
      _showMessage('Factory deactivated.');
      widget.onRefresh();
    } on PostgrestException catch (error) {
      if (!mounted) return;
      _showMessage(error.message, isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final canManageSetup = data.role.canManageOrganizationSetup;

    return Scaffold(
      appBar: AppBar(
        title: const Text('FactoryOS'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: widget.onRefresh,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => Supabase.instance.client.auth.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(FactorySpacing.lg),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.organizationName,
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: FactorySpacing.xs),
                    Text(
                      '${data.role.label} · ${data.organizationCode} · live Supabase context',
                    ),
                  ],
                ),
              ),
              if (canManageSetup)
                OutlinedButton.icon(
                  onPressed: editOrganization,
                  icon: const Icon(Icons.settings_outlined),
                  label: const Text('Organization settings'),
                ),
            ],
          ),
          const SizedBox(height: FactorySpacing.lg),
          Wrap(
            spacing: FactorySpacing.md,
            runSpacing: FactorySpacing.md,
            children: [
              MetricCard(
                label: 'Active factories',
                value: '${data.factories.length}',
                icon: Icons.factory_outlined,
              ),
              MetricCard(
                label: 'Active members',
                value: '${data.memberCount}',
                icon: Icons.groups_outlined,
              ),
              MetricCard(
                label: 'Enabled modules',
                value: '${data.modules.length}',
                icon: Icons.widgets_outlined,
              ),
            ],
          ),
          const SizedBox(height: FactorySpacing.lg),
          LayoutBuilder(
            builder: (context, constraints) {
              final twoColumns = constraints.maxWidth >= 920;
              final width = twoColumns
                  ? (constraints.maxWidth - FactorySpacing.md) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: FactorySpacing.md,
                runSpacing: FactorySpacing.md,
                children: [
                  SizedBox(
                    width: width,
                    child: SectionCard(
                      title: 'Organization',
                      action: canManageSetup
                          ? TextButton.icon(
                              onPressed: editOrganization,
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('Edit'),
                            )
                          : null,
                      children: [
                        InfoRow(label: 'Code', value: data.organizationCode),
                        InfoRow(
                          label: 'Legal name',
                          value: data.legalName ?? 'Not set',
                        ),
                        InfoRow(label: 'Country', value: data.countryCode),
                        InfoRow(label: 'Timezone', value: data.timezone),
                        InfoRow(label: 'Currency', value: data.currencyCode),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: SectionCard(
                      title: 'Enabled modules',
                      children: data.modules
                          .map(
                            (module) => ListTile(
                              dense: true,
                              leading: const Icon(Icons.check_circle_outline),
                              title: Text(module.name),
                              subtitle: Text(module.key),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: FactorySpacing.lg),
          SectionCard(
            title: 'Factories',
            action: canManageSetup
                ? FilledButton.icon(
                    onPressed: createFactory,
                    icon: const Icon(Icons.add),
                    label: const Text('Add factory'),
                  )
                : const Chip(label: Text('View only')),
            children: data.factories.isEmpty
                ? const [
                    Padding(
                      padding: EdgeInsets.all(FactorySpacing.md),
                      child: Text('No active factories are available.'),
                    ),
                  ]
                : data.factories
                    .map(
                      (factory) => FactoryListTile(
                        factory: factory,
                        canManage: canManageSetup,
                        onEdit: () => editFactory(factory),
                        onDeactivate: () => deactivateFactory(factory),
                      ),
                    )
                    .toList(),
          ),
          const SizedBox(height: FactorySpacing.lg),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(FactorySpacing.lg),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.verified_user_outlined),
                  const SizedBox(width: FactorySpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tenant-safe management',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: FactorySpacing.xs),
                        const Text(
                          'Factory and organization writes are enforced by Supabase RLS. '
                          'Changes are automatically recorded in the audit log.',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FactoryListTile extends StatelessWidget {
  const FactoryListTile({
    required this.factory,
    required this.canManage,
    required this.onEdit,
    required this.onDeactivate,
    super.key,
  });

  final Map<String, dynamic> factory;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onDeactivate;

  @override
  Widget build(BuildContext context) {
    final location = [
      factory['city'],
      factory['state'],
      factory['postal_code'],
    ].whereType<String>().where((value) => value.isNotEmpty).join(' · ');

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: FactorySpacing.sm),
      leading: const CircleAvatar(child: Icon(Icons.factory_outlined)),
      title: Text(factory['name'] as String),
      subtitle: Text(
        [factory['code'] as String, if (location.isNotEmpty) location].join(' · '),
      ),
      trailing: canManage
          ? PopupMenuButton<String>(
              tooltip: 'Factory actions',
              onSelected: (value) {
                if (value == 'edit') onEdit();
                if (value == 'deactivate') onDeactivate();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit factory')),
                PopupMenuItem(
                  value: 'deactivate',
                  child: Text('Deactivate factory'),
                ),
              ],
            )
          : null,
    );
  }
}

class OrganizationDialog extends StatefulWidget {
  const OrganizationDialog({required this.data, super.key});
  final AdminData data;

  @override
  State<OrganizationDialog> createState() => _OrganizationDialogState();
}

class _OrganizationDialogState extends State<OrganizationDialog> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController name;
  late final TextEditingController legalName;
  late final TextEditingController countryCode;
  late final TextEditingController timezone;
  late final TextEditingController currencyCode;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.data.organizationName);
    legalName = TextEditingController(text: widget.data.legalName ?? '');
    countryCode = TextEditingController(text: widget.data.countryCode);
    timezone = TextEditingController(text: widget.data.timezone);
    currencyCode = TextEditingController(text: widget.data.currencyCode);
  }

  @override
  void dispose() {
    name.dispose();
    legalName.dispose();
    countryCode.dispose();
    timezone.dispose();
    currencyCode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Organization settings'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Organization name'),
                  validator: _requiredName,
                ),
                const SizedBox(height: FactorySpacing.md),
                TextFormField(
                  controller: legalName,
                  decoration: const InputDecoration(labelText: 'Legal name'),
                ),
                const SizedBox(height: FactorySpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: countryCode,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(labelText: 'Country code'),
                        validator: _twoLetterCode,
                      ),
                    ),
                    const SizedBox(width: FactorySpacing.md),
                    Expanded(
                      child: TextFormField(
                        controller: currencyCode,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(labelText: 'Currency'),
                        validator: _threeLetterCode,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: FactorySpacing.md),
                TextFormField(
                  controller: timezone,
                  decoration: const InputDecoration(labelText: 'Timezone'),
                  validator: _requiredText,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!(formKey.currentState?.validate() ?? false)) return;
            Navigator.pop(
              context,
              OrganizationDraft(
                name: name.text,
                legalName: legalName.text,
                countryCode: countryCode.text,
                timezone: timezone.text,
                currencyCode: currencyCode.text,
              ),
            );
          },
          child: const Text('Save changes'),
        ),
      ],
    );
  }
}

class FactoryDialog extends StatefulWidget {
  const FactoryDialog({this.initial, super.key});
  final Map<String, dynamic>? initial;

  @override
  State<FactoryDialog> createState() => _FactoryDialogState();
}

class _FactoryDialogState extends State<FactoryDialog> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController name;
  late final TextEditingController code;
  late final TextEditingController addressLine1;
  late final TextEditingController city;
  late final TextEditingController stateName;
  late final TextEditingController postalCode;
  late final TextEditingController countryCode;
  late final TextEditingController timezone;

  String initialValue(String key, [String fallback = '']) {
    return widget.initial?[key] as String? ?? fallback;
  }

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: initialValue('name'));
    code = TextEditingController(text: initialValue('code'));
    addressLine1 = TextEditingController(text: initialValue('address_line1'));
    city = TextEditingController(text: initialValue('city'));
    stateName = TextEditingController(text: initialValue('state'));
    postalCode = TextEditingController(text: initialValue('postal_code'));
    countryCode = TextEditingController(text: initialValue('country_code', 'IN'));
    timezone = TextEditingController(text: initialValue('timezone', 'Asia/Kolkata'));
  }

  @override
  void dispose() {
    name.dispose();
    code.dispose();
    addressLine1.dispose();
    city.dispose();
    stateName.dispose();
    postalCode.dispose();
    countryCode.dispose();
    timezone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initial != null;
    return AlertDialog(
      title: Text(editing ? 'Edit factory' : 'Add factory'),
      content: SizedBox(
        width: 560,
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Factory name'),
                  validator: _requiredName,
                ),
                const SizedBox(height: FactorySpacing.md),
                TextFormField(
                  controller: code,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Factory code',
                    helperText: 'Letters, numbers, underscore and hyphen only',
                  ),
                  validator: _factoryCode,
                ),
                const SizedBox(height: FactorySpacing.md),
                TextFormField(
                  controller: addressLine1,
                  decoration: const InputDecoration(labelText: 'Address'),
                ),
                const SizedBox(height: FactorySpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: city,
                        decoration: const InputDecoration(labelText: 'City'),
                      ),
                    ),
                    const SizedBox(width: FactorySpacing.md),
                    Expanded(
                      child: TextFormField(
                        controller: stateName,
                        decoration: const InputDecoration(labelText: 'State'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: FactorySpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: postalCode,
                        decoration: const InputDecoration(labelText: 'Postal code'),
                      ),
                    ),
                    const SizedBox(width: FactorySpacing.md),
                    Expanded(
                      child: TextFormField(
                        controller: countryCode,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(labelText: 'Country code'),
                        validator: _twoLetterCode,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: FactorySpacing.md),
                TextFormField(
                  controller: timezone,
                  decoration: const InputDecoration(labelText: 'Timezone'),
                  validator: _requiredText,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!(formKey.currentState?.validate() ?? false)) return;
            Navigator.pop(
              context,
              FactoryDraft(
                name: name.text,
                code: code.text,
                addressLine1: addressLine1.text,
                city: city.text,
                state: stateName.text,
                postalCode: postalCode.text,
                countryCode: countryCode.text,
                timezone: timezone.text,
              ),
            );
          },
          child: Text(editing ? 'Save changes' : 'Create factory'),
        ),
      ],
    );
  }
}

String? _requiredText(String? value) {
  if (value == null || value.trim().isEmpty) return 'Required';
  return null;
}

String? _requiredName(String? value) {
  final cleaned = value?.trim() ?? '';
  if (cleaned.length < 2) return 'Enter at least 2 characters';
  if (cleaned.length > 120) return 'Maximum 120 characters';
  return null;
}

String? _twoLetterCode(String? value) {
  if (!RegExp(r'^[A-Za-z]{2}$').hasMatch(value?.trim() ?? '')) {
    return 'Use 2 letters';
  }
  return null;
}

String? _threeLetterCode(String? value) {
  if (!RegExp(r'^[A-Za-z]{3}$').hasMatch(value?.trim() ?? '')) {
    return 'Use 3 letters';
  }
  return null;
}

String? _factoryCode(String? value) {
  final cleaned = value?.trim().toUpperCase() ?? '';
  if (!RegExp(r'^[A-Z0-9][A-Z0-9_-]{1,31}$').hasMatch(cleaned)) {
    return 'Use 2–32 valid characters';
  }
  return null;
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 230,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(FactorySpacing.lg),
          child: Row(
            children: [
              CircleAvatar(child: Icon(icon)),
              const SizedBox(width: FactorySpacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  Text(label),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  const InfoRow({required this.label, required this.value, super.key});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: FactorySpacing.sm,
        vertical: FactorySpacing.xs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({
    required this.title,
    required this.children,
    this.action,
    super.key,
  });

  final String title;
  final List<Widget> children;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(FactorySpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(FactorySpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  ?action,
                ],
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}
