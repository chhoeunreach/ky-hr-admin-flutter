import 'dart:async';

import 'package:cnattendance/core/theme/app_colors.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:flutter/material.dart';

import 'branch_mission_editor.dart';
import 'branch_route_model.dart';
import 'branch_route_storage.dart';
import 'daily_records_api.dart';

/// A dedicated floating button pinned above or next to the Quick Create (+) button.
///
/// Features:
/// 1. When an active mission is in-progress:
///    Transforms into an elevated Live Tracking Pill with a pulsing status dot,
///    live elapsed timer, destination branch name, and 1-tap shortcut to open
///    the mission editor to Check-in or Finish.
/// 2. When idle (no active mission):
///    Displays a dedicated shortcut button to launch Branch Mission directly.
class DedicatedMissionFloatingButton extends StatefulWidget {
  const DedicatedMissionFloatingButton({
    super.key,
    this.api,
    this.showWhenIdle = true,
  });

  final DailyRecordsApi? api;
  final bool showWhenIdle;

  @override
  State<DedicatedMissionFloatingButton> createState() =>
      _DedicatedMissionFloatingButtonState();
}

class _DedicatedMissionFloatingButtonState
    extends State<DedicatedMissionFloatingButton>
    with SingleTickerProviderStateMixin {
  Timer? _ticker;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Initial check from storage
    BranchRouteStorage.getActiveRoute();
    _startTimerIfNeeded();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPulse();
  }

  /// The pulse only runs while the live-tracking pill is on screen, so idle
  /// dashboards keep no ticking animation (pumpAndSettle/tests stay clean).
  void _syncPulse() {
    final route = BranchRouteStorage.activeRouteNotifier.value;
    final active = route != null && route.isProcessing;
    final shouldPulse = active && !MediaQuery.disableAnimationsOf(context);
    if (shouldPulse) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else if (_pulseController.isAnimating) {
      _pulseController.stop();
    }
  }

  void _startTimerIfNeeded() {
    _ticker?.cancel();
    final route = BranchRouteStorage.activeRouteNotifier.value;
    if (route != null && route.isProcessing) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _openMissionModal() async {
    final service = widget.api ?? DailyRecordsApi();
    await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.95,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BranchMissionEditor(api: service, asModal: true),
        ),
      ),
    );
    // Refresh storage state upon closing
    await BranchRouteStorage.getActiveRoute();
    if (mounted) {
      _startTimerIfNeeded();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<BranchRoute?>(
      valueListenable: BranchRouteStorage.activeRouteNotifier,
      builder: (context, route, _) {
        _syncPulse();
        if (route == null || !route.isProcessing) {
          if (!widget.showWhenIdle) return const SizedBox.shrink();
          return _buildIdleButton(context);
        }
        return _buildActiveTrackingPill(context, route);
      },
    );
  }

  /// Idle State: Compact Dedicated Button above Quick Create (+)
  Widget _buildIdleButton(BuildContext context) {
    final theme = EnterpriseTheme.of(context);
    return Tooltip(
      message: 'ចេញក្រៅ / បេសកកម្មតាមសាខា (Branch Mission)',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _openMissionModal,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colors.cardColor.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: theme.accent.withValues(alpha: 0.45),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: theme.accent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.alt_route_rounded,
                    size: 15,
                    color: theme.accent,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'ចេញក្រៅ',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: theme.text,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Active State: Live Tracking Pill with Pulsing Indicator & Realtime Timer
  Widget _buildActiveTrackingPill(BuildContext context, BranchRoute route) {
    final theme = EnterpriseTheme.of(context);
    final isRoundTrip = route.isRoundTrip;
    final isDeparted = route.isDeparted;

    final Color statusColor = isRoundTrip
        ? AppColors.customFF059669
        : (isDeparted ? Colors.orange : AppColors.customFF059669);

    final IconData statusIcon = isRoundTrip
        ? Icons.replay_circle_filled_rounded
        : (isDeparted ? Icons.directions_car_rounded : Icons.storefront_rounded);

    final String label = isRoundTrip
        ? 'ការងារក្រៅ (${route.originBranch})'
        : (isDeparted
            ? 'កំពុងធ្វើដំណើរ ➔ ${route.currentBranchName}'
            : 'បានមកដល់៖ ${route.currentBranchName}');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openMissionModal,
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colors.cardColor,
                theme.colors.cardColor.withValues(alpha: 0.95),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: statusColor.withValues(alpha: 0.7),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: statusColor.withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pulsing Indicator Dot
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withValues(alpha: 0.6),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(statusIcon, size: 16, color: statusColor),
              const SizedBox(width: 6),
              // Live Timer
              Text(
                route.liveTimerString,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                  color: theme.text,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 1,
                height: 12,
                color: theme.text.withValues(alpha: 0.2),
              ),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 130),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: theme.mutedText,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: statusColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
