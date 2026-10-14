import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class DriverHomePage extends StatelessWidget {
  const DriverHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Driver home', style: TextStyle(fontWeight: FontWeight.w800)),
          Text('Rahul Jadhav • MH 13 DK 4521', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
        ]),
        actions: [IconButton(tooltip: 'Notifications', onPressed: () => Navigator.of(context).pushNamed('/notifications/driver'), icon: const Icon(Icons.notifications_none))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Today’s duty', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                const Row(children: [
                  Icon(Icons.local_shipping_outlined, color: AppTheme.brand),
                  SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('MH 13 DK 4521', style: TextStyle(fontWeight: FontWeight.w800)),
                    Text('Medium truck • 4.5T capacity', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
                  ])),
                  _DutyChip(),
                ]),
                const SizedBox(height: 16),
                SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () {}, icon: const Icon(Icons.play_arrow), label: const Text('Start duty'))),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Today’s trips', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          _TripCard(
            trip: 'TRIP-2026-00814',
            route: 'Plant → CityCare Hospital',
            time: '10:30 AM',
            status: 'Ready',
            onTap: () => Navigator.of(context).pushNamed('/fleet/trips'),
          ),
          _TripCard(
            trip: 'TRIP-2026-00815',
            route: 'CityCare → Metro Engineering',
            time: '01:30 PM',
            status: 'Planned',
            onTap: () => Navigator.of(context).pushNamed('/fleet/trips'),
          ),
          const SizedBox(height: 18),
          const Text('Quick actions', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.15,
            children: [
              const _DriverAction(icon: Icons.fact_check_outlined, title: 'Inspection', subtitle: 'Vehicle checklist'),
              _DriverAction(icon: Icons.local_gas_station_outlined, title: 'Fuel entry', subtitle: 'Odometer + receipt', onTap: () => Navigator.of(context).pushNamed('/fleet/fuel')),
              _DriverAction(icon: Icons.inventory_2_outlined, title: 'Deliveries', subtitle: '2 assigned', onTap: () => Navigator.of(context).pushNamed('/delivery/driver')),
              const _DriverAction(icon: Icons.warning_amber_outlined, title: 'Breakdown', subtitle: 'Report issue'),
            ],
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (index) {
          if (index == 1) Navigator.of(context).pushNamed('/fleet/trips');
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.route_outlined), label: 'Trips'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip, required this.route, required this.time, required this.status, required this.onTap});
  final String trip;
  final String route;
  final String time;
  final String status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: const Color(0xFFE7EEFF), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.route, color: AppTheme.brand),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(trip, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(route, style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
                const SizedBox(height: 3),
                Text(time, style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
              ])),
              Text(status, style: const TextStyle(color: AppTheme.brand, fontWeight: FontWeight.w700, fontSize: 12)),
            ]),
          ),
        ),
      );
}

class _DriverAction extends StatelessWidget {
  const _DriverAction({required this.icon, required this.title, required this.subtitle, this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, color: AppTheme.brand),
              const SizedBox(height: 10),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(subtitle, style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
            ]),
          ),
        ),
      );
}

class _DutyChip extends StatelessWidget {
  const _DutyChip();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(999)),
        child: const Text('Not started', style: TextStyle(color: AppTheme.warning, fontSize: 11, fontWeight: FontWeight.w700)),
      );
}
