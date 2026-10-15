import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/delivery_repository.dart';
import '../domain/delivery_models.dart';

class DeliveryDashboardPage extends StatelessWidget {
  const DeliveryDashboardPage({super.key, required this.repository});
  final DeliveryRepository repository;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Delivery Management', style: TextStyle(fontWeight: FontWeight.w800)), Text('Outbound deliveries, POD and customer exceptions', style: TextStyle(fontSize: 12, color: AppTheme.muted))])),
        body: FutureBuilder<DeliveryOverview>(
          future: repository.loadOverview(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (!snapshot.hasData) return const Center(child: Text('Unable to load deliveries.'));
            final data = snapshot.requireData;
            return ListView(padding: const EdgeInsets.all(24), children: [
              Wrap(spacing: 14, runSpacing: 14, children: [
                _Metric(label: 'Out for delivery', value: '${data.outForDelivery}', accent: AppTheme.brand),
                _Metric(label: 'Delivered today', value: '${data.deliveredToday}', accent: AppTheme.success),
                _Metric(label: 'POD pending', value: '${data.podPending}', accent: AppTheme.warning),
                _Metric(label: 'Exceptions', value: '${data.exceptions}', accent: AppTheme.danger),
              ]),
              const SizedBox(height: 18),
              LayoutBuilder(builder: (context, constraints) {
                final queue = Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Delivery queue', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  ...data.deliveries.map((delivery) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        onTap: () => Navigator.of(context).pushNamed(delivery.hasException ? '/delivery/exception' : '/delivery/detail'),
                        leading: const Icon(Icons.local_shipping_outlined, color: AppTheme.brand),
                        title: Text('${delivery.deliveryNumber} • ${delivery.customer}', style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text('${delivery.salesOrderNumber} • ${delivery.tripNumber} • ETA ${delivery.etaLabel}'),
                        trailing: Text(delivery.status, style: TextStyle(fontWeight: FontWeight.w800, color: _statusColor(delivery.status))),
                      )),
                ])));
                final alerts = Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Attention required', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  ...data.alerts.map((alert) => ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.warning_amber_outlined, color: _alertColor(alert.severity)), title: Text(alert.title, style: TextStyle(fontWeight: FontWeight.w800, color: _alertColor(alert.severity))), subtitle: Text(alert.detail))),
                ])));
                if (constraints.maxWidth > 900) return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 2, child: queue), const SizedBox(width: 16), Expanded(child: alerts)]);
                return Column(children: [queue, const SizedBox(height: 16), alerts]);
              }),
            ]);
          },
        ),
      );

  static Color _statusColor(String status) => switch (status) {
        'Delivered' => AppTheme.success,
        'Rejected qty' || 'Failed' => AppTheme.danger,
        'Arrived' => AppTheme.warning,
        _ => AppTheme.brand,
      };

  static Color _alertColor(DeliveryAlertSeverity severity) => switch (severity) {
        DeliveryAlertSeverity.info => AppTheme.brand,
        DeliveryAlertSeverity.warning => AppTheme.warning,
        DeliveryAlertSeverity.danger => AppTheme.danger,
      };
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.accent});
  final String label;
  final String value;
  final Color accent;
  @override
  Widget build(BuildContext context) => SizedBox(width: 245, height: 128, child: Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.muted)), const SizedBox(height: 8), Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: accent))]))));
}
