import 'package:cnattendance/services/sell_out_api_service.dart';
import '../models/pos_report.dart';

abstract class PosReportingRepository {
  Future<PosReport> load(PosFilters filters);
  Future<List<int>> export(PosFilters filters);
}

class ApiPosReportingRepository implements PosReportingRepository {
  ApiPosReportingRepository({SellOutApiService? api})
      : _api = api ?? SellOutApiService();
  final SellOutApiService _api;
  @override
  Future<PosReport> load(PosFilters filters) => _api.fetchReporting(filters);
  @override
  Future<List<int>> export(PosFilters filters) => _api.exportReporting(filters);
}
