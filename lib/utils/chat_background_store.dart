import 'package:shared_preferences/shared_preferences.dart';

class ChatBackgroundStore {
  static const _prefix = 'chat_background_photo_';

  static Future<String?> getBackground(String conversationKey) async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString('$_prefix$conversationKey');
    if (value == null || value.trim().isEmpty) return null;
    return value;
  }

  static Future<void> setBackground(
      String conversationKey, String filePath) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefix$conversationKey', filePath);
  }

  static Future<void> resetBackground(String conversationKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$conversationKey');
  }
}
