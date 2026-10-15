import 'dart:async';

import 'package:factoryos_core/factoryos_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const config = AppConfig.fromEnvironment();
  if (config.isConfigured) {
    await Supabase.initialize(url: config.supabaseUrl, anonKey: config.anonKey);
  }
  runApp(FactoryAdminApp(config: config));
}

class AppConfig {
  const AppConfig({required this.supabaseUrl, required this.anonKey});

  const AppConfig.fromEnvironment()
      : supabaseUrl = const String.fromEnvironment('SUPABASE_URL'),
        anonKey = const String.fromEnvironment('SUPABASE_ANON_KEY');

  final String supabaseUrl;
  final String anonKey;

  bool get isConfigured => supabaseUrl.isNotEmpty && anonKey.isNotEmpty;
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
          constraints: const BoxConstraints(maxWidth: 560),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(FactorySpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('FactoryOS Admin', style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: FactorySpacing.md),
                  const Text('Backend configuration is missing. Run with --dart-define=SUPABASE_URL=... and --dart-define=SUPABASE_ANON_KEY=...'),
                ],
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
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool submitting = false;
  String? error;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    setState(() {
      submitting = true;
      error = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );
    } on AuthException catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => submitting = false);
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
                  Text('FactoryOS', style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: FactorySpacing.xs),
                  Text('Factory administration', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: FactorySpacing.lg),
                  TextField(controller: emailController, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
                  const SizedBox(height: FactorySpacing.md),
                  TextField(controller: passwordController, obscureText: true, onSubmitted: (_) => submit(), decoration: const InputDecoration(labelText: 'Password')),
                  if (error != null) ...[
                    const SizedBox(height: FactorySpacing.sm),
                    Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: FactorySpacing.lg),
                  FilledButton(onPressed: submitting ? null : submit, child: Text(submitting ? 'Signing in…' : 'Sign in')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AdminContext {
  const AdminContext({
    required this.organizationId,
    required this.organizationName,
    required this.role,
    required this.factories,
    required this.memberCount,
    required this.modules,
  });

  final String organizationId;
  final String organizationName;
  final AppRole role;
  final List<Map<String, dynamic>> factories;
  final int memberCount;
  final List<AppModule> modules;
}

class AdminContextRepository {
  AdminContextRepository(this.client);
  final SupabaseClient client;

  Future<AdminContext> load(User user) async {
    final rows = await client
        .from('organization_members')
        .select('organization_id, role, organizations(id,name,code)')
        .eq('user_id', user.id)
        .eq('is_active', true)
        .limit(1);

    if (rows.isEmpty) throw StateError('No active organization membership found.');
    final row = Map<String, dynamic>.from(rows.first);
    final role = AppRole.fromWireName(row['role'] as String);
    if (!role.canUseAdminPortal) throw StateError('Your role does not have access to the admin portal.');

    final organization = Map<String, dynamic>.from(row['organizations'] as Map);
    final organizationId = row['organization_id'] as String;
    final factories = await client
        .from('factories')
        .select('id,name,code,city,state,is_active')
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
        .select('module_key, app_modules(key,name,sort_order)')
        .eq('organization_id', organizationId)
        .eq('is_enabled', true);

    final modules = moduleRows
        .map((item) => Map<String, dynamic>.from(item['app_modules'] as Map))
        .map(AppModule.fromMap)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return AdminContext(
      organizationId: organizationId,
      organizationName: organization['name'] as String,
      role: role,
      factories: List<Map<String, dynamic>>.from(factories),
      memberCount: members.length,
      modules: modules,
    );
  }
}

class AdminBootstrap extends StatefulWidget {
  const AdminBootstrap({required this.user, super.key});
  final User user;

  @override
  State<AdminBootstrap> createState() => _AdminBootstrapState();
}

class _AdminBootstrapState extends State<AdminBootstrap> {
  late Future<AdminContext> future;

  @override
  void initState() {
    super.initState();
    future = AdminContextRepository(Supabase.instance.client).load(widget.user);
  }

  void retry() => setState(() => future = AdminContextRepository(Supabase.instance.client).load(widget.user));

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AdminContext>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(FactorySpacing.lg),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.lock_outline, size: 42),
                      const SizedBox(height: FactorySpacing.md),
                      Text('${snapshot.error}', textAlign: TextAlign.center),
                      const SizedBox(height: FactorySpacing.md),
                      Wrap(spacing: FactorySpacing.sm, children: [
                        OutlinedButton(onPressed: retry, child: const Text('Retry')),
                        FilledButton(onPressed: () => Supabase.instance.client.auth.signOut(), child: const Text('Sign out')),
                      ]),
                    ]),
                  ),
                ),
              ),
            ),
          );
        }
        return AdminShell(data: snapshot.requireData);
      },
    );
  }
}

class AdminShell extends StatefulWidget {
  const AdminShell({required this.data, super.key});
  final AdminContext data;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int selected = 0;

