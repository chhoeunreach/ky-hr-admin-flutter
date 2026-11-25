import 'package:cnattendance/core/theme/app_colors.dart';
import 'package:cnattendance/features/company_documents/company_document_api.dart';
import 'package:cnattendance/features/company_documents/company_document_create_screen.dart';
import 'package:cnattendance/features/company_documents/company_document_detail_screen.dart';
import 'package:cnattendance/features/company_documents/company_document_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class CompanyDocumentsScreen extends StatefulWidget {
  const CompanyDocumentsScreen({super.key});

  @override
  State<CompanyDocumentsScreen> createState() => _CompanyDocumentsScreenState();
}

class _CompanyDocumentsScreenState extends State<CompanyDocumentsScreen> {
  final CompanyDocumentApi _api = CompanyDocumentApi();
  final TextEditingController _searchController = TextEditingController();

  List<CompanyDocumentItem> _documents = [];
  CompanyDocumentSummary _summary = CompanyDocumentSummary.empty();
  List<CompanyDocumentCategoryItem> _categories = [];
  List<CompanyDocumentItem> _expiringAlerts = [];

  bool _isLoading = true;
  String _selectedCategory = 'all';
  String _selectedStatus = 'all';
  int _currentPage = 1;
  bool _hasMore = false;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final meta = await _api.getMeta();
      if (mounted) {
        setState(() {
          _categories = meta['categories'] as List<CompanyDocumentCategoryItem>? ?? [];
        });
      }

      await _fetchDocuments(reset: true);
      _fetchAlerts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading documents: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchAlerts() async {
    try {
      final alerts = await _api.getAlerts();
      if (mounted) {
        setState(() {
          _expiringAlerts = [
            ...alerts['expired'] as List<CompanyDocumentItem>? ?? [],
            ...alerts['expiring_soon'] as List<CompanyDocumentItem>? ?? [],
          ];
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchDocuments({bool reset = false}) async {
    if (reset) {
      _currentPage = 1;
    } else {
      if (_isLoadingMore || !_hasMore) return;
      setState(() => _isLoadingMore = true);
    }

    try {
      final result = await _api.getDocuments(
        category: _selectedCategory,
        status: _selectedStatus,
        search: _searchController.text,
        page: _currentPage,
      );

      final newDocs = result['documents'] as List<CompanyDocumentItem>? ?? [];
      final summary = result['summary'] as CompanyDocumentSummary? ?? CompanyDocumentSummary.empty();
      final pagination = result['pagination'] as Map<String, dynamic>? ?? {};

      if (mounted) {
        setState(() {
          if (reset) {
            _documents = newDocs;
          } else {
            _documents.addAll(newDocs);
          }
          _summary = summary;
          _hasMore = pagination['has_more'] == true;
          if (_hasMore) _currentPage++;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
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
        return 'ជិតផុត (Expiring)';
      case 'valid':
        return 'មានសុពលភាព (Valid)';
      case 'archived':
        return 'ទុកក្នុងបណ្ណសារ (Archived)';
      default:
        return status;
    }
  }

  IconData _getCategoryIcon(String categoryCode) {
    switch (categoryCode) {
      case 'master':
        return FontAwesomeIcons.idCard;
      case 'tax':
        return FontAwesomeIcons.fileInvoiceDollar;
      case 'business_license':
        return FontAwesomeIcons.briefcase;
      case 'nssf':
        return FontAwesomeIcons.shieldHeart;
      case 'contract':
        return FontAwesomeIcons.fileSignature;
      case 'utility':
        return FontAwesomeIcons.bolt;
      default:
        return FontAwesomeIcons.fileLines;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>() ?? AppColors.light;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          translate('more_screen.company_documents'),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
            fontSize: 18,
          ),
        ),
        backgroundColor: colors.card,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 20, color: colors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: colors.primary),
            onPressed: () => _loadInitialData(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: colors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'បញ្ចូលឯកសារ',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) => const CompanyDocumentCreateScreen(),
            ),
          );
          if (created == true) {
            _fetchDocuments(reset: true);
            _fetchAlerts();
          }
        },
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await _fetchDocuments(reset: true);
                await _fetchAlerts();
              },
              child: Column(
                children: [
                  // Search Bar
                  Container(
                    color: colors.card,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'ស្វែងរកតាមឈ្មោះ, លេខកូដ, ម្ចាស់...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  _fetchDocuments(reset: true);
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: colors.surface.withValues(alpha: 0.4),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _fetchDocuments(reset: true),
                    ),
                  ),

                  // Category Filter Horizontal Pills
                  Container(
                    color: colors.card,
                    height: 48,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      children: [
                        _buildCategoryChip('all', '📁 ទាំងអស់ (All)'),
                        if (_categories.isNotEmpty)
                          ..._categories.map((c) => _buildCategoryChip(c.code, '${c.nameKm} (${c.nameEn})'))
                        else ...[
                          _buildCategoryChip('master', '🏢 មេ/អត្តសញ្ញាណ'),
                          _buildCategoryChip('tax', '📑 ពន្ធដារ'),
                          _buildCategoryChip('business_license', '🏪 អាជ្ញាបណ្ណ'),
                          _buildCategoryChip('nssf', '🏥 ប.ស.ស'),
                          _buildCategoryChip('contract', '✍️ កិច្ចសន្យា'),
                          _buildCategoryChip('utility', '⚡ ថ្លៃជួល & ទឹកភ្លើង'),
                        ],
                      ],
                    ),
                  ),

                  // Status Chips
                  Container(
                    color: colors.card,
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          _buildStatusChip('all', 'ទាំងអស់'),
                          const SizedBox(width: 8),
                          _buildStatusChip('valid', 'សុពលភាព', count: _summary.totalCount - _summary.expiringSoonCount - _summary.expiredCount),
                          const SizedBox(width: 8),
                          _buildStatusChip('expiring_soon', 'ជិតផុត', count: _summary.expiringSoonCount, color: Colors.orange),
                          const SizedBox(width: 8),
                          _buildStatusChip('expired', 'ផុតកំណត់', count: _summary.expiredCount, color: Colors.red),
                        ],
                      ),
                    ),
                  ),

