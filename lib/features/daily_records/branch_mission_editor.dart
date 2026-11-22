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
import 'branch_route_storage.dart';
import 'daily_records_api.dart';

class BranchMissionEditor extends StatefulWidget {
  const BranchMissionEditor({
    super.key,
    required this.api,
    this.entry,
    this.autoLaunchSelfie = false,
    this.asModal = false,
  });

  final DailyRecordsApi api;
  final RecordData? entry;
  final bool autoLaunchSelfie;
  final bool asModal;

  @override
  State<BranchMissionEditor> createState() => _BranchMissionEditorState();
}

class _BranchMissionEditorState extends State<BranchMissionEditor> {
  static const String otherBranchOption = 'ផ្សេងទៀត (បញ្ចូលថ្មី / Other)';

  static const _defaultBranches = [
    'សាខាទី១ - ទួលគោក (Toul Kork)',
    'សាខាទី២ - សែនសុខ (Sen Sok)',
    'សាខាទី៣ - ច្បារអំពៅ (Chbar Ampov)',
    'សាខាទី៤ - បឹងកេងកង (BKK)',
    'សាខាទី៥ - ចំការមន (Chamkarmon)',
  ];

  late final List<String> _branchOptions = List<String>.from(_defaultBranches);
  String? _detectedSystemBranch;

  BranchRoute? _activeRoute;
  bool _loading = true;
  Timer? _tickerTimer;