  static const destinations = [
    NavigationRailDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: Text('Dashboard')),
    NavigationRailDestination(icon: Icon(Icons.factory_outlined), selectedIcon: Icon(Icons.factory), label: Text('Factories')),
    NavigationRailDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: Text('Team')),
    NavigationRailDestination(icon: Icon(Icons.widgets_outlined), selectedIcon: Icon(Icons.widgets), label: Text('Modules')),
  ];

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 920;
    final pages = [
      OverviewPage(data: widget.data),
      FactoriesPage(factories: widget.data.factories),
      TeamPage(memberCount: widget.data.memberCount, role: widget.data.role),
      ModulesPage(modules: widget.data.modules),
    ];

    if (compact) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.data.organizationName), actions: [IconButton(onPressed: () => Supabase.instance.client.auth.signOut(), icon: const Icon(Icons.logout))]),
        body: pages[selected],
        bottomNavigationBar: NavigationBar(
          selectedIndex: selected,
          onDestinationSelected: (value) => setState(() => selected = value),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.factory_outlined), selectedIcon: Icon(Icons.factory), label: 'Factories'),
            NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: 'Team'),
            NavigationDestination(icon: Icon(Icons.widgets_outlined), selectedIcon: Icon(Icons.widgets), label: 'Modules'),
          ],
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: MediaQuery.sizeOf(context).width >= 1180,
            selectedIndex: selected,
            onDestinationSelected: (value) => setState(() => selected = value),
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: FactorySpacing.lg),
              child: Text('FactoryOS', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: FactoryColors.navy)),
            ),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: FactorySpacing.lg),
                  child: IconButton(tooltip: 'Sign out', onPressed: () => Supabase.instance.client.auth.signOut(), icon: const Icon(Icons.logout)),
                ),
              ),
            ),
            destinations: destinations,
          ),
          const VerticalDivider(width: 1),
          Expanded(child: pages[selected]),
        ],
      ),
    );
  }
}

class OverviewPage extends StatelessWidget {
  const OverviewPage({required this.data, super.key});
  final AdminContext data;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(FactorySpacing.lg),
      children: [
        Text(data.organizationName, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: FactorySpacing.xs),
        Text('${data.role.label} · live organization context'),
        const SizedBox(height: FactorySpacing.lg),
        Wrap(
          spacing: FactorySpacing.md,
          runSpacing: FactorySpacing.md,
          children: [
            MetricCard(label: 'Active factories', value: '${data.factories.length}', icon: Icons.factory_outlined),
            MetricCard(label: 'Active members', value: '${data.memberCount}', icon: Icons.groups_outlined),
            MetricCard(label: 'Enabled modules', value: '${data.modules.length}', icon: Icons.widgets_outlined),
          ],
        ),
        const SizedBox(height: FactorySpacing.lg),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(FactorySpacing.lg),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Foundation status', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: FactorySpacing.sm),
              const Text('Dashboard values above are read from Supabase. Production, inventory, HR and delivery KPIs will appear only after their ledger/workflow modules are implemented.'),
            ]),
          ),
        ),
      ],
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({required this.label, required this.value, required this.icon, super.key});
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
          child: Row(children: [
            CircleAvatar(child: Icon(icon)),
            const SizedBox(width: FactorySpacing.md),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              Text(label),
            ]),
          ]),
        ),
      ),
    );
  }
}

class FactoriesPage extends StatelessWidget {
  const FactoriesPage({required this.factories, super.key});
  final List<Map<String, dynamic>> factories;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(FactorySpacing.lg),
      children: [
        Text('Factories', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: FactorySpacing.md),
        if (factories.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(FactorySpacing.lg), child: Text('No accessible factories.'))),
        for (final factory in factories)
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.factory_outlined)),
              title: Text(factory['name'] as String),
              subtitle: Text([factory['code'], factory['city'], factory['state']].whereType<String>().where((e) => e.isNotEmpty).join(' · ')),
            ),
          ),
      ],
    );
  }
}

class TeamPage extends StatelessWidget {
  const TeamPage({required this.memberCount, required this.role, super.key});
  final int memberCount;
  final AppRole role;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(FactorySpacing.lg),
      children: [
        Text('Team', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: FactorySpacing.md),
        MetricCard(label: 'Active organization members', value: '$memberCount', icon: Icons.groups_outlined),
        const SizedBox(height: FactorySpacing.md),
        Card(child: Padding(padding: const EdgeInsets.all(FactorySpacing.lg), child: Text('${role.label} access is active. Member create/edit workflows are scheduled for the HR phase.'))),
      ],
    );
  }
}

class ModulesPage extends StatelessWidget {
  const ModulesPage({required this.modules, super.key});
  final List<AppModule> modules;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(FactorySpacing.lg),
      children: [
        Text('Enabled modules', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: FactorySpacing.md),
        for (final module in modules)
          Card(child: ListTile(leading: const Icon(Icons.check_circle_outline), title: Text(module.name), subtitle: Text(module.key))),
      ],
    );
  }
}
