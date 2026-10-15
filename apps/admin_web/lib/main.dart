import 'package:factoryos_core/factoryos_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'access_management.dart';
import 'hr_management.dart';
import 'inventory_management.dart';
import 'production_management.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment();
  if (config.isConfigured) {
    await Supabase.initialize(url: config.url, publishableKey: config.key);
  }
  runApp(FactoryAdminApp(config: config));
}

class AppConfig {
  const AppConfig(this.url, this.key);
  factory AppConfig.fromEnvironment() {
    const url = String.fromEnvironment('SUPABASE_URL');
    const current = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
    const legacy = String.fromEnvironment('SUPABASE_ANON_KEY');
    return AppConfig(url, current.isNotEmpty ? current : legacy);
  }
  final String url;
  final String key;
  bool get isConfigured => url.isNotEmpty && key.isNotEmpty;
}

class FactoryAdminApp extends StatelessWidget {
  const FactoryAdminApp({required this.config, super.key});
  final AppConfig config;

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'FactoryOS Admin',
        theme: FactoryTheme.light(),
        home: config.isConfigured ? const AuthGate() : const ConfigPage(),
      );
}

class ConfigPage extends StatelessWidget {
  const ConfigPage({super.key});
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
      builder: (context, snapshot) => snapshot.data?.session == null ? const SignInPage() : AdminBootstrap(user: snapshot.data!.session!.user),
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

  Future<void> submit() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithPassword(email: email.text.trim(), password: password.text);
    } on AuthException catch (e) {
      if (mounted) setState(() => error = e.message);
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
                  const Text('Factory administration'),
                  const SizedBox(height: FactorySpacing.lg),
                  TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
                  const SizedBox(height: FactorySpacing.md),
                  TextField(controller: password, obscureText: true, onSubmitted: (_) => submit(), decoration: const InputDecoration(labelText: 'Password')),
                  if (error != null) ...[
                    const SizedBox(height: FactorySpacing.sm),
                    Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: FactorySpacing.lg),
                  FilledButton(onPressed: busy ? null : submit, child: Text(busy ? 'Signing in…' : 'Sign in')),
                ]),
              ),
            ),
          ),
        ),
      );
}

class Workspace {
  const Workspace({required this.orgId, required this.org, required this.role, required this.factories, required this.members, required this.modules});
  final String orgId;
  final Map<String, dynamic> org;
  final AppRole role;
  final List<Map<String, dynamic>> factories;
  final int members;
  final List<AppModule> modules;
}

class BootstrapResult {
  const BootstrapResult({this.workspace, this.invite, this.message});
  final Workspace? workspace;
  final Map<String, dynamic>? invite;
  final String? message;
}

class AdminRepository {
  AdminRepository(this.client);
  final SupabaseClient client;

  Future<BootstrapResult> bootstrap(User user) async {
    final memberships = await client
        .from('organization_members')
        .select('organization_id,role,organizations(id,name,code,legal_name,country_code,timezone,currency_code)')
        .eq('user_id', user.id)
        .eq('is_active', true)
        .limit(1);
    if (memberships.isEmpty) {
      final pending = await client.rpc('pending_invitation_for_current_user') as List<dynamic>;
      return pending.isEmpty
          ? const BootstrapResult(message: 'No active membership or pending invitation was found.')
          : BootstrapResult(invite: Map<String, dynamic>.from(pending.first as Map));
    }
    final membership = Map<String, dynamic>.from(memberships.first);
    final role = AppRole.fromWireName(membership['role'] as String);
    if (!role.canUseAdminPortal) return BootstrapResult(message: '${role.label} access is active. Use the FactoryOS mobile app.');
    final orgId = membership['organization_id'] as String;
    final org = Map<String, dynamic>.from(membership['organizations'] as Map);
    final factories = await client.from('factories').select('id,name,code,city,state').eq('organization_id', orgId).eq('is_active', true).order('name');
    final members = await client.from('organization_members').select('id').eq('organization_id', orgId).eq('is_active', true);
    final rawModules = await client.from('organization_modules').select('app_modules(key,name,sort_order)').eq('organization_id', orgId).eq('is_enabled', true);
    final modules = rawModules.map((row) => AppModule.fromMap(Map<String, dynamic>.from(row['app_modules'] as Map))).toList()..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return BootstrapResult(workspace: Workspace(orgId: orgId, org: org, role: role, factories: List<Map<String, dynamic>>.from(factories), members: members.length, modules: modules));
  }

