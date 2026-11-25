import 'package:cnattendance/core/theme/app_colors.dart';
import 'package:cnattendance/model/admin_asset.dart';
import 'package:cnattendance/repositories/admin_asset_repository.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:cnattendance/utils/asset_image_compressor.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:cnattendance/widget/radialDecoration.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:gallery_image_viewer/gallery_image_viewer.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class AdminAssetFormScreen extends StatefulWidget {
  final AdminAsset? asset;
  final List<AssetDropdownItem> types;
  final List<AssetDropdownItem> branches;
  final List<AssetEmployeeItem> employees;

  const AdminAssetFormScreen({
    super.key,
    this.asset,
    required this.types,
    required this.branches,
    required this.employees,
  });

  @override
  State<AdminAssetFormScreen> createState() => _AdminAssetFormScreenState();
}

class _AdminAssetFormScreenState extends State<AdminAssetFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final repository = AdminAssetRepository();

  late TextEditingController _nameController;
  late TextEditingController _codeController;
  late TextEditingController _serialController;
  late TextEditingController _phoneController;
  late TextEditingController _icloudController;
  late TextEditingController _notesController;

  int? _selectedTypeId;
  int? _selectedBranchId;
  int? _selectedEmployeeId;

  DateTime _purchasedDate = DateTime.now();
  bool _warrantyAvailable = false;
  DateTime? _warrantyEndDate;

  bool _isAvailable = true;
  bool _isWorking = true;
  DateTime _assignedDate = DateTime.now();

  final List<CompressedAssetPhoto> _pickedPhotos = [];
  final List<String> _existingImages = [];
  bool _isSubmitting = false;

  bool get isEdit => widget.asset != null;

  @override
  void initState() {
    super.initState();
    final a = widget.asset;

    _nameController = TextEditingController(text: a?.name ?? '');
    _codeController = TextEditingController(text: a?.assetCode ?? '');
    _serialController = TextEditingController(text: a?.assetSerialNo ?? '');
    _phoneController = TextEditingController(text: a?.phoneNumbers ?? '');
    _icloudController = TextEditingController(text: a?.icloud ?? '');
    _notesController = TextEditingController(text: a?.note ?? '');

    _selectedTypeId = a?.typeId ?? (widget.types.isNotEmpty ? widget.types.first.id : null);
    _selectedBranchId = a?.branchId ?? (widget.branches.isNotEmpty ? widget.branches.first.id : null);
    _selectedEmployeeId = a?.assignedTo?.id;

    if (a?.purchasedDate.isNotEmpty == true) {
      final parsed = DateTime.tryParse(a!.purchasedDate);
      // Only apply when parse succeeds — never silently default to today.
      if (parsed != null) _purchasedDate = parsed;
    }
    _warrantyAvailable = a?.warrantyAvailable ?? false;
    if (a?.warrantyEndDate != null && a!.warrantyEndDate!.isNotEmpty) {
      _warrantyEndDate = DateTime.tryParse(a.warrantyEndDate!);
    }

    _isAvailable = a?.isAvailable ?? true;
    _isWorking = (a?.isWorking ?? 'yes').toLowerCase() == 'yes';

    if (a?.assignedTo?.assignedDate.isNotEmpty == true) {
      final parsed = DateTime.tryParse(a!.assignedTo!.assignedDate);
      if (parsed != null) _assignedDate = parsed;
    }

    if (a != null) {
      if (a.images.isNotEmpty) {
        _existingImages.addAll(a.images);
      } else if (a.imageUrl != null && a.imageUrl!.isNotEmpty) {
        _existingImages.add(a.imageUrl!);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _serialController.dispose();
    _phoneController.dispose();
    _icloudController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    _showPhotoOptions(context);
  }

  Future<void> _pickFromCamera() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (picked != null) {
        await _compressAndAdd([picked.path]);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Camera pick error: $e');
      showToast('Camera error: $e');
    }
  }

  Future<void> _pickMultiFromGallery() async {
    try {
      final picker = ImagePicker();
      final pickedList = await picker.pickMultiImage(imageQuality: 85);
      if (pickedList.isNotEmpty) {
        await _compressAndAdd(pickedList.map((e) => e.path).toList());
      }
    } catch (e) {
      // Fallback to FilePicker
      try {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: true,
        );
        if (result != null && result.paths.isNotEmpty) {
          final paths = result.paths.whereType<String>().toList();
          if (paths.isNotEmpty) {
            await _compressAndAdd(paths);
          }
        }
      } catch (err) {
        if (kDebugMode) debugPrint('Gallery pick error: $err');
        showToast('Photo pick error: $err');
      }
    }
  }

  Future<void> _compressAndAdd(List<String> paths) async {
    if (paths.isEmpty) return;
    final isKhmer = Localizations.localeOf(context).languageCode == 'km';
    EasyLoading.show(
      status: isKhmer
          ? 'កំពុងបង្រួមរូបភាព (${paths.length})...'
          : 'Compressing ${paths.length} photos...',
      maskType: EasyLoadingMaskType.black,
    );
    try {
      final compressed = await AssetImageCompressor.compressMultiple(paths);
      if (!mounted) {
        EasyLoading.dismiss(animation: true);
        return;
      }
      setState(() {
        _pickedPhotos.addAll(compressed);
      });
      EasyLoading.dismiss(animation: true);
      final totalKb = (_pickedPhotos.fold<int>(0, (sum, e) => sum + e.compressedSizeBytes) / 1024).round();
      showToast(isKhmer
          ? 'បង្រួមរូបភាព ${compressed.length} រូបរួចរាល់ ($totalKb KB)'
          : '${compressed.length} photos compressed ($totalKb KB)');
    } catch (e) {
      EasyLoading.dismiss(animation: true);
      if (mounted) showToast('Compression error: $e');
    }
  }

  void _showPhotoOptions(BuildContext context) {
    final theme = EnterpriseTheme.of(context);
    final isKhmer = Localizations.localeOf(context).languageCode == 'km';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.isDark ? const Color(0xFF1E293B) : AppColors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withValues(alpha: theme.isDark ? 0.35 : 0.12),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isKhmer ? 'ជ្រើសរើសរូបភាពទ្រព្យសម្បត្តិ' : 'Add Asset Photos',
                style: TextStyle(
                  color: theme.text,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.photo_library_outlined, color: theme.primary),
                ),
                title: Text(
                  isKhmer ? 'ជ្រើសរើសរូបភាពច្រើនពីវិចិត្រសាល' : 'Choose multiple from Gallery',
                  style: TextStyle(color: theme.text, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  isKhmer ? 'ជ្រើសរូបភាពច្រើនក្នុងពេលតែមួយ និងបង្រួមទំហំ' : 'Multi-select with auto compression',
                  style: TextStyle(color: theme.mutedText, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickMultiFromGallery();
                },
              ),
              const Divider(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.camera_alt_outlined, color: Colors.green),
                ),
                title: Text(
                  isKhmer ? 'ថតរូបដោយម៉ាស៊ីនថត' : 'Take photo with Camera',
                  style: TextStyle(color: theme.text, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  isKhmer ? 'ថតរូបភាពឧបករណ៍ផ្ទាល់' : 'Capture instant asset photo',
                  style: TextStyle(color: theme.mutedText, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickFromCamera();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectPurchasedDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _purchasedDate.isAfter(DateTime.now())
          ? DateTime.now()
          : _purchasedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() => _purchasedDate = picked);
    }
  }

  Future<void> _selectWarrantyEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _warrantyEndDate ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: _purchasedDate,
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() => _warrantyEndDate = picked);
    }
  }

  Future<void> _selectAssignedDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _assignedDate.isAfter(DateTime.now())
          ? DateTime.now()
          : _assignedDate,
      firstDate: _purchasedDate,
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() => _assignedDate = picked);
    }
  }

  /// Only pass dropdown values that exist in the items list — otherwise
  /// Flutter's DropdownButton throws a value-containment assertion.
  int? _safeBranchValue() =>
      _selectedBranchId != null &&
          widget.branches.any((b) => b.id == _selectedBranchId)
      ? _selectedBranchId
      : null;

  int? _safeTypeValue() =>
      _selectedTypeId != null && widget.types.any((t) => t.id == _selectedTypeId)
      ? _selectedTypeId
      : null;

  int? _safeEmployeeValue() =>
      _selectedEmployeeId != null &&
          widget.employees.any((e) => e.id == _selectedEmployeeId)
      ? _selectedEmployeeId
      : null;

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false) || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    EasyLoading.show(
      status: isEdit ? 'Updating asset...' : 'Creating asset...',
      maskType: EasyLoadingMaskType.black,
    );

    // Keep availability consistent with assignment.
    final assigned = _selectedEmployeeId != null;
    final isAvailable = assigned ? false : _isAvailable;

    final fields = <String, dynamic>{
      'name': _nameController.text.trim(),
      if (_selectedTypeId != null) 'type_id': _selectedTypeId,
      if (_selectedBranchId != null) 'branch_id': _selectedBranchId,
      'asset_code': _codeController.text.trim(),
      'asset_serial_no': _serialController.text.trim(),
      'phone_numbers': _phoneController.text.trim(),
      'icloud': _icloudController.text.trim(),
      'purchased_date': DateFormat('yyyy-MM-dd').format(_purchasedDate),
      'warranty_available': _warrantyAvailable ? '1' : '0',
      if (_warrantyAvailable && _warrantyEndDate != null)
        'warranty_end_date': DateFormat('yyyy-MM-dd').format(_warrantyEndDate!),
      'is_available': isAvailable ? '1' : '0',
      'is_working': _isWorking ? 'yes' : 'no',
      'note': _notesController.text.trim(),
      if (assigned) ...{
        'assigned_to': _selectedEmployeeId,
        'assigned_date': DateFormat('yyyy-MM-dd').format(_assignedDate),
      } else if (isEdit) ...{
        'assigned_to': '',
      },
    };

    try {
      final imageFiles = _pickedPhotos.map((e) => e.file).toList();
      final (success, message) = isEdit
          ? await repository.updateAsset(
              widget.asset!.id,
              fields,
              imageFiles: imageFiles,
            )
          : await repository.createAsset(
              fields,
              imageFiles: imageFiles,
            );

      if (!mounted) {
        EasyLoading.dismiss(animation: true);
        return;
      }
      EasyLoading.dismiss(animation: true);
      setState(() => _isSubmitting = false);

      showToast(message);
      if (success) {
        Get.back(result: true);
      }
    } catch (e) {
      EasyLoading.dismiss(animation: true);
      if (mounted) {
        setState(() => _isSubmitting = false);
        showToast(unknownError(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = EnterpriseTheme.of(context);
    final isKhmer = Localizations.localeOf(context).languageCode == 'km';

    return Container(
      decoration: RadialDecoration(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: theme.text),
          title: Text(
            isEdit
                ? (isKhmer ? 'កែសម្រួលទ្រព្យសម្បត្តិ' : 'Edit Asset')
                : (isKhmer ? 'បន្ថែមទ្រព្យសម្បត្តិថ្មី' : 'Add New Asset'),
            style: TextStyle(color: theme.text, fontWeight: FontWeight.bold),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.text),
            onPressed: () => Get.back(),
          ),
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                // 1. Photo Section (Multi-upload & Auto Compression)
                _buildPhotoSection(theme, isKhmer),
                const SizedBox(height: 14),

                // 2. Primary Details
                _buildCard(
                  theme: theme,
                  title: isKhmer ? 'ព័ត៌មានទូទៅ' : 'General Info',
                  icon: Icons.info_outline,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nameController,
                        style: TextStyle(color: theme.text),
                        cursorColor: theme.primary,
                        decoration: _inputDecoration(
                          theme,
                          isKhmer ? 'ឈ្មោះទ្រព្យសម្បត្តិ (Asset Name) *' : 'Asset Name *',
                        ),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Please enter asset name' : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: _safeBranchValue(),
                              dropdownColor: theme.isDark ? const Color(0xFF1E293B) : AppColors.white,
                              style: TextStyle(color: theme.text),
                              decoration: _inputDecoration(theme, isKhmer ? 'សាខា (Branch)' : 'Branch'),
                              items: widget.branches
                                  .map((b) => DropdownMenuItem(
                                        value: b.id,
                                        child: Text(
                                          b.name,
                                          style: TextStyle(color: theme.text),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ))
                                  .toList(),
                              onChanged: (v) => setState(() => _selectedBranchId = v),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: _safeTypeValue(),
                              dropdownColor: theme.isDark ? const Color(0xFF1E293B) : AppColors.white,
                              style: TextStyle(color: theme.text),
                              decoration: _inputDecoration(theme, isKhmer ? 'ប្រភេទ (Type) *' : 'Type *'),
                              items: widget.types
                                  .map((t) => DropdownMenuItem(
                                        value: t.id,
                                        child: Text(
                                          t.name,
                                          style: TextStyle(color: theme.text),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ))
                                  .toList(),
                              onChanged: (v) => setState(() => _selectedTypeId = v),
                              // Only require a type when options exist — an empty
                              // types list would otherwise block submit forever.
                              validator: (v) =>
                                  widget.types.isNotEmpty && v == null
                                      ? 'Select type'
                                      : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _codeController,
                              style: TextStyle(color: theme.text),
                              cursorColor: theme.primary,
                              decoration: _inputDecoration(
                                theme,
                                isKhmer ? 'លេខកូដ (Asset Code)' : 'Asset Code',
                                hintText: isKhmer ? 'ស្វ័យប្រវត្តិបើទទេ' : 'Auto if blank',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _serialController,
                              style: TextStyle(color: theme.text),
                              cursorColor: theme.primary,
                              decoration: _inputDecoration(
                                theme,
                                isKhmer ? 'លេខស៊េរី (Serial No)' : 'Serial No',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 3. Device & Connectivity Info
                _buildCard(
                  theme: theme,
                  title: isKhmer ? 'ទិន្នន័យទំនាក់ទំនង / ឧបករណ៍' : 'Device Connectivity',
                  icon: Icons.phone_android_outlined,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _phoneController,
                        style: TextStyle(color: theme.text),
                        cursorColor: theme.primary,
                        decoration: _inputDecoration(
                          theme,
                          isKhmer ? 'លេខទូរស័ព្ទប្រើលើឧបករណ៍' : 'Phone Numbers (if SIM)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _icloudController,
                        style: TextStyle(color: theme.text),
                        cursorColor: theme.primary,
                        decoration: _inputDecoration(
                          theme,
                          isKhmer ? 'គណនី iCloud / Google' : 'iCloud / Google Account',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 4. Dates & Warranty
                _buildCard(
                  theme: theme,
                  title: isKhmer ? 'កាលបរិច្ឆេទ & ការធានា' : 'Purchase & Warranty',
                  icon: Icons.calendar_today_outlined,
                  child: Column(
                    children: [
                      InkWell(
                        onTap: _selectPurchasedDate,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: theme.isDark ? AppColors.white12 : const Color(0xFFF8FAFC),
                            border: Border.all(
                              color: theme.isDark ? theme.cardBorder : AppColors.customFFB8DEFF,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.date_range, color: theme.primary, size: 20),
                              const SizedBox(width: 10),
                              Text(
                                '${isKhmer ? 'កាលបរិច្ឆេទជាវ' : 'Purchased Date'}: ${DateFormat('yyyy-MM-dd').format(_purchasedDate)}',
                                style: TextStyle(color: theme.text, fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          isKhmer ? 'មានការធានា (Warranty Available)' : 'Warranty Available',
                          style: TextStyle(color: theme.text, fontSize: 14),
                        ),
                        activeThumbColor: theme.primary,
                        value: _warrantyAvailable,
                        onChanged: (v) => setState(() => _warrantyAvailable = v),
                      ),
                      if (_warrantyAvailable) ...[
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: _selectWarrantyEndDate,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: theme.isDark ? AppColors.white12 : const Color(0xFFF8FAFC),
                              border: Border.all(
                                color: theme.isDark ? theme.cardBorder : AppColors.customFFB8DEFF,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.verified_user_outlined, color: Colors.green, size: 20),
                                const SizedBox(width: 10),
                                Text(
                                  _warrantyEndDate != null
                                      ? '${isKhmer ? 'ថ្ងៃផុតកំណត់ធានា' : 'Warranty End Date'}: ${DateFormat('yyyy-MM-dd').format(_warrantyEndDate!)}'
                                      : (isKhmer ? 'ជ្រើសថ្ងៃផុតកំណត់ធានា' : 'Select Warranty End Date'),
                                  style: TextStyle(color: theme.text, fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 5. Assignment & Status
                _buildCard(
                  theme: theme,
                  title: isKhmer ? 'ការប្រគល់ & ស្ថានភាព' : 'Assignment & Availability',
                  icon: Icons.person_add_alt_1_outlined,
                  child: Column(
                    children: [
                      DropdownButtonFormField<int>(
                        value: _safeEmployeeValue(),
                        dropdownColor: theme.isDark ? const Color(0xFF1E293B) : AppColors.white,
                        style: TextStyle(color: theme.text),
                        decoration: _inputDecoration(
                          theme,
                          isKhmer ? 'ប្រគល់ឱ្យបុគ្គលិក (Assign to)' : 'Assign to Employee',
                        ),
                        items: [
                          DropdownMenuItem<int>(
                            value: null,
                            child: Text(
                              isKhmer ? '-- មិនទាន់ប្រគល់ (Unassigned) --' : '-- Unassigned --',
                              style: TextStyle(color: theme.mutedText),
                            ),
                          ),
                          ...widget.employees.map((e) => DropdownMenuItem(
                                value: e.id,
                                child: Text(
                                  '${e.name}${e.employeeCode != null ? ' (${e.employeeCode})' : ''}',
                                  style: TextStyle(color: theme.text),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              )),
                        ],
                        onChanged: (v) => setState(() {
                          _selectedEmployeeId = v;
                          // Assigned ⇒ not available; unassigned ⇒ restore available.
                          _isAvailable = v == null;
                        }),
                      ),
                      if (_selectedEmployeeId != null) ...[
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: _selectAssignedDate,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: theme.isDark ? AppColors.white12 : const Color(0xFFF8FAFC),
                              border: Border.all(
                                color: theme.isDark ? theme.cardBorder : AppColors.customFFB8DEFF,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.event_available, color: theme.primary, size: 20),
                                const SizedBox(width: 10),
                                Text(
                                  '${isKhmer ? 'កាលបរិច្ឆេទប្រគល់' : 'Assigned Date'}: ${DateFormat('yyyy-MM-dd').format(_assignedDate)}',
                                  style: TextStyle(color: theme.text, fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          isKhmer ? 'អាចប្រគល់ជូនបុគ្គលិក (Available)' : 'Available for Employee',
                          style: TextStyle(color: theme.text, fontSize: 14),
                        ),
                        activeThumbColor: theme.primary,
                        value: _selectedEmployeeId != null ? false : _isAvailable,
                        onChanged: (v) {
                          if (_selectedEmployeeId != null) {
                            showToast(isKhmer
                                ? 'សូមដកចេញពីបុគ្គលិកសិន'
                                : 'Unassign employee first');
                            return;
                          }
                          setState(() => _isAvailable = v);
                        },
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          isKhmer ? 'ដំណើរការល្អ (Working Condition)' : 'Working Condition',
                          style: TextStyle(color: theme.text, fontSize: 14),
                        ),
                        activeThumbColor: Colors.green,
                        value: _isWorking,
                        onChanged: (v) => setState(() => _isWorking = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 6. Notes
                _buildCard(
                  theme: theme,
                  title: isKhmer ? 'កំណត់ចំណាំផ្សេងៗ' : 'Notes & Description',
                  icon: Icons.notes_outlined,
                  child: TextFormField(
                    controller: _notesController,
                    maxLines: 3,
                    style: TextStyle(color: theme.text),
                    cursorColor: theme.primary,
                    decoration: _inputDecoration(
                      theme,
                      isKhmer ? 'សេចក្តីពិពណ៌នា / កំណត់ចំណាំ' : 'Description / Notes',
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Submit Button
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primary,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isSubmitting ? null : _submit,
                  child: Text(
                    isEdit
                        ? (isKhmer ? 'រក្សាទុកការកែសម្រួល' : 'Update Asset')
                        : (isKhmer ? 'រក្សាទុកទ្រព្យសម្បត្តិ' : 'Create Asset'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoSection(EnterpriseTheme theme, bool isKhmer) {
    final totalPhotos = _existingImages.length + _pickedPhotos.length;
    final totalBytes = _pickedPhotos.fold<int>(0, (sum, p) => sum + p.compressedSizeBytes);
    final totalKb = (totalBytes / 1024).toStringAsFixed(1);

    return _buildCard(
      theme: theme,
      title: isKhmer ? 'រូបភាពទ្រព្យសម្បត្តិ' : 'Asset Photos',
      icon: Icons.photo_library_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header / Stats if photos selected
          if (totalPhotos > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: theme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isKhmer ? '$totalPhotos រូបភាព' : '$totalPhotos photos',
                      style: TextStyle(
                        color: theme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  if (_pickedPhotos.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isKhmer ? 'បង្រួមរួច: $totalKb KB' : 'Compressed: $totalKb KB',
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(50, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: _pickImage,
                    icon: Icon(Icons.add_photo_alternate_outlined, size: 16, color: theme.primary),
                    label: Text(
                      isKhmer ? 'បន្ថែម' : 'Add',
                      style: TextStyle(color: theme.primary, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

          // Photos Grid / Strip or Empty State
          if (totalPhotos == 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: theme.isDark ? AppColors.white12 : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.isDark ? theme.cardBorder : AppColors.customFFB8DEFF,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: theme.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.add_a_photo_outlined, color: theme.primary, size: 26),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isKhmer
                        ? 'ជ្រើសរូបភាពច្រើន និងបង្រួមទំហំស្វ័យប្រវត្តិ'
                        : 'Upload multiple photos with auto-compression',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: theme.text,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isKhmer
                        ? 'គាំទ្រការថតរូបផ្ទាល់ ឬជ្រើសរូបច្រើនពីវិចិត្រសាល'
                        : 'Capture with camera or choose multi-images from gallery',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: theme.mutedText,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primary,
                          foregroundColor: AppColors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        onPressed: _pickMultiFromGallery,
                        icon: const Icon(Icons.photo_library_outlined, size: 16),
                        label: Text(isKhmer ? 'វិចិត្រសាល (ច្រើន)' : 'Gallery (Multi)'),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.text,
                          side: BorderSide(
                            color: theme.isDark ? theme.cardBorder : AppColors.customFFB8DEFF,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        onPressed: _pickFromCamera,
                        icon: const Icon(Icons.camera_alt_outlined, size: 16),
                        label: Text(isKhmer ? 'ថតរូប' : 'Camera'),
                      ),
                    ],
                  ),
                ],
              ),
            )
          else
            SizedBox(
              height: 110,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  // Existing remote images
                  ..._existingImages.map((url) {
                    return Container(
                      width: 90,
                      height: 110,
                      margin: const EdgeInsets.only(right: 10),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                color: theme.isDark ? AppColors.white12 : const Color(0xFFF1F5F9),
                                child: InkWell(
                                  onTap: () {
                                    showImageViewer(
                                      context,
                                      NetworkImage(url),
                                      swipeDismissible: true,
                                    );
                                  },
                                  child: Image.network(
                                    url,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Icon(
                                      Icons.broken_image_outlined,
                                      color: theme.mutedText,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            left: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.black.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isKhmer ? 'ចាស់' : 'Saved',
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          // No remove-images field exists in any known asset
                          // API contract, so the ✕ stays disabled rather than
                          // implying a delete that would never be persisted.
                          // Flip this to a real action once the backend
                          // documents the field name.
                          Positioned(
                            top: 2,
                            right: 2,
                            child: Tooltip(
                              message: isKhmer
                                  ? 'រូបភាពរក្សាទុកមិនអាចលុបបានទេ'
                                  : 'Saved photos cannot be removed yet',
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: AppColors.black.withValues(alpha: 0.45),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.lock_outline,
                                    size: 12, color: AppColors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  // New picked compressed images
                  ..._pickedPhotos.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final photo = entry.value;
                    return Container(
                      width: 90,
                      height: 110,
                      margin: const EdgeInsets.only(right: 10),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                color: theme.isDark ? AppColors.white12 : const Color(0xFFF1F5F9),
                                child: InkWell(
                                  onTap: () {
                                    showImageViewer(
                                      context,
                                      FileImage(photo.file),
                                      swipeDismissible: true,
                                    );
                                  },
                                  child: Image.file(
                                    photo.file,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Icon(
                                      Icons.broken_image_outlined,
                                      color: theme.mutedText,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            left: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.primary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '#${idx + 1}',
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 4,
                            left: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.black.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                photo.readableSize,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _pickedPhotos.removeAt(idx);
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: AppColors.red.withValues(alpha: 0.9),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, size: 12, color: AppColors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  // Add more button card
                  Container(
                    width: 90,
                    height: 110,
                    decoration: BoxDecoration(
                      color: theme.isDark ? AppColors.white12 : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.isDark ? theme.cardBorder : AppColors.customFFB8DEFF,
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _pickImage,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_circle_outline, color: theme.primary, size: 28),
                          const SizedBox(height: 6),
                          Text(
                            isKhmer ? 'ថែមរូប' : 'Add More',
                            style: TextStyle(
                              color: theme.text,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required EnterpriseTheme theme,
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.isDark ? AppColors.white12 : AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.isDark ? theme.cardBorder : AppColors.customFFB8DEFF,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: theme.isDark ? 0.12 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: theme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: theme.text,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          Divider(
            color: theme.isDark ? theme.cardBorder : AppColors.customFFB8DEFF,
            height: 20,
          ),
          child,
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(EnterpriseTheme theme, String label, {String? hintText}) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      labelStyle: TextStyle(color: theme.mutedText, fontSize: 13),
      hintStyle: TextStyle(color: theme.mutedText.withValues(alpha: 0.6), fontSize: 12),
      filled: true,
      fillColor: theme.isDark ? AppColors.white12 : const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: theme.isDark ? theme.cardBorder : AppColors.customFFB8DEFF,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: theme.isDark ? theme.cardBorder : AppColors.customFFB8DEFF,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: theme.primary, width: 1.5),
      ),
    );
  }
}
