import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:cnattendance/models/commission_policy.dart';

void showServerCommissionRules(BuildContext context, CommissionPolicy policy) {
  if (!policy.visible) return;
  String tr(String key) => translate('sell_out_report.$key');
  showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
          child: DraggableScrollableSheet(
              expand: false,
              initialChildSize: .65,
              minChildSize: .35,
              maxChildSize: .9,
              builder: (_, scroll) => ListView(
                      controller: scroll,
                      padding: const EdgeInsets.all(18),
                      children: [
                        Text(tr('commission_rules'),
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        Text(tr('managed_by_admin')),
                        for (final entry in policy.rules.entries)
                          Card(
                              child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            translate(
                                                'home_screen.service_${entry.key}'),
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w700)),
                                        const SizedBox(height: 6),
                                        if (!policy.enabled ||
                                            !entry.value.enabled)
                                          Text(tr('commission_disabled'))
                                        else ...[
                                          Text(
                                              '${entry.value.rate} / ${tr(entry.value.perItem ? 'per_item' : 'per_invoice')}'),
                                          if (entry.value.requirePhone)
                                            Text(tr('phone_required')),
                                          Text(
                                              '${tr('minimum_invoice_amount')}: ${entry.value.minimumAmount}'),
                                          Text(
                                              '${tr('part_time_minimum_quantity')}: ${entry.value.partTimeQuantity}'),
                                          Text(
                                              '${tr('full_time_minimum_quantity')}: ${entry.value.fullTimeQuantity}'),
                                        ]
                                      ]))),
                      ]))));
}
