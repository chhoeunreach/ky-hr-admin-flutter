import 'package:flutter/material.dart';

import 'package:cnattendance/theme/enterprise_theme.dart';
import 'delivery_api.dart';
import 'delivery_model.dart';
import 'delivery_create_screen.dart';
import 'active_delivery_screen.dart';

class DeliveryDashboardScreen extends StatefulWidget {
  const DeliveryDashboardScreen({super.key});

  @override
  State<DeliveryDashboardScreen> createState() =>
      _DeliveryDashboardScreenState();
}

class _DeliveryDashboardScreenState extends State<DeliveryDashboardScreen> {
  final _api = DeliveryApi();

  DeliveryModel? _activeDelivery;
  List<DeliveryModel> _deliveries = [];
  bool _isLoading = true;
  bool _loadFailed = false;
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final active = await _api.getActiveDelivery();
      final list = await _api.getDeliveries(status: _selectedFilter);
      if (mounted) {
        setState(() {
          _activeDelivery = active;
          _deliveries = list;
          _isLoading = false;
          _loadFailed = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadFailed = true;
        });
      }
    }
  }

  void _openCreate() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DeliveryCreateScreen()),
    );
    _loadData();
  }

  void _openActive(DeliveryModel delivery) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ActiveDeliveryScreen(delivery: delivery),
      ),
    );
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = EnterpriseTheme.of(context);
    final surface = theme.contentSurface;
    final primary = theme.primary;

    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        title: const Text(
          '🛵 ការដឹកជញ្ជូន (Delivery Service)',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
        elevation: 0.5,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading || _loadFailed
            ? null
            : _activeDelivery == null
                ? _openCreate
                : () => _openActive(_activeDelivery!),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        icon: Icon(
            _activeDelivery == null ? Icons.add : Icons.local_shipping_rounded),
        label: Text(
          _loadFailed
              ? 'សូមពិនិត្យការតភ្ជាប់'
              : _activeDelivery == null
                  ? 'ចេញដឹកថ្មី'
                  : 'បន្តការដឹកជញ្ជូន',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_loadFailed)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'មិនអាចពិនិត្យស្ថានភាព Delivery បានទេ។ សូមចុច refresh មុនបង្កើតថ្មី។',
                      ),
                    ),
                  // Active Delivery Banner if any
                  if (_activeDelivery != null) ...[
                    InkWell(
                      onTap: () => _openActive(_activeDelivery!),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF059669), Color(0xFF10B981)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF059669)
                                  .withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.25),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.two_wheeler_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'ការដឹកជញ្ជូនកំពុងដំណើរការ',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'អ្នកទទួល៖ ${_activeDelivery!.customerName} (${_activeDelivery!.customerPhone})',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _filterChip('all', 'ទាំងអស់'),
                        const SizedBox(width: 8),
                        _filterChip('active', 'កំពុងដឹក'),
                        const SizedBox(width: 8),
                        _filterChip('completed', 'បានបញ្ចប់'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Deliveries list
                  if (_deliveries.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Column(
                          children: [
                            Icon(Icons.inventory_2_outlined,
                                size: 48, color: theme.mutedText),
                            const SizedBox(height: 12),
                            Text(
                              'មិនមានទិន្នន័យដឹកជញ្ជូនឡើយ',
                              style: TextStyle(
                                color: theme.mutedText,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._deliveries
                        .map((item) => _buildDeliveryCard(item, theme)),
                  const SizedBox(height: 60),
                ],
              ),
      ),
    );
  }

  Widget _filterChip(String key, String label) {
    final isSelected = _selectedFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) {
          setState(() => _selectedFilter = key);
          _loadData();
        }
      },
    );
  }

  Widget _buildDeliveryCard(DeliveryModel item, EnterpriseTheme theme) {
    final isDelivered = item.status == 'delivered';
    final isCancelled = item.status == 'cancelled';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.cardBorder),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: isDelivered
              ? Colors.green.shade50
              : (isCancelled ? Colors.red.shade50 : Colors.blue.shade50),
          child: Icon(
            isDelivered
                ? Icons.check_circle_outline
                : (isCancelled ? Icons.cancel_outlined : Icons.two_wheeler),
            color: isDelivered
                ? Colors.green.shade700
                : (isCancelled ? Colors.red.shade700 : Colors.blue.shade700),
          ),
        ),
        title: Text(
          item.customerName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${item.customerPhone} ${item.invoiceNumber != null ? "• ${item.invoiceNumber}" : ""}',
              style: TextStyle(fontSize: 12, color: theme.mutedText),
            ),
            if (item.destinationAddress != null) ...[
              const SizedBox(height: 2),
              Text(
                item.destinationAddress!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, color: theme.mutedText),
              ),
            ],
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isDelivered
                ? Colors.green.shade100
                : (isCancelled ? Colors.red.shade100 : Colors.blue.shade100),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            item.statusLabel,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isDelivered
                  ? Colors.green.shade800
                  : (isCancelled ? Colors.red.shade800 : Colors.blue.shade800),
            ),
          ),
        ),
        onTap: item.isActive ? () => _openActive(item) : null,
      ),
    );
  }
}
