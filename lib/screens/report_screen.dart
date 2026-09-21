import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../models/pos_models.dart';
import '../services/database_service.dart';
import '../services/receipt_service.dart';

class ReportScreen extends StatefulWidget {
  final String shiftId;
  final String? shiftTitle;

  const ReportScreen({
    super.key,
    required this.shiftId,
    this.shiftTitle,
  });

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _supabase = Supabase.instance.client;
  final _db = DatabaseService();

  bool _loading = true;
  String? _error;

  Shift? _shift;
  double _omzet = 0.0;
  int _totalOrders = 0;
  int _completedOrdersCount = 0;
  int _voidedOrdersCount = 0;
  double _voidedTotal = 0.0;
  double _pengeluaran = 0.0;
  double _bersih = 0.0;

  double _mixCash = 0.0;
  double _mixQris = 0.0;
  int _cashCount = 0;
  int _qrisCount = 0;

  List<Map<String, dynamic>> _transaksi = [];
  List<Map<String, dynamic>> _pengeluaranList = [];
  List<Map<String, dynamic>> _perKasir = [];

  // Filter aktivitas: 0 = Semua, 1 = Penjualan, 2 = Pengeluaran
  int _selectedFilter = 0;

  static final _rupiah = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);
  static final _timeFmt = DateFormat.Hm('id_ID');
  static final _dateFmt = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 1. Ambil data Shift untuk header sesi
      final shiftData = await _db.getShiftById(widget.shiftId);

      // 2. Ambil orders dan expenses dari Supabase
      final ordersRes = await _supabase
          .from('orders')
          .select('*, profiles(id, full_name), order_items(item_name, qty, price, subtotal)')
          .eq('shift_id', widget.shiftId)
          .order('queue_number', ascending: true);

      final expensesRes = await _supabase
          .from('expenses')
          .select('id, note, amount, category, user_id, created_at, profiles(id, full_name)')
          .eq('shift_id', widget.shiftId)
          .order('created_at', ascending: true);

      final orders = (ordersRes as List<dynamic>).cast<Map<String, dynamic>>();
      final expenses = (expensesRes as List<dynamic>).cast<Map<String, dynamic>>();

      // 3. HITUNG TOTAL & STATISTIK
      double omzet = 0.0;
      double cCash = 0.0;
      double cQris = 0.0;
      int cashCount = 0;
      int qrisCount = 0;
      int completedOrders = 0;
      int voidedOrders = 0;
      double voidedTotal = 0.0;

      for (final o in orders) {
        final status = (o['status'] as String?) ?? 'completed';
        final amt = (o['total_amount'] as num).toDouble();

        if (status == 'voided') {
          voidedOrders++;
          voidedTotal += amt;
          continue;
        }

        omzet += amt;
        completedOrders++;
        final p = (o['payment_method'] as String?) ?? 'cash';
        if (p == 'qris') {
          cQris += amt;
          qrisCount++;
        } else {
          cCash += amt;
          cashCount++;
        }
      }

      double totalExp = 0.0;
      for (final e in expenses) {
        totalExp += (e['amount'] as num).toDouble();
      }

      final bersih = omzet - totalExp;

      // 4. STRUKTUR TRANSAKSI UNTUK UI
      final transaksi = orders.map((o) {
        final prof = o['profiles'];
        final status = (o['status'] as String?) ?? 'completed';
        return {
          'queue': o['queue_number'] ?? 0,
          'name': o['customer_name'] ?? 'Pelanggan ${o['queue_number']}',
          'total': (o['total_amount'] as num).toDouble(),
          'pay': (o['payment_method'] as String?) ?? 'cash',
          'status': status,
          'voidReason': o['void_reason'] as String?,
          'inputBy': prof != null ? (prof['full_name'] as String) : 'Kasir',
          'items': (o['order_items'] as List<dynamic>?) ?? [],
          'created': o['created_at'] != null ? DateTime.parse(o['created_at'] as String).toLocal() : null,
        };
      }).toList();