                  const Divider(height: 1),

                  // Expiry Alert Banner (if any)
                  if (_expiringAlerts.isNotEmpty && _selectedStatus == 'all')
                    Container(
                      margin: const EdgeInsets.all(12),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        border: Border.all(color: Colors.amber.shade300),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800, size: 24),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'មានឯកសារ ${_summary.expiringSoonCount} ជិតផុតកំណត់ និង ${_summary.expiredCount} បានផុតកំណត់!',
                              style: TextStyle(
                                color: Colors.amber.shade900,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() => _selectedStatus = 'expiring_soon');
                              _fetchDocuments(reset: true);
                            },
                            child: const Text('ពិនិត្យ', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),

                  // Documents List
                  Expanded(
                    child: _documents.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.folder_open, size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                Text(
                                  'មិនមានឯកសារត្រូវបានរកឃើញឡើយ',
                                  style: TextStyle(color: colors.textSecondary, fontSize: 15),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'ចុចប៊ូតុង (+) ខាងក្រោមដើម្បីបញ្ចូលឯកសារថ្មី',
                                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                            itemCount: _documents.length + (_isLoadingMore ? 1 : 0),
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              if (index == _documents.length) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(12),
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }
                              final doc = _documents[index];
                              return _buildDocumentCard(doc, colors);
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCategoryChip(String code, String label) {
    final isSelected = _selectedCategory == code;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        selected: isSelected,
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : Colors.black87,
          ),
        ),
        backgroundColor: Colors.grey.shade100,
        selectedColor: Theme.of(context).primaryColor,
        checkmarkColor: Colors.white,
        showCheckmark: false,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onSelected: (selected) {
          setState(() => _selectedCategory = code);
          _fetchDocuments(reset: true);
        },
      ),
    );
  }

  Widget _buildStatusChip(String status, String label, {int? count, Color? color}) {
    final isSelected = _selectedStatus == status;
    final activeColor = color ?? Theme.of(context).primaryColor;

    return InkWell(
      onTap: () {
        setState(() => _selectedStatus = status);
        _fetchDocuments(reset: true);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.15) : Colors.transparent,
          border: Border.all(
            color: isSelected ? activeColor : Colors.grey.shade300,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? activeColor : Colors.grey.shade700,
              ),
            ),
            if (count != null && count > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected ? activeColor : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : Colors.grey.shade800,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentCard(CompanyDocumentItem doc, AppColors colors) {
    final statusColor = _getStatusColor(doc.calculatedStatus);
    final iconData = _getCategoryIcon(doc.categoryCode);

    return InkWell(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CompanyDocumentDetailScreen(document: doc),
          ),
        );
        if (result == true) {
          _fetchDocuments(reset: true);
          _fetchAlerts();
        }
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.divider.withValues(alpha: 0.5)),
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
            // Row 1: Category icon + Title + Status Badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: FaIcon(iconData, size: 16, color: statusColor),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc.title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: colors.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              doc.categoryName,
                              style: TextStyle(
                                fontSize: 11,
                                color: colors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (doc.docNumber != null && doc.docNumber!.isNotEmpty) ...[
                            Text(' • ', style: TextStyle(color: colors.textSecondary)),
                            Flexible(
                              child: Text(
                                doc.docNumber!,
                                style: TextStyle(fontSize: 11, color: colors.textSecondary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                          if (doc.attachments.length > 1) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: colors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.attach_file, size: 10, color: colors.primary),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${doc.attachments.length}',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: colors.primary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    _getStatusLabel(doc.calculatedStatus),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // Row 2: Branch & Expiry info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 14, color: colors.textSecondary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          doc.branchName,
                          style: TextStyle(fontSize: 11, color: colors.textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (doc.expiryDate != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 12, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        'ផុតកំណត់៖ ${doc.expiryDate}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
              ],
            ),

            // Row 3: Cost / Holder (if available)
            if (doc.formattedCost != null || (doc.holderName != null && doc.holderName!.isNotEmpty)) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (doc.holderName != null && doc.holderName!.isNotEmpty)
                    Expanded(
                      child: Text(
                        'ម្ចាស់៖ ${doc.holderName}',
                        style: TextStyle(fontSize: 11, color: colors.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                  if (doc.formattedCost != null)
                    Text(
                      'ចំណាយ៖ ${doc.formattedCost}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: colors.primary,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
