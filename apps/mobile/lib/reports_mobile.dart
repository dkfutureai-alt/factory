import 'package:factoryos_core/factoryos_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'workspace_guard.dart';

class ReportsMobilePage extends StatefulWidget {
  const ReportsMobilePage({super.key});

  @override
  State<ReportsMobilePage> createState() => _ReportsMobilePageState();
}

class _ReportsMobilePageState extends State<ReportsMobilePage> {
  Future<_MobileReportContext>? contextFuture;
  Future<_MobileReportSnapshot>? reportFuture;
  _MobileReportContext? currentContext;
  String? factoryId;
  int days = 30;

  @override
  void initState() {
    super.initState();
    contextFuture = _loadContext();
  }

  Future<_MobileReportContext> _loadContext() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) throw StateError('Sign in to open Reports.');
    final rows = await client
        .from('organization_members')
        .select('organization_id,role,organizations(name,currency_code)')
        .eq('user_id', user.id)
        .eq('is_active', true)
        .limit(2);
    if (rows.isEmpty) throw StateError('No active organization membership.');
    final membership = requireSingleActiveMembership(rows);
    final role = AppRole.fromWireName(membership['role'] as String);
    if (!const {
      AppRole.platformOwner,
      AppRole.orgAdmin,
      AppRole.factoryManager,
      AppRole.supervisor,
    }.contains(role)) {
      throw StateError('Reports are available to management roles only.');
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
    final context = _MobileReportContext(
      organizationId: organizationId,
      organizationName: organization['name'] as String,
      currencyCode: organization['currency_code'] as String? ?? 'INR',
      role: role,
      factories: List<Map<String, dynamic>>.from(factories),
    );
    currentContext = context;
    factoryId = context.canUseOrganizationScope
        ? null
        : (context.factories.isEmpty
              ? null
              : context.factories.first['id'] as String);
    reportFuture = _loadReport(context);
    return context;
  }

  Future<_MobileReportSnapshot> _loadReport(_MobileReportContext context) async {
    if (!context.canUseOrganizationScope && factoryId == null) {
      throw StateError('No factory is assigned for reporting.');
    }
    final client = Supabase.instance.client;
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: days - 1));
    final params = {
      'p_organization_id': context.organizationId,
      'p_factory_id': factoryId,
      'p_from': _date(from),
      'p_to': _date(now),
    };
    final dashboard = await client.rpc(
      'reports_executive_dashboard',
      params: params,
    );
    final exceptions = await client.rpc(
      'reports_operational_exceptions',
      params: {
        'p_organization_id': context.organizationId,
        'p_factory_id': factoryId,
        'p_limit': 20,
      },
    );
    return _MobileReportSnapshot(
      dashboard: Map<String, dynamic>.from(dashboard as Map),
      exceptions: (exceptions as List<dynamic>)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList(),
    );
  }

  void reload() {
    final context = currentContext;
    if (context == null) {
      setState(() => contextFuture = _loadContext());
      return;
    }
    setState(() => reportFuture = _loadReport(context));
  }

  void chooseFactory(String? value) {
    final context = currentContext;
    if (context == null || value == null) return;
    final next = value == '__all__' ? null : value;
    if (next == factoryId) return;
    setState(() {
      factoryId = next;
      reportFuture = _loadReport(context);
    });
  }

  void chooseDays(int value) {
    final context = currentContext;
    if (context == null || value == days) return;
    setState(() {
      days = value;
      reportFuture = _loadReport(context);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Reports'),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: reload,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: FutureBuilder<_MobileReportContext>(
          future: contextFuture,
          builder: (context, contextSnapshot) {
            if (contextSnapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (contextSnapshot.hasError) {
              return _ErrorState(
                message: '${contextSnapshot.error}',
                onRetry: reload,
              );
            }
            final reportContext = contextSnapshot.requireData;
            final currentReport = reportFuture;
            if (currentReport == null) {
              return const Center(child: CircularProgressIndicator());
            }
            return FutureBuilder<_MobileReportSnapshot>(
              future: currentReport,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _ErrorState(
                    message: '${snapshot.error}',
                    onRetry: reload,
                  );
                }
                final data = snapshot.requireData;
                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() => reportFuture = _loadReport(reportContext));
                    await reportFuture;
                  },
                  child: ListView(
                    padding: const EdgeInsets.all(FactorySpacing.md),
                    children: [
                      Text(
                        reportContext.organizationName,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      Text('${reportContext.role.label} · management reporting'),
                      const SizedBox(height: FactorySpacing.md),
                      DropdownButtonFormField<String>(
                        initialValue: factoryId ?? '__all__',
                        decoration: const InputDecoration(
                          labelText: 'Factory scope',
                        ),
                        items: [
                          if (reportContext.canUseOrganizationScope)
                            const DropdownMenuItem(
                              value: '__all__',
                              child: Text('All factories'),
                            ),
                          ...reportContext.factories.map(
                            (factory) => DropdownMenuItem(
                              value: factory['id'] as String,
                              child: Text(factory['name'] as String),
                            ),
                          ),
                        ],
                        onChanged: chooseFactory,
                      ),
                      const SizedBox(height: FactorySpacing.sm),
                      SegmentedButton<int>(
                        segments: const [
                          ButtonSegment(value: 7, label: Text('7d')),
                          ButtonSegment(value: 30, label: Text('30d')),
                          ButtonSegment(value: 90, label: Text('90d')),
                        ],
                        selected: {days},
                        onSelectionChanged: (values) => chooseDays(values.first),
                      ),
                      const SizedBox(height: FactorySpacing.lg),
                      _KpiRows(
                        data: data.dashboard,
                        currencyCode: reportContext.currencyCode,
                      ),
                      const SizedBox(height: FactorySpacing.lg),
                      Text(
                        'Module health',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: FactorySpacing.sm),
                      _HealthTile(
                        icon: Icons.precision_manufacturing_outlined,
                        title: 'Production',
                        value:
                            '${_number(data.dashboard['production_output'])} / ${_number(data.dashboard['production_planned'])}',
                        note: 'actual / planned output',
                      ),
                      _HealthTile(
                        icon: Icons.verified_outlined,
                        title: 'Quality',
                        value:
                            '${_num(data.dashboard['quality_pass_rate']).toStringAsFixed(1)}%',
                        note:
                            '${data.dashboard['open_ncrs'] ?? 0} open NCR(s)',
                      ),
                      _HealthTile(
                        icon: Icons.route_outlined,
                        title: 'Fleet & Delivery',
                        value: '${data.dashboard['active_trips'] ?? 0}',
                        note:
                            '${data.dashboard['deliveries_completed'] ?? 0} delivered in period',
                      ),
                      _HealthTile(
                        icon: Icons.build_outlined,
                        title: 'Maintenance',
                        value:
                            '${data.dashboard['maintenance_open_work'] ?? 0}',
                        note:
                            '${data.dashboard['maintenance_assets_down'] ?? 0} asset(s) down',
                      ),
                      _HealthTile(
                        icon: Icons.groups_2_outlined,
                        title: 'People',
                        value: '${data.dashboard['present_today'] ?? 0}',
                        note:
                            '${data.dashboard['active_employees'] ?? 0} active employees',
                      ),
                      const SizedBox(height: FactorySpacing.lg),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Exceptions',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ),
                          Chip(label: Text('${data.exceptions.length}')),
                        ],
                      ),
                      const SizedBox(height: FactorySpacing.sm),
                      if (data.exceptions.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(FactorySpacing.lg),
                            child: Text('No current operational exceptions.'),
                          ),
                        )
                      else
                        for (final row in data.exceptions.take(12))
                          Card(
                            child: ListTile(
                              leading: _SeverityIcon(
                                severity: row['severity'] as String,
                              ),
                              title: Text(row['title'] as String),
                              subtitle: Text(row['detail'] as String),
                              trailing: Text(_title(row['module'] as String)),
                            ),
                          ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      );
}

class _MobileReportContext {
  const _MobileReportContext({
    required this.organizationId,
    required this.organizationName,
    required this.currencyCode,
    required this.role,
    required this.factories,
  });

  final String organizationId;
  final String organizationName;
  final String currencyCode;
  final AppRole role;
  final List<Map<String, dynamic>> factories;

  bool get canUseOrganizationScope =>
      role == AppRole.platformOwner || role == AppRole.orgAdmin;
}

class _MobileReportSnapshot {
  const _MobileReportSnapshot({
    required this.dashboard,
    required this.exceptions,
  });
  final Map<String, dynamic> dashboard;
  final List<Map<String, dynamic>> exceptions;
}

class _KpiRows extends StatelessWidget {
  const _KpiRows({required this.data, required this.currencyCode});
  final Map<String, dynamic> data;
  final String currencyCode;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _KpiCard(
                  icon: Icons.trending_up,
                  label: 'Sales billed',
                  value: _money(data['sales_billed'], currencyCode),
                ),
              ),
              const SizedBox(width: FactorySpacing.sm),
              Expanded(
                child: _KpiCard(
                  icon: Icons.inventory_2_outlined,
                  label: 'Inventory',
                  value: _number(data['inventory_quantity']),
                ),
              ),
            ],
          ),
          const SizedBox(height: FactorySpacing.sm),
          Row(
            children: [
              Expanded(
                child: _KpiCard(
                  icon: Icons.precision_manufacturing_outlined,
                  label: 'Output',
                  value: _number(data['production_output']),
                ),
              ),
              const SizedBox(width: FactorySpacing.sm),
              Expanded(
                child: _KpiCard(
                  icon: Icons.warning_amber_rounded,
                  label: 'Low stock',
                  value: '${data['low_stock_items'] ?? 0}',
                ),
              ),
            ],
          ),
        ],
      );
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(FactorySpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: FactoryColors.blue),
              const SizedBox(height: FactorySpacing.sm),
              Text(label),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
      );
}