final pengeluaranList = expenses.map((e) {
        final prof = e['profiles'];
        return {
          'note': e['note'] as String,
          'amount': (e['amount'] as num).toDouble(),
          'category': (e['category'] as String?) ?? 'Operasional',
          'inputBy': prof != null ? (prof['full_name'] as String) : 'anggota',
          'created': e['created_at'] != null ? DateTime.parse(e['created_at'] as String).toLocal() : null,
        };
      }).toList();

      // 5. REKAP PER KASIR
      final Map<String, _CashierAcc> acc = {};

      for (final o in orders) {
        final status = (o['status'] as String?) ?? 'completed';
        if (status == 'voided') {
          continue;
        }

        final uid = o['user_id'] as String;
        final prof = o['profiles'];
        final nama = prof != null ? (prof['full_name'] as String) : 'User ($uid)';
        final amt = (o['total_amount'] as num).toDouble();
        acc.putIfAbsent(uid, () => _CashierAcc(name: nama, uid: uid));
        acc[uid]!.omzet += amt;
        acc[uid]!.jumOrder += 1;
      }

      for (final e in expenses) {
        final uid = e['user_id'] as String;
        final prof = e['profiles'];
        final nama = prof != null ? (prof['full_name'] as String) : 'User ($uid)';
        final amt = (e['amount'] as num).toDouble();
        acc.putIfAbsent(uid, () => _CashierAcc(name: nama, uid: uid));
        acc[uid]!.pengeluaran += amt;
      }

      final perKasir = acc.values.map((a) => {
        'name': a.name,
        'omzet': a.omzet,
        'exp': a.pengeluaran,
        'jum': a.jumOrder,
        'bersih': a.omzet - a.pengeluaran,
      }).toList();

      if (!mounted) {
        return;
      }

      setState(() {
        _shift = shiftData;
        _omzet = omzet;
        _totalOrders = orders.length;
        _completedOrdersCount = completedOrders;
        _voidedOrdersCount = voidedOrders;
        _voidedTotal = voidedTotal;
        _pengeluaran = totalExp;
        _bersih = bersih;
        _mixCash = cCash;
        _mixQris = cQris;
        _cashCount = cashCount;
        _qrisCount = qrisCount;
        _transaksi = transaksi;
        _pengeluaranList = pengeluaranList;
        _perKasir = perKasir;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOpen = _shift?.isOpen ?? false;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.shiftTitle ?? 'Laporan Sesi Shift',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: -0.4,
              ),
            ),
            if (_shift != null)
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isOpen ? const Color(0xFF059669) : const Color(0xFF94A3B8),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    isOpen ? 'Sesi Aktif' : 'Sesi Ditutup',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isOpen ? const Color(0xFF059669) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
          ],
        ),
        actions: [
          if (!_loading && _error == null && _shift != null)
            IconButton(
              icon: const Icon(Icons.share_outlined, size: 21, color: Color(0xFF0F172A)),
              tooltip: 'Bagikan Rekap Shift',
              onPressed: () {
                ReceiptService.showShareShiftReportModal(
                  context: context,
                  shiftStatus: _shift?.status ?? 'closed',
                  openedAt: _shift?.openedAt ?? DateTime.now(),
                  closedAt: _shift?.closedAt,
                  openerName: _shift?.opener?.fullName,
                  closerName: _shift?.closer?.fullName,
                  omzet: _omzet,
                  cashTotal: _mixCash,
                  qrisTotal: _mixQris,
                  cashCount: _cashCount,
                  qrisCount: _qrisCount,
                  expensesTotal: _pengeluaran,
                  expenseCount: _pengeluaranList.length,
                  bersih: _bersih,
                  completedOrdersCount: _completedOrdersCount,
                  voidedOrdersCount: _voidedOrdersCount,
                  voidedTotal: _voidedTotal,
                  perKasir: _perKasir,
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 21, color: Color(0xFF64748B)),
            tooltip: 'Muat Ulang Data',
            onPressed: _load,
          ),
          const SizedBox(width: 6),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE2E8F0)),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F172A)))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFDC2626)),
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: _load,
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: const Color(0xFF0F172A),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1. Shift Session Banner
                        _buildShiftSessionBanner(isOpen),

                        const SizedBox(height: 14),

                        // 2. Hero Card: Kas Bersih & Rasio Pembayaran
                        _buildHeroFinancialCard(),

                        const SizedBox(height: 14),

                        // 3. Bento Grid 4 Metrik
                        _buildBentoMetricsGrid(isMobile),

                        if (_pengeluaranList.isNotEmpty) ...[
                          const SizedBox(height: 18),

                          // 3b. Breakdown Pengeluaran per Kategori
                          _buildExpenseCategoryBreakdown(),
                        ],

                        const SizedBox(height: 18),

                        // 4. Kontribusi Per Kasir
                        if (_perKasir.isNotEmpty) ...[
                          _buildCashierContributionSection(),
                          const SizedBox(height: 18),
                        ],

                        // 5. Activity Log (Transaksi & Pengeluaran)
                        _buildActivityLogSection(),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
    );
  }

  // --- WIDGET KOMPONEN ---

  Widget _buildShiftSessionBanner(bool isOpen) {
    final openedAt = _shift?.openedAt;
    final closedAt = _shift?.closedAt;
    final openerName = _shift?.opener?.fullName ?? 'Petugas';
    final closerName = _shift?.closer?.fullName;

    String durationStr = '-';
    if (openedAt != null) {
      final diff = (closedAt ?? DateTime.now()).difference(openedAt);
      final hours = diff.inHours;
      final mins = diff.inMinutes.remainder(60);
      durationStr = '${hours > 0 ? '$hours jam ' : ''}$mins menit';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: isOpen ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isOpen ? const Color(0xFF10B981).withAlpha(80) : const Color(0xFFCBD5E1),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isOpen ? const Color(0xFF059669) : const Color(0xFF64748B),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isOpen ? 'SESI AKTIF BERJALAN' : 'SESI SUDAH DITUTUP',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: isOpen ? const Color(0xFF059669) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              const Icon(Icons.timer_outlined, size: 14, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Text(
                'Durasi: $durationStr',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Dibuka oleh $openerName${openedAt != null ? ' (${_dateFmt.format(openedAt)})' : ''}'
            '${closedAt != null ? ' • Ditutup oleh ${closerName ?? openerName} (${_timeFmt.format(closedAt)})' : ''}'
            ' • $_totalOrders pesanan',
            style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroFinancialCard() {
    final cashRatio = _omzet > 0 ? (_mixCash / _omzet).clamp(0.0, 1.0) : 0.0;
    final qrisRatio = _omzet > 0 ? (_mixQris / _omzet).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'KAS MASUK BERSIH SAAT INI',
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
                        _rupiah.format(_bersih),
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
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _bersih >= 0 ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _bersih >= 0 ? const Color(0xFF10B981).withAlpha(80) : const Color(0xFFDC2626).withAlpha(80),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _bersih >= 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                      size: 14,
                      color: _bersih >= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      _bersih >= 0 ? 'Surplus' : 'Defisit',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _bersih >= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Visual Ratio Bar: Tunai di Laci vs QRIS
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 8,
              child: Row(
                children: [
                  if (_omzet == 0)
                    Expanded(child: Container(color: const Color(0xFFE2E8F0)))
                  else ...[
                    if (cashRatio > 0)
                      Expanded(
                        flex: (cashRatio * 100).round().clamp(1, 100),
                        child: Container(color: const Color(0xFF059669)),
                      ),
                    if (qrisRatio > 0)
                      Expanded(
                        flex: (qrisRatio * 100).round().clamp(1, 100),
                        child: Container(color: const Color(0xFF2563EB)),
                      ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _buildPaymentLegend(
                dotColor: const Color(0xFF059669),
                label: 'Tunai di Laci:',
                value: _rupiah.format(_mixCash),
                count: '$_cashCount trx',
              ),
              _buildPaymentLegend(
                dotColor: const Color(0xFF2563EB),
                label: 'QRIS:',
                value: _rupiah.format(_mixQris),
                count: '$_qrisCount trx',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseCategoryBreakdown() {
    final Map<String, double> byCat = {for (final c in ExpenseCategories.all) c: 0.0};
    double grand = 0.0;
    for (final p in _pengeluaranList) {
      final cat = (p['category'] as String?) ?? 'Operasional';
      final amt = (p['amount'] as num).toDouble();
      byCat.update(cat, (v) => v + amt, ifAbsent: () => amt);
      grand += amt;
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
          const Row(
            children: [
              Icon(Icons.pie_chart_outline, size: 18, color: Color(0xFFDC2626)),
              SizedBox(width: 8),
              Text(
                'Pengeluaran per Kategori',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),
          for (final cat in ExpenseCategories.all)
            if ((byCat[cat] ?? 0) > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: ExpenseCategories.background(cat),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              ExpenseCategories.icons[cat] ?? Icons.receipt_long_outlined,
                              size: 14,
                              color: ExpenseCategories.textColor(cat),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            cat,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: grand > 0 ? (byCat[cat]! / grand).clamp(0.04, 1.0) : 0.0,
                          minHeight: 6,
                          backgroundColor: const Color(0xFFF1F5F9),
                          valueColor: AlwaysStoppedAnimation<Color>(ExpenseCategories.textColor(cat)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 110,
                      child: Text(
                        _rupiah.format(byCat[cat]),
                        textAlign: TextAlign.end,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildPaymentLegend({
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
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
        ),
        const SizedBox(width: 3),
        Text(
          '($count)',
          style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
        ),
      ],
    );
  }

  Widget _buildBentoMetricsGrid(bool isMobile) {
    final aov = _completedOrdersCount > 0 ? _omzet / _completedOrdersCount : 0.0;

    final cards = [
      _BentoCard(
        title: 'Total Penjualan',
        value: _rupiah.format(_omzet),
        subtitle: '$_completedOrdersCount transaksi sukses',
        icon: Icons.payments_outlined,
        badgeLabel: 'OMZET',
        badgeColor: const Color(0xFFECFDF5),
        badgeTextColor: const Color(0xFF059669),
      ),
      _BentoCard(
        title: 'Pengeluaran Kasir',
        value: '-${_rupiah.format(_pengeluaran)}',
        subtitle: '${_pengeluaranList.length} biaya dicatat',
        icon: Icons.shopping_bag_outlined,
        badgeLabel: 'KAS KELUAR',
        badgeColor: const Color(0xFFFEF2F2),
        badgeTextColor: const Color(0xFFDC2626),
      ),
      _BentoCard(
        title: 'Rata-rata / Pesanan',
        value: _rupiah.format(aov),
        subtitle: 'Average order value',
        icon: Icons.receipt_outlined,
        badgeLabel: 'AOV',
        badgeColor: const Color(0xFFEFF6FF),
        badgeTextColor: const Color(0xFF2563EB),
      ),
      _BentoCard(
        title: 'Pesanan Batal (Void)',
        value: '$_voidedOrdersCount pesanan',
        subtitle: _voidedOrdersCount > 0 ? 'Total: ${_rupiah.format(_voidedTotal)}' : 'Tidak ada pembatalan',
        icon: Icons.cancel_outlined,
        badgeLabel: 'VOID',
        badgeColor: _voidedOrdersCount > 0 ? const Color(0xFFFEF2F2) : const Color(0xFFF1F5F9),
        badgeTextColor: _voidedOrdersCount > 0 ? const Color(0xFFDC2626) : const Color(0xFF64748B),
      ),
    ];

    if (isMobile) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 10),
              Expanded(child: cards[1]),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: cards[2]),
              const SizedBox(width: 10),
              Expanded(child: cards[3]),
            ],
          ),
        ],
      );
    } else {
      return Row(
        children: [
          for (int i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: cards[i]),
          ],
        ],
      );
    }
  }

  Widget _buildCashierContributionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'KONTRIBUSI KASIR',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${_perKasir.length}',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (final k in _perKasir)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: const Color(0xFFF1F5F9),
                      child: Text(
                        (k['name'] as String).isNotEmpty ? (k['name'] as String)[0].toUpperCase() : 'K',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        k['name'] as String,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        '${k['jum']} pesanan',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Omzet', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _rupiah.format(k['omzet']),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 24, color: const Color(0xFFE2E8F0)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Pengeluaran', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '-${_rupiah.format(k['exp'])}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFDC2626)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 24, color: const Color(0xFFE2E8F0)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Net Bersih', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _rupiah.format(k['bersih']),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF059669)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildActivityLogSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'RINCIAN AKTIVITAS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
                color: Color(0xFF64748B),
              ),
            ),
            const Spacer(),
          ],
        ),
        const SizedBox(height: 10),

        // Filter Tabs
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip(0, 'Semua (${_transaksi.length + _pengeluaranList.length})'),
              const SizedBox(width: 8),
              _buildFilterChip(1, 'Penjualan (${_transaksi.length})'),
              const SizedBox(width: 8),
              _buildFilterChip(2, 'Pengeluaran (${_pengeluaranList.length})'),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Content
        if (_selectedFilter == 0) ...[
          if (_transaksi.isEmpty && _pengeluaranList.isEmpty)
            _buildEmptyState('Belum ada transaksi atau pengeluaran pada shift ini.')
          else ...[
            for (final t in _transaksi) _buildOrderCard(t),
            for (final p in _pengeluaranList) _buildExpenseCard(p),
          ],
        ] else if (_selectedFilter == 1) ...[
          if (_transaksi.isEmpty)
            _buildEmptyState('Belum ada transaksi penjualan pada shift ini.')
          else
            for (final t in _transaksi) _buildOrderCard(t),
        ] else ...[
          if (_pengeluaranList.isEmpty)
            _buildEmptyState('Belum ada pengeluaran dicatat pada shift ini.')
          else
            for (final p in _pengeluaranList) _buildExpenseCard(p),
        ],
      ],
    );
  }

  Widget _buildFilterChip(int index, String label) {
    final isSelected = _selectedFilter == index;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = index),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> t) {
    final isVoided = t['status'] == 'voided';
    final isQris = t['pay'] == 'qris';
    final items = (t['items'] as List<dynamic>?) ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isVoided ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0),
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Queue badge
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isVoided ? const Color(0xFFFEF2F2) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '#${t['queue']}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: isVoided ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            t['name'] as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: isVoided ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                              decoration: isVoided ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: isQris ? const Color(0xFFEFF6FF) : const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isQris ? 'QRIS' : 'TUNAI',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: isQris ? const Color(0xFF2563EB) : const Color(0xFF059669),
                            ),
                          ),
                        ),
                        if (isVoided) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'BATAL',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFFDC2626)),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Oleh: ${t['inputBy']}${t['created'] != null ? ' · ${_timeFmt.format(t['created'] as DateTime)}' : ''}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Text(
                _rupiah.format(t['total']),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: isVoided ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                  decoration: isVoided ? TextDecoration.lineThrough : null,
                ),
              ),
              const SizedBox(width: 2),
              IconButton(
                icon: const Icon(Icons.share_outlined, size: 16, color: Color(0xFF64748B)),
                tooltip: 'Kirim Struk',
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  ReceiptService.showShareReceiptModal(
                    context: context,
                    queueNumber: (t['queue'] as num).toInt(),
                    total: (t['total'] as num).toDouble(),
                    paymentMethod: t['pay'] as String,
                    customerName: t['name'] as String,
                    cashierName: t['inputBy'] as String?,
                    timestamp: t['created'] as DateTime?,
                    items: (t['items'] as List<dynamic>?) ?? [],
                  );
                },
              ),
            ],
          ),
          if (isVoided && t['voidReason'] != null && (t['voidReason'] as String).isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 13, color: Color(0xFFDC2626)),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'Alasan: ${t['voidReason']}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFFDC2626), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (items.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                children: [
                  for (final it in items)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${it['item_name']} × ${it['qty']}',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                            ),
                          ),
                          Text(
                            _rupiah.format(it['subtotal']),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExpenseCard(Map<String, dynamic> p) {
    final cat = (p['category'] as String?) ?? 'Operasional';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ExpenseCategories.background(cat),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              ExpenseCategories.icons[cat] ?? Icons.receipt_long_outlined,
              size: 16,
              color: ExpenseCategories.textColor(cat),
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
                        color: ExpenseCategories.background(cat),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: ExpenseCategories.textColor(cat),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        p['note'] as String,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Diinput oleh: ${p['inputBy']}${p['created'] != null ? ' · ${_timeFmt.format(p['created'] as DateTime)}' : ''}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          Text(
            '-${_rupiah.format(p['amount'])}',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: Color(0xFFDC2626),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String msg) {
    return Container(
      padding: const EdgeInsets.all(28),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, size: 36, color: Color(0xFFCBD5E1)),
          const SizedBox(height: 8),
          Text(
            msg,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}

class _BentoCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final String badgeLabel;
  final Color badgeColor;
  final Color badgeTextColor;

  const _BentoCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.badgeLabel,
    required this.badgeColor,
    required this.badgeTextColor,
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
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: badgeTextColor,
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
                letterSpacing: -0.6,
                color: Color(0xFF0F172A),
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
                  style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CashierAcc {
  String name;
  String uid;
  int jumOrder = 0;
  double omzet = 0;
  double pengeluaran = 0;

  _CashierAcc({required this.name, required this.uid});
}
