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
    required this.organizationName,
    required this.role,
    required this.factories,
    required this.memberCount,
    required this.modules,
  });

  final String organizationName;
  final AppRole role;
  final List<Map<String, dynamic>> factories;
  final int memberCount;
  final List<AppModule> modules;
}

class AdminRepository {
  AdminRepository(this.client);
  final SupabaseClient client;

  Future<AdminData> load(User user) async {
    final memberships = await client
        .from('organization_members')
        .select('organization_id, role, organizations(name)')
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
        .select('id,name,code,city,state')
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
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(FactorySpacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_outline, size: 44),
                      const SizedBox(height: FactorySpacing.md),
                      Text('${snapshot.error}'),
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
          );
        }
        return AdminDashboard(data: snapshot.requireData);
      },
    );
  }
}

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({required this.data, super.key});
  final AdminData data;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FactoryOS'),
        actions: [
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
          Text(
            data.organizationName,
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          Text('${data.role.label} · live Supabase organization context'),
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
              final twoColumns = constraints.maxWidth >= 900;
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
                      title: 'Factories',
                      children: data.factories.isEmpty
                          ? const [ListTile(title: Text('No accessible factories'))]
                          : data.factories
                              .map(
                                (factory) => ListTile(
                                  leading: const Icon(Icons.factory_outlined),
                                  title: Text(factory['name'] as String),
                                  subtitle: Text(
                                    [
                                      factory['code'],
                                      factory['city'],
                                      factory['state'],
                                    ].whereType<String>().join(' · '),
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: SectionCard(
                      title: 'Enabled modules',
                      children: data.modules
                          .map(
                            (module) => ListTile(
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
        ],
      ),
    );
  }
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

class SectionCard extends StatelessWidget {
  const SectionCard({required this.title, required this.children, super.key});
  final String title;
  final List<Widget> children;

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
              child: Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}
