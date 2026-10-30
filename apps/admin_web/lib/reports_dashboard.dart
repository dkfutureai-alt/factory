import 'dart:math' as math;

import 'package:factoryos_core/factoryos_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReportsDashboardPage extends StatefulWidget {
  const ReportsDashboardPage({
    required this.organizationId,
    required this.actorRole,
    required this.factories,
    required this.currencyCode,
    this.showReportWorkspace = false,
    super.key,
  });

  final String organizationId;
  final AppRole actorRole;
  final List<Map<String, dynamic>> factories;
  final String currencyCode;
  final bool showReportWorkspace;

  @override
  State<ReportsDashboardPage> createState() => _ReportsDashboardPageState();
}

class _ReportsDashboardPageState extends State<ReportsDashboardPage> {
  static const _allFactories = '__all__';
  String? factoryId;
  int days = 30;
  Future<ReportsSnapshot>? future;

  ReportsRepository get repository =>
      ReportsRepository(Supabase.instance.client);

  bool get canUseOrganizationScope =>
      widget.actorRole == AppRole.platformOwner ||
      widget.actorRole == AppRole.orgAdmin;

  @override
  void initState() {
    super.initState();
    factoryId = canUseOrganizationScope
        ? null
        : (widget.factories.isEmpty ? null : widget.factories.first['id'] as String);
    future = _load();
  }

  Future<ReportsSnapshot> _load() => repository.load(
        organizationId: widget.organizationId,
        factoryId: factoryId,
        days: days,
      );

  void reload() => setState(() => future = _load());

  void chooseFactory(String? value) {
    if (value == null) return;
    final next = value == _allFactories ? null : value;
    if (next == factoryId) return;
    setState(() {
      factoryId = next;
      future = _load();
    });
  }

  void chooseDays(int value) {
    if (value == days) return;
    setState(() {
      days = value;
      future = _load();
    });
  }

