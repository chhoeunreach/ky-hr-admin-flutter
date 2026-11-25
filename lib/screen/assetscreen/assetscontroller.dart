import 'package:cnattendance/data/source/network/model/asssetlistresponse/assetlistresponse.dart';
import 'package:cnattendance/repositories/assetrepository.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:get/get.dart';

class AssetController extends GetxController {
  final repository = AssetRepository();

  var assets = <AssetData>[].obs;
  final isLoading = false.obs;
  final errorMessage = RxnString();

  @override
  void onReady() {
    super.onReady();
    getAssets();
  }

  Future<void> getAssets() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final response = await repository.getAssets(1);
      assets.value = response.data;
    } catch (e) {
      // Surface via errorMessage (UI shows Retry); avoid raw exception spam.
      errorMessage.value = unknownError(e);
    } finally {
      isLoading.value = false;
    }
  }

  Future<(bool, String)> sendResponse(int id, String note, bool isWorking) async {
    final response = await repository.writeResponse(id.toString(), note, isWorking);
    return response;
  }
}
