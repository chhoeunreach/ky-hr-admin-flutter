import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:cnattendance/widget/premium_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/repair_price_config.dart';
import '../models/repair_device.dart';
import '../models/repair_service.dart';
import '../providers/repair_price_provider.dart';
import '../widgets/repair_category_filter.dart';
import '../widgets/repair_detail_bottom_sheet.dart';
import '../widgets/repair_edit_price_sheet.dart';
import '../widgets/repair_price_card.dart';
import '../widgets/repair_search_bar.dart';
import '../widgets/repair_service_card.dart';
import '../widgets/repair_status_badge.dart';

class RepairPriceDetailPage extends StatelessWidget {
  final RepairDevice device;
  final RepairPriceProvider? provider;

  const RepairPriceDetailPage({
    super.key,
    required this.device,
    this.provider,
  });

  @override
  Widget build(BuildContext context) {
    if (provider != null) {
      return ChangeNotifierProvider.value(
        value: provider!,
        child: _RepairPriceDetailView(device: device),
      );
    }
    return ChangeNotifierProvider(
      create: (_) => RepairPriceProvider()..setSelectedDevice(device),
      child: _RepairPriceDetailView(device: device),
    );
  }
}

class _RepairPriceDetailView extends StatelessWidget {
  final RepairDevice device;

  const _RepairPriceDetailView({required this.device});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RepairPriceProvider>();
    final enterprise = EnterpriseTheme.of(context);

