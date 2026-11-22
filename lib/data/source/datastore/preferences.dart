import 'dart:convert';
import 'package:cnattendance/data/source/network/model/login/User.dart';
import 'package:cnattendance/model/banner_slideshow_config.dart';
import 'package:cnattendance/model/app_appearance_config.dart';
import 'package:cnattendance/model/remote_theme_mode.dart';
import 'package:cnattendance/model/home_banner_config.dart';
import 'package:cnattendance/data/source/network/model/dashboard/User.dart'
    as DashboardUser;
import 'package:cnattendance/data/source/network/model/login/Login.dart';
import 'package:cnattendance/provider/chatbadgecontroller.dart';
import 'package:cnattendance/utils/chat_unread_store.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:cnattendance/services/server_url_resolver.dart';
import 'package:cnattendance/services/server_configuration.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class Preferences with ChangeNotifier {
  Preferences({ServerUrlResolver? serverUrlResolver})
      : _serverUrlResolver = serverUrlResolver ?? ServerUrlResolver.shared;

  final ServerUrlResolver _serverUrlResolver;
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _sharedPrefs async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  final String USER_ID = "user_id";
  final String USER_AVATAR = "user_avatar";
  final String USER_TOKEN = "user_token";
  final String USER_EMAIL = "user_email";
  final String USER_NAME = "user_name";
  final String USER_FULLNAME = "user_fullname";
  final String USER_BRANCH = "user_branch";
  final String USER_AUTH = "user_auth";
  final String WORKSPACE = "workspace_type";
  final String APP_IN_ENGLISH = "eng_date";
  final String ATTENDANCE_TYPE = "attendance_type";
  final String ATTENDANCE_TYPE_USER_SET = "attendance_type_user_set";
  final String APP_URL = "app_url";
  final String HARD_RESET_APP = "HARD_RESET";
  final String BIRTHDAY_WISHED = "BIRTHDAY_WISHED";
  final String SHOW_NFC = "SHOW_NFC";
  final String SHOWNOTE = "SHOW_NOTE";
  final String SHOWLOCATION = "SHOWLOCATION";
  final String COMPANY_VERIFY_REQUIRED = "company_verify_required";

  //feature control
  final String PROJECT_MANAGEMENT = "project-management";
  final String MEETING = "meeting";
  final String TADA = "tada";
  final String PAYROLL_MANGEMENT = "payroll-management";
  final String ADVANCE_SALARY = "advance-salary";
  final String ADVANCE_SALARY_APPROVE = "advance-salary-approve";
  final String ADMIN_ADVANCE_SALARY = "advance-salary-admin";
  final String SUPPORT = "support";
  final String DARK_MODE = "dark-mode";
  final String ATTENDANCE = "attendance";
  final String LEAVE_REQUEST = "leave-request";
  final String TIME_LEAVE = "time-leave";
  final String HOLIDAY = "holiday";
  final String NOTICE = "notice";
  final String SELL_STAFF_REPORT = "sell-staff-report";
  final String NFC_QR = "nfc-qr";
  final String AWARD = "award";
  final String TRAINING = "training";
  final String LOAN = "loan";
  final String EVENT = "event";
  final String COMPLAIN = "COMPLAIN";
  final String WARNING = "WARNING";
  final String RESIGNATION = "RESIGNATION";
  final String ASSETS = "ASSETS";
  final String SOCIAL_REWARDS = "social-rewards";
  final String SOCIAL_REWARDS_ADMIN = "social-rewards-admin";

  Future<bool> saveUser(Login data) async {
    // Obtain shared preferences.
    final user = data.user;
    final prefs = await _sharedPrefs;

    await prefs.remove('role_features_v2');
    await prefs.setString(USER_TOKEN, data.tokens);
    await prefs.setInt(USER_ID, user.id);
    await prefs.setString(USER_AVATAR, user.avatar);
    await prefs.setString(USER_EMAIL, user.email);
    await prefs.setString(USER_NAME, user.username);
    await prefs.setString(USER_FULLNAME, user.name);
    await prefs.setString(USER_BRANCH, '');
    await prefs.setString(WORKSPACE, user.workspace_type);

    final primary = ServerUrlResolver.normalize(await getConfiguredAppUrl());
    if (primary != null &&
        prefs.getString('verified_company_server') == primary) {
      await prefs.setString('login_server', primary);
    } else {
      await prefs.remove('login_server');
    }

    notifyListeners();

    return true;
  }

  Future<bool> saveUserDashboard(DashboardUser.User user) async {
    // Obtain shared preferences.
    final prefs = await _sharedPrefs;

    await prefs.setInt(USER_ID, user.id);
    await prefs.setString(USER_AVATAR, user.avatar);
    await prefs.setString(USER_EMAIL, user.email);
    await prefs.setString(USER_NAME, user.username);
    await prefs.setString(USER_FULLNAME, user.name);
    await prefs.setString(USER_BRANCH, user.branch);
    await prefs.setString(WORKSPACE, user.workspace_type);

    notifyListeners();

    return true;
  }

  /// Replace the complete server snapshot so revoked and newly added permissions
  /// never fall back to a previous grant or a hard-coded enabled default.
  Future<void> setFeatures(Map<String, String> features) async {
    final prefs = await _sharedPrefs;
    await prefs.setString('role_features_v2', jsonEncode(features));
    notifyListeners();
  }

  Future<Map<String, String>> getFeatures() async {
    final prefs = await _sharedPrefs;
    final snapshot = prefs.getString('role_features_v2');
    if (snapshot == null) return {};
    try {
      return Map<String, String>.from(jsonDecode(snapshot) as Map);
    } catch (_) {
      return {};
    }
  }

  static const String _roleMobileLayoutKey = 'role_mobile_layout_v1';

  Future<Map<String, List<String>>> getRoleMobileLayout() async {
    final prefs = await _sharedPrefs;
    final raw = prefs.getString(_roleMobileLayoutKey);
    if (raw == null || raw.trim().isEmpty) return {};
    try {
      final value = jsonDecode(raw) as Map<String, dynamic>;
      final data = value['data'];
      if (value['configured'] != true || data is! Map) return {};
      return Map<String, List<String>>.fromEntries(
        data.entries.map((entry) => MapEntry(
          entry.key.toString(),
          entry.value is List
              ? (entry.value as List).map((zone) => zone.toString()).toList()
              : <String>[],
        )),
      );
    } catch (_) {
      await prefs.remove(_roleMobileLayoutKey);
      return {};
    }
  }

  Future<bool> isRoleMobileLayoutConfigured() async {
    final prefs = await _sharedPrefs;
    final raw = prefs.getString(_roleMobileLayoutKey);
    if (raw == null || raw.trim().isEmpty) return false;
    try {
      return (jsonDecode(raw) as Map<String, dynamic>)['configured'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> cacheRoleMobileLayout(
      bool configured, Map<String, List<String>> layout) async {
    final prefs = await _sharedPrefs;
    await prefs.setString(_roleMobileLayoutKey, jsonEncode({
      'configured': configured,
      'data': layout,
    }));
  }

  Future<void> setRailExpanded(bool expanded) async {
    final prefs = await _sharedPrefs;
    await prefs.setBool('rail_expanded_v1', expanded);
  }

  Future<bool?> getRailExpanded() async {
    final prefs = await _sharedPrefs;
    return prefs.getBool('rail_expanded_v1');
  }

  void saveBasicUser(User user) async {
    final prefs = await _sharedPrefs;

    await prefs.setInt(USER_ID, user.id);
    await prefs.setString(USER_AVATAR, user.avatar);
    await prefs.setString(USER_EMAIL, user.email);
    await prefs.setString(USER_NAME, user.username);
    await prefs.setString(USER_FULLNAME, user.name);

    notifyListeners();
  }

  Future<void> clearPrefs() async {
    final prefs = await _sharedPrefs;

    await prefs.remove('login_server');
    await prefs.remove('verified_company_server');
    await prefs.remove('role_features_v2');

    await prefs.setInt(USER_ID, 0);
    await prefs.setString(USER_TOKEN, '');
    await prefs.setString(USER_AVATAR, '');
    await prefs.setString(USER_EMAIL, '');
    await prefs.setString(USER_NAME, '');
    await prefs.setString(USER_FULLNAME, '');
    await prefs.setString(USER_BRANCH, '');
    await prefs.setBool(USER_AUTH, false);
    await prefs.setBool(APP_IN_ENGLISH, true);
    await prefs.setString(WORKSPACE, "1");
    await prefs.setString(ATTENDANCE_TYPE, "Default");
    await prefs.setBool(ATTENDANCE_TYPE_USER_SET, false);
    await prefs.setString(APP_URL, "");

    await _clearChatUnreadState();

    notifyListeners();
  }

  Future<void> _clearChatUnreadState() async {
    try {
      await ChatUnreadStore.clearAll();
      if (Get.isRegistered<ChatBadgeController>()) {
        await Get.find<ChatBadgeController>().refreshUnreadCount();
      }
    } catch (e) {
      debugPrint('Unable to clear chat unread state: $e');
    }
  }

  void saveUserAuth(bool value) async {
    final prefs = await _sharedPrefs;
    await prefs.setBool(USER_AUTH, value);
  }

  void saveShowNfc(bool value) async {
    final prefs = await _sharedPrefs;
    await prefs.setBool(SHOW_NFC, value);
  }

  Future<void> saveHardReset(bool value) async {
    final prefs = await _sharedPrefs;
    await prefs.setBool(HARD_RESET_APP, value);
  }

  Future<void> saveAppUrl(String value) async {
    final prefs = await _sharedPrefs;
    if (ServerUrlResolver.normalize(value) !=
        prefs.getString('verified_company_server')) {
      await prefs.remove('login_server');
      await prefs.remove('verified_company_server');
    }
    await prefs.setString(APP_URL, value);
    _serverUrlResolver.invalidate(value);
    notifyListeners();
  }

  Future<bool> getCompanyVerifyRequired() async {
    final prefs = await _sharedPrefs;
    return prefs.getBool(COMPANY_VERIFY_REQUIRED) ?? false;
  }

  Future<void> setCompanyVerifyRequired(bool value) async {
    final prefs = await _sharedPrefs;
    await prefs.setBool(COMPANY_VERIFY_REQUIRED, value);
    notifyListeners();
  }

  Future<void> saveServerConfiguration(ServerConfiguration configuration,
      {bool verified = false}) async {
    final prefs = await _sharedPrefs;
    final primary = configuration.primaryUrl;
    await _serverUrlResolver.seedDefaults(primary, prefs);
    if (configuration.hasFallback) {
      final key = 'server_fallback:$primary';
      if (configuration.fallbackUrl == null) {
        await prefs.setString(key, '');
      } else {
        await prefs.setString(key, configuration.fallbackUrl!);
      }
    }
    await saveAppUrl(primary);
    if (verified) {
      await prefs.setString('verified_company_server', primary);
    }
  }

  Future<void> saveAttendanceType(String value) async {
    final prefs = await _sharedPrefs;
    await prefs.setString(ATTENDANCE_TYPE, value);
    notifyListeners();
  }

  Future<void> saveAttendanceTypeAsUserChoice(String value) async {
    final prefs = await _sharedPrefs;
    await prefs.setBool(ATTENDANCE_TYPE_USER_SET, true);
    await prefs.setString(ATTENDANCE_TYPE, value);
    notifyListeners();
  }

  Future<void> saveAttendanceTypeUserSet(bool value) async {
    final prefs = await _sharedPrefs;
    await prefs.setBool(ATTENDANCE_TYPE_USER_SET, value);
    notifyListeners();
  }

  Future<bool> getAttendanceTypeUserSet() async {
    final prefs = await _sharedPrefs;
    return prefs.getBool(ATTENDANCE_TYPE_USER_SET) ?? false;
  }

  void saveAppEng(bool value) async {
    final prefs = await _sharedPrefs;
    await prefs.setBool(APP_IN_ENGLISH, value);
  }

  void saveBirthdayWished(bool value) async {
    final prefs = await _sharedPrefs;
    await prefs.setBool(BIRTHDAY_WISHED, value);
  }

  void saveNote(bool value) async {
    final prefs = await _sharedPrefs;
    await prefs.setBool(SHOWNOTE, value);
  }

  void saveEmployeeLocation(bool value) async {
    final prefs = await _sharedPrefs;
    await prefs.setBool(SHOWLOCATION, value);
  }

  Future<User> getUser() async {
    final prefs = await _sharedPrefs;

    return User(
        id: prefs.getInt(USER_ID) ?? 0,
        name: prefs.getString(USER_FULLNAME) ?? "",
        email: prefs.getString(USER_EMAIL) ?? "",
        username: prefs.getString(USER_NAME) ?? "",
        avatar: prefs.getString(USER_AVATAR) ?? "",
        workspace_type: prefs.getString(WORKSPACE) ?? "1");
  }

  Future<String> getToken() async {
    final prefs = await _sharedPrefs;

    return prefs.getString(USER_TOKEN) ?? "";
  }

  Future<bool> getNote() async {
    final prefs = await _sharedPrefs;

    return prefs.getBool(SHOWNOTE) ?? false;
  }

  Future<bool> getEnableLocation() async {
    final prefs = await _sharedPrefs;

    return prefs.getBool(SHOWLOCATION) ?? false;
  }

  Future<String> getAttendanceType() async {
    final prefs = await _sharedPrefs;

    return prefs.getString(ATTENDANCE_TYPE) ?? "Default";
  }

  Future<bool> getUserAuth() async {
    final prefs = await _sharedPrefs;

    return prefs.getBool(USER_AUTH) ?? false;
  }

  Future<int> getUserId() async {
    final prefs = await _sharedPrefs;

    return prefs.getInt(USER_ID) ?? 0;
  }

  Future<bool> getShowNfc() async {
    final prefs = await _sharedPrefs;

    return prefs.getBool(SHOW_NFC) ?? true;
  }

  Future<bool> getBirthdayWished() async {
    final prefs = await _sharedPrefs;

    return prefs.getBool(BIRTHDAY_WISHED) ?? false;
  }

  Future<String> getUsername() async {
    final prefs = await _sharedPrefs;
    return prefs.getString(USER_NAME) ?? "";
  }

  Future<String> getEmail() async {
    final prefs = await _sharedPrefs;
    return prefs.getString(USER_EMAIL) ?? "";
  }

  Future<String> getAvatar() async {
    final prefs = await _sharedPrefs;
    return prefs.getString(USER_AVATAR) ?? "";
  }

  Future<String> getFullName() async {
    final prefs = await _sharedPrefs;
    return prefs.getString(USER_FULLNAME) ?? "";
  }

  Future<String> getBranchName() async {
    final prefs = await _sharedPrefs;
    return prefs.getString(USER_BRANCH) ?? "";
  }

  Future<String> getWorkSpace() async {
    final prefs = await _sharedPrefs;
    return prefs.getString(WORKSPACE) ?? "1";
  }

  Future<bool> getEnglishDate() async {
    final prefs = await _sharedPrefs;
    return prefs.getBool(APP_IN_ENGLISH) ?? true;
  }

  Future<String> getConfiguredAppUrl() async {
    final prefs = await _sharedPrefs;
    final saved = prefs.getString(APP_URL)?.trim();
    return saved == null || saved.isEmpty ? Constant.appUrl : saved;
  }

  Future<String> getAppUrl({bool forceCheck = false}) async {
    final prefs = await _sharedPrefs;
    return _serverUrlResolver.resolve(
      await getConfiguredAppUrl(),
      prefs,
      forceCheck: forceCheck,
    );
  }

  Future<bool> getHardReset() async {
    final prefs = await _sharedPrefs;
    return prefs.getBool(HARD_RESET_APP) ?? true;
  }

  Future<String?> getHomeBannerUrl() async {
    final prefs = await _sharedPrefs;
    return prefs.getString('home_banner_image_url');
  }

  Future<void> saveHomeBannerUrl(String? url) async {
    final prefs = await _sharedPrefs;
    if (url == null || url.trim().isEmpty) {
      await prefs.remove('home_banner_image_url');
    } else {
      await prefs.setString('home_banner_image_url', url.trim());
    }
    notifyListeners();
  }

  Future<String?> getHomeBannerLinkUrl() async {
    final prefs = await _sharedPrefs;
    return prefs.getString('home_banner_link_url');
  }

  Future<void> saveHomeBannerLinkUrl(String? url) async {
    final prefs = await _sharedPrefs;
    if (url == null || url.trim().isEmpty) {
      await prefs.remove('home_banner_link_url');
    } else {
      await prefs.setString('home_banner_link_url', url.trim());
    }
    notifyListeners();
  }

  Future<String?> getHomeBannerTitle() async {
    final prefs = await _sharedPrefs;
    return prefs.getString('home_banner_title');
  }

  Future<void> saveHomeBannerTitle(String? title) async {
    final prefs = await _sharedPrefs;
    if (title == null || title.trim().isEmpty) {
      await prefs.remove('home_banner_title');
    } else {
      await prefs.setString('home_banner_title', title.trim());
    }
    notifyListeners();
  }

  Future<void> resetHomeBanner() async {
    final prefs = await _sharedPrefs;
    await prefs.remove('home_banner_image_url');
    await prefs.remove('home_banner_link_url');
    await prefs.remove('home_banner_title');
    notifyListeners();
  }

  static const String _homeSlideshowKey = 'home_banner_slideshow_v1';

  /// Returns the locally stored banner slideshow.
  ///
  /// Falls back to the legacy single-banner keys when the slideshow has never
  /// been saved so existing installs keep their configured banner.
  Future<BannerSlideshowConfig> getHomeSlideshow() async {
    final prefs = await _sharedPrefs;
    final raw = prefs.getString(_homeSlideshowKey);
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        return BannerSlideshowConfig.fromJson(
            jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        // Corrupt payload -> fall through to legacy migration.
      }
    }

    final legacyUrl = prefs.getString('home_banner_image_url') ?? '';
    if (legacyUrl.trim().isEmpty) {
      return const BannerSlideshowConfig();
    }
    return BannerSlideshowConfig.legacy(
      imageUrl: legacyUrl,
      linkUrl: prefs.getString('home_banner_link_url') ?? '',
      title: prefs.getString('home_banner_title') ?? '',
    );
  }

  /// Updates the slideshow cache without notifying listeners. This avoids
  /// reloading the home banner when a fresh server response is cached.
  Future<void> cacheHomeSlideshow(BannerSlideshowConfig config) async {
    final prefs = await _sharedPrefs;
    await prefs.setString(_homeSlideshowKey, jsonEncode(config.toJson()));
  }

  Future<void> saveHomeSlideshow(BannerSlideshowConfig config) async {
    await cacheHomeSlideshow(config);
    notifyListeners();
  }

  Future<void> resetHomeSlideshow() async {
    final prefs = await _sharedPrefs;
    await prefs.remove(_homeSlideshowKey);
    await prefs.remove('home_banner_image_url');
    await prefs.remove('home_banner_link_url');
    await prefs.remove('home_banner_title');
    notifyListeners();
  }

  static const String _appAppearanceKey = 'app_appearance_v1';

  /// Returns the last server-delivered appearance config, or null when the
  /// device has never received one.
  Future<AppAppearanceConfig?> getAppAppearance() async {
    final prefs = await _sharedPrefs;
    final raw = prefs.getString(_appAppearanceKey);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      return AppAppearanceConfig.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      await prefs.remove(_appAppearanceKey);
      return null;
    }
  }

  Future<void> cacheAppAppearance(AppAppearanceConfig config) async {
    final prefs = await _sharedPrefs;
    await prefs.setString(_appAppearanceKey, jsonEncode(config.toJson()));
  }

  static const String _themeModesKey = 'app_theme_modes_v1';

  Future<List<RemoteThemeMode>> getThemeModes() async {
    final prefs = await _sharedPrefs;
    final raw = prefs.getString(_themeModesKey);
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((item) =>
                RemoteThemeMode.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      }
    } catch (_) {
      await prefs.remove(_themeModesKey);
    }
    return const [];
  }

  Future<void> cacheThemeModes(List<RemoteThemeMode> modes) async {
    final prefs = await _sharedPrefs;
    await prefs.setString(
        _themeModesKey, jsonEncode(modes.map((m) => m.toJson()).toList()));
  }

  Future<String> getHomeQuote() async {
    final prefs = await _sharedPrefs;
    return prefs.getString('home_quote_text') ??
        'ការចូលរួមទាន់ពេលវេលា\nវេលា សេចក្តីទទួលខុសត្រូវ\nនិងកិត្តិយសជោគជ័យ';
  }

  Future<void> saveHomeQuote(String quote) async {
    final prefs = await _sharedPrefs;
    await prefs.setString('home_quote_text', quote.trim());
    notifyListeners();
  }

  Future<void> cacheHomeQuote({
    required String text,
    required String? author,
    required QuoteStyle? style,
  }) async {
    final prefs = await _sharedPrefs;
    await Future.wait([
      prefs.setString('home_quote_text', text.trim()),
      if (author == null || author.trim().isEmpty)
        prefs.remove('home_quote_author')
      else
        prefs.setString('home_quote_author', author.trim()),
      if (style == null)
        prefs.remove('home_quote_style')
      else
        prefs.setString('home_quote_style', jsonEncode(style.toJson())),
    ]);
  }

  Future<bool> getHomeQuoteShow() async {
    final prefs = await _sharedPrefs;
    return prefs.getBool('home_quote_show') ?? true;
  }

  Future<void> saveHomeQuoteShow(bool show) async {
    final prefs = await _sharedPrefs;
    await prefs.setBool('home_quote_show', show);
    notifyListeners();
  }

  Future<String?> getHomeQuoteAuthor() async {
    final prefs = await _sharedPrefs;
    return prefs.getString('home_quote_author');
  }

  Future<void> saveHomeQuoteAuthor(String? author) async {
    final prefs = await _sharedPrefs;
    if (author == null || author.trim().isEmpty) {
      await prefs.remove('home_quote_author');
    } else {
      await prefs.setString('home_quote_author', author.trim());
    }
    notifyListeners();
  }

  Future<QuoteStyle?> getHomeQuoteStyle() async {
    final prefs = await _sharedPrefs;
    final jsonStr = prefs.getString('home_quote_style');
    if (jsonStr == null || jsonStr.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is Map<String, dynamic>) {
        return QuoteStyle.fromJson(decoded);
      }
    } catch (error) { if (kDebugMode) debugPrint('Preferences: failed to parse saved quote style: $error'); }
    return null;
  }

  Future<void> saveHomeQuoteStyle(QuoteStyle? style) async {
    final prefs = await _sharedPrefs;
    if (style == null) {
      await prefs.remove('home_quote_style');
    } else {
      await prefs.setString('home_quote_style', jsonEncode(style.toJson()));
    }
    notifyListeners();
  }

  Future<void> resetHomeQuote() async {
    final prefs = await _sharedPrefs;
    await prefs.remove('home_quote_text');
    await prefs.remove('home_quote_author');
    await prefs.remove('home_quote_style');
    await prefs.setBool('home_quote_show', true);
    notifyListeners();
  }
}
