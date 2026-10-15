import 'package:factoryos_core/factoryos_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'access_management.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment();
  if (config.isConfigured) {
    await Supabase.initialize(url: config.supabaseUrl, publishableKey: config.publishableKey);
  }
  runApp(FactoryAdminApp(config: config));
}

class AppConfig {
  const AppConfig({required this.supabaseUrl, required this.publishableKey});

  factory AppConfig.fromEnvironment() {
    const url = String.fromEnvironment('SUPABASE_URL');
    const currentKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
    const legacyKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    return AppConfig(supabaseUrl: url, publishableKey: currentKey.isNotEmpty ? currentKey : legacyKey);
  }

  final String supabaseUrl;
  final String publishableKey;
  bool get isConfigured => supabaseUrl.isNotEmpty && publishableKey.isNotEmpty;
}

class FactoryAdminApp extends StatelessWidget {
  const FactoryAdminApp({required this.config, super.key});
  final AppConfig config;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'FactoryOS Admin',
        debugShowCheckedModeBanner: false,
        theme: FactoryTheme.light(),
        home: config.isConfigured ? const AuthGate() : const MissingConfigPage(),
      );
}

class MissingConfigPage extends StatelessWidget {
  const MissingConfigPage({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(FactorySpacing.lg),
            child: Text('Provide SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY using --dart-define.'),
          ),
        ),
      );
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;
    return StreamBuilder<AuthState>(
      stream: client.auth.onAuthStateChange,
      initialData: AuthState(AuthChangeEvent.initialSession, client.auth.currentSession),
      builder: (context, snapshot) {
        final session = snapshot.data?.session;
        return session == null ? const SignInPage() : AdminBootstrap(user: session.user);
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
      await Supabase.instance.client.auth.signInWithPassword(email: email.text.trim(), password: password.text);
    } on AuthException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(FactorySpacing.xl),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('FactoryOS', style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: FactorySpacing.xs),
                  const Text('Factory administration'),
                  const SizedBox(height: FactorySpacing.lg),
                  TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
                  const SizedBox(height: FactorySpacing.md),
                  TextField(controller: password, obscureText: true, onSubmitted: (_) => signIn(), decoration: const InputDecoration(labelText: 'Password')),
                  if (error != null) ...[
                    const SizedBox(height: FactorySpacing.sm),
                    Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: FactorySpacing.lg),
                  FilledButton(onPressed: busy ? null : signIn, child: Text(busy ? 'Signing in…' : 'Sign in')),
                ]),
              ),
            ),
          ),
        ),
      );
}

