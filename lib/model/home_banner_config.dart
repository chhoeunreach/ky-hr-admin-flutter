import 'package:flutter/material.dart';

class QuoteStyle {
  final String? fontFamily;
  final double? fontSize;
  final FontWeight? fontWeight;
  final FontStyle? fontStyle;
  final TextAlign? textAlign;
  final Color? color;
  final double? opacity;
  final double rotation; // in degrees
  final double? posX; // percentage 0-100
  final double? posY; // percentage 0-100
  final double strokeWidth;
  final Color? strokeColor;
  final bool gradientEnabled;
  final Color? gradientStart;
  final Color? gradientEnd;
  final double gradientAngle;
  final double shadowBlur;
  final Color? shadowColor;
  final double shadowX;
  final double shadowY;
  final String? bannerImage;
  final double? bannerOverlay;

  const QuoteStyle({
    this.fontFamily,
    this.fontSize,
    this.fontWeight,
    this.fontStyle,
    this.textAlign,
    this.color,
    this.opacity,
    this.rotation = 0.0,
    this.posX,
    this.posY,
    this.strokeWidth = 0.0,
    this.strokeColor,
    this.gradientEnabled = false,
    this.gradientStart,
    this.gradientEnd,
    this.gradientAngle = 90.0,
    this.shadowBlur = 0.0,
    this.shadowColor,
    this.shadowX = 0.0,
    this.shadowY = 2.0,
    this.bannerImage,
    this.bannerOverlay,
  });

  bool get hasCustomPosition => posX != null && posY != null;

  QuoteStyle copyWith({
    String? fontFamily,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    TextAlign? textAlign,
    Color? color,
    double? opacity,
    double? rotation,
    double? posX,
    double? posY,
    double? strokeWidth,
    Color? strokeColor,
    bool? gradientEnabled,
    Color? gradientStart,
    Color? gradientEnd,
    double? gradientAngle,
    double? shadowBlur,
    Color? shadowColor,
    double? shadowX,
    double? shadowY,
    String? bannerImage,
    double? bannerOverlay,
  }) {
    return QuoteStyle(
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      fontWeight: fontWeight ?? this.fontWeight,
      fontStyle: fontStyle ?? this.fontStyle,
      textAlign: textAlign ?? this.textAlign,
      color: color ?? this.color,
      opacity: opacity ?? this.opacity,
      rotation: rotation ?? this.rotation,
      posX: posX ?? this.posX,
      posY: posY ?? this.posY,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      strokeColor: strokeColor ?? this.strokeColor,
      gradientEnabled: gradientEnabled ?? this.gradientEnabled,
      gradientStart: gradientStart ?? this.gradientStart,
      gradientEnd: gradientEnd ?? this.gradientEnd,
      gradientAngle: gradientAngle ?? this.gradientAngle,
      shadowBlur: shadowBlur ?? this.shadowBlur,
      shadowColor: shadowColor ?? this.shadowColor,
      shadowX: shadowX ?? this.shadowX,
      shadowY: shadowY ?? this.shadowY,
      bannerImage: bannerImage ?? this.bannerImage,
      bannerOverlay: bannerOverlay ?? this.bannerOverlay,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fontFamily': fontFamily,
      'fontSize': fontSize,
      'fontWeight': _fontWeightToString(fontWeight),
      'fontStyle': fontStyle == FontStyle.italic ? 'italic' : 'normal',
      'textAlign': textAlign?.name,
      'color': _colorToHex(color),
      'opacity': opacity,
      'rotation': rotation,
      'posX': posX,
      'posY': posY,
      'strokeWidth': strokeWidth,
      'strokeColor': _colorToHex(strokeColor),
      'gradientEnabled': gradientEnabled,
      'gradientStart': _colorToHex(gradientStart),
      'gradientEnd': _colorToHex(gradientEnd),
      'gradientAngle': gradientAngle,
      'shadowBlur': shadowBlur,
      'shadowColor': _colorToHex(shadowColor),
      'shadowX': shadowX,
      'shadowY': shadowY,
      'bannerImage': bannerImage,
      'bannerOverlay': bannerOverlay,
    };
  }

