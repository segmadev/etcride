import 'package:flutter/material.dart';

Future<T?> showAppBottomDrawer<T>({
  required BuildContext context,
  required Widget child,
  double heightFactor = 0.92,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => FractionallySizedBox(
      heightFactor: heightFactor,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Material(color: Colors.white, child: child),
      ),
    ),
  );
}

/// A bottom sheet that behaves like a true bottom drawer: flush against the
/// screen edges (no floating margin), draggable, and collapsible so the user
/// can drag it down to reveal whatever is behind it (e.g. a map) without
/// fully dismissing it.
///
/// [builder] returns only the sheet's content — the drag handle, rounded
/// top corners, and scroll wiring are handled here.
Future<T?> showDraggableBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double initialChildSize = 0.5,
  double minChildSize = 0.18,
  double maxChildSize = 0.92,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: initialChildSize,
      minChildSize: minChildSize,
      maxChildSize: maxChildSize,
      expand: false,
      builder: (sheetContext, scrollController) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Material(
          color: Colors.white,
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.zero,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              builder(sheetContext),
              SizedBox(height: MediaQuery.of(sheetContext).padding.bottom + 8),
            ],
          ),
        ),
      ),
    ),
  );
}

/// A persistent (non-modal) draggable panel meant to sit at the bottom of a
/// Stack on top of a map — e.g. a driver-assigned/trip-in-progress card.
/// Unlike [showDraggableBottomSheet] this isn't pushed as a route; it's just
/// a widget you place directly in your Stack's children, so it stays
/// visible permanently and the user can drag it down to reveal the map
/// underneath instead of it physically covering the screen with a
/// fixed-height panel.
///
/// Place it inside `Stack(children: [Positioned.fill(child: map), ...])` —
/// it sizes itself relative to the nearest bounded ancestor.
class CollapsibleMapSheet extends StatelessWidget {
  const CollapsibleMapSheet({
    super.key,
    required this.child,
    this.initialChildSize = 0.5,
    this.minChildSize = 0.14,
    this.maxChildSize = 0.88,
    this.backgroundColor = Colors.white,
  });

  final Widget child;
  final double initialChildSize;
  final double minChildSize;
  final double maxChildSize;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: initialChildSize,
      minChildSize: minChildSize,
      maxChildSize: maxChildSize,
      snap: true,
      snapSizes: [minChildSize, initialChildSize, maxChildSize],
      builder: (sheetContext, scrollController) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: Material(
            color: backgroundColor,
            child: ListView(
              controller: scrollController,
              padding: EdgeInsets.zero,
              children: [
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E0E0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                child,
                SizedBox(height: MediaQuery.of(sheetContext).padding.bottom + 16),
              ],
            ),
          ),
        );
      },
    );
  }
}

