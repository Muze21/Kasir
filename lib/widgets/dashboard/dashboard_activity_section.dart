import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/pos_models.dart';

class DashboardActivitySection extends StatefulWidget {
  final List<Order> recentOrders;
  final List<Expense> recentExpenses;

  const DashboardActivitySection({
    super.key,
    required this.recentOrders,
    required this.recentExpenses,
  });

  @override
  State<DashboardActivitySection> createState() => _DashboardActivitySectionState();
}

class _DashboardActivitySectionState extends State<DashboardActivitySection> {
  int _activityFilterIndex = 0; // 0: Semua, 1: Pesanan, 2: Pengeluaran

  static final _rupiah = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);
  static final _waktu = DateFormat.Hm('id_ID');

  @override
  Widget build(BuildContext context) {
    final List<_ActivityItem> allActivities = [
      ...widget.recentOrders.map((o) => _ActivityItem.order(o)),
      ...widget.recentExpenses.map((e) => _ActivityItem.expense(e)),
    ];
    allActivities.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    List<_ActivityItem> filteredActivities;
    if (_activityFilterIndex == 1) {
      filteredActivities = allActivities.where((a) => a.isOrder).toList();
    } else if (_activityFilterIndex == 2) {
      filteredActivities = allActivities.where((a) => !a.isOrder).toList();
    } else {
      filteredActivities = allActivities;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 480;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Aktivitas: Ditumpuk vertikal jika di layar HP agar tidak overflow
            if (isMobile) ...[
              const Text(
                'AKTIVITAS TRANSAKSI',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 10),
              _buildFilterTabs(allActivities.length),
            ] else ...[
              Row(
                children: [
                  const Text(
                    'AKTIVITAS TRANSAKSI',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const Spacer(),
                  _buildFilterTabs(allActivities.length),
                ],
              ),
            ],

            const SizedBox(height: 12),

            // Card Container List Aktivitas
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: filteredActivities.isEmpty
                  ? _buildEmptyActivityState()
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: filteredActivities.length,
                      separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      itemBuilder: (context, index) {
                        final item = filteredActivities[index];
                        if (item.isOrder) {
                          return _buildOrderRow(item.order!);
                        } else {
                          return _buildExpenseRow(item.expense!);
                        }
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilterTabs(int allCount) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ActivityFilterTab(
            label: 'Semua ($allCount)',
            isSelected: _activityFilterIndex == 0,
            onTap: () => setState(() => _activityFilterIndex = 0),
          ),
          _ActivityFilterTab(
            label: 'Pesanan (${widget.recentOrders.length})',
            isSelected: _activityFilterIndex == 1,
            onTap: () => setState(() => _activityFilterIndex = 1),
          ),
          _ActivityFilterTab(
            label: 'Biaya (${widget.recentExpenses.length})',
            isSelected: _activityFilterIndex == 2,
            onTap: () => setState(() => _activityFilterIndex = 2),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderRow(Order order) {
    final isQris = order.paymentMethod == 'qris';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            alignment: Alignment.center,
            child: Text(
              '#${order.queueNumber}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        order.customerName?.isNotEmpty == true
                            ? order.customerName!
                            : 'Pelanggan #${order.queueNumber}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: isQris ? const Color(0xFFEEF2FF) : const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isQris ? 'QRIS' : 'TUNAI',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: isQris ? const Color(0xFF4F46E5) : const Color(0xFF059669),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${_waktu.format(order.createdAt.toLocal())} WIB • ${order.profile?.fullName ?? 'kasir'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _rupiah.format(order.totalAmount),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseRow(Expense expense) {
    final cat = expense.category;
    final catColors = ExpenseCategories.textColor(cat);
    final catBg = ExpenseCategories.background(cat);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: catBg,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(
              ExpenseCategories.icons[cat] ?? Icons.receipt_long_outlined,
              size: 16,
              color: catColors,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: catBg,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: catColors,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        expense.note,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${_waktu.format(expense.createdAt.toLocal())} WIB • ${expense.profile?.fullName ?? 'anggota'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '-${_rupiah.format(expense.amount)}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: Color(0xFFDC2626),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyActivityState() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.receipt_long_outlined, size: 32, color: Color(0xFF94A3B8)),
            SizedBox(height: 10),
            Text(
              'Belum Ada Aktivitas Transaksi',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
            ),
            SizedBox(height: 4),
            Text(
              'Pesanan pelanggan dan pengeluaran kasir akan tercatat otomatis di sini.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityFilterTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ActivityFilterTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }
}

class _ActivityItem {
  final bool isOrder;
  final DateTime createdAt;
  final Order? order;
  final Expense? expense;

  _ActivityItem.order(this.order)
      : isOrder = true,
        createdAt = order!.createdAt,
        expense = null;

  _ActivityItem.expense(this.expense)
      : isOrder = false,
        createdAt = expense!.createdAt,
        order = null;
}
