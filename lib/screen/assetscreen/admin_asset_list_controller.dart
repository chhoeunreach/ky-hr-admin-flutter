import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/model/admin_asset.dart';
import 'package:cnattendance/repositories/admin_asset_repository.dart';
import 'package:cnattendance/screen/assetscreen/admin_asset_detail_screen.dart';
import 'package:cnattendance/screen/assetscreen/admin_asset_form_screen.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

class AdminAssetListController extends GetxController {
  final repository = AdminAssetRepository();
  final preferences = Preferences();

  final assets = <AdminAsset>[].obs;
  final isLoading = false.obs;
  final isMoreLoading = false.obs;

  final searchQuery = ''.obs;
  final selectedStatus = 'All'.obs;
  final selectedTypeId = Rxn<int>();
  final selectedBranchId = Rxn<int>();

  final types = <AssetDropdownItem>[].obs;
  final branches = <AssetDropdownItem>[].obs;
  final employees = <AssetEmployeeItem>[].obs;

  final canCreate = true.obs;
  final canEdit = true.obs;
  final canDelete = true.obs;

  int _currentPage = 1;
  int _lastPage = 1;
  int totalAssets = 0;

  @override
  void onInit() {
    super.onInit();
    _checkPermissions();
    loadFormData();
    getAssets();
  }

  Future<void> _checkPermissions() async {
    final features = await preferences.getFeatures();
    // If features map is available, use exact granular ability keys; fallback to true if admin
    if (features.isNotEmpty) {
      canCreate.value = features['create_assets'] == '1' ||
          features['assets-admin'] == '1';
      canEdit.value = features['edit_assets'] == '1' ||
          features['assets-admin'] == '1';
      canDelete.value = features['delete_assets'] == '1' ||
          features['assets-admin'] == '1';
    }
  }

  Future<void> loadFormData() async {
    try {
      final data = await repository.getFormData();
      types.value = data.types;
      branches.value = data.branches;
      employees.value = data.employees;
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to load asset form data: $e');
    }
  }

  Future<void> getAssets({bool refresh = true}) async {
    if (refresh) {
      _currentPage = 1;
      isLoading.value = true;
    }

    try {
      int? isAvailable;
      String? isWorking;

      if (selectedStatus.value == 'Available') {
        isAvailable = 1;
        isWorking = 'yes';
      } else if (selectedStatus.value == 'Assigned') {
        isAvailable = 0;
        isWorking = 'yes';
      } else if (selectedStatus.value == 'Maintenance') {
        isWorking = 'no';
      }

      final result = await repository.getAssets(
        search: searchQuery.value,
        typeId: selectedTypeId.value,
        branchId: selectedBranchId.value,
        isAvailable: isAvailable,
        isWorking: isWorking,
        page: _currentPage,
      );

      if (refresh) {
        assets.value = result.assets;
      } else {
        assets.addAll(result.assets);
      }

      totalAssets = result.total;
      _lastPage = result.lastPage;
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading assets: $e');
    } finally {
      isLoading.value = false;
      isMoreLoading.value = false;
    }
  }

  Future<void> loadMore() async {
    if (_currentPage >= _lastPage || isMoreLoading.value) return;
    isMoreLoading.value = true;
    _currentPage++;
    await getAssets(refresh: false);
  }

  void onSearchChanged(String query) {
    searchQuery.value = query;
    getAssets(refresh: true);
  }

  void onStatusChanged(String status) {
    selectedStatus.value = status;
    getAssets(refresh: true);
  }

  void onTypeFilterChanged(int? typeId) {
    selectedTypeId.value = typeId;
    getAssets(refresh: true);
  }

  void onBranchFilterChanged(int? branchId) {
    selectedBranchId.value = branchId;
    getAssets(refresh: true);
  }

  void onAddAssetClicked() async {
    final result = await Get.to(
      () => AdminAssetFormScreen(
        types: types,
        branches: branches,
        employees: employees,
      ),
      transition: Transition.cupertino,
    );
    if (result == true) {
      getAssets(refresh: true);
    }
  }

  void onEditAssetClicked(AdminAsset asset) async {
    final result = await Get.to(
      () => AdminAssetFormScreen(
        asset: asset,
        types: types,
        branches: branches,
        employees: employees,
      ),
      transition: Transition.cupertino,
    );
    if (result == true) {
      getAssets(refresh: true);
    }
  }

  void onAssetDetailClicked(AdminAsset asset) async {
    final result = await Get.to(
      () => AdminAssetDetailScreen(assetId: asset.id),
      transition: Transition.cupertino,
    );
    if (result == true) {
      getAssets(refresh: true);
    }
  }

  Future<void> deleteAsset(int id) async {
    try {
      EasyLoading.show(
        status: 'Deleting...',
        maskType: EasyLoadingMaskType.black,
      );
      final (success, message) = await repository.deleteAsset(id);
      EasyLoading.dismiss(animation: true);

      showToast(message);
      if (success) {
        assets.removeWhere((item) => item.id == id);
      }
    } catch (e) {
      EasyLoading.dismiss(animation: true);
      showToast(e.toString());
    }
  }
}
