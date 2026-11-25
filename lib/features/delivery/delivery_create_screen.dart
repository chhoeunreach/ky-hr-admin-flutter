import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

import 'package:cnattendance/theme/enterprise_theme.dart';
import 'delivery_api.dart';
import 'delivery_tracker_service.dart';
import 'active_delivery_screen.dart';

class DeliveryCreateScreen extends StatefulWidget {
  const DeliveryCreateScreen({super.key});

  @override
  State<DeliveryCreateScreen> createState() => _DeliveryCreateScreenState();
}

class _DeliveryCreateScreenState extends State<DeliveryCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api = DeliveryApi();
  final _imagePicker = ImagePicker();
  static const _maxProductPhotos = 5;
  final List<XFile> _productPhotos = [];
  XFile? _driverSelfie;

  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _invoiceNumberController = TextEditingController();
  final _destinationAddressController = TextEditingController();
  final _notesController = TextEditingController();

  String _deliveryType = 'customer'; // 'customer' or 'branch'
  List<Map<String, dynamic>> _branches = [];
  int? _selectedBranchId;
  double? _destinationLatitude;
  double? _destinationLongitude;

  bool _isGeneralCustomer = true;
  Position? _currentPosition;
  bool _isLoadingGps = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _customerNameController.text = 'អតិថិជនទូទៅ (General Customer)';
    _refreshInvoiceNumber();
    _fetchGps();
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    try {
      final list = await _api.getBranches();
      if (mounted) {
        setState(() {
          _branches = list;
        });
      }
    } catch (_) {}
  }

  void _onSelectBranch(int? branchId) {
    setState(() {
      _selectedBranchId = branchId;
      if (branchId != null) {
        final branch = _branches.firstWhere(
          (b) => b['id'] == branchId,
          orElse: () => <String, dynamic>{},
        );
        if (branch.isNotEmpty) {
          final bName = branch['name']?.toString() ?? '';
          _customerNameController.text = 'សាខា $bName';
          final bAddr = branch['address']?.toString() ?? '';
          if (bAddr.isNotEmpty) {
            _destinationAddressController.text = bAddr;
          }
          if (branch['latitude'] != null) {
            _destinationLatitude = double.tryParse('${branch['latitude']}');
          }
          if (branch['longitude'] != null) {
            _destinationLongitude = double.tryParse('${branch['longitude']}');
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _invoiceNumberController.dispose();
    _destinationAddressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _refreshInvoiceNumber() {
    final now = DateTime.now();
    final dateStr = DateFormat('yyMMdd').format(now);
    final rand = 1000 + Random().nextInt(9000);
    setState(() {
      _invoiceNumberController.text = 'INV-$dateStr-$rand';
    });
  }

  void _setCustomerType(bool isGeneral) {
    setState(() {
      _isGeneralCustomer = isGeneral;
      if (isGeneral) {
        _customerNameController.text = 'អតិថិជនទូទៅ (General Customer)';
      } else {
        if (_customerNameController.text == 'អតិថិជនទូទៅ (General Customer)') {
          _customerNameController.clear();
        }
      }
    });
  }

  Future<void> _fetchGps() async {
    setState(() => _isLoadingGps = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 7),
          ),
        );
        if (mounted) {
          setState(() {
            _currentPosition = pos;
            _isLoadingGps = false;
          });
        }
        return;
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _isLoadingGps = false);
    }
  }

  Future<void> _submitStart() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;
    if (_driverSelfie == null) {
      setState(() => _isSubmitting = true);
      await _takeDriverSelfie();
      if (!mounted) return;
      if (_driverSelfie == null) {
        setState(() => _isSubmitting = false);
        return;
      }
    }

    setState(() => _isSubmitting = true);
    try {
      final activeDelivery = await _api.getActiveDelivery();
      if (activeDelivery != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'មានការដឹកជញ្ជូនកំពុងដំណើរការ។ សូមបញ្ចប់វាមុនសិន។',
            ),
          ),
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ActiveDeliveryScreen(delivery: activeDelivery),
          ),
        );
        return;
      }

      final customerName = _deliveryType == 'branch'
          ? (_customerNameController.text.trim().isNotEmpty
              ? _customerNameController.text.trim()
              : 'សាខា (Branch Transfer)')
          : (_isGeneralCustomer
              ? 'អតិថិជនទូទៅ (General Customer)'
              : (_customerNameController.text.trim().isNotEmpty
                  ? _customerNameController.text.trim()
                  : 'អតិថិជនទូទៅ (General Customer)'));

      final delivery = await _api.startDelivery(
        driverSelfie: _driverSelfie!,
        productPhotos: _productPhotos,
        deliveryType: _deliveryType,
        destinationBranchId:
            _deliveryType == 'branch' ? _selectedBranchId : null,
        destinationLatitude: _destinationLatitude,
        destinationLongitude: _destinationLongitude,
        customerName: customerName,
        customerPhone: _customerPhoneController.text.trim(),
        invoiceNumber: _invoiceNumberController.text.trim().isNotEmpty
            ? _invoiceNumberController.text.trim()
            : null,
        destinationAddress: _destinationAddressController.text.trim().isNotEmpty
            ? _destinationAddressController.text.trim()
            : null,
        originLatitude: _currentPosition?.latitude,
        originLongitude: _currentPosition?.longitude,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
      );

      // Start automatic GPS tracking
      await DeliveryTrackerService.instance.startTracking(delivery.id);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ActiveDeliveryScreen(delivery: delivery),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _takeDriverSelfie() async {
    final photo = await _imagePicker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 80,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (photo != null && mounted) setState(() => _driverSelfie = photo);
  }

  Future<void> _addProductPhotos({required bool fromCamera}) async {
    final remaining = _maxProductPhotos - _productPhotos.length;
    if (remaining <= 0) return;
    if (fromCamera) {
      final photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 75,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (photo != null && mounted) {
        setState(() => _productPhotos.add(photo));
      }
      return;
    }
    final photos = await _imagePicker.pickMultiImage(
      imageQuality: 75,
      maxWidth: 1600,
      maxHeight: 1600,
      limit: remaining,
    );
    if (photos.isNotEmpty && mounted) {
      setState(() => _productPhotos.addAll(photos.take(remaining)));
    }
  }

  Widget _buildProductPhotosSection(EnterpriseTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.photo_camera_back_outlined, color: theme.primary),
            const SizedBox(width: 8),
            Text(
              'រូបភាពមុនចេញដឹក',
              style: TextStyle(
                color: theme.text,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'រូបភាពផលិតផល (អាចបន្ថែមរហូតដល់ $_maxProductPhotos សន្លឹក)',
          style: TextStyle(
            color: theme.text,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _productPhotos.length >= _maxProductPhotos
                  ? null
                  : () => _addProductPhotos(fromCamera: true),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              icon: const Icon(Icons.camera_alt_outlined, size: 18),
              label: const Text('ថតរូប'),
            ),
            OutlinedButton.icon(
              onPressed: _productPhotos.length >= _maxProductPhotos
                  ? null
                  : () => _addProductPhotos(fromCamera: false),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              icon: const Icon(Icons.photo_library_outlined, size: 18),
              label: const Text('ជ្រើសរូប'),
            ),
          ],
        ),
        if (_productPhotos.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _productPhotos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) => Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      File(_productPhotos[index].path),
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: -7,
                    right: -7,
                    child: IconButton.filledTonal(
                      tooltip: 'លុបរូប',
                      onPressed: () => setState(
                        () => _productPhotos.removeAt(index),
                      ),
                      visualDensity: VisualDensity.compact,
                      iconSize: 16,
                      constraints:
                          const BoxConstraints.tightFor(width: 28, height: 28),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = EnterpriseTheme.of(context);
    final surface = theme.contentSurface;
    final primary = theme.primary;
    final cardBg = theme.cardBackground;
    final cardBorder = theme.cardBorder;

    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        title: const Text(
          'ចេញដឹកជញ្ជូនថ្មី (New Delivery)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        elevation: 0.5,
      ),
      body: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 8),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(10),
          child: Theme(
            data: Theme.of(context).copyWith(
              inputDecorationTheme:
                  Theme.of(context).inputDecorationTheme.copyWith(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        prefixIconConstraints:
                            const BoxConstraints(minWidth: 40, minHeight: 40),
                        suffixIconConstraints:
                            const BoxConstraints(minWidth: 40, minHeight: 40),
                      ),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Collapsed by default; expand for the tracking-link note.
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.blue.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        dividerColor: Colors.transparent,
                      ),
                      child: ExpansionTile(
                        initiallyExpanded: false,
                        visualDensity: VisualDensity.compact,
                        tilePadding: const EdgeInsets.symmetric(horizontal: 10),
                        childrenPadding:
                            const EdgeInsets.fromLTRB(40, 0, 10, 10),
                        leading: const Icon(Icons.info_outline,
                            color: Colors.blue, size: 19),
                        title: Text(
                          'ព័ត៌មានអំពីការដឹកជញ្ជូន',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: theme.text,
                          ),
                        ),
                        children: [
                          Text(
                            'អតិថិជនអាចតាមដានទីតាំងដឹកជញ្ជូនតាម Link ផ្ទាល់ (Live GPS)។',
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.text.withValues(alpha: 0.85),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // GPS Status Pill
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _currentPosition != null
                          ? Colors.green.withValues(alpha: 0.08)
                          : Colors.orange.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _currentPosition != null
                            ? Colors.green.withValues(alpha: 0.25)
                            : Colors.orange.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _currentPosition != null
                              ? Icons.my_location
                              : Icons.location_searching,
                          size: 16,
                          color: _currentPosition != null
                              ? Colors.green
                              : Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _isLoadingGps
                                ? 'កំពុងចាប់ទីតាំង GPS...'
                                : (_currentPosition != null
                                    ? 'ចាប់ទីតាំងផ្ដើមចេញដំណើរបានជោគជ័យ'
                                    : 'មិនអាចចាប់ GPS បាន (អាចបន្តបាន)'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _currentPosition != null
                                  ? Colors.green.shade800
                                  : Colors.orange.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                // Delivery Type Toggle: Customer Delivery vs Branch Delivery
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: theme.cardBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.cardBorder),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() {
                            _deliveryType = 'customer';
                            if (_isGeneralCustomer) {
                              _customerNameController.text =
                                  'អតិថិជនទូទៅ (General Customer)';
                            }
                          }),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _deliveryType == 'customer'
                                  ? primary
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.person_pin_circle_outlined,
                                  size: 18,
                                  color: _deliveryType == 'customer'
                                      ? Colors.white
                                      : theme.mutedText,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'ដឹកជូនអតិថិជន',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: _deliveryType == 'customer'
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: _deliveryType == 'customer'
                                        ? Colors.white
                                        : theme.text,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() {
                            _deliveryType = 'branch';
                            if (_selectedBranchId != null) {
                              _onSelectBranch(_selectedBranchId);
                            } else {
                              _customerNameController.text =
                                  'ដឹកអីវ៉ាន់តាមសាខា (Branch Transfer)';
                            }
                          }),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _deliveryType == 'branch'
                                  ? primary
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.store_mall_directory_outlined,
                                  size: 18,
                                  color: _deliveryType == 'branch'
                                      ? Colors.white
                                      : theme.mutedText,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'ដឹកអីវ៉ាន់តាមសាខា',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: _deliveryType == 'branch'
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: _deliveryType == 'branch'
                                        ? Colors.white
                                        : theme.text,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Section 1: Customer Type & Info OR Branch Selection
                if (_deliveryType == 'branch')
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.business_rounded,
                                color: Colors.blue, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'ព័ត៌មានសាខាគោលដៅ (Destination Branch)',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<int>(
                          initialValue: _selectedBranchId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'ជ្រើសរើសសាខាគោលដៅ *',
                            prefixIcon: const Icon(Icons.storefront_outlined),
                            filled: true,
                            fillColor: cardBg,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: cardBorder),
                            ),
                          ),
                          items: _branches.map((b) {
                            return DropdownMenuItem<int>(
                              value: b['id'] as int,
                              child: Text(
                                b['name']?.toString() ?? 'សាខា',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: _onSelectBranch,
                          validator: (val) {
                            if (_deliveryType == 'branch' && val == null) {
                              return 'សូមជ្រើសរើសសាខាគោលដៅ';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.green.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.verified_user_outlined,
                                  size: 16, color: Colors.green),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '⚡ ពេលទៅដល់សាខានេះ បុគ្គលិកអាចស្កែនវត្តមានបានស្វ័យប្រវត្តិតាមរយៈ Geofence នៃសាខា។',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'លេខទូរស័ព្ទសាខា / អ្នកទទួល',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: theme.text,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  TextFormField(
                                    controller: _customerPhoneController,
                                    keyboardType: TextInputType.phone,
                                    decoration: InputDecoration(
                                      hintText: '012 345 678',
                                      prefixIcon:
                                          const Icon(Icons.phone_outlined),
                                      filled: true,
                                      fillColor: cardBg,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide:
                                            BorderSide(color: cardBorder),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'លេខកូដដឹក / វិក្កយបត្រ',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: theme.text,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  TextFormField(
                                    controller: _invoiceNumberController,
                                    decoration: InputDecoration(
                                      hintText: 'INV-261125-1234',
                                      suffixIcon: IconButton(
                                        tooltip: 'បង្កើតលេខកូដថ្មី',
                                        visualDensity: VisualDensity.compact,
                                        icon: const Icon(
                                          Icons.refresh_rounded,
                                          color: Colors.blue,
                                          size: 18,
                                        ),
                                        onPressed: _refreshInvoiceNumber,
                                      ),
                                      filled: true,
                                      fillColor: cardBg,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide:
                                            BorderSide(color: cardBorder),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.person_pin_rounded,
                                color: Colors.blue, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'ព័ត៌មានអតិថិជន (Customer)',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Quick Toggle: General Customer vs Specific Customer
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => _setCustomerType(true),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _isGeneralCustomer
                                        ? primary.withValues(alpha: 0.12)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: _isGeneralCustomer
                                          ? primary
                                          : cardBorder,
                                      width: _isGeneralCustomer ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.group_outlined,
                                        size: 18,
                                        color: _isGeneralCustomer
                                            ? primary
                                            : theme.mutedText,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'អតិថិជនទូទៅ',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: _isGeneralCustomer
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: _isGeneralCustomer
                                              ? primary
                                              : theme.text,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: InkWell(
                                onTap: () => _setCustomerType(false),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 6),
                                  decoration: BoxDecoration(
                                    color: !_isGeneralCustomer
                                        ? primary.withValues(alpha: 0.12)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: !_isGeneralCustomer
                                          ? primary
                                          : cardBorder,
                                      width: !_isGeneralCustomer ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.edit_note_rounded,
                                        size: 18,
                                        color: !_isGeneralCustomer
                                            ? primary
                                            : theme.mutedText,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'អតិថិជនជាក់លាក់',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: !_isGeneralCustomer
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: !_isGeneralCustomer
                                              ? primary
                                              : theme.text,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Customer Name field
                        Text(
                          _isGeneralCustomer
                              ? 'ឈ្មោះអតិថិជន'
                              : 'ឈ្មោះអ្នកទទួល / អតិថិជន *',
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: theme.text),
                        ),
                        const SizedBox(height: 3),
                        TextFormField(
                          controller: _customerNameController,
                          readOnly: _isGeneralCustomer,
                          validator: (val) {
                            if (!_isGeneralCustomer &&
                                (val == null || val.trim().isEmpty)) {
                              return 'សូមបញ្ចូលឈ្មោះអតិថិជន';
                            }
                            return null;
                          },
                          decoration: InputDecoration(
                            hintText: _isGeneralCustomer
                              ? 'អតិថិជនទូទៅ (General Customer)'
                              : 'ឧ. លោក សុខា',
                            prefixIcon: const Icon(Icons.person_outline),
                            filled: true,
                            fillColor: _isGeneralCustomer
                                ? theme.surface.withValues(alpha: 0.5)
                                : cardBg,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: cardBorder),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _isGeneralCustomer
                                        ? 'លេខទូរស័ព្ទ'
                                        : 'លេខទូរស័ព្ទអតិថិជន',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: theme.text,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  TextFormField(
                                    controller: _customerPhoneController,
                                    keyboardType: TextInputType.phone,
                                    decoration: InputDecoration(
                                      hintText: '012 345 678',
                                      prefixIcon:
                                          const Icon(Icons.phone_outlined),
                                      filled: true,
                                      fillColor: cardBg,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide:
                                            BorderSide(color: cardBorder),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'វិក្កយបត្រ',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: theme.text,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  TextFormField(
                                    controller: _invoiceNumberController,
                                    decoration: InputDecoration(
                                      hintText: 'INV-261125-1234',
                                      suffixIcon: IconButton(
                                        tooltip: 'បង្កើតលេខកូដថ្មី',
                                        visualDensity: VisualDensity.compact,
                                        icon: const Icon(
                                          Icons.refresh_rounded,
                                          color: Colors.blue,
                                          size: 18,
                                        ),
                                        onPressed: _refreshInvoiceNumber,
                                      ),
                                      filled: true,
                                      fillColor: cardBg,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide:
                                            BorderSide(color: cardBorder),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Section 2: Destination, notes, and product photos
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Destination Address
                        Text(
                          'អាសយដ្ឋានដឹកជញ្ជូន',
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: theme.text),
                        ),
                        const SizedBox(height: 4),
                        TextFormField(
                          controller: _destinationAddressController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            hintText:
                                'ឧ. ផ្ទះលេខ 12A, ផ្លូវ 271, សង្កាត់បឹងទំពុន...',
                            prefixIcon: const Padding(
                              padding: EdgeInsets.only(bottom: 24),
                              child: Icon(Icons.location_on_outlined),
                            ),
                            filled: true,
                            fillColor: cardBg,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: cardBorder),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Notes
                        Text(
                          'កំណត់ចំណាំផ្សេងៗ',
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: theme.text),
                        ),
                        const SizedBox(height: 4),
                        TextFormField(
                          controller: _notesController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            hintText: 'ឧ. ហៅទូរស័ព្ទមុនទៅដល់ ៥នាទី...',
                            prefixIcon: const Padding(
                              padding: EdgeInsets.only(bottom: 24),
                              child: Icon(Icons.note_alt_outlined),
                            ),
                            filled: true,
                            fillColor: cardBg,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: cardBorder),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Divider(height: 1),
                        const SizedBox(height: 10),
                        _buildProductPhotosSection(theme),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Start Delivery Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _submitStart,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 2,
                      ),
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.two_wheeler_rounded, size: 24),
                      label: Text(
                        _isSubmitting
                            ? 'កំពុងបង្កើត...'
                            : 'ចាប់ផ្តើមចេញដឹក (Start Delivery)',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
