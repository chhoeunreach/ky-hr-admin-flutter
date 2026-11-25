import 'package:cnattendance/core/theme/app_colors.dart';
import 'package:cnattendance/model/admin_asset.dart';
import 'package:cnattendance/screen/assetscreen/admin_asset_list_controller.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:cnattendance/widget/radialDecoration.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AdminAssetListScreen extends StatelessWidget {
  const AdminAssetListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(AdminAssetListController());
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
            isKhmer ? 'គ្រប់គ្រងទ្រព្យសម្បត្តិ (Asset)' : 'Asset Management',
            style: TextStyle(color: enterprise.text, fontWeight: FontWeight.bold),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: enterprise.text),
            onPressed: () => Get.back(),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.filter_list_rounded, color: enterprise.text),
              tooltip: 'Filter',
              onPressed: () => _showFilterSheet(context, controller, enterprise),
            ),
          ],
        ),
        floatingActionButton: Obx(() {
          if (!controller.canCreate.value) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            backgroundColor: enterprise.primary,
            foregroundColor: AppColors.white,
            onPressed: controller.onAddAssetClicked,
            icon: const Icon(Icons.add),
            label: Text(
              isKhmer ? 'បន្ថែមទ្រព្យ' : 'Add Asset',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          );
        }),
        body: SafeArea(
          child: Column(
            children: [
              // 1. Search Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: TextField(
                  style: TextStyle(color: enterprise.text),
                  cursorColor: enterprise.primary,
                  decoration: InputDecoration(
                    hintText: isKhmer
                        ? 'ស្វែងរកឈ្មោះ, លេខកូដ, ស៊េរី...'
                        : 'Search by name, code, serial...',
                    hintStyle: TextStyle(color: enterprise.mutedText, fontSize: 13),
                    prefixIcon: Icon(Icons.search, color: enterprise.primary),
                    suffixIcon: Obx(() {
                      if (controller.searchQuery.value.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return IconButton(
                        icon: Icon(Icons.clear, color: enterprise.mutedText),
                        onPressed: () => controller.onSearchChanged(''),
                      );
                    }),
                    filled: true,
                    fillColor: enterprise.isDark ? AppColors.white12 : AppColors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: enterprise.isDark ? enterprise.cardBorder : AppColors.customFFB8DEFF,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: enterprise.isDark ? enterprise.cardBorder : AppColors.customFFB8DEFF,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: enterprise.primary, width: 1.5),
                    ),
                  ),
                  onChanged: controller.onSearchChanged,
                  onSubmitted: controller.onSearchChanged,
                ),
              ),

              // 2. Status Filter Chips
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _statusChip(context, controller, enterprise, 'All', isKhmer ? 'ទាំងអស់' : 'All'),
                    const SizedBox(width: 8),
                    _statusChip(context, controller, enterprise, 'Available', isKhmer ? 'អាចប្រើប្រាស់បាន' : 'Available'),
                    const SizedBox(width: 8),
                    _statusChip(context, controller, enterprise, 'Assigned', isKhmer ? 'បានប្រគល់' : 'Assigned'),
                    const SizedBox(width: 8),
                    _statusChip(context, controller, enterprise, 'Maintenance', isKhmer ? 'កំពុងជួសជុល' : 'Maintenance'),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // 3. Asset List
              Expanded(
                child: Obx(() {
                  if (controller.isLoading.value) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (controller.errorMessage.value != null &&
                      controller.assets.isEmpty) {
                    return RefreshIndicator(
                      onRefresh: () => controller.getAssets(refresh: true),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.45,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.cloud_off_outlined,
                                    size: 64,
                                    color: enterprise.mutedText
                                        .withValues(alpha: 0.5)),
                                const SizedBox(height: 12),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 32),
                                  child: Text(
                                    controller.errorMessage.value!,
                                    textAlign: TextAlign.center,
                                    style:
                                        TextStyle(color: enterprise.mutedText),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: enterprise.primary),
                                  onPressed: () =>
                                      controller.getAssets(refresh: true),
                                  child: Text(
                                    isKhmer ? 'ព្យាយាមម្តងទៀត' : 'Retry',
                                    style: const TextStyle(
                                        color: AppColors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  if (controller.assets.isEmpty) {
                    return RefreshIndicator(
                      onRefresh: () => controller.getAssets(refresh: true),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.45,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.inventory_2_outlined,
                                  size: 64,
                                  color: enterprise.mutedText
                                      .withValues(alpha: 0.5),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  isKhmer
                                      ? 'មិនមានទ្រព្យសម្បត្តិត្រូវបានរកឃើញទេ'
                                      : 'No assets found',
                                  style:
                                      TextStyle(color: enterprise.mutedText),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () => controller.getAssets(refresh: true),
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (ScrollNotification scrollInfo) {
                        if (scrollInfo.metrics.pixels >=
                            scrollInfo.metrics.maxScrollExtent - 80) {
                          controller.loadMore();
                        }
                        return false;
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                        itemCount: controller.assets.length + (controller.isMoreLoading.value ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == controller.assets.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          final asset = controller.assets[index];
                          return _buildAssetCard(context, controller, enterprise, asset);
                        },
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusChip(
    BuildContext context,
    AdminAssetListController controller,
    EnterpriseTheme enterprise,
    String key,
    String label,
  ) {
    return Obx(() {
      final isSelected = controller.selectedStatus.value == key;
      return InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => controller.onStatusChanged(key),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected
                ? enterprise.primary
                : (enterprise.isDark ? AppColors.white12 : AppColors.white),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? enterprise.primary
                  : (enterprise.isDark ? enterprise.cardBorder : AppColors.customFFB8DEFF),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? AppColors.white : enterprise.mutedText,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 12,
            ),
          ),
        ),
      );
    });
  }

  Widget _buildAssetCard(
    BuildContext context,
    AdminAssetListController controller,
    EnterpriseTheme enterprise,
    AdminAsset asset,
  ) {
    final isKhmer = Localizations.localeOf(context).languageCode == 'km';

    Color statusColor = Colors.green;
    String statusText = isKhmer ? 'ទំនេរ' : 'Available';

    if (asset.isWorking == 'no') {
      statusColor = AppColors.orange;
      statusText = isKhmer ? 'ជួសជុល' : 'Maintenance';
    } else if (!asset.isAvailable || asset.assignedTo != null) {
      statusColor = enterprise.primary;
      statusText = isKhmer ? 'បានប្រគល់' : 'Assigned';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => controller.onAssetDetailClicked(asset),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 54,
                  height: 54,
                  color: enterprise.isDark ? AppColors.white12 : const Color(0xFFF1F5F9),
                  child: asset.imageUrl != null && asset.imageUrl!.isNotEmpty
                      ? Image.network(
                          asset.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.inventory_2_outlined,
                            color: enterprise.mutedText,
                            size: 28,
                          ),
                        )
                      : Icon(
                          Icons.inventory_2_outlined,
                          color: enterprise.mutedText,
                          size: 28,
                        ),
                ),
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            asset.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: enterprise.text,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${asset.typeName} · ${asset.branchName}',
                      style: TextStyle(color: enterprise.mutedText, fontSize: 12),
                    ),
                    if (asset.assetCode.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2.0),
                        child: Text(
                          '#${asset.assetCode}',
                          style: TextStyle(color: enterprise.primary, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    if (asset.assignedTo != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: enterprise.primary.withValues(alpha: enterprise.isDark ? 0.2 : 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person, size: 12, color: enterprise.primary),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                asset.assignedTo!.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: enterprise.text,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Actions Popup
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: enterprise.mutedText, size: 20),
                color: enterprise.isDark ? const Color(0xFF1E293B) : AppColors.white,
                onSelected: (value) {
                  if (value == 'view') {
                    controller.onAssetDetailClicked(asset);
                  } else if (value == 'edit') {
                    controller.onEditAssetClicked(asset);
                  } else if (value == 'delete') {
                    _confirmDelete(context, controller, enterprise, asset);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'view',
                    child: Row(
                      children: [
                        Icon(Icons.visibility_outlined, size: 18, color: enterprise.mutedText),
                        const SizedBox(width: 8),
                        Text(isKhmer ? 'មើលលម្អិត' : 'View Detail', style: TextStyle(color: enterprise.text)),
                      ],
                    ),
                  ),
                  if (controller.canEdit.value)
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18, color: enterprise.primary),
                          const SizedBox(width: 8),
                          Text(isKhmer ? 'កែសម្រួល' : 'Edit', style: TextStyle(color: enterprise.text)),
                        ],
                      ),
                    ),
                  if (controller.canDelete.value)
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          const Icon(Icons.delete_outline, size: 18, color: AppColors.red),
                          const SizedBox(width: 8),
                          Text(isKhmer ? 'លុប' : 'Delete', style: const TextStyle(color: AppColors.red)),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    AdminAssetListController controller,
    EnterpriseTheme enterprise,
    AdminAsset asset,
  ) {
    final isKhmer = Localizations.localeOf(context).languageCode == 'km';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: enterprise.isDark ? const Color(0xFF1E293B) : AppColors.white,
        title: Text(
          isKhmer ? 'លុបទ្រព្យសម្បត្តិ?' : 'Delete Asset?',
          style: TextStyle(color: enterprise.text, fontWeight: FontWeight.bold),
        ),
        content: Text(
          isKhmer
              ? 'តើអ្នកប្រាកដជាចង់លុប "${asset.name}" មែនទេ?'
              : 'Are you sure you want to delete "${asset.name}"?',
          style: TextStyle(color: enterprise.mutedText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isKhmer ? 'បោះបង់' : 'Cancel', style: TextStyle(color: enterprise.mutedText)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () {
              Navigator.pop(ctx);
              controller.deleteAsset(asset.id);
            },
            child: Text(isKhmer ? 'លុប' : 'Delete', style: const TextStyle(color: AppColors.white)),
          ),
        ],
      ),
    );
  }

  void _showFilterSheet(
    BuildContext context,
    AdminAssetListController controller,
    EnterpriseTheme enterprise,
  ) {
    final isKhmer = Localizations.localeOf(context).languageCode == 'km';

    showModalBottomSheet(
      context: context,
      backgroundColor: enterprise.isDark ? const Color(0xFF0F172A) : AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune_rounded, color: enterprise.primary),
                const SizedBox(width: 8),
                Text(
                  isKhmer ? 'ចម្រាញ់ទិន្នន័យ (Filters)' : 'Filter Assets',
                  style: TextStyle(
                    color: enterprise.text,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    controller.onBranchFilterChanged(null);
                    controller.onTypeFilterChanged(null);
                    Navigator.pop(ctx);
                  },
                  child: Text(isKhmer ? 'កំណត់ឡើងវិញ' : 'Reset', style: TextStyle(color: enterprise.primary)),
                ),
              ],
            ),
            Divider(color: enterprise.isDark ? enterprise.cardBorder : AppColors.customFFB8DEFF),
            const SizedBox(height: 10),

            // Branch filter
            DropdownButtonFormField<int>(
              value: controller.branches
                      .any((b) => b.id == controller.selectedBranchId.value)
                  ? controller.selectedBranchId.value
                  : null,
              dropdownColor: enterprise.isDark ? const Color(0xFF1E293B) : AppColors.white,
              style: TextStyle(color: enterprise.text),
              decoration: InputDecoration(
                labelText: isKhmer ? 'ជ្រើសរើសសាខា (Branch)' : 'Filter by Branch',
                labelStyle: TextStyle(color: enterprise.mutedText),
                filled: true,
                fillColor: enterprise.isDark ? AppColors.white12 : const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: enterprise.isDark ? enterprise.cardBorder : AppColors.customFFB8DEFF),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: enterprise.isDark ? enterprise.cardBorder : AppColors.customFFB8DEFF),
                ),
              ),
              items: [
                DropdownMenuItem<int>(
                  value: null,
                  child: Text(isKhmer ? 'សាខាទាំងអស់ (All Branches)' : 'All Branches', style: TextStyle(color: enterprise.text)),
                ),
                ...controller.branches.map((b) => DropdownMenuItem(
                      value: b.id,
                      child: Text(b.name, style: TextStyle(color: enterprise.text)),
                    )),
              ],
              onChanged: (v) {
                controller.onBranchFilterChanged(v);
                Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: 14),

            // Type filter
            DropdownButtonFormField<int>(
              value: controller.types
                      .any((t) => t.id == controller.selectedTypeId.value)
                  ? controller.selectedTypeId.value
                  : null,
              dropdownColor: enterprise.isDark ? const Color(0xFF1E293B) : AppColors.white,
              style: TextStyle(color: enterprise.text),
              decoration: InputDecoration(
                labelText: isKhmer ? 'ជ្រើសរើសប្រភេទ (Type)' : 'Filter by Type',
                labelStyle: TextStyle(color: enterprise.mutedText),
                filled: true,
                fillColor: enterprise.isDark ? AppColors.white12 : const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: enterprise.isDark ? enterprise.cardBorder : AppColors.customFFB8DEFF),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: enterprise.isDark ? enterprise.cardBorder : AppColors.customFFB8DEFF),
                ),
              ),
              items: [
                DropdownMenuItem<int>(
                  value: null,
                  child: Text(isKhmer ? 'ប្រភេទទាំងអស់ (All Types)' : 'All Types', style: TextStyle(color: enterprise.text)),
                ),
                ...controller.types.map((t) => DropdownMenuItem(
                      value: t.id,
                      child: Text(t.name, style: TextStyle(color: enterprise.text)),
                    )),
              ],
              onChanged: (v) {
                controller.onTypeFilterChanged(v);
                Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
