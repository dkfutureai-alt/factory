import 'package:factoryos_core/factoryos_core.dart';
import 'package:flutter/material.dart';

import 'main_phase11.dart' show MobileData;
import 'mobile_work_hub.dart' show FactoryWorkHubPolicy;

typedef FactoryModuleOpener = void Function(
  BuildContext context,
  AppModule module,
);

/// Role-aware home. Everything shown comes from the real bootstrap response.
class FactoryHomeDashboard extends StatelessWidget {
  const FactoryHomeDashboard({
    required this.data,
    required this.onOpenModule,
    super.key,
  });

  final MobileData data;
  final FactoryModuleOpener onOpenModule;

  @override
  Widget build(BuildContext context) {
    final launchable = FactoryWorkHubPolicy.available(data);
    return SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final horizontal = constraints.maxWidth >= 720 ? 32.0 : 20.0;
                return ListView(
                  padding: EdgeInsets.fromLTRB(
                    horizontal,
                    FactorySpacing.lg,
                    horizontal,
                    FactorySpacing.xl + 12,
                  ),
                  children: [
                    FactoryReveal(child: _WorkspaceHero(data: data, workspaceCount: launchable.length)),
                    const SizedBox(height: FactorySpacing.md),
                    _FactoryAssignment(factories: data.factories),
                    const SizedBox(height: FactorySpacing.xl),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Your workspaces',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        Text(
                          '${launchable.length} available',
                          style: const TextStyle(
                            color: FactoryColors.muted,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Tools enabled for your assigned role',
                      style: TextStyle(color: FactoryColors.muted),
                    ),
                    const SizedBox(height: FactorySpacing.md),
                    LayoutBuilder(
                      builder: (context, grid) {
                        const gap = FactorySpacing.sm;
                        final columns = grid.maxWidth >= 850
                            ? 4
                            : grid.maxWidth >= 520
                                ? 3
                                : 2;
                        final tileWidth =
                            (grid.maxWidth - (columns - 1) * gap) / columns;
                        return Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: [
                            for (final module in launchable)
                              SizedBox(
                                width: tileWidth,
                                child: _ModuleTile(
                                  module: module,
                                  onTap: () => onOpenModule(context, module),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    if (launchable.isEmpty) ...[
                      const SizedBox(height: FactorySpacing.md),
                      const _EmptyWorkspace(),
                    ],
                    const SizedBox(height: FactorySpacing.lg),
                  ],
                );
              },
            ),
          ),
        ),
      );
  }
}

class _WorkspaceHero extends StatelessWidget {
  const _WorkspaceHero({required this.data, required this.workspaceCount});
  final MobileData data;
  final int workspaceCount;

  @override
  Widget build(BuildContext context) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: [Color(0xFF163D60), FactoryColors.navy],
          ),
          borderRadius: BorderRadius.circular(FactoryRadius.lg + 8),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1C102A43),
              blurRadius: 22,
              offset: Offset(0, 9),
            ),
          ],
        ),
        child: Stack(
          children: [
            PositionedDirectional(
              end: -64,
              top: -64,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0x26FFFFFF),
                    width: 34,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(FactorySpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.factory_outlined,
                        color: Colors.white,
                        size: 22,
                      ),
                      const SizedBox(width: FactorySpacing.xs),
                      const Flexible(
                        flex: 2,
                        child: Text(
                          'FACTORYOS',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Color(0xFFD7E9FF),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: FactorySpacing.xs),
                      Flexible(
                        flex: 3,
                        child: Text(
                          data.role.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: const TextStyle(
                            color: Color(0xFFD7E9FF),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: FactorySpacing.xl),
                  const Text(
                    'Your factory, connected.',
                    style: TextStyle(
                      color: Color(0xFFD7E9FF),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: FactorySpacing.xxs),
                  Text(
                    data.organizationName,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontSize: 27,
                          height: 1.15,
                        ),
                  ),
                  const SizedBox(height: FactorySpacing.lg),
                  Wrap(
                    spacing: FactorySpacing.xs,
                    runSpacing: FactorySpacing.xs,
                    children: [
                      _HeroPill(
                        icon: Icons.apps_outlined,
                        label: '$workspaceCount ${workspaceCount == 1 ? 'workspace' : 'workspaces'}',
                      ),
                      _HeroPill(
                        icon: Icons.location_on_outlined,
                        label: '${data.factories.length} factories',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0x24FFFFFF),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 15),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
}

class _FactoryAssignment extends StatelessWidget {
  const _FactoryAssignment({required this.factories});
  final List<Map<String, dynamic>> factories;

  @override
  Widget build(BuildContext context) {
    final primary = factories.isEmpty ? null : factories.first;
    final location = primary == null
        ? ''
        : [
            primary['code'],
            primary['city'],
            primary['state'],
          ].whereType<String>().where((part) => part.trim().isNotEmpty).join(' · ');
    return Container(
      padding: const EdgeInsets.all(FactorySpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(FactoryRadius.lg),
        border: Border.all(color: FactoryColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: FactoryColors.softBlue,
              borderRadius: BorderRadius.circular(FactoryRadius.md),
            ),
            child: const Icon(
              Icons.location_on_outlined,
              color: FactoryColors.blue,
            ),
          ),
          const SizedBox(width: FactorySpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PRIMARY FACTORY',
                  style: TextStyle(
                    color: FactoryColors.muted,
                    fontSize: 10,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  primary?['name'] as String? ?? 'No factory assigned',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (location.isNotEmpty)
                  Text(
                    location,
                    style: const TextStyle(
                      color: FactoryColors.muted,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({required this.module, required this.onTap});
  final AppModule module;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = switch (module.key) {
      'hr' => Icons.groups_2_outlined,
      'inventory' => Icons.inventory_2_outlined,
      'production' => Icons.precision_manufacturing_outlined,
      'quality' => Icons.verified_outlined,
      'warehouse' => Icons.warehouse_outlined,
      'vehicles' => Icons.local_shipping_outlined,
      'delivery' => Icons.route_outlined,
      'maintenance' => Icons.build_outlined,
      'purchase' || 'sales' => Icons.receipt_long_outlined,
      'reports' => Icons.insights_outlined,
      'notifications' => Icons.notifications_outlined,
      'dashboard' => Icons.dashboard_outlined,
      _ => Icons.grid_view_outlined,
    };

    return FactoryPressCard(
      semanticLabel: 'Open ${module.name}',
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 153),
        child: Padding(
          padding: const EdgeInsets.all(FactorySpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: FactoryColors.softBlue,
                      borderRadius: BorderRadius.circular(FactoryRadius.md),
                    ),
                    child: Icon(icon, color: FactoryColors.blue, size: 23),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.north_east_rounded,
                    size: 16,
                    color: FactoryColors.muted,
                  ),
                ],
              ),
              const SizedBox(height: FactorySpacing.lg),
              Text(
                module.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 13,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyWorkspace extends StatelessWidget {
  const _EmptyWorkspace();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(FactorySpacing.lg),
        child: Column(
          children: [
            Icon(Icons.lock_outline, color: FactoryColors.muted, size: 34),
            SizedBox(height: FactorySpacing.sm),
            Text(
              'No modules are enabled for this role.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
}
