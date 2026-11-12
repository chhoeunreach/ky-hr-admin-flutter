import 'package:flutter/material.dart';
import 'home_highlight_api.dart';
import 'home_highlight_detail_screen.dart';
import 'home_highlights_strings.dart';
import '../../models/home_highlight.dart';

int? homeHighlightNotificationId(Map<String, dynamic> payload) {
  if (payload['type']?.toString() != 'home_highlight') return null;
  final id =
      int.tryParse('${payload['home_highlight_id'] ?? payload['id'] ?? ''}');
  return id != null && id > 0 ? id : null;
}

/// Fetch from the authenticated API when opening an alert, so removed or
/// retargeted highlights are never shown using stale notification content.
class HomeHighlightOpenScreen extends StatefulWidget {
  const HomeHighlightOpenScreen({super.key, required this.id, this.api});
  final int id;
  final HomeHighlightApi? api;
  @override
  State<HomeHighlightOpenScreen> createState() =>
      _HomeHighlightOpenScreenState();
}

class _HomeHighlightOpenScreenState extends State<HomeHighlightOpenScreen> {
  late final _api = widget.api ?? HomeHighlightApi();
  HomeHighlight? _highlight;
  String? _error;
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    if (widget.api == null) _api.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final item = await _api.show(widget.id);
      if (mounted)
        setState(() {
          _highlight = item;
          _loading = false;
        });
    } catch (error) {
      if (mounted)
        setState(() {
          _error = error.toString();
          _loading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_highlight != null)
      return HomeHighlightDetailScreen(highlight: _highlight!);
    return Scaffold(
      appBar: AppBar(title: Text(homeHighlightsText('Highlight'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.info_outline, size: 40),
                    const SizedBox(height: 12),
                    Text(
                        _error ??
                            homeHighlightsText(
                                'This highlight is unavailable.'),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
                        label: Text(homeHighlightsText('Retry'))),
                  ])),
            ),
    );
  }
}
