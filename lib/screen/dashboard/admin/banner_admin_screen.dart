import 'package:cached_network_image/cached_network_image.dart';
import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/features/banner_slideshow/banner_slideshow_api.dart';
import 'package:cnattendance/model/banner_slideshow_config.dart';
import 'package:cnattendance/model/home_banner_config.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:cnattendance/widget/radialDecoration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

/// Admin panel screen for the home hero banner slideshow.
///
/// Managed from More → Admin → Banner Manager (feature flag `banner-admin`).
/// Stores the banner settings on the server for use across staff devices.
class BannerAdminScreen extends StatefulWidget {
  const BannerAdminScreen({super.key});

  @override
  State<BannerAdminScreen> createState() => _BannerAdminScreenState();
}

class _BannerAdminScreenState extends State<BannerAdminScreen> {
  final Preferences _preferences = Preferences();
  final BannerSlideshowApi _api = BannerSlideshowApi();

  BannerSlideshowConfig _config = const BannerSlideshowConfig();
  bool _loading = true;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    BannerSlideshowConfig config;
    try {
      config = await _api.fetch();
      await _preferences.saveHomeSlideshow(config);
    } catch (_) {
      config = await _preferences.getHomeSlideshow();
    }
    if (!mounted) return;
    setState(() {
      _config = config;
      _loading = false;
      _dirty = false;
    });
  }

  void _update(BannerSlideshowConfig next) {
    setState(() {
      _config = next;
      _dirty = true;
    });
  }

  Future<void> _save() async {
    EasyLoading.show(status: 'Saving...');
    try {
      final saved = await _api.save(_config);
      await _preferences.saveHomeSlideshow(saved);
      if (!mounted) return;
      setState(() {
        _config = saved;
        _dirty = false;
      });
      EasyLoading.dismiss();
      EasyLoading.showSuccess('បានរក្សាទុកដោយជោគជ័យ / Saved successfully');
    } catch (error) {
      EasyLoading.dismiss();
      EasyLoading.showError('Unable to save banner: $error');
    }
  }

  Future<void> _resetAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ស្តារបដាដើម / Reset Banner'),
        content: const Text(
          'លុបបដាទាំងអស់ និងកំណត់ slideshow ទៅលំនាំដើមអង្គរវត្ត?\n'
          'Remove all slides and restore the default Angkor Wat banner?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child:
                const Text('Reset', style: TextStyle(color: Color(0xFFDC2626))),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    EasyLoading.show(status: 'Resetting...');
    try {
      final config = await _api.reset();
      await _preferences.saveHomeSlideshow(config);
      if (!mounted) return;
      setState(() {
        _config = config;
        _dirty = false;
      });
      EasyLoading.dismiss();
      EasyLoading.showToast('បានស្តាររូបអង្គរវត្ត / Banner reset to default');
    } catch (error) {
      EasyLoading.dismiss();
      EasyLoading.showError('Unable to reset banner: $error');
    }
  }

  Future<void> _editSlide({int? index}) async {
    final existing = index != null ? _config.slides[index] : null;
    final imageUrlController =
        TextEditingController(text: existing?.imageUrl ?? '');
    final linkController = TextEditingController(text: existing?.linkUrl ?? '');
    final titleController = TextEditingController(text: existing?.title ?? '');

    final result = await showDialog<_SlideDraft>(
      context: context,
      builder: (ctx) => _SlideEditDialog(
        imageUrlController: imageUrlController,
        linkController: linkController,
        titleController: titleController,
        isEdit: existing != null,
      ),
    );

    if (result != null) {
      final slide = BannerSlide(
        id: existing?.id ?? BannerSlide.newId(),
        imageUrl: result.imageUrl,
        linkUrl: result.linkUrl,
        title: result.title,
        enabled: existing?.enabled ?? true,
      );
      final slides = List<BannerSlide>.from(_config.slides);
      if (index != null) {
        slides[index] = slide;
      } else {
        slides.add(slide);
      }
      _update(_config.copyWith(slides: slides));
    }

    imageUrlController.dispose();
    linkController.dispose();
    titleController.dispose();
  }

  void _removeSlide(int index) {
    final slides = List<BannerSlide>.from(_config.slides)..removeAt(index);
    _update(_config.copyWith(slides: slides));
  }

  void _toggleSlide(int index, bool enabled) {
    final slides = List<BannerSlide>.from(_config.slides);
    slides[index] = slides[index].copyWith(enabled: enabled);
    _update(_config.copyWith(slides: slides));
  }

  void _moveSlide(int oldIndex, int newIndex) {
    if (newIndex == oldIndex) return;
    final slides = List<BannerSlide>.from(_config.slides);
    final item = slides.removeAt(oldIndex);
    slides.insert(newIndex, item);
    _update(_config.copyWith(slides: slides));
  }

  @override
  Widget build(BuildContext context) {
    final enterprise = EnterpriseTheme.of(context);

    return Container(
      decoration: RadialDecoration(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          title: const Text('Banner Manager'),
          actions: [
            if (_dirty)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFF59E0B),
                        width: 0.8,
                      ),
                    ),
                    child: const Text(
                      'Unsaved',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFF59E0B),
                      ),
                    ),
                  ),
                ),
              ),
            IconButton(
              tooltip: 'Reset to default',
              onPressed: _loading ? null : _resetAll,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 100),
                  children: [
                    _buildPreviewCard(enterprise),
                    const SizedBox(height: 12),
                    _buildSettingsCard(enterprise),
                    const SizedBox(height: 12),
                    _buildSlidesCard(enterprise),
                    const SizedBox(height: 12),
                    _buildInfoCard(enterprise),
                  ],
                ),
              ),
        bottomNavigationBar: _loading
            ? null
            : Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                decoration: BoxDecoration(
                  color: enterprise.isDark
                      ? const Color(0xFF0F172A)
                      : Colors.white,
                  border: Border(
                    top: BorderSide(color: enterprise.cardBorder),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          side: BorderSide(color: enterprise.cardBorder),
                        ),
                        onPressed: _dirty ? _save : null,
                        child: Text(
                          'Save & Apply',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: enterprise.text,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: enterprise.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _save,
                        child: const Text(
                          'Save',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  // ==========================================================================
  // Preview
  // ==========================================================================
  Widget _buildPreviewCard(EnterpriseTheme enterprise) {
    final slides = _config.enabledSlides;
    final preview = slides.isNotEmpty
        ? slides.first
        : const BannerSlide(id: 'preview-default');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: enterprise.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: enterprise.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.visibility_rounded,
                  size: 15, color: enterprise.accent),
              const SizedBox(width: 6),
              Text(
                'មើលជាមុន / Live Preview',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                  color: enterprise.text,
                ),
              ),
              const Spacer(),
              Text(
                '${slides.length} active slide${slides.length == 1 ? '' : 's'}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: enterprise.mutedText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              height: 96,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF071B45),
                    Color(0xFF0E3A8C),
                    Color(0xFF1A5ED4),
                  ],
                  stops: [0.0, 0.55, 1.0],
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (preview.hasImage)
                    if (preview.isNetworkImage)
                      CachedNetworkImage(
                        imageUrl: preview.imageUrl.trim(),
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const SizedBox.shrink(),
                      )
                    else
                      Image.asset(
                        preview.imageUrl.trim(),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      )
                  else
                    Positioned.fill(
                      child: Image.asset(
                        HomeBannerConfig.defaultAngkorWatAsset,
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          const Color(0xFF002255).withValues(alpha: 0.88),
                          const Color(0xFF003D99).withValues(alpha: 0.55),
                          Colors.black.withValues(alpha: 0.35),
                        ],
                        stops: const [0.0, 0.55, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    top: 12,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (preview.title.trim().isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.24),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.35),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              preview.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        const SizedBox(height: 4),
                        const Text(
                          'សូមស្វាគមន៍!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Text(
                          'Good Morning!',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_config.showIndicators && slides.length > 1)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 6,
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(
                            slides.length > 6 ? 6 : slides.length,
                            (index) => Container(
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              width: index == 0 ? 12 : 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: index == 0
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.45),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // Slideshow settings (speed, transitions, indicators, …)
  // ==========================================================================
  Widget _buildSettingsCard(EnterpriseTheme enterprise) {
    final interval = _config.effectiveIntervalSeconds;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: enterprise.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: enterprise.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.speed_rounded, size: 16, color: enterprise.accent),
              const SizedBox(width: 6),
              Text(
                'ការកំណត់ Slideshow / Slideshow Settings',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: enterprise.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _settingSwitchRow(
            enterprise: enterprise,
            title: 'លេងស្វ័យប្រវត្តិ',
            subtitle: 'Auto-rotate slides',
            value: _config.autoplay,
            onChanged: (value) => _update(_config.copyWith(autoplay: value)),
          ),
          const Divider(height: 18),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ល្បឿន Slideshow',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: enterprise.text,
                      ),
                    ),
                    Text(
                      'Speed · $interval seconds per slide',
                      style: TextStyle(
                        fontSize: 11,
                        color: enterprise.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: enterprise.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: enterprise.accent.withValues(alpha: 0.45),
                  ),
                ),
                child: Text(
                  '${interval}s',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: enterprise.accent,
                  ),
                ),
              ),
            ],
          ),
          Slider(
            value: interval.toDouble(),
            min: BannerSlideshowConfig.minIntervalSeconds.toDouble(),
            max: BannerSlideshowConfig.maxIntervalSeconds.toDouble(),
            divisions: BannerSlideshowConfig.maxIntervalSeconds -
                BannerSlideshowConfig.minIntervalSeconds,
            label: '${interval}s',
            activeColor: enterprise.accent,
            onChanged: (value) => _update(
              _config.copyWith(intervalSeconds: value.round()),
            ),
          ),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [3, 5, 7, 10, 15].map((seconds) {
              final selected = interval == seconds;
              return ActionChip(
                avatar: Icon(
                  selected ? Icons.check_circle_rounded : Icons.timer_outlined,
                  size: 14,
                  color: selected ? enterprise.accent : enterprise.mutedText,
                ),
                label: Text(
                  '${seconds}s',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: enterprise.text,
                  ),
                ),
                backgroundColor: selected
                    ? enterprise.accent.withValues(alpha: 0.16)
                    : (enterprise.isDark
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFF1F5F9)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: selected ? enterprise.accent : enterprise.cardBorder,
                  ),
                ),
                onPressed: () => _update(
                  _config.copyWith(intervalSeconds: seconds),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          Text(
            'ប្តូររូបភាព / Transition',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: enterprise.text,
            ),
          ),
          const SizedBox(height: 7),
          DropdownButtonFormField<String>(
            key: ValueKey(_config.transition),
            initialValue: _config.transition,
            isExpanded: true,
            items: [
              for (final option in BannerSlideshowConfig.transitionLabels.entries)
                DropdownMenuItem(value: option.key, child: Text(option.value)),
            ],
            onChanged: (value) {
              if (value != null) _update(_config.copyWith(transition: value));
            },
          ),
          const Divider(height: 18),
          _settingSwitchRow(
            enterprise: enterprise,
            title: 'បង្ហាញចំណុចសម្គាល់',
            subtitle: 'Show dot indicators',
            value: _config.showIndicators,
            onChanged: (value) =>
                _update(_config.copyWith(showIndicators: value)),
          ),
          _settingSwitchRow(
            enterprise: enterprise,
            title: 'ឈប់ពេលប៉ះ',
            subtitle: 'Pause while touching the banner',
            value: _config.pauseOnTouch,
            onChanged: (value) =>
                _update(_config.copyWith(pauseOnTouch: value)),
          ),
          _settingSwitchRow(
            enterprise: enterprise,
            title: 'បង្វិលជាប់ដដែល',
            subtitle: 'Loop back to the first slide',
            value: _config.loop,
            onChanged: (value) => _update(_config.copyWith(loop: value)),
          ),
        ],
      ),
    );
  }

  Widget _settingSwitchRow({
    required EnterpriseTheme enterprise,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: enterprise.text,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(fontSize: 10.5, color: enterprise.mutedText),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          activeThumbColor: enterprise.accent,
          onChanged: onChanged,
        ),
      ],
    );
  }

  // ==========================================================================
  // Slides list
  // ==========================================================================
  Widget _buildSlidesCard(EnterpriseTheme enterprise) {
    final slides = _config.slides;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: enterprise.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: enterprise.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.view_carousel_rounded,
                  size: 16, color: enterprise.accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'បញ្ជីបដា / Slides (${slides.length})',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: enterprise.text,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _editSlide,
                icon:
                    Icon(Icons.add_rounded, size: 17, color: enterprise.accent),
                label: Text(
                  'Add slide',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: enterprise.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (slides.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 22),
              decoration: BoxDecoration(
                color: enterprise.isDark
                    ? const Color(0xFF0F172A)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: enterprise.cardBorder),
              ),
              child: Column(
                children: [
                  Icon(Icons.image_outlined,
                      size: 28, color: enterprise.mutedText),
                  const SizedBox(height: 8),
                  Text(
                    'No slides yet — default Angkor Wat banner is showing',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: enterprise.mutedText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'បន្ថែមបដាដំបូង / Add your first slide',
                    style: TextStyle(
                      fontSize: 11,
                      color: enterprise.mutedText,
                    ),
                  ),
                ],
              ),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: slides.length,
              onReorder: _moveSlide,
              itemBuilder: (context, index) {
                final slide = slides[index];
                return Container(
                  key: ValueKey(slide.id),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: _buildSlideTile(
                    enterprise: enterprise,
                    slide: slide,
                    index: index,
                    total: slides.length,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSlideTile({
    required EnterpriseTheme enterprise,
    required BannerSlide slide,
    required int index,
    required int total,
  }) {
    return Opacity(
      opacity: slide.enabled ? 1 : 0.55,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: enterprise.isDark
              ? const Color(0xFF0F172A)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: enterprise.cardBorder),
        ),
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: index,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.drag_indicator_rounded,
                    size: 18, color: enterprise.mutedText),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: SizedBox(
                width: 54,
                height: 40,
                child: _slideThumbnail(slide),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    slide.title.trim().isEmpty
                        ? (slide.hasImage
                            ? 'Untitled slide'
                            : 'Angkor Wat (default)')
                        : slide.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: enterprise.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    slide.hasLink ? slide.linkUrl : 'No action link',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: enterprise.mutedText,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: slide.enabled,
              activeThumbColor: enterprise.accent,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: (value) => _toggleSlide(index, value),
            ),
            IconButton(
              tooltip: 'Edit',
              visualDensity: VisualDensity.compact,
              onPressed: () => _editSlide(index: index),
              icon:
                  Icon(Icons.edit_rounded, size: 17, color: enterprise.accent),
            ),
            IconButton(
              tooltip: 'Delete',
              visualDensity: VisualDensity.compact,
              onPressed: () => _removeSlide(index),
              icon: const Icon(Icons.delete_outline_rounded,
                  size: 17, color: Color(0xFFDC2626)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _slideThumbnail(BannerSlide slide) {
    if (!slide.hasImage) {
      return Image.asset(
        HomeBannerConfig.defaultAngkorWatAsset,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(color: const Color(0xFF0E3A8C)),
      );
    }
    if (slide.isNetworkImage) {
      return CachedNetworkImage(
        imageUrl: slide.imageUrl.trim(),
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(color: const Color(0xFF0E3A8C)),
        errorWidget: (_, __, ___) => Container(color: const Color(0xFF0E3A8C)),
      );
    }
    return Image.asset(
      slide.imageUrl.trim(),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(color: const Color(0xFF0E3A8C)),
    );
  }

  Widget _buildInfoCard(EnterpriseTheme enterprise) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: enterprise.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: enterprise.accent.withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: enterprise.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'បដានេះត្រូវបានគ្រប់គ្រងសម្រាប់ឧបករណ៍នេះ។ សូមរក្សាទុកក្រោយកែប្រែ។\n'
              'This slideshow is stored on this device. Tap Save & Apply after editing.',
              style: TextStyle(
                fontSize: 11,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: enterprise.text.withValues(alpha: 0.82),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SlideDraft {
  final String imageUrl;
  final String linkUrl;
  final String title;

  const _SlideDraft({
    required this.imageUrl,
    required this.linkUrl,
    required this.title,
  });
}

class _SlideEditDialog extends StatefulWidget {
  final TextEditingController imageUrlController;
  final TextEditingController linkController;
  final TextEditingController titleController;
  final bool isEdit;

  const _SlideEditDialog({
    required this.imageUrlController,
    required this.linkController,
    required this.titleController,
    required this.isEdit,
  });

  @override
  State<_SlideEditDialog> createState() => _SlideEditDialogState();
}

class _SlideEditDialogState extends State<_SlideEditDialog> {
  @override
  Widget build(BuildContext context) {
    final enterprise = EnterpriseTheme.of(context);
    final inputFill =
        enterprise.isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color),
        );

    return Dialog(
      backgroundColor:
          enterprise.isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isEdit ? 'កែប្រែបដា / Edit Slide' : 'បដាថ្មី / New Slide',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: enterprise.text,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: widget.titleController,
              style: TextStyle(fontSize: 13, color: enterprise.text),
              decoration: InputDecoration(
                labelText: 'ចំណងជើង / Title',
                hintText: 'Special Announcement',
                prefixIcon: Icon(Icons.label_outline_rounded,
                    size: 18, color: enterprise.mutedText),
                filled: true,
                fillColor: inputFill,
                border: border(enterprise.cardBorder),
                enabledBorder: border(enterprise.cardBorder),
                focusedBorder: border(enterprise.accent),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: widget.imageUrlController,
              style: TextStyle(fontSize: 13, color: enterprise.text),
              decoration: InputDecoration(
                labelText: 'រូបភាព / Image URL',
                hintText: 'https://example.com/banner.jpg',
                helperText: 'ទុកទទេ = អង្គរវត្ត / Leave empty = Angkor Wat',
                helperMaxLines: 2,
                prefixIcon: Icon(Icons.image_rounded,
                    size: 18, color: enterprise.mutedText),
                suffixIcon: IconButton(
                  tooltip: 'Clear → default artwork',
                  icon: Icon(Icons.clear_rounded,
                      size: 16, color: enterprise.mutedText),
                  onPressed: () =>
                      setState(() => widget.imageUrlController.clear()),
                ),
                filled: true,
                fillColor: inputFill,
                border: border(enterprise.cardBorder),
                enabledBorder: border(enterprise.cardBorder),
                focusedBorder: border(enterprise.accent),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: HomeBannerConfig.presetBanners.map((preset) {
                final isAngkor = preset['type'] == 'angkor';
                return ActionChip(
                  avatar: Icon(
                    isAngkor
                        ? Icons.temple_buddhist_rounded
                        : Icons.star_rounded,
                    size: 14,
                    color: enterprise.accent,
                  ),
                  label: Text(
                    preset['title']!,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: enterprise.text,
                    ),
                  ),
                  backgroundColor: enterprise.isDark
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFF1F5F9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: enterprise.cardBorder),
                  ),
                  onPressed: () => setState(() {
                    widget.imageUrlController.text =
                        isAngkor ? '' : preset['url']!;
                    if (widget.titleController.text.trim().isEmpty) {
                      widget.titleController.text = preset['title']!;
                    }
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: widget.linkController,
              style: TextStyle(fontSize: 13, color: enterprise.text),
              decoration: InputDecoration(
                labelText: 'តំណពេលចុច / Action Link (optional)',
                hintText: 'https://example.com/promotion',
                prefixIcon: Icon(Icons.link_rounded,
                    size: 18, color: enterprise.mutedText),
                filled: true,
                fillColor: inputFill,
                border: border(enterprise.cardBorder),
                enabledBorder: border(enterprise.cardBorder),
                focusedBorder: border(enterprise.accent),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'បោះបង់ / Cancel',
                    style: TextStyle(
                      color: enterprise.mutedText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: enterprise.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop(_SlideDraft(
                      imageUrl: widget.imageUrlController.text.trim(),
                      linkUrl: widget.linkController.text.trim(),
                      title: widget.titleController.text.trim(),
                    ));
                  },
                  child: const Text(
                    'បន្ថែម / Apply',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
