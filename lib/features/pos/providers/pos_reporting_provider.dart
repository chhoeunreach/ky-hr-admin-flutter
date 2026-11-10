import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../models/pos_report.dart';
import '../services/pos_reporting_repository.dart';

class PosReportingProvider extends ChangeNotifier {
  PosReportingProvider(
      {PosReportingRepository? repository, String initialModule = 'dashboard'})
      : repository = repository ?? ApiPosReportingRepository(),
        destination = initialModule,
        filters = PosFilters.today(
            type: initialModule == 'dashboard' ? 'all' : initialModule);
  final PosReportingRepository repository;
  PosFilters filters;
  String destination;
  PosReport? report;
  bool loading = true;
  String? errorKey;
  Timer? _debounce;
  int _generation = 0;
  bool _disposed = false;
  int get requestRevision => _generation;

  static String failureKey(Object error) {
    if (error is FormatException) return 'server_update_required';
    if (error is DioException) {
      if (error.response?.statusCode == 401) return 'session_expired';
      if (error.response?.statusCode == 403) return 'access_denied';
      if (error.response?.statusCode == 422) return 'invalid_filters';
    }
    return 'load_error';
  }

  Future<void> refresh() async {
    _debounce?.cancel();
    final generation = ++_generation;
    loading = true;
    errorKey = null;
    notifyListeners();
    try {
      final value = await repository.load(filters);
      if (_disposed || generation != _generation) return;
      report = value;
      if (filters.page != value.page || filters.perPage != value.perPage) {
        filters = filters.copyWith(page: value.page, perPage: value.perPage);
      }
      if (filters.commissionMode != value.effectiveCommissionMode) {
        filters =
            filters.copyWith(commissionMode: value.effectiveCommissionMode);
      }
      loading = false;
      notifyListeners();
    } catch (error) {
      if (_disposed || generation != _generation) return;
      loading = false;
      errorKey = failureKey(error);
      if (errorKey == 'session_expired' || errorKey == 'access_denied')
        report = null;
      notifyListeners();
    }
  }

  Future<void> update(PosFilters value, {bool debounce = false}) {
    _debounce?.cancel();
    ++_generation;
    filters = value;
    if (debounce) {
      loading = true;
      errorKey = null;
      notifyListeners();
      _debounce =
          Timer(const Duration(milliseconds: 350), () => unawaited(refresh()));
      return Future.value();
    } else {
      return refresh();
    }
  }

  void search(String value) =>
      update(filters.copyWith(search: value, page: 1), debounce: true);
  void navigate(String module) {
    if (module != 'dashboard' && !(report?.modules.contains(module) ?? false))
      return;
    destination = module;
    update(filters.copyWith(
        type: module == 'dashboard' ? 'all' : module,
        status: 'all',
        search: '',
        page: 1));
  }

  Future<void> page(int value) async {
    if (loading || value < 1 || value > (report?.lastPage ?? 1)) return;
    await update(filters.copyWith(page: value));
  }

  void reset() => update(
      PosFilters.today(type: destination == 'dashboard' ? 'all' : destination));

  void period(String preset) {
    final now = DateUtils.dateOnly(DateTime.now());
    DateTime start = now, end = now;
    switch (preset) {
      case 'yesterday':
        start = DateTime(now.year, now.month, now.day - 1);
        end = start;
      case 'last_7_days':
        start = DateTime(now.year, now.month, now.day - 6);
      case 'last_30_days':
        start = DateTime(now.year, now.month, now.day - 29);
      case 'this_month':
        start = DateTime(now.year, now.month);
        end = DateTime(now.year, now.month + 1, 0);
      case 'last_month':
        start = DateTime(now.year, now.month - 1);
        end = DateTime(now.year, now.month, 0);
      case 'this_year':
        start = DateTime(now.year);
        end = DateTime(now.year, 12, 31);
      case 'three_months':
        start = DateTime(now.year, now.month - 2, 1);
    }
    update(filters.copyWith(from: start, to: end, page: 1, bucket: ''));
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    _debounce?.cancel();
    super.dispose();
  }
}
