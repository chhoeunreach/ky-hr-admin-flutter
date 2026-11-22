import 'dart:io';

import 'package:cnattendance/core/theme/app_colors.dart';
import 'package:cnattendance/model/admin_asset.dart';
import 'package:cnattendance/repositories/admin_asset_repository.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:cnattendance/widget/radialDecoration.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:get/get.dart';
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

  PlatformFile? _pickedImage;
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
      _purchasedDate = DateTime.tryParse(a!.purchasedDate) ?? DateTime.now();
    }
    _warrantyAvailable = a?.warrantyAvailable ?? false;
    if (a?.warrantyEndDate != null && a!.warrantyEndDate!.isNotEmpty) {
      _warrantyEndDate = DateTime.tryParse(a.warrantyEndDate!);
    }

    _isAvailable = a?.isAvailable ?? true;
    _isWorking = (a?.isWorking ?? 'yes').toLowerCase() == 'yes';

    if (a?.assignedTo?.assignedDate.isNotEmpty == true) {
      _assignedDate = DateTime.tryParse(a!.assignedTo!.assignedDate) ?? DateTime.now();
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
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _pickedImage = result.files.first;
      });
    }
  }

  Future<void> _selectPurchasedDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _purchasedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
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
    if (picked != null) {
      setState(() => _warrantyEndDate = picked);
    }
  }

  Future<void> _selectAssignedDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _assignedDate,
      firstDate: _purchasedDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _assignedDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    EasyLoading.show(
      status: isEdit ? 'Updating asset...' : 'Creating asset...',
      maskType: EasyLoadingMaskType.black,
    );

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
      'is_available': _isAvailable ? '1' : '0',
      'is_working': _isWorking ? 'yes' : 'no',
      'note': _notesController.text.trim(),
      if (_selectedEmployeeId != null) ...{
        'assigned_to': _selectedEmployeeId,
        'assigned_date': DateFormat('yyyy-MM-dd').format(_assignedDate),
      } else if (isEdit) ...{
        'assigned_to': '',
      },
    };

    final (success, message) = isEdit
        ? await repository.updateAsset(widget.asset!.id, fields, imageFile: _pickedImage)
        : await repository.createAsset(fields, imageFile: _pickedImage);

    EasyLoading.dismiss(animation: true);
    setState(() => _isSubmitting = false);

    showToast(message);
    if (success) {
      Get.back(result: true);
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
          title: Text(
            isEdit
                ? (isKhmer ? 'កែសម្រួលទ្រព្យសម្បត្តិ' : 'Edit Asset')
                : (isKhmer ? 'បន្ថែមទ្រព្យសម្បត្តិថ្មី' : 'Add New Asset'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Get.back(),
          ),
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                // 1. Photo Section
                _buildCard(
                  title: isKhmer ? 'រូបភាពទ្រព្យសម្បត្តិ' : 'Asset Photo',
                  icon: Icons.photo_camera_back_outlined,
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 80,
                          height: 80,
                          color: AppColors.white12,
                          child: _pickedImage != null
                              ? (_pickedImage!.path != null
                                  ? Image.file(
                                      File(_pickedImage!.path!),
                                      fit: BoxFit.cover,
                                    )
                                  : Image.memory(
                                      _pickedImage!.bytes!,
                                      fit: BoxFit.cover,
                                    ))
                              : (widget.asset?.imageUrl != null &&
                                      widget.asset!.imageUrl!.isNotEmpty
                                  ? Image.network(
                                      widget.asset!.imageUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(
                                        Icons.inventory_2_outlined,
                                        color: AppColors.white70,
                                        size: 36,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.inventory_2_outlined,
                                      color: AppColors.white70,
                                      size: 36,
                                    )),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.blue,
                                foregroundColor: AppColors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: _pickImage,
                              icon: const Icon(Icons.upload_file, size: 18),
                              label: Text(isKhmer ? 'ជ្រើសរើសរូបភាព' : 'Choose Photo'),
                            ),
                            if (_pickedImage != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  _pickedImage!.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 2. Primary Details
                _buildCard(
                  title: isKhmer ? 'ព័ត៌មានទូទៅ' : 'General Info',
                  icon: Icons.info_outline,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nameController,
                        style: const TextStyle(color: AppColors.white),
                        decoration: _inputDecoration(
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
                              value: _selectedBranchId,
                              dropdownColor: const Color(0xFF1E293B),
                              style: const TextStyle(color: AppColors.white),
                              decoration: _inputDecoration(isKhmer ? 'សាខា (Branch)' : 'Branch'),
                              items: widget.branches
                                  .map((b) => DropdownMenuItem(
                                        value: b.id,
                                        child: Text(
                                          b.name,
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
                              value: _selectedTypeId,
                              dropdownColor: const Color(0xFF1E293B),
                              style: const TextStyle(color: AppColors.white),
                              decoration: _inputDecoration(isKhmer ? 'ប្រភេទ (Type) *' : 'Type *'),
                              items: widget.types
                                  .map((t) => DropdownMenuItem(
                                        value: t.id,
                                        child: Text(
                                          t.name,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ))
                                  .toList(),
                              onChanged: (v) => setState(() => _selectedTypeId = v),
                              validator: (v) => v == null ? 'Select type' : null,
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
                              style: const TextStyle(color: AppColors.white),
                              decoration: _inputDecoration(
                                isKhmer ? 'លេខកូដ (Asset Code)' : 'Asset Code',
                                hintText: isKhmer ? 'ស្វ័យប្រវត្តិបើទទេ' : 'Auto if blank',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _serialController,
                              style: const TextStyle(color: AppColors.white),
                              decoration: _inputDecoration(
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
                  title: isKhmer ? 'ទិន្នន័យទំនាក់ទំនង / ឧបករណ៍' : 'Device Connectivity',
                  icon: Icons.phone_android_outlined,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _phoneController,
                        style: const TextStyle(color: AppColors.white),
                        decoration: _inputDecoration(
                          isKhmer ? 'លេខទូរស័ព្ទប្រើលើឧបករណ៍' : 'Phone Numbers (if SIM)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _icloudController,
                        style: const TextStyle(color: AppColors.white),
                        decoration: _inputDecoration(
                          isKhmer ? 'គណនី iCloud / Google' : 'iCloud / Google Account',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 4. Dates & Warranty
                _buildCard(
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
                            border: Border.all(color: AppColors.white24),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.date_range, color: AppColors.blue, size: 20),
                              const SizedBox(width: 10),
                              Text(
                                '${isKhmer ? 'កាលបរិច្ឆេទជាវ' : 'Purchased Date'}: ${DateFormat('yyyy-MM-dd').format(_purchasedDate)}',
                                style: const TextStyle(color: AppColors.white),
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
                          style: const TextStyle(color: AppColors.white, fontSize: 14),
                        ),
                        activeColor: AppColors.blue,
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
                              border: Border.all(color: AppColors.white24),
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
                                  style: const TextStyle(color: AppColors.white),
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
                  title: isKhmer ? 'ការប្រគល់ & ស្ថានភាព' : 'Assignment & Availability',
                  icon: Icons.person_add_alt_1_outlined,
                  child: Column(
                    children: [
                      DropdownButtonFormField<int>(
                        value: _selectedEmployeeId,
                        dropdownColor: const Color(0xFF1E293B),
                        style: const TextStyle(color: AppColors.white),
                        decoration: _inputDecoration(
                          isKhmer ? 'ប្រគល់ឱ្យបុគ្គលិក (Assign to)' : 'Assign to Employee',
                        ),
                        items: [
                          DropdownMenuItem<int>(
                            value: null,
                            child: Text(
                              isKhmer ? '-- មិនទាន់ប្រគល់ (Unassigned) --' : '-- Unassigned --',
                              style: const TextStyle(color: AppColors.white54),
                            ),
                          ),
                          ...widget.employees.map((e) => DropdownMenuItem(
                                value: e.id,
                                child: Text(
                                  '${e.name}${e.employeeCode != null ? ' (${e.employeeCode})' : ''}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              )),
                        ],
                        onChanged: (v) => setState(() {
                          _selectedEmployeeId = v;
                          if (v != null) _isAvailable = false;
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
                              border: Border.all(color: AppColors.white24),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.event_available, color: AppColors.blue, size: 20),
                                const SizedBox(width: 10),
                                Text(
                                  '${isKhmer ? 'កាលបរិច្ឆេទប្រគល់' : 'Assigned Date'}: ${DateFormat('yyyy-MM-dd').format(_assignedDate)}',
                                  style: const TextStyle(color: AppColors.white),
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
                          style: const TextStyle(color: AppColors.white, fontSize: 14),
                        ),
                        activeColor: AppColors.blue,
                        value: _isAvailable,
                        onChanged: (v) => setState(() => _isAvailable = v),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          isKhmer ? 'ដំណើរការល្អ (Working Condition)' : 'Working Condition',
                          style: const TextStyle(color: AppColors.white, fontSize: 14),
                        ),
                        activeColor: Colors.green,
                        value: _isWorking,
                        onChanged: (v) => setState(() => _isWorking = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 6. Notes
                _buildCard(
                  title: isKhmer ? 'កំណត់ចំណាំផ្សេងៗ' : 'Notes & Description',
                  icon: Icons.notes_outlined,
                  child: TextFormField(
                    controller: _notesController,
                    maxLines: 3,
                    style: const TextStyle(color: AppColors.white),
                    decoration: _inputDecoration(
                      isKhmer ? 'សេចក្តីពិពណ៌នា / កំណត់ចំណាំ' : 'Description / Notes',
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Submit Button
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blue,
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

  Widget _buildCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white12,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.blue, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const Divider(color: AppColors.white24, height: 20),
          child,
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, {String? hintText}) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      labelStyle: const TextStyle(color: AppColors.white70, fontSize: 13),
      hintStyle: const TextStyle(color: AppColors.white38, fontSize: 12),
      filled: true,
      fillColor: AppColors.white12,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.white24),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.white24),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.blue),
      ),
    );
  }
}