class AdminWorkspace {
  const AdminWorkspace({
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

class BootstrapData {
  const BootstrapData({this.workspace, this.invitation, this.message});
  final AdminWorkspace? workspace;
  final Map<String, dynamic>? invitation;
  final String? message;
}

class AdminRepository {
  AdminRepository(this.client);
  final SupabaseClient client;

  Future<BootstrapData> bootstrap(User user) async {
    final memberships = await client
        .from('organization_members')
        .select('organization_id,role,organizations(id,name,code,legal_name,country_code,timezone,currency_code)')
        .eq('user_id', user.id)
        .eq('is_active', true)
        .limit(1);

    if (memberships.isEmpty) {
      final pending = await client.rpc('pending_invitation_for_current_user');
      final rows = pending as List<dynamic>;
      if (rows.isNotEmpty) return BootstrapData(invitation: Map<String, dynamic>.from(rows.first as Map));
      return const BootstrapData(message: 'No active FactoryOS membership or pending invitation was found.');
    }

    final membership = Map<String, dynamic>.from(memberships.first);
    final role = AppRole.fromWireName(membership['role'] as String);
    if (!role.canUseAdminPortal) {
      return BootstrapData(message: '${role.label} access is active. Use the FactoryOS mobile app for this role.');
    }

    final organizationId = membership['organization_id'] as String;
    final organization = Map<String, dynamic>.from(membership['organizations'] as Map);
    final factories = await client
        .from('factories')
        .select('id,name,code,address_line1,city,state,postal_code,country_code,timezone,is_active')
        .eq('organization_id', organizationId)
        .eq('is_active', true)
        .order('name');
    final members = await client.from('organization_members').select('id').eq('organization_id', organizationId).eq('is_active', true);
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

    return BootstrapData(
      workspace: AdminWorkspace(
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
      ),
    );
  }

  Future<void> updateOrganization(String organizationId, OrganizationDraft draft) async {
    await client.from('organizations').update(draft.toMap()).eq('id', organizationId);
  }

  Future<void> createFactory(String organizationId, FactoryDraft draft) async {
    await client.from('factories').insert({'organization_id': organizationId, ...draft.toMap()});
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
  late Future<BootstrapData> future;

  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() => setState(() => future = AdminRepository(Supabase.instance.client).bootstrap(widget.user));

  @override
  Widget build(BuildContext context) => FutureBuilder<BootstrapData>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Scaffold(body: Center(child: CircularProgressIndicator()));
          if (snapshot.hasError) return MessagePage(message: '${snapshot.error}', onRetry: reload);
          final data = snapshot.requireData;
          if (data.invitation != null) return OnboardingPage(invitation: data.invitation!, onCompleted: reload);
          if (data.workspace != null) return AdminDashboard(workspace: data.workspace!, onRefresh: reload);
          return MessagePage(message: data.message ?? 'Access unavailable.', onRetry: reload);
        },
      );
}

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({required this.invitation, required this.onCompleted, super.key});
  final Map<String, dynamic> invitation;
  final VoidCallback onCompleted;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  late final TextEditingController fullName;
  late final TextEditingController phone;
  final password = TextEditingController();
  final confirmPassword = TextEditingController();
  bool busy = false;
  String? error;

  @override
  void initState() {
    super.initState();
    fullName = TextEditingController(text: widget.invitation['full_name'] as String? ?? '');
    phone = TextEditingController(text: widget.invitation['phone'] as String? ?? '');
  }

  @override
  void dispose() {
    fullName.dispose();
    phone.dispose();
    password.dispose();
    confirmPassword.dispose();
    super.dispose();
  }

  Future<void> complete() async {
    final name = fullName.text.trim();
    if (name.length < 2) return setState(() => error = 'Enter your full name.');
    if (password.text.length < 8) return setState(() => error = 'Password must contain at least 8 characters.');
    if (password.text != confirmPassword.text) return setState(() => error = 'Passwords do not match.');

    setState(() {
      busy = true;
      error = null;
    });
    try {
      await Supabase.instance.client.auth.updateUser(UserAttributes(password: password.text));
      await Supabase.instance.client.rpc('complete_invitation', params: {
        'p_invitation_id': widget.invitation['invitation_id'],
        'p_full_name': name,
        'p_phone': phone.text.trim(),
      });
      if (mounted) widget.onCompleted();
    } catch (exception) {
      if (mounted) setState(() => error = '$exception');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final factoryNames = (widget.invitation['factory_names'] as List<dynamic>? ?? const []).join(', ');
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(FactorySpacing.xl),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Icon(Icons.verified_user_outlined, size: 52, color: FactoryColors.blue),
                const SizedBox(height: FactorySpacing.md),
                Text('Complete your FactoryOS account', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: FactorySpacing.sm),
                Text('${widget.invitation['organization_name']} · ${AppRole.fromWireName(widget.invitation['invited_role'] as String).label}${factoryNames.isEmpty ? '' : ' · $factoryNames'}'),
                const SizedBox(height: FactorySpacing.lg),
                TextField(controller: fullName, decoration: const InputDecoration(labelText: 'Full name')),
                const SizedBox(height: FactorySpacing.sm),
                TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone')),
                const SizedBox(height: FactorySpacing.sm),
                TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Create password')),
                const SizedBox(height: FactorySpacing.sm),
                TextField(controller: confirmPassword, obscureText: true, onSubmitted: (_) => complete(), decoration: const InputDecoration(labelText: 'Confirm password')),
                if (error != null) ...[
                  const SizedBox(height: FactorySpacing.sm),
                  Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: FactorySpacing.lg),
                FilledButton(onPressed: busy ? null : complete, child: Text(busy ? 'Finishing setup…' : 'Complete setup')),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({required this.workspace, required this.onRefresh, super.key});
  final AdminWorkspace workspace;
  final VoidCallback onRefresh;

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int selected = 0;

  @override
  Widget build(BuildContext context) {
    final workspace = widget.workspace;
    final destinations = <_Destination>[
      _Destination('Overview', Icons.dashboard_outlined, OverviewPage(workspace: workspace)),
      _Destination('Factories', Icons.factory_outlined, FactoriesPage(workspace: workspace, onChanged: widget.onRefresh)),
      if (workspace.role.canManageAccess)
        _Destination('Users', Icons.groups_outlined, AccessManagementPage(organizationId: workspace.organizationId, actorRole: workspace.role, factories: workspace.factories)),
      _Destination('Modules', Icons.widgets_outlined, ModulesPage(modules: workspace.modules)),
      _Destination('Organization', Icons.settings_outlined, OrganizationPage(workspace: workspace, onChanged: widget.onRefresh)),
    ];
    if (selected >= destinations.length) selected = 0;
    final compact = MediaQuery.sizeOf(context).width < 900;

    if (compact) {
      return Scaffold(
        appBar: AppBar(title: Text(workspace.organizationName), actions: [IconButton(tooltip: 'Sign out', onPressed: () => Supabase.instance.client.auth.signOut(), icon: const Icon(Icons.logout))]),
        body: destinations[selected].page,
        bottomNavigationBar: NavigationBar(
          selectedIndex: selected,
          onDestinationSelected: (value) => setState(() => selected = value),
          destinations: destinations.map((item) => NavigationDestination(icon: Icon(item.icon), label: item.label)).toList(),
        ),
      );
    }

    return Scaffold(
      body: Row(children: [
        NavigationRail(
          extended: MediaQuery.sizeOf(context).width >= 1180,
          selectedIndex: selected,
          onDestinationSelected: (value) => setState(() => selected = value),
          leading: const Padding(padding: EdgeInsets.symmetric(vertical: FactorySpacing.lg), child: Text('FactoryOS', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: FactoryColors.navy))),
          destinations: destinations.map((item) => NavigationRailDestination(icon: Icon(item.icon), label: Text(item.label))).toList(),
        ),
        const VerticalDivider(width: 1),
        Expanded(child: destinations[selected].page),
        IconButton(tooltip: 'Sign out', onPressed: () => Supabase.instance.client.auth.signOut(), icon: const Icon(Icons.logout)),
        const SizedBox(width: FactorySpacing.sm),
      ]),
    );
  }
}

class _Destination {
  const _Destination(this.label, this.icon, this.page);
  final String label;
  final IconData icon;
  final Widget page;
}

class OverviewPage extends StatelessWidget {
  const OverviewPage({required this.workspace, super.key});
  final AdminWorkspace workspace;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(FactorySpacing.lg),
        children: [
          Text(workspace.organizationName, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: FactorySpacing.xs),
          Text('${workspace.role.label} · live organization context'),
          const SizedBox(height: FactorySpacing.lg),
          Wrap(spacing: FactorySpacing.md, runSpacing: FactorySpacing.md, children: [
            MetricCard(label: 'Active factories', value: '${workspace.factories.length}', icon: Icons.factory_outlined),
            MetricCard(label: 'Active members', value: '${workspace.memberCount}', icon: Icons.groups_outlined),
            MetricCard(label: 'Enabled modules', value: '${workspace.modules.length}', icon: Icons.widgets_outlined),
          ]),
          const SizedBox(height: FactorySpacing.lg),
          Card(child: Padding(padding: const EdgeInsets.all(FactorySpacing.lg), child: Text('Phase 2 access flow is enabled: invite → onboarding → role → factory assignment → authenticated access.', style: Theme.of(context).textTheme.titleMedium))),
        ],
      );
}

class FactoriesPage extends StatefulWidget {
  const FactoriesPage({required this.workspace, required this.onChanged, super.key});
  final AdminWorkspace workspace;
  final VoidCallback onChanged;

