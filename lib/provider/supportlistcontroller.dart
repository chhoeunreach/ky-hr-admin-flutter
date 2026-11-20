import 'dart:convert';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/data/source/network/model/supportlistresponse/supportlistresponse.dart';
import 'package:cnattendance/model/support.dart';
import 'package:cnattendance/screen/profile/supportdetailscreen.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:get/get.dart';
import 'package:cnattendance/core/ky_security/ky_http.dart';
import 'package:intl/intl.dart';
import 'package:nepali_date_picker/nepali_date_picker.dart';
import 'package:flutter/foundation.dart';

class SupportListController extends GetxController {
  var supportList = <Support>[].obs;
  final filteredList = <Support>[].obs;

  final selected = "All".obs;

  Future<void> getSupportList() async {
    final Preferences preferences = Preferences();
    final uri = Uri.parse(await preferences.getAppUrl()+Constant.SUPPORT_LIST_URL + "?per_page=50&page=1");

    final String token = await preferences.getToken();
    final bool isAd = await preferences.getEnglishDate();

    final Map<String, String> headers = {
      'Accept': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token'
    };

    try {
      EasyLoading.show(
          status: translate('loader.loading'), maskType: EasyLoadingMaskType.black);
      final response = await KyHttp.get(uri, headers: headers);
      debugPrint(response.body.toString());
      EasyLoading.dismiss(animation: true);

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        final supportResponse = supportlistresponse.fromJson(responseData);
        final list = <Support>[];
        for (var support in supportResponse.data.data) {
          final date = new DateFormat('MMM dd yyyy').parse(support.query_date);

          final nepali = DateFormat("MMM dd yyyy")
              .parse(support.query_date)
              .toNepaliDateTime();

          final nepaliDate = NepaliDateFormat("MMM dd yyyy").format(nepali);

          list.add(Support(
              support.title,
              support.description,
              isAd?support.query_date:nepaliDate,
              support.status,
              support.requested_department,
              isAd
                  ? DateFormat("dd").format(date)
                  : NepaliDateFormat("dd").format(nepali),
              isAd
                  ? DateFormat("MMM").format(date)
                  : NepaliDateFormat("MMM").format(nepali),
              support.updated_by,
              support.updated_at));
        }

        supportList.value = list;
        filterList();
      } else {
        final errorMessage = responseData['message'];
        throw errorMessage;
      }
    } catch (e) {
      EasyLoading.dismiss(animation: true);
      if (kDebugMode) debugPrint(e.toString());
      throw unknownError(e);
    }
  }

  void filterList() {
    filteredList.clear();
    if (selected.value == "All") {
      filteredList.addAll(supportList);
    } else {
      for (var support in supportList) {
        if (support.status == selected.value) {
          filteredList.add(support);
        }
      }
    }
  }

  @override
  Future<void> onInit() async {
    await getSupportList();
    super.onInit();
  }

  void onSupportClicked(Support support) {
    Get.to(SupportDetailScreen(support), transition: Transition.cupertino);
  }
}
