import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../data/maintenance_repository.dart';
import '../domain/maintenance_models.dart';
import 'maintenance_work_order_page.dart';

class MaintenanceAssetPage extends StatelessWidget {
  const MaintenanceAssetPage({super.key, required this.repository, required this.code});
  final MaintenanceRepository repository;
  final String code;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Asset Detail', style: TextStyle(fontWeight: FontWeight.w800))),
    body: FutureBuilder<MaintenanceAssetDetail>(
      future: repository.loadAsset(code),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError || !snapshot.hasData) return const Center(child: Text('Unable to load asset.'));
        final asset = snapshot.requireData;
        return ListView(padding: const EdgeInsets.all(24), children: [
          Text('${asset.name} • ${asset.code}', style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(asset.location, style: const TextStyle(color: AppTheme.muted)),
          const SizedBox(height: 18),
          Wrap(spacing: 16, runSpacing: 16, children: [
            SizedBox(width: 550, child: Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Asset information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              _Info('Status', asset.status),
              _Info('Serial', asset.serialNumber),
              _Info('Operating hours', '${asset.operatingHours} h'),
              _Info('Location', asset.location),
            ])))),
            SizedBox(width: 400, child: Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Service readiness', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              _Info('Last service', asset.lastService),
              _Info('Next service', asset.nextService),
            ])))),
          ]),
          const SizedBox(height: 18),
          Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Maintenance history', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ...asset.history.map((entry) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${entry.number} • ${entry.description}', style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(entry.status),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => MaintenanceWorkOrderPage(repository: repository, number: entry.number))),
            )),
            const Text('Spare consumption is tracked through posted Inventory ledger entries.', style: TextStyle(color: AppTheme.muted)),
          ]))),
        ]);
      },
    ),
  );
}

class _Info extends StatelessWidget {
  const _Info(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 14), child: Row(children: [
    SizedBox(width: 135, child: Text(label, style: const TextStyle(color: AppTheme.muted))),
    Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700))),
  ]));
}
