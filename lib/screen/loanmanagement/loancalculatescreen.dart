import 'dart:math';

import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:intl/intl.dart';

enum InterestType {
  fixed,
  declining,
}

class LoanCalculateScreen extends StatefulWidget {
  @override
  State<LoanCalculateScreen> createState() => _LoanCalculateScreenState();
}

class _LoanCalculateScreenState extends State<LoanCalculateScreen> {
  final TextEditingController _totalPriceController = TextEditingController();
  final TextEditingController _joinPaymentController =
      TextEditingController(text: '0');
  final TextEditingController _interestRateController =
      TextEditingController(text: '4');
  final TextEditingController _amountMonthController =
      TextEditingController(text: '12');

  final NumberFormat _currencyFormat = NumberFormat('#,##0.00');
  InterestType _interestType = InterestType.fixed;
  DateTime _loanDate = DateTime.now();
  late DateTime _firstDueDate = _nextMonth(_loanDate);
  String _frequency = 'monthly';

  @override
  void dispose() {
    _totalPriceController.dispose();
    _joinPaymentController.dispose();
    _interestRateController.dispose();
    _amountMonthController.dispose();
    super.dispose();
  }

  double get _totalPrice => _parseNumber(_totalPriceController.text);
  double get _joinPayment => _parseNumber(_joinPaymentController.text);
  double get _interestRate => _parseNumber(_interestRateController.text);
  int get _amountMonth => int.tryParse(_amountMonthController.text.trim()) ?? 0;

  double get _loanAmount => max(_totalPrice - _joinPayment, 0);

  double get _monthlyPayment {
    if (_loanAmount <= 0 || _amountMonth <= 0) {
      return 0;
    }

    final monthlyRate = _interestRate / 100;
    if (_interestType == InterestType.fixed) {
      return (_loanAmount / _amountMonth) + (_loanAmount * monthlyRate);
    }

    if (monthlyRate <= 0) {
      return _loanAmount / _amountMonth;
    }

    final factor = pow(1 + monthlyRate, _amountMonth);
    return _loanAmount * monthlyRate * factor / (factor - 1);
  }

  double get _totalPayment => _monthlyPayment * _amountMonth;

  double _parseNumber(String value) {
    return double.tryParse(value.replaceAll(',', '').trim()) ?? 0;
  }

  String _formatMoney(double value) {
    return _currencyFormat.format(value);
  }