  void message(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  Future<void> saveView() async {
    try {
      await repository.saveView(
        organizationId: widget.organizationId,
        factoryId: factoryId,
        days: days,
        name: '${factoryId == null ? 'All factories' : _factoryName(factoryId)} · $days days',
      );
      if (!mounted) return;
      message('Report view saved.');
      reload();
    } catch (error) {
      if (mounted) message(_errorText(error), error: true);
    }
  }

  Future<void> deleteView(String id) async {
    try {
      await repository.deleteView(id);
      if (!mounted) return;
      message('Saved view deleted.');
      reload();
    } catch (error) {
      if (mounted) message(_errorText(error), error: true);
    }
  }

  void applyView(Map<String, dynamic> row) {
    final filters = Map<String, dynamic>.from(row['filters'] as Map? ?? const {});
    final candidateFactory = row['factory_id'] as String?;
    if (candidateFactory != null &&
        !widget.factories.any((factory) => factory['id'] == candidateFactory)) {
      return message('That factory is no longer available to this account.', error: true);
    }
    final candidateDays = (filters['days'] as num?)?.toInt() ?? 30;
    setState(() {
      factoryId = candidateFactory;
      days = const {7, 30, 90}.contains(candidateDays) ? candidateDays : 30;
      future = _load();
    });
  }

  Future<void> copyCsv(ReportsSnapshot data) async {
    final rows = <List<String>>[
      ['metric', 'value'],
      ['sales_billed', '${data.dashboard['sales_billed'] ?? 0}'],
      ['purchase_billed', '${data.dashboard['purchase_billed'] ?? 0}'],
      ['inventory_quantity', '${data.dashboard['inventory_quantity'] ?? 0}'],
      ['production_planned', '${data.dashboard['production_planned'] ?? 0}'],
      ['production_output', '${data.dashboard['production_output'] ?? 0}'],
      ['quality_pass_rate', '${data.dashboard['quality_pass_rate'] ?? 0}'],
      ['open_sales_orders', '${data.dashboard['open_sales_orders'] ?? 0}'],
      ['customer_due', '${data.dashboard['customer_due'] ?? 0}'],
      ['supplier_due', '${data.dashboard['supplier_due'] ?? 0}'],
      ['warehouse_open_picks', '${data.dashboard['warehouse_open_picks'] ?? 0}'],
      ['active_trips', '${data.dashboard['active_trips'] ?? 0}'],
      ['deliveries_completed', '${data.dashboard['deliveries_completed'] ?? 0}'],
      ['dispatch_open_exceptions', '${data.dashboard['dispatch_open_exceptions'] ?? 0}'],
      ['maintenance_open_work', '${data.dashboard['maintenance_open_work'] ?? 0}'],
      ['maintenance_assets_down', '${data.dashboard['maintenance_assets_down'] ?? 0}'],
      ['active_employees', '${data.dashboard['active_employees'] ?? 0}'],
      ['present_today', '${data.dashboard['present_today'] ?? 0}'],
      [],
      ['exception_module', 'severity', 'title', 'detail'],
      ...data.exceptions.map(
        (row) => [
          '${row['module'] ?? ''}',
          '${row['severity'] ?? ''}',
          '${row['title'] ?? ''}',
          '${row['detail'] ?? ''}',
        ],
      ),
    ];
    final csv = rows.map((row) => row.map(_csvCell).join(',')).join('\n');
    await Clipboard.setData(ClipboardData(text: csv));
    if (mounted) message('Filtered report CSV copied to clipboard.');
  }

  String _factoryName(String? id) {
    if (id == null) return 'All factories';
    for (final factory in widget.factories) {
      if (factory['id'] == id) return factory['name'] as String;
    }
    return 'Factory';
  }

  @override
  Widget build(BuildContext context) {
    if (!canUseOrganizationScope && widget.factories.isEmpty) {
      return const Center(
        child: Text('Assign this manager to a factory before opening Reports.'),
      );
    }
    final currentFuture = future;
    if (currentFuture == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return FutureBuilder<ReportsSnapshot>(
      future: currentFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ReportError(message: '${snapshot.error}', onRetry: reload);
        }
        final data = snapshot.requireData;
        final exceptionCount = data.exceptions.length;
        return ListView(
          padding: const EdgeInsets.all(FactorySpacing.lg),
          children: [
            _Header(
              title: widget.showReportWorkspace
                  ? 'Reports'
                  : 'Executive Dashboard',
              subtitle: widget.showReportWorkspace
                  ? 'Filter, inspect and export trusted operational reporting.'
                  : 'Operational health across the selected scope and period.',
              factories: widget.factories,
              factoryId: factoryId,
              canUseOrganizationScope: canUseOrganizationScope,
              days: days,
              onFactoryChanged: chooseFactory,
              onDaysChanged: chooseDays,
              onRefresh: reload,
              onSave: saveView,
              onExport: () => copyCsv(data),
            ),
            if (data.savedViews.isNotEmpty) ...[
              const SizedBox(height: FactorySpacing.md),
              _SavedViews(
                rows: data.savedViews,
                onApply: applyView,
                onDelete: deleteView,
              ),
            ],
            const SizedBox(height: FactorySpacing.lg),
            _KpiGrid(
              data: data.dashboard,
              currencyCode: widget.currencyCode,
              exceptionCount: exceptionCount,
            ),
            const SizedBox(height: FactorySpacing.lg),
            _ResponsiveTwoColumn(
              leftFlex: 7,
              rightFlex: 4,
              left: _TrendPanel(
                rows: data.trend,
                currencyCode: widget.currencyCode,
              ),
              right: _ExceptionsPanel(rows: data.exceptions),
            ),
            const SizedBox(height: FactorySpacing.lg),
            _ModuleScorecards(data: data.dashboard),
            const SizedBox(height: FactorySpacing.lg),
            _ResponsiveTwoColumn(
              leftFlex: 7,
              rightFlex: 4,
              left: _ReportWorkspace(
                data: data.dashboard,
                currencyCode: widget.currencyCode,
                expanded: widget.showReportWorkspace,
              ),
              right: _ActivityPanel(rows: data.activity),
            ),
          ],
        );
      },
    );
  }
}

