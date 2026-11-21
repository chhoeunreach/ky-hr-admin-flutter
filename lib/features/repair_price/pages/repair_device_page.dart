import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:cnattendance/widget/premium_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:provider/provider.dart';
import '../config/repair_price_config.dart';
import '../models/repair_device.dart';
import '../providers/repair_price_provider.dart';
import '../widgets/repair_brand_filter.dart';
import '../widgets/repair_device_card.dart';
import '../widgets/repair_edit_device_sheet.dart';
import '../widgets/repair_search_bar.dart';
import 'repair_price_detail_page.dart';

class RepairDevicePage extends StatelessWidget {
  const RepairDevicePage({
    super.key,
    this.showBackButton = true,
    this.onNavigationVisibilityChanged,
  });
  final bool showBackButton;
  final ValueChanged<bool>? onNavigationVisibilityChanged;

  static Route route() {
    return MaterialPageRoute(
      builder: (_) => const RepairDevicePage(),
    );
  }

  @override
  Widget build(BuildContext context) {
    try {
      Provider.of<RepairPriceProvider>(context, listen: false);
      return _RepairDeviceView(
        showBackButton: showBackButton,
        onNavigationVisibilityChanged: onNavigationVisibilityChanged,
      );
    } catch (_) {
      return ChangeNotifierProvider(
        create: (_) => RepairPriceProvider()..initDevicePage(),
        child: _RepairDeviceView(
          showBackButton: showBackButton,
          onNavigationVisibilityChanged: onNavigationVisibilityChanged,
        ),
      );
    }
  }
}

class _RepairDeviceView extends StatefulWidget {
  const _RepairDeviceView({
    required this.showBackButton,
    required this.onNavigationVisibilityChanged,
  });
  final bool showBackButton;
  final ValueChanged<bool>? onNavigationVisibilityChanged;

  @override
  State<_RepairDeviceView> createState() => _RepairDeviceViewState();
}