class _HealthTile extends StatelessWidget {
  const _HealthTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.note,
  });
  final IconData icon;
  final String title;
  final String value;
  final String note;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: CircleAvatar(child: Icon(icon)),
          title: Text(title),
          subtitle: Text(note),
          trailing: Text(
            value,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
      );
}

class _SeverityIcon extends StatelessWidget {
  const _SeverityIcon({required this.severity});
  final String severity;

  @override
  Widget build(BuildContext context) {
    final color = switch (severity) {
      'critical' || 'high' => Colors.red,
      'medium' => Colors.orange,
      _ => FactoryColors.blue,
    };
    return CircleAvatar(
      backgroundColor: color.withValues(alpha: 0.12),
      child: Icon(Icons.priority_high, color: color),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(FactorySpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: FactorySpacing.md),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: FactorySpacing.md),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      );
}

num _num(dynamic value) => value is num ? value : num.tryParse('$value') ?? 0;

String _number(dynamic value) {
  final number = _num(value);
  if (number == number.roundToDouble()) return number.toInt().toString();
  return number.toStringAsFixed(2);
}

String _money(dynamic value, String currencyCode) {
  final symbol = currencyCode == 'INR' ? '₹' : '$currencyCode ';
  return '$symbol${_num(value).toStringAsFixed(2)}';
}

String _title(String value) => value
    .split('_')
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');

String _date(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
