import 'package:html/dom.dart' as html_dom;
import 'package:html/parser.dart' as html_parser;
import 'package:characters/characters.dart';

class HomeHighlight {
  const HomeHighlight({
    required this.id,
    required this.title,
    this.body,
    this.imageUrl,
    this.linkUrl,
    this.linkLabel,
    this.priority = 0,
    this.startsAt,
    this.endsAt,
    this.createdAt,
  });

  factory HomeHighlight.fromJson(Map<String, dynamic> json) {
    return HomeHighlight(
      id: int.tryParse('${json['id'] ?? ''}') ?? 0,
      title: (json['title'] ?? '').toString(),
      body: _nullableString(json['body']),
      imageUrl: _nullableString(json['image_url']),
      linkUrl: _nullableString(json['link_url']),
      linkLabel: _nullableString(json['link_label']),
      priority: int.tryParse('${json['priority'] ?? 0}') ?? 0,
      startsAt: _date(json['starts_at']),
      endsAt: _date(json['ends_at']),
      createdAt: _date(json['created_at']),
    );
  }

  final int id;
  final String title;
  final String? body;
  final String? imageUrl;
  final String? linkUrl;
  final String? linkLabel;
  final int priority;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final DateTime? createdAt;

  String get plainBody {
    final fragment = html_parser.parseFragment(body ?? '');
    for (final node
        in fragment.querySelectorAll('script,style,iframe,object')) {
      node.remove();
    }
    for (final node
        in fragment.querySelectorAll('p,br,li,h2,h3,h4,blockquote')) {
      node.nodes.add(html_dom.Text(' '));
    }
    final text = (fragment.text ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
    return text;
  }

  String get snippet {
    final text = plainBody;
    if (text.characters.length <= 140) return text;
    return '${text.characters.take(140).toString().trimRight()}…';
  }

  static String? _nullableString(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static DateTime? _date(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}

class HomeHighlightPage {
  const HomeHighlightPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  final List<HomeHighlight> items;
  final int currentPage;
  final int lastPage;
  final int total;

  bool get hasMore => currentPage < lastPage;
}

class HomeHighlightDisplaySettings {
  const HomeHighlightDisplaySettings(
      {this.autoSwitchEnabled = false,
      this.lateBonusSeconds = 15,
      this.highlightsSeconds = 15});
  factory HomeHighlightDisplaySettings.fromJson(dynamic value) {
    final json = value is Map ? value : const {};
    int seconds(dynamic value) => (int.tryParse('$value') ?? 15).clamp(5, 300);
    return HomeHighlightDisplaySettings(
      autoSwitchEnabled: json['auto_switch_enabled'] == true ||
          json['auto_switch_enabled'] == 1 ||
          json['auto_switch_enabled'] == '1',
      lateBonusSeconds: seconds(json['late_bonus_seconds']),
      highlightsSeconds: seconds(json['highlights_seconds']),
    );
  }
  final bool autoSwitchEnabled;
  final int lateBonusSeconds;
  final int highlightsSeconds;
  bool sameAs(HomeHighlightDisplaySettings other) =>
      autoSwitchEnabled == other.autoSwitchEnabled &&
      lateBonusSeconds == other.lateBonusSeconds &&
      highlightsSeconds == other.highlightsSeconds;
}

class HomeHighlightFeed {
  const HomeHighlightFeed({required this.items, required this.settings});
  final List<HomeHighlight> items;
  final HomeHighlightDisplaySettings settings;
}
