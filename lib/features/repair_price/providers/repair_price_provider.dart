import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';
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
  static final _storage = GetStorage();
  static const _canViewKey = 'repair_can_view';

  RepairPriceProvider({RepairPriceRepository? repository})
      : _repository = repository ?? RepairPriceRepository();

  // Permissions are server controlled. Initialize from local cache if available.
  bool _canView = _storage.read<bool>(_canViewKey) ?? false;
  bool _canViewCost = false;
  bool _canManageDevices = false;
  bool _canManageServices = false;
  bool _canManagePrices = false;
  bool _canCreatePrices = false;
  bool _canUpdatePrices = false;
  bool _canDeletePrices = false;

  String? _backendRoleName;
  String? get backendRoleName => _backendRoleName;

  bool get canView => _canView;
  bool get canViewCost => _canViewCost;
  bool get canManageDevices => _canManageDevices;
  bool get canManageServices => _canManageServices;
  bool get canManagePrices => _canManagePrices;
  bool get canCreatePrices => _canCreatePrices;
  bool get canUpdatePrices => _canUpdatePrices;
  bool get canDeletePrices => _canDeletePrices;

  /// Loads the logged-in user's role and permissions directly from the web backend
  Future<void> loadWebPermissions() async {
    try {
      final perms = await _repository.fetchPermissions();
      if (perms != null) {
        _backendRoleName = perms['role_name']?.toString();

        _canView = perms['can_view'] == true;
        _storage.write(_canViewKey, _canView);
        _canViewCost = perms['can_view_cost'] == true;
        _canManagePrices = perms['can_manage_prices'] == true;
        _canCreatePrices = perms['can_create_prices'] == true;
        _canUpdatePrices = perms['can_update_prices'] == true;
        _canDeletePrices = perms['can_delete_prices'] == true;
        _canManageDevices = perms['can_manage_devices'] == true;
        _canManageServices = perms['can_manage_services'] == true;

        notifyListeners();

        if (!_canView) {
          _deviceLoadingState = RepairLoadingState.forbidden;
          _deviceErrorMessage =
              'លោកអ្នកគ្មានសិទ្ធិចូលមើលតម្លៃជួសជុលទេ\nYou do not have permission to view repair prices';
        }
      }
    } catch (e) {
      _canView = false;
      _canViewCost = false;
      _canManagePrices = false;
      _canCreatePrices = false;
      _canUpdatePrices = false;
      _canDeletePrices = false;
      _canManageDevices = false;
      _canManageServices = false;
      _deviceLoadingState = _stateForError(e);
      _deviceErrorMessage = _messageForError(e);
      notifyListeners();
    }
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
    // 1. First fetch latest role & permissions configured on the web backend
    await loadWebPermissions();

    if (!canView) {
      _deviceLoadingState = RepairLoadingState.forbidden;
      _deviceErrorMessage =
          'លោកអ្នកគ្មានសិទ្ធិចូលមើលតម្លៃជួសជុលទេ\nYou do not have permission to view repair prices';
      notifyListeners();
      return;
    }

    _deviceLoadingState = RepairLoadingState.loading;
    _deviceErrorMessage = null;
    _devicePage = 1;
    _hasMoreDevices = true;
    notifyListeners();

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
    final idx = _services.indexWhere((s) => s.id == updatedService.id);
    if (idx != -1) {
      _services[idx] = updatedService;
      if (_selectedService?.id == updatedService.id) {
        _selectedService = updatedService;
      }
      notifyListeners();
    }
  }

  Future<void> saveServicePrice(RepairService updatedService) async {
    if (!canUpdatePrices) {
      throw const RepairApiException(
        'You do not have permission to update repair prices',
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
    _selectedDevice = device;
    _selectedCategoryId = null;
    _serviceSearchQuery = '';
    _selectedService = null;
    notifyListeners();
    initServiceDetailPage();
  }

  Future<void> initServiceDetailPage() async {
    if (_selectedDevice == null) return;

    if (!canView) {
      await loadWebPermissions();
    }

    if (!canView) {
      _serviceLoadingState = RepairLoadingState.forbidden;
      _serviceErrorMessage =
          'លោកអ្នកគ្មានសិទ្ធិចូលមើលតម្លៃជួសជុលទេ\nYou do not have permission to view repair prices';
      notifyListeners();
      return;
    }

    _serviceLoadingState = RepairLoadingState.loading;
    _serviceErrorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _repository.fetchCategories(),
        _repository.fetchDeviceServices(
          _selectedDevice!.id,
          search: _serviceSearchQuery,
          categoryId: _selectedCategoryId,
        ),
      ]);

      _categories = results[0] as List<RepairCategory>;
      _services = results[1] as List<RepairService>;

      if (_services.isNotEmpty && _selectedService == null) {
        _selectedService = _services.first;
      }

      _serviceLoadingState = _services.isEmpty
          ? RepairLoadingState.empty
          : RepairLoadingState.loaded;
    } catch (e) {
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
    if (_selectedDevice == null) return;

    _serviceLoadingState = RepairLoadingState.loading;
    _serviceErrorMessage = null;
    notifyListeners();

    try {
      _services = await _repository.fetchDeviceServices(
        _selectedDevice!.id,
        search: _serviceSearchQuery,
        categoryId: _selectedCategoryId,
      );

      if (_selectedService != null &&
          !_services.any((s) => s.id == _selectedService!.id)) {
        _selectedService = _services.isNotEmpty ? _services.first : null;
      }

      _serviceLoadingState = _services.isEmpty
          ? RepairLoadingState.empty
          : RepairLoadingState.loaded;
    } catch (e) {
      _serviceErrorMessage = _messageForError(e);
      _serviceLoadingState = _stateForError(e);
    }

    notifyListeners();
  }

  @override
  void dispose() {
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
