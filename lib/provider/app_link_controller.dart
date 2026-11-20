import 'dart:convert';
import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/model/app_link.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:get/get.dart';
import 'package:cnattendance/core/ky_security/ky_http.dart';
import 'package:url_launcher/url_launcher.dart';

class AppLinkController extends GetxController {
  var links = <AppLink>[].obs;
  var isLoading = false.obs;
  var selectedFilter = 'all'.obs;
  var searchQuery = ''.obs;

  List<AppLink> get filteredLinks {
    var result = links.toList();
    if (selectedFilter.value != 'all') {
      result = result
          .where((item) => item.linkType.toLowerCase() == selectedFilter.value.toLowerCase())
          .toList();
    }
    if (searchQuery.value.trim().isNotEmpty) {
      final query = searchQuery.value.toLowerCase().trim();
      result = result.where((item) {
        final nameMatch = item.name.toLowerCase().contains(query);
        final descMatch = item.description != null &&
            item.description!.toLowerCase().contains(query);
        final urlMatch = item.url.toLowerCase().contains(query);
        final typeMatch = item.linkType.toLowerCase().contains(query);
        return nameMatch || descMatch || urlMatch || typeMatch;
      }).toList();
    }
    return result;
  }

  void setSearchQuery(String query) {
    searchQuery.value = query;
  }

  void clearSearch() {
    searchQuery.value = '';
  }

  @override
  void onInit() {
    super.onInit();
    getLinks();
  }

  Future<void> getLinks() async {
    try {
      isLoading.value = true;
      final Preferences preferences = Preferences();
      final String baseUrl = await preferences.getAppUrl();
      final String token = await preferences.getToken();

      final uri = Uri.parse(baseUrl + Constant.APP_LINKS_URL);
      final Map<String, String> headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json; charset=UTF-8',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final response = await KyHttp.get(uri, headers: headers);
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['status'] == true && responseData['data'] != null) {
          final List<dynamic> list = responseData['data'];
          links.value = list.map((item) => AppLink.fromJson(item)).toList();
        }
      }
    } catch (e) {
      debugPrint('Error fetching app links: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void setFilter(String filter) {
    selectedFilter.value = filter;
  }

  Future<void> launchLink(String url) async {
    try {
      String formattedUrl = url.trim();
      if (!formattedUrl.startsWith('http://') && !formattedUrl.startsWith('https://')) {
        formattedUrl = 'https://$formattedUrl';
      }
      final uri = Uri.parse(formattedUrl);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        debugPrint('Could not launch $formattedUrl');
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }

  void copyLink(BuildContext context, String url) {
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(translate('link_screen.copied')),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
