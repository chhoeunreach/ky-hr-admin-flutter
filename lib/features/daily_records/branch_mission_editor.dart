import 'dart:async';
import 'dart:io';

import 'package:cnattendance/core/theme/app_colors.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:cnattendance/utils/locationstatus.dart';
import 'package:cnattendance/widget/attendance_selfie_camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import 'branch_route_model.dart';
import 'branch_route_storage.dart';
import 'daily_records_api.dart';

class BranchMissionEditor extends StatefulWidget {
  const BranchMissionEditor({
    super.key,
    required this.api,
    this.entry,
  });

  final DailyRecordsApi api;
  final RecordData? entry;

  @override
  State<BranchMissionEditor> createState() => _BranchMissionEditorState();
}

class _BranchMissionEditorState extends State<BranchMissionEditor> {
  static const _defaultBranches = [
    'សាខាទី១ - ទួលគោក (Toul Kork)',
    'សាខាទី២ - សែនសុខ (Sen Sok)',
    'សាខាទី៣ - ច្បារអំពៅ (Chbar Ampov)',
    'សាខាទី៤ - បឹងកេងកង (BKK)',
    'សាខាទី៥ - ចំការមន (Chamkarmon)',
  ];

  BranchRoute? _activeRoute;
  bool _loading = true;
  Timer? _tickerTimer;

  // Form controllers for Stage 1 (Start/Add)
  final _formKey = GlobalKey<FormState>();
  final _purposeController = TextEditingController();
  String _selectedOrigin = _defaultBranches[0];
  final Set<String> _selectedTargets = {_defaultBranches[1]};
  String? _startSelfiePath;
  double? _startLat;
  double? _startLng;
  bool _fetchingGps = false;
  String? _gpsMessage;

  // Processing state
  bool _actionLoading = false;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    final active = await BranchRouteStorage.getActiveRoute();
    if (active != null && active.isProcessing) {
      if (mounted) {
        setState(() {
          _activeRoute = active;
          _loading = false;
        });
        _startTimer();
      }
      return;
    }

