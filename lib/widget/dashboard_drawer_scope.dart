import 'package:flutter/material.dart';

class DashboardDrawerScope extends InheritedWidget {
  const DashboardDrawerScope({
    super.key,
    required this.openDrawer,
    required super.child,
  });

  final VoidCallback openDrawer;

  static DashboardDrawerScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<DashboardDrawerScope>();
  }

  @override
  bool updateShouldNotify(DashboardDrawerScope oldWidget) =>
      openDrawer != oldWidget.openDrawer;
}