  static DateTime _nextMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, date.day);
  }

  Future<void> _pickLoanDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _loanDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null) {
      return;
    }
    setState(() {
      _loanDate = date;
      _firstDueDate = _nextMonth(date);
    });
  }

  Future<void> _pickFirstDueDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _firstDueDate,
      firstDate: _loanDate,
      lastDate: DateTime(2100),
    );
    if (date == null) {
      return;
    }
    setState(() {
      _firstDueDate = date;
    });
  }

  void _previewSchedule() {
    final enterprise = EnterpriseTheme.of(context);
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: enterprise.surface,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                translate('loan_calculate_screen.schedule_preview'),
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 16),
              _PreviewRow(
                  label: translate('loan_calculate_screen.loan_amount'),
                  value: '\$ ${_formatMoney(_loanAmount)}'),
              _PreviewRow(
                label: translate('loan_calculate_screen.monthly_payment'),
                value: '\$ ${_formatMoney(_monthlyPayment)}',
              ),
              _PreviewRow(
                label: translate('loan_calculate_screen.duration'),
                value:
                    '$_amountMonth ${translate('loan_calculate_screen.months')}',
              ),
              _PreviewRow(
                label: translate('loan_calculate_screen.total_payment'),
                value: '\$ ${_formatMoney(_totalPayment)}',
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final enterprise = EnterpriseTheme.of(context);
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: enterprise.text,
        title: Text(
          translate('loan_calculate_screen.loan_calculator'),
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth >= 720 ? 32.0 : 16.0;
            return Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    10,
                    horizontalPadding,
                    14,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 620),
                      child: _SummaryCard(
                        payment: _monthlyPayment,
                        price: _totalPrice,
                        downPayment: _joinPayment,
                        formatter: _formatMoney,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      0,
                      horizontalPadding,
                      20,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 620),
                        child: _LoanFormCard(
                          totalPriceController: _totalPriceController,
                          joinPaymentController: _joinPaymentController,
                          interestRateController: _interestRateController,
                          amountMonthController: _amountMonthController,
                          frequency: _frequency,
                          interestType: _interestType,
                          loanDate: _loanDate,
                          firstDueDate: _firstDueDate,
                          monthlyPayment: _monthlyPayment,
                          totalPayment: _totalPayment,
                          formatter: _formatMoney,
                          onChanged: () => setState(() {}),
                          onFrequencyChanged: (value) {
                            setState(() {
                              _frequency = value;
                            });
                          },
                          onInterestTypeChanged: (value) {
                            setState(() {
                              _interestType = value;
                            });
                          },
                          onPickLoanDate: _pickLoanDate,
                          onPickFirstDueDate: _pickFirstDueDate,
                          onPreviewSchedule: _previewSchedule,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final double payment;
  final double price;
  final double downPayment;
  final String Function(double) formatter;

  const _SummaryCard({
    required this.payment,
    required this.price,
    required this.downPayment,
    required this.formatter,
  });

  @override
  Widget build(BuildContext context) {
    final enterprise = EnterpriseTheme.of(context);
    return Container(
      height: 104,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            enterprise.primary,
            enterprise.secondary,
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: enterprise.primary.withValues(alpha: 0.26),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 76,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.10),
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(28),
              ),
            ),
            child: const Center(
              child: Icon(Icons.calculate, color: Colors.white, size: 34),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '\$ ${formatter(payment)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${translate('loan_calculate_screen.price')} \$ ${formatter(price)}  •  ${translate('loan_calculate_screen.down')} \$ ${formatter(downPayment)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.88),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoanFormCard extends StatelessWidget {
  final TextEditingController totalPriceController;
  final TextEditingController joinPaymentController;
  final TextEditingController interestRateController;
  final TextEditingController amountMonthController;
  final String frequency;
  final InterestType interestType;
  final DateTime loanDate;
  final DateTime firstDueDate;
  final double monthlyPayment;
  final double totalPayment;
  final String Function(double) formatter;
  final VoidCallback onChanged;
  final ValueChanged<String> onFrequencyChanged;
  final ValueChanged<InterestType> onInterestTypeChanged;
  final VoidCallback onPickLoanDate;
  final VoidCallback onPickFirstDueDate;
  final VoidCallback onPreviewSchedule;

  const _LoanFormCard({
    required this.totalPriceController,
    required this.joinPaymentController,
    required this.interestRateController,
    required this.amountMonthController,
    required this.frequency,
    required this.interestType,
    required this.loanDate,
    required this.firstDueDate,
    required this.monthlyPayment,
    required this.totalPayment,
    required this.formatter,
    required this.onChanged,
    required this.onFrequencyChanged,
    required this.onInterestTypeChanged,
    required this.onPickLoanDate,
    required this.onPickFirstDueDate,
    required this.onPreviewSchedule,
  });

  @override
  Widget build(BuildContext context) {
    final enterprise = EnterpriseTheme.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            color: enterprise.surface,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black
                    .withValues(alpha: enterprise.isDark ? 0.28 : 0.10),
                blurRadius: 24,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FieldPair(
                first: _LoanTextField(
                  controller: totalPriceController,
                  label: translate('loan_calculate_screen.product_price'),
                  onChanged: (_) => onChanged(),
                ),
                second: _LoanTextField(
                  controller: joinPaymentController,
                  label: translate('loan_calculate_screen.down_payment'),
                  onChanged: (_) => onChanged(),
                ),
              ),
              const SizedBox(height: 10),
              _FieldPair(
                first: _LoanTextField(
                  controller: interestRateController,
                  label: translate('loan_calculate_screen.interest_percent'),
                  onChanged: (_) => onChanged(),
                ),
                second: _LoanTextField(
                  controller: amountMonthController,
                  label: translate('loan_calculate_screen.duration'),
                  integerOnly: true,
                  onChanged: (_) => onChanged(),
                ),
              ),
              const SizedBox(height: 10),
              _FieldPair(
                first: _LoanDropdown<String>(
                  label: translate('loan_calculate_screen.frequency'),
                  value: frequency,
                  items: const ['monthly', 'weekly'],
                  itemLabel: (value) =>
                      translate('loan_calculate_screen.$value'),
                  onChanged: onFrequencyChanged,
                ),
                second: _LoanDropdown<InterestType>(
                  label: translate('loan_calculate_screen.interest_type'),
                  value: interestType,
                  items: InterestType.values,
                  itemLabel: (value) {
                    switch (value) {
                      case InterestType.fixed:
                        return translate('loan_calculate_screen.flat');
                      case InterestType.declining:
                        return translate('loan_calculate_screen.declining');
                    }
                  },
                  onChanged: onInterestTypeChanged,
                ),
              ),
              const SizedBox(height: 10),
              _FieldPair(
                first: _LoanDateField(
                  label: translate('loan_calculate_screen.loan_date'),
                  value: loanDate,
                  onTap: onPickLoanDate,
                ),
                second: _LoanDateField(
                  label: translate('loan_calculate_screen.first_due'),
                  value: firstDueDate,
                  onTap: onPickFirstDueDate,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _MetricTile(
                      label: translate('loan_calculate_screen.monthly'),
                      value: '\$ ${formatter(monthlyPayment)}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricTile(
                      label: translate('loan_calculate_screen.total'),
                      value: '\$ ${formatter(totalPayment)}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: enterprise.primary,
                    foregroundColor: colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  onPressed: onPreviewSchedule,
                  child:
                      Text(translate('loan_calculate_screen.preview_schedule')),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FieldPair extends StatelessWidget {
  final Widget first;
  final Widget second;

  const _FieldPair({
    required this.first,
    required this.second,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: first),
        const SizedBox(width: 8),
        Expanded(child: second),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;

  const _MetricTile({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final enterprise = EnterpriseTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: enterprise.primary
            .withValues(alpha: enterprise.isDark ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: enterprise.primary.withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: enterprise.mutedText,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: enterprise.text,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoanTextField extends StatelessWidget {
  final TextEditingController controller;
  final String? label;
  final ValueChanged<String> onChanged;
  final bool integerOnly;

  const _LoanTextField({
    required this.controller,
    required this.onChanged,
    this.label,
    this.integerOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final enterprise = EnterpriseTheme.of(context);
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          integerOnly ? RegExp(r'[0-9]') : RegExp(r'[0-9.]'),
        ),
      ],
      style: TextStyle(
        color: enterprise.text,
        fontSize: 17,
        fontWeight: FontWeight.w500,
      ),
      cursorColor: enterprise.primary,
      onChanged: onChanged,
      decoration: _fieldDecoration(context, label: label),
    );
  }
}

class _LoanDropdown<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<T> items;
  final String Function(T value) itemLabel;
  final ValueChanged<T> onChanged;

  const _LoanDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final enterprise = EnterpriseTheme.of(context);
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      dropdownColor: enterprise.surface,
      icon: Icon(Icons.keyboard_arrow_down, color: enterprise.mutedText),
      style: TextStyle(
        color: enterprise.text,
        fontSize: 17,
        fontWeight: FontWeight.w800,
      ),
      decoration: _fieldDecoration(context, label: label),
      items: [
        for (final item in items)
          DropdownMenuItem<T>(
            value: item,
            child: Text(itemLabel(item)),
          ),
      ],
      onChanged: (value) {
        if (value != null) {
          onChanged(value);
        }
      },
    );
  }
}

class _LoanDateField extends StatelessWidget {
  final String label;
  final DateTime value;
  final VoidCallback onTap;

  const _LoanDateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enterprise = EnterpriseTheme.of(context);
    final text = DateFormat('yyyy-MM-dd').format(value);
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: InputDecorator(
        decoration: _fieldDecoration(context, label: label),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: enterprise.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              Icons.calendar_today_outlined,
              color: enterprise.mutedText,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  final String label;
  final String value;

  const _PreviewRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final enterprise = EnterpriseTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: enterprise.mutedText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: enterprise.text,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

InputDecoration _fieldDecoration(
  BuildContext context, {
  String? label,
}) {
  final enterprise = EnterpriseTheme.of(context);
  final fillColor = enterprise.isDark
      ? Colors.white.withValues(alpha: 0.06)
      : Colors.white.withValues(alpha: 0.78);
  final borderColor = enterprise.text.withValues(alpha: 0.10);
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(18),
    borderSide: BorderSide(color: borderColor, width: 1.2),
  );

  return InputDecoration(
    labelText: label,
    labelStyle: TextStyle(
      color: enterprise.mutedText,
      fontSize: 14,
      fontWeight: FontWeight.w800,
      letterSpacing: 0,
    ),
    floatingLabelBehavior: label == null
        ? FloatingLabelBehavior.never
        : FloatingLabelBehavior.always,
    filled: true,
    fillColor: fillColor,
    enabledBorder: border,
    focusedBorder: border.copyWith(
      borderSide: BorderSide(color: enterprise.primary, width: 1.5),
    ),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
  );
}
