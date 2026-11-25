import 'package:cached_network_image/cached_network_image.dart';
import 'package:cnattendance/core/theme/app_colors.dart';
import 'package:cnattendance/features/company_documents/company_document_api.dart';
import 'package:cnattendance/features/company_documents/company_document_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:url_launcher/url_launcher.dart';

class CompanyDocumentDetailScreen extends StatefulWidget {
  final CompanyDocumentItem document;

  const CompanyDocumentDetailScreen({super.key, required this.document});

  @override
  State<CompanyDocumentDetailScreen> createState() => _CompanyDocumentDetailScreenState();
}

class _CompanyDocumentDetailScreenState extends State<CompanyDocumentDetailScreen> {
  final CompanyDocumentApi _api = CompanyDocumentApi();
  late CompanyDocumentItem _doc;

  @override
  void initState() {
    super.initState();
    _doc = widget.document;
    _refreshDetail();
  }

  Future<void> _refreshDetail() async {
    try {
      final updated = await _api.getDocument(_doc.id);
      if (mounted) {
        setState(() => _doc = updated);
      }
    } catch (_) {}
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'expired':
        return Colors.red.shade600;
      case 'expiring_soon':
        return Colors.orange.shade700;
      case 'valid':
        return Colors.green.shade600;
      case 'archived':
        return Colors.grey.shade600;
      default:
        return Colors.blue.shade600;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'expired':
        return 'ផុតកំណត់ (Expired)';
      case 'expiring_soon':
        return 'ជិតផុត (Expiring Soon)';
      case 'valid':
        return 'មានសុពលភាព (Valid)';
      case 'archived':
        return 'បណ្ណសារ (Archived)';
      default:
        return status;
    }
  }

  int _selectedAttachmentIndex = 0;

  void _openFullScreenImage(String imageUrl, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
          ),
          body: Center(
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                placeholder: (_, __) => const Center(child: CircularProgressIndicator(color: Colors.white)),
                errorWidget: (_, __, ___) => const Center(child: Icon(Icons.broken_image, color: Colors.white, size: 50)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openFile([String? url]) async {
    final targetUrl = url ?? _doc.fileUrl;
    if (targetUrl.isEmpty) {
      EasyLoading.showInfo('មិនមានឯកសារភ្ជាប់ឡើយ (No file attached)');
      return;
    }
    final uri = Uri.parse(targetUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        EasyLoading.showError('Could not open file: $targetUrl');
      }
    } catch (e) {
      EasyLoading.showError('Error opening file: $e');
    }
  }

  Future<void> _deleteDocument() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('បញ្ជាក់ការលុបឯកសារ', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('តើលោកអ្នកពិតជាចង់លុបឯកសារ "${_doc.title}" នេះមែនទេ? សកម្មភាពនេះមិនអាចត្រឡប់ក្រោយបានឡើយ។'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('បោះបង់ (Cancel)'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('លុប (Delete)', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        EasyLoading.show(status: 'កំពុងលុប...');
        await _api.deleteDocument(_doc.id);
        EasyLoading.showSuccess('ឯកសារត្រូវបានលុបដោយជោគជ័យ!');
        if (mounted) Navigator.pop(context, true);
      } catch (e) {
        EasyLoading.showError('Error deleting: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>() ?? AppColors.light;
    final statusColor = _getStatusColor(_doc.calculatedStatus);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          'ព័ត៌មានលម្អិតឯកសារ',
          style: TextStyle(fontWeight: FontWeight.bold, color: colors.textPrimary, fontSize: 16),
        ),
        backgroundColor: colors.card,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 20, color: colors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: _deleteDocument,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header Card with Title & Status
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _doc.categoryName,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.primary),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        _getStatusLabel(_doc.calculatedStatus),
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _doc.title,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: colors.textPrimary),
                ),
                if (_doc.docNumber != null && _doc.docNumber!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'លេខឯកសារ៖ ${_doc.docNumber}',
                    style: TextStyle(fontSize: 13, color: colors.textSecondary),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // File Preview Card (Supports Multiple Attachments)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'ឯកសារភ្ជាប់ (Attachments)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    if (_doc.attachments.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_doc.attachments.length} ឯកសារ',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors.primary),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Multi-attachment Selector Pills (if more than 1 attachment)
                if (_doc.attachments.length > 1) ...[
                  SizedBox(
                    height: 80,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _doc.attachments.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final att = _doc.attachments[index];
                        final isSelected = index == _selectedAttachmentIndex;
                        return InkWell(
                          onTap: () => setState(() => _selectedAttachmentIndex = index),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 70,
                            decoration: BoxDecoration(
                              color: isSelected ? colors.primary.withValues(alpha: 0.08) : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected ? colors.primary : Colors.grey.shade300,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  att.isImage
                                      ? Icons.image
                                      : (att.isPdf ? Icons.picture_as_pdf : Icons.insert_drive_file),
                                  color: att.isImage
                                      ? colors.primary
                                      : (att.isPdf ? Colors.red : Colors.blue),
                                  size: 26,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'ទំព័រ ${index + 1}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected ? colors.primary : Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Active Attachment View
                Builder(
                  builder: (context) {
                    final currentAtt = _doc.attachments.isNotEmpty
                        ? _doc.attachments[_selectedAttachmentIndex.clamp(0, _doc.attachments.length - 1)]
                        : null;
                    final isImg = currentAtt?.isImage ?? _doc.isImage;
                    final activeUrl = currentAtt?.fileUrl ?? _doc.fileUrl;
                    final activeFileName = currentAtt?.fileName ?? _doc.fileName ?? 'Document File';
                    final isPdf = currentAtt?.isPdf ?? _doc.isPdf;

                    if (isImg && activeUrl.isNotEmpty) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            onTap: () => _openFullScreenImage(activeUrl, activeFileName),
                            borderRadius: BorderRadius.circular(12),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: CachedNetworkImage(
                                    imageUrl: activeUrl,
                                    placeholder: (context, url) => const SizedBox(
                                      height: 200,
                                      child: Center(child: CircularProgressIndicator()),
                                    ),
                                    errorWidget: (context, url, error) => Container(
                                      height: 160,
                                      color: Colors.grey.shade100,
                                      child: const Center(child: Icon(Icons.broken_image, size: 40, color: Colors.grey)),
                                    ),
                                    fit: BoxFit.contain,
                                    width: double.infinity,
                                  ),
                                ),
                                Positioned(
                                  bottom: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.65),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.zoom_in, color: Colors.white, size: 14),
                                        SizedBox(width: 4),
                                        Text('ពង្រីក (Zoom)', style: TextStyle(color: Colors.white, fontSize: 10)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      );
                    } else {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isPdf ? Icons.picture_as_pdf : Icons.insert_drive_file,
                                  color: isPdf ? Colors.red : Colors.blue,
                                  size: 36,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        activeFileName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        isPdf ? 'ឯកសារ PDF' : 'ឯកសារភ្ជាប់ (Attachment)',
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      );
                    }
                  },
                ),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final currentAtt = _doc.attachments.isNotEmpty
                          ? _doc.attachments[_selectedAttachmentIndex.clamp(0, _doc.attachments.length - 1)]
                          : null;
                      _openFile(currentAtt?.fileUrl);
                    },
                    icon: const Icon(Icons.open_in_new, size: 18, color: Colors.white),
                    label: Text(
                      _doc.attachments.length > 1
                          ? 'បើកមើលទំព័រ ${_selectedAttachmentIndex + 1} (Open / Download)'
                          : 'បើកមើល ឬទាញយកឯកសារ (Open / Download)',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Metadata Details Table Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ព័ត៌មានលម្អិត (Document Information)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 12),
                _buildInfoRow('សាខា (Branch)', _doc.branchName),
                if (_doc.holderName != null && _doc.holderName!.isNotEmpty)
                  _buildInfoRow('ម្ចាស់ឯកសារ (Holder)', _doc.holderName!),
                if (_doc.issuingAuthority != null && _doc.issuingAuthority!.isNotEmpty)
                  _buildInfoRow('ស្ថាប័នចេញ (Authority)', _doc.issuingAuthority!),
                if (_doc.issueDate != null)
                  _buildInfoRow('កាលបរិច្ឆេទចេញ (Issue Date)', _doc.issueDate!),
                if (_doc.expiryDate != null)
                  _buildInfoRow('កាលបរិច្ឆេទផុតកំណត់ (Expiry Date)', _doc.expiryDate!, isExpiry: true),
                if (_doc.daysRemaining != null)
                  _buildInfoRow('ថ្ងៃនៅសល់ (Days Remaining)', '${_doc.daysRemaining} ថ្ងៃ'),
                if (_doc.formattedCost != null)
                  _buildInfoRow('ចំនួនទឹកប្រាក់ (Cost)', _doc.formattedCost!),
                if (_doc.receiptNumber != null && _doc.receiptNumber!.isNotEmpty)
                  _buildInfoRow('លេខបង្កាន់ដៃ (Receipt No.)', _doc.receiptNumber!),
                if (_doc.createdBy != null)
                  _buildInfoRow('បញ្ចូលដោយ (Created By)', _doc.createdBy!),
                if (_doc.description != null && _doc.description!.isNotEmpty) ...[
                  const Divider(height: 20),
                  const Text('កំណត់សម្គាល់បន្ថែម៖', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text(_doc.description!, style: const TextStyle(fontSize: 13, height: 1.4)),
                ],
              ],
            ),
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isExpiry = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isExpiry ? FontWeight.bold : FontWeight.w500,
                color: isExpiry ? Colors.red.shade700 : Colors.black87,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
