import 'package:factoryos_core/factoryos_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'commercial_operations.dart';
import 'fleet_driver.dart';
import 'hr_self_service.dart';
import 'inventory_scanner.dart';
import 'production_execution.dart';
import 'quality_execution.dart';
import 'warehouse_operations.dart';

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
  Widget build(BuildContext context) => MaterialApp(
    title: 'FactoryOS',
    debugShowCheckedModeBanner: false,
    theme: FactoryTheme.light(),
    home: config.isConfigured ? const MobileAuthGate() : const ConfigPage(),
  );
}

class ConfigPage extends StatelessWidget {
  const ConfigPage({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: Padding(
        padding: EdgeInsets.all(FactorySpacing.lg),
        child: Text(
          'Provide SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY using --dart-define.',
        ),
      ),
    ),
  );
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
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(FactorySpacing.lg),
        children: [
          const SizedBox(height: 64),
          const Icon(Icons.factory, size: 68, color: FactoryColors.blue),
          const SizedBox(height: FactorySpacing.md),
          Text(
            'FactoryOS',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
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

class MobileBootstrapData {
  const MobileBootstrapData({this.workspace, this.invitation, this.message});
  final MobileData? workspace;
  final Map<String, dynamic>? invitation;
  final String? message;
}

class MobileRepository {
  MobileRepository(this.client);
  final SupabaseClient client;

  Future<MobileBootstrapData> bootstrap(User user) async {
    final memberships = await client
        .from('organization_members')
        .select('organization_id,role,organizations(name)')
        .eq('user_id', user.id)
        .eq('is_active', true)
        .limit(1);

    if (memberships.isEmpty) {
      final pending = await client.rpc('pending_invitation_for_current_user');
      final rows = pending as List<dynamic>;
      if (rows.isNotEmpty)
        return MobileBootstrapData(
          invitation: Map<String, dynamic>.from(rows.first as Map),
        );
      return const MobileBootstrapData(
        message:
            'No active FactoryOS membership or pending invitation was found.',
      );
    }

    final membership = Map<String, dynamic>.from(memberships.first);
    final organizationId = membership['organization_id'] as String;
    final organization = Map<String, dynamic>.from(
      membership['organizations'] as Map,
    );
    final role = AppRole.fromWireName(membership['role'] as String);
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
    final modules =
        moduleRows
            .map((row) => Map<String, dynamic>.from(row['app_modules'] as Map))
            .map(AppModule.fromMap)
            .where((module) => _moduleAllowed(role, module.key))
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return MobileBootstrapData(
      workspace: MobileData(
        organizationName: organization['name'] as String,
        role: role,
        factories: List<Map<String, dynamic>>.from(factories),
        modules: modules,
      ),
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
  late Future<MobileBootstrapData> future;

  @override
  void initState() {
    super.initState();
    future = MobileRepository(Supabase.instance.client).bootstrap(widget.user);
  }

  void reload() => setState(
    () => future = MobileRepository(
      Supabase.instance.client,
    ).bootstrap(widget.user),
  );

  @override
  Widget build(BuildContext context) => FutureBuilder<MobileBootstrapData>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done)
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      if (snapshot.hasError)
        return MobileMessagePage(message: '${snapshot.error}', onRetry: reload);
      final data = snapshot.requireData;
      if (data.invitation != null)
        return MobileOnboardingPage(
          invitation: data.invitation!,
          onCompleted: reload,
        );
      if (data.workspace != null) return MobileHome(data: data.workspace!);
      return MobileMessagePage(
        message: data.message ?? 'Access unavailable.',
        onRetry: reload,
      );
    },
  );
}

class MobileOnboardingPage extends StatefulWidget {
  const MobileOnboardingPage({
    required this.invitation,
    required this.onCompleted,
    super.key,
  });
  final Map<String, dynamic> invitation;
  final VoidCallback onCompleted;

  @override
  State<MobileOnboardingPage> createState() => _MobileOnboardingPageState();
}

class _MobileOnboardingPageState extends State<MobileOnboardingPage> {
  late final TextEditingController fullName;
  late final TextEditingController phone;
  final password = TextEditingController();
  final confirmPassword = TextEditingController();
  bool busy = false;
  String? error;

  @override
  void initState() {
    super.initState();
    fullName = TextEditingController(
      text: widget.invitation['full_name'] as String? ?? '',
    );
    phone = TextEditingController(
      text: widget.invitation['phone'] as String? ?? '',
    );
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
    if (fullName.text.trim().length < 2)
      return setState(() => error = 'Enter your full name.');
    if (password.text.length < 8)
      return setState(
        () => error = 'Password must contain at least 8 characters.',
      );
    if (password.text != confirmPassword.text)
      return setState(() => error = 'Passwords do not match.');
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: password.text),
      );
      await Supabase.instance.client.rpc(
        'complete_invitation',
        params: {
          'p_invitation_id': widget.invitation['invitation_id'],
          'p_full_name': fullName.text.trim(),
          'p_phone': phone.text.trim(),
        },
      );
      if (mounted) widget.onCompleted();
    } catch (exception) {
      if (mounted) setState(() => error = '$exception');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final factoryNames =
        (widget.invitation['factory_names'] as List<dynamic>? ?? const []).join(
          ', ',
        );
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(FactorySpacing.lg),
          children: [
            const SizedBox(height: 32),
            const Icon(
              Icons.verified_user_outlined,
              size: 64,
              color: FactoryColors.blue,
            ),
            const SizedBox(height: FactorySpacing.md),
            Text(
              'Complete your account',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: FactorySpacing.sm),
            Text(
              '${widget.invitation['organization_name']} · ${AppRole.fromWireName(widget.invitation['invited_role'] as String).label}',
              textAlign: TextAlign.center,
            ),
            if (factoryNames.isNotEmpty)
              Text(factoryNames, textAlign: TextAlign.center),
            const SizedBox(height: FactorySpacing.xl),
            TextField(
              controller: fullName,
              decoration: const InputDecoration(labelText: 'Full name'),
            ),
            const SizedBox(height: FactorySpacing.sm),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
            const SizedBox(height: FactorySpacing.sm),
            TextField(
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Create password'),
            ),
            const SizedBox(height: FactorySpacing.sm),
            TextField(
              controller: confirmPassword,
              obscureText: true,
              onSubmitted: (_) => complete(),
              decoration: const InputDecoration(labelText: 'Confirm password'),
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
              onPressed: busy ? null : complete,
              child: Text(busy ? 'Finishing setup…' : 'Complete setup'),
            ),
          ],
        ),
      ),
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
    final hasInventory = widget.data.modules.any(
      (module) => module.key == 'inventory',
    );
    final pages = [
      HomeTab(data: widget.data),
      const SimpleTab(title: 'Tasks', icon: Icons.task_alt),
      hasInventory
          ? const InventoryScannerPage()
          : const SimpleTab(title: 'Scan', icon: Icons.qr_code_scanner),
      const SimpleTab(title: 'Alerts', icon: Icons.notifications_none),
      ProfileTab(data: widget.data),
    ];
    return Scaffold(
      body: pages[index],
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

  void openModule(BuildContext context, AppModule module) {
    if (module.key == 'hr') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const HrSelfServicePage()),
      );
      return;
    }
    if (module.key == 'inventory') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const InventoryScannerPage()),
      );
      return;
    }
    if (module.key == 'production') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const ProductionExecutionPage(),
        ),
      );
      return;
    }
    if (module.key == 'quality') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const QualityExecutionPage()),
      );
      return;
    }
    if (module.key == 'purchase' || module.key == 'sales') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const CommercialOperationsPage(),
        ),
      );
      return;
    }
    if (module.key == 'warehouse') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const WarehouseOperationsPage(),
        ),
      );
      return;
    }
    if (module.key == 'vehicles') {
      if (data.role == AppRole.driver) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const FleetDriverPage()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Driver Fleet operations are available to the Driver role. Fleet planning is available in FactoryOS Admin.',
            ),
          ),
        );
      }
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${module.name} activates in its module phase.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryFactory = data.factories.isEmpty ? null : data.factories.first;
    return SafeArea(
      child: ListView(
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
            'Your modules',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
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
            itemBuilder: (context, moduleIndex) {
              final module = data.modules[moduleIndex];
              final icon = switch (module.key) {
                'hr' => Icons.groups_2_outlined,
                'inventory' => Icons.inventory_2_outlined,
                'production' => Icons.precision_manufacturing_outlined,
                'quality' => Icons.verified_user_outlined,
                'warehouse' => Icons.warehouse_outlined,
                'vehicles' => Icons.local_shipping_outlined,
                _ => Icons.widgets_outlined,
              };
              return Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(FactoryRadius.lg),
                  onTap: () => openModule(context, module),
                  child: Padding(
                    padding: const EdgeInsets.all(FactorySpacing.md),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(icon, color: FactoryColors.blue),
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
                child: Text('No modules are available for this role.'),
              ),
            ),
        ],
      ),
    );
  }
}