  factory QuoteStyle.fromJson(Map<String, dynamic> json) {
    return QuoteStyle(
      fontFamily: json['fontFamily'] as String?,
      fontSize: _toDouble(json['fontSize']),
      fontWeight: _parseFontWeight(json['fontWeight']),
      fontStyle:
          json['fontStyle'] == 'italic' ? FontStyle.italic : FontStyle.normal,
      textAlign: _parseTextAlign(json['textAlign']),
      color: _parseColor(json['color']),
      opacity: _toDouble(json['opacity']),
      rotation: _toDouble(json['rotation']) ?? 0.0,
      posX: _toDouble(json['posX']),
      posY: _toDouble(json['posY']),
      strokeWidth: _toDouble(json['strokeWidth']) ?? 0.0,
      strokeColor: _parseColor(json['strokeColor']),
      gradientEnabled: json['gradientEnabled'] as bool? ?? false,
      gradientStart: _parseColor(json['gradientStart']),
      gradientEnd: _parseColor(json['gradientEnd']),
      gradientAngle: _toDouble(json['gradientAngle']) ?? 90.0,
      shadowBlur: _toDouble(json['shadowBlur']) ?? 0.0,
      shadowColor: _parseColor(json['shadowColor']),
      shadowX: _toDouble(json['shadowX']) ?? 0.0,
      shadowY: _toDouble(json['shadowY']) ?? 2.0,
      bannerImage: json['bannerImage'] as String?,
      bannerOverlay: _toDouble(json['bannerOverlay']),
    );
  }

  static double? _toDouble(dynamic val) {
    if (val == null) return null;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val);
    return null;
  }

  static Color? _parseColor(dynamic val) {
    if (val == null) return null;
    if (val is int) return Color(val);
    if (val is String) {
      var s = val.trim();
      if (s.startsWith('rgba')) {
        final match = RegExp(
                r'rgba?\((\d+),\s*(\d+),\s*(\d+)(?:,\s*([\d.]+))?\)')
            .firstMatch(s);
        if (match != null) {
          final r = int.parse(match.group(1)!);
          final g = int.parse(match.group(2)!);
          final b = int.parse(match.group(3)!);
          final a =
              match.group(4) != null ? double.parse(match.group(4)!) : 1.0;
          return Color.fromRGBO(r, g, b, a);
        }
      }
      s = s.replaceAll('#', '');
      if (s.length == 6) s = 'FF$s';
      if (s.length == 8) {
        final intVal = int.tryParse(s, radix: 16);
        if (intVal != null) return Color(intVal);
      }
    }
    return null;
  }

  static String? _colorToHex(Color? c) {
    if (c == null) return null;
    return '#${(c.toARGB32() & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0')}';
  }

  static FontWeight? _parseFontWeight(dynamic val) {
    if (val == null) return null;
    final str = val.toString().toLowerCase().trim();
    return switch (str) {
      '100' || 'thin' => FontWeight.w100,
      '200' || 'extralight' => FontWeight.w200,
      '300' || 'light' => FontWeight.w300,
      '400' || 'normal' || 'regular' => FontWeight.w400,
      '500' || 'medium' => FontWeight.w500,
      '600' || 'semibold' => FontWeight.w600,
      '700' || 'bold' => FontWeight.w700,
      '800' || 'extrabold' => FontWeight.w800,
      '900' || 'black' => FontWeight.w900,
      _ => null,
    };
  }

  static String? _fontWeightToString(FontWeight? fw) {
    if (fw == null) return null;
    return '${fw.value}';
  }

  static TextAlign? _parseTextAlign(dynamic val) {
    if (val == null) return null;
    final str = val.toString().toLowerCase().trim();
    return switch (str) {
      'left' => TextAlign.left,
      'center' => TextAlign.center,
      'right' => TextAlign.right,
      'justify' => TextAlign.justify,
      _ => null,
    };
  }
}

class HomeBannerConfig {
  static const String defaultQuote =
      'ការចូលរួមទាន់ពេលវេលា\nវេលា សេចក្តីទទួលខុសត្រូវ\nនិងកិត្តិយសជោគជ័យ';

  static const String defaultAngkorWatAsset =
      'assets/images/angkor_wat_banner.png';

  static const List<Map<String, String>> presetQuotes = [
    {
      'title': 'វិន័យ & ពេលវេលា (Punctuality & Discipline)',
      'quote':
          'ការចូលរួមទាន់ពេលវេលា\nវេលា សេចក្តីទទួលខុសត្រូវ\nនិងកិត្តិយសជោគជ័យ',
    },
    {
      'title': 'សាមគ្គីភាព & ការងារជាក្រុម (Teamwork)',
      'quote': 'ការងារជាក្រុម នាំមកនូវលទ្ធផលល្អ\nសាមគ្គីភាពនាំឱ្យមានជ័យជំនះ',
    },
    {
      'title': 'ចំណេះដឹង & ការតស៊ូ (Knowledge & Effort)',
      'quote':
          'ចំណេះដឹងជាទ្រព្យ កាតព្វកិច្ចជាកិត្តិយស\nការខិតខំប្រឹងប្រែងដើម្បីអនាគត',
    },
    {
      'title': 'ភាពជោគជ័យ & ការប្តេជ្ញា (Success & Commitment)',
      'quote': 'វិន័យគឺជាស្ពានឆ្ពោះទៅរកគោលដៅ\nនិងភាពជោគជ័យដ៏ត្រចះត្រចង់',
    },
  ];

