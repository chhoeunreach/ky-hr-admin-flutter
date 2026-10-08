import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import '../config/repair_price_config.dart';
import '../models/repair_service.dart';
import '../services/repair_price_api_service.dart';
import '../utils/repair_price_helper.dart';

class RepairEditPriceSheet extends StatefulWidget {
  final RepairService service;
  final Future<void> Function(RepairService service) onSave;

  const RepairEditPriceSheet({
    super.key,
    required this.service,
    required this.onSave,
  });

  static Future<void> show(
    BuildContext context, {
    required RepairService service,
    required Future<void> Function(RepairService service) onSave,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RepairEditPriceSheet(service: service, onSave: onSave),
    );
  }

  @override
  State<RepairEditPriceSheet> createState() => _RepairEditPriceSheetState();
}

class _RepairEditPriceSheetState extends State<RepairEditPriceSheet> {
  late final TextEditingController _sellingPriceController;
  late final TextEditingController _partCostController;
  late final TextEditingController _serviceFeeController;
  late final TextEditingController _warrantyController;
  late final TextEditingController _timeController;
  late String _availabilityStatus;

  double _sellingPrice = 0;
  double _partCost = 0;
  double _serviceFee = 0;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _sellingPrice = widget.service.sellingPrice.toDouble();
    _partCost = (widget.service.partCost ?? 0).toDouble();
    _serviceFee = (widget.service.serviceFee ?? 0).toDouble();
    _availabilityStatus = widget.service.availabilityStatus;

    _sellingPriceController =
        TextEditingController(text: _sellingPrice.toStringAsFixed(0));
    _partCostController =
        TextEditingController(text: _partCost.toStringAsFixed(0));
    _serviceFeeController =
        TextEditingController(text: _serviceFee.toStringAsFixed(0));
    _warrantyController =
        TextEditingController(text: '${widget.service.warrantyDays ?? 90}');
    _timeController =
        TextEditingController(text: '${widget.service.estimatedMinutes ?? 30}');

    _sellingPriceController.addListener(_updateCalc);
    _partCostController.addListener(_updateCalc);
    _serviceFeeController.addListener(_updateCalc);
  }

  void _updateCalc() {
    setState(() {
      _sellingPrice = double.tryParse(_sellingPriceController.text) ?? 0;
      _partCost = double.tryParse(_partCostController.text) ?? 0;
      _serviceFee = double.tryParse(_serviceFeeController.text) ?? 0;
    });
  }

  double get _profit => _sellingPrice - _partCost - _serviceFee;

  @override
  void dispose() {
    _sellingPriceController.dispose();
    _partCostController.dispose();
    _serviceFeeController.dispose();
    _warrantyController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final updated = RepairService(
      id: widget.service.id,
      repairPriceId: widget.service.repairPriceId,
      name: widget.service.name,
      nameKh: widget.service.nameKh,
      description: widget.service.description,
      category: widget.service.category,
      partName: widget.service.partName,
      partType: widget.service.partType,
      sellingPrice: _sellingPrice,
      partCost: _partCost,
      serviceFee: _serviceFee,
      warrantyDays: int.tryParse(_warrantyController.text),
      estimatedMinutes: int.tryParse(_timeController.text),
      note: widget.service.note,
      availabilityStatus: _availabilityStatus,
      canViewCost: widget.service.canViewCost,
    );

    try {
      await widget.onSave(updated);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('បានកែប្រែតម្លៃ ${widget.service.name} ដោយជោគជ័យ!'),
          backgroundColor: RepairPriceConfig.success,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      final message = error is RepairApiException
          ? error.message
          : 'មានបញ្ហាក្នុងការកែប្រែតម្លៃ';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: RepairPriceConfig.error,
        ),
      );
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: RepairPriceConfig.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        translate('repair_screen.edit_price'),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: RepairPriceConfig.mainText,
                        ),
                      ),
                      Text(
                        widget.service.name,
                        style: const TextStyle(
                          fontSize: 13,
                          color: RepairPriceConfig.secondaryText,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: RepairPriceConfig.secondaryText),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              const Divider(color: RepairPriceConfig.border, height: 24),

              // Live Profit Card Preview
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: RepairPriceConfig.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: RepairPriceConfig.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _previewItem(
                        translate('repair_screen.selling_price'),
                        RepairPriceHelper.currency(_sellingPrice),
                        RepairPriceConfig.primaryBlue),
                    Container(
                        width: 1, height: 28, color: RepairPriceConfig.border),
                    _previewItem(
                        translate('repair_screen.part_cost'),
                        RepairPriceHelper.currency(_partCost),
                        RepairPriceConfig.mainText),
                    Container(
                        width: 1, height: 28, color: RepairPriceConfig.border),
                    _previewItem(
                        translate('repair_screen.service_fee'),
                        RepairPriceHelper.currency(_serviceFee),
                        RepairPriceConfig.mainText),
                    Container(
                        width: 1, height: 28, color: RepairPriceConfig.border),
                    _previewItem(translate('repair_screen.profit'), RepairPriceHelper.currency(_profit),
                        RepairPriceConfig.success,
                        isBold: true),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Input fields
              Row(
                children: [
                  Expanded(
                    child: _inputField(
                      controller: _sellingPriceController,
                      label: '${translate('repair_screen.selling_price')} (\$)',
                      icon: Icons.attach_money_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _inputField(
                      controller: _partCostController,
                      label: '${translate('repair_screen.part_cost')} (\$)',
                      icon: Icons.shopping_bag_outlined,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _inputField(
                      controller: _serviceFeeController,
                      label: '${translate('repair_screen.service_fee')} (\$)',
                      icon: Icons.handyman_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _inputField(
                      controller: _warrantyController,
                      label: '${translate('repair_screen.warranty')} (Days)',
                      icon: Icons.verified_outlined,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              _inputField(
                controller: _timeController,
                label: '${translate('repair_screen.repair_time')} (Minutes)',
                icon: Icons.timer_outlined,
              ),

              const SizedBox(height: 14),

              // Availability Dropdown
              Text(
                translate('repair_screen.status'),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: RepairPriceConfig.mainText,
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _availabilityStatus,
                decoration: InputDecoration(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: RepairPriceConfig.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: RepairPriceConfig.border),
                  ),
                ),
                items: const [
                  DropdownMenuItem(
                      value: 'available',
                      child: Text('Available / មានក្នុងស្តុក')),
                  DropdownMenuItem(
                      value: 'limited_stock',
                      child: Text('Limited Stock / ស្តុកមានកំណត់')),
                  DropdownMenuItem(
                      value: 'out_of_stock',
                      child: Text('Out of Stock / អស់ស្តុក')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _availabilityStatus = val);
                },
              ),

              const SizedBox(height: 20),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: RepairPriceConfig.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_rounded, size: 20),
                  label: Text(
                    _isSaving
                        ? 'កំពុងរក្សាទុក... / Saving...'
                        : translate('repair_screen.save'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: _isSaving ? null : _save,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _previewItem(String label, String value, Color color,
      {bool isBold = false}) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
              fontSize: 10, color: RepairPriceConfig.secondaryText),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: RepairPriceConfig.mainText,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            prefixIcon:
                Icon(icon, size: 18, color: RepairPriceConfig.secondaryText),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: RepairPriceConfig.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: RepairPriceConfig.border),
            ),
          ),
        ),
      ],
    );
  }
}