  @override
  State<FactoriesPage> createState() => _FactoriesPageState();
}

class _FactoriesPageState extends State<FactoriesPage> {
  AdminRepository get repository => AdminRepository(Supabase.instance.client);

  Future<void> edit([Map<String, dynamic>? factory]) async {
    final draft = await showDialog<FactoryDraft>(context: context, builder: (_) => FactoryDialog(initial: factory));
    if (draft == null || !mounted) return;
    try {
      if (factory == null) {
        await repository.createFactory(widget.workspace.organizationId, draft);
      } else {
        await repository.updateFactory(factory['id'] as String, draft);
      }
      if (mounted) widget.onChanged();
    } catch (error) {
      if (mounted) _message(error);
    }
  }

  Future<void> deactivate(Map<String, dynamic> factory) async {
    try {
      await repository.deactivateFactory(factory['id'] as String);
      if (mounted) widget.onChanged();
    } catch (error) {
      if (mounted) _message(error);
    }
  }

  void _message(Object error) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(FactorySpacing.lg),
        children: [
          Row(children: [
            Expanded(child: Text('Factories', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800))),
            if (widget.workspace.role.canManageOrganizationSetup) FilledButton.icon(onPressed: () => edit(), icon: const Icon(Icons.add), label: const Text('New factory')),
          ]),
          const SizedBox(height: FactorySpacing.md),
          for (final factory in widget.workspace.factories)
            Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.factory_outlined)),
                title: Text(factory['name'] as String),
                subtitle: Text([factory['code'], factory['city'], factory['state']].whereType<String>().join(' · ')),
                trailing: widget.workspace.role.canManageOrganizationSetup
                    ? PopupMenuButton<String>(
                        onSelected: (value) => value == 'edit' ? edit(factory) : deactivate(factory),
                        itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Edit')), PopupMenuItem(value: 'deactivate', child: Text('Deactivate'))],
                      )
                    : null,
              ),
            ),
        ],
      );
}

