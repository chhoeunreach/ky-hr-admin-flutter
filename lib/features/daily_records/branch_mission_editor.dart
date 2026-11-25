import 'dart:async';
import 'dart:io';

import 'package:cnattendance/core/theme/app_colors.dart';
import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/provider/dashboardprovider.dart';
import 'package:cnattendance/provider/teamsheetprovider.dart';
import 'package:cnattendance/repositories/teamsheetrepository.dart';
import 'package:cnattendance/services/device_clock_monitor.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:cnattendance/utils/locationstatus.dart';
import 'package:cnattendance/widget/attendance_selfie_camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'branch_route_model.dart';
import 'branch_route_report.dart';
import 'branch_route_storage.dart';
import 'daily_records_api.dart';
import 'work_labels.dart';

class BranchMissionEditor extends StatefulWidget {
  const BranchMissionEditor({
    super.key,
    required this.api,
    this.entry,
    this.autoLaunchSelfie = false,
    this.asModal = false,
    this.initialMode,
  });

  final DailyRecordsApi api;
  final RecordData? entry;
  final bool autoLaunchSelfie;
  final bool asModal;
  final String? initialMode;

  @override
  State<BranchMissionEditor> createState() => _BranchMissionEditorState();
}

class _BranchMissionEditorState extends State<BranchMissionEditor> {
  static const String otherBranchOption = 'ផ្សេងទៀត (បញ្ចូលថ្មី / Other)';

  final List<String> _branchOptions = [];
  String? _detectedSystemBranch;

  BranchRoute? _activeRoute;
  bool _loading = true;
  Timer? _tickerTimer;

  // Form controllers for Stage 1 (Start/Add)
  final _formKey = GlobalKey<FormState>();
  final _purposeController = TextEditingController();
  DateTime _departureTime = DateTime.now();
  String _selectedOrigin = '';
  final Set<String> _selectedTargets = {};
  String? _startSelfiePath;
  double? _startLat;
  double? _startLng;
  bool _fetchingGps = false;
  String? _gpsMessage;
  late String _selectedMode = widget.initialMode ?? 'round_trip'; // 'round_trip' | 'multi_branch'

  // Supporting items for Mission Purpose
  final List<String> _supportingPhotos = [];
  final List<String> _supportingFiles = [];
  final List<String> _supportingLinks = [];
  bool _showEmojiTray = false;

  static const _quickEmojis = [
    '📍', '📸', '🏬', '🚗', '📋', '📦', '🎯', '📝',
    '🤝', '💼', '📊', '✅', '🔍', '💬', '🕒', '🚀',
    '🏢', '🛣️', '🛵', '✨', '⚠️', '👍',
  ];

  // Processing state
  bool _actionLoading = false;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    // 1. Auto-detect user's primary branch from Preferences / DashboardProvider
    String systemBranch = '';
    try {
      systemBranch = await Preferences().getBranchName();
    } catch (_) {}

    if (systemBranch.trim().isEmpty && mounted) {
      try {
        final dash = context.read<DashboardProvider?>();
        if (dash != null && dash.branch.trim().isNotEmpty) {
          systemBranch = dash.branch.trim();
        }
      } catch (_) {}
    }

    if (systemBranch.trim().isNotEmpty) {
      final trimmed = systemBranch.trim();
      _detectedSystemBranch = trimmed;
      _selectedOrigin = trimmed;
      if (!_branchOptions.contains(trimmed)) {
        _branchOptions.add(trimmed);
      }
    }

    // 2. Try to load system branches from TeamSheetProvider
    try {
      final teamSheet = context.read<TeamSheetProvider?>();
      if (teamSheet != null && teamSheet.branches.isNotEmpty) {
        final liveBranches = teamSheet.branches
            .map((b) => b.name.trim())
            .where((n) => n.isNotEmpty && n.toLowerCase() != 'all')
            .toList();
        for (final b in liveBranches) {
          if (!_branchOptions.contains(b)) _branchOptions.add(b);
        }
      }
    } catch (_) {}

