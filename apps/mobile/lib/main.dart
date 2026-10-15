import 'package:factoryos_core/factoryos_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const config = MobileConfig.fromEnvironment();
  if (config.isConfigured) {
    await Supabase.initialize(url: config.supabaseUrl, anonKey: config.anonKey);
  }
  runApp(FactoryMobileApp(config: config));
}

class MobileConfig {
  const MobileConfig({required this.supabaseUrl, required this.anonKey});

  const MobileConfig.fromEnvironment()
      : supabaseUrl = const String.fromEnvironment('SUPABASE_URL'),
        anonKey = const String.fromEnvironment('SUPABASE_ANON_KEY');

  final String supabaseUrl;
  final String anonKey;
  bool get isConfigured => supabaseUrl.isNotEmpty && anonKey.isNotEmpty;
}

class FactoryMobileApp extends StatelessWidget {
  const FactoryMobileApp({required this.config, super.key});
  final MobileConfig config;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FactoryOS',
      debugShowCheckedModeBanner: false,
      theme: FactoryTheme.light(),
      home: config.isConfigured ? const MobileAuthGate() : const MobileConfigPage(),
    );
  }
}

class MobileConfigPage extends StatelessWidget {
  const MobileConfigPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(FactorySpacing.lg),
          child: Center(child: Text('FactoryOS backend is not configured. Provide SUPABASE_URL and SUPABASE_ANON_KEY using --dart-define.')),
        ),
      ),
    );
  }
}

class MobileAuthGate extends StatelessWidget {
  const MobileAuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;
    return StreamBuilder<AuthState>(
      stream: client.auth.onAuthStateChange,
      initialData: AuthState(AuthChangeEvent.initialSession, client.auth.currentSession),
      builder: (context, snapshot) {
        final session = snapshot.data?.session;
        return session == null ? const MobileSignInPage() : MobileBootstrap(user: session.user);
      },
    );
  }
}

class MobileSignInPage extends StatefulWidget {
  const MobileSignInPage({super.key});

  @override
  State<MobileSignInPage> createState() => _MobileSignInPageState();
}

class _MobileSignInPageState extends State<MobileSignInPage> {
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
    } on AuthException catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(FactorySpacing.lg),
          children: [
            const SizedBox(height: 72),
            const Icon(Icons.factory, size: 68, color: FactoryColors.blue),
            const SizedBox(height: FactorySpacing.lg),
            Text('FactoryOS', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: FactorySpacing.xs),
            const Text('Sign in to your factory workspace', textAlign: TextAlign.center),
            const SizedBox(height: FactorySpacing.xl),
            TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
            const SizedBox(height: FactorySpacing.md),
            TextField(controller: password, obscureText: true, onSubmitted: (_) => signIn(), decoration: const InputDecoration(labelText: 'Password')),
            if (error != null) ...[
              const SizedBox(height: FactorySpacing.sm),
              Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: FactorySpacing.lg),
            FilledButton(onPressed: busy ? null : signIn, child: Text(busy ? 'Signing in…' : 'Sign in')),
          ],
        ),
      ),
    );
  }
}

class MobileContext {
  const MobileContext({
    required this.organizationName,
    required this.role,
    required this.factories,
    required this.modules,
  });

  final String organizationName;
  final AppRole role;
  final List<Map<String, dynamic>> factories;
  final List<AppModule> modules;
}

class MobileContextRepository {
  MobileContextRepository(this.client);
  final SupabaseClient client;

  Future<MobileContext> load(User user) async {
    final rows = await client
        .from('organization_members')
        .select('organization_id, role, organizations(name)')
        .eq('user_id', user.id)
        .eq('is_active', true)
        .limit(1);
    if (rows.isEmpty) throw StateError('No active FactoryOS membership found.');

    final row = Map<String, dynamic>.from(rows.first);
    final organizationId = row['organization_id'] as String;
    final organization = Map<String, dynamic>.from(row['organizations'] as Map);
    final factories = await client
        .from('factories')
        .select('id,name,code,city,state')
        .eq('organization_id', organizationId)
        .eq('is_active', true)
        .order('name');
    final moduleRows = await client
        .from('organization_modules')
        .select('app_modules(key,name,sort_order)')
        .eq('organization_id', organizationId)
        .eq('is_enabled', true);
    final modules = moduleRows
        .map((item) => Map<String, dynamic>.from(item['app_modules'] as Map))
        .map(AppModule.fromMap)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return MobileContext(
      organizationName: organization['name'] as String,
      role: AppRole.fromWireName(row['role'] as String),
      factories: List<Map<String, dynamic>>.from(factories),
      modules: modules,
    );
  }
}

class MobileBootstrap extends StatefulWidget {
  const MobileBootstrap({required this.user, super.key});
  final User user;

  @override
  State<MobileBootstrap> createState() => _MobileBootstrapState();
}

class _MobileBootstrapState extends State<MobileBootstrap> {
  late Future<MobileContext> future;

