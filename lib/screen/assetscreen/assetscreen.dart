import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/screen/assetscreen/admin_asset_list_screen.dart';
import 'package:cnattendance/screen/assetscreen/assetscontroller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:get/get.dart';

import '../../widget/buttonborder.dart';
import '../../widget/profile/asset_bottom_sheet.dart';
import '../../widget/radialDecoration.dart';
import 'package:cnattendance/core/theme/app_colors.dart';

class AssetScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final model = Get.put(AssetController());
    return Container(
      decoration: RadialDecoration(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          title: Text(translate('common.assets')),
          actions: [
            FutureBuilder<Map<String, String>>(
              future: Preferences().getFeatures(),
              builder: (context, snapshot) {
                final features = snapshot.data ?? {};
                final canAdmin = features['assets-admin'] == '1' ||
                    features['list_assets'] == '1';
                if (!canAdmin) return const SizedBox.shrink();
                return IconButton(
                  icon: const Icon(Icons.admin_panel_settings_outlined),
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
            padding: const EdgeInsets.symmetric(horizontal: 15.0),
            child: RefreshIndicator(
              onRefresh: () async {
                await model.getAssets();
              },
              child: ListView.builder(
                itemCount: model.assets.length,
                itemBuilder: (context, index) {
                  final asset = model.assets[index];
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      showModalBottomSheet(
                          elevation: 0,
                          context: context,
                          isScrollControlled: true,
                          shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(20),
                                  topRight: Radius.circular(20))),
                          builder: (context) {
                            return AssetBottomSheet(asset);
                          });
                    },
                    child: Card(
                      shape: ButtonBorder(),
                      color: asset.returnedDate == null
                          ? AppColors.blue.withValues(alpha: .5)
                          : AppColors.white24,
                      elevation: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    asset.assignedDate,
                                    style: TextStyle(
                                        color: AppColors.white70,
                                        fontSize: 12,
                                        fontWeight: FontWeight.normal),
                                  ),
                                  Text(
                                    asset.asset,
                                    style: TextStyle(
                                        color: AppColors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                                style: TextButton.styleFrom(
                                  backgroundColor: asset.notes != null
                                      ? AppColors.customFF036EB7
                                          .withValues(alpha: .3)
                                      : AppColors.customFF036EB7,
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                  shape: ButtonBorder(),
                                ),
                                onPressed: () {
                                  showModalBottomSheet(
                                      elevation: 0,
                                      context: context,
                                      isScrollControlled: true,
                                      shape: const RoundedRectangleBorder(
                                          borderRadius: BorderRadius.only(
                                              topLeft: Radius.circular(20),
                                              topRight: Radius.circular(20))),
                                      builder: (context) {
                                        return AssetBottomSheet(asset);
                                      });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 15.0),
                                  child: Text(
                                    asset.notes == null ? 'Return' : "Returned",
                                    style: TextStyle(color: AppColors.white),
                                  ),
                                ))
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
