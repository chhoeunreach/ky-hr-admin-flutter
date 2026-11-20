import 'dart:convert';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/data/source/network/model/hollidays/HolidayResponse.dart';
import 'package:cnattendance/data/source/network/model/hollidays/Holidays.dart';
import 'package:cnattendance/model/holiday.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:get/get.dart';
import 'package:cnattendance/core/ky_security/ky_http.dart';
import 'package:intl/intl.dart';
import 'package:nepali_date_picker/nepali_date_picker.dart';

class HolidayController extends GetxController {
  var _holidayList = <Holiday>[].obs;
  var _holidayListFilter = <Holiday>[].obs;

  List<Holiday> get holidayList {
    return List.of(_holidayListFilter);
  }

  var toggleValue = 0.obs;

  void holidayListFilter() {
    _holidayListFilter.clear();
    if (toggleValue == 0) {
      _holidayListFilter.addAll(_holidayList
          .where((element) => element.dateTime.isAfter(DateTime.now()))
          .toList());
    } else {
      _holidayListFilter.addAll(_holidayList
          .where((element) => element.dateTime.isBefore(DateTime.now()))
          .toList()
          .reversed);
    }
  }

  Future<HolidayResponse> getHolidays({bool showLoader = true}) async {
    Preferences preferences = Preferences();
    var uri = Uri.parse(await preferences.getAppUrl() + Constant.HOLIDAYS_API);

    String token = await preferences.getToken();

    Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token'
    };

    try {
      if (showLoader)
        EasyLoading.show(
            status: translate('loader.loading'),
            maskType: EasyLoadingMaskType.black);
      final response = await KyHttp.get(uri, headers: headers);
      if (showLoader) EasyLoading.dismiss(animation: true);
      final responseData = json.decode(response.body);
      if (response.statusCode == 200) {
        final responseJson = HolidayResponse.fromJson(responseData);

        await makeHolidayList(responseJson.data);
        holidayListFilter();

        return responseJson;
      } else {
        var errorMessage = responseData['message'];
        throw errorMessage;
      }
    } catch (error) {
      if (showLoader) EasyLoading.dismiss(animation: true);
      rethrow;
    }
  }

  Future<void> makeHolidayList(List<Holidays>? data) async {
    Preferences preferences = Preferences();
    bool isAd = await preferences.getEnglishDate();

    _holidayList.clear();
    for (var item in data ?? []) {
      DateTime tempDate = DateFormat("yyyy-MM-dd").parse(item.eventDate);

      NepaliDateTime nepaliDate = tempDate.toNepaliDateTime();

      _holidayList.add(Holiday(
          id: item.id,
          day: isAd
              ? DateFormat('dd').format(tempDate)
              : NepaliDateFormat('dd').format(nepaliDate),
          month: isAd
              ? DateFormat('MMM').format(tempDate)
              : NepaliDateFormat('MMMM').format(nepaliDate),
          title: item.event,
          description: item.description,
          dateTime: tempDate,
          isPublicHoliday: item.isPublicHoliday));
    }
  }

  @override
  void onReady() {
    getHolidays();
    super.onReady();
  }
}
