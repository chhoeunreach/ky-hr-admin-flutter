import 'package:cnattendance/core/theme/app_colors.dart';
import 'package:cnattendance/model/admin_asset.dart';
import 'package:cnattendance/screen/assetscreen/admin_asset_list_controller.dart';
import 'package:cnattendance/widget/radialDecoration.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AdminAssetListScreen extends StatelessWidget {
  const AdminAssetListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(AdminAssetListController());
    final isKhmer = Localizations.localeOf(context).languageCode == 'km';

    return Container(
      decoration: RadialDecoration(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            isKhmer ? 'គ្រប់គ្រងទ្រព្យសម្បត្តិ (Asset)' : 'Asset Management',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Get.back(),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.filter_list_rounded),
              tooltip: 'Filter',
              onPressed: () => _showFilterSheet(context, controller),
            ),
          ],
        ),
        floatingActionButton: Obx(() {
          if (!controller.canCreate.value) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            backgroundColor: AppColors.blue,
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
                  style: const TextStyle(color: AppColors.white),
                  decoration: InputDecoration(
                    hintText: isKhmer
                        ? 'ស្វែងរកឈ្មោះ, លេខកូដ, ស៊េរី...'
                        : 'Search by name, code, serial...',
                    hintStyle: const TextStyle(color: AppColors.white38, fontSize: 13),
                    prefixIcon: const Icon(Icons.search, color: AppColors.white70),
                    suffixIcon: Obx(() {
                      if (controller.searchQuery.value.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return IconButton(
                        icon: const Icon(Icons.clear, color: AppColors.white70),
                        onPressed: () => controller.onSearchChanged(''),
                      );
                    }),
                    filled: true,
                    fillColor: AppColors.white12,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.white24),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.blue),
                    ),
                  ),
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
                    _statusChip(context, controller, 'All', isKhmer ? 'ទាំងអស់' : 'All'),
                    const SizedBox(width: 8),
                    _statusChip(context, controller, 'Available', isKhmer ? 'អាចប្រើប្រាស់បាន' : 'Available'),
                    const SizedBox(width: 8),
                    _statusChip(context, controller, 'Assigned', isKhmer ? 'បានប្រគល់' : 'Assigned'),
                    const SizedBox(width: 8),
                    _statusChip(context, controller, 'Maintenance', isKhmer ? 'កំពុងជួសជុល' : 'Maintenance'),
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

                  if (controller.assets.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.inventory_2_outlined,
                            size: 64,
                            color: AppColors.white38,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            isKhmer
                                ? 'មិនមានទ្រព្យសម្បត្តិត្រូវបានរកឃើញទេ'
                                : 'No assets found',
                            style: const TextStyle(color: AppColors.white70),
                          ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () => controller.getAssets(refresh: true),
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (ScrollNotification scrollInfo) {
                        if (scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
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
                          return _buildAssetCard(context, controller, asset);
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
            color: isSelected ? AppColors.blue : AppColors.white12,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppColors.blue : AppColors.white24,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? AppColors.white : AppColors.white70,
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
    AdminAsset asset,
  ) {
    final isKhmer = Localizations.localeOf(context).languageCode == 'km';

    Color statusColor = Colors.green;
    String statusText = isKhmer ? 'ទំនេរ' : 'Available';

    if (asset.isWorking == 'no') {
      statusColor = AppColors.orange;
      statusText = isKhmer ? 'ជួសជុល' : 'Maintenance';
    } else if (asset.assignedTo != null) {
      statusColor = AppColors.blue;
      statusText = isKhmer ? 'បានប្រគល់' : 'Assigned';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.white12,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.white24),
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
                  color: AppColors.white12,
                  child: asset.imageUrl != null && asset.imageUrl!.isNotEmpty
                      ? Image.network(
                          asset.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.inventory_2_outlined,
                            color: AppColors.white70,
                            size: 28,
                          ),
                        )
                      : const Icon(
                          Icons.inventory_2_outlined,
                          color: AppColors.white70,
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
                            style: const TextStyle(
                              color: AppColors.white,
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
                      style: const TextStyle(color: AppColors.white70, fontSize: 12),
                    ),
                    if (asset.assetCode.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2.0),
                        child: Text(
                          '#${asset.assetCode}',
                          style: const TextStyle(color: AppColors.blue, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    if (asset.assignedTo != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.blue.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.person, size: 12, color: AppColors.blue),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                asset.assignedTo!.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.white,
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
                icon: const Icon(Icons.more_vert, color: AppColors.white70, size: 20),
                color: const Color(0xFF1E293B),
                onSelected: (value) {
                  if (value == 'view') {
                    controller.onAssetDetailClicked(asset);
                  } else if (value == 'edit') {
                    controller.onEditAssetClicked(asset);
                  } else if (value == 'delete') {
                    _confirmDelete(context, controller, asset);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'view',
                    child: Row(
                      children: [
                        const Icon(Icons.visibility_outlined, size: 18, color: AppColors.white70),
                        const SizedBox(width: 8),
                        Text(isKhmer ? 'មើលលម្អិត' : 'View Detail', style: const TextStyle(color: AppColors.white)),
                      ],
                    ),
                  ),
                  if (controller.canEdit.value)
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          const Icon(Icons.edit_outlined, size: 18, color: AppColors.blue),
                          const SizedBox(width: 8),
                          Text(isKhmer ? 'កែសម្រួល' : 'Edit', style: const TextStyle(color: AppColors.white)),
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
    AdminAsset asset,
  ) {
    final isKhmer = Localizations.localeOf(context).languageCode == 'km';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(
          isKhmer ? 'លុបទ្រព្យសម្បត្តិ?' : 'Delete Asset?',
          style: const TextStyle(color: AppColors.white),
        ),
        content: Text(
          isKhmer
              ? 'តើអ្នកប្រាកដជាចង់លុប "${asset.name}" មែនទេ?'
              : 'Are you sure you want to delete "${asset.name}"?',
          style: const TextStyle(color: AppColors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isKhmer ? 'បោះបង់' : 'Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () {
              Navigator.pop(ctx);
              controller.deleteAsset(asset.id);
            },
            child: Text(isKhmer ? 'លុប' : 'Delete'),
          ),
        ],
      ),
    );
  }

  void _showFilterSheet(
    BuildContext context,
    AdminAssetListController controller,
  ) {
    final isKhmer = Localizations.localeOf(context).languageCode == 'km';

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
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
                const Icon(Icons.tune_rounded, color: AppColors.blue),
                const SizedBox(width: 8),
                Text(
                  isKhmer ? 'ចម្រាញ់ទិន្នន័យ (Filters)' : 'Filter Assets',
                  style: const TextStyle(
                    color: AppColors.white,
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
                  child: Text(isKhmer ? 'កំណត់ឡើងវិញ' : 'Reset'),
                ),
              ],
            ),
            const Divider(color: AppColors.white24),
            const SizedBox(height: 10),

            // Branch filter
            DropdownButtonFormField<int>(
              value: controller.selectedBranchId.value,
              dropdownColor: const Color(0xFF1E293B),
              style: const TextStyle(color: AppColors.white),
              decoration: InputDecoration(
                labelText: isKhmer ? 'ជ្រើសរើសសាខា (Branch)' : 'Filter by Branch',
                labelStyle: const TextStyle(color: AppColors.white70),
                filled: true,
                fillColor: AppColors.white12,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              items: [
                DropdownMenuItem<int>(
                  value: null,
                  child: Text(isKhmer ? 'សាខាទាំងអស់ (All Branches)' : 'All Branches'),
                ),
                ...controller.branches.map((b) => DropdownMenuItem(
                      value: b.id,
                      child: Text(b.name),
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
              value: controller.selectedTypeId.value,
              dropdownColor: const Color(0xFF1E293B),
              style: const TextStyle(color: AppColors.white),
              decoration: InputDecoration(
                labelText: isKhmer ? 'ជ្រើសរើសប្រភេទ (Type)' : 'Filter by Type',
                labelStyle: const TextStyle(color: AppColors.white70),
                filled: true,
                fillColor: AppColors.white12,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              items: [
                DropdownMenuItem<int>(
                  value: null,
                  child: Text(isKhmer ? 'ប្រភេទទាំងអស់ (All Types)' : 'All Types'),
                ),
                ...controller.types.map((t) => DropdownMenuItem(
                      value: t.id,
                      child: Text(t.name),
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