class _RepairDeviceViewState extends State<_RepairDeviceView> {
  final ScrollController _scrollController = ScrollController();
  bool _navigationVisible = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<RepairPriceProvider>().initDevicePage();
      }
    });
  }

  void _onScroll() {
    if (_scrollController.position.userScrollDirection !=
        ScrollDirection.idle) {
      final visible = _scrollController.position.userScrollDirection ==
          ScrollDirection.forward;
      if (visible != _navigationVisible) {
        _navigationVisible = visible;
        widget.onNavigationVisibilityChanged?.call(visible);
      }
    }
    if (_scrollController.position.pixels <= 0 && !_navigationVisible) {
      _navigationVisible = true;
      widget.onNavigationVisibilityChanged?.call(true);
    }
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<RepairPriceProvider>().loadMoreDevices();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

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
          automaticallyImplyLeading: false,
          leading: widget.showBackButton
              ? IconButton(
                  icon: Icon(Icons.arrow_back_ios_new_rounded,
                      size: 18, color: enterprise.text),
                  onPressed: () => Navigator.maybePop(context),
                )
              : null,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                translate('repair_screen.select_device'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: enterprise.text,
                ),
              ),
              Text(
                translate('repair_screen.title'),
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
        floatingActionButton: provider.canManageDevices
            ? FloatingActionButton.extended(
                backgroundColor: enterprise.primary,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.add_rounded, size: 20),
                label: Text(
                  translate('repair_screen.add_device'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                onPressed: () {
                  RepairEditDeviceSheet.show(
                    context,
                    brands: provider.brands,
                    deviceTypes: provider.deviceTypes,
                    existingDevices: provider.devices,
                    onSave: (device) => provider.addDevice(device),
                  );
                },
              )
            : null,
        body: !provider.canView
            ? provider.deviceLoadingState == RepairLoadingState.forbidden
                ? _buildAccessDenied(context, provider)
                : _buildDeviceBody(context, provider)
            : Column(
                children: [
                  // Search Box & Filters Header
                  Container(
                    color: Colors.white
                        .withValues(alpha: enterprise.isDark ? 0.06 : 0.12),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Search Bar
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: RepairSearchBar(
                            hintText:
                                translate('repair_screen.search_device_hint'),
                            onChanged: provider.onDeviceSearchChanged,
                            onClear: () => provider.onDeviceSearchChanged(''),
                          ),
                        ),

                        if (provider.brands.isNotEmpty ||
                            provider.deviceTypes.isNotEmpty)
                          const SizedBox(height: 7),

                        // Brand Filter Pills
                        if (provider.brands.isNotEmpty)
                          RepairBrandFilter(
                            brands: provider.brands,
                            selectedBrandId: provider.selectedBrandId,
                            onBrandSelected: provider.selectBrand,
                            onAddBrand: null,
                            onEditBrand: null,
                          ),

                        // Device Type Filter Pills
                        if (provider.deviceTypes.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          _buildDeviceTypeFilter(context, provider),
                        ],
                      ],
                    ),
                  ),

                  // Main Content: List, Loading, Empty, or Error
                  Expanded(
                    child: RefreshIndicator(
                      color: Colors.white,
                      backgroundColor: enterprise.primary,
                      onRefresh: () => provider.initDevicePage(),
                      child: _buildDeviceBody(context, provider),
                    ),
                  ),
                ],
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
            Text(
              translate('repair_screen.access_denied'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: RepairPriceConfig.mainText,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              translate('repair_screen.access_denied_desc'),
              textAlign: TextAlign.center,
              style: const TextStyle(
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
              label: Text(translate('repair_screen.retry')),
              onPressed: () => provider.initDevicePage(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceTypeFilter(
      BuildContext context, RepairPriceProvider provider) {
    final enterprise = EnterpriseTheme.of(context);
    return SizedBox(
      height: 28,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: provider.deviceTypes.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final isAll = index == 0;
          final isSelected = isAll
              ? provider.selectedDeviceTypeId == null
              : provider.selectedDeviceTypeId ==
                  provider.deviceTypes[index - 1].id;
          final title = isAll
              ? translate('repair_screen.all_types')
              : provider.deviceTypes[index - 1].name;

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (isAll) {
                  provider.selectDeviceType(null);
                } else {
                  provider.selectDeviceType(provider.deviceTypes[index - 1].id);
                }
              },
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                decoration: BoxDecoration(
                  color: isSelected
                      ? enterprise.primary
                      : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color:
                        isSelected ? enterprise.accent : enterprise.glassStroke,
                    width: 0.9,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.white : enterprise.mutedText,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDeviceBody(BuildContext context, RepairPriceProvider provider) {
    final enterprise = EnterpriseTheme.of(context);
    switch (provider.deviceLoadingState) {
      case RepairLoadingState.loading:
      case RepairLoadingState.initial:
        return const Center(
          child: CircularProgressIndicator(
            color: Colors.white,
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
                  provider.deviceLoadingState == RepairLoadingState.unauthorized
                      ? Icons.lock_outline_rounded
                      : Icons.wifi_off_rounded,
                  size: 48,
                  color: Colors.redAccent,
                ),
                const SizedBox(height: 12),
                Text(
                  provider.deviceErrorMessage ?? 'មានបញ្ហាក្នុងការទាញទិន្នន័យ',
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
                  onPressed: () => provider.initDevicePage(),
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
                  translate('repair_screen.no_devices_found'),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: enterprise.text,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  translate('repair_screen.no_devices_hint'),
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
        return LayoutBuilder(
          builder: (context, constraints) {
            final isTablet = constraints.maxWidth >= 600;

            if (isTablet) {
              return GridView.builder(
                controller: _scrollController,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics()),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: constraints.maxWidth > 900 ? 3 : 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  mainAxisExtent: 78,
                ),
                itemCount: provider.devices.length +
                    (provider.isLoadingMoreDevices ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= provider.devices.length) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: enterprise.accent,
                        strokeWidth: 2,
                      ),
                    );
                  }
                  final device = provider.devices[index];
                  return RepairDeviceCard(
                    device: device,
                    onTap: () => _navigateToDetail(context, device),
                    onEdit: provider.canManageDevices
                        ? () => RepairEditDeviceSheet.show(
                              context,
                              brands: provider.brands,
                              deviceTypes: provider.deviceTypes,
                              existingDevices: provider.devices,
                              device: device,
                              onSave: (d) => provider.updateDevice(d),
                              onDelete: (id) => provider.deleteDevice(id),
                            )
                        : null,
                    onDelete: provider.canManageDevices
                        ? () => _confirmDeleteDevice(context, provider, device)
                        : null,
                  );
                },
              );
            }

            return ListView.separated(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics()),
              itemCount: provider.devices.length +
                  (provider.isLoadingMoreDevices ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                if (index >= provider.devices.length) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: enterprise.accent,
                        strokeWidth: 2,
                      ),
                    ),
                  );
                }
                final device = provider.devices[index];
                return RepairDeviceCard(
                  device: device,
                  onTap: () => _navigateToDetail(context, device),
                  onEdit: provider.canManageDevices
                      ? () => RepairEditDeviceSheet.show(
                            context,
                            brands: provider.brands,
                            deviceTypes: provider.deviceTypes,
                            existingDevices: provider.devices,
                            device: device,
                            onSave: (d) => provider.updateDevice(d),
                            onDelete: (id) => provider.deleteDevice(id),
                          )
                      : null,
                  onDelete: provider.canManageDevices
                      ? () => _confirmDeleteDevice(context, provider, device)
                      : null,
                );
              },
            );
          },
        );
    }
  }

  void _confirmDeleteDevice(
      BuildContext context, RepairPriceProvider provider, RepairDevice device) {
    final enterprise = EnterpriseTheme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: enterprise.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Colors.redAccent, size: 24),
            const SizedBox(width: 8),
            Text(
              translate('repair_screen.delete_device'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: enterprise.text,
              ),
            ),
          ],
        ),
        content: Text(
          '${translate('repair_screen.delete_device_confirm')}\n"${device.name}"',
          style: TextStyle(fontSize: 13, color: enterprise.mutedText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              translate('repair_screen.cancel'),
              style: TextStyle(color: enterprise.mutedText),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final deleted = await provider.deleteDevice(device.id);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(translate(deleted
                      ? 'repair_screen.device_deleted'
                      : 'repair_screen.device_delete_failed')),
                  backgroundColor: deleted ? Colors.green : Colors.redAccent,
                ),
              );
            },
            child: Text(translate('repair_screen.delete')),
          ),
        ],
      ),
    );
  }

  void _navigateToDetail(BuildContext context, RepairDevice device) {
    final provider = context.read<RepairPriceProvider>();
    provider.setSelectedDevice(device);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RepairPriceDetailPage(
          device: device,
          provider: provider,
        ),
      ),
    );
  }
}
