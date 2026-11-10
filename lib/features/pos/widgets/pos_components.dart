import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:intl/intl.dart';

const posDashboardRoute = '/mobile-pos';
const posBlue = Color(0xff0759c7);
const posBackground = Color(0xfff4f6fa);
const posBorder = Color(0xffe0e8f2);
const posInk = Color(0xff14233b);
const posMuted = Color(0xff63758e);
ThemeData posWorkspaceTheme(ThemeData base) => base.copyWith(
      colorScheme:
          ColorScheme.fromSeed(seedColor: posBlue, brightness: Brightness.light)
              .copyWith(
                  surface: Colors.white,
                  surfaceTint: Colors.transparent,
                  onSurface: posInk,
                  primaryContainer: const Color(0xffe8f1fd),
                  onPrimaryContainer: posBlue,
                  secondaryContainer: const Color(0xffe8f1fd),
                  onSecondaryContainer: posBlue,
                  outline: posBorder,
                  outlineVariant: posBorder,
                  surfaceContainerHighest: const Color(0xffedf2f7)),
      scaffoldBackgroundColor: posBackground,
      canvasColor: Colors.white,
      textTheme: base.textTheme.apply(bodyColor: posInk, displayColor: posInk),
      popupMenuTheme: PopupMenuThemeData(
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 6,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: base.textTheme.bodyMedium?.copyWith(color: posInk)),
      dropdownMenuTheme: const DropdownMenuThemeData(
          menuStyle: MenuStyle(
              backgroundColor: WidgetStatePropertyAll(Colors.white),
              surfaceTintColor: WidgetStatePropertyAll(Colors.transparent))),
    );

String posTr(String key, [Map<String, String> args = const {}]) {
  var text = translate('pos.$key');
  args.forEach((key, value) => text = text.replaceAll('{$key}', value));
  return text;
}

String posMoney(num value, String symbol) =>
    NumberFormat.currency(symbol: symbol, decimalDigits: 2).format(value);
String posServiceLabel(String type) => translate('home_screen.service_$type');
String posModuleName(String type) => type == 'dashboard'
    ? posTr('dashboard')
    : type == 'sell'
        ? posTr('sales')
        : type == 'all'
            ? posTr('all_types')
            : translate('home_screen.service_$type');
IconData posModuleIcon(String type) => switch (type) {
      'dashboard' => Icons.home_outlined,
      'material' => Icons.inventory_2_outlined,
      'iron' => Icons.layers_outlined,
      'repair' => Icons.build_outlined,
      'buy_in' => Icons.add_box_outlined,
      'more' => Icons.more_horiz,
      'icloud_cus' => Icons.cloud_outlined,
      _ => Icons.shopping_cart_outlined,
    };
Color posModuleColor(String type) => switch (type) {
      'iron' => const Color(0xff7952cc),
      'repair' => const Color(0xff16885f),
      'buy_in' => const Color(0xffd38115),
      _ => posBlue,
    };

class PosPanel extends StatelessWidget {
  const PosPanel(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(12)});
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: posBorder),
            boxShadow: [
              BoxShadow(
                  color: posInk.withValues(alpha: .025),
                  blurRadius: 9,
                  offset: const Offset(0, 3))
            ]),
        child: child,
      );
}

class PosKpiCard extends StatelessWidget {
  const PosKpiCard(
      {super.key,
      required this.title,
      required this.value,
      required this.icon,
      required this.color});
  final String title, value;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => PosPanel(
      padding: const EdgeInsets.all(10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(7)),
              child: Icon(icon, color: color, size: 16)),
          const SizedBox(width: 7),
          Expanded(
              child: Text(title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11, color: posMuted, height: 1.2))),
        ]),
        const SizedBox(height: 7),
        FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: const TextStyle(
                    fontSize: 20, color: posInk, fontWeight: FontWeight.w800))),
      ]));
}

class PosStatusBadge extends StatelessWidget {
  const PosStatusBadge({super.key, required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final color = status == 'qualified'
        ? const Color(0xff16885f)
        : status == 'failed'
            ? const Color(0xffcf4353)
            : posMuted;
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
            color: color.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(7)),
        child: Text(posTr(status),
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w600, color: color)));
  }
}

class PosLoadingSkeleton extends StatelessWidget {
  const PosLoadingSkeleton({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
      label: posTr('loading'),
      child: Column(children: [
        const LinearProgressIndicator(minHeight: 2, color: posBlue),
        const SizedBox(height: 12),
        ...List.generate(
            3,
            (_) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                    children: List.generate(
                        2,
                        (i) => Expanded(
                            child: Container(
                                height: 76,
                                margin: EdgeInsets.only(left: i == 1 ? 8 : 0),
                                decoration: BoxDecoration(
                                    color: const Color(0xffe8eef6),
                                    borderRadius:
                                        BorderRadius.circular(12)))))))),
        Container(
            height: 140,
            decoration: BoxDecoration(
                color: const Color(0xffe8eef6),
                borderRadius: BorderRadius.circular(12))),
      ]));
}

class PosNavigation extends StatelessWidget {
  const PosNavigation(
      {super.key,
      required this.destination,
      required this.modules,
      required this.onSelect});
  final String destination;
  final List<String> modules;
  final ValueChanged<String> onSelect;
  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= 650;
        final destinations = [
          'dashboard',
          ...[
            'sell',
            'material',
            'iron',
            if (wide) ...['repair', 'buy_in']
          ].where(modules.contains),
          'more'
        ];
        return Container(
            decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: posBorder))),
            child: SafeArea(
                top: false,
                child: Row(
                    children: destinations.map((type) {
                  final selected = destination == type ||
                      (type == 'more' && !destinations.contains(destination));
                  return Expanded(
                      child: Semantics(
                          selected: selected,
                          button: true,
                          child: InkWell(
                            key: ValueKey('pos-nav-$type'),
                            onTap: () => onSelect(type),
                            child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 10, horizontal: 2),
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(posModuleIcon(type),
                                          color: selected ? posBlue : posMuted,
                                          size: 23),
                                      const SizedBox(height: 4),
                                      Text(
                                          type == 'more'
                                              ? posTr('more')
                                              : posModuleName(type),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: selected
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                              color: selected
                                                  ? posBlue
                                                  : posMuted)),
                                    ])),
                          )));
                }).toList())));
      });
}
