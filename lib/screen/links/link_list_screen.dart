import 'package:cached_network_image/cached_network_image.dart';
import 'package:cnattendance/model/app_link.dart';
import 'package:cnattendance/provider/app_link_controller.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:cnattendance/widget/premium_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:get/get.dart';
import 'package:cnattendance/core/theme/app_colors.dart';

class LinkListScreen extends StatefulWidget {
  const LinkListScreen({Key? key}) : super(key: key);

  @override
  State<LinkListScreen> createState() => _LinkListScreenState();
}

class _LinkListScreenState extends State<LinkListScreen> {
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, dynamic>> _filterOptions = [
    {
      'key': 'all',
      'label': translate('link_screen.all'),
      'icon': Icons.grid_view_rounded
    },
    {'key': 'telegram', 'label': 'Telegram', 'icon': Icons.send_rounded},
    {'key': 'facebook', 'label': 'Facebook', 'icon': Icons.facebook_rounded},
    {'key': 'tiktok', 'label': 'TikTok', 'icon': Icons.music_note_rounded},
    {
      'key': 'instagram',
      'label': 'Instagram',
      'icon': Icons.camera_alt_rounded
    },
    {
      'key': 'youtube',
      'label': 'YouTube',
      'icon': Icons.play_circle_fill_rounded
    },
    {'key': 'website', 'label': 'Website', 'icon': Icons.language_rounded},
    {'key': 'other', 'label': 'Other', 'icon': Icons.link_rounded},
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(AppLinkController());
    final enterprise = EnterpriseTheme.of(context);

    return PremiumBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 20, color: AppColors.white),
            onPressed: () => Navigator.maybePop(context),
          ),
          title: Row(
            children: [
              Text(
                translate('link_screen.title'),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: AppColors.white,
                ),
              ),
              const SizedBox(width: 8),
              Obx(() {
                final count = controller.filteredLinks.length;
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: enterprise.accent.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: enterprise.accent.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: enterprise.accent,
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        body: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.white
                      .withValues(alpha: enterprise.isDark ? 0.08 : 0.18),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: enterprise.glassStroke),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => controller.setSearchQuery(val),
                  style:
                      const TextStyle(color: AppColors.white, fontSize: 13.5),
                  decoration: InputDecoration(
                    hintText: 'Search links, apps or websites...',
                    hintStyle: TextStyle(
                      color: AppColors.white.withValues(alpha: 0.5),
                      fontSize: 13,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: AppColors.white.withValues(alpha: 0.6),
                    ),
                    suffixIcon: Obx(() {
                      if (controller.searchQuery.value.isNotEmpty) {
                        return IconButton(
                          icon: const Icon(Icons.clear_rounded,
                              size: 18, color: AppColors.white70),
                          onPressed: () {
                            _searchController.clear();
                            controller.clearSearch();
                          },
                        );
                      }
                      return const SizedBox.shrink();
                    }),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),

            // Filter Chips Bar
            SizedBox(
              height: 38,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: _filterOptions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final option = _filterOptions[index];
                  return Obx(() {
                    final isSelected =
                        controller.selectedFilter.value == option['key'];
                    return InkWell(
                      borderRadius: BorderRadius.circular(19),
                      onTap: () => controller.setFilter(option['key']!),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(19),
                          gradient: isSelected
                              ? LinearGradient(
                                  colors: [
                                    enterprise.primary,
                                    enterprise.accent
                                  ],
                                )
                              : null,
                          color: isSelected
                              ? null
                              : AppColors.white.withValues(alpha: 0.08),
                          border: Border.all(
                            color: isSelected
                                ? Colors.transparent
                                : AppColors.white.withValues(alpha: 0.15),
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: enterprise.accent
                                        .withValues(alpha: 0.35),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  )
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              option['icon'] as IconData,
                              size: 15,
                              color: isSelected
                                  ? AppColors.white
                                  : AppColors.white70,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              option['label']! as String,
                              style: TextStyle(
                                color: isSelected
                                    ? AppColors.white
                                    : AppColors.white70,
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  });
                },
              ),
            ),
            const SizedBox(height: 8),

            // Links List
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value && controller.links.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.white),
                  );
                }

                final displayList = controller.filteredLinks;

                return RefreshIndicator(
                  color: AppColors.white,
                  backgroundColor: enterprise.primary,
                  onRefresh: () => controller.getLinks(),
                  child: displayList.isEmpty
                      ? ListView(
                          children: [
                            SizedBox(
                                height:
                                    MediaQuery.of(context).size.height * 0.2),
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 72,
                                    height: 72,
                                    decoration: BoxDecoration(
                                      color: AppColors.white
                                          .withValues(alpha: 0.08),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.link_off_rounded,
                                      size: 38,
                                      color: AppColors.white
                                          .withValues(alpha: 0.4),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    translate('link_screen.no_links'),
                                    style: TextStyle(
                                      color: AppColors.white
                                          .withValues(alpha: 0.8),
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                          itemCount: displayList.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final link = displayList[index];
                            return _buildLinkCard(
                                context, link, controller, enterprise);
                          },
                        ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkCard(
    BuildContext context,
    AppLink link,
    AppLinkController controller,
    EnterpriseTheme enterprise,
  ) {
    final typeConfig = _getLinkTypeConfig(link.linkType);

    return Container(
      decoration: BoxDecoration(
        color:
            AppColors.white.withValues(alpha: enterprise.isDark ? 0.07 : 0.16),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: enterprise.glassStroke),
        boxShadow: [
          BoxShadow(
            color: AppColors.black
                .withValues(alpha: enterprise.isDark ? 0.2 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => controller.launchLink(link.url),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Brand Icon / Image
                    _buildLeadingIcon(link, typeConfig),
                    const SizedBox(width: 12),

                    // Name, Type Badge & Description
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  link.name,
                                  style: const TextStyle(
                                    color: AppColors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color:
                                      typeConfig.color.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: typeConfig.color
                                        .withValues(alpha: 0.38),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(typeConfig.icon,
                                        size: 11, color: typeConfig.color),
                                    const SizedBox(width: 4),
                                    Text(
                                      typeConfig.name,
                                      style: TextStyle(
                                        color: typeConfig.color,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (link.description != null &&
                              link.description!.trim().isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Text(
                              link.description!,
                              style: TextStyle(
                                color: AppColors.white.withValues(alpha: 0.72),
                                fontSize: 12.5,
                                height: 1.35,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Interactive URL Capsule
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.black.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.white.withValues(alpha: 0.08)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.link_rounded,
                        size: 14,
                        color: AppColors.white.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          link.url,
                          style: TextStyle(
                            color: AppColors.blue.shade200,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        Icons.arrow_outward_rounded,
                        size: 14,
                        color: AppColors.white.withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),
                Divider(
                    height: 1, color: AppColors.white.withValues(alpha: 0.09)),
                const SizedBox(height: 8),

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => controller.copyLink(context, link.url),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.copy_rounded,
                                size: 14,
                                color: AppColors.white.withValues(alpha: 0.75),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                translate('link_screen.copy_link'),
                                style: TextStyle(
                                  color: AppColors.white.withValues(alpha: 0.8),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => controller.launchLink(link.url),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              typeConfig.color,
                              typeConfig.color.withValues(alpha: 0.82),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: typeConfig.color.withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.open_in_new_rounded,
                                size: 13, color: AppColors.white),
                            const SizedBox(width: 5),
                            Text(
                              translate('link_screen.open_link'),
                              style: const TextStyle(
                                color: AppColors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeadingIcon(AppLink link, _LinkTypeConfig config) {
    if (link.image != null && link.image!.trim().isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: link.image!,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.white30),
              ),
            ),
          ),
          errorWidget: (context, url, error) => _buildFallbackIcon(config),
        ),
      );
    }
    return _buildFallbackIcon(config);
  }

  Widget _buildFallbackIcon(_LinkTypeConfig config) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: config.color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: config.color.withValues(alpha: 0.38)),
      ),
      child: Center(
        child: Icon(
          config.icon,
          color: config.color,
          size: 22,
        ),
      ),
    );
  }

  _LinkTypeConfig _getLinkTypeConfig(String type) {
    switch (type.toLowerCase()) {
      case 'facebook':
        return _LinkTypeConfig(
            'Facebook', AppColors.customFF1877F2, Icons.facebook_rounded);
      case 'tiktok':
        return _LinkTypeConfig(
            'TikTok', AppColors.customFFEE1D52, Icons.music_note_rounded);
      case 'telegram':
        return _LinkTypeConfig(
            'Telegram', AppColors.customFF24A1DE, Icons.send_rounded);
      case 'instagram':
        return _LinkTypeConfig(
            'Instagram', AppColors.customFFE4405F, Icons.camera_alt_rounded);
      case 'youtube':
        return _LinkTypeConfig('YouTube', AppColors.customFFCD201F,
            Icons.play_circle_fill_rounded);
      case 'website':
        return _LinkTypeConfig(
            'Website', AppColors.successToken, Icons.language_rounded);
      default:
        return _LinkTypeConfig(
            'Other', AppColors.customFF8B5CF6, Icons.link_rounded);
    }
  }
}

class _LinkTypeConfig {
  final String name;
  final Color color;
  final IconData icon;

  _LinkTypeConfig(this.name, this.color, this.icon);
}
