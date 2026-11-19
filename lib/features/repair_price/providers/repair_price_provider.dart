import 'dart:async';
import 'package:flutter/foundation.dart';
import '../config/repair_price_config.dart';
import '../models/repair_brand.dart';
import '../models/repair_category.dart';
import '../models/repair_device.dart';
import '../models/repair_service.dart';
import '../repositories/repair_price_repository.dart';
import '../services/repair_price_api_service.dart';

enum RepairLoadingState {
  initial,
  loading,
  loaded,
  empty,
  error,
  unauthorized,
  forbidden
}

class RepairPriceProvider extends ChangeNotifier {
  final RepairPriceRepository _repository;
  Map<String, dynamic> _permissions = const {};
  bool _checkingPermissions = false;
  bool _disposed = false;

  RepairPriceProvider({RepairPriceRepository? repository})
      : _repository = repository ?? RepairPriceRepository();

  String? get backendRoleName => _permissions['role_name']?.toString();

  bool get canView => !_checkingPermissions && _permissions['can_view'] == true;
  bool get canViewCost => canView && _permissions['can_view_cost'] == true;
  bool get canManageDevices =>
      canView && _permissions['can_manage_devices'] == true;
  bool get canManageServices =>
      canView && _permissions['can_manage_services'] == true;
  bool get canManagePrices =>
      canView && _permissions['can_manage_prices'] == true;
  bool get canCreatePrices =>
      canView && _permissions['can_create_prices'] == true;
  bool get canUpdatePrices =>
      canView && _permissions['can_update_prices'] == true;
  bool get canDeletePrices =>
      canView && _permissions['can_delete_prices'] == true;

  bool canEditServicePrice(RepairService service) =>
      canUpdatePrices &&
      canViewCost &&
      service.partCost != null &&
      service.serviceFee != null &&
      (service.repairPriceId ?? 0) > 0;

  /// Loads the permissions for the current authenticated repair session.
  Future<void> loadWebPermissions() async {
    _checkingPermissions = true;
    try {
      _permissions = await _repository.fetchPermissions() ?? const {};
      _checkingPermissions = false;
      if (_disposed) return;
      if (!canView) _deviceLoadingState = RepairLoadingState.forbidden;
    } catch (error) {
      _permissions = const {};
      _checkingPermissions = false;
      if (_disposed) return;
      _deviceLoadingState = _stateForError(error);
      _deviceErrorMessage = _messageForError(error);
    }
    notifyListeners();
  }

  // --- Page 2: Device / Model Selection State ---
  RepairLoadingState _deviceLoadingState = RepairLoadingState.initial;
  RepairLoadingState get deviceLoadingState => _deviceLoadingState;

  String? _deviceErrorMessage;
  String? get deviceErrorMessage => _deviceErrorMessage;

  List<RepairBrand> _brands = [];
  List<RepairBrand> get brands => _brands;

  List<RepairDeviceType> _deviceTypes = [];
  List<RepairDeviceType> get deviceTypes => _deviceTypes;

  List<RepairDeviceSeries> _series = [];
  List<RepairDeviceSeries> get series => _series;

  List<RepairDevice> _devices = [];
  List<RepairDevice> get devices => _devices;

  int? _selectedBrandId;
  int? get selectedBrandId => _selectedBrandId;

  int? _selectedDeviceTypeId;
  int? get selectedDeviceTypeId => _selectedDeviceTypeId;

  int? _selectedSeriesId;
  int? get selectedSeriesId => _selectedSeriesId;

  String _deviceSearchQuery = '';
  String get deviceSearchQuery => _deviceSearchQuery;

  int _devicePage = 1;
  bool _hasMoreDevices = true;
  bool get hasMoreDevices => _hasMoreDevices;

  bool _isLoadingMoreDevices = false;
  bool get isLoadingMoreDevices => _isLoadingMoreDevices;

  Timer? _searchDebounceTimer;

  // --- Page 3: Repair Price Detail State ---
  RepairDevice? _selectedDevice;
  RepairDevice? get selectedDevice => _selectedDevice;

  RepairLoadingState _serviceLoadingState = RepairLoadingState.initial;
  RepairLoadingState get serviceLoadingState => _serviceLoadingState;
  int _serviceRequest = 0;