    // 3. Try to load cached system branches from SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getStringList('system_branch_names');
      if (cached != null && cached.isNotEmpty) {
        for (final b in cached) {
          final tb = b.trim();
          if (tb.isNotEmpty && !_branchOptions.contains(tb)) _branchOptions.add(tb);
        }
      }
    } catch (_) {}

    // 4. Background fetch from TeamSheetRepository
    try {
      TeamSheetRepository().getTeam().then((res) async {
        final apiBranches = res.data.branch
            .map((b) => b.name.trim())
            .where((n) => n.isNotEmpty && n.toLowerCase() != 'all')
            .toList();
        if (apiBranches.isNotEmpty && mounted) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setStringList('system_branch_names', apiBranches);
          setState(() {
            for (final b in apiBranches) {
              if (!_branchOptions.contains(b)) _branchOptions.add(b);
            }
          });
        }
      }).catchError((_) {});
    } catch (_) {}

    // Ensure _selectedOrigin is populated
    if (_selectedOrigin.isEmpty) {
      _selectedOrigin = _branchOptions.isNotEmpty ? _branchOptions.first : 'សាខាចម្បង';
    }
    if (!_branchOptions.contains(_selectedOrigin)) {
      _branchOptions.insert(0, _selectedOrigin);
    }

    _selectedTargets.remove(_selectedOrigin);
    if (_selectedTargets.isEmpty) {
      final next = _branchOptions.firstWhere(
        (b) => b != _selectedOrigin,
        orElse: () => '',
      );
      if (next.isNotEmpty) {
        _selectedTargets.add(next);
      }
    }

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
      unawaited(DeviceClockMonitor.instance.refresh());
      _departureTime = _currentServerTime;
      setState(() => _loading = false);
      _startTimer();
      _captureGps();

      if (widget.autoLaunchSelfie && _startSelfiePath == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _activeRoute == null && _startSelfiePath == null) {
            _takeStartSelfie();
          }
        });
      }
    }
  }

  DateTime get _currentServerTime {
    final offset = DeviceClockMonitor.instance.latest?.offset;
    if (offset != null) {
      return DateTime.now().add(offset);
    }
    return DateTime.now();
  }

  void _startTimer() {
    _tickerTimer?.cancel();
    _tickerTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_activeRoute == null) {
        setState(() => _departureTime = _currentServerTime);
      } else {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    _purposeController.dispose();
    super.dispose();
  }

  Future<void> _captureGps() async {
    _fetchingGps = true;
    try {
      final pos = await LocationStatus().determinePosition('0', forceHighAccuracy: true);
      if (!mounted) return;
      _startLat = pos.latitude;
      _startLng = pos.longitude;
      _fetchingGps = false;
    } catch (_) {
      if (!mounted) return;
      _fetchingGps = false;
    }
  }

  Future<void> _pickSupportingImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final theme = EnterpriseTheme.of(sheetContext);
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            color: theme.colors.cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ជ្រើសរើសប្រភពរូបភាព (Choose Image Source)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: theme.text),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(Icons.camera_alt_outlined, color: theme.accent),
                title: Text('ថតរូបផ្ទាល់ (Camera)', style: TextStyle(color: theme.text)),
                onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
              ),
              ListTile(
                leading: Icon(Icons.photo_library_outlined, color: theme.accent),
                title: Text('ជ្រើសពីវិចិត្រសាល (Gallery)', style: TextStyle(color: theme.text)),
                onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );

    if (source == null) return;

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 80,
      );
      if (picked != null) {
        final compressed = await _compressImage(picked.path);
        if (mounted) {
          setState(() {
            _supportingPhotos.add(compressed);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('មិនអាចជ្រើសរូបភាពបានទេ: $e')),
        );
      }
    }
  }

  Future<String> _compressImage(String originalPath) async {
    try {
      final targetPath = p.join(
        p.dirname(originalPath),
        'branch_route_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      final compressed = await FlutterImageCompress.compressAndGetFile(
        originalPath,
        targetPath,
        minWidth: 1080,
        minHeight: 1080,
        quality: 80,
        format: CompressFormat.jpeg,
        autoCorrectionAngle: true,
        keepExif: false,
      );
      if (compressed != null) {
        return compressed.path;
      }
    } catch (_) {}
    return originalPath;
  }

  Future<void> _pickSupportingFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt', 'csv'],
      );
      if (result != null && result.paths.isNotEmpty) {
        if (mounted) {
          setState(() {
            for (final path in result.paths) {
              if (path != null && !_supportingFiles.contains(path)) {
                _supportingFiles.add(path);
              }
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('មិនអាចភ្ជាប់ឯកសារបានទេ: $e')),
        );
      }
    }
  }

  void _insertEmoji(String emoji) {
    final text = _purposeController.text;
    final selection = _purposeController.selection;
    if (selection.start >= 0 && selection.end >= 0) {
      final newText = text.replaceRange(selection.start, selection.end, emoji);
      _purposeController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start + emoji.length),
      );
    } else {
      _purposeController.text = '$text$emoji';
      _purposeController.selection = TextSelection.collapsed(offset: _purposeController.text.length);
    }
  }

  Future<void> _addSupportingLink() async {
    final linkController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        final theme = EnterpriseTheme.of(dialogCtx);
        return AlertDialog(
          backgroundColor: theme.colors.cardColor,
          title: Text(
            'បញ្ចូលតំណភ្ជាប់ (Insert Link)',
            style: TextStyle(color: theme.text, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: linkController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'https://...',
              labelText: 'តំណភ្ជាប់ URL (Link URL)',
              prefixIcon: Icon(Icons.link_rounded),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('បោះបង់ (Cancel)'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              style: ElevatedButton.styleFrom(backgroundColor: theme.accent),
              child: Text(
                'បញ្ចូល (Insert)',
                style: TextStyle(color: theme.colors.isDark ? AppColors.black : AppColors.white),
              ),
            ),
          ],
        );
      },
    );
    if (ok == true && linkController.text.trim().isNotEmpty && mounted) {
      setState(() {
        _supportingLinks.add(linkController.text.trim());
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

    String? selfiePath = _startSelfiePath;
    if (selfiePath == null) {
      // 1-Click flow: directly launch selfie camera
      final file = await Navigator.of(context).push<File>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => const AttendanceSelfieCamera(),
        ),
      );
      if (file == null) {
        // User cancelled selfie camera
        return;
      }
      selfiePath = file.path;
      if (mounted) {
        setState(() => _startSelfiePath = selfiePath);
      }
    }

    setState(() => _actionLoading = true);

    // Auto-capture GPS in background if not yet resolved
    double? lat = _startLat;
    double? lng = _startLng;
    if (lat == null || lng == null) {
      try {
        final pos = await LocationStatus().determinePosition('0', forceHighAccuracy: true);
        lat = pos.latitude;
        lng = pos.longitude;
      } catch (_) {}
    }

    final route = BranchRoute(
      id: const Uuid().v4(),
      purpose: _purposeController.text.trim(),
      originBranch: _selectedOrigin,
      targetBranches: _selectedTargets.toList(),
      status: 'processing',
      startTime: _departureTime,
      missionMode: _selectedMode,
      startLatitude: lat,
      startLongitude: lng,
      startSelfiePath: selfiePath,
      supportingPhotos: _supportingPhotos,
      supportingFiles: _supportingFiles,
      supportingLinks: _supportingLinks,
    );

    await BranchRouteStorage.saveActiveRoute(route);

    if (mounted) {
      setState(() {
        _activeRoute = route;
        _actionLoading = false;
      });
      _startTimer();
      final msg = _selectedMode == 'round_trip'
          ? 'ការចេញបំពេញការងារក្រៅត្រូវបានកត់ត្រាដោយជោគជ័យ!'
          : 'បេសកកម្មត្រូវបានចាប់ផ្តើមដោយជោគជ័យ!';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.customFF059669,
        ),
      );
    }
  }

  Future<void> _completeRoundTripReturn() async {
    if (_activeRoute == null) return;

    final f = await Navigator.of(context, rootNavigator: true).push<File>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const AttendanceSelfieCamera(),
      ),
    );
    if (f == null) {
      // User cancelled camera
      return;
    }

    setState(() => _actionLoading = true);
    final endSelfie = await _compressImage(f.path);

    double? endLat;
    double? endLng;
    try {
      final pos = await LocationStatus().determinePosition('0', forceHighAccuracy: true);
      endLat = pos.latitude;
      endLng = pos.longitude;
    } catch (_) {}

    final completedRoute = _activeRoute!.copyWith(
      status: 'completed',
      endTime: _currentServerTime,
      endLatitude: endLat,
      endLongitude: endLng,
      endSelfiePath: endSelfie,
      finalSummary: 'បានត្រឡប់មកដល់ហាងវិញរួចរាល់ (${_activeRoute!.originBranch})',
      totalMinutes: _activeRoute!.currentDuration.inMinutes,
      targetBranches: [_activeRoute!.originBranch],
    );

    await BranchRouteStorage.saveToHistory(completedRoute);
    await BranchRouteStorage.clearActiveRoute();
    BranchRouteStorage.syncRouteToServer(completedRoute, widget.api);

    if (mounted) {
      setState(() {
        _activeRoute = null;
        _actionLoading = false;
      });
      _tickerTimer?.cancel();
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('បានត្រឡប់មកដល់ហាងវិញ និងកត់ត្រាជោគជ័យ!'),
          backgroundColor: AppColors.customFF059669,
        ),
      );
    }
  }

  Future<void> _openArrivalSheet({bool isFinish = false}) async {
    if (_activeRoute == null) return;

    // Default to the first branch in _branchOptions that isn't the current branch
    String currentBranch = _branchOptions.firstWhere(
      (b) => b != _activeRoute!.currentBranchName,
      orElse: () => _branchOptions.isNotEmpty ? _branchOptions[0] : _activeRoute!.currentBranchName,
    );
    final customBranchCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    double? cpLat;
    double? cpLng;
    bool gettingGps = true;
    String? gpsInfo;

    // Trigger GPS immediately in background
    LocationStatus().determinePosition('0', forceHighAccuracy: true).then((pos) {
      cpLat = pos.latitude;
      cpLng = pos.longitude;
      gettingGps = false;
      gpsInfo = 'GPS: (${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)})';
    }).catchError((err) {
      gettingGps = false;
      gpsInfo = 'GPS: $err';
    });

    final arrivalServerTime = _currentServerTime;

    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final theme = EnterpriseTheme.of(context);
            return Container(
              padding: EdgeInsets.only(
                left: 14,
                right: 14,
                top: 10,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              decoration: BoxDecoration(
                color: theme.colors.cardColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.text.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          isFinish ? Icons.flag_rounded : Icons.storefront_rounded,
                          color: AppColors.customFF059669,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isFinish
                              ? 'មកដល់ & បញ្ចប់បេសកកម្ម (Arrive & Finish)'
                              : 'មកដល់សាខា (Arrival Check-in)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: theme.text,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: (currentBranch.isNotEmpty && (_branchOptions.contains(currentBranch) || currentBranch == otherBranchOption))
                          ? currentBranch
                          : (_branchOptions.isNotEmpty ? _branchOptions.first : otherBranchOption),
                      decoration: const InputDecoration(
                        labelText: 'សាខាដែលបានមកដល់ (Arrived Branch) *',
                        prefixIcon: Icon(Icons.location_city_rounded),
                      ),
                      items: [
                        for (final b in _branchOptions)
                          DropdownMenuItem(value: b, child: Text(b, overflow: TextOverflow.ellipsis)),
                        const DropdownMenuItem(
                          value: otherBranchOption,
                          child: Row(
                            children: [
                              Icon(Icons.add_circle_outline, size: 16, color: AppColors.customFF059669),
                              SizedBox(width: 6),
                              Text(
                                otherBranchOption,
                                style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.customFF059669),
                              ),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setSheetState(() => currentBranch = val);
                      },
                    ),
                    if (currentBranch == otherBranchOption) ...[
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: customBranchCtrl,
                        decoration: InputDecoration(
                          labelText: 'បញ្ចូលឈ្មោះសាខាថ្មី (Custom Branch Name) *',
                          hintText: 'ឧ. សាខាស្ទឹងមានជ័យ, សាខាខេត្ត...',
                          prefixIcon: const Icon(Icons.edit_location_alt_outlined),
                          filled: true,
                          fillColor: theme.accent.withValues(alpha: 0.06),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        autofocus: true,
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded, size: 15, color: theme.accent),
                        const SizedBox(width: 6),
                        Text(
                          'ម៉ោងមកដល់ (Server Time)៖ ${DateFormat('hh:mm a').format(arrivalServerTime)}',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.text),
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
                    const SizedBox(height: 10),
                    TextField(
                      controller: notesCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: isFinish
                            ? 'សង្ខេបលទ្ធផលការងារ (Final Summary)'
                            : 'កំណត់ត្រាសកម្មភាពការងារ (Activity notes)',
                        hintText: isFinish
                            ? 'ឧ. បានបញ្ចប់ការងារ និងរៀបចំស្តុកសាខា... (e.g. Completed tasks & restocked...)'
                            : 'ឧ. ថតរូបផលិតផលបាន ១៥ ម៉ូដ និងវីដេអូ TikTok... (e.g. Photographed 15 styles & videos...)',
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (isFinish) ...[
                      // Direct Arrive & Finish Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.flag_rounded),
                          label: const Text('ថត Selfie មកដល់ & បញ្ចប់បេសកកម្ម'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.customFF059669,
                            foregroundColor: AppColors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => _handleArrivalSave(
                            sheetContext: sheetContext,
                            currentBranch: currentBranch,
                            customBranchCtrl: customBranchCtrl,
                            notesCtrl: notesCtrl,
                            arrivalServerTime: arrivalServerTime,
                            cpLat: cpLat,
                            cpLng: cpLng,
                            isFinish: true,
                          ),
                        ),
                      ),
                    ] else ...[
                      // Arrive Check-in Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.camera_front_rounded),
                          label: const Text('រក្សាទុក Check-in'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.customFF059669,
                            foregroundColor: AppColors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => _handleArrivalSave(
                            sheetContext: sheetContext,
                            currentBranch: currentBranch,
                            customBranchCtrl: customBranchCtrl,
                            notesCtrl: notesCtrl,
                            arrivalServerTime: arrivalServerTime,
                            cpLat: cpLat,
                            cpLng: cpLng,
                            isFinish: false,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Arrive and Finish Option
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.flag_rounded, size: 16, color: AppColors.customFFE11D48),
                          label: const Text(
                            'មកដល់សាខានេះ & បញ្ចប់បេសកកម្ម',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.customFFE11D48),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.customFFE11D48,
                            side: const BorderSide(color: AppColors.customFFE11D48, width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => _handleArrivalSave(
                            sheetContext: sheetContext,
                            currentBranch: currentBranch,
                            customBranchCtrl: customBranchCtrl,
                            notesCtrl: notesCtrl,
                            arrivalServerTime: arrivalServerTime,
                            cpLat: cpLat,
                            cpLng: cpLng,
                            isFinish: true,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleArrivalSave({
    required BuildContext sheetContext,
    required String currentBranch,
    required TextEditingController customBranchCtrl,
    required TextEditingController notesCtrl,
    required DateTime arrivalServerTime,
    required double? cpLat,
    required double? cpLng,
    required bool isFinish,
  }) async {
    final finalBranchName = currentBranch == otherBranchOption
        ? customBranchCtrl.text.trim()
        : currentBranch;

    if (finalBranchName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('សូមបញ្ចូលឈ្មោះសាខា!'),
          backgroundColor: AppColors.customFFE11D48,
        ),
      );
      return;
    }

    // Directly launch selfie camera
    final f = await Navigator.of(context, rootNavigator: true).push<File>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const AttendanceSelfieCamera(),
      ),
    );
    if (f == null) {
      // User cancelled selfie camera
      return;
    }
    final selfie = await _compressImage(f.path);

    final cp = RouteCheckpoint(
      id: const Uuid().v4(),
      branchName: finalBranchName,
      actionType: 'arrival',
      arrivedAt: arrivalServerTime,
      latitude: cpLat,
      longitude: cpLng,
      notes: notesCtrl.text.trim(),
      photoPaths: [selfie],
    );

    final updatedCheckpoints = [..._activeRoute!.checkpoints, cp];
    final finalTargets = [
      ..._activeRoute!.targetBranches,
      if (!_activeRoute!.targetBranches.contains(finalBranchName)) finalBranchName,
    ];

    if (!_branchOptions.contains(finalBranchName)) {
      _branchOptions.add(finalBranchName);
    }

    if (isFinish) {
      // Finish mission right here at arrival
      final completedRoute = _activeRoute!.copyWith(
        status: 'completed',
        endTime: arrivalServerTime,
        endLatitude: cpLat,
        endLongitude: cpLng,
        endSelfiePath: selfie,
        finalSummary: notesCtrl.text.trim().isNotEmpty
            ? notesCtrl.text.trim()
            : 'បានមកដល់ និងបញ្ចប់បេសកកម្មនៅ $finalBranchName',
        totalMinutes: arrivalServerTime.difference(_activeRoute!.startTime).inMinutes,
        checkpoints: updatedCheckpoints,
        targetBranches: finalTargets,
      );

      await BranchRouteStorage.saveToHistory(completedRoute);
      await BranchRouteStorage.clearActiveRoute();
      BranchRouteStorage.syncRouteToServer(completedRoute, widget.api);

      if (mounted) {
        setState(() {
          _activeRoute = null;
          _actionLoading = false;
        });
        _tickerTimer?.cancel();
        Navigator.pop(sheetContext);
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('បានមកដល់ $finalBranchName និងបញ្ចប់បេសកកម្មដោយជោគជ័យ!'),
            backgroundColor: AppColors.customFF059669,
          ),
        );
      }
    } else {
      // Arrival Check-in only: keep in processing
      final updatedRoute = _activeRoute!.copyWith(
        checkpoints: updatedCheckpoints,
        targetBranches: finalTargets,
      );

      await BranchRouteStorage.saveActiveRoute(updatedRoute);
      if (mounted) {
        setState(() => _activeRoute = updatedRoute);
        Navigator.pop(sheetContext);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('បានមកដល់ $finalBranchName និង Check-in ជោគជ័យ!'),
            backgroundColor: AppColors.customFF059669,
          ),
        );
      }
    }
  }

  Future<void> _confirmDepartureFromCurrentBranch() async {
    if (_activeRoute == null) return;

    final currentBranch = _activeRoute!.currentBranchName;
    final notesCtrl = TextEditingController();
    double? cpLat;
    double? cpLng;
    bool gettingGps = true;
    String? gpsInfo;

    LocationStatus().determinePosition('0', forceHighAccuracy: true).then((pos) {
      cpLat = pos.latitude;
      cpLng = pos.longitude;
      gettingGps = false;
      gpsInfo = 'GPS: (${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)})';
    }).catchError((err) {
      gettingGps = false;
      gpsInfo = 'GPS: $err';
    });

    final departureServerTime = _currentServerTime;

    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final theme = EnterpriseTheme.of(context);
            return Container(
              padding: EdgeInsets.only(
                left: 14,
                right: 14,
                top: 10,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              decoration: BoxDecoration(
                color: theme.colors.cardColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.text.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.directions_car_rounded, color: Colors.orange, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'ចេញដំណើរទៅសាខាបន្ទាប់ (Depart)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: theme.text,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.storefront_rounded, color: Colors.orange, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ចេញពីសាខាបច្ចុប្បន្ន (Current Branch)',
                                  style: TextStyle(fontSize: 11, color: theme.mutedText, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  currentBranch,
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: theme.text),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded, size: 15, color: theme.accent),
                        const SizedBox(width: 6),
                        Text(
                          'ម៉ោងចេញ (Server Time)៖ ${DateFormat('hh:mm a').format(departureServerTime)}',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.text),
                        ),
                        const Spacer(),
                        if (gettingGps)
                          const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        else
                          Text(
                            gpsInfo ?? 'GPS បានចាប់ (GPS Locked)',
                            style: TextStyle(fontSize: 11, color: theme.mutedText),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: notesCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'ចំណាំការចេញដំណើរ (Departure notes)',
                        hintText: 'ឧ. ចេញដំណើរឆ្ពោះទៅសាខាទី៣... (e.g. Heading to Branch 3...)',
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.camera_front_rounded),
                        label: const Text('ចេញដំណើរ (Depart)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade700,
                          foregroundColor: AppColors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          // Launch selfie camera for departure
                          final f = await Navigator.of(context, rootNavigator: true).push<File>(
                            MaterialPageRoute(
                              fullscreenDialog: true,
                              builder: (_) => const AttendanceSelfieCamera(),
                            ),
                          );
                          if (f == null) {
                            // User cancelled selfie camera
                            return;
                          }
                          final selfie = await _compressImage(f.path);

                          final cp = RouteCheckpoint(
                            id: const Uuid().v4(),
                            branchName: currentBranch,
                            actionType: 'departure',
                            arrivedAt: departureServerTime,
                            latitude: cpLat,
                            longitude: cpLng,
                            notes: notesCtrl.text.trim(),
                            photoPaths: [selfie],
                          );

                          final updatedCheckpoints = [..._activeRoute!.checkpoints, cp];
                          final updatedRoute = _activeRoute!.copyWith(checkpoints: updatedCheckpoints);

                          await BranchRouteStorage.saveActiveRoute(updatedRoute);
                          if (mounted) {
                            setState(() => _activeRoute = updatedRoute);
                            Navigator.pop(sheetContext);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('បានកត់ត្រាការចេញដំណើរពី $currentBranch រួចរាល់!'),
                                backgroundColor: Colors.orange.shade700,
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

  Future<void> _openCompleteSheet() async {
    if (_activeRoute == null) return;

    final bool alreadyArrived = _activeRoute!.isArrived;
    String finalBranch = _activeRoute!.currentBranchName;
    if (!alreadyArrived && finalBranch.isEmpty && _branchOptions.isNotEmpty) {
      finalBranch = _branchOptions.first;
    }
    final customFinalBranchCtrl = TextEditingController();
    final summaryCtrl = TextEditingController();
    double? endLat;
    double? endLng;

    LocationStatus().determinePosition('0', forceHighAccuracy: true).then((pos) {
      endLat = pos.latitude;
      endLng = pos.longitude;
    }).catchError((_) {});

    final completeServerTime = _currentServerTime;

    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final theme = EnterpriseTheme.of(context);
            return Container(
              padding: EdgeInsets.only(
                left: 14,
                right: 14,
                top: 10,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              decoration: BoxDecoration(
                color: theme.colors.cardColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.text.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.flag_rounded, color: AppColors.customFF059669, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'បញ្ចប់បេសកកម្ម (Complete Route)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: theme.text,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: theme.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: theme.accent.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.timer_outlined, color: theme.accent, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'រយៈពេលសរុប៖ ${_activeRoute!.formattedDuration} (${_activeRoute!.liveTimerString})',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: theme.text,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    if (alreadyArrived) ...[
                      // Employee is ALREADY arrived at this branch:
                      // Location is verified, arrival selfie is already captured!
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.customFF059669.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.customFF059669.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: AppColors.customFF059669, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'សាខាបញ្ចប់ (បានមកដល់រួចរាល់)',
                                    style: TextStyle(fontSize: 11, color: theme.mutedText, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _activeRoute!.currentBranchName,
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: theme.text),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.customFF059669.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Check-in រួច',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.customFF059669),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // In transit / Departed: choose destination branch
                      DropdownButtonFormField<String>(
                        initialValue: finalBranch.isNotEmpty && (_branchOptions.contains(finalBranch) || finalBranch == otherBranchOption)
                            ? finalBranch
                            : (_branchOptions.isNotEmpty ? _branchOptions.first : otherBranchOption),
                        decoration: const InputDecoration(
                          labelText: 'សាខាបញ្ចប់ (Final Destination Branch) *',
                          prefixIcon: Icon(Icons.location_on_outlined),
                        ),
                        items: [
                          for (final b in _branchOptions)
                            DropdownMenuItem(value: b, child: Text(b, overflow: TextOverflow.ellipsis)),
                          const DropdownMenuItem(
                            value: otherBranchOption,
                            child: Row(
                              children: [
                                Icon(Icons.add_circle_outline, size: 16, color: AppColors.customFF059669),
                                SizedBox(width: 6),
                                Text(otherBranchOption, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.customFF059669)),
                              ],
                            ),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) setSheetState(() => finalBranch = val);
                        },
                      ),
                      if (finalBranch == otherBranchOption) ...[
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: customFinalBranchCtrl,
                          decoration: InputDecoration(
                            labelText: 'បញ្ចូលឈ្មោះសាខាបញ្ចប់ (Custom Final Branch) *',
                            hintText: 'ឧ. សាខាស្ទឹងមានជ័យ...',
                            prefixIcon: const Icon(Icons.edit_location_alt_outlined),
                            filled: true,
                            fillColor: theme.accent.withValues(alpha: 0.06),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          autofocus: true,
                        ),
                      ],
                    ],
                    const SizedBox(height: 10),
                    TextField(
                      controller: summaryCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'សេចក្តីសង្ខេបចុងក្រោយ (Final summary)',
                        hintText: 'ឧ. បានបញ្ចប់ការងារគ្រប់សាខាដោយរលូន... (e.g. Completed all branch tasks smoothly...)',
                      ),
                    ),
                    const SizedBox(height: 14),

                    if (alreadyArrived) ...[
                      // 1-Click Finish reusing arrival selfie (no duplicate camera or input at same location & time)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.check_circle_rounded),
                          label: const Text('បញ្ចប់បេសកកម្មឥឡូវនេះ'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.customFF059669,
                            foregroundColor: AppColors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () async {
                            final resolvedFinalBranch = _activeRoute!.currentBranchName;
                            String? endSelfie;
                            if (_activeRoute!.checkpoints.isNotEmpty &&
                                _activeRoute!.checkpoints.last.photoPaths.isNotEmpty) {
                              endSelfie = _activeRoute!.checkpoints.last.photoPaths.last;
                            } else {
                              endSelfie = _activeRoute!.startSelfiePath;
                            }

                            final completedRoute = _activeRoute!.copyWith(
                              status: 'completed',
                              endTime: completeServerTime,
                              endLatitude: endLat ?? (_activeRoute!.checkpoints.isNotEmpty ? _activeRoute!.checkpoints.last.latitude : null),
                              endLongitude: endLng ?? (_activeRoute!.checkpoints.isNotEmpty ? _activeRoute!.checkpoints.last.longitude : null),
                              endSelfiePath: endSelfie,
                              finalSummary: summaryCtrl.text.trim().isNotEmpty
                                  ? summaryCtrl.text.trim()
                                  : 'បានបញ្ចប់បេសកកម្មនៅ $resolvedFinalBranch',
                              totalMinutes: _activeRoute!.currentDuration.inMinutes,
                              targetBranches: [
                                ..._activeRoute!.targetBranches,
                                if (!_activeRoute!.targetBranches.contains(resolvedFinalBranch)) resolvedFinalBranch,
                              ],
                            );

                            await BranchRouteStorage.saveToHistory(completedRoute);
                            await BranchRouteStorage.clearActiveRoute();
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
                    ] else ...[
                      // In transit: 1 selfie for arrival & finish in one shot
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.camera_front_rounded),
                          label: const Text('បញ្ចប់បេសកកម្ម'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.customFF059669,
                            foregroundColor: AppColors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () async {
                            final resolvedFinalBranch = finalBranch == otherBranchOption
                                ? customFinalBranchCtrl.text.trim()
                                : finalBranch;

                            if (resolvedFinalBranch.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('សូមបញ្ចូលឈ្មោះសាខាបញ្ចប់!'),
                                  backgroundColor: AppColors.customFFE11D48,
                                ),
                              );
                              return;
                            }

                            final f = await Navigator.of(context, rootNavigator: true).push<File>(
                              MaterialPageRoute(
                                fullscreenDialog: true,
                                builder: (_) => const AttendanceSelfieCamera(),
                              ),
                            );
                            if (f == null) return;
                            final endSelfie = await _compressImage(f.path);

                            final cp = RouteCheckpoint(
                              id: const Uuid().v4(),
                              branchName: resolvedFinalBranch,
                              actionType: 'arrival',
                              arrivedAt: completeServerTime,
                              latitude: endLat,
                              longitude: endLng,
                              notes: summaryCtrl.text.trim(),
                              photoPaths: [endSelfie],
                            );

                            final completedRoute = _activeRoute!.copyWith(
                              status: 'completed',
                              endTime: completeServerTime,
                              endLatitude: endLat,
                              endLongitude: endLng,
                              endSelfiePath: endSelfie,
                              finalSummary: summaryCtrl.text.trim(),
                              totalMinutes: _activeRoute!.currentDuration.inMinutes,
                              checkpoints: [..._activeRoute!.checkpoints, cp],
                              targetBranches: [
                                ..._activeRoute!.targetBranches,
                                if (!_activeRoute!.targetBranches.contains(resolvedFinalBranch)) resolvedFinalBranch,
                              ],
                            );

                            await BranchRouteStorage.saveToHistory(completedRoute);
                            await BranchRouteStorage.clearActiveRoute();
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
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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
        centerTitle: false,
        leading: widget.asModal
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                tooltip: 'បិទផ្ទាំង',
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: Text(
          _activeRoute?.isProcessing == true
              ? 'បេសកកម្មកំពុងដំណើរការ'
              : 'ចាប់ផ្តើមបេសកកម្មតាមសាខា',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: theme.text,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        backgroundColor: theme.colors.cardColor,
        elevation: 1,
        shape: Border(
          bottom: BorderSide(
            color: theme.accent.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        actions: [
          IconButton(
            tooltip: workText(context, 'Branch Route Report'),
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => BranchRouteReportScreen(api: widget.api),
              ),
            ),
          ),
          if (_activeRoute?.isProcessing == true)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: ElevatedButton.icon(
                  onPressed: _openCompleteSheet,
                  icon: const Icon(Icons.flag_rounded, size: 16),
                  label: const Text(
                    'បញ្ចប់',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.customFFE11D48,
                    foregroundColor: AppColors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (widget.asModal)
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: theme.text.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            Expanded(
              child: _activeRoute?.isProcessing == true
                  ? _buildProcessingView(theme)
                  : _buildStartView(theme),
            ),
          ],
        ),
      ),
    );
  }

  // ================= STAGE 1: START / ADD VIEW =================
  Widget _buildStartView(EnterpriseTheme theme) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        children: [
          // Mode Selection: Option 1 (2-Card Selector)
          Text(
            'ប្រភេទនៃការចេញដំណើរ (Mission Type) *',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: theme.text,
            ),
          ),
          const SizedBox(height: 6),

          // Card 1: 🔄 ចេញក្រៅ & វិលត្រឡប់ (Round-trip / Out & Return)
          InkWell(
            onTap: () => setState(() => _selectedMode = 'round_trip'),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: _selectedMode == 'round_trip'
                    ? theme.accent.withValues(alpha: 0.08)
                    : theme.colors.cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _selectedMode == 'round_trip'
                      ? theme.accent
                      : theme.text.withValues(alpha: 0.15),
                  width: _selectedMode == 'round_trip' ? 1.5 : 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Radio<String>(
                    value: 'round_trip',
                    groupValue: _selectedMode,
                    activeColor: theme.accent,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedMode = val);
                    },
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '🔄 ចេញក្រៅ & វិលត្រឡប់',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: theme.text,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.customFF059669.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'ណែនាំ ⭐',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.customFF059669,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'សម្រាប់ចេញបំពេញការងារខ្លីៗ (ជួបភ្ញៀវ, ទិញសម្ភារៈ, ធនាគារ...) ហើយត្រឡប់មកហាងដើមវិញ។\n(Quick external errands & return to origin shop)',
                          style: TextStyle(fontSize: 11, color: theme.mutedText, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),

          // Card 2: 🚗 បេសកកម្មចល័ត (Multi-Branch Mission)
          InkWell(
            onTap: () => setState(() => _selectedMode = 'multi_branch'),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: _selectedMode == 'multi_branch'
                    ? theme.accent.withValues(alpha: 0.08)
                    : theme.colors.cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _selectedMode == 'multi_branch'
                      ? theme.accent
                      : theme.text.withValues(alpha: 0.15),
                  width: _selectedMode == 'multi_branch' ? 1.5 : 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Radio<String>(
                    value: 'multi_branch',
                    groupValue: _selectedMode,
                    activeColor: theme.accent,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedMode = val);
                    },
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🚗 បេសកកម្មចល័ត',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: theme.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'សម្រាប់ចុះបំពេញការងារឆ្លងកាត់ច្រើនសាខា (A ➔ B ➔ C...) មិនប្រាកដថាមកវិញភ្លាមៗ។\n(Sequential travel across multiple branches)',
                          style: TextStyle(fontSize: 11, color: theme.mutedText, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Auto Origin Branch (No dropdown needed as it auto-selects from current system branch)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colors.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.accent.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.storefront_rounded, size: 18, color: theme.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'សាខាចេញដំណើរ (Auto Branch)',
                        style: TextStyle(fontSize: 10, color: theme.mutedText, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        _selectedOrigin,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: theme.text),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.customFF059669.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 10, color: AppColors.customFF059669),
                      SizedBox(width: 3),
                      Text(
                        'ប្រព័ន្ធកំណត់ស្វ័យប្រវត្តិ',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.customFF059669),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // ម៉ោងចេញដំណើរ (Server Time - Non-editable)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colors.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.accent.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.lock_clock_outlined, color: theme.accent, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ម៉ោងចេញដំណើរ (Server Time)',
                        style: TextStyle(fontSize: 10, color: theme.mutedText, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        DateFormat('hh:mm:ss a').format(_departureTime),
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: theme.text),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: theme.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: theme.accent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_done_rounded, size: 10, color: theme.accent),
                      const SizedBox(width: 3),
                      Text(
                        'Server Time',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: theme.accent),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Purpose Section
          Row(
            children: [
              Text(
                'គោលបំណងបេសកកម្ម (Mission Purpose) *',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: theme.text),
              ),
              const Spacer(),
              if (_supportingPhotos.isNotEmpty || _supportingFiles.isNotEmpty || _supportingLinks.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${_supportingPhotos.length + _supportingFiles.length + _supportingLinks.length} ឯកសារភ្ជាប់ (Attachments)',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: theme.accent),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          TextFormField(
            controller: _purposeController,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'បញ្ចូលគោលបំណងបេសកកម្ម (ឧ. ចុះថតរូបផលិតផលថ្មី, ជួបអតិថិជន...) / Mission purpose...',
              prefixIcon: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Icon(Icons.assignment_outlined, color: theme.accent, size: 20),
              ),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'សូមបញ្ចូលគោលបំណងបេសកកម្ម!';
              }
              return null;
            },
          ),
          const SizedBox(height: 6),

          // Purpose Rich Toolbar: Image (with compress), File, Emoji, Link
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colors.cardColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: theme.accent.withValues(alpha: 0.2)),
            ),
            child: Wrap(
              spacing: 2,
              runSpacing: 2,
              alignment: WrapAlignment.start,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // 1. Image (with compression)
                TextButton.icon(
                  onPressed: _pickSupportingImage,
                  icon: const Icon(Icons.add_photo_alternate_outlined, size: 16),
                  label: const Text('រូបភាព', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: theme.accent,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  ),
                ),
                // 2. File
                TextButton.icon(
                  onPressed: _pickSupportingFiles,
                  icon: const Icon(Icons.attach_file_rounded, size: 16),
                  label: const Text('ឯកសារ', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: theme.accent,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  ),
                ),
                // 3. Emoji
                TextButton.icon(
                  onPressed: () => setState(() => _showEmojiTray = !_showEmojiTray),
                  icon: const Icon(Icons.emoji_emotions_outlined, size: 16),
                  label: const Text('Emoji', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: _showEmojiTray ? AppColors.customFF059669 : theme.accent,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  ),
                ),
                // 4. Link
                TextButton.icon(
                  onPressed: _addSupportingLink,
                  icon: const Icon(Icons.link_rounded, size: 16),
                  label: const Text('តំណភ្ជាប់', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: theme.accent,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  ),
                ),
              ],
            ),
          ),

          // Emoji Tray
          if (_showEmojiTray) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colors.cardColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.accent.withValues(alpha: 0.25)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final em in _quickEmojis)
                      InkWell(
                        onTap: () => _insertEmoji(em),
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                          child: Text(em, style: const TextStyle(fontSize: 20)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],

          // Supporting Attachments Preview
          if (_supportingPhotos.isNotEmpty || _supportingFiles.isNotEmpty || _supportingLinks.isNotEmpty) ...[
            const SizedBox(height: 8),
            // Attached Images
            if (_supportingPhotos.isNotEmpty) ...[
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var i = 0; i < _supportingPhotos.length; i++)
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(_supportingPhotos[i]),
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: -6,
                          right: -6,
                          child: IconButton(
                            icon: const Icon(Icons.cancel, color: AppColors.customFFE11D48, size: 18),
                            onPressed: () => setState(() => _supportingPhotos.removeAt(i)),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 6),
            ],

            // Attached Files
            for (var i = 0; i < _supportingFiles.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colors.cardColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.accent.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.insert_drive_file_outlined, size: 16, color: theme.accent),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _supportingFiles[i].split('/').last,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: theme.text),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.close_rounded, size: 14, color: AppColors.customFFE11D48),
                        onPressed: () => setState(() => _supportingFiles.removeAt(i)),
                      ),
                    ],
                  ),
                ),
              ),

            // Attached Links
            for (var i = 0; i < _supportingLinks.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colors.cardColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.accent.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.link_rounded, size: 16, color: theme.accent),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _supportingLinks[i],
                          style: TextStyle(fontSize: 11, color: theme.accent, decoration: TextDecoration.underline),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.close_rounded, size: 14, color: AppColors.customFFE11D48),
                        onPressed: () => setState(() => _supportingLinks.removeAt(i)),
                      ),
                    ],
                  ),
                ),
              ),
          ],
          const SizedBox(height: 14),

          // Start Mission Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: _actionLoading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(
                      _selectedMode == 'round_trip'
                          ? Icons.replay_circle_filled_rounded
                          : Icons.camera_front_rounded,
                      size: 20,
                    ),
              label: Text(
                _selectedMode == 'round_trip'
                    ? 'ចេញក្រៅ'
                    : 'ចាប់ផ្តើមបេសកកម្ម',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.accent,
                foregroundColor: theme.colors.isDark ? AppColors.black : AppColors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _actionLoading ? null : _startMission,
            ),
          ),

          // Daily / monthly branch route report list
          BranchRouteReportSection(
            api: widget.api,
            embedded: true,
            heading: true,
          ),
        ],
      ),
    );
  }

  // ================= STAGE 2: IN-PROGRESS / PROCESSING VIEW =================
  Widget _buildProcessingView(EnterpriseTheme theme) {
    final route = _activeRoute!;
    if (route.isRoundTrip) {
      return _buildRoundTripProcessingView(theme, route);
    }
    return _buildMultiBranchProcessingView(theme, route);
  }

  Widget _buildRoundTripProcessingView(EnterpriseTheme theme, BranchRoute route) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      children: [
        // Live Active Header Card
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colors.cardColor,
                theme.colors.cardColor.withValues(alpha: 0.85),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.customFF059669.withValues(alpha: 0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.customFF059669.withValues(alpha: 0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.customFF059669,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    '🔄 កំពុងបំពេញការងារក្រៅ (Out on Errands)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.customFF059669,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                route.liveTimerString,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                  color: theme.text,
                ),
              ),
              Text(
                'រយៈពេលចំណាយរហូតមកដល់បច្ចុប្បន្ន (Elapsed Time)',
                style: TextStyle(fontSize: 11, color: theme.mutedText),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.customFF059669.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.customFF059669.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.storefront_rounded, size: 14, color: AppColors.customFF059669),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'ចេញពី៖ ${route.originBranch}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.customFF059669),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'សកម្មភាពបន្ទាប់៖ ចុច "ត្រឡប់មកដល់ហាងវិញ" ពេលមកដល់ (Next: Tap Return when back)',
                style: TextStyle(fontSize: 10, color: theme.mutedText, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Route overview card
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colors.cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.accent.withValues(alpha: 0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (route.startSelfiePath != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(route.startSelfiePath!),
                        width: 46,
                        height: 46,
                        fit: BoxFit.cover,
                      ),
                    ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          route.purpose,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: theme.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'ចេញពី៖ ${route.originBranch}',
                          style: TextStyle(fontSize: 11, color: theme.mutedText),
                        ),
                        Text(
                          'គោលដៅ៖ ត្រឡប់មក ${route.originBranch} វិញ',
                          style: TextStyle(fontSize: 11, color: AppColors.customFF059669, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'ម៉ោងចេញ៖ ${DateFormat('hh:mm a').format(route.startTime)}',
                          style: TextStyle(fontSize: 11, color: theme.accent, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 1-Click Return to Shop Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: _actionLoading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.camera_front_rounded, size: 20),
            label: const Text(
              'ត្រឡប់មកដល់ហាងវិញ',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.customFF059669,
              foregroundColor: AppColors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 1,
            ),
            onPressed: _actionLoading ? null : _completeRoundTripReturn,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildMultiBranchProcessingView(EnterpriseTheme theme, BranchRoute route) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      children: [
        // Live Active Header Card
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colors.cardColor,
                theme.colors.cardColor.withValues(alpha: 0.85),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.accent.withValues(alpha: 0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: theme.accent.withValues(alpha: 0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: route.isDeparted ? Colors.orange : AppColors.customFF059669,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'បេសកកម្មកំពុងដំណើរការ (Processing)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: theme.accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                route.liveTimerString,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                  color: theme.text,
                ),
              ),
              Text(
                'រយៈពេលចំណាយរហូតមកដល់បច្ចុប្បន្ន (Elapsed Time)',
                style: TextStyle(fontSize: 11, color: theme.mutedText),
              ),
              const SizedBox(height: 8),
              // State Machine Status Badge
              if (route.isDeparted) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.directions_car_rounded, size: 14, color: Colors.orange),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '🚗 កំពុងធ្វើដំណើរ (ចេញពី៖ ${route.currentBranchName})',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'សកម្មភាពបន្ទាប់៖ ចុច "មកដល់សាខា" ពេលទៅដល់ ឬ "បញ្ចប់" នៅខាងលើស្តាំ (Next: Tap Arrive or Finish)',
                  style: TextStyle(fontSize: 10, color: theme.mutedText, fontWeight: FontWeight.w500),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.customFF059669.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.customFF059669.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.storefront_rounded, size: 14, color: AppColors.customFF059669),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '🏬 បានមកដល់៖ ${route.currentBranchName}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.customFF059669),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'សកម្មភាពបន្ទាប់៖ ចុច "ចេញបន្ត" ឬ "បញ្ចប់" នៅខាងលើស្តាំ (Next: Tap Depart or Finish)',
                  style: TextStyle(fontSize: 10, color: theme.mutedText, fontWeight: FontWeight.w500),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Route overview card
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colors.cardColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (route.startSelfiePath != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(route.startSelfiePath!),
                        width: 46,
                        height: 46,
                        fit: BoxFit.cover,
                      ),
                    ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          route.purpose,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: theme.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'ចេញពី៖ ${route.originBranch}',
                          style: TextStyle(fontSize: 11, color: theme.mutedText),
                        ),
                        Text(
                          'ម៉ោងចេញ៖ ${DateFormat('hh:mm a').format(route.startTime)}',
                          style: TextStyle(fontSize: 11, color: theme.accent, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Timeline Checkpoints Title
        Row(
          children: [
            Icon(Icons.alt_route_rounded, color: theme.accent, size: 18),
            const SizedBox(width: 6),
            Text(
              'សកម្មភាពតាមសាខា (${route.checkpoints.length} Checkpoints)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: theme.text,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),

        if (route.checkpoints.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colors.cardColor.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                'មិនទាន់មានការ Check-in សាខានៅឡើយទេ។\nចុច "មកដល់សាខា" ពេលទៅដល់សាខាបន្ទាប់!\n(No check-ins yet. Tap "Arrive at Branch" upon arrival!)',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: theme.mutedText, height: 1.3),
              ),
            ),
          )
        else
          for (var i = 0; i < route.checkpoints.length; i++) ...[
            _buildCheckpointCard(route.checkpoints[i], i + 1, theme),
            const SizedBox(height: 6),
          ],
        const SizedBox(height: 12),

        // Action Buttons according to State Machine:
        if (route.isDeparted) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.storefront_rounded, size: 18),
              label: const Text(
                'មកដល់សាខា (Arrive at Branch)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.customFF059669,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _openArrivalSheet(isFinish: false),
            ),
          ),
        ] else ...[
          // State is arrived: can Depart to next branch (with front selfie)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.directions_car_rounded, size: 18),
              label: const Text(
                'ចេញបន្ត (Depart)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade700,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _confirmDepartureFromCurrentBranch,
            ),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildCheckpointCard(RouteCheckpoint cp, int index, EnterpriseTheme theme) {
    final isArrival = cp.isArrival;
    final color = isArrival ? AppColors.customFF059669 : Colors.orange;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colors.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: color,
                child: Icon(
                  isArrival ? Icons.storefront_rounded : Icons.directions_car_rounded,
                  size: 13,
                  color: AppColors.white,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isArrival ? 'មកដល់' : 'ចេញដំណើរ',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color),
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
                  overflow: TextOverflow.ellipsis,
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
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: Text(
                cp.notes,
                style: TextStyle(fontSize: 12, color: theme.text.withValues(alpha: 0.9)),
              ),
            ),
          ],
          if (cp.photoPaths.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: SizedBox(
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
            ),
          ],
        ],
      ),
    );
  }
}
