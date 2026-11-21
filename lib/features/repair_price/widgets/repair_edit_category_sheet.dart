import 'package:cnattendance/theme/enterprise_theme.dart';
import 'package:flutter/material.dart';
import '../models/repair_category.dart';

class RepairEditCategorySheet extends StatefulWidget {
  final RepairCategory? category;
  final ValueChanged<RepairCategory> onSave;
  final ValueChanged<int>? onDelete;

  const RepairEditCategorySheet({
    super.key,
    this.category,
    required this.onSave,
    this.onDelete,
  });

  static Future<void> show(
    BuildContext context, {
    RepairCategory? category,
    required ValueChanged<RepairCategory> onSave,
    ValueChanged<int>? onDelete,
  }) {
    return showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RepairEditCategorySheet(
        category: category,
        onSave: onSave,
        onDelete: onDelete,
      ),
    );
  }

  @override
  State<RepairEditCategorySheet> createState() =>
      _RepairEditCategorySheetState();
}

class _RepairEditCategorySheetState extends State<RepairEditCategorySheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _nameKhController;
  late final TextEditingController _slugController;
  late final TextEditingController _sortOrderController;
  late bool _status;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.name ?? '');
    _nameKhController =
        TextEditingController(text: widget.category?.nameKh ?? '');
    _slugController = TextEditingController(text: widget.category?.slug ?? '');
    _sortOrderController = TextEditingController(
        text: (widget.category?.sortOrder ?? 0).toString());
    _status = widget.category?.status ?? true;

    _nameController.addListener(() {
      if (widget.category == null) {
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
    _nameKhController.dispose();
    _slugController.dispose();
    _sortOrderController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'សូមបញ្ចូលឈ្មោះប្រភេទសេវា (អង់គ្លេស) / Please enter category name'),
        ),
      );
      return;
    }

    final slug = _slugController.text.trim().isNotEmpty
        ? _slugController.text.trim()
        : name.toLowerCase().replaceAll(RegExp(r'\s+'), '-');

    final sortOrder = int.tryParse(_sortOrderController.text.trim()) ?? 0;

    final updatedCategory = RepairCategory(
      id: widget.category?.id ?? DateTime.now().millisecondsSinceEpoch % 100000,
      name: name,
      nameKh: _nameKhController.text.trim(),
      slug: slug,
      icon: widget.category?.icon ?? '',
      sortOrder: sortOrder,
      status: _status,
    );

    widget.onSave(updatedCategory);
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.category == null
              ? 'បានបន្ថែមប្រភេទសេវាថ្មីជោគជ័យ! / Category added!'
              : 'បានកែប្រែប្រភេទសេវាជោគជ័យ! / Category updated!',
        ),
        backgroundColor: const Color(0xFF10B981),
      ),
    );
  }

  void _confirmDelete() {
    if (widget.category == null || widget.onDelete == null) return;
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
              'លុបប្រភេទសេវា / Delete Category',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: enterprise.text,
              ),
            ),
          ],
        ),
        content: Text(
          'តើអ្នកពិតជាចង់លុបប្រភេទ "${widget.category!.name}" (${widget.category!.nameKh}) មែនទេ?\nAre you sure you want to delete this category?',
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
              widget.onDelete!(widget.category!.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'បានលុបប្រភេទ "${widget.category!.name}" ជោគជ័យ!',
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
    final isNew = widget.category == null;

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
                        ? 'បន្ថែមប្រភេទសេវា / Add Category'
                        : 'កែសម្រួលប្រភេទសេវា / Edit Category',
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

              // Category Name (EN)
              _textField(
                'ឈ្មោះជាភាសាអង់គ្លេស / English Name *',
                _nameController,
                'e.g. Screen, Battery, Charging Port',
                enterprise,
              ),
              const SizedBox(height: 12),

              // Category Name (KH)
              _textField(
                'ឈ្មោះជាភាសាខ្មែរ / Khmer Name',
                _nameKhController,
                'e.g. អេក្រង់, ថ្ម, កន្ទុយសាក',
                enterprise,
              ),
              const SizedBox(height: 12),

              // Row: Slug & Sort Order
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _textField(
                      'Slug',
                      _slugController,
                      'e.g. screen',
                      enterprise,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 1,
                    child: _textField(
                      'លំដាប់ / Order',
                      _sortOrderController,
                      '1',
                      enterprise,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
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
                        ? 'បង្កើតប្រភេទសេវា / Create Category'
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
                      'លុបប្រភេទសេវា / Delete Category',
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
    EnterpriseTheme enterprise, {
    TextInputType keyboardType = TextInputType.text,
  }) {
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
          keyboardType: keyboardType,
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
