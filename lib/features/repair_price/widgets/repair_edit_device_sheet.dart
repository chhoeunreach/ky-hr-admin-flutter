import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import '../models/repair_brand.dart';
import '../models/repair_device.dart';
import 'package:cnattendance/core/theme/app_colors.dart';

class RepairEditDeviceSheet extends StatefulWidget {
  final List<RepairBrand> brands;
  final List<RepairDeviceType> deviceTypes;
  final List<RepairDevice> existingDevices;
  final RepairDevice? device;
  final Future<bool> Function(RepairDevice) onSave;
  final Future<bool> Function(int)? onDelete;

  const RepairEditDeviceSheet({
    super.key,
    required this.brands,
    required this.deviceTypes,
    this.existingDevices = const [],
    this.device,
    required this.onSave,
    this.onDelete,
  });

  static Future<void> show(
    BuildContext context, {
    required List<RepairBrand> brands,
    required List<RepairDeviceType> deviceTypes,
    List<RepairDevice> existingDevices = const [],
    RepairDevice? device,
    required Future<bool> Function(RepairDevice) onSave,
    Future<bool> Function(int)? onDelete,
  }) {
    return showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RepairEditDeviceSheet(
        brands: brands,
        deviceTypes: deviceTypes,
        existingDevices: existingDevices,
        device: device,
        onSave: onSave,
        onDelete: onDelete,
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
  bool _saving = false;

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
  }

  @override
  void dispose() {
    _nameController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _nameController.text.trim();
    if (name.isEmpty || _selectedBrand == null || _selectedDeviceType == null) {
      _showResult('device_required_fields', false);
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
            'ម៉ូឌែល "$name" មានរួចហើយសម្រាប់ម៉ាកនេះ / Model "$name" already exists for this brand',
          ),
          backgroundColor: AppColors.redAccent,
        ),
      );
      return;
    }

    final series = widget.device?.series;
    final newDevice = RepairDevice(
      id: widget.device?.id ?? DateTime.now().millisecondsSinceEpoch % 100000,
      name: name,
      modelNumber: _modelController.text.trim(),
      image: widget.device?.image ?? '',
      brand: _selectedBrand,
      deviceType: _selectedDeviceType,
      series: series?.brandId == brandId &&
              series?.deviceTypeId == _selectedDeviceType?.id
          ? series
          : null,
    );

    setState(() => _saving = true);
    final saved = await widget.onSave(newDevice);
    if (!mounted) return;
    if (saved) {
      _showResult(
          widget.device == null ? 'device_created' : 'device_updated', true);
      Navigator.pop(context);
    } else {
      setState(() => _saving = false);
      _showResult('device_save_failed', false);
    }
  }

  void _showResult(String key, bool success) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(translate('repair_screen.$key')),
        backgroundColor: success ? AppColors.successToken : AppColors.redAccent,
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
                color: AppColors.redAccent, size: 24),
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
              backgroundColor: AppColors.redAccent,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              if (_saving) return;
              setState(() => _saving = true);
              final deleted = await widget.onDelete!(widget.device!.id);
              if (!mounted) return;
              if (deleted) {
                _showResult('device_deleted', true);
                Navigator.pop(context);
              } else {
                setState(() => _saving = false);
                _showResult('device_delete_failed', false);
              }
            },
            child: const Text('លុប / Delete'),
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

              Text(
                translate('repair_screen.brand'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: enterprise.text,
                ),
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

              Text(
                translate('repair_screen.device_type'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: enterprise.text,
                ),
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
                    foregroundColor: AppColors.white,
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
                  onPressed: _saving ? null : _save,
                ),
              ),

              // Delete Button (if editing)
              if (!isNew && widget.onDelete != null) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.redAccent,
                      side: const BorderSide(
                          color: AppColors.redAccent, width: 1),
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
                    onPressed: _saving ? null : _confirmDelete,
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
      fillColor:
          AppColors.white.withValues(alpha: enterprise.isDark ? 0.06 : 0.4),
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
            fillColor: AppColors.white
                .withValues(alpha: enterprise.isDark ? 0.06 : 0.4),
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
}
