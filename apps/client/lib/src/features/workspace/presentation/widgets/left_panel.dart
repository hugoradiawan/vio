import 'package:flutter/material.dart';
import 'package:vio_ui_kit/vio_ui_kit.dart';

/// Left panel containing layers tree and assets browser
class LeftPanel extends StatefulWidget {
  const LeftPanel({super.key});

  @override
  State<LeftPanel> createState() => _LeftPanelState();
}

class _LeftPanelState extends State<LeftPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: VioColors.surface1,
        border: Border(
          right: BorderSide(
            color: VioColors.border,
          ),
        ),
      ),
      child: Column(
        children: [
          // Tab bar
          Container(
            height: 40,
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: VioColors.border,
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: VioColors.textPrimary,
              unselectedLabelColor: VioColors.textTertiary,
              indicatorColor: VioColors.primary,
              labelStyle: VioTypography.body2,
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'Layers'),
                Tab(text: 'Assets'),
              ],
            ),
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _LayersTab(),
                _AssetsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LayersTab extends StatelessWidget {
  const _LayersTab();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Toolbar
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: VioSpacing.xs),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: VioColors.border,
              ),
            ),
          ),
          child: Row(
            children: [
              VioIconButton(
                icon: Icons.add,
                size: 28,
                tooltip: 'Add Component',
                onPressed: () {},
              ),
              VioIconButton(
                icon: Icons.folder_outlined,
                size: 28,
                tooltip: 'New Group',
                onPressed: () {},
              ),
              const Spacer(),
              VioIconButton(
                icon: Icons.search,
                size: 28,
                tooltip: 'Search',
                onPressed: () {},
              ),
            ],
          ),
        ),

        // Layers list (placeholder for now)
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.layers_outlined,
                  size: 48,
                  color: VioColors.textTertiary,
                ),
                const SizedBox(height: VioSpacing.sm),
                Text(
                  'No layers yet',
                  style: VioTypography.body2.copyWith(
                    color: VioColors.textTertiary,
                  ),
                ),
                const SizedBox(height: VioSpacing.xs),
                Text(
                  'Draw a shape to get started',
                  style: VioTypography.caption.copyWith(
                    color: VioColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AssetsTab extends StatelessWidget {
  const _AssetsTab();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Asset categories
        VioPanel(
          title: 'Components',
          child: _buildEmptyState(
            icon: Icons.widgets_outlined,
            message: 'No components',
          ),
        ),
        VioPanel(
          title: 'Graphics',
          child: _buildEmptyState(
            icon: Icons.image_outlined,
            message: 'No graphics',
          ),
        ),
        VioPanel(
          title: 'Colors',
          child: _buildEmptyState(
            icon: Icons.palette_outlined,
            message: 'No colors',
          ),
        ),
        VioPanel(
          title: 'Typographies',
          child: _buildEmptyState(
            icon: Icons.text_fields,
            message: 'No typographies',
          ),
        ),
        const Spacer(),
      ],
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
  }) {
    return Padding(
      padding: const EdgeInsets.all(VioSpacing.md),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: VioColors.textTertiary,
            ),
            const SizedBox(height: VioSpacing.xs),
            Text(
              message,
              style: VioTypography.caption.copyWith(
                color: VioColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
