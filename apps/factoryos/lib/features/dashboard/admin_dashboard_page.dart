import 'package:flutter/material.dart';

import '../../core/data/dashboard_repository.dart';
import '../../core/models/dashboard_snapshot.dart';
import '../../core/theme/app_theme.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key, required this.repository});
  final DashboardRepository repository;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Row(
          children: [
            const _Sidebar(),
            Expanded(
              child: FutureBuilder<DashboardSnapshot>(
                future: repository.loadOverview(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError || !snapshot.hasData) {
                    return const _DashboardError();
                  }
                  return _DashboardBody(data: snapshot.requireData);
                },
              ),
            ),
          ],
        ),
      );
}

class _Sidebar extends StatelessWidget {
  const _Sidebar();

  static const sections = [
    'Dashboard',
    'Inventory',
    'Purchase',
    'Production',
    'Quality',
    'Warehouse',
    'Dispatch',
    'Transport',
    'HR',
    'Maintenance',
    'Reports',
  ];

  String? _routeFor(String section) => switch (section) {
        'Inventory' => '/inventory',
        'Purchase' => '/purchase',
        'Production' => '/production',
        'Warehouse' => '/warehouse',
        'Dispatch' => '/dispatch',
        'HR' => '/hr',
        _ => null,
      };

  @override
  Widget build(BuildContext context) => Container(
        width: 236,
        color: AppTheme.navInk,
        padding: const EdgeInsets.fromLTRB(16, 28, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('FACTORYOS', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 8, 12, 20),
              child: Text('DK Industrial Manufacturing', style: TextStyle(color: Color(0xFF98A2B3), fontSize: 12)),
            ),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: sections.length,
                itemBuilder: (context, index) {
                  final section = sections[index];
                  final route = _routeFor(section);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: route == null ? null : () => Navigator.of(context).pushNamed(route),
                      child: Container(
                        height: 42,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.centerLeft,
                        decoration: BoxDecoration(
                          color: section == 'Dashboard' ? const Color(0xFF23477E) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                section,
                                style: TextStyle(
                                  color: section == 'Dashboard' ? Colors.white : const Color(0xFFD0D5DD),
                                  fontWeight: section == 'Dashboard' ? FontWeight.w700 : FontWeight.w500,
                                ),
                              ),
                            ),
                            if (route != null) const Icon(Icons.chevron_right, size: 16, color: Color(0xFF98A2B3)),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const Divider(color: Color(0xFF344054)),
            const ListTile(
              dense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8),
              leading: CircleAvatar(radius: 17, child: Text('AK')),
              title: Text('Amit Kulkarni', style: TextStyle(color: Colors.white, fontSize: 13)),
              subtitle: Text('Factory Manager', style: TextStyle(color: Color(0xFF98A2B3), fontSize: 11)),
            ),
          ],
        ),
      );
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.data});
  final DashboardSnapshot data;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final crossAxisCount = width > 1180 ? 4 : 2;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Operations overview', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppTheme.text)),
                    SizedBox(height: 6),
                    Text('Main Manufacturing Plant • Today', style: TextStyle(color: AppTheme.muted)),
                  ],
                ),
              ),
              OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.tune), label: const Text('Filters')),
            ],
          ),
          const SizedBox(height: 24),
          GridView.count(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 2.2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _KpiCard(label: 'Production today', value: '${data.productionCompleted} / ${data.productionPlanned}', supporting: '${(data.productionAchievement * 100).toStringAsFixed(1)}% achievement'),
              _KpiCard(label: 'Employees present', value: '${data.employeesPresent}', supporting: 'active attendance records'),
              _KpiCard(label: 'Low stock', value: '${data.lowStockCount}', supporting: 'at / below reorder level', accent: AppTheme.warning),
              _KpiCard(label: 'Vehicles active', value: '${data.activeVehicles}', supporting: '${data.pendingApprovals} approvals pending'),
            ],
          ),
          const SizedBox(height: 20),
          const Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _Panel(
                title: 'Production status',
                width: 560,
                children: [
                  _StatusRow(title: 'PRD-2026-01038', subtitle: 'Industrial Component X • LINE-02', status: 'In Production'),
                  _StatusRow(title: 'PRD-2026-01039', subtitle: 'Valve Assembly 25mm • LINE-01', status: 'QC Pending'),
                  _StatusRow(title: 'PRD-2026-01040', subtitle: 'Bracket Set A • LINE-03', status: 'Material Pending'),
                ],
              ),
              _Panel(
                title: 'Attention required',
                width: 420,
                children: [
                  _StatusRow(title: '12 low-stock items', subtitle: 'Warehouse action required', status: 'Review'),
                  _StatusRow(title: 'QC-2026-00418', subtitle: '8 units on hold', status: 'Hold'),
                  _StatusRow(title: '5 approvals', subtitle: 'Purchase, leave and adjustments', status: 'Pending'),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.label, required this.value, required this.supporting, this.accent = AppTheme.brand});
  final String label;
  final String value;
  final String supporting;
  final Color accent;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label, style: const TextStyle(color: AppTheme.muted, fontSize: 13)),
              const SizedBox(height: 8),
              Text(value, style: TextStyle(color: accent, fontSize: 25, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(supporting, style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
            ],
          ),
        ),
      );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.width, required this.children});
  final String title;
  final double width;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.text)),
                const SizedBox(height: 12),
                ...children,
              ],
            ),
          ),
        ),
      );
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.title, required this.subtitle, required this.status});
  final String title;
  final String subtitle;
  final String status;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.text)),
                  const SizedBox(height: 3),
                  Text(subtitle, style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: const Color(0xFFE7EEFF), borderRadius: BorderRadius.circular(999)),
              child: Text(status, style: const TextStyle(color: AppTheme.brand, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
}

class _DashboardError extends StatelessWidget {
  const _DashboardError();

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40, color: AppTheme.danger),
            const SizedBox(height: 12),
            const Text('Unable to load dashboard data.'),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: () {}, child: const Text('Retry')),
          ],
        ),
      );
}
