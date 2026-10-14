import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

String moneyLakhs(double value) => '₹${(value / 100000).toStringAsFixed(1)}L';
String percent(double value) => '${(value.clamp(0, 1) * 100).toStringAsFixed(1)}%';

class ReportPageHeader extends StatelessWidget {
  const ReportPageHeader({super.key, required this.title, required this.subtitle, this.actions = const []});
  final String title;
  final String subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppTheme.text)),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(color: AppTheme.muted)),
        ])),
        ...actions,
      ]);
}

class ReportMetricCard extends StatelessWidget {
  const ReportMetricCard({super.key, required this.label, required this.value, this.supporting = '', this.accent = AppTheme.brand});
  final String label;
  final String value;
  final String supporting;
  final Color accent;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 245,
        height: 126,
        child: Card(child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: accent)),
            if (supporting.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(supporting, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppTheme.muted)),
            ],
          ]),
        )),
      );
}

class ReportSection extends StatelessWidget {
  const ReportSection({super.key, required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          child,
        ]),
      ));
}

class RateBarRow extends StatelessWidget {
  const RateBarRow({super.key, required this.label, required this.rate});
  final String label;
  final double rate;

  @override
  Widget build(BuildContext context) {
    final safe = rate.clamp(0, 1).toDouble();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        SizedBox(width: 120, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
        Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: safe, minHeight: 12))),
        const SizedBox(width: 12),
        SizedBox(width: 54, child: Text(percent(safe), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700))),
      ]),
    );
  }
}