class ReportsRepository {
  ReportsRepository(this.client);
  final SupabaseClient client;

  Future<ReportsSnapshot> load({
    required String organizationId,
    required String? factoryId,
    required int days,
  }) async {
    final to = DateTime.now();
    final from = DateTime(to.year, to.month, to.day)
        .subtract(Duration(days: days - 1));
    final dateFrom = _isoDate(from);
    final dateTo = _isoDate(to);
    final dashboard = await client.rpc(
      'reports_executive_dashboard',
      params: {
        'p_organization_id': organizationId,
        'p_factory_id': factoryId,
        'p_from': dateFrom,
        'p_to': dateTo,
      },
    );
    final trend = await client.rpc(
      'reports_daily_trend',
      params: {
        'p_organization_id': organizationId,
        'p_factory_id': factoryId,
        'p_from': dateFrom,
        'p_to': dateTo,
      },
    );
    final exceptions = await client.rpc(
      'reports_operational_exceptions',
      params: {
        'p_organization_id': organizationId,
        'p_factory_id': factoryId,
        'p_limit': 40,
      },
    );
    final activity = await client.rpc(
      'reports_recent_activity',
      params: {
        'p_organization_id': organizationId,
        'p_factory_id': factoryId,
        'p_limit': 24,
      },
    );
    final savedViews = await client
        .from('report_saved_views')
        .select('id,name,report_key,factory_id,filters,is_default,updated_at')
        .eq('organization_id', organizationId)
        .eq('user_id', client.auth.currentUser!.id)
        .order('updated_at', ascending: false)
        .limit(20);
    return ReportsSnapshot(
      dashboard: Map<String, dynamic>.from(dashboard as Map),
      trend: (trend as List<dynamic>)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList(),
      exceptions: (exceptions as List<dynamic>)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList(),
      activity: (activity as List<dynamic>)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList(),
      savedViews: List<Map<String, dynamic>>.from(savedViews),
    );
  }

  Future<void> saveView({
    required String organizationId,
    required String? factoryId,
    required int days,
    required String name,
  }) async {
    await client.from('report_saved_views').upsert(
      {
        'organization_id': organizationId,
        'factory_id': factoryId,
        'user_id': client.auth.currentUser!.id,
        'name': name,
        'report_key': 'executive',
        'filters': {'days': days},
      },
      onConflict: 'user_id,report_key,name',
    );
  }

  Future<void> deleteView(String id) async {
    await client.from('report_saved_views').delete().eq('id', id);
  }
}

class ReportsSnapshot {
  const ReportsSnapshot({
    required this.dashboard,
    required this.trend,
    required this.exceptions,
    required this.activity,
    required this.savedViews,
  });

  final Map<String, dynamic> dashboard;
  final List<Map<String, dynamic>> trend;
  final List<Map<String, dynamic>> exceptions;
  final List<Map<String, dynamic>> activity;
  final List<Map<String, dynamic>> savedViews;
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.factories,
    required this.factoryId,
    required this.canUseOrganizationScope,
    required this.days,
    required this.onFactoryChanged,
    required this.onDaysChanged,
    required this.onRefresh,
    required this.onSave,
    required this.onExport,
  });

  final String title;
  final String subtitle;
  final List<Map<String, dynamic>> factories;
  final String? factoryId;
  final bool canUseOrganizationScope;
  final int days;
  final ValueChanged<String?> onFactoryChanged;
  final ValueChanged<int> onDaysChanged;
  final VoidCallback onRefresh;
  final VoidCallback onSave;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: FactorySpacing.md,
            runSpacing: FactorySpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 430,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    Text(subtitle),
                  ],
                ),
              ),
              SizedBox(
                width: 250,
                child: DropdownButtonFormField<String>(
                  initialValue: factoryId ?? _ReportsDashboardPageState._allFactories,
                  decoration: const InputDecoration(labelText: 'Factory scope'),
                  items: [
                    if (canUseOrganizationScope)
                      const DropdownMenuItem(
                        value: _ReportsDashboardPageState._allFactories,
                        child: Text('All factories'),
                      ),
                    ...factories.map(
                      (factory) => DropdownMenuItem(
                        value: factory['id'] as String,
                        child: Text(factory['name'] as String),
                      ),
                    ),
                  ],
                  onChanged: onFactoryChanged,
                ),
              ),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 7, label: Text('7d')),
                  ButtonSegment(value: 30, label: Text('30d')),
                  ButtonSegment(value: 90, label: Text('90d')),
                ],
                selected: {days},
                onSelectionChanged: (value) => onDaysChanged(value.first),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
              ),
              OutlinedButton.icon(
                onPressed: onSave,
                icon: const Icon(Icons.bookmark_add_outlined),
                label: const Text('Save view'),
              ),
              FilledButton.tonalIcon(
                onPressed: onExport,
                icon: const Icon(Icons.content_copy_outlined),
                label: const Text('Copy CSV'),
              ),
            ],
          ),
        ],
      );
}

