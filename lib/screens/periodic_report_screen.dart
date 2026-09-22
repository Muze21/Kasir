import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/pos_models.dart';
import '../services/database_service.dart';

class PeriodicReportScreen extends StatefulWidget {
  const PeriodicReportScreen({super.key});

  @override
  State<PeriodicReportScreen> createState() => _PeriodicReportScreenState();
}

class _PeriodicReportScreenState extends State<PeriodicReportScreen> {
  final _db = DatabaseService();

  // 0: 7 Hari Terakhir (Mingguan), 1: Bulan Ini, 2: 30 Hari Terakhir, 3: Hari Ini
  int _selectedPeriodIndex = 0;
  bool _isLoading = true;
  PeriodicReportData? _reportData;
  String? _errorMessage;

  static final _rupiah = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);
  static final _dateFmt = DateFormat('d MMMM yyyy', 'id_ID');
  static final _shortDateFmt = DateFormat('d MMM', 'id_ID');

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  void _getRangeForSelectedPeriod(void Function(DateTime start, DateTime end) callback) {
    final now = DateTime.now();
    DateTime start;
    DateTime end = DateTime(now.year, now.month, now.day, 23, 59, 59);

    switch (_selectedPeriodIndex) {
      case 0: // 7 Hari Terakhir
        start = DateTime(now.year, now.month, now.day - 6, 0, 0, 0);
        break;
      case 1: // Bulan Ini (Kalender)
        start = DateTime(now.year, now.month, 1, 0, 0, 0);
        break;
      case 2: // 30 Hari Terakhir
        start = DateTime(now.year, now.month, now.day - 29, 0, 0, 0);
        break;
      case 3: // Hari Ini
      default:
        start = DateTime(now.year, now.month, now.day, 0, 0, 0);
        break;
    }
    callback(start, end);
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      DateTime start = DateTime.now();
      DateTime end = DateTime.now();
      _getRangeForSelectedPeriod((s, e) {
        start = s;
        end = e;
      });

      final data = await _db.getPeriodicReport(startDate: start, endDate: end);
      if (!mounted) return;
      setState(() {
        _reportData = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Laporan Toko',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
            letterSpacing: -0.4,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync_outlined, size: 20, color: Color(0xFF64748B)),
            tooltip: 'Perbarui Laporan',
            onPressed: _loadReport,
          ),
          const SizedBox(width: 8),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE2E8F0)),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A)))
          : _errorMessage != null
              ? _buildErrorState()
              : _buildReportContent(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40, color: Color(0xFFDC2626)),
            const SizedBox(height: 12),
            const Text(
              'Gagal Memuat Laporan',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 6),
            Text(
              '$_errorMessage',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
              ),
              onPressed: _loadReport,
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportContent() {
    final report = _reportData!;
    final dateRangeStr =
        '${_shortDateFmt.format(report.startDate)} - ${_dateFmt.format(report.endDate)}';

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Selector Periode (Horizontal Scrollable)
              _buildPeriodSelector(),

              const SizedBox(height: 14),

              // 2. Info Periode Terpilih
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF64748B)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        dateRangeStr,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    Text(
                      '${report.totalOrders} transaksi',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 3. Hero Finansial: Kas Masuk Bersih (Profit)
              _buildProfitHeroCard(report),

              const SizedBox(height: 12),

              // 4. Bento Grid: Total Omzet & Pengeluaran
              _buildBentoFinancialGrid(report),

              const SizedBox(height: 18),

              // 5. Grafik Tren Omzet Harian
              if (report.dailySummaries.length > 1) ...[
                _buildDailyChartCard(report.dailySummaries),
                const SizedBox(height: 18),
              ],

              // 6. Menu Terlaris (Top Selling Items)
              _buildTopSellingItemsCard(report.topItems),

              const SizedBox(height: 18),

              // 7. Pengeluaran Operasional Periode
              _buildExpensesListCard(report.expenses),

              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  // Filter Chips Periode
  Widget _buildPeriodSelector() {
    final periods = ['7 Hari Terakhir', 'Bulan Ini', '30 Hari Terakhir', 'Hari Ini'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: periods.asMap().entries.map((entry) {
          final idx = entry.key;
          final title = entry.value;
          final isSelected = _selectedPeriodIndex == idx;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(title),
              selected: isSelected,
              onSelected: (_) {
                if (_selectedPeriodIndex != idx) {
                  setState(() => _selectedPeriodIndex = idx);
                  _loadReport();
                }
              },
              selectedColor: const Color(0xFF0F172A),
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              visualDensity: VisualDensity.compact,
            ),
          );
        }).toList(),
      ),
    );
  }

  // Hero Card Laba Bersih
  Widget _buildProfitHeroCard(PeriodicReportData report) {
    final omzet = report.totalOmzet;
    final cashRatio = omzet > 0 ? (report.totalCash / omzet).clamp(0.0, 1.0) : 0.0;
    final qrisRatio = omzet > 0 ? (report.totalQris / omzet).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x050F172A), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'LABA BERSIH PERIODE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _rupiah.format(report.bersih),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.0,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: report.bersih >= 0 ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      report.bersih >= 0 ? Icons.trending_up : Icons.trending_down,
                      size: 16,
                      color: report.bersih >= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      report.bersih >= 0 ? 'PROFIT' : 'DEFISIT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: report.bersih >= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Rasio Bar Tunai vs QRIS
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 7,
              child: Row(
                children: [
                  if (cashRatio > 0)
                    Expanded(
                      flex: (cashRatio * 100).round(),
                      child: Container(color: const Color(0xFF059669)),
                    ),
                  if (qrisRatio > 0)
                    Expanded(
                      flex: (qrisRatio * 100).round(),
                      child: Container(color: const Color(0xFF4F46E5)),
                    ),
                  if (omzet == 0)
                    Expanded(
                      child: Container(color: const Color(0xFFE2E8F0)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _buildPaymentBadge(
                dotColor: const Color(0xFF059669),
                label: 'Tunai:',
                value: _rupiah.format(report.totalCash),
                count: '${report.cashOrderCount} trx',
              ),
              _buildPaymentBadge(
                dotColor: const Color(0xFF4F46E5),
                label: 'QRIS:',
                value: _rupiah.format(report.totalQris),
                count: '${report.qrisOrderCount} trx',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBentoFinancialGrid(PeriodicReportData report) {
    return Row(
      children: [
        Expanded(
          child: _BentoSummaryTile(
            title: 'Total Penjualan',
            value: _rupiah.format(report.totalOmzet),
            subtitle: '${report.totalOrders} pesanan',
            icon: Icons.payments_outlined,
            badgeColor: const Color(0xFFECFDF5),
            badgeTextColor: const Color(0xFF059669),
            badgeLabel: 'OMZET',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _BentoSummaryTile(
            title: 'Pengeluaran Kasir',
            value: '-${_rupiah.format(report.totalExpenses)}',
            subtitle: '${report.expenses.length} pos biaya',
            icon: Icons.receipt_long_outlined,
            badgeColor: const Color(0xFFFEF2F2),
            badgeTextColor: const Color(0xFFDC2626),
            badgeLabel: 'PENGELUARAN',
          ),
        ),
      ],
    );
  }

  // Grafik Batang Tren Harian
  Widget _buildDailyChartCard(List<DailySummary> dailySummaries) {
    final maxOmzet = dailySummaries.fold(0.0, (max, d) => d.omzet > max ? d.omzet : max);
    final isLongPeriod = dailySummaries.length > 7;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded, size: 18, color: Color(0xFF64748B)),
              const SizedBox(width: 8),
              const Text(
                'Tren Omzet Harian',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
              const Spacer(),
              if (isLongPeriod)
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.swipe_left_rounded, size: 14, color: Color(0xFF94A3B8)),
                    SizedBox(width: 4),
                    Text(
                      'Geser grafik',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)),
                    ),
                  ],
                )
              else
                Text(
                  'Maks: ${_rupiah.format(maxOmzet)}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Bar Chart: Scrollable jika > 7 hari agar di HP tidak gepeng/rusak
          SizedBox(
            height: 140,
            child: isLongPeriod
                ? SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: dailySummaries.map((day) {
                        final ratio = maxOmzet > 0 ? (day.omzet / maxOmzet).clamp(0.06, 1.0) : 0.06;
                        final isHighest = maxOmzet > 0 && day.omzet == maxOmzet;

                        return Container(
                          width: 38,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: _buildBarItem(day, ratio, isHighest),
                        );
                      }).toList(),
                    ),
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: dailySummaries.map((day) {
                      final ratio = maxOmzet > 0 ? (day.omzet / maxOmzet).clamp(0.06, 1.0) : 0.06;
                      final isHighest = maxOmzet > 0 && day.omzet == maxOmzet;

                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: _buildBarItem(day, ratio, isHighest),
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarItem(DailySummary day, double ratio, bool isHighest) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (day.omzet > 0)
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _formatCompactK(day.omzet),
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: isHighest ? const Color(0xFF059669) : const Color(0xFF64748B),
              ),
            ),
          )
        else
          const SizedBox(height: 11),
        const SizedBox(height: 4),
        // Bar
        Container(
          height: 85 * ratio,
          decoration: BoxDecoration(
            color: day.omzet > 0
                ? (isHighest ? const Color(0xFF0F172A) : const Color(0xFF059669))
                : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 6),
        // Label Tanggal
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            DateFormat('d/M').format(day.date),
            style: TextStyle(
              fontSize: 9,
              fontWeight: isHighest ? FontWeight.w800 : FontWeight.w500,
              color: isHighest ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
            ),
          ),
        ),
      ],
    );
  }

  // Menu Terlaris (Top Selling Items)
  Widget _buildTopSellingItemsCard(List<TopItemSummary> topItems) {
    final maxQty = topItems.isNotEmpty ? topItems.first.totalQty : 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.local_fire_department_outlined, size: 18, color: Color(0xFFF59E0B)),
              SizedBox(width: 8),
              Text(
                'Menu Paling Laris',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),

          if (topItems.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('Belum ada pesanan pada periode ini.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: topItems.take(5).length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = topItems[index];
                final rank = index + 1;
                final ratio = maxQty > 0 ? (item.totalQty / maxQty).clamp(0.1, 1.0) : 0.1;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: rank == 1
                                ? const Color(0xFF0F172A)
                                : (rank == 2 ? const Color(0xFF475569) : const Color(0xFFF1F5F9)),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '#$rank',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: rank <= 2 ? Colors.white : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.itemName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                          ),
                        ),
                        Text(
                          '${item.totalQty} terjual',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF059669)),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _rupiah.format(item.totalRevenue),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 5,
                        backgroundColor: const Color(0xFFF1F5F9),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          rank == 1 ? const Color(0xFF0F172A) : const Color(0xFF059669),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  // Rincian Pengeluaran Operasional
  Widget _buildExpensesListCard(List<Expense> expenses) {
    // Agregasi per kategori
    final Map<String, double> byCat = {for (final c in ExpenseCategories.all) c: 0.0};
    for (final e in expenses) {
      byCat.update(e.category, (v) => v + e.amount, ifAbsent: () => e.amount);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_outlined, size: 18, color: Color(0xFFDC2626)),
              const SizedBox(width: 8),
              const Text(
                'Rincian Kas Keluar / Pengeluaran',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
              const Spacer(),
              Text(
                '${expenses.length} catatan',
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
            ],
          ),
          // Sub-total per kategori (jika ada pengeluaran)
          if (expenses.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: ExpenseCategories.all.where((c) => (byCat[c] ?? 0) > 0).map((cat) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: ExpenseCategories.background(cat),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$cat ${_rupiah.format(byCat[cat]!)}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: ExpenseCategories.textColor(cat),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 8),

          if (expenses.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('Tidak ada pengeluaran pada periode ini.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: expenses.length,
              separatorBuilder: (context, index) => const Divider(height: 12, color: Color(0xFFF8FAFC)),
              itemBuilder: (context, index) {
                final e = expenses[index];

                return Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: ExpenseCategories.background(e.category),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        ExpenseCategories.icons[e.category] ?? Icons.receipt_long_outlined,
                        size: 14,
                        color: ExpenseCategories.textColor(e.category),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: ExpenseCategories.background(e.category),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  e.category,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: ExpenseCategories.textColor(e.category),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  e.note,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '${_shortDateFmt.format(e.createdAt.toLocal())} • oleh ${e.profile?.fullName ?? 'anggota'}',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '-${_rupiah.format(e.amount)}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFFDC2626)),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildPaymentBadge({
    required Color dotColor,
    required String label,
    required String value,
    required String count,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        const SizedBox(width: 4),
        Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
        const SizedBox(width: 3),
        Text('($count)', style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
      ],
    );
  }

  String _formatCompactK(double value) {
    if (value >= 1000000) {
      final v = value / 1000000;
      return '${v.toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      final v = (value / 1000).round();
      return '${v}k';
    }
    return value.toStringAsFixed(0);
  }
}

class _BentoSummaryTile extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color badgeColor;
  final Color badgeTextColor;
  final String badgeLabel;

  const _BentoSummaryTile({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.badgeColor,
    required this.badgeTextColor,
    required this.badgeLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badgeLabel,
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: badgeTextColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(icon, size: 12, color: const Color(0xFF94A3B8)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
