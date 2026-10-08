import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import '../models/repair_brand.dart';
import '../models/repair_device.dart';

class RepairEditDeviceSheet extends StatefulWidget {
  final List<RepairBrand> brands;
  final List<RepairDeviceType> deviceTypes;
  final List<RepairDeviceSeries> series;
  final List<RepairDevice> existingDevices;
  final RepairDevice? device;
  final ValueChanged<RepairDevice> onSave;
  final ValueChanged<int>? onDelete;
  final Future<RepairBrand?> Function(RepairBrand brand)? onAddBrand;
  final Future<RepairDeviceType?> Function(RepairDeviceType deviceType)?
      onAddDeviceType;

  const RepairEditDeviceSheet({
    super.key,
    required this.brands,
    required this.deviceTypes,
    required this.series,
    this.existingDevices = const [],
    this.device,
    required this.onSave,
    this.onDelete,
    this.onAddBrand,
    this.onAddDeviceType,
  });

  static Future<void> show(
    BuildContext context, {
    required List<RepairBrand> brands,
    required List<RepairDeviceType> deviceTypes,
    required List<RepairDeviceSeries> series,
    List<RepairDevice> existingDevices = const [],
    RepairDevice? device,
    required ValueChanged<RepairDevice> onSave,
    ValueChanged<int>? onDelete,
    Future<RepairBrand?> Function(RepairBrand brand)? onAddBrand,
    Future<RepairDeviceType?> Function(RepairDeviceType deviceType)?
        onAddDeviceType,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RepairEditDeviceSheet(
        brands: brands,
        deviceTypes: deviceTypes,
        series: series,
        existingDevices: existingDevices,
        device: device,
        onSave: onSave,
        onDelete: onDelete,
        onAddBrand: onAddBrand,
        onAddDeviceType: onAddDeviceType,
      ),
    );
  }

  @override
  State<RepairEditDeviceSheet> createState() => _RepairEditDeviceSheetState();
}