class _SavedViews extends StatelessWidget {
  const _SavedViews({
    required this.rows,
    required this.onApply,
    required this.onDelete,
  });
  final List<Map<String, dynamic>> rows;
  final ValueChanged<Map<String, dynamic>> onApply;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: FactorySpacing.sm,
        runSpacing: FactorySpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text('Saved:'),
          ...rows.take(6).map(
                (row) => InputChip(
                  label: Text(row['name'] as String),
                  avatar: const Icon(Icons.bookmark_outline, size: 18),
                  onPressed: () => onApply(row),
                  onDeleted: () => onDelete(row['id'] as String),
                ),
              ),
        ],
      );
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({
    required this.data,
    required this.currencyCode,
    required this.exceptionCount,
  });
  final Map<String, dynamic> data;
  final String currencyCode;
  final int exceptionCount;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _Kpi(
        'Sales billed',
        _money(data['sales_billed'], currencyCode),
        Icons.trending_up,
        _deltaText(data['sales_billed'], data['previous_sales_billed']),
      ),
      _Kpi(
        'Purchase billed',
        _money(data['purchase_billed'], currencyCode),
        Icons.shopping_cart_outlined,
        _deltaText(data['purchase_billed'], data['previous_purchase_billed']),
      ),
      _Kpi(
        'Inventory on hand',
        _number(data['inventory_quantity']),
        Icons.inventory_2_outlined,
        '${data['low_stock_items'] ?? 0} low-stock item(s)',
      ),
      _Kpi(
        'Production output',
        _number(data['production_output']),
        Icons.precision_manufacturing_outlined,
        '${_planAttainment(data)}% of period plan',
      ),
      _Kpi(
        'Open exceptions',
        '$exceptionCount',
        Icons.warning_amber_rounded,
        '${data['open_ncrs'] ?? 0} NCR · ${data['dispatch_open_exceptions'] ?? 0} dispatch',
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final count = width >= 1250 ? 5 : width >= 900 ? 3 : width >= 600 ? 2 : 1;
        final cardWidth = (width - (count - 1) * FactorySpacing.md) / count;
        return Wrap(
          spacing: FactorySpacing.md,
          runSpacing: FactorySpacing.md,
          children: cards
              .map(
                (card) => SizedBox(
                  width: cardWidth,
                  child: _KpiCard(data: card),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _Kpi {
  const _Kpi(this.label, this.value, this.icon, this.note);
  final String label;
  final String value;
  final IconData icon;
  final String note;
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.data});
  final _Kpi data;

  @override
  Widget build(BuildContext context) => FactoryMetricCard(
        icon: data.icon,
        label: data.label,
        value: data.value,
        detail: data.note,
      );
}

class _ResponsiveTwoColumn extends StatelessWidget {
  const _ResponsiveTwoColumn({
    required this.left,
    required this.right,
    required this.leftFlex,
    required this.rightFlex,
  });
  final Widget left;
  final Widget right;
  final int leftFlex;
  final int rightFlex;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 980) {
            return Column(
              children: [
                left,
                const SizedBox(height: FactorySpacing.md),
                right,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: leftFlex, child: left),
              const SizedBox(width: FactorySpacing.md),
              Expanded(flex: rightFlex, child: right),
            ],
          );
        },
      );
}

