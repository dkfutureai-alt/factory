import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/hr_repository.dart';
import '../domain/hr_models.dart';

class HolidayCalendarPage extends StatelessWidget {
  const HolidayCalendarPage({super.key, required this.repository});
  final HrRepository repository;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Holiday Calendar', style: TextStyle(fontWeight: FontWeight.w800)),
            Text('Company holidays, optional holidays and plant closures', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
          ]),
          actions: [Padding(padding: const EdgeInsets.only(right: 16), child: FilledButton.icon(onPressed: () {}, icon: const Icon(Icons.add), label: const Text('Add holiday')))],
        ),
        body: FutureBuilder<List<HolidaySummary>>(
          future: repository.loadHolidays(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (!snapshot.hasData) return const Center(child: Text('Unable to load holiday calendar.'));
            final holidays = snapshot.requireData;
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const _CalendarFilters(),
                const SizedBox(height: 18),
                LayoutBuilder(builder: (context, constraints) {
                  final month = _OctoberCalendar(holidays: holidays);
                  final upcoming = _UpcomingHolidayPanel(holidays: holidays);
                  if (constraints.maxWidth > 930) return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 2, child: month), const SizedBox(width: 16), Expanded(child: upcoming)]);
                  return Column(children: [month, const SizedBox(height: 16), upcoming]);
                }),
              ],
            );
          },
        ),
      );
}

class _CalendarFilters extends StatelessWidget {
  const _CalendarFilters();

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(spacing: 34, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
            const Text('Calendar year 2026', style: TextStyle(fontWeight: FontWeight.w800)),
            const Text('Maharashtra', style: TextStyle(color: AppTheme.muted)),
            const Text('All plants', style: TextStyle(color: AppTheme.muted)),
            const Text('12 holidays configured', style: TextStyle(color: AppTheme.muted)),
            TextButton(onPressed: () {}, child: const Text('Manage policy')),
          ]),
        ),
      );
}

class _OctoberCalendar extends StatelessWidget {
  const _OctoberCalendar({required this.holidays});
  final List<HolidaySummary> holidays;

  HolidaySummary? _holidayForDay(int day) {
    for (final holiday in holidays) {
      if (holiday.dateLabel.startsWith(day.toString().padLeft(2, '0')) || holiday.dateLabel.startsWith('$day ')) return holiday;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    const days = [28, 29, 30, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 1];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('October 2026', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 18),
          const Row(children: [for (final day in ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN']) Expanded(child: Text(day, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: AppTheme.muted, fontWeight: FontWeight.w800)))]),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 1.15),
            itemCount: days.length,
            itemBuilder: (context, index) {
              final day = days[index];
              final inOctober = index >= 3 && index <= 33;
              final holiday = inOctober ? _holidayForDay(day) : null;
              return Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: holiday == null ? Colors.transparent : (holiday.mandatory ? const Color(0xFFEAF8F0) : const Color(0xFFEAF1FF)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('$day', style: TextStyle(color: inOctober ? AppTheme.text : const Color(0xFF98A2B3), fontWeight: holiday == null ? FontWeight.w500 : FontWeight.w800)),
                  if (holiday != null) ...[const SizedBox(height: 4), Text(holiday.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: holiday.mandatory ? AppTheme.success : AppTheme.brand))],
                ]),
              );
            },
          ),
          const SizedBox(height: 14),
          const Text('Green = mandatory holiday • Blue = optional / local observance', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
          const SizedBox(height: 18),
          const Text('Next company holiday: 20 Oct 2026 • Diwali', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          const Text('Applies to Pune and Nashik plants • Paid holiday', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
        ]),
      ),
    );
  }
}

class _UpcomingHolidayPanel extends StatelessWidget {
  const _UpcomingHolidayPanel({required this.holidays});
  final List<HolidaySummary> holidays;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Upcoming holidays', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            ...holidays.take(4).map((holiday) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${holiday.dateLabel} • ${holiday.name}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('${holiday.mandatory ? 'Mandatory' : 'Optional'} • ${holiday.scopeLabel}${holiday.paid ? ' • Paid' : ''}'),
                )),
            const Divider(height: 30),
            const Text('Policy controls', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            const Text('• Paid / unpaid holiday type\n• Factory-specific applicability\n• Optional holiday quota\n• Half-day / shift overrides', style: TextStyle(color: AppTheme.muted, height: 1.8)),
            const SizedBox(height: 12),
            const Text('Holiday changes are audited', style: TextStyle(color: AppTheme.brand, fontWeight: FontWeight.w800)),
          ]),
        ),
      );
}