  Future<void> addFactory(String orgId, Map<String, dynamic> values) async => client.from('factories').insert({'organization_id': orgId, ...values});
  Future<void> updateFactory(String id, Map<String, dynamic> values) async => client.from('factories').update(values).eq('id', id);
  Future<void> disableFactory(String id) async => client.from('factories').update({'is_active': false}).eq('id', id);
  Future<void> updateOrganization(String id, Map<String, dynamic> values) async => client.from('organizations').update(values).eq('id', id);
}

class AdminBootstrap extends StatefulWidget {
  const AdminBootstrap({required this.user, super.key});
  final User user;
  @override
  State<AdminBootstrap> createState() => _AdminBootstrapState();
}

class _AdminBootstrapState extends State<AdminBootstrap> {
  late Future<BootstrapResult> future;
  @override
  void initState() {
    super.initState();
    future = _load();
  }
  Future<BootstrapResult> _load() => AdminRepository(Supabase.instance.client).bootstrap(widget.user);
  void reload() => setState(() => future = _load());

  @override
  Widget build(BuildContext context) => FutureBuilder<BootstrapResult>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Scaffold(body: Center(child: CircularProgressIndicator()));
          if (snapshot.hasError) return _Message(text: '${snapshot.error}', onRetry: reload);
          final result = snapshot.requireData;
          if (result.invite != null) return OnboardingPage(invite: result.invite!, onDone: reload);
          if (result.workspace != null) return AdminShell(workspace: result.workspace!, onRefresh: reload);
          return _Message(text: result.message ?? 'Access unavailable.', onRetry: reload);
        },
      );
}

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({required this.invite, required this.onDone, super.key});
  final Map<String, dynamic> invite;
  final VoidCallback onDone;
  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  late final TextEditingController name;
  late final TextEditingController phone;
  final password = TextEditingController();
  final confirm = TextEditingController();
  bool busy = false;
  String? error;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.invite['full_name'] as String? ?? '');
    phone = TextEditingController(text: widget.invite['phone'] as String? ?? '');
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  Future<void> complete() async {
    if (name.text.trim().length < 2 || password.text.length < 8 || password.text != confirm.text) {
      setState(() => error = 'Enter your name, matching passwords, and at least 8 password characters.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await Supabase.instance.client.auth.updateUser(UserAttributes(password: password.text));
      await Supabase.instance.client.rpc('complete_invitation', params: {'p_invitation_id': widget.invite['invitation_id'], 'p_full_name': name.text.trim(), 'p_phone': phone.text.trim()});
      if (mounted) widget.onDone();
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Card(child: Padding(padding: const EdgeInsets.all(FactorySpacing.xl), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Icon(Icons.verified_user_outlined, size: 52, color: FactoryColors.blue),
              const SizedBox(height: FactorySpacing.md),
              Text('Complete your account', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              Text('${widget.invite['organization_name']} · ${AppRole.fromWireName(widget.invite['invited_role'] as String).label}'),
              const SizedBox(height: FactorySpacing.lg),
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Full name')),
              const SizedBox(height: FactorySpacing.sm),
              TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone')),
              const SizedBox(height: FactorySpacing.sm),
              TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Create password')),
              const SizedBox(height: FactorySpacing.sm),
              TextField(controller: confirm, obscureText: true, onSubmitted: (_) => complete(), decoration: const InputDecoration(labelText: 'Confirm password')),
              if (error != null) ...[const SizedBox(height: FactorySpacing.sm), Text(error!, style: TextStyle(color: Colors.red))],
              const SizedBox(height: FactorySpacing.lg),
              FilledButton(onPressed: busy ? null : complete, child: Text(busy ? 'Finishing…' : 'Complete setup')),
            ]))),
          ),
        ),
      );
}