  String? _serviceErrorMessage;
  String? get serviceErrorMessage => _serviceErrorMessage;

  List<RepairCategory> _categories = [];
  List<RepairCategory> get categories => _categories;

  List<RepairService> _services = [];
  List<RepairService> get services => _services;

  int? _selectedCategoryId;
  int? get selectedCategoryId => _selectedCategoryId;

  String _serviceSearchQuery = '';
  String get serviceSearchQuery => _serviceSearchQuery;

  RepairService? _selectedService;
  RepairService? get selectedService => _selectedService;

  // --- Page 2 Actions ---

  Future<void> initDevicePage() async {
    if (_deviceLoadingState == RepairLoadingState.loading) return;
    _deviceLoadingState = RepairLoadingState.loading;
    _deviceErrorMessage = null;
    notifyListeners();

    await loadWebPermissions();
    if (_disposed || !canView) return;

    _devicePage = 1;
    _hasMoreDevices = true;

    try {
      final results = await Future.wait([
        _repository.fetchBrands(),
        _repository.fetchDeviceTypes(),
        _repository.fetchSeries(
          brandId: _selectedBrandId,
          deviceTypeId: _selectedDeviceTypeId,
        ),
        _repository.fetchDevices(
          search: _deviceSearchQuery,
          brandId: _selectedBrandId,
          deviceTypeId: _selectedDeviceTypeId,
          seriesId: _selectedSeriesId,
          page: 1,
          perPage: RepairPriceConfig.pageSize,
        ),
      ]);

      _brands = results[0] as List<RepairBrand>;
      _deviceTypes = results[1] as List<RepairDeviceType>;
      _series = results[2] as List<RepairDeviceSeries>;
      _devices = results[3] as List<RepairDevice>;

      _hasMoreDevices = _devices.length >= RepairPriceConfig.pageSize;
      _deviceLoadingState = _devices.isEmpty
          ? RepairLoadingState.empty
          : RepairLoadingState.loaded;
    } catch (e) {
      _deviceErrorMessage = _messageForError(e);
      _deviceLoadingState = _stateForError(e);
    }

    notifyListeners();
  }