class ModulesPage extends StatelessWidget {
  const ModulesPage({required this.modules, super.key});
  final List<AppModule> modules;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(FactorySpacing.lg),
        children: [
          Text('Enabled modules', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: FactorySpacing.md),
          for (final module in modules) Card(child: ListTile(leading: const Icon(Icons.check_circle_outline), title: Text(module.name), subtitle: Text(module.key))),
        ],
      );
}

class OrganizationPage extends StatefulWidget {
  const OrganizationPage({required this.workspace, required this.onChanged, super.key});
  final AdminWorkspace workspace;
  final VoidCallback onChanged;

  @override
  State<OrganizationPage> createState() => _OrganizationPageState();
}

class _OrganizationPageState extends State<OrganizationPage> {
  Future<void> edit() async {
    final draft = await showDialog<OrganizationDraft>(context: context, builder: (_) => OrganizationDialog(workspace: widget.workspace));
    if (draft == null || !mounted) return;
    try {
      await AdminRepository(Supabase.instance.client).updateOrganization(widget.workspace.organizationId, draft);
      if (mounted) widget.onChanged();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(FactorySpacing.lg),
        children: [
          Row(children: [
            Expanded(child: Text('Organization', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800))),
            if (widget.workspace.role.canManageOrganizationSetup) FilledButton.icon(onPressed: edit, icon: const Icon(Icons.edit_outlined), label: const Text('Edit')),
          ]),
          const SizedBox(height: FactorySpacing.md),
          Card(child: Padding(padding: const EdgeInsets.all(FactorySpacing.lg), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.workspace.organizationName, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: FactorySpacing.sm),
            Text('Code: ${widget.workspace.organizationCode}'),
            Text('Legal name: ${widget.workspace.legalName ?? '—'}'),
            Text('Country: ${widget.workspace.countryCode}'),
            Text('Timezone: ${widget.workspace.timezone}'),
            Text('Currency: ${widget.workspace.currencyCode}'),
          ]))),
        ],
      );
}

class MetricCard extends StatelessWidget {
  const MetricCard({required this.label, required this.value, required this.icon, super.key});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 230,
        child: Card(child: Padding(padding: const EdgeInsets.all(FactorySpacing.lg), child: Row(children: [
          CircleAvatar(child: Icon(icon)),
          const SizedBox(width: FactorySpacing.md),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)), Text(label)]),
        ]))),
      );
}

class FactoryDraft {
  const FactoryDraft({required this.name, required this.code, required this.addressLine1, required this.city, required this.state, required this.postalCode, required this.countryCode, required this.timezone});
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
  const OrganizationDraft({required this.name, required this.legalName, required this.countryCode, required this.timezone, required this.currencyCode});
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

class FactoryDialog extends StatefulWidget {
  const FactoryDialog({this.initial, super.key});
  final Map<String, dynamic>? initial;

  @override
  State<FactoryDialog> createState() => _FactoryDialogState();
}

class _FactoryDialogState extends State<FactoryDialog> {
  late final TextEditingController name;
  late final TextEditingController code;
  late final TextEditingController address;
  late final TextEditingController city;
  late final TextEditingController state;
  late final TextEditingController postal;
  late final TextEditingController country;
  late final TextEditingController timezone;

