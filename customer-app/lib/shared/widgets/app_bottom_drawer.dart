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