  // Form controllers for Stage 1 (Start/Add)
  final _formKey = GlobalKey<FormState>();
  final _purposeController = TextEditingController();
  DateTime _departureTime = DateTime.now();
  late String _selectedOrigin = _branchOptions[0];
  final Set<String> _selectedTargets = {};
  String? _startSelfiePath;
  double? _startLat;
  double? _startLng;
  bool _fetchingGps = false;
  String? _gpsMessage;

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
    _selectedTargets.add(_branchOptions[1]);
    _initData();
  }

  Future<void> _initData() async {
    // 1. Try to load system branches from TeamSheetProvider
    try {
      final teamSheet = context.read<TeamSheetProvider?>();
      if (teamSheet != null && teamSheet.branches.isNotEmpty) {
        final liveBranches = teamSheet.branches
            .map((b) => b.name.trim())
            .where((n) => n.isNotEmpty && n.toLowerCase() != 'all')
            .toList();
        if (liveBranches.isNotEmpty) {
          _branchOptions.clear();
          _branchOptions.addAll(liveBranches);
        }
      }
    } catch (_) {}

    // 2. Try to load cached system branches from SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getStringList('system_branch_names');
      if (cached != null && cached.isNotEmpty) {
        for (final b in cached) {
          if (!_branchOptions.contains(b)) _branchOptions.add(b);
        }
      }
    } catch (_) {}

    // 3. Background fetch from TeamSheetRepository
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

    // Auto-detect branch from system preferences or providers
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

      final match = _branchOptions.firstWhere(
        (b) =>
            b.toLowerCase().contains(trimmed.toLowerCase()) ||
            trimmed.toLowerCase().contains(b.toLowerCase()),
        orElse: () => '',
      );

      if (match.isNotEmpty) {
        _selectedOrigin = match;
      } else {
        _branchOptions.insert(0, trimmed);
        _selectedOrigin = trimmed;
      }

      _selectedTargets.remove(_selectedOrigin);
      if (_selectedTargets.isEmpty) {
        final next = _branchOptions.firstWhere(
          (b) => b != _selectedOrigin,
          orElse: () => _branchOptions.last,
        );
        _selectedTargets.add(next);
      }
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
              labelText: 'Link URL',
              prefixIcon: Icon(Icons.link_rounded),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('បោះបង់'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              style: ElevatedButton.styleFrom(backgroundColor: theme.accent),
              child: Text(
                'បញ្ចូល',
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('បេសកកម្មត្រូវបានចាប់ផ្តើមដោយជោគជ័យ!'),
          backgroundColor: AppColors.customFF059669,
        ),
      );
    }
  }

  Future<void> _openArrivalSheet() async {
    if (_activeRoute == null) return;

    // Default to the first branch in _branchOptions that isn't the current branch
    String currentBranch = _branchOptions.firstWhere(
      (b) => b != _activeRoute!.currentBranchName,
      orElse: () => _branchOptions.isNotEmpty ? _branchOptions[0] : _activeRoute!.currentBranchName,
    );
    final notesCtrl = TextEditingController();
    final List<String> photos = [];
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
                        const Icon(Icons.storefront_rounded, color: AppColors.customFF059669, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'មកដល់សាខា (Arrival Check-in)',
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
                        labelText: 'សាខាដែលបានមកដល់ (Arrived Branch) *',
                        prefixIcon: Icon(Icons.location_city_rounded),
                      ),
                      items: [
                        for (final b in _branchOptions)
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
                          'ម៉ោងមកដល់ (Server Time)៖ ${DateFormat('hh:mm a').format(arrivalServerTime)}',
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
                            final img = await picker.pickImage(source: ImageSource.camera);
                            if (img != null) {
                              final compressed = await _compressImage(img.path);
                              setSheetState(() => photos.add(compressed));
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
                        label: const Text('បញ្ជាក់ការមកដល់សាខា'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.customFF059669,
                          foregroundColor: AppColors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () {
                          final cp = RouteCheckpoint(
                            id: const Uuid().v4(),
                            branchName: currentBranch,
                            actionType: 'arrival',
                            arrivedAt: arrivalServerTime,
                            latitude: cpLat,
                            longitude: cpLng,
                            notes: notesCtrl.text.trim(),
                            photoPaths: photos,
                          );

                          final updatedCheckpoints = [..._activeRoute!.checkpoints, cp];
                          final updatedRoute = _activeRoute!.copyWith(
                            checkpoints: updatedCheckpoints,
                            targetBranches: [
                              ..._activeRoute!.targetBranches,
                              if (!_activeRoute!.targetBranches.contains(currentBranch)) currentBranch,
                            ],
                          );

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
                        const Icon(Icons.directions_car_rounded, color: Colors.orange, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'ចេញដំណើរទៅសាខាបន្ទាប់ (Depart)',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: theme.text,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
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
                                  'ចេញពីសាខាបច្ចុប្បន្ន',
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
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded, size: 16, color: theme.accent),
                        const SizedBox(width: 6),
                        Text(
                          'ម៉ោងចេញ (Server Time)៖ ${DateFormat('hh:mm a').format(departureServerTime)}',
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
                    TextField(
                      controller: notesCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'ចំណាំការចេញដំណើរ (Optional note)',
                        hintText: 'ឧ. ចេញដំណើរឆ្ពោះទៅសាខាទី៣...',
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.directions_car_rounded),
                        label: const Text('បញ្ជាក់ការចេញដំណើរ'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade700,
                          foregroundColor: AppColors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () {
                          final cp = RouteCheckpoint(
                            id: const Uuid().v4(),
                            branchName: currentBranch,
                            actionType: 'departure',
                            arrivedAt: departureServerTime,
                            latitude: cpLat,
                            longitude: cpLng,
                            notes: notesCtrl.text.trim(),
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

    String finalBranch = _activeRoute!.currentBranchName;
    String? endSelfie;
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
                        for (final b in _branchOptions)
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
                            endTime: completeServerTime,
                            endLatitude: endLat,
                            endLongitude: endLng,
                            endSelfiePath: endSelfie,
                            finalSummary: summaryCtrl.text.trim(),
                            totalMinutes: _activeRoute!.currentDuration.inMinutes,
                            targetBranches: [
                              ..._activeRoute!.targetBranches,
                              if (!_activeRoute!.targetBranches.contains(finalBranch)) finalBranch,
                            ],
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
          // Auto Origin Branch (No dropdown needed as it auto-selects from current system branch)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colors.cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.accent.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.storefront_rounded, size: 20, color: theme.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'សាខាចេញដំណើរ (Auto Branch)',
                        style: TextStyle(fontSize: 11, color: theme.mutedText, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _selectedOrigin,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: theme.text),
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
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 12, color: AppColors.customFF059669),
                      SizedBox(width: 4),
                      Text(
                        'ប្រព័ន្ធកំណត់ស្វ័យប្រវត្តិ',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.customFF059669),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ម៉ោងចេញដំណើរ (Server Time - Non-editable)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colors.cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.accent.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.lock_clock_outlined, color: theme.accent, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ម៉ោងចេញដំណើរ (Server Time)',
                        style: TextStyle(fontSize: 11, color: theme.mutedText, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('hh:mm:ss a').format(_departureTime),
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: theme.text),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.accent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_done_rounded, size: 12, color: theme.accent),
                      const SizedBox(width: 4),
                      Text(
                        'Server Time',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.accent),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Purpose Section
          Row(
            children: [
              Text(
                'គោលបំណងបេសកកម្ម (Mission Purpose) *',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: theme.text),
              ),
              const Spacer(),
              if (_supportingPhotos.isNotEmpty || _supportingFiles.isNotEmpty || _supportingLinks.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${_supportingPhotos.length + _supportingFiles.length + _supportingLinks.length} ឯកសារភ្ជាប់',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: theme.accent),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _purposeController,
            minLines: 3,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: 'បញ្ចូលគោលបំណងបេសកកម្ម (ឧ. ចុះថតរូបផលិតផលថ្មី និងវីដេអូ TikTok ផ្សព្វផ្សាយ...)',
              prefixIcon: Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: Icon(Icons.assignment_outlined, color: theme.accent),
              ),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'សូមបញ្ចូលគោលបំណងបេសកកម្ម!';
              }
              return null;
            },
          ),
          const SizedBox(height: 8),

          // Purpose Rich Toolbar: Image (with compress), File, Emoji, Link
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colors.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.accent.withValues(alpha: 0.2)),
            ),
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              alignment: WrapAlignment.start,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // 1. Image (with compression)
                TextButton.icon(
                  onPressed: _pickSupportingImage,
                  icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                  label: const Text('រូបភាព'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: theme.accent,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
                // 2. File
                TextButton.icon(
                  onPressed: _pickSupportingFiles,
                  icon: const Icon(Icons.attach_file_rounded, size: 18),
                  label: const Text('ឯកសារ'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: theme.accent,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
                // 3. Emoji
                TextButton.icon(
                  onPressed: () => setState(() => _showEmojiTray = !_showEmojiTray),
                  icon: const Icon(Icons.emoji_emotions_outlined, size: 18),
                  label: const Text('Emoji'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: _showEmojiTray ? AppColors.customFF059669 : theme.accent,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
                // 4. Link
                TextButton.icon(
                  onPressed: _addSupportingLink,
                  icon: const Icon(Icons.link_rounded, size: 18),
                  label: const Text('តំណភ្ជាប់'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: theme.accent,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
              ],
            ),
          ),

          // Emoji Tray
          if (_showEmojiTray) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colors.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.accent.withValues(alpha: 0.25)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final em in _quickEmojis)
                      InkWell(
                        onTap: () => _insertEmoji(em),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          child: Text(em, style: const TextStyle(fontSize: 22)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],

          // Supporting Attachments Preview
          if (_supportingPhotos.isNotEmpty || _supportingFiles.isNotEmpty || _supportingLinks.isNotEmpty) ...[
            const SizedBox(height: 12),
            // Attached Images
            if (_supportingPhotos.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < _supportingPhotos.length; i++)
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            File(_supportingPhotos[i]),
                            width: 68,
                            height: 68,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: -6,
                          right: -6,
                          child: IconButton(
                            icon: const Icon(Icons.cancel, color: AppColors.customFFE11D48, size: 20),
                            onPressed: () => setState(() => _supportingPhotos.removeAt(i)),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // Attached Files
            for (var i = 0; i < _supportingFiles.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colors.cardColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: theme.accent.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.insert_drive_file_outlined, size: 18, color: theme.accent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _supportingFiles[i].split('/').last,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.text),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.customFFE11D48),
                        onPressed: () => setState(() => _supportingFiles.removeAt(i)),
                      ),
                    ],
                  ),
                ),
              ),

            // Attached Links
            for (var i = 0; i < _supportingLinks.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colors.cardColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: theme.accent.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.link_rounded, size: 18, color: theme.accent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _supportingLinks[i],
                          style: TextStyle(fontSize: 12, color: theme.accent, decoration: TextDecoration.underline),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.customFFE11D48),
                        onPressed: () => setState(() => _supportingLinks.removeAt(i)),
                      ),
                    ],
                  ),
                ),
              ),
          ],
          const SizedBox(height: 24),

          // Start Mission Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: _actionLoading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.camera_front_rounded, size: 22),
              label: const Text(
                'ថត Selfie & ចាប់ផ្តើមបេសកកម្ម',
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
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: route.isDeparted ? Colors.orange : AppColors.customFF059669,
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
              const SizedBox(height: 12),
              // State Machine Status Badge
              if (route.isDeparted) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.directions_car_rounded, size: 16, color: Colors.orange),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '🚗 កំពុងធ្វើដំណើរ (ចេញពី៖ ${route.currentBranchName})',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'សកម្មភាពបន្ទាប់៖ ចុច "មកដល់សាខា" ពេលទៅដល់',
                  style: TextStyle(fontSize: 11, color: theme.mutedText, fontWeight: FontWeight.w500),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.customFF059669.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.customFF059669.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.storefront_rounded, size: 16, color: AppColors.customFF059669),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '🏬 បានមកដល់៖ ${route.currentBranchName}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.customFF059669),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'សកម្មភាពបន្ទាប់៖ ចុច "ចេញបន្ត" ឬ "បញ្ចប់បេសកកម្ម"',
                  style: TextStyle(fontSize: 11, color: theme.mutedText, fontWeight: FontWeight.w500),
                ),
              ],
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
                'មិនទាន់មានការ Check-in សាខានៅឡើយទេ។\nចុច "មកដល់សាខា" ពេលទៅដល់សាខាបន្ទាប់!',
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

        // Action Buttons according to State Machine:
        // ប្រសិនបើសកម្មភាពចេញ សកម្មភាពបន្ទាប់ត្រូវតែមកដល់
        if (route.isDeparted) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.storefront_rounded, size: 20),
              label: const Text(
                'មកដល់សាខា (Arrive at Branch)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.customFF059669,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _openArrivalSheet,
            ),
          ),
        ] else ...[
          // State is arrived: can Depart to next branch or Finish mission
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.directions_car_rounded, color: Colors.orange, size: 20),
                  label: const Text(
                    'ចេញបន្ត (Depart)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _confirmDepartureFromCurrentBranch,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.flag_rounded, size: 20),
                  label: const Text(
                    'បញ្ចប់បេសកកម្ម',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.customFF059669,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _openCompleteSheet,
                ),
              ),
            ],
          ),
        ],
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
