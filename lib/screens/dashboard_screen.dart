import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/pos_models.dart';
import '../services/database_service.dart';
import '../widgets/dashboard/dashboard_activity_section.dart';
import '../widgets/dashboard/dashboard_closed_shift.dart';
import '../widgets/dashboard/dashboard_expense_dialog.dart';
import '../widgets/dashboard/dashboard_greeting_banner.dart';
import '../widgets/dashboard/dashboard_header.dart';
import '../widgets/dashboard/dashboard_hero_shift.dart';
import '../widgets/dashboard/dashboard_stats_grid.dart';
import 'pos_screen.dart';
import 'report_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _db = DatabaseService();
  Profile? _profile;
  Shift? _activeShift;
  Shift? _lastClosedShift;
  Profile? _opener;
  ShiftStats? _stats;
  List<Order> _recentOrders = [];
  List<Expense> _recentExpenses = [];
  bool _isLoading = true;
  Timer? _autoRefreshTimer;

  static final _rupiah = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

  // Perhitungan pembayaran Tunai & QRIS dari transaksi sesi aktif
  double get _totalCash => _recentOrders
      .where((o) => o.paymentMethod == 'cash' && !o.isVoided)
      .fold(0.0, (sum, o) => sum + o.totalAmount);

  double get _totalQris => _recentOrders
      .where((o) => o.paymentMethod == 'qris' && !o.isVoided)
      .fold(0.0, (sum, o) => sum + o.totalAmount);

  int get _cashOrderCount => _recentOrders.where((o) => o.paymentMethod == 'cash' && !o.isVoided).length;
  int get _qrisOrderCount => _recentOrders.where((o) => o.paymentMethod == 'qris' && !o.isVoided).length;

  @override
  void initState() {
    super.initState();
    _loadData();
    // Auto-refresh ringan tiap 5 detik: hanya statistik & aktivitas,
    // tidak menyentuh form/state lain. (ponytail: polling 5s cukup untuk 3-4 device;
    // kalau transaksi sangat ramai, naikkan frekuensi atau ganti realtime.)
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _autoRefresh();
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  // Refresh ringan (tanpa spinner): update angka live + cek status shift
  // (misal: shift dibuka/ditutup device lain, atau transaksi dari device lain).
  Future<void> _autoRefresh() async {
    if (_isLoading || !mounted) return;
    try {
      final shift = await _db.getActiveShift();

      ShiftStats? stats;
      List<Order> recent = [];
      List<Expense> expenses = [];
      Shift? lastClosed = _lastClosedShift;
      Profile? opener = _opener;

      if (shift == null) {
        final closed = await _db.getLastClosedShift();
        if (closed != null) lastClosed = closed;
        stats = null;
        recent = [];
        expenses = [];
      } else {
        stats = await _db.getShiftStats(shift.id);
        recent = await _db.getOrders(shift.id);
        if (recent.length > 5) recent = recent.sublist(0, 5);
        expenses = await _db.getExpenses(shift.id);
        if (shift.id != _activeShift?.id || _opener == null) {
          if (shift.openedBy != null) opener = await _db.getProfileById(shift.openedBy!);
        }
      }

      if (!mounted) return;
      setState(() {
        _activeShift = shift;
        _lastClosedShift = lastClosed;
        _opener = opener;
        _stats = stats;
        _recentOrders = recent;
        _recentExpenses = expenses;
      });
    } catch (_) {
      // Auto-refresh gagal diabaikan supaya tidak mengganggu pemakaian;
      // refresh manual/pull-to-refresh tetap tersedia.
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final profile = await _db.getCurrentProfile();
      final shift = await _db.getActiveShift();
      final lastClosed = await _db.getLastClosedShift();

      Profile? opener;
      ShiftStats? stats;
      List<Order> recent = [];
      List<Expense> expenses = [];

      if (shift != null) {
        if (shift.openedBy != null) {
          opener = await _db.getProfileById(shift.openedBy!);
        }
        stats = await _db.getShiftStats(shift.id);
        recent = await _db.getOrders(shift.id);
        expenses = await _db.getExpenses(shift.id);
      }

      if (!mounted) return;
      setState(() {
        _profile = profile;
        _activeShift = shift;
        _lastClosedShift = lastClosed;
        _opener = opener;
        _stats = stats;
        _recentOrders = recent;
        _recentExpenses = expenses;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memuat data dashboard: $e'),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openShift() async {
    // Dialog input Modal Awal sebelum buka toko
    final result = await showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _OpenShiftDialog(),
    );
    if (result == null || !mounted) return; // user tekan Batal

    try {
      final shift = await _db.openShift(initialCash: result);
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => PosScreen(shift: shift)))
          .then((_) => _loadData());
    } catch (e) {
      if (!mounted) return;
      if (e.toString().contains('one_open_shift_idx')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Toko sudah dibuka oleh anggota lain. Menyinkronkan...'),
            backgroundColor: Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal Buka Toko: $e'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _openPosScreen() {
    final shift = _activeShift;
    if (shift == null) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => PosScreen(shift: shift)))
        .then((_) => _loadData());
  }

  Future<void> _closeShift() async {
    final shift = _activeShift;
    if (shift == null) return;

    // Hitung seharusnya di laci: Modal Awal + Penjualan Tunai - Semua Kas Keluar (Beban + Pribadi)
    final totalKasKeluar = _stats?.totalKasKeluar ?? 0;
    final seharusnya = shift.initialCash + _totalCash - totalKasKeluar;

    final result = await showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _CloseShiftDialog(
        stats: _stats,
        totalCash: _totalCash,
        totalQris: _totalQris,
        initialCash: shift.initialCash,
        seharusnya: seharusnya,
        rupiah: _rupiah,
      ),
    );
    if (result == null || !mounted) return; // user tekan Batal

    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() => _isLoading = true);

    try {
      await _db.closeShift(shift.id, actualCash: result);
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Shift toko berhasil ditutup.'),
          backgroundColor: Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await nav.push(
        MaterialPageRoute(
          builder: (_) => ReportScreen(shiftId: shift.id, shiftTitle: 'Rekap Sesi Ditutup'),
        ),
      );
      _loadData();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Gagal menutup toko: $e'),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _confirmDeleteExpense(Expense expense) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        title: const Text('Hapus Pengeluaran?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text('"${expense.note}" (${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0).format(expense.amount)}) akan dihapus dari shift ini.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Hapus'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;
    try {
      await _db.deleteExpense(expense.id);
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Pengeluaran berhasil dihapus.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadData();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Gagal menghapus pengeluaran: $e'),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showAddExpenseDialog({Expense? expense}) {
    final shift = _activeShift;
    if (shift == null) return;

    final isEdit = expense != null;
    showDialog(
      context: context,
      builder: (_) => DashboardExpenseDialog(
        initialNote: expense?.note,
        initialAmount: expense?.amount,
        initialCategory: expense?.category ?? 'Operasional',
        onSubmit: (note, amount, category) async {
          if (isEdit) {
            await _db.updateExpense(
              expenseId: expense.id,
              note: note,
              amount: amount,
              category: category,
            );
          } else {
            await _db.createExpense(
              shiftId: shift.id,
              amount: amount,
              note: note,
              category: category,
            );
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(isEdit ? 'Pengeluaran berhasil diperbarui.' : 'Kas keluar berhasil dicatat.'),
                backgroundColor: const Color(0xFF059669),
                behavior: SnackBarBehavior.floating,
              ),
            );
            _loadData();
          }
        },
        onDelete: isEdit
            ? () => _db.deleteExpense(expense.id)
            : null,
      ),
    );
  }

  void _viewReport(String shiftId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReportScreen(shiftId: shiftId, shiftTitle: 'Rekap Sesi Terakhir'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A)))
          : SafeArea(
              child: RefreshIndicator(
                color: const Color(0xFF0F172A),
                onRefresh: _loadData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Top Bar
                      DashboardHeader(onRefresh: _loadData),

                      const SizedBox(height: 14),

                      // 2. Greeting Banner
                      DashboardGreetingBanner(
                        profile: _profile,
                        isOpen: _activeShift != null,
                      ),

                      const SizedBox(height: 16),

                      // 3. State Aktif atau Tutup
                      if (_activeShift != null) ...[
                        DashboardHeroShift(
                          shift: _activeShift!,
                          stats: _stats,
                          opener: _opener,
                          totalCash: _totalCash,
                          totalQris: _totalQris,
                          cashOrderCount: _cashOrderCount,
                          qrisOrderCount: _qrisOrderCount,
                          onOpenPos: _openPosScreen,
                          onAddExpense: _showAddExpenseDialog,
                          onViewReport: () => _viewReport(_activeShift!.id),
                          onCloseShift: _closeShift,
                        ),
                        const SizedBox(height: 14),
                        DashboardStatsGrid(
                          stats: _stats,
                          expenseCount: _recentExpenses.length,
                        ),
                        const SizedBox(height: 18),
                        DashboardActivitySection(
                          recentOrders: _recentOrders,
                          recentExpenses: _recentExpenses,
                          onEditExpense: (e) => _showAddExpenseDialog(expense: e),
                          onDeleteExpense: (e) => _confirmDeleteExpense(e),
                        ),
                      ] else ...[
                        DashboardClosedShift(
                          profile: _profile,
                          lastClosedShift: _lastClosedShift,
                          onOpenShift: _openShift,
                          onViewReport: _viewReport,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

// ─── Dialog: Buka Toko — Input Modal Awal ────────────────────────────────────
class _OpenShiftDialog extends StatefulWidget {
  @override
  State<_OpenShiftDialog> createState() => _OpenShiftDialogState();
}

class _OpenShiftDialogState extends State<_OpenShiftDialog> {
  final _ctrl = TextEditingController();
  static final _rupiah = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _setNominal(double val) {
    setState(() => _ctrl.text = val.toInt().toString());
  }

  double get _parsed => double.tryParse(_ctrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      title: const Row(
        children: [
          Icon(Icons.store_outlined, size: 22, color: Color(0xFF059669)),
          SizedBox(width: 8),
          Text(
            'Buka Toko',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A), letterSpacing: -0.3),
          ),
        ],
      ),
      content: StatefulBuilder(
        builder: (ctx, setSt) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Masukkan jumlah uang kembalian (modal awal) yang diletakkan di laci kasir sebelum toko dibuka.',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _ctrl,
                autofocus: true,
                keyboardType: TextInputType.number,
                onChanged: (_) => setSt(() {}),
                decoration: const InputDecoration(
                  labelText: 'Modal Awal di Laci',
                  hintText: '0',
                  prefixText: 'Rp ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              // Quick chips nominal umum modal awal
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [50000, 100000, 150000, 200000].map((val) {
                  return ActionChip(
                    label: Text(_rupiah.format(val), style: const TextStyle(fontSize: 11)),
                    backgroundColor: const Color(0xFFF0FDF4),
                    side: const BorderSide(color: Color(0xFF86EFAC)),
                    onPressed: () {
                      _setNominal(val.toDouble());
                      setSt(() {});
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 6),
              // Opsi Tanpa Modal Awal
              ActionChip(
                label: const Text('Tanpa Modal Awal (Rp 0)', style: TextStyle(fontSize: 11)),
                backgroundColor: const Color(0xFFF8FAFC),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
                onPressed: () {
                  _setNominal(0);
                  setSt(() {});
                },
              ),
            ],
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B))),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF059669),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () => Navigator.pop(context, _parsed),
          icon: const Icon(Icons.store_outlined, size: 16),
          label: const Text('Buka Toko'),
        ),
      ],
    );
  }
}

