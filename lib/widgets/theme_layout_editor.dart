import 'package:cnattendance/provider/dashboardprovider.dart';
import 'package:cnattendance/theme/app_theme_data.dart';
import 'package:cnattendance/theme/app_theme_mode.dart';
import 'package:cnattendance/theme/theme_layout.dart';
import 'package:cnattendance/theme/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ThemeLayoutEditor extends StatefulWidget {
  const ThemeLayoutEditor({super.key});

  @override
  State<ThemeLayoutEditor> createState() => _ThemeLayoutEditorState();
}

class _ThemeLayoutEditorState extends State<ThemeLayoutEditor> {
  late final AppThemeMode _mode;
  late ThemeLayout _draft;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<ThemeProvider>();
    _mode = provider.mode;
    _draft = provider.layout;
  }

  Future<void> _save() async {
    final provider = context.read<ThemeProvider>();
    setState(() => _saving = true);
    var saved = false;
    try {
      saved = await provider.saveLayout(_mode, _draft);
    } catch (_) {
      // Keep the draft open so a failed local write can be retried.
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Layout could not be saved. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = AppThemeData.info(_mode);
    final colors = _draft.colorsFor(info.colors);
    final features = context.watch<DashboardProvider?>()?.features ??
        const <String, String>{};
    final baseTheme = Theme.of(context);
    final ambientText = ThemeData.estimateBrightnessForColor(
                baseTheme.scaffoldBackgroundColor) ==
            Brightness.dark
        ? Colors.white
        : const Color(0xFF211720);
    final ambientTheme = baseTheme.copyWith(
      textTheme: baseTheme.textTheme
          .apply(bodyColor: ambientText, displayColor: ambientText),
      colorScheme: baseTheme.colorScheme.copyWith(
        onSurface: ambientText,
        onSurfaceVariant: ambientText,
      ),
    );

    return DefaultTabController(
      length: LayoutArea.values.length + 1,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Customize layout'),
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              for (final area in LayoutArea.values) Tab(text: area.label),
              const Tab(text: 'Colors & placement'),
            ],
          ),
        ),
        body: Theme(
          data: ambientTheme,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(info.name,
                      style: ambientTheme.textTheme.titleMedium),
                ),
              ),
              Expanded(
                child: IgnorePointer(
                  ignoring: _saving,
                  child: TabBarView(
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      for (final area in LayoutArea.values)
                        _itemList(area, features),
                      ListView(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                        children: [
                          Semantics(
                            label: 'Color preview',
                            child: Container(
                              height: 70,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                    colors: colors.gradientColors),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: colors.accentColor),
                              ),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Icon(Icons.dashboard_outlined,
                                    color: colors.accentColor),
                              ),
                            ),
                          ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                                backgroundColor: colors.backgroundColor),
                            title: const Text('Background color'),
                            trailing: const Icon(Icons.edit_outlined),
                            onTap: () async {
                              final selected = await _pickColor(
                                  'Background color', colors.backgroundColor);
                              if (!mounted || selected == null) return;
                              setState(() => _draft = _draft.setColors(
                                  background: selected, accent: _draft.accent));
                            },
                          ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                                backgroundColor: colors.accentColor),
                            title: const Text('Accent color'),
                            trailing: const Icon(Icons.edit_outlined),
                            onTap: () async {
                              final selected = await _pickColor(
                                  'Accent color', colors.accentColor);
                              if (!mounted || selected == null) return;
                              setState(() => _draft = _draft.setColors(
                                  background: _draft.background,
                                  accent: selected));
                            },
                          ),
                          if (_draft.background != null ||
                              _draft.accent != null)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                onPressed: () => setState(() {
                                  _draft = _draft.setColors(
                                      background: null, accent: null);
                                }),
                                child: const Text('Use theme colors'),
                              ),
                            ),
                          if (_mode != AppThemeMode.royalBlueGold &&
                              _mode != AppThemeMode.royalBlueDay &&
                              _mode != AppThemeMode.royalBlueGoldKhmerDay)
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                  'Separate banner, quote and clock'),
                              value: _draft.separatesBanner(_mode),
                              onChanged: (value) => setState(() {
                                _draft = _draft.setSeparateBanner(value);
                              }),
                            ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Show side menu button'),
                            value: _draft.showMenuButton,
                            onChanged: (value) => setState(() {
                              _draft = _draft.setShowMenuButton(value);
                            }),
                          ),
                          const SizedBox(height: 10),
                          Text('Side menu position',
                              style: ambientTheme.textTheme.titleMedium),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: SegmentedButton<bool>(
                              segments: const [
                                ButtonSegment(
                                    value: false, label: Text('Left')),
                                ButtonSegment(
                                    value: true, label: Text('Right')),
                              ],
                              selected: {_draft.menuOnRight},
                              onSelectionChanged: (values) => setState(() =>
                                  _draft =
                                      _draft.setMenuOnRight(values.single)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: Theme(
          data: ambientTheme,
          child: SafeArea(
            minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: OverflowBar(
              alignment: MainAxisAlignment.spaceBetween,
              spacing: 10,
              overflowSpacing: 6,
              children: [
                TextButton(
                  onPressed: _saving
                      ? null
                      : () =>
                          setState(() => _draft = const ThemeLayout.defaults()),
                  child: const Text('Reset to default'),
                ),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving…' : 'Save layout'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _itemList(LayoutArea area, Map<String, String> features) {
    final separateBanner = _draft.separatesBanner(_mode);
    final entries = _draft
        .items(area)
        .where((item) =>
            (!item.separateBannerOnly || separateBanner) &&
            item.allowed(features))
        .toList();
    return ReorderableListView.builder(
      key: PageStorageKey(area),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      buildDefaultDragHandles: false,
      header: const Padding(
        padding: EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: Text(
            'Drag the handle to move an item. Use its switch to show or hide it.'),
      ),
      itemCount: entries.length,
      onReorder: (from, to) {
        final target = to > from ? to - 1 : to;
        setState(() =>
            _draft = _draft.reorder(area, entries[from], entries[target]));
      },
      itemBuilder: (context, index) {
        final item = entries[index];
        final label = !separateBanner && item == LayoutItem.banner
            ? 'Banner, quote and clock'
            : item.label;
        return Row(
          key: ValueKey(item),
          children: [
            Expanded(
              child: SwitchListTile(
                title: Text(label),
                subtitle: item.pinned ? const Text('Always available') : null,
                value: _draft.shows(item),
                onChanged: item.pinned
                    ? null
                    : (value) =>
                        setState(() => _draft = _draft.setVisible(item, value)),
              ),
            ),
            ReorderableDragStartListener(
              index: index,
              child: Semantics(
                label: 'Move $label',
                child: const ColoredBox(
                  color: Colors.transparent,
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Icon(Icons.drag_handle),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<Color?> _pickColor(String label, Color current) => showDialog<Color>(
        context: context,
        builder: (_) => _LayoutColorDialog(label: label, current: current),
      );
}

class _LayoutColorDialog extends StatefulWidget {
  const _LayoutColorDialog({required this.label, required this.current});

  final String label;
  final Color current;

  @override
  State<_LayoutColorDialog> createState() => _LayoutColorDialogState();
}

class _LayoutColorDialogState extends State<_LayoutColorDialog> {
  static const _swatches = [
    Color(0xff750f2b),
    Color(0xff0c2b61),
    Color(0xff0b4b38),
    Color(0xff332059),
    Color(0xff26111b),
    Color(0xfffff2dc),
    Color(0xffe6b857),
    Color(0xff61a7f5),
  ];
  late final _hex = TextEditingController(text: _format(widget.current));
  final _form = GlobalKey<FormState>();

  static String _format(Color color) =>
      '#${(color.toARGB32() & 0xffffff).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  Color? _parse(String? value) {
    final digits = (value ?? '').trim().replaceFirst('#', '');
    if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(digits)) return null;
    return Color(0xff000000 | int.parse(digits, radix: 16));
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: Text(widget.label),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: [
                for (final color in _swatches)
                  IconButton(
                    tooltip: _format(color),
                    icon: Icon(Icons.circle, size: 29, color: color),
                    onPressed: () => _hex.text = _format(color),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _hex,
              decoration: const InputDecoration(
                  labelText: 'Hex color', hintText: '#750F2B'),
              validator: (value) =>
                  _parse(value) == null ? 'Enter a six-digit hex color.' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (_form.currentState!.validate())
              Navigator.pop(context, _parse(_hex.text));
          },
          child: const Text('Use color'),
        ),
      ],
    );
  }
}