    if (mounted) {
      setState(() => _loading = false);
      _captureGps();
    }
  }

  void _startTimer() {
    _tickerTimer?.cancel();
    _tickerTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    _purposeController.dispose();
    super.dispose();
  }

  Future<void> _captureGps() async {
    setState(() {
      _fetchingGps = true;
      _gpsMessage = null;
    });
    try {
      final pos = await LocationStatus().determinePosition('0', forceHighAccuracy: true);
      if (!mounted) return;
      setState(() {
        _startLat = pos.latitude;
        _startLng = pos.longitude;
        _fetchingGps = false;
        _gpsMessage = 'GPS បានផ្ទៀងផ្ទាត់ (±${pos.accuracy.toStringAsFixed(1)}m)';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _fetchingGps = false;
        _gpsMessage = 'មិនអាចចាប់ GPS បានទេ: $e';
      });
    }
  }

  Future<void> _takeStartSelfie() async {
    final file = await Navigator.of(context).push<File>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const AttendanceSelfieCamera(),
      ),
    );
    if (file != null && mounted) {
      setState(() => _startSelfiePath = file.path);
    }
  }

  Future<void> _startMission() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startSelfiePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('សូមថតរូប Selfie បញ្ជាក់វត្តមានចេញដំណើរជាមុនសិន!'),
          backgroundColor: AppColors.customFFE11D48,
        ),
      );
      return;
    }

    setState(() => _actionLoading = true);

    final route = BranchRoute(
      id: const Uuid().v4(),
      purpose: _purposeController.text.trim(),
      originBranch: _selectedOrigin,
      targetBranches: _selectedTargets.toList(),
      status: 'processing',
      startTime: DateTime.now(),
      startLatitude: _startLat,
      startLongitude: _startLng,
      startSelfiePath: _startSelfiePath,
    );

    await BranchRouteStorage.saveActiveRoute(route);

    if (mounted) {
      setState(() {
        _activeRoute = route;
        _actionLoading = false;
      });
      _startTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('បេសកកម្មត្រូវបានចាប់ផ្តើមដោយជោគជ័យ!'),
          backgroundColor: AppColors.customFF059669,
        ),
      );
    }
  }

  Future<void> _openCheckpointSheet() async {
    if (_activeRoute == null) return;

    String currentBranch = _defaultBranches.firstWhere(
      (b) => !_activeRoute!.checkpoints.any((c) => c.branchName == b) && b != _activeRoute!.originBranch,
      orElse: () => _defaultBranches[1],
    );
    final notesCtrl = TextEditingController();
    final List<String> photos = [];
    double? cpLat;
    double? cpLng;
    bool gettingGps = true;
    String? gpsInfo;

    // Trigger GPS immediately
    LocationStatus().determinePosition('0', forceHighAccuracy: true).then((pos) {
      cpLat = pos.latitude;
      cpLng = pos.longitude;
      gettingGps = false;
      gpsInfo = 'GPS: (${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)})';
    }).catchError((err) {
      gettingGps = false;
      gpsInfo = 'GPS: $err';
    });

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final theme = EnterpriseTheme.of(context);
            return Container(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              decoration: BoxDecoration(
                color: theme.colors.cardColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.text.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Icon(Icons.add_location_alt_rounded, color: theme.accent, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'Check-in សាខាបន្ទាប់',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: theme.text,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: currentBranch,
                      decoration: const InputDecoration(
                        labelText: 'សាខាដែលបានមកដល់ (Current Branch)',
                        prefixIcon: Icon(Icons.storefront_rounded),
                      ),
                      items: [
                        for (final b in _defaultBranches)
                          DropdownMenuItem(value: b, child: Text(b, overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (val) {
                        if (val != null) setSheetState(() => currentBranch = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded, size: 16, color: theme.accent),
                        const SizedBox(width: 6),
                        Text(
                          'ម៉ោងមកដល់៖ ${DateFormat('hh:mm a').format(DateTime.now())}',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.text),
                        ),
                        const Spacer(),
                        if (gettingGps)
                          const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        else
                          Text(
                            gpsInfo ?? 'GPS បានចាប់',
                            style: TextStyle(fontSize: 11, color: theme.mutedText),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'រូបភាពភស្តុតាងការងារ (Work Photos/Evidence)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: theme.text),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (var i = 0; i < photos.length; i++)
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.file(
                                  File(photos[i]),
                                  width: 64,
                                  height: 64,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: -4,
                                right: -4,
                                child: IconButton(
                                  icon: const Icon(Icons.cancel, color: AppColors.customFFE11D48, size: 18),
                                  onPressed: () => setSheetState(() => photos.removeAt(i)),
                                ),
                              ),
                            ],
                          ),
                        InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () async {
                            final picker = ImagePicker();
                            final img = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
                            if (img != null) {
                              setSheetState(() => photos.add(img.path));
                            }
                          },
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: theme.accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: theme.accent.withValues(alpha: 0.4)),
                            ),
                            child: Icon(Icons.add_a_photo_outlined, color: theme.accent, size: 24),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: notesCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'កំណត់ត្រាសកម្មភាពការងារ (Activity notes)',
                        hintText: 'ឧ. ថតរូបផលិតផលបាន ១៥ ម៉ូដ និងវីដេអូ TikTok...',
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('រក្សាទុក Check-in សាខានេះ'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.accent,
                          foregroundColor: theme.colors.isDark ? AppColors.black : AppColors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () {
                          final cp = RouteCheckpoint(
                            id: const Uuid().v4(),
                            branchName: currentBranch,
                            arrivedAt: DateTime.now(),
                            latitude: cpLat,
                            longitude: cpLng,
                            notes: notesCtrl.text.trim(),
                            photoPaths: photos,
                          );

                          final updatedCheckpoints = [..._activeRoute!.checkpoints, cp];
                          final updatedRoute = _activeRoute!.copyWith(checkpoints: updatedCheckpoints);

                          BranchRouteStorage.saveActiveRoute(updatedRoute);
                          setState(() => _activeRoute = updatedRoute);
                          Navigator.pop(sheetContext);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openCompleteSheet() async {
    if (_activeRoute == null) return;

    String finalBranch = _activeRoute!.targetBranches.isNotEmpty
        ? _activeRoute!.targetBranches.last
        : _activeRoute!.originBranch;
    String? endSelfie;
    final summaryCtrl = TextEditingController();
    double? endLat;
    double? endLng;

    LocationStatus().determinePosition('0', forceHighAccuracy: true).then((pos) {
      endLat = pos.latitude;
      endLng = pos.longitude;
    }).catchError((_) {});

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final theme = EnterpriseTheme.of(context);
            return Container(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              decoration: BoxDecoration(
                color: theme.colors.cardColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.text.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Icon(Icons.flag_rounded, color: AppColors.customFF059669, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          'បញ្ចប់បេសកកម្ម (Complete Route)',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: theme.text,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.accent.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.timer_outlined, color: theme.accent, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'រយៈពេលសរុប៖ ${_activeRoute!.formattedDuration} (${_activeRoute!.liveTimerString})',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: theme.text,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: finalBranch,
                      decoration: const InputDecoration(
                        labelText: 'សាខាបញ្ចប់ (Final Branch)',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                      items: [
                        for (final b in _defaultBranches)
                          DropdownMenuItem(value: b, child: Text(b, overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (val) {
                        if (val != null) setSheetState(() => finalBranch = val);
                      },
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'ថតរូប Selfie បញ្ចប់បេសកកម្ម (Mandatory Final Selfie)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: theme.text),
                    ),
                    const SizedBox(height: 8),
                    if (endSelfie != null)
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(File(endSelfie!), width: 72, height: 72, fit: BoxFit.cover),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.replay_rounded, size: 16),
                            label: const Text('ថតម្តងទៀត'),
                            style: ElevatedButton.styleFrom(visualDensity: VisualDensity.compact),
                            onPressed: () async {
                              final f = await Navigator.of(context).push<File>(
                                MaterialPageRoute(
                                  fullscreenDialog: true,
                                  builder: (_) => const AttendanceSelfieCamera(),
                                ),
                              );
                              if (f != null) setSheetState(() => endSelfie = f.path);
                            },
                          ),
                        ],
                      )
                    else
                      OutlinedButton.icon(
                        icon: const Icon(Icons.camera_front_rounded),
                        label: const Text('ថតរូប Selfie បញ្ចប់ (Front Camera)'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                        ),
                        onPressed: () async {
                          final f = await Navigator.of(context).push<File>(
                            MaterialPageRoute(
                              fullscreenDialog: true,
                              builder: (_) => const AttendanceSelfieCamera(),
                            ),
                          );
                          if (f != null) setSheetState(() => endSelfie = f.path);
                        },
                      ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: summaryCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'សេចក្តីសង្ខេបចុងក្រោយ (Final summary)',
                        hintText: 'ឧ. បានបញ្ចប់ការងារថតរូបគ្រប់សាខាដោយរលូន...',
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.flag_rounded),
                        label: const Text('បញ្ជាក់ការបញ្ចប់បេសកកម្ម'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.customFF059669,
                          foregroundColor: AppColors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () async {
                          if (endSelfie == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('សូមថត Selfie បញ្ចប់បេសកកម្មជាមុនសិន!'),
                                backgroundColor: AppColors.customFFE11D48,
                              ),
                            );
                            return;
                          }

                          final completedRoute = _activeRoute!.copyWith(
                            status: 'completed',
                            endTime: DateTime.now(),
                            endLatitude: endLat,
                            endLongitude: endLng,
                            endSelfiePath: endSelfie,
                            finalSummary: summaryCtrl.text.trim(),
                            totalMinutes: _activeRoute!.currentDuration.inMinutes,
                          );

                          await BranchRouteStorage.saveToHistory(completedRoute);
                          await BranchRouteStorage.clearActiveRoute();

                          // Background sync to server
                          BranchRouteStorage.syncRouteToServer(completedRoute, widget.api);

                          if (mounted) {
                            Navigator.pop(sheetContext);
                            Navigator.pop(context, true);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('បេសកកម្មត្រូវបានបញ្ចប់ និងរក្សាទុកដោយជោគជ័យ!'),
                                backgroundColor: AppColors.customFF059669,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _cancelMission() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('លុបចោលបេសកកម្ម?'),
        content: const Text('តើអ្នកពិតជាចង់លុបចោលបេសកកម្មដែលកំពុងដំណើរការនេះមែនទេ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ទេ')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.customFFE11D48),
            child: const Text('លុបចោល'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await BranchRouteStorage.clearActiveRoute();
      setState(() => _activeRoute = null);
      _tickerTimer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = EnterpriseTheme.of(context);

    if (_loading) {
      return Scaffold(
        backgroundColor: theme.colors.backgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: theme.colors.backgroundColor,
      appBar: AppBar(
        title: Text(
          _activeRoute?.isProcessing == true
              ? 'បេសកកម្មកំពុងដំណើរការ'
              : 'ចាប់ផ្តើមបេសកកម្មតាមសាខា',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: theme.text,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_activeRoute?.isProcessing == true)
            IconButton(
              tooltip: 'លុបចោលបេសកកម្ម',
              icon: const Icon(Icons.cancel_outlined, color: AppColors.customFFE11D48),
              onPressed: _cancelMission,
            ),
        ],
      ),
      body: SafeArea(
        child: _activeRoute?.isProcessing == true
            ? _buildProcessingView(theme)
            : _buildStartView(theme),
      ),
    );
  }

  // ================= STAGE 1: START / ADD VIEW =================
  Widget _buildStartView(EnterpriseTheme theme) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Purpose field
          Text(
            'គោលបំណងបេសកកម្ម (Mission Purpose)',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: theme.text),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _purposeController,
            decoration: const InputDecoration(
              hintText: 'ឧ. ចុះថតរូបផលិតផលថ្មី និងវីដេអូ TikTok ផ្សព្វផ្សាយ...',
              prefixIcon: Icon(Icons.edit_note_rounded),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'សូមបញ្ចូលគោលបំណងបេសកកម្ម!';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Origin Branch
          Text(
            'សាខាចេញដំណើរ (Origin Branch)',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: theme.text),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _selectedOrigin,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.storefront_rounded),
            ),
            items: [
              for (final b in _defaultBranches)
                DropdownMenuItem(value: b, child: Text(b, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _selectedOrigin = val);
            },
          ),
          const SizedBox(height: 16),

          // Target branches
          Text(
            'សាខាគោលដៅគ្រោងទុក (Target Branches)',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: theme.text),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final branch in _defaultBranches)
                if (branch != _selectedOrigin)
                  FilterChip(
                    label: Text(branch.split(' - ').first),
                    selected: _selectedTargets.contains(branch),
                    selectedColor: theme.accent.withValues(alpha: 0.25),
                    checkmarkColor: theme.accent,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedTargets.add(branch);
                        } else {
                          _selectedTargets.remove(branch);
                        }
                      });
                    },
                  ),
            ],
          ),
          const SizedBox(height: 18),

          // Mandatory Selfie
          Text(
            'ថតរូប Selfie ចេញដំណើរ (Mandatory Selfie)',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: theme.text),
          ),
          const SizedBox(height: 8),
          if (_startSelfiePath != null)
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.file(
                    File(_startSelfiePath!),
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: AppColors.customFF059669, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'Selfie រួចរាល់',
                          style: TextStyle(fontWeight: FontWeight.bold, color: theme.text, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.replay_rounded, size: 16),
                      label: const Text('ថតម្តងទៀត'),
                      style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                      onPressed: _takeStartSelfie,
                    ),
                  ],
                ),
              ],
            )
          else
            OutlinedButton.icon(
              icon: const Icon(Icons.camera_front_rounded),
              label: const Text('ថតរូប Selfie ផ្ទាល់ (Front Camera)'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                side: BorderSide(color: theme.accent),
              ),
              onPressed: _takeStartSelfie,
            ),
          const SizedBox(height: 18),

          // Real GPS Location & Time preview
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colors.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.accent.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.location_on_rounded, color: theme.accent, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _fetchingGps
                            ? 'កំពុងចាប់ទីតាំង GPS...'
                            : (_gpsMessage ?? 'មិនទាន់មានទិន្នន័យ GPS'),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.text),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      onPressed: _fetchingGps ? null : _captureGps,
                    ),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  children: [
                    Icon(Icons.access_time_rounded, color: theme.accent, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'ម៉ោងចេញដំណើរ៖ ${DateFormat('hh:mm a').format(DateTime.now())}',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.text),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: theme.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Status: Processing',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.accent),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Start Mission Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: _actionLoading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.play_arrow_rounded),
              label: const Text(
                'ចាប់ផ្តើមបេសកកម្ម (Start Mission)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.accent,
                foregroundColor: theme.colors.isDark ? AppColors.black : AppColors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _actionLoading ? null : _startMission,
            ),
          ),
        ],
      ),
    );
  }

  // ================= STAGE 2: IN-PROGRESS / PROCESSING VIEW =================
  Widget _buildProcessingView(EnterpriseTheme theme) {
    final route = _activeRoute!;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // Live Active Header Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colors.cardColor,
                theme.colors.cardColor.withValues(alpha: 0.85),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.accent.withValues(alpha: 0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: theme.accent.withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.customFF059669,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'បេសកកម្មកំពុងដំណើរការ (Processing)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: theme.accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                route.liveTimerString,
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                  color: theme.text,
                ),
              ),
              Text(
                'រយៈពេលចំណាយរហូតមកដល់បច្ចុប្បន្ន',
                style: TextStyle(fontSize: 11, color: theme.mutedText),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Route overview card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colors.cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (route.startSelfiePath != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        File(route.startSelfiePath!),
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                      ),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          route.purpose,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: theme.text,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ចេញពី៖ ${route.originBranch}',
                          style: TextStyle(fontSize: 12, color: theme.mutedText),
                        ),
                        Text(
                          'ម៉ោងចេញ៖ ${DateFormat('hh:mm a').format(route.startTime)}',
                          style: TextStyle(fontSize: 12, color: theme.accent, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Timeline Checkpoints Title
        Row(
          children: [
            Icon(Icons.alt_route_rounded, color: theme.accent, size: 20),
            const SizedBox(width: 8),
            Text(
              'សកម្មភាពតាមសាខា (${route.checkpoints.length} Checkpoints)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: theme.text,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (route.checkpoints.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colors.cardColor.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                'មិនទាន់មានការ Check-in សាខានៅឡើយទេ។\nចុចប៊ូតុងខាងក្រោមពេលមកដល់សាខាបន្ទាប់!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: theme.mutedText, height: 1.4),
              ),
            ),
          )
        else
          for (var i = 0; i < route.checkpoints.length; i++) ...[
            _buildCheckpointCard(route.checkpoints[i], i + 1, theme),
            const SizedBox(height: 8),
          ],
        const SizedBox(height: 20),

        // Action Buttons: Add Checkpoint & Finish Route
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add_location_alt_rounded),
                label: const Text('Check-in សាខា'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: theme.accent),
                ),
                onPressed: _openCheckpointSheet,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.flag_rounded),
                label: const Text('បញ្ចប់បេសកកម្ម'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.customFF059669,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _openCompleteSheet,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCheckpointCard(RouteCheckpoint cp, int index, EnterpriseTheme theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colors.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: theme.accent,
                child: Text(
                  '$index',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: theme.colors.isDark ? AppColors.black : AppColors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  cp.branchName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: theme.text,
                  ),
                ),
              ),
              Text(
                DateFormat('hh:mm a').format(cp.arrivedAt),
                style: TextStyle(fontSize: 11, color: theme.mutedText, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          if (cp.notes.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              cp.notes,
              style: TextStyle(fontSize: 12, color: theme.text.withValues(alpha: 0.9)),
            ),
          ],
          if (cp.photoPaths.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 52,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: cp.photoPaths.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, pIndex) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(cp.photoPaths[pIndex]),
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
