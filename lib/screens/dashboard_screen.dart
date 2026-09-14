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
  Timer? _clockTimer;
  DateTime _currentTime = DateTime.now();

  static final _rupiah = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

  // Perhitungan pembayaran Tunai & QRIS dari transaksi sesi aktif
  double get _totalCash => _recentOrders
      .where((o) => o.paymentMethod == 'cash')
      .fold(0.0, (sum, o) => sum + o.totalAmount);

  double get _totalQris => _recentOrders
      .where((o) => o.paymentMethod == 'qris')
      .fold(0.0, (sum, o) => sum + o.totalAmount);

  int get _cashOrderCount => _recentOrders.where((o) => o.paymentMethod == 'cash').length;
  int get _qrisOrderCount => _recentOrders.where((o) => o.paymentMethod == 'qris').length;

  @override
  void initState() {
    super.initState();
    _loadData();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _currentTime = DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
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
    try {
      final shift = await _db.openShift();
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

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
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
              'Tutup Sesi Toko?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pastikan uang tunai di laci kasir dan semua transaksi telah sesuai. Laporan shift lengkap akan otomatis dibuat.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Transaksi:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      Text('${_stats?.orderCount ?? 0} pesanan', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Penjualan:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      Text(_rupiah.format(_stats?.omzet ?? 0), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Kas Keluar (Biaya):', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      Text('-${_rupiah.format(_stats?.expenses ?? 0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFDC2626))),
                    ],
                  ),
                  const Divider(height: 16, color: Color(0xFFE2E8F0)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Kas Masuk Bersih:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                      Text(_rupiah.format(_stats?.bersih ?? 0), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF059669))),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.lock_outline, size: 16),
            label: const Text('Tutup & Lihat Laporan'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() => _isLoading = true);

    try {
      await _db.closeShift(shift.id);
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

  void _showAddExpenseDialog() {
    final shift = _activeShift;
    if (shift == null) return;

    showDialog(
      context: context,
      builder: (_) => DashboardExpenseDialog(
        onSubmit: (note, amount) async {
          await _db.createExpense(
            shiftId: shift.id,
            amount: amount,
            note: note,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Biaya operasional berhasil dicatat.'),
                backgroundColor: Color(0xFF059669),
                behavior: SnackBarBehavior.floating,
              ),
            );
            _loadData();
          }
        },
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
                        currentTime: _currentTime,
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