    return PremiumBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          toolbarHeight: 50,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                size: 18, color: enterprise.text),
            onPressed: () => Navigator.maybePop(context),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                device.name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: enterprise.text,
                ),
              ),
              Text(
                translate('repair_screen.repair_prices'),
                style: TextStyle(
                  fontSize: 11,
                  color: enterprise.mutedText,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(color: enterprise.glassStroke, height: 1),
          ),
        ),
        body: !provider.canView
            ? _buildAccessDenied(context, provider)
            : LayoutBuilder(
                builder: (context, constraints) {
                  final isTablet = constraints.maxWidth >= 600;

                  if (isTablet) {
                    return _buildTabletLayout(context, provider);
                  }

                  return _buildMobileLayout(context, provider);
                },
              ),
      ),
    );
  }

  Widget _buildAccessDenied(
      BuildContext context, RepairPriceProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: RepairPriceConfig.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_person_rounded,
                size: 64,
                color: RepairPriceConfig.error,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'លោកអ្នកគ្មានសិទ្ធិចូលមើលទេ',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: RepairPriceConfig.mainText,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Access Denied: You do not have permission (repair_price.view) to view this module.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: RepairPriceConfig.secondaryText,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: RepairPriceConfig.primaryBlue,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('ព្យាយាមម្ដងទៀត / Retry'),
              onPressed: () async {
                await provider.loadWebPermissions();
                if (provider.canView) {
                  provider.initServiceDetailPage();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- Mobile Layout ---
  Widget _buildMobileLayout(
      BuildContext context, RepairPriceProvider provider) {
    return Column(
      children: [
        _buildHeader(context, provider),
        Expanded(
          child: RefreshIndicator(
            color: RepairPriceConfig.primaryBlue,
            backgroundColor: RepairPriceConfig.card,
            onRefresh: () => provider.loadServices(),
            child: _buildServiceList(context, provider, isTablet: false),
          ),
        ),
      ],
    );
  }

  // --- Tablet Master-Detail Layout ---
  Widget _buildTabletLayout(
      BuildContext context, RepairPriceProvider provider) {
    final enterprise = EnterpriseTheme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // LEFT: Master list
        Expanded(
          flex: 5,
          child: Column(
            children: [
              _buildHeader(context, provider),
              Expanded(
                child: RefreshIndicator(
                  color: enterprise.accent,
                  backgroundColor: enterprise.primary,
                  onRefresh: () => provider.loadServices(),
                  child: _buildServiceList(context, provider, isTablet: true),
                ),
              ),
            ],
          ),
        ),

        // Divider
        Container(width: 1, color: enterprise.glassStroke),

        // RIGHT: Selected Service Detail Panel
        Expanded(
          flex: 6,
          child: Container(
            color:
                Colors.white.withValues(alpha: enterprise.isDark ? 0.04 : 0.08),
            child: provider.selectedService != null
                ? _buildTabletDetailPanel(
                    context, provider, provider.selectedService!)
                : Center(
                    child: Text(
                      'ជ្រើសរើសសេវាកម្មដើម្បីមើលព័ត៌មានលម្អិត\nSelect a service to view details',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: enterprise.mutedText,
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, RepairPriceProvider provider) {
    final enterprise = EnterpriseTheme.of(context);
    return Container(
      color: Colors.white.withValues(alpha: enterprise.isDark ? 0.06 : 0.12),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Device Info Card Banner
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: enterprise.glassStroke, width: 0.8),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: enterprise.glassStroke, width: 0.8),
                    ),
                    child: device.image.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: device.image,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Icon(
                                Icons.phone_iphone_rounded,
                                color: enterprise.accent,
                                size: 20,
                              ),
                            ),
                          )
                        : Icon(
                            Icons.phone_iphone_rounded,
                            color: enterprise.accent,
                            size: 20,
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          device.name,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: enterprise.text,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          [
                            if (device.brand != null) device.brand!.name,
                            if (device.series != null) device.series!.name,
                            if (device.modelNumber.isNotEmpty)
                              device.modelNumber,
                          ].join(' • '),
                          style: TextStyle(
                            fontSize: 11,
                            color: enterprise.mutedText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: RepairSearchBar(
              hintText: translate('repair_screen.search_service_hint'),
              onChanged: provider.onServiceSearchChanged,
              onClear: () => provider.onServiceSearchChanged(''),
            ),
          ),

          // Category Filters
          if (provider.categories.isNotEmpty) ...[
            const SizedBox(height: 7),
            RepairCategoryFilter(
              categories: provider.categories,
              selectedCategoryId: provider.selectedCategoryId,
              onCategorySelected: provider.selectCategory,
              onAddCategory: null,
              onEditCategory: null,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildServiceList(BuildContext context, RepairPriceProvider provider,
      {required bool isTablet}) {
    final enterprise = EnterpriseTheme.of(context);
    switch (provider.serviceLoadingState) {
      case RepairLoadingState.loading:
      case RepairLoadingState.initial:
        return const Center(
          child: CircularProgressIndicator(
            color: RepairPriceConfig.primaryBlue,
            strokeWidth: 2.5,
          ),
        );

      case RepairLoadingState.unauthorized:
      case RepairLoadingState.forbidden:
      case RepairLoadingState.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  provider.serviceLoadingState ==
                          RepairLoadingState.unauthorized
                      ? Icons.lock_outline_rounded
                      : Icons.wifi_off_rounded,
                  size: 48,
                  color: RepairPriceConfig.error,
                ),
                const SizedBox(height: 12),
                Text(
                  provider.serviceErrorMessage ?? 'មានបញ្ហាក្នុងការទាញទិន្នន័យ',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: enterprise.text,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: enterprise.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                  ),
                  onPressed: () => provider.initServiceDetailPage(),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(translate('repair_screen.retry')),
                ),
              ],
            ),
          ),
        );

      case RepairLoadingState.empty:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off_rounded,
                  size: 48,
                  color: enterprise.mutedText.withValues(alpha: 0.6),
                ),
                const SizedBox(height: 12),
                Text(
                  translate('repair_screen.no_services_found'),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: enterprise.text,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  translate('repair_screen.no_services_hint'),
                  style: TextStyle(
                    fontSize: 12,
                    color: enterprise.mutedText,
                  ),
                ),
              ],
            ),
          ),
        );

      case RepairLoadingState.loaded:
        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          itemCount: provider.services.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final service = provider.services[index];
            final isSelected =
                isTablet && provider.selectedService?.id == service.id;

            return RepairServiceCard(
              service: service,
              canViewCost: provider.canViewCost,
              canManagePrices: provider.canUpdatePrices,
              isSelected: isSelected,
              onTap: () {
                provider.selectService(service);
                if (!isTablet) {
                  RepairDetailBottomSheet.show(
                    context,
                    device: device,
                    service: service,
                    canViewCost: provider.canViewCost,
                    canManagePrices: provider.canUpdatePrices,
                    onPriceUpdated: provider.saveServicePrice,
                  );
                }
              },
              onEditPrice: provider.canUpdatePrices
                  ? () {
                      RepairEditPriceSheet.show(
                        context,
                        service: service,
                        onSave: provider.saveServicePrice,
                      );
                    }
                  : null,
            );
          },
        );
    }
  }

  Widget _buildTabletDetailPanel(BuildContext context,
      RepairPriceProvider provider, RepairService service) {
    final enterprise = EnterpriseTheme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (service.nameKh.isNotEmpty) ...[
                      Text(
                        service.nameKh,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: enterprise.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      service.name,
                      style: TextStyle(
                        fontSize: service.nameKh.isNotEmpty ? 15 : 20,
                        fontWeight: service.nameKh.isNotEmpty
                            ? FontWeight.w500
                            : FontWeight.w700,
                        color: service.nameKh.isNotEmpty
                            ? enterprise.mutedText
                            : enterprise.text,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  RepairStatusBadge(status: service.availabilityStatus),
                  if (provider.canUpdatePrices) ...[
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: enterprise.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.edit_note_rounded, size: 16),
                      label: const Text('Edit Price',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700)),
                      onPressed: () {
                        RepairEditPriceSheet.show(
                          context,
                          service: service,
                          onSave: provider.saveServicePrice,
                        );
                      },
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (service.description.isNotEmpty) ...[
            Text(
              service.description,
              style: TextStyle(
                fontSize: 14,
                color: enterprise.mutedText,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
          ],
          if (service.partName.isNotEmpty || service.partType.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: enterprise.glassStroke, width: 0.8),
              ),
              child: Row(
                children: [
                  Icon(Icons.build_rounded, size: 18, color: enterprise.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${service.partName} ${service.partType.isNotEmpty ? '(${service.partType})' : ''}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: enterprise.text,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              Expanded(
                child: _infoBox(context, Icons.verified_outlined,
                    translate('repair_screen.warranty'), service.warrantyLabel),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _infoBox(context, Icons.timer_outlined,
                    translate('repair_screen.repair_time'), service.timeLabel),
              ),
            ],
          ),
          const SizedBox(height: 20),
          RepairPriceCard(
            service: service,
            canViewCost: provider.canViewCost,
          ),
          if (service.note.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: RepairPriceConfig.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: RepairPriceConfig.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline,
                      size: 18, color: RepairPriceConfig.warning),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      service.note,
                      style: TextStyle(fontSize: 13, color: enterprise.text),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoBox(
      BuildContext context, IconData icon, String title, String value) {
    final enterprise = EnterpriseTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: enterprise.glassStroke, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: enterprise.mutedText),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 12, color: enterprise.mutedText),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: enterprise.text,
            ),
          ),
        ],
      ),
    );
  }
}
