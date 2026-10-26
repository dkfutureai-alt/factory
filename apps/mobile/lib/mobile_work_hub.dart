import 'package:factoryos_core/factoryos_core.dart';
import 'package:flutter/material.dart';

import 'main_phase11.dart' show MobileData;

/// A discoverable launcher for real, enabled workspaces. This deliberately does
/// not display invented task counts or promise unsupported operational actions.
class FactoryWorkHub extends StatefulWidget {
  const FactoryWorkHub({
    required this.data,
    required this.onOpenModule,
    super.key,
  });

  final MobileData data;
  final void Function(BuildContext context, AppModule module) onOpenModule;

  @override
  State<FactoryWorkHub> createState() => _FactoryWorkHubState();
}

abstract final class FactoryWorkHubPolicy {
  static const _supported = <String>{
    'hr', 'inventory', 'production', 'quality', 'warehouse',
    'purchase', 'sales', 'maintenance', 'reports',
    'notifications', 'delivery', 'vehicles',
  };

  static bool canLaunch(MobileData data, AppModule module) {
    if (!_supported.contains(module.key)) return false;
    if (!WorkspaceAccessPolicy.isMobileModuleVisible(data.role, module.key)) {
      return false;
    }
    if (module.key == 'delivery' &&
        !WorkspaceAccessPolicy.canExecuteDelivery(data.role)) {
      return false;
    }
    if (module.key == 'vehicles' &&
        !WorkspaceAccessPolicy.canExecuteFleet(data.role)) {
      return false;
    }
    return true;
  }

  static List<AppModule> available(MobileData data) {
    final result = data.modules
        .where((module) => canLaunch(data, module))
        .toList(growable: false);
    return [...result]..sort((a, b) =>
        a.sortOrder.compareTo(b.sortOrder) != 0
            ? a.sortOrder.compareTo(b.sortOrder)
            : a.name.compareTo(b.name));
  }

  static String group(String key) => switch (key) {
    'hr' => 'People',
    'reports' || 'notifications' => 'Insights & communication',
    _ => 'Factory operations',
  };
}

class _FactoryWorkHubState extends State<FactoryWorkHub> {
  String search = '';

  @override
  Widget build(BuildContext context) {
    final available = FactoryWorkHubPolicy.available(widget.data);
    final query = search.trim().toLowerCase();
    final filtered = available.where((module) =>
        query.isEmpty || module.name.toLowerCase().contains(query)
        || module.key.toLowerCase().contains(query)).toList();
    const groups = [
      'Factory operations', 'People', 'Insights & communication',
    ];

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
            children: [
              FactoryReveal(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Workspaces',
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 6),
                    const Text(
                      'Choose an available tool for your role.',
                      style: TextStyle(color: FactoryColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: FactorySpacing.lg),
              TextField(
                onChanged: (value) => setState(() => search = value),
                decoration: const InputDecoration(
                  hintText: 'Find a workspace',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: FactorySpacing.lg),
              if (filtered.isEmpty)
                _EmptyResult(isSearch: query.isNotEmpty)
              else
                for (final group in groups) ...[
                  if (filtered.any(
                    (module) => FactoryWorkHubPolicy.group(module.key) == group,
                  )) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12, top: 10),
                      child: Text(
                        group,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    LayoutBuilder(builder: (context, limits) {
                      const gap = 12.0;
                      final count = limits.maxWidth >= 820
                          ? 3
                          : limits.maxWidth >= 560 ? 2 : 1;
                      final tileWidth =
                          (limits.maxWidth - gap * (count - 1)) / count;
                      return Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: [
                          for (final module in filtered.where((module) =>
                              FactoryWorkHubPolicy.group(module.key) == group))
                            SizedBox(
                              width: tileWidth,
                              child: FactoryPressCard(
                                semanticLabel: 'Open ${module.name}',
                                onTap: () => widget.onOpenModule(context, module),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 15,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: FactoryColors.softBlue,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          _icon(module.key),
                                          color: FactoryColors.blue,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          module.name,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme.titleMedium,
                                        ),
                                      ),
                                      const Icon(Icons.chevron_right,
                                          color: FactoryColors.muted),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    }),
                    const SizedBox(height: FactorySpacing.md),
                  ],
                ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyResult extends StatelessWidget {
  const _EmptyResult({required this.isSearch});
  final bool isSearch;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 12),
        child: Column(
          children: [
            const Icon(Icons.grid_view_outlined,
                color: FactoryColors.muted, size: 40),
            const SizedBox(height: 12),
            Text(
              isSearch
                  ? 'No matching workspaces'
                  : 'No operational workspaces are available',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              isSearch
                  ? 'Try a different name.'
                  : 'Ask your administrator to check your assigned modules.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: FactoryColors.muted),
            ),
          ],
        ),
      );
}

IconData _icon(String key) => switch (key) {
  'hr' => Icons.groups_2_outlined,
  'production' => Icons.precision_manufacturing_outlined,
  'inventory' => Icons.inventory_2_outlined,
  'quality' => Icons.verified_outlined,
  'warehouse' => Icons.warehouse_outlined,
  'delivery' => Icons.route_outlined,
  'vehicles' => Icons.local_shipping_outlined,
  'maintenance' => Icons.build_circle_outlined,
  'purchase' || 'sales' || 'commercial' => Icons.receipt_long_outlined,
  'reports' => Icons.bar_chart_outlined,
  'notifications' => Icons.notifications_outlined,
  _ => Icons.widgets_outlined,
};
