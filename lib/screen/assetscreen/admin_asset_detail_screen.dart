import 'package:cnattendance/core/theme/app_colors.dart';
import 'package:cnattendance/model/admin_asset.dart';
import 'package:cnattendance/repositories/admin_asset_repository.dart';
import 'package:cnattendance/screen/assetscreen/admin_asset_form_screen.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:cnattendance/utils/asset_permissions.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:cnattendance/widget/radialDecoration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:gallery_image_viewer/gallery_image_viewer.dart';
import 'package:get/get.dart';

class AdminAssetDetailScreen extends StatefulWidget {
  final int assetId;

  const AdminAssetDetailScreen({super.key, required this.assetId});

  @override
  State<AdminAssetDetailScreen> createState() => _AdminAssetDetailScreenState();
}

class _AdminAssetDetailScreenState extends State<AdminAssetDetailScreen> {
  final repository = AdminAssetRepository();

  AdminAsset? _asset;
  bool _isLoading = true;
  String? _error;
  int _selectedPhotoIndex = 0;
  bool _canEdit = false;
  bool _canDelete = false;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
    _loadDetail();
  }

  Future<void> _loadPermissions() async {
    final result = await AssetPermissions.crud();
    if (!mounted) return;
    setState(() {
      _canEdit = result.edit;
      _canDelete = result.delete;
    });
  }

  Future<void> _loadDetail() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final data = await repository.getAssetDetail(widget.assetId);
      if (!mounted) return;
      setState(() {
        _asset = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = unknownError(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _confirmDelete(EnterpriseTheme enterprise) async {
    final isKhmer = Localizations.localeOf(context).languageCode == 'km';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: enterprise.isDark ? const Color(0xFF1E293B) : AppColors.white,
        title: Text(
          isKhmer ? 'លុបទ្រព្យសម្បត្តិ?' : 'Delete Asset?',
          style: TextStyle(color: enterprise.text, fontWeight: FontWeight.bold),
        ),
        content: Text(
          isKhmer
              ? 'តើអ្នកប្រាកដជាចង់លុបទ្រព្យសម្បត្តិនេះមែនទេ? សកម្មភាពនេះមិនអាចត្រឡប់វិញបានទេ។'
              : 'Are you sure you want to delete this asset? This action cannot be undone.',
          style: TextStyle(color: enterprise.mutedText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isKhmer ? 'បោះបង់' : 'Cancel', style: TextStyle(color: enterprise.mutedText)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isKhmer ? 'លុប' : 'Delete', style: const TextStyle(color: AppColors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      EasyLoading.show(status: 'Deleting...', maskType: EasyLoadingMaskType.black);
      final (success, message) = await repository.deleteAsset(widget.assetId);
      EasyLoading.dismiss(animation: true);
      if (!mounted) return;
      if (success) {
        Get.back(result: true);
      } else {
        showToast(message);
      }
    }
  }

  Future<void> _openEdit() async {
    try {
      final formData = await repository.getFormData();
      if (!mounted) return;
      final updated = await Get.to(
        () => AdminAssetFormScreen(
          asset: _asset,
          types: formData.types,
          branches: formData.branches,
          employees: formData.employees,
        ),
        transition: Transition.cupertino,
      );
      if (updated == true && mounted) {
        _loadDetail();
      }
    } catch (e) {
      if (!mounted) return;
      showToast(unknownError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final enterprise = EnterpriseTheme.of(context);
    final isKhmer = Localizations.localeOf(context).languageCode == 'km';

    return Container(
      decoration: RadialDecoration(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: enterprise.text),
          title: Text(
            isKhmer ? 'ព័ត៌មានលម្អិតទ្រព្យសម្បត្តិ' : 'Asset Details',
            style: TextStyle(color: enterprise.text, fontWeight: FontWeight.bold),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: enterprise.text),
            onPressed: () => Get.back(),
          ),
          actions: [
            if (_asset != null) ...[
              if (_canEdit)
                IconButton(
                  icon: Icon(Icons.edit_outlined, color: enterprise.primary),
                  tooltip: 'Edit',
                  onPressed: _openEdit,
                ),
              if (_canDelete)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.red),
                  tooltip: 'Delete',
                  onPressed: () => _confirmDelete(enterprise),
                ),
            ],
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_error!, style: TextStyle(color: enterprise.mutedText)),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: enterprise.primary),
                          onPressed: _loadDetail,
                          child: Text(isKhmer ? 'ព្យាយាមម្តងទៀត' : 'Retry', style: const TextStyle(color: AppColors.white)),
                        ),
                      ],
                    ),
                  )
                : _buildContent(context, enterprise, _asset!),
      ),
    );
  }

  Widget _buildContent(BuildContext context, EnterpriseTheme enterprise, AdminAsset a) {
    final isKhmer = Localizations.localeOf(context).languageCode == 'km';

    Color statusColor = Colors.green;
    String statusText = isKhmer ? 'អាចប្រើប្រាស់បាន' : 'Available';

    if (a.isWorking == 'no') {
      statusColor = AppColors.orange;
      statusText = isKhmer ? 'កំពុងជួសជុល / ខូច' : 'Maintenance';
    } else if (!a.isAvailable || a.assignedTo != null) {
      statusColor = enterprise.primary;
      statusText = isKhmer ? 'បានប្រគល់ជូនបុគ្គលិក' : 'Assigned';
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        // 1. Multi-photo Gallery & Preview
        Builder(
          builder: (context) {
            final allImages = <String>[];
            if (a.imageUrl != null && a.imageUrl!.isNotEmpty) {
              allImages.add(a.imageUrl!);
            }
            for (final img in a.images) {
              if (img.isNotEmpty && !allImages.contains(img)) {
                allImages.add(img);
              }
            }

            if (allImages.isEmpty) {
              return const SizedBox.shrink();
            }

            final currentIdx = (_selectedPhotoIndex < allImages.length) ? _selectedPhotoIndex : 0;
            final currentUrl = allImages[currentIdx];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        height: 220,
                        width: double.infinity,
                        color: enterprise.isDark ? AppColors.white12 : const Color(0xFFF1F5F9),
                        child: InkWell(
                          onTap: () {
                            showImageViewer(
                              context,
                              NetworkImage(currentUrl),
                              swipeDismissible: true,
                            );
                          },
                          child: Image.network(
                            currentUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Center(
                              child: Icon(Icons.inventory_2_outlined, size: 64, color: enterprise.mutedText),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (allImages.length > 1)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.photo_library, size: 13, color: AppColors.white),
                              const SizedBox(width: 5),
                              Text(
                                '${currentIdx + 1}/${allImages.length}',
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Positioned(
                      bottom: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.zoom_in, size: 18, color: AppColors.white),
                      ),
                    ),
                  ],
                ),
                if (allImages.length > 1) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 64,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: allImages.length,
                      itemBuilder: (context, idx) {
                        final isSelected = idx == currentIdx;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedPhotoIndex = idx;
                            });
                          },
                          child: Container(
                            width: 64,
                            height: 64,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? enterprise.primary
                                    : (enterprise.isDark ? enterprise.cardBorder : AppColors.customFFB8DEFF),
                                width: isSelected ? 2.5 : 1.0,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                allImages[idx],
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(
                                  Icons.broken_image_outlined,
                                  size: 20,
                                  color: enterprise.mutedText,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 14),
              ],
            );
          },
        ),

        // 2. Title & Status Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: enterprise.isDark ? AppColors.white12 : AppColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: enterprise.isDark ? enterprise.cardBorder : AppColors.customFFB8DEFF,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withValues(alpha: enterprise.isDark ? 0.12 : 0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.name,
                          style: TextStyle(
                            color: enterprise.text,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (a.assetCode.isNotEmpty)
                          Text(
                            'Code: #${a.assetCode}',
                            style: TextStyle(
                              color: enterprise.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              Divider(
                color: enterprise.isDark ? enterprise.cardBorder : AppColors.customFFB8DEFF,
                height: 24,
              ),
              Row(
                children: [
                  _infoChip(enterprise, Icons.category_outlined, a.typeName),
                  const SizedBox(width: 8),
                  _infoChip(enterprise, Icons.storefront_outlined, a.branchName),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 3. Current Holder Card
        if (a.assignedTo != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: enterprise.primary.withValues(alpha: enterprise.isDark ? 0.15 : 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: enterprise.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: enterprise.primary,
                  child: a.assignedTo!.avatar != null &&
                          a.assignedTo!.avatar!.isNotEmpty
                      ? ClipOval(
                          child: Image.network(
                            a.assignedTo!.avatar!,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                                Icons.person,
                                color: AppColors.white),
                          ),
                        )
                      : const Icon(Icons.person, color: AppColors.white),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isKhmer ? 'បុគ្គលិកកំពុងកាន់កាប់' : 'Current Holder',
                        style: TextStyle(color: enterprise.mutedText, fontSize: 11),
                      ),
                      Text(
                        a.assignedTo!.name,
                        style: TextStyle(
                          color: enterprise.text,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (a.assignedTo!.assignedDate.isNotEmpty)
                        Text(
                          '${isKhmer ? 'កាលបរិច្ឆេទប្រគល់' : 'Assigned'}: ${a.assignedTo!.assignedDate}',
                          style: TextStyle(color: enterprise.mutedText, fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // 4. Specifications Grid
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: enterprise.isDark ? AppColors.white12 : AppColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: enterprise.isDark ? enterprise.cardBorder : AppColors.customFFB8DEFF,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withValues(alpha: enterprise.isDark ? 0.12 : 0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isKhmer ? 'លក្ខណៈបច្ចេកទេស & ទិន្នន័យ' : 'Specifications',
                style: TextStyle(
                  color: enterprise.text,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              Divider(
                color: enterprise.isDark ? enterprise.cardBorder : AppColors.customFFB8DEFF,
                height: 20,
              ),
              _specRow(enterprise, isKhmer ? 'លេខស៊េរី (Serial No)' : 'Serial Number', a.assetSerialNo.isEmpty ? 'N/A' : a.assetSerialNo),
              _specRow(enterprise, isKhmer ? 'កាលបរិច្ឆេទជាវ' : 'Purchased Date', a.purchasedDate.isEmpty ? 'N/A' : a.purchasedDate),
              _specRow(
                enterprise,
                isKhmer ? 'ការធានា' : 'Warranty',
                a.warrantyAvailable
                    ? (isKhmer
                        ? 'មាន (ផុតកំណត់: ${a.warrantyEndDate ?? 'N/A'})'
                        : 'Active (Until: ${a.warrantyEndDate ?? 'N/A'})')
                    : (isKhmer ? 'គ្មានការធានា' : 'No Warranty'),
              ),
              if (a.phoneNumbers.isNotEmpty)
                _specRow(enterprise, isKhmer ? 'លេខទូរស័ព្ទប្រើប្រាស់' : 'Phone Numbers', a.phoneNumbers),
              if (a.icloud.isNotEmpty)
                _specRow(enterprise, 'iCloud / Account', a.icloud),
              if (a.note.isNotEmpty)
                _specRow(enterprise, isKhmer ? 'កំណត់ចំណាំ' : 'Description / Note', a.note),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 5. Assignment History Timeline
        if (a.assignmentHistory.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: enterprise.isDark ? AppColors.white12 : AppColors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: enterprise.isDark ? enterprise.cardBorder : AppColors.customFFB8DEFF,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.black.withValues(alpha: enterprise.isDark ? 0.12 : 0.04),
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
                    Icon(Icons.history_rounded, color: enterprise.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      isKhmer ? 'ប្រវត្តិការប្រគល់ជូនបុគ្គលិក' : 'Assignment History',
                      style: TextStyle(
                        color: enterprise.text,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                Divider(
                  color: enterprise.isDark ? enterprise.cardBorder : AppColors.customFFB8DEFF,
                  height: 20,
                ),
                ...a.assignmentHistory.map((h) => Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: h.returnedDate == null ? Colors.green : enterprise.mutedText,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  h.employeeName,
                                  style: TextStyle(
                                    color: enterprise.text,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  '${h.assignedDate} ➔ ${h.returnedDate ?? (isKhmer ? 'កំពុងកាន់កាប់' : 'Current')}',
                                  style: TextStyle(color: enterprise.mutedText, fontSize: 12),
                                ),
                                if (h.notes != null && h.notes!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2.0),
                                    child: Text(
                                      'Note: ${h.notes}',
                                      style: TextStyle(color: enterprise.mutedText, fontSize: 11),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _infoChip(EnterpriseTheme enterprise, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: enterprise.primary.withValues(alpha: enterprise.isDark ? 0.2 : 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: enterprise.primary),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(color: enterprise.text, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _specRow(EnterpriseTheme enterprise, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(color: enterprise.mutedText, fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: enterprise.text,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
