import 'package:cnattendance/model/app_theme_option.dart';
import 'package:cnattendance/provider/dashboardprovider.dart';
import 'package:cnattendance/theme/app_theme_mode.dart';
import 'package:cnattendance/theme/theme_layout.dart';
import 'package:cnattendance/theme/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cnattendance/core/theme/app_colors.dart';
import 'package:cnattendance/core/theme/app_palette.dart';

class ThemeLayoutEditor extends StatefulWidget {
  final AppThemeOption? option;
  const ThemeLayoutEditor({super.key, this.option});

  @override
  State<ThemeLayoutEditor> createState() => _ThemeLayoutEditorState();
}

class _ThemeLayoutEditorState extends State<ThemeLayoutEditor> {
  late final AppThemeOption _themeOption;
  late final String _themeId;
  late ThemeLayout _draft;
  bool _saving = false;

  AppThemeMode get _effectiveCoreMode =>
      _themeOption.coreMode ?? AppThemeMode.light;

  @override
  void initState() {
    super.initState();
    final provider = context.read<ThemeProvider>();
    _themeOption = widget.option ?? provider.currentThemeOption;
    _themeId = _themeOption.id;
    _draft = provider.layoutForId(_themeId);
  }

  Future<void> _save() async {
    final provider = context.read<ThemeProvider>();
    setState(() => _saving = true);
    var saved = false;
    try {
      saved = await provider.saveLayoutForId(_themeId, _draft);
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
    final colors = _draft.colorsFor(_themeOption.colors);
    final features = context.watch<DashboardProvider?>()?.features ??
        const <String, String>{};
    final baseTheme = Theme.of(context);
    final ambientText = ThemeData.estimateBrightnessForColor(
                baseTheme.scaffoldBackgroundColor) ==
            Brightness.dark
        ? AppColors.white
        : AppColors.customFF211720;
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
                  child: Text(_themeOption.name,
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
                        cacheExtent: 2000,
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                        children: [
                          Semantics(
                            label: 'Color preview',
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: colors.backgroundColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: colors.accentColor.withValues(alpha: 0.5)),
                                boxShadow: [
                                  BoxShadow(
                                    color: colors.primaryColor.withValues(alpha: 0.15),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _themeOption.name,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: colors.textColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: colors.accentColor,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'Accent',
                                          style: TextStyle(
                                            color: colors.isDark
                                                ? AppColors.black
                                                : AppColors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: colors.cardColor,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.dashboard_outlined,
                                                size: 16,
                                                color: colors.accentColor),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                'Card element',
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: colors.textColor,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: colors.primaryColor,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: const Text(
                                                'Primary',
                                                style: TextStyle(
                                                  color: AppColors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: colors.secondaryColor,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: const Text(
                                                'Secondary',
                                                style: TextStyle(
                                                  color: AppColors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                                backgroundColor: colors.backgroundColor),
                            title: const Text('Background color'),
                            subtitle: Text(
                              AppPalette.hexPrefix +
                                  (colors.backgroundColor.toARGB32() & 0xFFFFFF)
                                      .toRadixString(16)
                                      .padLeft(6, '0')
                                      .toUpperCase(),
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: const Icon(Icons.edit_outlined),
                            onTap: () async {
                              final selected = await _pickColor(
                                  'Background color', colors.backgroundColor);
                              if (!mounted || selected == null) return;
                              setState(() => _draft = _draft.setColors(
                                    primary: _draft.primary,
                                    secondary: _draft.secondary,
                                    accent: _draft.accent,
                                    background: selected,
                                    card: _draft.card,
                                    text: _draft.text,
                                  ));
                            },
                          ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                                backgroundColor: colors.accentColor),
                            title: const Text('Accent color'),
                            subtitle: Text(
                              AppPalette.hexPrefix +
                                  (colors.accentColor.toARGB32() & 0xFFFFFF)
                                      .toRadixString(16)
                                      .padLeft(6, '0')
                                      .toUpperCase(),
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: const Icon(Icons.edit_outlined),
                            onTap: () async {
                              final selected = await _pickColor(
                                  'Accent color', colors.accentColor);
                              if (!mounted || selected == null) return;
                              setState(() => _draft = _draft.setColors(
                                    primary: _draft.primary,
                                    secondary: _draft.secondary,
                                    accent: selected,
                                    background: _draft.background,
                                    card: _draft.card,
                                    text: _draft.text,
                                  ));
                            },
                          ),
                          if (_effectiveCoreMode != AppThemeMode.royalBlueGold &&
                              _effectiveCoreMode != AppThemeMode.royalBlueDay &&
                              _effectiveCoreMode != AppThemeMode.royalBlueGoldKhmerDay)
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                  'Separate banner, quote and clock'),
                              value: _draft.separatesBanner(_effectiveCoreMode),
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
                          const SizedBox(height: 16),
                          Text('Theme palette colors',
                              style: ambientTheme.textTheme.titleMedium),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                                backgroundColor: colors.primaryColor),
                            title: const Text('Primary color'),
                            subtitle: Text(
                              AppPalette.hexPrefix +
                                  (colors.primaryColor.toARGB32() & 0xFFFFFF)
                                      .toRadixString(16)
                                      .padLeft(6, '0')
                                      .toUpperCase(),
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: const Icon(Icons.edit_outlined),
                            onTap: () async {
                              final selected = await _pickColor(
                                  'Primary color', colors.primaryColor);
                              if (!mounted || selected == null) return;
                              setState(() => _draft = _draft.setColors(
                                    primary: selected,
                                    secondary: _draft.secondary,
                                    accent: _draft.accent,
                                    background: _draft.background,
                                    card: _draft.card,
                                    text: _draft.text,
                                  ));
                            },
                          ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                                backgroundColor: colors.secondaryColor),
                            title: const Text('Secondary color'),
                            subtitle: Text(
                              AppPalette.hexPrefix +
                                  (colors.secondaryColor.toARGB32() & 0xFFFFFF)
                                      .toRadixString(16)
                                      .padLeft(6, '0')
                                      .toUpperCase(),
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: const Icon(Icons.edit_outlined),
                            onTap: () async {
                              final selected = await _pickColor(
                                  'Secondary color', colors.secondaryColor);
                              if (!mounted || selected == null) return;
                              setState(() => _draft = _draft.setColors(
                                    primary: _draft.primary,
                                    secondary: selected,
                                    accent: _draft.accent,
                                    background: _draft.background,
                                    card: _draft.card,
                                    text: _draft.text,
                                  ));
                            },
                          ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                                backgroundColor: colors.cardColor),
                            title: const Text('Card color'),
                            subtitle: Text(
                              AppPalette.hexPrefix +
                                  (colors.cardColor.toARGB32() & 0xFFFFFF)
                                      .toRadixString(16)
                                      .padLeft(6, '0')
                                      .toUpperCase(),
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: const Icon(Icons.edit_outlined),
                            onTap: () async {
                              final selected = await _pickColor(
                                  'Card color', colors.cardColor);
                              if (!mounted || selected == null) return;
                              setState(() => _draft = _draft.setColors(
                                    primary: _draft.primary,
                                    secondary: _draft.secondary,
                                    accent: _draft.accent,
                                    background: _draft.background,
                                    card: selected,
                                    text: _draft.text,
                                  ));
                            },
                          ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                                backgroundColor: colors.textColor),
                            title: const Text('Text color'),
                            subtitle: Text(
                              AppPalette.hexPrefix +
                                  (colors.textColor.toARGB32() & 0xFFFFFF)
                                      .toRadixString(16)
                                      .padLeft(6, '0')
                                      .toUpperCase(),
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: const Icon(Icons.edit_outlined),
                            onTap: () async {
                              final selected = await _pickColor(
                                  'Text color', colors.textColor);
                              if (!mounted || selected == null) return;
                              setState(() => _draft = _draft.setColors(
                                    primary: _draft.primary,
                                    secondary: _draft.secondary,
                                    accent: _draft.accent,
                                    background: _draft.background,
                                    card: _draft.card,
                                    text: selected,
                                  ));
                            },
                          ),
                          if (_draft.primary != null ||
                              _draft.secondary != null ||
                              _draft.accent != null ||
                              _draft.background != null ||
                              _draft.card != null ||
                              _draft.text != null)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                icon: const Icon(Icons.restart_alt_rounded,
                                    size: 16),
                                onPressed: () => setState(() {
                                  _draft = _draft.setColors(
                                    primary: null,
                                    secondary: null,
                                    accent: null,
                                    background: null,
                                    card: null,
                                    text: null,
                                  );
                                }),
                                label: const Text('Use theme defaults'),
                              ),
                            ),
                          if (_effectiveCoreMode != AppThemeMode.royalBlueGold &&
                              _effectiveCoreMode != AppThemeMode.royalBlueDay &&
                              _effectiveCoreMode != AppThemeMode.royalBlueGoldKhmerDay)
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                  'Separate banner, quote and clock'),
                              value: _draft.separatesBanner(_effectiveCoreMode),
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
    final separateBanner = _draft.separatesBanner(_effectiveCoreMode);
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
    AppColors.customFF750F2B,
    AppColors.customFF0C2B61,
    AppColors.customFF0B4B38,
    AppColors.customFF332059,
    AppColors.customFF26111B,
    AppColors.customFFFFF2DC,
    AppColors.customFFE6B857,
    AppColors.customFF61A7F5,
  ];
  late final _hex = TextEditingController(text: _format(widget.current));
  final _form = GlobalKey<FormState>();

  static String _format(Color color) =>
      '${AppPalette.hexPrefix}${(color.toARGB32() & AppPalette.rgbMask).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  Color? _parse(String? value) {
    final input = (value ?? '').trim();
    final digits = input.startsWith(AppPalette.hexPrefix)
        ? input.substring(AppPalette.hexPrefix.length)
        : input;
    if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(digits)) return null;
    return AppPalette.parseOpaqueHex(digits);
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
                  labelText: 'Hex color',
                  hintText: '${AppPalette.hexPrefix}750F2B'),
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
