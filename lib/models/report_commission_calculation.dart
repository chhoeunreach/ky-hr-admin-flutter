import 'sell_out_report.dart';
import 'commission_policy.dart';

enum ReportCommissionMode { withConditions, withoutConditions }

/// Calculates a report preview across the entire filtered period, before status
/// tabs or pagination are applied. Saved invoice commission is not used here.
class ReportCommissionCalculation {
  ReportCommissionCalculation(Iterable<SellOutReport> reports,
      {this.mode = ReportCommissionMode.withConditions,
      CommissionPolicy? policy})
      : policy = policy ?? CommissionPolicy.defaults() {
    for (final report in reports) {
      final type = SellOutReport.canonicalServiceType(report.serviceType);
      final rule = this.policy.rules[type];
      if (rule != null &&
          (!rule.requirePhone || report.hasValidCustomerPhone)) {
        final key = _sellerKey(report);
        _sellQuantities[key] = (_sellQuantities[key] ?? 0) + report.totalQty;
      }
    }
  }

  final CommissionPolicy policy;
  final ReportCommissionMode mode;
  final Map<String, int> _sellQuantities = {};

  // The API supplies the current user's reports. Seller name/category also keep
  // separately named sellers and work categories from sharing a threshold.
  String _sellerKey(SellOutReport report) =>
      '${SellOutReport.canonicalServiceType(report.serviceType)}|${report.sellerName.trim().toLowerCase()}|${report.sellerWorkCategory.trim().toLowerCase()}';

  int periodSellQty(SellOutReport report) =>
      _sellQuantities[_sellerKey(report)] ?? 0;

  List<String> failureKeys(SellOutReport report) {
    if (!policy.visible) return const ['no_commission_condition'];
    if (!policy.canCalculate)
      return (report.serverCommission ?? 0) > 0
          ? const []
          : const ['not_earned_yet'];
    return policy.failures(
        SellOutReport.canonicalServiceType(report.serviceType),
        report.totalQty,
        report.totalAmount,
        report.customerPhone,
        report.sellerWorkCategory,
        periodQuantity: periodSellQty(report),
        conditions: (policy.canChangeMode
            ? mode == ReportCommissionMode.withConditions
            : policy.defaultMode == 'with_conditions'));
  }

  bool isEligible(SellOutReport report) => failureKeys(report).isEmpty;

  double commission(SellOutReport report) {
    if (!policy.visible) return 0;
    if (!policy.canCalculate) return report.serverCommission ?? 0;
    return policy.calculate(
        SellOutReport.canonicalServiceType(report.serviceType),
        report.totalQty,
        report.totalAmount,
        report.customerPhone,
        report.sellerWorkCategory,
        periodQuantity: periodSellQty(report),
        conditions: (policy.canChangeMode
            ? mode == ReportCommissionMode.withConditions
            : policy.defaultMode == 'with_conditions'));
  }
}