class _RepairEditDeviceSheetState extends State<RepairEditDeviceSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _modelController;

  late List<RepairBrand> _availableBrands;
  late List<RepairDeviceType> _availableDeviceTypes;

  RepairBrand? _selectedBrand;
  RepairDeviceType? _selectedDeviceType;
  RepairDeviceSeries? _selectedSeries;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.device?.name ?? '');
    _modelController =
        TextEditingController(text: widget.device?.modelNumber ?? '');

    _availableBrands = List<RepairBrand>.from(widget.brands);
    _availableDeviceTypes = List<RepairDeviceType>.from(widget.deviceTypes);

    if (widget.device?.brand != null) {
      _selectedBrand = _availableBrands.firstWhere(
        (b) => b.id == widget.device!.brand!.id,
        orElse: () => _availableBrands.isNotEmpty
            ? _availableBrands.first
            : widget.device!.brand!,
      );
    } else if (_availableBrands.isNotEmpty) {
      _selectedBrand = _availableBrands.first;
    }

    if (widget.device?.deviceType != null) {
      _selectedDeviceType = _availableDeviceTypes.firstWhere(
        (t) => t.id == widget.device!.deviceType!.id,
        orElse: () => _availableDeviceTypes.isNotEmpty
            ? _availableDeviceTypes.first
            : widget.device!.deviceType!,
      );
    } else if (_availableDeviceTypes.isNotEmpty) {
      _selectedDeviceType = _availableDeviceTypes.first;
    }

    if (widget.device?.series != null) {
      _selectedSeries = widget.series.firstWhere(
        (s) => s.id == widget.device!.series!.id,
        orElse: () => widget.series.isNotEmpty
            ? widget.series.first
            : widget.device!.series!,
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('សូមបញ្ចូលឈ្មោះឧបករណ៍ / Please enter device name'),
        ),
      );
      return;
    }

    final brandId = _selectedBrand?.id;
    final isDuplicate = widget.existingDevices.any((d) =>
        d.brand?.id == brandId &&
        d.id != widget.device?.id &&
        d.name.trim().toLowerCase() == name.toLowerCase());

    if (isDuplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'ម៉ូឌែល "" មានរួចហើយសម្រាប់ម៉ាកនេះ / Model "" already exists for this brand',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final newDevice = RepairDevice(
      id: widget.device?.id ?? DateTime.now().millisecondsSinceEpoch % 100000,
      name: name,
      modelNumber: _modelController.text.trim(),
      image: widget.device?.image ?? '',
      brand: _selectedBrand,
      deviceType: _selectedDeviceType,
      series: _selectedSeries,
    );

    widget.onSave(newDevice);
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(widget.device == null
            ? 'បានបន្ថែមឧបករណ៍ថ្មីដោយជោគជ័យ! / Device created!'
            : 'បានកែប្រែឧបករណ៍ដោយជោគជ័យ! / Device updated!'),
        backgroundColor: const Color(0xFF10B981),
      ),
    );
  }

  void _confirmDelete() {
    if (widget.device == null || widget.onDelete == null) return;
    final enterprise = EnterpriseTheme.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: enterprise.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Colors.redAccent, size: 24),
            const SizedBox(width: 8),
            Text(
              'លុបឧបករណ៍ / Delete Device',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: enterprise.text,
              ),
            ),
          ],
        ),
        content: Text(
          'តើអ្នកពិតជាចង់លុបឧបករណ៍ "${widget.device!.name}" មែនទេ?\nAre you sure you want to delete this device?',
          style: TextStyle(fontSize: 13, color: enterprise.mutedText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'បោះបង់ / Cancel',
              style: TextStyle(color: enterprise.mutedText),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
              widget.onDelete!(widget.device!.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'បានលុបឧបករណ៍ "${widget.device!.name}" ជោគជ័យ!',
                  ),
                  backgroundColor: Colors.redAccent,
                ),
              );
            },
            child: const Text('លុប / Delete'),
          ),
        ],
      ),
    );
  }

  void _openAddBrandDialog() {
    final nameCtrl = TextEditingController();
    final slugCtrl = TextEditingController();
    final enterprise = EnterpriseTheme.of(context);

    nameCtrl.addListener(() {
      slugCtrl.text =
          nameCtrl.text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '-');
    });

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: enterprise.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: enterprise.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.branding_watermark_rounded,
                  color: enterprise.accent, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'បន្ថែមម៉ាក / Add Brand',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: enterprise.text,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _dialogTextField(
              'ឈ្មោះម៉ាក / Brand Name *',
              nameCtrl,
              'e.g. Google, Sony, OnePlus',
              enterprise,
              icon: Icons.branding_watermark_outlined,
            ),
            const SizedBox(height: 12),
            _dialogTextField(
              'Slug / សម្គាល់',
              slugCtrl,
              'e.g. google',
              enterprise,
              icon: Icons.link_rounded,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('បោះបង់ / Cancel',
                style: TextStyle(color: enterprise.mutedText)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: enterprise.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              final slug = slugCtrl.text.trim().isNotEmpty
                  ? slugCtrl.text.trim()
                  : name.toLowerCase().replaceAll(RegExp(r'\s+'), '-');
              final newBrand = RepairBrand(
                id: DateTime.now().millisecondsSinceEpoch % 100000,
                name: name,
                slug: slug,
                status: true,
              );
              Navigator.pop(ctx);

              RepairBrand? created = newBrand;
              if (widget.onAddBrand != null) {
                created = await widget.onAddBrand!(newBrand) ?? newBrand;
              }

              setState(() {
                final newBrand = created!;
                _availableBrands = [
                  newBrand,
                  ..._availableBrands.where((b) => b.id != newBrand.id),
                ];
                _selectedBrand = newBrand;
              });

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('បានបន្ថែមម៉ាក "$name" ជោគជ័យ!'),
                    backgroundColor: const Color(0xFF10B981),
                  ),
                );
              }
            },
            child: const Text('បង្កើត / Add'),
          ),
        ],
      ),
    );
  }

  void _openAddDeviceTypeDialog() {
    final nameCtrl = TextEditingController();
    final slugCtrl = TextEditingController();
    final enterprise = EnterpriseTheme.of(context);

    nameCtrl.addListener(() {
      slugCtrl.text =
          nameCtrl.text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '-');
    });

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: enterprise.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: enterprise.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.category_rounded,
                  color: enterprise.accent, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'បន្ថែមប្រភេទឧបករណ៍ / Add Type',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: enterprise.text,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _dialogTextField(
              'ឈ្មោះប្រភេទ / Type Name *',
              nameCtrl,
              'e.g. Smartwatch, Console, Drone',
              enterprise,
              icon: Icons.category_outlined,
            ),
            const SizedBox(height: 12),
            _dialogTextField(
              'Slug / សម្គាល់',
              slugCtrl,
              'e.g. smartwatch',
              enterprise,
              icon: Icons.link_rounded,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('បោះបង់ / Cancel',
                style: TextStyle(color: enterprise.mutedText)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: enterprise.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              final slug = slugCtrl.text.trim().isNotEmpty
                  ? slugCtrl.text.trim()
                  : name.toLowerCase().replaceAll(RegExp(r'\s+'), '-');
              final newType = RepairDeviceType(
                id: DateTime.now().millisecondsSinceEpoch % 100000,
                name: name,
                slug: slug,
              );
              Navigator.pop(ctx);

              RepairDeviceType? created = newType;
              if (widget.onAddDeviceType != null) {
                created = await widget.onAddDeviceType!(newType) ?? newType;
              }

              setState(() {
                final newType = created!;
                _availableDeviceTypes = [
                  ..._availableDeviceTypes.where((t) => t.id != newType.id),
                  newType,
                ];
                _selectedDeviceType = newType;
              });

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('បានបន្ថែមប្រភេទ "$name" ជោគជ័យ!'),
                    backgroundColor: const Color(0xFF10B981),
                  ),
                );
              }
            },
            child: const Text('បង្កើត / Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final enterprise = EnterpriseTheme.of(context);
    final isNew = widget.device == null;

    final effectiveBrand =
        _availableBrands.any((b) => b.id == _selectedBrand?.id)
            ? _availableBrands.firstWhere((b) => b.id == _selectedBrand?.id)
            : (_availableBrands.isNotEmpty ? _availableBrands.first : null);
    final effectiveDeviceType =
        _availableDeviceTypes.any((t) => t.id == _selectedDeviceType?.id)
            ? _availableDeviceTypes
                .firstWhere((t) => t.id == _selectedDeviceType?.id)
            : (_availableDeviceTypes.isNotEmpty
                ? _availableDeviceTypes.first
                : null);

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: enterprise.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border:
            Border(top: BorderSide(color: enterprise.glassStroke, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top drag indicator
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: enterprise.mutedText.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header Row
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: enterprise.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: enterprise.accent.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Icon(
                      isNew
                          ? Icons.add_to_photos_rounded
                          : Icons.edit_note_rounded,
                      color: enterprise.accent,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isNew
                              ? translate('repair_screen.add_device')
                              : translate('repair_screen.edit_device'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: enterprise.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'បំពេញព័ត៌មានម៉ូឌែល និងម៉ាកយីហោឧបករណ៍',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: enterprise.mutedText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded,
                        color: enterprise.mutedText, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              Divider(color: enterprise.glassStroke, height: 22),

              // Device Name Field
              _textField(
                translate('repair_screen.device_name'),
                _nameController,
                'e.g. iPhone 16 Pro Max, Galaxy S24',
                enterprise,
                icon: Icons.phone_iphone_rounded,
              ),
              const SizedBox(height: 14),

              // Model Number Field
              _textField(
                translate('repair_screen.model_number'),
                _modelController,
                'e.g. A3294, SM-S928B',
                enterprise,
                icon: Icons.tag_rounded,
              ),
              const SizedBox(height: 14),

              // Brand Section Header with "+" Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    translate('repair_screen.brand'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: enterprise.text,
                    ),
                  ),
                  InkWell(
                    onTap: _openAddBrandDialog,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_circle_outline_rounded,
                              size: 14, color: enterprise.accent),
                          const SizedBox(width: 4),
                          Text(
                            translate('repair_screen.add_brand'),
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: enterprise.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<RepairBrand>(
                key: ValueKey('brand_${effectiveBrand?.id}'),
                initialValue: effectiveBrand,
                dropdownColor: enterprise.surface,
                style: TextStyle(fontSize: 13, color: enterprise.text),
                decoration: _dropdownDecoration(
                  enterprise,
                  icon: Icons.branding_watermark_rounded,
                ),
                items: _availableBrands
                    .map((b) => DropdownMenuItem(
                          value: b,
                          child: Text(b.name,
                              style: TextStyle(color: enterprise.text)),
                        ))
                    .toList(),
                onChanged: (val) => setState(() => _selectedBrand = val),
              ),
              const SizedBox(height: 14),

              // Device Type Section Header with "+" Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ប្រភេទឧបករណ៍ / Device Type',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: enterprise.text,
                    ),
                  ),
                  InkWell(
                    onTap: _openAddDeviceTypeDialog,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_circle_outline_rounded,
                              size: 14, color: enterprise.accent),
                          const SizedBox(width: 4),
                          Text(
                            translate('repair_screen.add_device_type'),
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: enterprise.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<RepairDeviceType>(
                key: ValueKey('type_${effectiveDeviceType?.id}'),
                initialValue: effectiveDeviceType,
                dropdownColor: enterprise.surface,
                style: TextStyle(fontSize: 13, color: enterprise.text),
                decoration: _dropdownDecoration(
                  enterprise,
                  icon: Icons.category_rounded,
                ),
                items: _availableDeviceTypes
                    .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(t.name,
                              style: TextStyle(color: enterprise.text)),
                        ))
                    .toList(),
                onChanged: (val) => setState(() => _selectedDeviceType = val),
              ),

              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: enterprise.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  icon: const Icon(Icons.check_rounded, size: 20),
                  label: Text(
                    isNew
                        ? translate('repair_screen.add_device')
                        : translate('repair_screen.save'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: _save,
                ),
              ),

              // Delete Button (if editing)
              if (!isNew && widget.onDelete != null) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent, width: 1),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: Text(
                      translate('repair_screen.delete_device'),
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onPressed: _confirmDelete,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _dropdownDecoration(EnterpriseTheme enterprise,
      {IconData? icon}) {
    return InputDecoration(
      prefixIcon: icon != null
          ? Icon(icon,
              size: 18, color: enterprise.mutedText.withValues(alpha: 0.8))
          : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      filled: true,
      fillColor: Colors.white.withValues(alpha: enterprise.isDark ? 0.06 : 0.4),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: enterprise.glassStroke),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: enterprise.glassStroke),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: enterprise.accent, width: 1.5),
      ),
    );
  }

  Widget _textField(
    String label,
    TextEditingController controller,
    String hint,
    EnterpriseTheme enterprise, {
    IconData? icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: enterprise.text,
          ),
        ),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          style: TextStyle(fontSize: 13.5, color: enterprise.text),
          decoration: InputDecoration(
            prefixIcon: icon != null
                ? Icon(icon,
                    size: 18,
                    color: enterprise.mutedText.withValues(alpha: 0.8))
                : null,
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: 12.5,
              color: enterprise.mutedText.withValues(alpha: 0.6),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            filled: true,
            fillColor:
                Colors.white.withValues(alpha: enterprise.isDark ? 0.06 : 0.4),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: enterprise.glassStroke),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: enterprise.glassStroke),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: enterprise.accent, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _dialogTextField(
    String label,
    TextEditingController controller,
    String hint,
    EnterpriseTheme enterprise, {
    IconData? icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: enterprise.text,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          style: TextStyle(fontSize: 13, color: enterprise.text),
          decoration: InputDecoration(
            prefixIcon: icon != null
                ? Icon(icon,
                    size: 16,
                    color: enterprise.mutedText.withValues(alpha: 0.8))
                : null,
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: 12,
              color: enterprise.mutedText.withValues(alpha: 0.6),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            filled: true,
            fillColor:
                Colors.white.withValues(alpha: enterprise.isDark ? 0.06 : 0.4),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: enterprise.glassStroke),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: enterprise.glassStroke),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: enterprise.accent, width: 1.2),
            ),
          ),
        ),
      ],
    );
  }
}
