import '../models/repair_brand.dart';
import '../models/repair_category.dart';
import '../models/repair_device.dart';
import '../models/repair_service.dart';
import '../services/repair_price_api_service.dart';

class RepairPriceRepository {
  final RepairPriceApiService _apiService;

  RepairPriceRepository({RepairPriceApiService? apiService})
      : _apiService = apiService ?? RepairPriceApiService();

  Future<List<RepairBrand>> fetchBrands() async {
    return await _apiService.getBrands();
  }

  Future<List<RepairDeviceType>> fetchDeviceTypes() async {
    return await _apiService.getDeviceTypes();
  }

  Future<RepairDeviceType> createDeviceType(Map<String, dynamic> data) async {
    return await _apiService.createDeviceType(data);
  }

  Future<List<RepairDeviceSeries>> fetchSeries({
    int? brandId,
    int? deviceTypeId,
  }) async {
    return await _apiService.getSeries(
      brandId: brandId,
      deviceTypeId: deviceTypeId,
    );
  }

  Future<List<RepairDevice>> fetchDevices({
    String? search,
    int? brandId,
    int? deviceTypeId,
    int? seriesId,
    int page = 1,
    int perPage = 20,
  }) async {
    return await _apiService.getDevices(
      search: search,
      brandId: brandId,
      deviceTypeId: deviceTypeId,
      seriesId: seriesId,
      page: page,
      perPage: perPage,
    );
  }

  Future<RepairDevice> fetchDevice(int id) async {
    return await _apiService.getDevice(id);
  }

  Future<List<RepairService>> fetchDeviceServices(
    int deviceId, {
    String? search,
    int? categoryId,
  }) async {
    return await _apiService.getDeviceServices(
      deviceId,
      search: search,
      categoryId: categoryId,
    );
  }

  Future<List<RepairCategory>> fetchCategories() async {
    return await _apiService.getCategories();
  }

  Future<List<RepairService>> fetchServices({
    String? search,
    int? categoryId,
  }) async {
    return await _apiService.getAllServices(
      search: search,
      categoryId: categoryId,
    );
  }

  Future<List<RepairDevice>> searchDevices(String query) async {
    return await _apiService.searchDevices(query);
  }

  Future<Map<String, dynamic>?> fetchPermissions() async {
    return await _apiService.getPermissions();
  }

  Future<RepairService> updatePrice({
    required int priceId,
    required int deviceId,
    required RepairService service,
  }) async {
    return await _apiService.updatePrice(
      priceId: priceId,
      deviceId: deviceId,
      service: service,
    );
  }

  // Brand CRUD
  Future<RepairBrand> createBrand(Map<String, dynamic> data) async {
    return await _apiService.createBrand(data);
  }

  Future<RepairBrand> updateBrand(int id, Map<String, dynamic> data) async {
    return await _apiService.updateBrand(id, data);
  }

  Future<bool> deleteBrand(int id) async {
    return await _apiService.deleteBrand(id);
  }

  // Device CRUD
  Future<RepairDevice> createDevice(Map<String, dynamic> data) async {
    return await _apiService.createDevice(data);
  }

  Future<RepairDevice> updateDevice(int id, Map<String, dynamic> data) async {
    return await _apiService.updateDevice(id, data);
  }

  Future<bool> deleteDevice(int id) async {
    return await _apiService.deleteDevice(id);
  }

  // Category CRUD
  Future<RepairCategory> createCategory(Map<String, dynamic> data) async {
    return await _apiService.createCategory(data);
  }

  Future<RepairCategory> updateCategory(
      int id, Map<String, dynamic> data) async {
    return await _apiService.updateCategory(id, data);
  }

  Future<bool> deleteCategory(int id) async {
    return await _apiService.deleteCategory(id);
  }
}
