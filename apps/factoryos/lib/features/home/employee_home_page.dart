import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class EmployeeHomePage extends StatelessWidget {
  const EmployeeHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Good morning, Ravi', style: TextStyle(fontWeight: FontWeight.w800)),
          Text('Production • Morning Shift', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
        ]),
        actions: [IconButton(tooltip: 'Notifications', onPressed: () => Navigator.of(context).pushNamed('/notifications/employee'), icon: const Icon(Icons.notifications_none))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [
                  Expanded(child: Text('Attendance', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
                  _StatusChip(label: 'Checked in'),
                ]),
                const SizedBox(height: 18),
                const Text('09:01 AM', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppTheme.text)),
                const SizedBox(height: 4),
                const Text('Shift 09:00 AM – 06:00 PM', style: TextStyle(color: AppTheme.muted)),
                const SizedBox(height: 16),
                SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.logout), label: const Text('Check out'))),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Quick actions', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.45,
            children: [
              _QuickAction(icon: Icons.qr_code_scanner, label: 'Scan', subtitle: 'Material / item', onTap: () => Navigator.of(context).pushNamed('/scanner')),
              const _QuickAction(icon: Icons.assignment_outlined, label: 'My tasks', subtitle: '3 assigned'),
              _QuickAction(icon: Icons.precision_manufacturing_outlined, label: 'Production', subtitle: 'LINE-02', onTap: () => Navigator.of(context).pushNamed('/production')),
              const _QuickAction(icon: Icons.beach_access_outlined, label: 'Leave', subtitle: 'Apply / status'),
            ],
          ),
          const SizedBox(height: 20),
          const Text('Today', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          const _TaskTile(title: 'PRD-2026-01038', subtitle: 'Industrial Component X • LINE-02', trailing: 'In progress'),
          const _TaskTile(title: 'Safety inspection', subtitle: 'Workstation checklist • before 2:00 PM', trailing: 'Pending'),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.assignment_outlined), label: 'Tasks'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.subtitle, this.onTap});
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, color: AppTheme.brand),
              const SizedBox(height: 10),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
            ]),
          ),
        ),
      );
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.title, required this.subtitle, required this.trailing});
  final String title;
  final String subtitle;
  final String trailing;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(subtitle),
          trailing: Text(trailing, style: const TextStyle(color: AppTheme.brand, fontSize: 12, fontWeight: FontWeight.w700)),
        ),
      );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: const Color(0xFFECFDF3), borderRadius: BorderRadius.circular(999)),
        child: Text(label, style: const TextStyle(color: AppTheme.success, fontSize: 11, fontWeight: FontWeight.w700)),
      );
}
