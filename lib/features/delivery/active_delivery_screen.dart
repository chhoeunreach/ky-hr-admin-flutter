import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:cnattendance/widget/attendance_bottom_sheet.dart';
import 'delivery_api.dart';
import 'delivery_model.dart';
import 'delivery_tracker_service.dart';

class ActiveDeliveryScreen extends StatefulWidget {
  const ActiveDeliveryScreen({super.key, required this.delivery});

  final DeliveryModel delivery;

  @override
  State<ActiveDeliveryScreen> createState() => _ActiveDeliveryScreenState();
}

class _ActiveDeliveryScreenState extends State<ActiveDeliveryScreen> {
  late DeliveryModel _delivery;
  final _api = DeliveryApi();
  final _imagePicker = ImagePicker();

  Timer? _elapsedTimer;
  late final ValueNotifier<Duration> _elapsedNotifier;
  bool _isActionInProgress = false;

  @override
  void initState() {
    super.initState();
    _delivery = widget.delivery;

    // Start timer from startedAt using ValueNotifier to prevent full-screen rebuilds
    final start = _delivery.startedAt ?? DateTime.now();
    _elapsedNotifier =
        ValueNotifier<Duration>(DateTime.now().difference(start));
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsedNotifier.value = DateTime.now().difference(start);
    });

    // Ensure GPS tracking is active
    DeliveryTrackerService.instance.startTracking(_delivery.id);
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _elapsedNotifier.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  Future<void> _callCustomer() async {
    final phone = _delivery.customerPhone.replaceAll(' ', '');
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openGoogleMaps() async {
    String query = '';
    if (_delivery.destinationLatitude != null &&
        _delivery.destinationLongitude != null) {
      query =
          '${_delivery.destinationLatitude},${_delivery.destinationLongitude}';
    } else if (_delivery.destinationAddress != null &&
        _delivery.destinationAddress!.isNotEmpty) {
      query = Uri.encodeComponent(_delivery.destinationAddress!);
    } else {
      return;
    }

    final url =
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _copyTrackingLink() async {
    final link = _delivery.trackingUrl;
    if (link == null || link.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: link));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('បានចម្លងតំណភ្ជាប់ជោគជ័យ (Copied live tracking link)'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _shareToTelegram() async {
    final link = _delivery.trackingUrl;
    if (link == null || link.isEmpty) return;

    final msg = 'សូមតាមដានទីតាំងដឹកទំនិញរបស់អ្នកផ្ទាល់ (Live Tracking):\n$link';

    // Try sharing via Telegram direct URL first, fallback to native share
    final tgUri = Uri.parse(
        'https://t.me/share/url?url=${Uri.encodeComponent(link)}&text=${Uri.encodeComponent("ការតាមដានការដឹកជញ្ជូន KNEAYERNG")}');

    try {
      if (await canLaunchUrl(tgUri)) {
        await launchUrl(tgUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}

    // Fallback native share
    await Share.share(msg);
  }

  Future<void> _showCompleteSheet() async {
    XFile? pickedPhoto;
    final noteController = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        top: false,
        child: StatefulBuilder(
          builder: (ctx, setSheetState) {
            final theme = EnterpriseTheme.of(ctx);
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                top: 24,
                left: 20,
                right: 20,
              ),
              decoration: BoxDecoration(
                color: theme.contentSurface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          '✅ បញ្ចប់ការដឹកជញ្ជូន',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'ថតរូបទំនិញ ឬទីតាំងប្រគល់ជូនអតិថិជន (Proof of Delivery)',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 14),

                    // Photo preview / select
                    if (pickedPhoto != null)
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              File(pickedPhoto!.path),
                              height: 160,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: InkWell(
                              onTap: () =>
                                  setSheetState(() => pickedPhoto = null),
                              child: const CircleAvatar(
                                radius: 14,
                                backgroundColor: Colors.black54,
                                child: Icon(Icons.close,
                                    size: 16, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final img = await _imagePicker.pickImage(
                                  source: ImageSource.camera,
                                  imageQuality: 75,
                                  maxWidth: 1600,
                                  maxHeight: 1600,
                                );
                                if (img != null) {
                                  setSheetState(() => pickedPhoto = img);
                                }
                              },
                              icon: const Icon(Icons.camera_alt_outlined),
                              label: const Text('ថតរូប (Camera)'),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final img = await _imagePicker.pickImage(
                                  source: ImageSource.gallery,
                                  imageQuality: 75,
                                  maxWidth: 1600,
                                  maxHeight: 1600,
                                );
                                if (img != null) {
                                  setSheetState(() => pickedPhoto = img);
                                }
                              },
                              icon: const Icon(Icons.photo_library_outlined),
                              label: const Text('ជ្រើសរូប (Gallery)'),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 16),

                    // Note field
                    TextField(
                      controller: noteController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'កំណត់ចំណាំបន្ថែម (ឧ. ប្រគល់ជូនសន្តិសុខ)',
                        filled: true,
                        fillColor: theme.cardBackground,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: theme.cardBorder),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'ពេលចុចបញ្ជាក់ កាមេរ៉ាមុខនឹងបើកដើម្បីថត Selfie អ្នកដឹក។',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.mutedText,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Confirm button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () async {
                          XFile? selfie;
                          try {
                            selfie = await _imagePicker.pickImage(
                              source: ImageSource.camera,
                              preferredCameraDevice: CameraDevice.front,
                              imageQuality: 80,
                              maxWidth: 1600,
                              maxHeight: 1600,
                            );
                          } catch (error) {
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('មិនអាចបើកកាមេរ៉ាបាន៖ $error'),
                                ),
                              );
                            }
                            return;
                          }
                          if (selfie == null || !ctx.mounted) return;

                          Navigator.pop(ctx);
                          await _completeDelivery(
                            photo: pickedPhoto,
                            completionSelfie: selfie,
                            notes: noteController.text.trim(),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'បញ្ជាក់ការប្រគល់ជោគជ័យ (Confirm Delivered)',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _completeDelivery({
    XFile? photo,
    required XFile completionSelfie,
    String? notes,
  }) async {
    setState(() => _isActionInProgress = true);
    try {
      final updated = await _api.completeDelivery(
        deliveryId: _delivery.id,
        proofPhoto: photo,
        completionSelfie: completionSelfie,
        notes: notes,
      );

      // Stop tracking GPS
      await DeliveryTrackerService.instance.stopTracking();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 ការដឹកជញ្ជូនត្រូវបានបញ្ចប់ដោយជោគជ័យ!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(updated);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionInProgress = false);
    }
  }

  Future<void> _cancelDelivery() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('បោះបង់ការដឹកជញ្ជូន?'),
        content: const Text('តើអ្នកពិតជាចង់បោះបង់ការដឹកជញ្ជូននេះមែនទេ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('មិនបោះបង់'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('បោះបង់', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isActionInProgress = true);
    try {
      await _api.cancelDelivery(deliveryId: _delivery.id);
      await DeliveryTrackerService.instance.stopTracking();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ការដឹកជញ្ជូនត្រូវបានបោះបង់')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionInProgress = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = EnterpriseTheme.of(context);
    final surface = theme.contentSurface;
    final primary = theme.primary;

    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        title: Text(
          _delivery.trackingCode.isNotEmpty
              ? _delivery.trackingCode
              : 'ការដឹកជញ្ជូន (Active Delivery)',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'បោះបង់',
            icon: const Icon(Icons.cancel_outlined, color: Colors.red),
            onPressed: _isActionInProgress ? null : _cancelDelivery,
          ),
        ],
        elevation: 0.5,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status & Timer Header Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primary, primary.withValues(alpha: 0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.two_wheeler_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'កំពុងធ្វើដំណើរ (In Transit)',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.timer_outlined,
                                  color: Colors.white70, size: 16),
                              const SizedBox(width: 4),
                              ValueListenableBuilder<Duration>(
                                valueListenable: _elapsedNotifier,
                                builder: (context, elapsed, _) {
                                  return Text(
                                    'រយៈពេល៖ ${_formatDuration(elapsed)}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Inter-Branch Destination Card & Attendance Scan Shortcut
              if (_delivery.deliveryType == 'branch' ||
                  _delivery.destinationBranchName != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.purple.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.store_mall_directory_rounded,
                              color: Colors.purple.shade800, size: 22),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'ដឹកអីវ៉ាន់តាមសាខា (Branch Transfer)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.purple.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _delivery.destinationBranchName != null
                            ? 'សាខាគោលដៅ៖ ${_delivery.destinationBranchName}'
                            : _delivery.customerName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple.shade900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              useSafeArea: true,
                              builder: (context) => AttedanceBottomSheet(),
                            );
                          },
                          icon: const Icon(Icons.fingerprint_rounded, size: 20),
                          label: const Text(
                            'ស្កែនវត្តមាននៅសាខាគោលដៅ',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Customer Contact Box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.cardBackground,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: theme.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.blue,
                          child:
                              Icon(Icons.person, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _delivery.customerName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: theme.text,
                                ),
                              ),
                              Text(
                                _delivery.customerPhone,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: theme.mutedText,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _callCustomer,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          icon: const Icon(Icons.phone, size: 16),
                          label: const Text('ខល',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    if (_delivery.destinationAddress != null &&
                        _delivery.destinationAddress!.isNotEmpty) ...[
                      const Divider(height: 24),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.location_on,
                              color: Colors.red, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _delivery.destinationAddress!,
                              style: TextStyle(
                                fontSize: 13,
                                color: theme.text,
                                height: 1.3,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _openGoogleMaps,
                            icon: const Icon(Icons.map, size: 16),
                            label: const Text('Maps',
                                style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ],
                    if (_delivery.productPhotoUrls.isNotEmpty) ...[
                      const Divider(height: 24),
                      Text(
                        'រូបភាពផលិតផល (${_delivery.productPhotoUrls.length})',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: theme.text,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 64,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _delivery.productPhotoUrls.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, idx) {
                            final url = _delivery.productPhotoUrls[idx];
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                url,
                                width: 64,
                                height: 64,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 64,
                                  height: 64,
                                  color: Colors.grey.shade200,
                                  child:
                                      const Icon(Icons.broken_image, size: 24),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Live Tracking Link Card (for sharing to customer)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.share_location_rounded,
                            color: Colors.amber.shade900, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'តំណភ្ជាប់ផ្ញើជូនអតិថិជន (Live Tracking)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _delivery.trackingUrl ??
                          'https://.../track/live/${_delivery.trackingToken}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade800,
                        decoration: TextDecoration.underline,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _copyTrackingLink,
                            icon: const Icon(Icons.copy_rounded, size: 16),
                            label: const Text('ចម្លង Link'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.blue.shade800,
                              side: BorderSide(color: Colors.blue.shade300),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _shareToTelegram,
                            icon: const Icon(Icons.send_rounded, size: 16),
                            label: const Text('ផ្ញើ Telegram'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF229ED9),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Order Metadata
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.cardBackground,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: theme.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ព័ត៌មានបន្ថែមនៃការដឹកជញ្ជូន',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    _metaRow(
                      'ប្រភេទការដឹក',
                      _delivery.deliveryType == 'branch'
                          ? 'ដឹកតាមសាខា (Branch)'
                          : 'ដឹកជូនអតិថិជន (Customer)',
                      theme,
                    ),
                    if (_delivery.destinationBranchName != null &&
                        _delivery.destinationBranchName!.isNotEmpty)
                      _metaRow(
                          'សាខាគោលដៅ', _delivery.destinationBranchName!, theme),
                    _metaRow('លេខកូដដឹក', _delivery.trackingCode, theme),
                    if (_delivery.invoiceNumber != null &&
                        _delivery.invoiceNumber!.isNotEmpty)
                      _metaRow(
                          'លេខវិក្កយបត្រ', _delivery.invoiceNumber!, theme),
                    if (_delivery.notes != null && _delivery.notes!.isNotEmpty)
                      _metaRow('កំណត់ចំណាំ', _delivery.notes!, theme),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Complete Delivery Action
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isActionInProgress ? null : _showCompleteSheet,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 2,
                  ),
                  icon: const Icon(Icons.check_circle_outline, size: 22),
                  label: const Text(
                    'បញ្ចប់ការដឹកជញ្ជូន (Complete Delivery)',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metaRow(String label, String value, EnterpriseTheme theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12.5, color: theme.mutedText)),
          Text(value,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: theme.text)),
        ],
      ),
    );
  }
}
