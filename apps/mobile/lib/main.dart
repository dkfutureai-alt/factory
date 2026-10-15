import 'package:factoryos_core/factoryos_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = MobileConfig.fromEnvironment();
  if (config.isConfigured) {
    await Supabase.initialize(
      url: config.supabaseUrl,
      publishableKey: config.publishableKey,
    );
  }
  runApp(FactoryMobileApp(config: config));
}

class MobileConfig {
  const MobileConfig({required this.supabaseUrl, required this.publishableKey});

  factory MobileConfig.fromEnvironment() {
    const url = String.fromEnvironment('SUPABASE_URL');
    const currentKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
    const legacyKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    return MobileConfig(
      supabaseUrl: url,
      publishableKey: currentKey.isNotEmpty ? currentKey : legacyKey,
    );
  }

  final String supabaseUrl;
  final String publishableKey;

  bool get isConfigured => supabaseUrl.isNotEmpty && publishableKey.isNotEmpty;
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
      home: config.isConfigured ? const MobileAuthGate() : const ConfigPage(),
    );
  }
}

class ConfigPage extends StatelessWidget {
  const ConfigPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(FactorySpacing.lg),
          child: Center(
            child: Text(
              'FactoryOS backend is not configured. Provide SUPABASE_URL and '
              'SUPABASE_PUBLISHABLE_KEY using --dart-define.',
            ),
          ),
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
      initialData: AuthState(
        AuthChangeEvent.initialSession,
        client.auth.currentSession,
      ),
      builder: (context, snapshot) {
        final session = snapshot.data?.session;
        return session == null
            ? const SignInPage()
            : MobileBootstrap(user: session.user);
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
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(FactorySpacing.lg),
          children: [
            const SizedBox(height: 72),
            const Icon(Icons.factory, size: 68, color: FactoryColors.blue),
            const SizedBox(height: FactorySpacing.lg),
            Text(
              'FactoryOS',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .headlineLarge
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: FactorySpacing.xs),
            const Text(
              'Sign in to your factory workspace',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: FactorySpacing.xl),
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
    );
  }
}

class MobileData {
  const MobileData({
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

class MobileRepository {
  MobileRepository(this.client);
  final SupabaseClient client;

  Future<MobileData> load(User user) async {
    final memberships = await client
        .from('organization_members')
        .select('organization_id, role, organizations(name)')
        .eq('user_id', user.id)
        .eq('is_active', true)
        .limit(1);

    if (memberships.isEmpty) {
      throw StateError('No active FactoryOS membership found.');
    }

    final membership = Map<String, dynamic>.from(memberships.first);
    final organizationId = membership['organization_id'] as String;
    final organization = Map<String, dynamic>.from(
      membership['organizations'] as Map,
    );
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
        .map((row) => Map<String, dynamic>.from(row['app_modules'] as Map))
        .map(AppModule.fromMap)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return MobileData(
      organizationName: organization['name'] as String,
      role: AppRole.fromWireName(membership['role'] as String),
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
  late Future<MobileData> future;

  @override
  void initState() {
    super.initState();
    future = MobileRepository(Supabase.instance.client).load(widget.user);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MobileData>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(FactorySpacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48),
                      const SizedBox(height: FactorySpacing.md),
                      Text('${snapshot.error}', textAlign: TextAlign.center),
                      const SizedBox(height: FactorySpacing.md),
                      FilledButton(
                        onPressed: () => Supabase.instance.client.auth.signOut(),
                        child: const Text('Sign out'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        return MobileHome(data: snapshot.requireData);
      },
    );
  }
}

class MobileHome extends StatefulWidget {
  const MobileHome({required this.data, super.key});
  final MobileData data;

  @override
  State<MobileHome> createState() => _MobileHomeState();
}

class _MobileHomeState extends State<MobileHome> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeTab(data: widget.data),
      const SimpleTab(title: 'Tasks', icon: Icons.task_alt),
      const SimpleTab(title: 'Scan', icon: Icons.qr_code_scanner),
      const SimpleTab(title: 'Alerts', icon: Icons.notifications_none),
      ProfileTab(data: widget.data),
    ];

    return Scaffold(
      body: SafeArea(child: pages[index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(icon: Icon(Icons.task_alt), label: 'Tasks'),
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner),
            label: 'Scan',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_none),
            label: 'Alerts',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class HomeTab extends StatelessWidget {
  const HomeTab({required this.data, super.key});
  final MobileData data;

  @override
  Widget build(BuildContext context) {
    final primaryFactory = data.factories.isEmpty ? null : data.factories.first;
    return ListView(
      padding: const EdgeInsets.all(FactorySpacing.md),
      children: [
        Row(
          children: [
            const CircleAvatar(child: Icon(Icons.factory_outlined)),
            const SizedBox(width: FactorySpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.organizationName,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(data.role.label),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: FactorySpacing.lg),
        Card(
          child: ListTile(
            leading: const Icon(Icons.location_on_outlined),
            title: Text(
              primaryFactory == null
                  ? 'No factory assigned'
                  : primaryFactory['name'] as String,
            ),
            subtitle: primaryFactory == null
                ? null
                : Text(
                    [
                      primaryFactory['code'],
                      primaryFactory['city'],
                      primaryFactory['state'],
                    ].whereType<String>().join(' · '),
                  ),
          ),
        ),
        const SizedBox(height: FactorySpacing.lg),
        Text(
          'Work modules',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: FactorySpacing.md),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: data.modules.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.35,
            crossAxisSpacing: FactorySpacing.sm,
            mainAxisSpacing: FactorySpacing.sm,
          ),
          itemBuilder: (context, index) {
            final module = data.modules[index];
            return Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(FactoryRadius.lg),
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${module.name} will activate when its workflow phase is implemented.',
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(FactorySpacing.md),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.widgets_outlined, color: FactoryColors.blue),
                      const SizedBox(height: FactorySpacing.sm),
                      Text(
                        module.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        if (data.modules.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(FactorySpacing.lg),
              child: Text('No modules are enabled for this organization.'),
            ),
          ),
      ],
    );
  }
}

class SimpleTab extends StatelessWidget {
  const SimpleTab({required this.title, required this.icon, super.key});
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52),
          const SizedBox(height: FactorySpacing.md),
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: FactorySpacing.xs),
          const Text('Shell ready. Workflow implementation follows its module phase.'),
        ],
      ),
    );
  }
}

class ProfileTab extends StatelessWidget {
  const ProfileTab({required this.data, super.key});
  final MobileData data;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(FactorySpacing.lg),
      children: [
        Text(
          'Profile',
          style: Theme.of(context)
              .textTheme
              .headlineMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: FactorySpacing.lg),
        Card(
          child: ListTile(
            leading: const Icon(Icons.business_outlined),
            title: Text(data.organizationName),
            subtitle: Text(data.role.label),
          ),
        ),
        const SizedBox(height: FactorySpacing.lg),
        FilledButton.tonalIcon(
          onPressed: () => Supabase.instance.client.auth.signOut(),
          icon: const Icon(Icons.logout),
          label: const Text('Sign out'),
        ),
      ],
    );
  }
}