  @override
  void initState() {
    super.initState();
    future = MobileContextRepository(Supabase.instance.client).load(widget.user);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MobileContext>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        if (snapshot.hasError) {
          return Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(FactorySpacing.lg),
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.error_outline, size: 48),
                    const SizedBox(height: FactorySpacing.md),
                    Text('${snapshot.error}', textAlign: TextAlign.center),
                    const SizedBox(height: FactorySpacing.md),
                    FilledButton(onPressed: () => Supabase.instance.client.auth.signOut(), child: const Text('Sign out')),
                  ]),
                ),
              ),
            ),
          );
        }
        return MobileShell(data: snapshot.requireData);
      },
    );
  }
}

class MobileShell extends StatefulWidget {
  const MobileShell({required this.data, super.key});
  final MobileContext data;

  @override
  State<MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends State<MobileShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      EmployeeHome(data: widget.data),
      const PlaceholderPage(title: 'Tasks', icon: Icons.task_alt),
      const PlaceholderPage(title: 'Scan', icon: Icons.qr_code_scanner),
      const PlaceholderPage(title: 'Alerts', icon: Icons.notifications_none),
      ProfilePage(data: widget.data),
    ];

    return Scaffold(
      body: SafeArea(child: pages[index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.task_alt_outlined), selectedIcon: Icon(Icons.task_alt), label: 'Tasks'),
          NavigationDestination(icon: Icon(Icons.qr_code_scanner), label: 'Scan'),
          NavigationDestination(icon: Icon(Icons.notifications_none), selectedIcon: Icon(Icons.notifications), label: 'Alerts'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class EmployeeHome extends StatelessWidget {
  const EmployeeHome({required this.data, super.key});
  final MobileContext data;

  @override
  Widget build(BuildContext context) {
    final primaryFactory = data.factories.isEmpty ? null : data.factories.first;
    return ListView(
      padding: const EdgeInsets.all(FactorySpacing.md),
      children: [
        Row(children: [
          const CircleAvatar(child: Icon(Icons.factory_outlined)),
          const SizedBox(width: FactorySpacing.sm),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(data.organizationName, style: const TextStyle(fontWeight: FontWeight.w800)),
            Text(data.role.label),
          ])),
          IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none)),
        ]),
        const SizedBox(height: FactorySpacing.lg),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(FactorySpacing.md),
            child: Row(children: [
              const Icon(Icons.location_on_outlined),
              const SizedBox(width: FactorySpacing.sm),
              Expanded(child: Text(primaryFactory == null ? 'No factory assigned' : '${primaryFactory['name']} · ${primaryFactory['code']}')),
            ]),
          ),
        ),
        const SizedBox(height: FactorySpacing.lg),
        Text('Work modules', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: FactorySpacing.md),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: data.modules.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 1.35, crossAxisSpacing: FactorySpacing.sm, mainAxisSpacing: FactorySpacing.sm),
          itemBuilder: (context, i) => ModuleCard(module: data.modules[i]),
        ),
        if (data.modules.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(FactorySpacing.lg), child: Text('No modules are enabled for this organization.'))),
      ],
    );
  }
}

class ModuleCard extends StatelessWidget {
  const ModuleCard({required this.module, super.key});
  final AppModule module;

  static const icons = <String, IconData>{
    'hr': Icons.badge_outlined,
    'inventory': Icons.inventory_2_outlined,
    'production': Icons.precision_manufacturing_outlined,
    'quality': Icons.verified_outlined,
    'purchase': Icons.shopping_cart_outlined,
    'sales': Icons.point_of_sale_outlined,
    'warehouse': Icons.warehouse_outlined,
    'vehicles': Icons.local_shipping_outlined,
    'delivery': Icons.route_outlined,
    'maintenance': Icons.build_outlined,
    'reports': Icons.analytics_outlined,
    'dashboard': Icons.dashboard_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(FactoryRadius.lg),
        onTap: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${module.name} workflow will activate when its module phase is implemented.'))),
        child: Padding(
          padding: const EdgeInsets.all(FactorySpacing.md),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icons[module.key] ?? Icons.widgets_outlined, color: FactoryColors.blue),
            const SizedBox(height: FactorySpacing.sm),
            Text(module.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }
}

class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({required this.title, required this.icon, super.key});
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 52), const SizedBox(height: FactorySpacing.md), Text(title, style: Theme.of(context).textTheme.headlineSmall), const SizedBox(height: FactorySpacing.xs), const Text('Shell ready. Workflow implementation follows its module phase.') ]));
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({required this.data, super.key});
  final MobileContext data;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(FactorySpacing.lg),
      children: [
        Text('Profile', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: FactorySpacing.lg),
        Card(child: ListTile(leading: const Icon(Icons.business_outlined), title: Text(data.organizationName), subtitle: Text(data.role.label))),
        const SizedBox(height: FactorySpacing.lg),
        FilledButton.tonalIcon(onPressed: () => Supabase.instance.client.auth.signOut(), icon: const Icon(Icons.logout), label: const Text('Sign out')),
      ],
    );
  }
}
