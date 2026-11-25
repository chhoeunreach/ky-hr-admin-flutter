import 'dart:io';

import 'package:cnattendance/core/theme/app_colors.dart';
import 'package:cnattendance/features/company_documents/company_document_api.dart';
import 'package:cnattendance/features/company_documents/company_document_model.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class SelectedDocFile {
  final File file;
  final String name;
  final bool isPdf;
  final int size;

  SelectedDocFile({
    required this.file,
    required this.name,
    required this.isPdf,
    required this.size,
  });

  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class CompanyDocumentCreateScreen extends StatefulWidget {
  const CompanyDocumentCreateScreen({super.key});

  @override
  State<CompanyDocumentCreateScreen> createState() =>
      _CompanyDocumentCreateScreenState();
}

class _CompanyDocumentCreateScreenState
    extends State<CompanyDocumentCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final CompanyDocumentApi _api = CompanyDocumentApi();
  final ImagePicker _picker = ImagePicker();

  // Form Controllers
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _docNumberController = TextEditingController();
  final TextEditingController _holderNameController = TextEditingController();
  final TextEditingController _authorityController = TextEditingController();
  final TextEditingController _costController = TextEditingController();
  final TextEditingController _receiptNumberController =
      TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  // Selection states
  String _selectedCategory = 'tax';
  String? _selectedSubType;
  int? _selectedBranchId;
  String _selectedCurrency = 'USD';
  DateTime? _issueDate;
  DateTime? _expiryDate;
  int _alertBeforeDays = 30;

  // Selected multi-files
  final List<SelectedDocFile> _selectedFiles = [];

  // Metadata from backend
  List<CompanyDocumentCategoryItem> _categories = [];
  List<CompanyDocumentBranchItem> _branches = [];
  Map<String, List<CompanyDocumentSubTypeItem>> _subTypes = {};
  bool _isLoadingMeta = true;

  @override
  void initState() {
    super.initState();
    _loadMetadata();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _docNumberController.dispose();
    _holderNameController.dispose();
    _authorityController.dispose();
    _costController.dispose();
    _receiptNumberController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadMetadata() async {
    try {
      final meta = await _api.getMeta();
      if (mounted) {
        setState(() {
          _categories =
              meta['categories'] as List<CompanyDocumentCategoryItem>? ?? [];
          _branches =
              meta['branches'] as List<CompanyDocumentBranchItem>? ?? [];
          _subTypes = meta['sub_types']
                  as Map<String, List<CompanyDocumentSubTypeItem>>? ??
              {};
          if (_categories.isNotEmpty &&
              !_categories.any((c) => c.code == _selectedCategory)) {
            _selectedCategory = _categories.first.code;
          }
          _isLoadingMeta = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMeta = false);
      }
    }
  }

  Future<void> _pickCamera() async {
    try {
      final picked =
          await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
      if (picked != null) {
        final file = File(picked.path);
        final size = await file.length();
        setState(() {
          _selectedFiles.add(SelectedDocFile(
            file: file,
            name: picked.name,
            isPdf: false,
            size: size,
          ));
        });
      }
    } catch (e) {
      EasyLoading.showError('Error capturing image: $e');
    }
  }

  Future<void> _pickGallery() async {
    try {
      final pickedList = await _picker.pickMultiImage(imageQuality: 85);
      if (pickedList.isNotEmpty) {
        final List<SelectedDocFile> newItems = [];
        for (final picked in pickedList) {
          final file = File(picked.path);
          final size = await file.length();
          newItems.add(SelectedDocFile(
            file: file,
            name: picked.name,
            isPdf: false,
            size: size,
          ));
        }
        setState(() {
          _selectedFiles.addAll(newItems);
        });
      }
    } catch (e) {
      EasyLoading.showError('Error picking images: $e');
    }
  }

  Future<void> _pickDocuments() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'docx', 'xlsx'],
      );
      if (result != null && result.files.isNotEmpty) {
        final List<SelectedDocFile> newItems = [];
        for (final pf in result.files) {
          if (pf.path != null) {
            final file = File(pf.path!);
            newItems.add(SelectedDocFile(
              file: file,
              name: pf.name,
              isPdf: pf.extension?.toLowerCase() == 'pdf',
              size: pf.size,
            ));
          }
        }
        setState(() {
          _selectedFiles.addAll(newItems);
        });
      }
    } catch (e) {
      EasyLoading.showError('Error selecting files: $e');
    }
  }

  void _previewLocalImage(File file, String name) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            title: Text(name,
                style: const TextStyle(color: Colors.white, fontSize: 15)),
          ),
          body: Center(
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.file(file, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, bool isExpiry) async {
    final initial = isExpiry
        ? (_expiryDate ?? DateTime.now().add(const Duration(days: 365)))
        : (_issueDate ?? DateTime.now());

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2040),
    );

    if (picked != null) {
      setState(() {
        if (isExpiry) {
          _expiryDate = picked;
        } else {
          _issueDate = picked;
        }
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'សូមជ្រើសរើស ឬថតរូបឯកសារយ៉ាងតិច ១ សន្លឹក! (Please attach at least 1 document file)'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      EasyLoading.show(
        status: 'កំពុងបញ្ចូលឯកសារ ${_selectedFiles.length} សន្លឹក...',
        maskType: EasyLoadingMaskType.black,
      );

      double? cost;
      if (_costController.text.trim().isNotEmpty) {
        cost = double.tryParse(_costController.text.trim());
      }

      final issueDateStr = _issueDate != null
          ? DateFormat('yyyy-MM-dd').format(_issueDate!)
          : null;
      final expiryDateStr = _expiryDate != null
          ? DateFormat('yyyy-MM-dd').format(_expiryDate!)
          : null;

      await _api.uploadDocument(
        categoryCode: _selectedCategory,
        docSubType: _selectedSubType,
        title: _titleController.text.trim(),
        holderName: _holderNameController.text.trim().isNotEmpty
            ? _holderNameController.text.trim()
            : null,
        docNumber: _docNumberController.text.trim().isNotEmpty
            ? _docNumberController.text.trim()
            : null,
        branchId: _selectedBranchId,
        issuingAuthority: _authorityController.text.trim().isNotEmpty
            ? _authorityController.text.trim()
            : null,
        issueDate: issueDateStr,
        expiryDate: expiryDateStr,
        alertBeforeDays: _alertBeforeDays,
        costAmount: cost,
        currency: _selectedCurrency,
        receiptNumber: _receiptNumberController.text.trim().isNotEmpty
            ? _receiptNumberController.text.trim()
            : null,
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        files: _selectedFiles.map((s) => s.file).toList(),
      );

      EasyLoading.showSuccess('ឯកសារត្រូវបានបញ្ចូលដោយជោគជ័យ!');
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      EasyLoading.showError(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>() ?? AppColors.light;
    final dateFormat = DateFormat('dd/MM/yyyy');
    final availableSubTypes = _subTypes[_selectedCategory] ?? [];

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          'បញ្ចូលឯកសារថ្មី (Add Document)',
          style: TextStyle(
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
              fontSize: 16),
        ),
        backgroundColor: colors.card,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.close, color: colors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        top: false,
        child: _isLoadingMeta
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // File Upload Area
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colors.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _selectedFiles.isNotEmpty
                              ? colors.primary
                              : Colors.grey.shade300,
                          width: _selectedFiles.isNotEmpty ? 1.5 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.cloud_upload_outlined,
                                      color: colors.primary, size: 22),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'ឯកសារភ្ជាប់ (Attach Documents) *',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14),
                                  ),
                                ],
                              ),
                              if (_selectedFiles.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color:
                                        colors.primary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${_selectedFiles.length} ឯកសារ',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: colors.primary),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_selectedFiles.isNotEmpty) ...[
                            SizedBox(
                              height: 115,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _selectedFiles.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 10),
                                itemBuilder: (context, index) {
                                  final item = _selectedFiles[index];
                                  return Stack(
                                    children: [
                                      InkWell(
                                        onTap: () {
                                          if (!item.isPdf) {
                                            _previewLocalImage(
                                                item.file, item.name);
                                          }
                                        },
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          width: 95,
                                          decoration: BoxDecoration(
                                            color: colors.surface
                                                .withValues(alpha: 0.4),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                                color: Colors.grey.shade300),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              Expanded(
                                                child: ClipRRect(
                                                  borderRadius:
                                                      const BorderRadius
                                                          .vertical(
                                                          top: Radius.circular(
                                                              11)),
                                                  child: !item.isPdf
                                                      ? Image.file(
                                                          item.file,
                                                          fit: BoxFit.cover,
                                                          width: 95,
                                                          errorBuilder:
                                                              (_, __, ___) =>
                                                                  Container(
                                                            color: Colors
                                                                .grey.shade200,
                                                            child: const Icon(
                                                                Icons
                                                                    .broken_image,
                                                                size: 30,
                                                                color: Colors
                                                                    .grey),
                                                          ),
                                                        )
                                                      : Container(
                                                          color: Colors
                                                              .red.shade50,
                                                          width: 95,
                                                          child: const Center(
                                                            child: Icon(
                                                                Icons
                                                                    .picture_as_pdf,
                                                                color:
                                                                    Colors.red,
                                                                size: 36),
                                                          ),
                                                        ),
                                                ),
                                              ),
                                              Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 4,
                                                        vertical: 4),
                                                child: Column(
                                                  children: [
                                                    Text(
                                                      item.name,
                                                      style: const TextStyle(
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.w600),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                    Text(
                                                      item.formattedSize,
                                                      style: TextStyle(
                                                          fontSize: 9,
                                                          color: Colors
                                                              .grey.shade600),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: InkWell(
                                          onTap: () {
                                            setState(() {
                                              _selectedFiles.removeAt(index);
                                            });
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(2),
                                            decoration: const BoxDecoration(
                                              color: Colors.red,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.close,
                                                size: 14, color: Colors.white),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _pickCamera,
                                  icon: const Icon(Icons.camera_alt_outlined,
                                      size: 18),
                                  label: const Text('ថតរូប (Camera)',
                                      style: TextStyle(fontSize: 11)),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _pickGallery,
                                  icon: const Icon(Icons.photo_library_outlined,
                                      size: 18),
                                  label: const Text('រូបភាព (Gallery)',
                                      style: TextStyle(fontSize: 11)),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _pickDocuments,
                                  icon: const Icon(Icons.picture_as_pdf,
                                      size: 18),
                                  label: const Text('PDF / File',
                                      style: TextStyle(fontSize: 11)),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_selectedFiles.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'អាចចុចបន្ថែមរូបភាព ឬទំព័រផ្សេងទៀតបាន',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600),
                                ),
                                TextButton(
                                  onPressed: () {
                                    setState(() => _selectedFiles.clear());
                                  },
                                  style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      visualDensity: VisualDensity.compact),
                                  child: const Text('លុបទាំងអស់',
                                      style: TextStyle(
                                          fontSize: 11, color: Colors.red)),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Metadata Form Container
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colors.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Category Selector
                          const Text('ប្រភេទឯកសារ (Category) *',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedCategory,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            items: _categories.map((cat) {
                              return DropdownMenuItem<String>(
                                value: cat.code,
                                child: Text(cat.name,
                                    style: const TextStyle(fontSize: 13)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedCategory = val;
                                  _selectedSubType = null;
                                });
                              }
                            },
                          ),

                          // Sub-Type Selector (if category has sub-types like master or utility)
                          if (availableSubTypes.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            const Text('ប្រភេទរង (Sub-Type)',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              initialValue: _selectedSubType,
                              decoration: InputDecoration(
                                hintText: '-- ជ្រើសរើសប្រភេទរង --',
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              items: availableSubTypes.map((sub) {
                                return DropdownMenuItem<String>(
                                  value: sub.code,
                                  child: Text(sub.name,
                                      style: const TextStyle(fontSize: 13)),
                                );
                              }).toList(),
                              onChanged: (val) =>
                                  setState(() => _selectedSubType = val),
                            ),
                          ],

                          const SizedBox(height: 14),

                          // Title Field
                          const Text('ចំណងជើងឯកសារ (Document Title) *',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _titleController,
                            decoration: InputDecoration(
                              hintText:
                                  'ឧ. វិក្កយបត្រភ្លើងខែវិច្ឆិកា, កិច្ចសន្យាជួលការិយាល័យ...',
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            validator: (val) =>
                                val == null || val.trim().isEmpty
                                    ? 'សូមបញ្ចូលចំណងជើងឯកសារ'
                                    : null,
                          ),

                          const SizedBox(height: 14),

                          // Holder / Owner & Doc Number Row
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('ម្ចាស់ឯកសារ (Holder)',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13)),
                                    const SizedBox(height: 6),
                                    TextFormField(
                                      controller: _holderNameController,
                                      decoration: InputDecoration(
                                        hintText: 'ឈ្មោះសាមីខ្លួន / ក្រុមហ៊ុន',
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 14, vertical: 10),
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('លេខកូដឯកសារ (Doc No.)',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13)),
                                    const SizedBox(height: 6),
                                    TextFormField(
                                      controller: _docNumberController,
                                      decoration: InputDecoration(
                                        hintText: 'ឧ. TAX-2026-05',
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 14, vertical: 10),
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 14),

                          // Branch Selector
                          const Text('សាខា (Branch)',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<int>(
                            initialValue: _selectedBranchId,
                            decoration: InputDecoration(
                              hintText: 'ក្រុមហ៊ុនមេ / គ្រប់សាខាទាំងអស់',
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            items: [
                              const DropdownMenuItem<int>(
                                value: null,
                                child: Text(
                                    'ក្រុមហ៊ុនមេ / គ្រប់សាខា (Head Office)',
                                    style: TextStyle(fontSize: 13)),
                              ),
                              ..._branches.map((b) => DropdownMenuItem<int>(
                                    value: b.id,
                                    child: Text(b.name,
                                        style: const TextStyle(fontSize: 13)),
                                  )),
                            ],
                            onChanged: (val) =>
                                setState(() => _selectedBranchId = val),
                          ),

                          const SizedBox(height: 14),

                          // Issue Date & Expiry Date Row
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('កាលបរិច្ឆេទចេញ (Issue)',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13)),
                                    const SizedBox(height: 6),
                                    InkWell(
                                      onTap: () => _selectDate(context, false),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 11),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                              color: Colors.grey.shade400),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.calendar_today,
                                                size: 16, color: Colors.grey),
                                            const SizedBox(width: 8),
                                            Text(
                                              _issueDate != null
                                                  ? dateFormat
                                                      .format(_issueDate!)
                                                  : '--/--/----',
                                              style:
                                                  const TextStyle(fontSize: 13),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('កាលបរិច្ឆេទផុត (Expiry)',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13)),
                                    const SizedBox(height: 6),
                                    InkWell(
                                      onTap: () => _selectDate(context, true),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 11),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                              color: Colors.grey.shade400),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.event_busy,
                                                size: 16, color: Colors.red),
                                            const SizedBox(width: 8),
                                            Text(
                                              _expiryDate != null
                                                  ? dateFormat
                                                      .format(_expiryDate!)
                                                  : '--/--/----',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: _expiryDate != null
                                                    ? Colors.red.shade700
                                                    : Colors.black87,
                                                fontWeight: _expiryDate != null
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
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

                          const SizedBox(height: 14),

                          // Cost Amount & Currency Row (Useful for Bills / Tax)
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('ចំនួនទឹកប្រាក់ (Cost Amount)',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13)),
                                    const SizedBox(height: 6),
                                    TextFormField(
                                      controller: _costController,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      decoration: InputDecoration(
                                        hintText: '0.00',
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 14, vertical: 10),
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 1,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('រូបិយប័ណ្ណ',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13)),
                                    const SizedBox(height: 6),
                                    DropdownButtonFormField<String>(
                                      initialValue: _selectedCurrency,
                                      decoration: InputDecoration(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 14, vertical: 10),
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                      ),
                                      items: const [
                                        DropdownMenuItem(
                                            value: 'USD',
                                            child: Text(r'USD ($)')),
                                        DropdownMenuItem(
                                            value: 'KHR',
                                            child: Text('KHR (៛)')),
                                      ],
                                      onChanged: (val) => setState(() =>
                                          _selectedCurrency = val ?? 'USD'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 14),

                          // Description
                          const Text('កំណត់សម្គាល់បន្ថែម (Description)',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _descriptionController,
                            maxLines: 3,
                            decoration: InputDecoration(
                              hintText:
                                  'បញ្ចូលព័ត៌មានលម្អិតបន្ថែមអំពីឯកសារនេះ...',
                              contentPadding: const EdgeInsets.all(12),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Submit Button
                    ElevatedButton(
                      onPressed: _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
                      child: const Text(
                        'រក្សាទុកឯកសារ (Save Document)',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
      ),
    );
  }
}