class _TrendPanel extends StatelessWidget {
  const _TrendPanel({required this.rows, required this.currencyCode});
  final List<Map<String, dynamic>> rows;
  final String currencyCode;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(FactorySpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Operations trend',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const Text('Planned vs actual production across the selected period.'),
              const SizedBox(height: FactorySpacing.md),
              Wrap(
                spacing: FactorySpacing.lg,
                children: const [
                  _Legend(label: 'Planned', color: Color(0xFF2563EB)),
                  _Legend(label: 'Actual', color: Color(0xFF16A34A)),
                ],
              ),
              const SizedBox(height: FactorySpacing.sm),
              SizedBox(
                height: 235,
                width: double.infinity,
                child: rows.isEmpty
                    ? const Center(child: Text('No trend data for this period.'))
                    : CustomPaint(painter: _TrendPainter(rows)),
              ),
              const Divider(),
              Wrap(
                spacing: FactorySpacing.xl,
                runSpacing: FactorySpacing.sm,
                children: [
                  Text(
                    'Sales ${_money(_sum(rows, 'sales_billed'), currencyCode)}',
                  ),
                  Text(
                    'Purchases ${_money(_sum(rows, 'purchase_billed'), currencyCode)}',
                  ),
                  Text(
                    'Deliveries ${_sum(rows, 'deliveries_completed').toInt()}',
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}

class _Legend extends StatelessWidget {
  const _Legend({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label),
        ],
      );
}

class _TrendPainter extends CustomPainter {
  const _TrendPainter(this.rows);
  final List<Map<String, dynamic>> rows;

  @override
  void paint(Canvas canvas, Size size) {
    const plannedColor = Color(0xFF2563EB);
    const actualColor = Color(0xFF16A34A);
    final gridPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    final values = <double>[
      ...rows.map((row) => _num(row['production_planned']).toDouble()),
      ...rows.map((row) => _num(row['production_output']).toDouble()),
    ];
    final maxValue = values.fold<double>(1, math.max);
    if (rows.length < 2) return;
    Path makePath(String key) {
      final path = Path();
      for (var index = 0; index < rows.length; index++) {
        final x = size.width * index / (rows.length - 1);
        final value = _num(rows[index][key]).toDouble();
        final y = size.height - (value / maxValue * (size.height - 8)) - 4;
        if (index == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      return path;
    }
    canvas.drawPath(
      makePath('production_planned'),
      Paint()
        ..color = plannedColor
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      makePath('production_output'),
      Paint()
        ..color = actualColor
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) =>
      oldDelegate.rows != rows;
}

class _ExceptionsPanel extends StatelessWidget {
  const _ExceptionsPanel({required this.rows});
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(FactorySpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Operational exceptions',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const Text('Highest-priority items needing attention.'),
              const SizedBox(height: FactorySpacing.sm),
              if (rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: FactorySpacing.xl),
                  child: Center(child: Text('No current exceptions.')),
                )
              else
                for (final row in rows.take(7))
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: _SeverityDot(severity: row['severity'] as String),
                    title: Text(row['title'] as String),
                    subtitle: Text(row['detail'] as String),
                    trailing: Text(_title(row['module'] as String)),
                  ),
            ],
          ),
        ),
      );
}

class _SeverityDot extends StatelessWidget {
  const _SeverityDot({required this.severity});
  final String severity;
  @override
  Widget build(BuildContext context) {
    final color = switch (severity) {
      'critical' => const Color(0xFF991B1B),
      'high' => const Color(0xFFDC2626),
      'medium' => const Color(0xFFD97706),
      _ => const Color(0xFF2563EB),
    };
    return CircleAvatar(
      radius: 13,
      backgroundColor: color.withValues(alpha: 0.12),
      child: Icon(Icons.priority_high, size: 16, color: color),
    );
  }
}

class _ModuleScorecards extends StatelessWidget {
  const _ModuleScorecards({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _Score('Quality', '${_num(data['quality_pass_rate']).toStringAsFixed(1)}%', 'Inspection pass rate', Icons.verified_outlined),
      _Score('Warehouse', '${data['warehouse_open_picks'] ?? 0}', 'Open picks / staging', Icons.warehouse_outlined),
      _Score('Fleet & Delivery', '${data['active_trips'] ?? 0}', '${data['deliveries_completed'] ?? 0} delivered in period', Icons.local_shipping_outlined),
      _Score('Maintenance', '${data['maintenance_open_work'] ?? 0}', '${data['maintenance_assets_down'] ?? 0} asset(s) down', Icons.build_outlined),
      _Score('People', '${data['active_employees'] ?? 0}', '${data['present_today'] ?? 0} present today', Icons.groups_2_outlined),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = constraints.maxWidth >= 1200 ? 5 : constraints.maxWidth >= 760 ? 3 : 1;
        final width = (constraints.maxWidth - (count - 1) * FactorySpacing.md) / count;
        return Wrap(
          spacing: FactorySpacing.md,
          runSpacing: FactorySpacing.md,
          children: cards
              .map(
                (card) => SizedBox(
                  width: width,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(FactorySpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(card.icon, color: FactoryColors.blue),
                          const SizedBox(height: FactorySpacing.sm),
                          Text(card.label),
                          Text(
                            card.value,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          Text(card.note, style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _Score {
  const _Score(this.label, this.value, this.note, this.icon);
  final String label;
  final String value;
  final String note;
  final IconData icon;
}

class _ReportWorkspace extends StatelessWidget {
  const _ReportWorkspace({
    required this.data,
    required this.currencyCode,
    required this.expanded,
  });
  final Map<String, dynamic> data;
  final String currencyCode;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final rows = <_ReportRow>[
      _ReportRow('Sales', 'Billed value', _money(data['sales_billed'], currencyCode), _healthDelta(data['sales_billed'], data['previous_sales_billed'])),
      _ReportRow('Purchase', 'Billed value', _money(data['purchase_billed'], currencyCode), _healthDelta(data['previous_purchase_billed'], data['purchase_billed'])),
      _ReportRow('Production', 'Plan attainment', '${_planAttainment(data)}%', _planAttainment(data) >= 90 ? 'Healthy' : 'Watch'),
      _ReportRow('Quality', 'Inspection pass rate', '${_num(data['quality_pass_rate']).toStringAsFixed(1)}%', _num(data['quality_pass_rate']) >= 95 ? 'Healthy' : 'Watch'),
      _ReportRow('Sales', 'Customer receivable', _money(data['customer_due'], currencyCode), _num(data['customer_due']) > 0 ? 'Open' : 'Clear'),
      _ReportRow('Purchase', 'Supplier payable', _money(data['supplier_due'], currencyCode), _num(data['supplier_due']) > 0 ? 'Open' : 'Clear'),
      _ReportRow('Maintenance', 'Downtime', '${_number(data['maintenance_downtime_minutes'])} min', _num(data['maintenance_assets_down']) > 0 ? 'Attention' : 'Healthy'),
    ];
    final visible = expanded ? rows : rows.take(5).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(FactorySpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Report workspace',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const Text('Period metrics built from connected module records.'),
            const SizedBox(height: FactorySpacing.md),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Module')),
                  DataColumn(label: Text('Metric')),
                  DataColumn(label: Text('Value')),
                  DataColumn(label: Text('Status')),
                ],
                rows: visible
                    .map(
                      (row) => DataRow(
                        cells: [
                          DataCell(Text(row.module)),
                          DataCell(Text(row.metric)),
                          DataCell(Text(row.value)),
                          DataCell(_HealthChip(value: row.health)),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportRow {
  const _ReportRow(this.module, this.metric, this.value, this.health);
  final String module;
  final String metric;
  final String value;
  final String health;
}

class _HealthChip extends StatelessWidget {
  const _HealthChip({required this.value});
  final String value;
  @override
  Widget build(BuildContext context) => Chip(
        label: Text(value),
        visualDensity: VisualDensity.compact,
      );
}

class _ActivityPanel extends StatelessWidget {
  const _ActivityPanel({required this.rows});
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(FactorySpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recent activity',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const Text('Audited system events in the current scope.'),
              const SizedBox(height: FactorySpacing.sm),
              if (rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: FactorySpacing.xl),
                  child: Center(child: Text('No audited activity yet.')),
                )
              else
                for (final row in rows.take(8))
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      radius: 13,
                      child: Icon(Icons.history, size: 16),
                    ),
                    title: Text(
                      '${_title('${row['action'] ?? ''}')} ${_title('${row['entity_type'] ?? ''}')} ',
                    ),
                    subtitle: Text(
                      '${row['actor_name'] ?? 'System'} · ${_dateTime(row['occurred_at'])}',
                    ),
                  ),
            ],
          ),
        ),
      );
}

class _ReportError extends StatelessWidget {
  const _ReportError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => FactoryStatePanel(
        state: FactoryViewState.error,
        message: message,
        onRetry: onRetry,
      );
}

num _num(dynamic value) => value is num ? value : num.tryParse('$value') ?? 0;

num _sum(List<Map<String, dynamic>> rows, String key) =>
    rows.fold<num>(0, (sum, row) => sum + _num(row[key]));

String _number(dynamic value) {
  final n = _num(value);
  if (n == n.roundToDouble()) return _groupIndian(n.toInt().toString());
  return n.toStringAsFixed(2);
}

String _money(dynamic value, String currency) {
  final symbol = currency == 'INR' ? '₹' : '$currency ';
  final amount = _num(value).toDouble();
  final fixed = amount.toStringAsFixed(2).split('.');
  return '$symbol${_groupIndian(fixed.first)}.${fixed.last}';
}

String _groupIndian(String raw) {
  final negative = raw.startsWith('-');
  final digits = negative ? raw.substring(1) : raw;
  if (digits.length <= 3) return raw;
  final last3 = digits.substring(digits.length - 3);
  var prefix = digits.substring(0, digits.length - 3);
  final groups = <String>[];
  while (prefix.length > 2) {
    groups.insert(0, prefix.substring(prefix.length - 2));
    prefix = prefix.substring(0, prefix.length - 2);
  }
  if (prefix.isNotEmpty) groups.insert(0, prefix);
  final result = '${groups.join(',')},$last3';
  return negative ? '-$result' : result;
}

String _deltaText(dynamic current, dynamic previous) {
  final now = _num(current).toDouble();
  final before = _num(previous).toDouble();
  if (before == 0) return now == 0 ? 'No change vs previous period' : 'New activity this period';
  final pct = (now - before) / before * 100;
  final sign = pct >= 0 ? '↑' : '↓';
  return '$sign ${pct.abs().toStringAsFixed(1)}% vs previous period';
}

String _healthDelta(dynamic current, dynamic previous) =>
    _num(current) >= _num(previous) ? 'Healthy' : 'Watch';

double _planAttainment(Map<String, dynamic> data) {
  final planned = _num(data['production_planned']).toDouble();
  if (planned <= 0) return 0;
  return (_num(data['production_output']).toDouble() / planned * 100)
      .clamp(0, 999)
      .toDouble();
}

String _title(String value) => value
    .split('_')
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');

String _dateTime(dynamic value) {
  final parsed = DateTime.tryParse('$value');
  if (parsed == null) return '—';
  final local = parsed.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
}

String _isoDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

String _csvCell(String value) =>
    '"${value.replaceAll('"', '""').replaceAll('\n', ' ')}"';

String _errorText(Object error) {
  if (error is PostgrestException) return error.message;
  return '$error';
}