class AdminShell extends StatefulWidget {
  const AdminShell({required this.workspace, required this.onRefresh, super.key});
  final Workspace workspace;
  final VoidCallback onRefresh;
  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int index = 0;
  @override
  Widget build(BuildContext context) {
    final w = widget.workspace;
    final hrEnabled = w.modules.any((module) => module.key == 'hr');
    final inventoryEnabled = w.modules.any((module) => module.key == 'inventory');
    final productionEnabled = w.modules.any((module) => module.key == 'production');
    final tabs = <_Tab>[
      _Tab('Overview', Icons.dashboard_outlined, Overview(workspace: w)),
      _Tab('Factories', Icons.factory_outlined, Factories(workspace: w, onChanged: widget.onRefresh)),
      if (hrEnabled) _Tab('HR', Icons.groups_2_outlined, HrManagementPage(organizationId: w.orgId, actorRole: w.role, factories: w.factories)),
      if (inventoryEnabled) _Tab('Inventory', Icons.inventory_2_outlined, InventoryManagementPage(organizationId: w.orgId, actorRole: w.role, factories: w.factories)),
      if (productionEnabled) _Tab('Production', Icons.precision_manufacturing_outlined, ProductionManagementPage(organizationId: w.orgId, actorRole: w.role, factories: w.factories)),
      if (w.role.canManageAccess) _Tab('Users', Icons.groups_outlined, AccessManagementPage(organizationId: w.orgId, actorRole: w.role, factories: w.factories)),
      _Tab('Modules', Icons.widgets_outlined, ModuleList(modules: w.modules)),
      _Tab('Organization', Icons.settings_outlined, Organization(workspace: w, onChanged: widget.onRefresh)),
    ];
    if (index >= tabs.length) index = 0;
    final compact = MediaQuery.sizeOf(context).width < 900;
    if (compact) {
      return Scaffold(
        appBar: AppBar(title: Text(w.org['name'] as String), actions: [IconButton(onPressed: () => Supabase.instance.client.auth.signOut(), icon: const Icon(Icons.logout))]),
        body: tabs[index].page,
        bottomNavigationBar: NavigationBar(selectedIndex: index, onDestinationSelected: (value) => setState(() => index = value), destinations: tabs.map((tab) => NavigationDestination(icon: Icon(tab.icon), label: tab.label)).toList()),
      );
    }
    return Scaffold(body: Row(children: [
      NavigationRail(extended: MediaQuery.sizeOf(context).width > 1160, selectedIndex: index, onDestinationSelected: (value) => setState(() => index = value), leading: const Padding(padding: EdgeInsets.all(FactorySpacing.lg), child: Text('FactoryOS', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900))), destinations: tabs.map((tab) => NavigationRailDestination(icon: Icon(tab.icon), label: Text(tab.label))).toList()),
      const VerticalDivider(width: 1),
      Expanded(child: tabs[index].page),
      IconButton(onPressed: () => Supabase.instance.client.auth.signOut(), icon: const Icon(Icons.logout)),
    ]));
  }
}

class _Tab {
  const _Tab(this.label, this.icon, this.page);
  final String label;
  final IconData icon;
  final Widget page;
}

class Overview extends StatelessWidget {
  const Overview({required this.workspace, super.key});
  final Workspace workspace;
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(FactorySpacing.lg), children: [
        Text(workspace.org['name'] as String, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
        Text(workspace.role.label),
        const SizedBox(height: FactorySpacing.lg),
        Wrap(spacing: FactorySpacing.md, runSpacing: FactorySpacing.md, children: [_Metric('Factories', '${workspace.factories.length}', Icons.factory_outlined), _Metric('Users', '${workspace.members}', Icons.groups_outlined), _Metric('Modules', '${workspace.modules.length}', Icons.widgets_outlined)]),
      ]);
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.icon);
  final String label;
  final String value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => SizedBox(width: 220, child: Card(child: Padding(padding: const EdgeInsets.all(FactorySpacing.lg), child: Row(children: [CircleAvatar(child: Icon(icon)), const SizedBox(width: FactorySpacing.md), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)), Text(label)])]))));
}

class Factories extends StatefulWidget {
  const Factories({required this.workspace, required this.onChanged, super.key});
  final Workspace workspace;
  final VoidCallback onChanged;
  @override
  State<Factories> createState() => _FactoriesState();
}

class _FactoriesState extends State<Factories> {
  Future<void> openEditor([Map<String, dynamic>? factory]) async {
    final result = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => FactoryEditor(initial: factory));
    if (result == null || !mounted) return;
    final repo = AdminRepository(Supabase.instance.client);
    if (factory == null) {
      await repo.addFactory(widget.workspace.orgId, result);
    } else {
      await repo.updateFactory(factory['id'] as String, result);
    }
    if (mounted) widget.onChanged();
  }

  Future<void> disable(Map<String, dynamic> factory) async {
    await AdminRepository(Supabase.instance.client).disableFactory(factory['id'] as String);
    if (mounted) widget.onChanged();
  }

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(FactorySpacing.lg), children: [
        Row(children: [Expanded(child: Text('Factories', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800))), if (widget.workspace.role.canManageOrganizationSetup) FilledButton.icon(onPressed: () => openEditor(), icon: const Icon(Icons.add), label: const Text('New'))]),
        const SizedBox(height: FactorySpacing.md),
        for (final factory in widget.workspace.factories)
          Card(child: ListTile(leading: const Icon(Icons.factory_outlined), title: Text(factory['name'] as String), subtitle: Text([factory['code'], factory['city'], factory['state']].whereType<String>().join(' · ')), trailing: widget.workspace.role.canManageOrganizationSetup ? PopupMenuButton<String>(onSelected: (value) => value == 'edit' ? openEditor(factory) : disable(factory), itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Edit')), PopupMenuItem(value: 'disable', child: Text('Deactivate'))]) : null)),
      ]);
}