  void onDeviceSearchChanged(String query) {
    _deviceSearchQuery = query;
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      loadDevices();
    });
  }

  void selectBrand(int? brandId) {
    if (_selectedBrandId == brandId) {
      _selectedBrandId = null;
    } else {
      _selectedBrandId = brandId;
    }
    _selectedSeriesId = null;
    _reloadSeriesAndDevices();
  }

  void selectDeviceType(int? deviceTypeId) {
    if (_selectedDeviceTypeId == deviceTypeId) {
      _selectedDeviceTypeId = null;
    } else {
      _selectedDeviceTypeId = deviceTypeId;
    }
    _selectedSeriesId = null;
    _reloadSeriesAndDevices();
  }

  void selectSeries(int? seriesId) {
    if (_selectedSeriesId == seriesId) {
      _selectedSeriesId = null;
    } else {
      _selectedSeriesId = seriesId;
    }
    loadDevices();
  }

  Future<void> _reloadSeriesAndDevices() async {
    try {
      _series = await _repository.fetchSeries(
        brandId: _selectedBrandId,
        deviceTypeId: _selectedDeviceTypeId,
      );
    } catch (_) {}
    loadDevices();
  }

  Future<void> loadDevices() async {
    if (!canView) {
      _deviceLoadingState = RepairLoadingState.forbidden;
      notifyListeners();
      return;
    }

    _deviceLoadingState = RepairLoadingState.loading;
    _deviceErrorMessage = null;
    _devicePage = 1;
    _hasMoreDevices = true;
    notifyListeners();

    try {
      _devices = await _repository.fetchDevices(
        search: _deviceSearchQuery,
        brandId: _selectedBrandId,
        deviceTypeId: _selectedDeviceTypeId,
        seriesId: _selectedSeriesId,
        page: 1,
        perPage: RepairPriceConfig.pageSize,
      );
      _hasMoreDevices = _devices.length >= RepairPriceConfig.pageSize;
      _deviceLoadingState = _devices.isEmpty
          ? RepairLoadingState.empty
          : RepairLoadingState.loaded;
    } catch (e) {
      _deviceErrorMessage = _messageForError(e);
      _deviceLoadingState = _stateForError(e);
    }

    notifyListeners();
  }

  Future<void> loadMoreDevices() async {
    if (_isLoadingMoreDevices ||
        !_hasMoreDevices ||
        _deviceLoadingState != RepairLoadingState.loaded) {
      return;
    }

    _isLoadingMoreDevices = true;
    notifyListeners();

    try {
      final nextPage = _devicePage + 1;
      final newDevices = await _repository.fetchDevices(
        search: _deviceSearchQuery,
        brandId: _selectedBrandId,
        deviceTypeId: _selectedDeviceTypeId,
        seriesId: _selectedSeriesId,
        page: nextPage,
        perPage: RepairPriceConfig.pageSize,
      );

      if (newDevices.isEmpty) {
        _hasMoreDevices = false;
      } else {
        _devicePage = nextPage;
        _devices.addAll(newDevices);
        _hasMoreDevices = newDevices.length >= RepairPriceConfig.pageSize;
      }
    } catch (_) {
      _hasMoreDevices = false;
    }

    _isLoadingMoreDevices = false;
    notifyListeners();
  }

  // --- Role Management Actions (Admin / Manager) ---

  // --- Brand Management Actions ---
  Future<RepairBrand> addBrand(RepairBrand brand) async {
    try {
      final created = await _repository.createBrand(brand.toJson());
      _brands.insert(0, created);
      notifyListeners();
      return created;
    } catch (e) {
      if (kDebugMode) print('addBrand error: $e');
      _brands.insert(0, brand);
      notifyListeners();
      return brand;
    }
  }

  // --- Device Type Management Actions ---
  Future<RepairDeviceType> addDeviceType(RepairDeviceType type) async {
    try {
      final created = await _repository.createDeviceType(type.toJson());
      _deviceTypes.add(created);
      notifyListeners();
      return created;
    } catch (e) {
      if (kDebugMode) print('addDeviceType error: $e');
      _deviceTypes.add(type);
      notifyListeners();
      return type;
    }
  }

  Future<bool> updateBrand(RepairBrand brand) async {
    try {
      final updated = await _repository.updateBrand(brand.id, brand.toJson());
      final idx = _brands.indexWhere((b) => b.id == brand.id);
      if (idx != -1) {
        _brands[idx] = updated;
        notifyListeners();
      }
      return true;
    } catch (e) {
      if (kDebugMode) print('updateBrand error: $e');
      return false;
    }
  }

  Future<bool> deleteBrand(int brandId) async {
    try {
      await _repository.deleteBrand(brandId);
    } catch (e) {
      if (kDebugMode) print('deleteBrand error: $e');
      return false;
    }
    _brands = _brands.where((b) => b.id != brandId).toList();
    if (_selectedBrandId == brandId) {
      _selectedBrandId = null;
      loadDevices();
    } else {
      notifyListeners();
    }
    return true;
  }

  // --- Device Management Actions ---
  Future<bool> addDevice(RepairDevice device) async {
    if (!canManageDevices) return false;
    final brandId = device.brand?.id;
    final isDuplicate = _devices.any((d) =>
        d.brand?.id == brandId &&
        d.name.trim().toLowerCase() == device.name.trim().toLowerCase());
    if (isDuplicate) {
      if (kDebugMode) {
        print('addDevice error: Duplicate device model name for this brand');
      }
      return false;
    }

    try {
      final created = await _repository.createDevice(device.toJson());
      final finalDevice = created.brand == null && device.brand != null
          ? created.copyWith(
              brand: device.brand,
              deviceType: device.deviceType,
              series: device.series,
            )
          : created;
      _devices.insert(0, finalDevice);
      if (_deviceLoadingState == RepairLoadingState.empty) {
        _deviceLoadingState = RepairLoadingState.loaded;
      }
      notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) print('addDevice error: ');
      return false;
    }
  }

  Future<bool> updateDevice(RepairDevice device) async {
    if (!canManageDevices) return false;
    final brandId = device.brand?.id;
    final isDuplicate = _devices.any((d) =>
        d.brand?.id == brandId &&
        d.id != device.id &&
        d.name.trim().toLowerCase() == device.name.trim().toLowerCase());
    if (isDuplicate) {
      if (kDebugMode) {
        print('updateDevice error: Duplicate device model name for this brand');
      }
      return false;
    }

    try {
      final updated =
          await _repository.updateDevice(device.id, device.toJson());
      final finalDevice = updated.brand == null && device.brand != null
          ? updated.copyWith(
              brand: device.brand,
              deviceType: device.deviceType,
              series: device.series,
            )
          : updated;
      final idx = _devices.indexWhere((d) => d.id == device.id);
      if (idx != -1) {
        _devices[idx] = finalDevice;
        if (_selectedDevice?.id == device.id) {
          _selectedDevice = finalDevice;
        }
        notifyListeners();
      }
      return true;
    } catch (e) {
      if (kDebugMode) print('updateDevice error: ');
      return false;
    }
  }

  Future<bool> deleteDevice(int deviceId) async {
    if (!canManageDevices) return false;
    try {
      await _repository.deleteDevice(deviceId);
    } catch (e) {
      if (kDebugMode) print('deleteDevice error: $e');
      return false;
    }
    _devices = _devices.where((d) => d.id != deviceId).toList();
    if (_selectedDevice?.id == deviceId) {
      _selectedDevice = null;
    }
    if (_devices.isEmpty) {
      _deviceLoadingState = RepairLoadingState.empty;
    }
    notifyListeners();
    return true;
  }

  // --- Category Management Actions ---
  Future<bool> addCategory(RepairCategory category) async {
    try {
      final created = await _repository.createCategory(category.toJson());
      _categories.add(created);
      notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) print('addCategory error: $e');
      return false;
    }
  }

  Future<bool> updateCategory(RepairCategory category) async {
    try {
      final updated =
          await _repository.updateCategory(category.id, category.toJson());
      final idx = _categories.indexWhere((c) => c.id == category.id);
      if (idx != -1) {
        _categories[idx] = updated;
        notifyListeners();
      }
      return true;
    } catch (e) {
      if (kDebugMode) print('updateCategory error: $e');
      return false;
    }
  }

  Future<bool> deleteCategory(int categoryId) async {
    try {
      await _repository.deleteCategory(categoryId);
    } catch (e) {
      if (kDebugMode) print('deleteCategory error: $e');
      return false;
    }
    _categories = _categories.where((c) => c.id != categoryId).toList();
    if (_selectedCategoryId == categoryId) {
      _selectedCategoryId = null;
      loadServices();
    } else {
      notifyListeners();
    }
    return true;
  }

  void updateServicePrice(RepairService updatedService) {
    final idx =
        _services.indexWhere((s) => s.priceKey == updatedService.priceKey);
    if (idx != -1) {
      _services[idx] = updatedService;
      if (_selectedService?.priceKey == updatedService.priceKey) {
        _selectedService = updatedService;
      }
      notifyListeners();
    }
  }

  Future<void> saveServicePrice(RepairService updatedService) async {
    if (!canEditServicePrice(updatedService)) {
      throw const RepairApiException(
        'Mobile price editing requires permission to update prices and view their costs.',
        statusCode: 403,
      );
    }
    if (_selectedDevice == null) {
      throw const RepairApiException('No repair device selected');
    }
    final priceId = updatedService.repairPriceId;
    if (priceId == null || priceId <= 0) {
      throw const RepairApiException('Missing repair price id');
    }

    final saved = await _repository.updatePrice(
      priceId: priceId,
      deviceId: _selectedDevice!.id,
      service: updatedService,
    );
    updateServicePrice(saved);
  }

  // --- Page 3 Actions ---

  void setSelectedDevice(RepairDevice device) {
    _searchDebounceTimer?.cancel();
    _selectedDevice = device;
    _selectedCategoryId = null;
    _serviceSearchQuery = '';
    _selectedService = null;
    _services = [];
    _categories = [];
    _serviceLoadingState = RepairLoadingState.initial;
    notifyListeners();
    initServiceDetailPage();
  }

  Future<void> initServiceDetailPage() async {
    final device = _selectedDevice;
    if (device == null || _serviceLoadingState == RepairLoadingState.loading) {
      return;
    }
    final request = ++_serviceRequest;
    _serviceLoadingState = RepairLoadingState.loading;
    _serviceErrorMessage = null;
    notifyListeners();

    if (!canView) {
      await loadWebPermissions();
    }

    if (_disposed || request != _serviceRequest) return;
    if (!canView) {
      _serviceLoadingState = RepairLoadingState.forbidden;
      _serviceErrorMessage =
          'លោកអ្នកគ្មានសិទ្ធិចូលមើលតម្លៃជួសជុលទេ\nYou do not have permission to view repair prices';
      notifyListeners();
      return;
    }

    try {
      final results = await Future.wait([
        _repository.fetchCategories(),
        _repository.fetchDeviceServices(
          device.id,
          search: _serviceSearchQuery,
          categoryId: _selectedCategoryId,
        ),
      ]);

      if (_disposed || !identical(_selectedDevice, device)) return;
      _categories = results[0] as List<RepairCategory>;
      if (request != _serviceRequest) {
        notifyListeners();
        return;
      }
      _services = results[1] as List<RepairService>;

      if (_services.isNotEmpty && _selectedService == null) {
        _selectedService = _services.first;
      }

      _serviceLoadingState = _services.isEmpty
          ? RepairLoadingState.empty
          : RepairLoadingState.loaded;
    } catch (e) {
      if (_disposed || request != _serviceRequest) return;
      _serviceErrorMessage = _messageForError(e);
      _serviceLoadingState = _stateForError(e);
    }

    notifyListeners();
  }

  void onServiceSearchChanged(String query) {
    _serviceSearchQuery = query;
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      loadServices();
    });
  }

  void selectCategory(int? categoryId) {
    if (_selectedCategoryId == categoryId) {
      _selectedCategoryId = null;
    } else {
      _selectedCategoryId = categoryId;
    }
    loadServices();
  }

  void selectService(RepairService service) {
    _selectedService = service;
    notifyListeners();
  }

  Future<void> loadServices() async {
    final device = _selectedDevice;
    if (device == null || !canView) return;
    final request = ++_serviceRequest;

    _serviceLoadingState = RepairLoadingState.loading;
    _serviceErrorMessage = null;
    notifyListeners();

    try {
      final services = await _repository.fetchDeviceServices(
        device.id,
        search: _serviceSearchQuery,
        categoryId: _selectedCategoryId,
      );

      if (_disposed || request != _serviceRequest) return;
      _services = services;
      final selectedKey = _selectedService?.priceKey;
      final index =
          _services.indexWhere((service) => service.priceKey == selectedKey);
      _selectedService = index >= 0 ? _services[index] : _services.firstOrNull;

      _serviceLoadingState = _services.isEmpty
          ? RepairLoadingState.empty
          : RepairLoadingState.loaded;
    } catch (e) {
      if (_disposed || request != _serviceRequest) return;
      _serviceErrorMessage = _messageForError(e);
      _serviceLoadingState = _stateForError(e);
    }

    notifyListeners();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _searchDebounceTimer?.cancel();
    super.dispose();
  }

  RepairLoadingState _stateForError(Object error) {
    if (error is RepairApiException && error.isUnauthorized) {
      return RepairLoadingState.unauthorized;
    }
    if (error is RepairApiException && error.isForbidden) {
      return RepairLoadingState.forbidden;
    }
    return RepairLoadingState.error;
  }

  String _messageForError(Object error) {
    if (error is RepairApiException && error.isUnauthorized) {
      return 'សូមចូលគណនីដើម្បីមើលតម្លៃជួសជុល\nPlease login to view repair prices';
    }
    if (error is RepairApiException && error.isForbidden) {
      return 'លោកអ្នកគ្មានសិទ្ធិមើលតម្លៃជួសជុលទេ\nYou do not have permission to view repair prices';
    }
    return 'មានបញ្ហាក្នុងការទាញទិន្នន័យ\n($error)';
  }
}