class SimpleTab extends StatelessWidget {
  const SimpleTab({required this.title, required this.icon, super.key});
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52),
          const SizedBox(height: FactorySpacing.md),
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: FactorySpacing.xs),
          const Text('Workflow activates in its module phase.'),
        ],
      ),
    ),
  );
}

class ProfileTab extends StatelessWidget {
  const ProfileTab({required this.data, super.key});
  final MobileData data;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ListView(
      padding: const EdgeInsets.all(FactorySpacing.lg),
      children: [
        Text(
          'Profile',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: FactorySpacing.lg),
        Card(
          child: ListTile(
            leading: const Icon(Icons.business_outlined),
            title: Text(data.organizationName),
            subtitle: Text(data.role.label),
          ),
        ),
        const SizedBox(height: FactorySpacing.md),
        for (final factory in data.factories)
          Card(
            child: ListTile(
              leading: const Icon(Icons.factory_outlined),
              title: Text(factory['name'] as String),
              subtitle: Text(factory['code'] as String),
            ),
          ),
        const SizedBox(height: FactorySpacing.lg),
        FilledButton.tonalIcon(
          onPressed: () => Supabase.instance.client.auth.signOut(),
          icon: const Icon(Icons.logout),
          label: const Text('Sign out'),
        ),
      ],
    ),
  );
}

class MobileMessagePage extends StatelessWidget {
  const MobileMessagePage({
    required this.message,
    required this.onRetry,
    super.key,
  });
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(FactorySpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline, size: 52),
              const SizedBox(height: FactorySpacing.md),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: FactorySpacing.md),
              Wrap(
                spacing: FactorySpacing.sm,
                children: [
                  OutlinedButton(
                    onPressed: onRetry,
                    child: const Text('Retry'),
                  ),
                  FilledButton(
                    onPressed: () => Supabase.instance.client.auth.signOut(),
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

bool _moduleAllowed(AppRole role, String key) {
  if (role == AppRole.platformOwner ||
      role == AppRole.orgAdmin ||
      role == AppRole.factoryManager ||
      role == AppRole.supervisor)
    return true;
  if (role == AppRole.driver)
    return const {
      'dashboard',
      'hr',
      'vehicles',
      'delivery',
      'reports',
    }.contains(key);
  if (role == AppRole.employee)
    return const {
      'dashboard',
      'hr',
      'inventory',
      'production',
      'quality',
      'warehouse',
      'delivery',
      'maintenance',
      'reports',
    }.contains(key);
  return const {'dashboard', 'reports'}.contains(key);
}
