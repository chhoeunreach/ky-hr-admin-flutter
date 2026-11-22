import 'package:cnattendance/core/theme/app_colors.dart';
import 'package:cnattendance/model/admin_asset.dart';
import 'package:cnattendance/repositories/admin_asset_repository.dart';
import 'package:cnattendance/screen/assetscreen/admin_asset_form_screen.dart';
import 'package:cnattendance/widget/radialDecoration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
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

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await repository.getAssetDetail(widget.assetId);
      setState(() {
        _asset = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _confirmDelete() async {
    final isKhmer = Localizations.localeOf(context).languageCode == 'km';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(
          isKhmer ? 'លុបទ្រព្យសម្បត្តិ?' : 'Delete Asset?',
          style: const TextStyle(color: AppColors.white),
        ),
        content: Text(
          isKhmer
              ? 'តើអ្នកប្រាកដជាចង់លុបទ្រព្យសម្បត្តិនេះមែនទេ? សកម្មភាពនេះមិនអាចត្រឡប់វិញបានទេ។'
              : 'Are you sure you want to delete this asset? This action cannot be undone.',
          style: const TextStyle(color: AppColors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isKhmer ? 'បោះបង់' : 'Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isKhmer ? 'លុប' : 'Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      EasyLoading.show(status: 'Deleting...', maskType: EasyLoadingMaskType.black);
      final (success, message) = await repository.deleteAsset(widget.assetId);
      EasyLoading.dismiss(animation: true);
      if (success) {
        Get.back(result: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isKhmer = Localizations.localeOf(context).languageCode == 'km';

    return Container(
      decoration: RadialDecoration(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            isKhmer ? 'ព័ត៌មានលម្អិតទ្រព្យសម្បត្តិ' : 'Asset Details',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Get.back(),
          ),
          actions: [
            if (_asset != null) ...[
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: AppColors.white),
                tooltip: 'Edit',
                onPressed: () async {
                  final formData = await repository.getFormData();
                  final updated = await Get.to(
                    () => AdminAssetFormScreen(
                      asset: _asset,
                      types: formData.types,
                      branches: formData.branches,
                      employees: formData.employees,
                    ),
                    transition: Transition.cupertino,
                  );
                  if (updated == true) {
                    _loadDetail();
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.red),
                tooltip: 'Delete',
                onPressed: _confirmDelete,
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
                        Text(_error!, style: const TextStyle(color: AppColors.white70)),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _loadDetail,
                          child: Text(isKhmer ? 'ព្យាយាមម្តងទៀត' : 'Retry'),
                        ),
                      ],
                    ),
                  )
                : _buildContent(context, _asset!),
      ),
    );
  }

  Widget _buildContent(BuildContext context, AdminAsset a) {
    final isKhmer = Localizations.localeOf(context).languageCode == 'km';

    Color statusColor = Colors.green;
    String statusText = isKhmer ? 'អាចប្រើប្រាស់បាន' : 'Available';

    if (a.isWorking == 'no') {
      statusColor = AppColors.orange;
      statusText = isKhmer ? 'កំពុងជួសជុល / ខូច' : 'Maintenance';
    } else if (a.assignedTo != null) {
      statusColor = AppColors.blue;
      statusText = isKhmer ? 'បានប្រគល់ជូនបុគ្គលិក' : 'Assigned';
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        // 1. Cover Image & Status Badge
        if (a.imageUrl != null && a.imageUrl!.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 200,
              width: double.infinity,
              color: AppColors.white12,
              child: Image.network(
                a.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.white38),
                ),
              ),
            ),
          ),
        const SizedBox(height: 16),

        // 2. Title & Status Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white12,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.white24),
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
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (a.assetCode.isNotEmpty)
                          Text(
                            'Code: #${a.assetCode}',
                            style: const TextStyle(
                              color: AppColors.blue,
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
              const Divider(color: AppColors.white24, height: 24),
              Row(
                children: [
                  _infoChip(Icons.category_outlined, a.typeName),
                  const SizedBox(width: 8),
                  _infoChip(Icons.storefront_outlined, a.branchName),
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
              color: AppColors.blue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.blue.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.blue,
                  backgroundImage: a.assignedTo!.avatar != null
                      ? NetworkImage(a.assignedTo!.avatar!)
                      : null,
                  child: a.assignedTo!.avatar == null
                      ? const Icon(Icons.person, color: AppColors.white)
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isKhmer ? 'បុគ្គលិកកំពុងកាន់កាប់' : 'Current Holder',
                        style: const TextStyle(color: AppColors.white70, fontSize: 11),
                      ),
                      Text(
                        a.assignedTo!.name,
                        style: const TextStyle(
                          color: AppColors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (a.assignedTo!.assignedDate.isNotEmpty)
                        Text(
                          '${isKhmer ? 'កាលបរិច្ឆេទប្រគល់' : 'Assigned'}: ${a.assignedTo!.assignedDate}',
                          style: const TextStyle(color: AppColors.white54, fontSize: 12),
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
            color: AppColors.white12,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.white24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isKhmer ? 'លក្ខណៈបច្ចេកទេស & ទិន្នន័យ' : 'Specifications',
                style: const TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const Divider(color: AppColors.white24, height: 20),
              _specRow(isKhmer ? 'លេខស៊េរី (Serial No)' : 'Serial Number', a.assetSerialNo.isEmpty ? 'N/A' : a.assetSerialNo),
              _specRow(isKhmer ? 'កាលបរិច្ឆេទជាវ' : 'Purchased Date', a.purchasedDate.isEmpty ? 'N/A' : a.purchasedDate),
              _specRow(
                isKhmer ? 'ការធានា' : 'Warranty',
                a.warrantyAvailable
                    ? (isKhmer
                        ? 'មាន (ផុតកំណត់: ${a.warrantyEndDate ?? 'N/A'})'
                        : 'Active (Until: ${a.warrantyEndDate ?? 'N/A'})')
                    : (isKhmer ? 'គ្មានការធានា' : 'No Warranty'),
              ),
              if (a.phoneNumbers.isNotEmpty)
                _specRow(isKhmer ? 'លេខទូរស័ព្ទប្រើប្រាស់' : 'Phone Numbers', a.phoneNumbers),
              if (a.icloud.isNotEmpty)
                _specRow('iCloud / Account', a.icloud),
              if (a.note.isNotEmpty)
                _specRow(isKhmer ? 'កំណត់ចំណាំ' : 'Description / Note', a.note),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 5. Assignment History Timeline
        if (a.assignmentHistory.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
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
                    const Icon(Icons.history_rounded, color: AppColors.blue, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      isKhmer ? 'ប្រវត្តិការប្រគល់ជូនបុគ្គលិក' : 'Assignment History',
                      style: const TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                const Divider(color: AppColors.white24, height: 20),
                ...a.assignmentHistory.map((h) => Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 3),
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: h.returnedDate == null ? Colors.green : AppColors.white38,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  h.employeeName,
                                  style: const TextStyle(
                                    color: AppColors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  '${h.assignedDate} ➔ ${h.returnedDate ?? (isKhmer ? 'កំពុងកាន់កាប់' : 'Current')}',
                                  style: const TextStyle(color: AppColors.white54, fontSize: 12),
                                ),
                                if (h.notes != null && h.notes!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2.0),
                                    child: Text(
                                      'Note: ${h.notes}',
                                      style: const TextStyle(color: AppColors.white70, fontSize: 11),
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

  Widget _infoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.white12,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.white70),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(color: AppColors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _specRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.white70, fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