// ─── Dialog: Tutup Toko — Input Uang Fisik & Rekonsiliasi Laci ───────────────
class _CloseShiftDialog extends StatefulWidget {
  final ShiftStats? stats;
  final double totalCash;
  final double totalQris;
  final double initialCash;
  final double seharusnya;
  final NumberFormat rupiah;

  const _CloseShiftDialog({
    required this.stats,
    required this.totalCash,
    required this.totalQris,
    required this.initialCash,
    required this.seharusnya,
    required this.rupiah,
  });

  @override
  State<_CloseShiftDialog> createState() => _CloseShiftDialogState();
}

class _CloseShiftDialogState extends State<_CloseShiftDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  double get _actualCash => double.tryParse(_ctrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  double get _selisih => _actualCash - widget.seharusnya;
  bool get _hasInput => _ctrl.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      title: const Row(
        children: [
          Icon(Icons.lock_clock_outlined, size: 22, color: Color(0xFFDC2626)),
          SizedBox(width: 8),
          Text(
            'Tutup Sesi Toko',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A), letterSpacing: -0.3),
          ),
        ],
      ),
      content: StatefulBuilder(
        builder: (ctx, setSt) {
          final selisih = _selisih;
          final lebih = selisih >= 0;

          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ringkasan Rekonsiliasi
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      _RekonRow('Modal Awal Laci', widget.rupiah.format(widget.initialCash), isPositive: true),
                      _RekonRow('+ Penjualan Tunai', widget.rupiah.format(widget.totalCash), isPositive: true),
                      _RekonRow('- Semua Kas Keluar', widget.rupiah.format(widget.stats?.totalKasKeluar ?? 0), isNegative: true),
                      const Divider(height: 14, color: Color(0xFFE2E8F0)),
                      _RekonRow(
                        'Seharusnya di Laci',
                        widget.rupiah.format(widget.seharusnya),
                        isBold: true,
                      ),
                      const SizedBox(height: 4),
                      _RekonRow('+ QRIS (tidak di laci)', widget.rupiah.format(widget.totalQris), isInfo: true),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // Input uang fisik
                TextField(
                  controller: _ctrl,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setSt(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Uang Fisik yang Dihitung di Laci',
                    hintText: '0',
                    prefixText: 'Rp ',
                    border: OutlineInputBorder(),
                  ),
                ),
                // Chip uang pas
                const SizedBox(height: 8),
                ActionChip(
                  label: Text(
                    'Pas ${widget.rupiah.format(widget.seharusnya)}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  backgroundColor: const Color(0xFFECFDF5),
                  side: const BorderSide(color: Color(0xFF6EE7B7)),
                  onPressed: () {
                    _ctrl.text = widget.seharusnya.toInt().toString();
                    setSt(() {});
                  },
                ),
                // Selisih (muncul saat ada input)
                if (_hasInput) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: lebih ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: lebih ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              lebih ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                              size: 16,
                              color: lebih ? const Color(0xFF059669) : const Color(0xFFDC2626),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              lebih ? 'Selisih Lebih' : 'Selisih Kurang',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: lebih ? const Color(0xFF059669) : const Color(0xFFDC2626),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${lebih ? '+' : ''}${widget.rupiah.format(selisih)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: lebih ? const Color(0xFF059669) : const Color(0xFFDC2626),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B))),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0F172A),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () => Navigator.pop(context, _actualCash),
          icon: const Icon(Icons.lock_outline, size: 16),
          label: const Text('Tutup & Lihat Laporan'),
        ),
      ],
    );
  }
}

// Helper row rekonsiliasi
class _RekonRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isPositive;
  final bool isNegative;
  final bool isBold;
  final bool isInfo;

  const _RekonRow(
    this.label,
    this.value, {
    this.isPositive = false,
    this.isNegative = false,
    this.isBold = false,
    this.isInfo = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isNegative
        ? const Color(0xFFDC2626)
        : isInfo
            ? const Color(0xFF4F46E5)
            : const Color(0xFF0F172A);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isInfo ? const Color(0xFF4F46E5) : const Color(0xFF64748B),
              fontStyle: isInfo ? FontStyle.italic : FontStyle.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isBold ? 13 : 12,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}