class FactoryEditor extends StatefulWidget {
  const FactoryEditor({this.initial, super.key});
  final Map<String, dynamic>? initial;
  @override
  State<FactoryEditor> createState() => _FactoryEditorState();
}

class _FactoryEditorState extends State<FactoryEditor> {
  late final TextEditingController name = TextEditingController(text: widget.initial?['name'] as String? ?? '');
  late final TextEditingController code = TextEditingController(text: widget.initial?['code'] as String? ?? '');
  late final TextEditingController city = TextEditingController(text: widget.initial?['city'] as String? ?? '');
  late final TextEditingController state = TextEditingController(text: widget.initial?['state'] as String? ?? '');
  @override
  void dispose() {
    name.dispose();
    code.dispose();
    city.dispose();
    state.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) => AlertDialog(title: Text(widget.initial == null ? 'New factory' : 'Edit factory'), content: SizedBox(width: 480, child: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')), const SizedBox(height: FactorySpacing.sm), TextField(controller: code, decoration: const InputDecoration(labelText: 'Code')), const SizedBox(height: FactorySpacing.sm), TextField(controller: city, decoration: const InputDecoration(labelText: 'City')), const SizedBox(height: FactorySpacing.sm), TextField(controller: state, decoration: const InputDecoration(labelText: 'State'))])), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, {'name': name.text.trim(), 'code': code.text.trim().toUpperCase(), 'city': _nullIfBlank(city.text), 'state': _nullIfBlank(state.text), 'country_code': 'IN', 'timezone': 'Asia/Kolkata'}), child: const Text('Save'))]);
}

class ModuleList extends StatelessWidget {
  const ModuleList({required this.modules, super.key});
  final List<AppModule> modules;
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(FactorySpacing.lg), children: [Text('Enabled modules', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: FactorySpacing.md), for (final module in modules) Card(child: ListTile(leading: const Icon(Icons.check_circle_outline), title: Text(module.name), subtitle: Text(module.key)))]);
}

class Organization extends StatelessWidget {
  const Organization({required this.workspace, required this.onChanged, super.key});
  final Workspace workspace;
  final VoidCallback onChanged;

  Future<void> edit(BuildContext context) async {
    final current = workspace.org;
    final name = TextEditingController(text: current['name'] as String? ?? '');
    final legal = TextEditingController(text: current['legal_name'] as String? ?? '');
    final result = await showDialog<Map<String, dynamic>>(context: context, builder: (dialogContext) => AlertDialog(title: const Text('Organization settings'), content: SizedBox(width: 480, child: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')), const SizedBox(height: FactorySpacing.sm), TextField(controller: legal, decoration: const InputDecoration(labelText: 'Legal name'))])), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(dialogContext, {'name': name.text.trim(), 'legal_name': _nullIfBlank(legal.text), 'country_code': current['country_code'], 'timezone': current['timezone'], 'currency_code': current['currency_code']}), child: const Text('Save'))]));
    name.dispose();
    legal.dispose();
    if (result == null) return;
    await AdminRepository(Supabase.instance.client).updateOrganization(workspace.orgId, result);
    onChanged();
  }

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(FactorySpacing.lg), children: [
        Row(children: [Expanded(child: Text('Organization', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800))), if (workspace.role.canManageOrganizationSetup) FilledButton.icon(onPressed: () => edit(context), icon: const Icon(Icons.edit_outlined), label: const Text('Edit'))]),
        const SizedBox(height: FactorySpacing.md),
        Card(child: Padding(padding: const EdgeInsets.all(FactorySpacing.lg), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(workspace.org['name'] as String, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)), Text('Code: ${workspace.org['code']}'), Text('Timezone: ${workspace.org['timezone']}'), Text('Currency: ${workspace.org['currency_code']}')]))),
      ]);
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.onRetry});
  final String text;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Scaffold(body: Center(child: Padding(padding: const EdgeInsets.all(FactorySpacing.lg), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.info_outline, size: 52), const SizedBox(height: FactorySpacing.md), Text(text, textAlign: TextAlign.center), const SizedBox(height: FactorySpacing.md), if (onRetry != null) OutlinedButton(onPressed: onRetry, child: const Text('Retry')), const SizedBox(height: FactorySpacing.sm), if (Supabase.instance.client.auth.currentSession != null) FilledButton(onPressed: () => Supabase.instance.client.auth.signOut(), child: const Text('Sign out'))]))));
}

String? _nullIfBlank(String value) => value.trim().isEmpty ? null : value.trim();