  @override
  void initState() {
    super.initState();
    final data = widget.initial ?? const <String, dynamic>{};
    name = TextEditingController(text: data['name'] as String? ?? '');
    code = TextEditingController(text: data['code'] as String? ?? '');
    address = TextEditingController(text: data['address_line1'] as String? ?? '');
    city = TextEditingController(text: data['city'] as String? ?? '');
    state = TextEditingController(text: data['state'] as String? ?? '');
    postal = TextEditingController(text: data['postal_code'] as String? ?? '');
    country = TextEditingController(text: data['country_code'] as String? ?? 'IN');
    timezone = TextEditingController(text: data['timezone'] as String? ?? 'Asia/Kolkata');
  }

  @override
  void dispose() {
    for (final controller in [name, code, address, city, state, postal, country, timezone]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.initial == null ? 'New factory' : 'Edit factory'),
        content: SizedBox(width: 540, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
          const SizedBox(height: FactorySpacing.sm),
          TextField(controller: code, decoration: const InputDecoration(labelText: 'Code')),
          const SizedBox(height: FactorySpacing.sm),
          TextField(controller: address, decoration: const InputDecoration(labelText: 'Address')),
          const SizedBox(height: FactorySpacing.sm),
          Row(children: [Expanded(child: TextField(controller: city, decoration: const InputDecoration(labelText: 'City'))), const SizedBox(width: FactorySpacing.sm), Expanded(child: TextField(controller: state, decoration: const InputDecoration(labelText: 'State')))]),
          const SizedBox(height: FactorySpacing.sm),
          Row(children: [Expanded(child: TextField(controller: postal, decoration: const InputDecoration(labelText: 'Postal code'))), const SizedBox(width: FactorySpacing.sm), Expanded(child: TextField(controller: country, decoration: const InputDecoration(labelText: 'Country code')))]),
          const SizedBox(height: FactorySpacing.sm),
          TextField(controller: timezone, decoration: const InputDecoration(labelText: 'Timezone')),
        ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: name.text.trim().length < 2 || code.text.trim().length < 2
                ? null
                : () => Navigator.pop(context, FactoryDraft(name: name.text, code: code.text, addressLine1: address.text, city: city.text, state: state.text, postalCode: postal.text, countryCode: country.text, timezone: timezone.text)),
            child: const Text('Save'),
          ),
        ],
      );
}

class OrganizationDialog extends StatefulWidget {
  const OrganizationDialog({required this.workspace, super.key});
  final AdminWorkspace workspace;

  @override
  State<OrganizationDialog> createState() => _OrganizationDialogState();
}

class _OrganizationDialogState extends State<OrganizationDialog> {
  late final TextEditingController name;
  late final TextEditingController legalName;
  late final TextEditingController country;
  late final TextEditingController timezone;
  late final TextEditingController currency;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.workspace.organizationName);
    legalName = TextEditingController(text: widget.workspace.legalName ?? '');
    country = TextEditingController(text: widget.workspace.countryCode);
    timezone = TextEditingController(text: widget.workspace.timezone);
    currency = TextEditingController(text: widget.workspace.currencyCode);
  }

  @override
  void dispose() {
    name.dispose();
    legalName.dispose();
    country.dispose();
    timezone.dispose();
    currency.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Organization settings'),
        content: SizedBox(width: 520, child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Display name')),
          const SizedBox(height: FactorySpacing.sm),
          TextField(controller: legalName, decoration: const InputDecoration(labelText: 'Legal name')),
          const SizedBox(height: FactorySpacing.sm),
          TextField(controller: country, decoration: const InputDecoration(labelText: 'Country code')),
          const SizedBox(height: FactorySpacing.sm),
          TextField(controller: timezone, decoration: const InputDecoration(labelText: 'Timezone')),
          const SizedBox(height: FactorySpacing.sm),
          TextField(controller: currency, decoration: const InputDecoration(labelText: 'Currency code')),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, OrganizationDraft(name: name.text, legalName: legalName.text, countryCode: country.text, timezone: timezone.text, currencyCode: currency.text)), child: const Text('Save')),
        ],
      );
}

class MessagePage extends StatelessWidget {
  const MessagePage({required this.message, required this.onRetry, super.key});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(FactorySpacing.lg),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.info_outline, size: 52),
              const SizedBox(height: FactorySpacing.md),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: FactorySpacing.md),
              Wrap(spacing: FactorySpacing.sm, children: [
                OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
                FilledButton(onPressed: () => Supabase.instance.client.auth.signOut(), child: const Text('Sign out')),
              ]),
            ]),
          ),
        ),
      );
}

String? _nullable(String value) {
  final cleaned = value.trim();
  return cleaned.isEmpty ? null : cleaned;
}