  static const List<Map<String, String>> presetBanners = [
    {
      'title': 'អង្គរវត្ត (Angkor Wat Default)',
      'type': 'angkor',
      'url': '',
      'description': 'Cambodian heritage artwork with dawn silhouette',
    },
    {
      'title': 'ការប្រកាសព័ត៌មាន (Company News)',
      'type': 'url',
      'url':
          'https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?q=80&w=800&auto=format&fit=crop',
      'description': 'Modern corporate announcement header',
    },
    {
      'title': 'ការលើកទឹកចិត្ត (Team Motivation)',
      'type': 'url',
      'url':
          'https://images.unsplash.com/photo-1522071820081-009f0129c71c?q=80&w=800&auto=format&fit=crop',
      'description': 'High-energy collaborative teamwork scene',
    },
    {
      'title': 'ប្រូម៉ូសិនពិសេស (Special Promotion)',
      'type': 'url',
      'url':
          'https://images.unsplash.com/photo-1607082348824-0a96f2a4b9da?q=80&w=800&auto=format&fit=crop',
      'description': 'Vibrant promotional banner for campaigns',
    },
  ];

  final String? bannerImageUrl; // URL (http/https) or asset path
  final String? bannerLinkUrl; // Target link when banner is tapped
  final String? bannerTitle; // Tag/title (e.g. "Special Announcement")
  final String quote; // Motivational quote (ពាក្យស្លោក)
  final String? quoteAuthor; // Quote author or subtitle
  final QuoteStyle? quoteStyle; // Full custom quote style
  final String greetingKhmer; // Khmer greeting (default 'សូមស្វាគមន៍!')
  final bool showQuote; // Whether to display the quote overlay
  final bool isAngkorWatDefault; // Whether default Angkor Wat silhouette is active

  const HomeBannerConfig({
    this.bannerImageUrl,
    this.bannerLinkUrl,
    this.bannerTitle,
    this.quote = defaultQuote,
    this.quoteAuthor,
    this.quoteStyle,
    this.greetingKhmer = 'សូមស្វាគមន៍!',
    this.showQuote = true,
    this.isAngkorWatDefault = true,
  });

  bool get hasCustomBanner =>
      bannerImageUrl != null && bannerImageUrl!.trim().isNotEmpty;

  HomeBannerConfig copyWith({
    String? bannerImageUrl,
    String? bannerLinkUrl,
    String? bannerTitle,
    String? quote,
    String? quoteAuthor,
    QuoteStyle? quoteStyle,
    String? greetingKhmer,
    bool? showQuote,
    bool? isAngkorWatDefault,
  }) {
    return HomeBannerConfig(
      bannerImageUrl: bannerImageUrl ?? this.bannerImageUrl,
      bannerLinkUrl: bannerLinkUrl ?? this.bannerLinkUrl,
      bannerTitle: bannerTitle ?? this.bannerTitle,
      quote: quote ?? this.quote,
      quoteAuthor: quoteAuthor ?? this.quoteAuthor,
      quoteStyle: quoteStyle ?? this.quoteStyle,
      greetingKhmer: greetingKhmer ?? this.greetingKhmer,
      showQuote: showQuote ?? this.showQuote,
      isAngkorWatDefault: isAngkorWatDefault ?? this.isAngkorWatDefault,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bannerImageUrl': bannerImageUrl,
      'bannerLinkUrl': bannerLinkUrl,
      'bannerTitle': bannerTitle,
      'quote': quote,
      'quoteAuthor': quoteAuthor,
      'quoteStyle': quoteStyle?.toJson(),
      'greetingKhmer': greetingKhmer,
      'showQuote': showQuote,
      'isAngkorWatDefault': isAngkorWatDefault,
    };
  }

  factory HomeBannerConfig.fromJson(Map<String, dynamic> json) {
    return HomeBannerConfig(
      bannerImageUrl: json['bannerImageUrl'] as String?,
      bannerLinkUrl: json['bannerLinkUrl'] as String?,
      bannerTitle: json['bannerTitle'] as String?,
      quote: json['quote'] as String? ?? defaultQuote,
      quoteAuthor: json['quoteAuthor'] as String?,
      quoteStyle: json['quoteStyle'] is Map
          ? QuoteStyle.fromJson(
              Map<String, dynamic>.from(json['quoteStyle'] as Map))
          : (json['style'] is Map
              ? QuoteStyle.fromJson(
                  Map<String, dynamic>.from(json['style'] as Map))
              : null),
      greetingKhmer: json['greetingKhmer'] as String? ?? 'សូមស្វាគមន៍!',
      showQuote: json['showQuote'] as bool? ?? true,
      isAngkorWatDefault: json['isAngkorWatDefault'] as bool? ?? true,
    );
  }
}
