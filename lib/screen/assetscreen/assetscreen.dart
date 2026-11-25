import 'package:cnattendance/data/source/network/model/asssetlistresponse/assetlistresponse.dart';
import 'package:cnattendance/screen/assetscreen/admin_asset_list_screen.dart';
import 'package:cnattendance/screen/assetscreen/assetscontroller.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:get/get.dart';

import '../../widget/profile/asset_bottom_sheet.dart';
import '../../widget/radialDecoration.dart';
import 'package:cnattendance/core/theme/app_colors.dart';
import 'package:cnattendance/utils/asset_permissions.dart';

class AssetScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final model = Get.put(AssetController());
    final enterprise = EnterpriseTheme.of(context);
    final adminGateFuture = AssetPermissions.canOpenAdminAsync();

    return Container(
      decoration: RadialDecoration(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          iconTheme: IconThemeData(color: enterprise.text),
          title: Text(
            translate('common.assets'),
            style: TextStyle(
              color: enterprise.text,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            FutureBuilder<bool>(
              future: adminGateFuture,
              builder: (context, snapshot) {
                if (snapshot.data != true) return const SizedBox.shrink();
                return IconButton(
                  icon: Icon(Icons.admin_panel_settings_outlined, color: enterprise.text),
                  tooltip: 'Admin Asset Management',
                  onPressed: () => Get.to(
                    () => const AdminAssetListScreen(),
                    transition: Transition.cupertino,
                  ),
                );
              },
            ),
          ],
        ),
        body: Obx(
          () => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 8.0),
            child: _buildBody(context, model, enterprise),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AssetController model,
    EnterpriseTheme enterprise,
  ) {
    if (model.isLoading.value && model.assets.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (model.errorMessage.value != null && model.assets.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => model.getAssets(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.4,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_off_outlined,
                      size: 56, color: enterprise.mutedText.withValues(alpha: 0.6)),
                  const SizedBox(height: 12),
                  Text(
                    model.errorMessage.value ?? 'Something went wrong',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: enterprise.mutedText),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: enterprise.primary,
                    ),
                    onPressed: model.getAssets,
                    child: const Text('Retry',
                        style: TextStyle(color: AppColors.white)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await model.getAssets();
      },
      child: model.assets.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.4,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined,
                          size: 56,
                          color: enterprise.mutedText.withValues(alpha: 0.5)),
                      const SizedBox(height: 12),
                      Text(
                        translate('common.assets'),
                        style: TextStyle(color: enterprise.mutedText),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: model.assets.length,
              itemBuilder: (context, index) {
                final asset = model.assets[index];
                final isReturned =
                    asset.notes != null && asset.notes!.trim().isNotEmpty;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color:
                        enterprise.isDark ? AppColors.white12 : AppColors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: enterprise.isDark
                          ? enterprise.cardBorder
                          : AppColors.customFFB8DEFF,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.black.withValues(
                            alpha: enterprise.isDark ? 0.12 : 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _openBottomSheet(context, asset),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: enterprise.primary
                                  .withValues(alpha: enterprise.isDark ? 0.2 : 0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.inventory_2_outlined,
                              color: enterprise.primary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  asset.assignedDate,
                                  style: TextStyle(
                                      color: enterprise.mutedText,
                                      fontSize: 12,
                                      fontWeight: FontWeight.normal),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  asset.asset,
                                  style: TextStyle(
                                      color: enterprise.text,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isReturned
                                    ? enterprise.primary.withValues(alpha: .3)
                                    : enterprise.primary,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                visualDensity: VisualDensity.compact,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () => _openBottomSheet(context, asset),
                              child: Text(
                                isReturned ? "Returned" : 'Return',
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ))
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _openBottomSheet(BuildContext context, AssetData asset) {
    showModalBottomSheet(
        elevation: 0,
        backgroundColor: Colors.transparent,
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20), topRight: Radius.circular(20))),
        builder: (context) {
          return AssetBottomSheet(asset);
        });
  }
}
