import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:flutter/material.dart';
import '../models/repair_brand.dart';

class RepairEditBrandSheet extends StatefulWidget {
  final RepairBrand? brand;
  final ValueChanged<RepairBrand> onSave;
  final ValueChanged<int>? onDelete;

  const RepairEditBrandSheet({
    super.key,
    this.brand,
    required this.onSave,
    this.onDelete,
  });

  static Future<void> show(
    BuildContext context, {
    RepairBrand? brand,
    required ValueChanged<RepairBrand> onSave,
    ValueChanged<int>? onDelete,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RepairEditBrandSheet(
        brand: brand,
        onSave: onSave,
        onDelete: onDelete,
      ),
    );
  }

  @override
  State<RepairEditBrandSheet> createState() => _RepairEditBrandSheetState();
}

class _RepairEditBrandSheetState extends State<RepairEditBrandSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _slugController;
  late bool _status;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.brand?.name ?? '');
    _slugController = TextEditingController(text: widget.brand?.slug ?? '');
    _status = widget.brand?.status ?? true;

    _nameController.addListener(() {
      if (widget.brand == null) {
        _slugController.text = _nameController.text
            .trim()
            .toLowerCase()
            .replaceAll(RegExp(r'\s+'), '-');
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _slugController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('សូមបញ្ចូលឈ្មោះម៉ាកយីហោ / Please enter brand name'),
        ),
      );
      return;
    }

    final slug = _slugController.text.trim().isNotEmpty
        ? _slugController.text.trim()
        : name.toLowerCase().replaceAll(RegExp(r'\s+'), '-');

    final updatedBrand = RepairBrand(
      id: widget.brand?.id ?? DateTime.now().millisecondsSinceEpoch % 100000,
      name: name,
      slug: slug,
      logo: widget.brand?.logo ?? '',
      status: _status,
    );

    widget.onSave(updatedBrand);
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.brand == null
              ? 'បានបន្ថែមម៉ាកយីហោថ្មីជោគជ័យ! / Brand added successfully!'
              : 'បានកែប្រែម៉ាកយីហោជោគជ័យ! / Brand updated successfully!',
        ),
        backgroundColor: const Color(0xFF10B981),
      ),
    );
  }

  void _confirmDelete() {
    if (widget.brand == null || widget.onDelete == null) return;
    final enterprise = EnterpriseTheme.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: enterprise.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Colors.redAccent, size: 24),
            const SizedBox(width: 8),
            Text(
              'លុបម៉ាកយីហោ / Delete Brand',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: enterprise.text,
              ),
            ),
          ],
        ),
        content: Text(
          'តើអ្នកពិតជាចង់លុបម៉ាក "${widget.brand!.name}" មែនទេ?\nAre you sure you want to delete this brand?',
          style: TextStyle(fontSize: 13, color: enterprise.mutedText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'បោះបង់ / Cancel',
              style: TextStyle(color: enterprise.mutedText),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx); // close dialog
              Navigator.pop(context); // close sheet
              widget.onDelete!(widget.brand!.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'បានលុប "${widget.brand!.name}" ជោគជ័យ! / Brand deleted!',
                  ),
                  backgroundColor: Colors.redAccent,
                ),
              );
            },
            child: const Text('លុប / Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final enterprise = EnterpriseTheme.of(context);
    final isNew = widget.brand == null;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: enterprise.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border:
            Border(top: BorderSide(color: enterprise.glassStroke, width: 1)),
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
                  Text(
                    isNew
                        ? 'បន្ថែមម៉ាកយីហោ / Add Brand'
                        : 'កែសម្រួលម៉ាកយីហោ / Edit Brand',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: enterprise.text,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded,
                        color: enterprise.mutedText, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              Divider(color: enterprise.glassStroke, height: 20),

              // Brand Name
              _textField(
                'ឈ្មោះម៉ាក / Brand Name *',
                _nameController,
                'e.g. Apple, Samsung, Google',
                enterprise,
              ),
              const SizedBox(height: 12),

              // Brand Slug
              _textField(
                'Slug / ឈ្មោះសម្គាល់',
                _slugController,
                'e.g. apple, samsung',
                enterprise,
              ),
              const SizedBox(height: 12),

              // Status Switch
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ស្ថានភាព / Active Status',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: enterprise.text,
                    ),
                  ),
                  Switch.adaptive(
                    value: _status,
                    activeTrackColor: enterprise.accent,
                    onChanged: (val) => setState(() => _status = val),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: enterprise.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: Text(
                    isNew
                        ? 'បង្កើតម៉ាកថ្មី / Create Brand'
                        : 'រក្សាទុក / Save Changes',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: _save,
                ),
              ),

              // Delete Button (if editing)
              if (!isNew && widget.onDelete != null) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent, width: 1),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text(
                      'លុបម៉ាកយីហោ / Delete Brand',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onPressed: _confirmDelete,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _textField(
    String label,
    TextEditingController controller,
    String hint,
    EnterpriseTheme enterprise,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: enterprise.text,
          ),
        ),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          style: TextStyle(fontSize: 13.5, color: enterprise.text),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: 12.5,
              color: enterprise.mutedText.withValues(alpha: 0.6),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            filled: true,
            fillColor:
                Colors.white.withValues(alpha: enterprise.isDark ? 0.06 : 0.4),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: enterprise.glassStroke),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: enterprise.glassStroke),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: enterprise.accent, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
