/// Global appearance configuration managed from the web admin panel.
///
/// Applies to every user: the admin picks the app background (image or SVG)
/// and switches the floating decorations on or off. Cached locally so the
/// last known configuration renders before the first network response.
class AppAppearanceConfig {
  static const String backgroundNone = 'none';
  static const String backgroundImage = 'image';
  static const String backgroundSvg = 'svg';

  static const String effectHeat = 'heat';
  static const String effectSnow = 'snow';
  static const String effectFloatingHearts = 'floating_hearts';
  static const String effectRosePetals = 'rose_petals';
  static const String effectHeartGlow = 'heart_glow';
  static const String effectSparkleEffects = 'sparkle_effects';
  static const String effectEmoji = 'emoji_effect';

  static const List<String> effectKeys = [
    effectHeat,
    effectSnow,
    effectFloatingHearts,
    effectRosePetals,
    effectHeartGlow,
    effectSparkleEffects,
    effectEmoji,
  ];

  final String backgroundType;
  final String? backgroundUrl;
  final bool heat;
  final bool snow;
  final bool floatingHearts;
  final bool rosePetals;
  final bool heartGlow;
  final bool sparkleEffects;
  final bool emojiEffect;
  final String emojiChar;
  final List<Map<String, dynamic>> customEffects;
  final List<String> customFloatingEmojis;

  const AppAppearanceConfig({
    this.backgroundType = backgroundNone,
    this.backgroundUrl,
    this.heat = false,
    this.snow = false,
    this.floatingHearts = true,
    this.rosePetals = false,
    this.heartGlow = true,
    this.sparkleEffects = true,
    this.emojiEffect = false,
    this.emojiChar = '✨',
    this.customEffects = const [],
    this.customFloatingEmojis = const [],
  });

  bool get hasCustomBackground =>
      backgroundUrl != null &&
      backgroundUrl!.trim().isNotEmpty &&
      backgroundType != backgroundNone;

  bool get isSvgBackground => backgroundType == backgroundSvg;

  bool effectEnabled(String key) => switch (key) {
        effectHeat => heat,
        effectSnow => snow,
        effectFloatingHearts => floatingHearts,
        effectRosePetals => rosePetals,
        effectHeartGlow => heartGlow,
        effectSparkleEffects => sparkleEffects,
        effectEmoji => emojiEffect,
        _ => false,
      };

  factory AppAppearanceConfig.fromJson(Map<String, dynamic> json) {
    String type = json['background_type']?.toString() ?? backgroundNone;
    if (type != backgroundImage && type != backgroundSvg) {
      type = backgroundNone;
    }
    final rawUrl = json['background_url']?.toString().trim();
    bool flag(String key, bool fallback) {
      final value = json[key];
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) return value == '1' || value == 'true';
      return fallback;
    }

    final emoji = json['emoji_char']?.toString().trim();
    final customEffects = json['custom_effects'];
    final normalizedCustomEffects = customEffects is List
        ? customEffects
            .whereType<Map>()
            .take(20)
            .map((effect) => <String, dynamic>{
                  'id': effect['id']?.toString() ?? '',
                  'name': effect['name']?.toString() ?? '',
                  'emoji': effect['emoji']?.toString() ?? '',
                  'enabled': effect['enabled'] == null ||
                      effect['enabled'] == true ||
                      effect['enabled'] == 1 ||
                      effect['enabled'] == '1' ||
                      effect['enabled'] == 'true',
                })
            .toList()
        : <Map<String, dynamic>>[];
    final customFloatingEmojis = customEffects is List
        ? normalizedCustomEffects
            .where((effect) => effect['enabled'] == true)
            .map((effect) => effect['emoji']?.toString().trim() ?? '')
            .where((value) => value.isNotEmpty)
            .take(20)
            .toList()
        : <String>[];
    return AppAppearanceConfig(
      backgroundType: type,
      backgroundUrl: (rawUrl == null || rawUrl.isEmpty) ? null : rawUrl,
      heat: flag(effectHeat, false),
      snow: flag(effectSnow, false),
      floatingHearts: flag(effectFloatingHearts, true),
      rosePetals: flag(effectRosePetals, false),
      heartGlow: flag(effectHeartGlow, true),
      sparkleEffects: flag(effectSparkleEffects, true),
      emojiEffect: flag(effectEmoji, false),
      emojiChar: (emoji == null || emoji.isEmpty) ? '✨' : emoji,
      customEffects: normalizedCustomEffects,
      customFloatingEmojis: customFloatingEmojis,
    );
  }

  Map<String, dynamic> toJson() => {
        'background_type': backgroundType,
        'background_url': backgroundUrl,
        effectHeat: heat,
        effectSnow: snow,
        effectFloatingHearts: floatingHearts,
        effectRosePetals: rosePetals,
        effectHeartGlow: heartGlow,
        effectSparkleEffects: sparkleEffects,
        effectEmoji: emojiEffect,
        'emoji_char': emojiChar,
        'custom_effects': customEffects,
      };
}
