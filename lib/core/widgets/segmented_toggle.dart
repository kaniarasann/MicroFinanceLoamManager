import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// One option of a [SegmentedToggle].
class ToggleSegment<T> {
  const ToggleSegment({required this.value, required this.label});

  final T value;
  final String label;
}

/// Pill segmented control: `primarySubtle` track, selected segment white
/// with navy text. Track + segment = 48dp touch height.
class SegmentedToggle<T> extends StatelessWidget {
  const SegmentedToggle({
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.expand = false,
    super.key,
  });

  final List<ToggleSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  /// Stretch segments to fill the available width.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      for (final segment in segments)
        _wrap(
          _Segment(
            label: segment.label,
            selected: segment.value == selected,
            onTap: () => onChanged(segment.value),
          ),
        ),
    ];
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.primarySubtle,
        borderRadius: AppRadii.fullAll,
      ),
      child: Padding(
        padding: AppInsets.segmentTrack,
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }

  Widget _wrap(Widget child) => expand ? Expanded(child: child) : child;
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: selected ? AppColors.surface : AppColors.transparent,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppSizes.segmentHeight,
            ),
            child: Padding(
              padding: AppInsets.segment,
              child: Center(
                widthFactor: 1,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelLgTabular.copyWith(
                    color: selected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
