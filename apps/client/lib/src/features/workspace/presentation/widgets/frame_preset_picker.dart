import 'package:flutter/material.dart';
import 'package:vio_ui_kit/vio_ui_kit.dart';

import '../../../canvas/models/frame_presets.dart';

class FramePresetPicker extends StatefulWidget {
  const FramePresetPicker({
    required this.value,
    required this.onChanged,
    this.includeNoneOption = true,
    this.noneLabel = 'Custom',
    this.categoryLabel = 'Category',
    this.presetLabel = 'Preset',
    super.key,
  });

  final String? value;
  final ValueChanged<String?> onChanged;

  final bool includeNoneOption;
  final String noneLabel;
  final String categoryLabel;
  final String presetLabel;

  @override
  State<FramePresetPicker> createState() => _FramePresetPickerState();
}

class _FramePresetPickerState extends State<FramePresetPicker> {
  late String _categoryName;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _categoryName =
        _categoryForPreset(widget.value) ?? framePresetCategories.first.name;
  }

  @override
  void didUpdateWidget(covariant FramePresetPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _categoryName = _categoryForPreset(widget.value) ?? _categoryName;
      if (!framePresetCategories.any((c) => c.name == _categoryName)) {
        _categoryName = framePresetCategories.first.name;
      }
    }
  }

  String? _categoryForPreset(String? presetId) {
    if (presetId == null) return null;
    for (final category in framePresetCategories) {
      if (category.items.any((e) => e.id == presetId)) {
        return category.name;
      }
    }
    return null;
  }

  FramePresetCategory get _category => framePresetCategories.firstWhere(
        (c) => c.name == _categoryName,
        orElse: () => framePresetCategories.first,
      );

  @override
  Widget build(BuildContext context) {
    final categoryItems =
        framePresetCategories.map((c) => c.name).toList(growable: false);

    // Ensure each value appears at most once (DropdownButton asserts otherwise).
    final presetItems = <String?>{
      if (widget.includeNoneOption) null,
      ..._category.items.map((p) => p.id),
    }.toList(growable: false);

    final effectivePresetValue = presetItems.contains(widget.value)
        ? widget.value
        : (widget.includeNoneOption
            ? null
            : (presetItems.isNotEmpty ? presetItems.first : null));

    String presetLabel(String? id) {
      if (id == null) return widget.noneLabel;
      final preset = framePresetById(id);
      if (preset == null) return id;
      return '${preset.name}  ${preset.sizeLabel}';
    }

    return Padding(
      padding: const EdgeInsets.all(VioSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LabeledDropdown<String>(
            label: widget.categoryLabel,
            value: _categoryName,
            items: categoryItems,
            itemLabel: (value) => value,
            onChanged: (value) {
              setState(() {
                _categoryName = value;
              });
            },
          ),
          const SizedBox(height: VioSpacing.sm),
          _LabeledDropdownNullable<String>(
            label: widget.presetLabel,
            value: effectivePresetValue,
            items: presetItems,
            itemLabel: presetLabel,
            onChanged: widget.onChanged,
          ),
        ],
      ),
    );
  }
}

class _LabeledDropdown<T> extends StatelessWidget {
  const _LabeledDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> items;
  final String Function(T) itemLabel;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final labels = items.map(itemLabel).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: VioTypography.caption.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: VioSpacing.sm),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(VioSpacing.radiusSm),
            border: Border.all(color: cs.outline),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isDense: true,
              isExpanded: true,
              style: VioTypography.caption.copyWith(
                color: cs.onSurface,
              ),
              dropdownColor: cs.surfaceContainerHigh,
              selectedItemBuilder: (context) => labels
                  .map(
                    (label) => Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(growable: false),
              items: items
                  .map(
                    (item) => DropdownMenuItem<T>(
                      value: item,
                      child: Text(
                        itemLabel(item),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (next) {
                if (next != null) {
                  onChanged(next);
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _LabeledDropdownNullable<T> extends StatelessWidget {
  const _LabeledDropdownNullable({
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  final String label;
  final T? value;
  final List<T?> items;
  final String Function(T?) itemLabel;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final labels = items.map(itemLabel).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: VioTypography.caption.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: VioSpacing.sm),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(VioSpacing.radiusSm),
            border: Border.all(color: cs.outline),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T?>(
              value: value,
              isDense: true,
              isExpanded: true,
              style: VioTypography.caption.copyWith(
                color: cs.onSurface,
              ),
              dropdownColor: cs.surfaceContainerHigh,
              selectedItemBuilder: (context) => labels
                  .map(
                    (label) => Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(growable: false),
              items: items
                  .map(
                    (item) => DropdownMenuItem<T?>(
                      value: item,
                      child: Text(
                        itemLabel(item),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
