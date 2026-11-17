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
  final String greetingKhmer; // Khmer greeting (default 'សូមស្វាគមន៍!')
  final bool showQuote; // Whether to display the quote overlay
  final bool isAngkorWatDefault; // Whether default Angkor Wat silhouette is active

  const HomeBannerConfig({
    this.bannerImageUrl,
    this.bannerLinkUrl,
    this.bannerTitle,
    this.quote = defaultQuote,
    this.quoteAuthor,
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
      greetingKhmer: json['greetingKhmer'] as String? ?? 'សូមស្វាគមន៍!',
      showQuote: json['showQuote'] as bool? ?? true,
      isAngkorWatDefault: json['isAngkorWatDefault'] as bool? ?? true,
    );
  }
}
