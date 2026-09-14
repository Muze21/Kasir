import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/database_service.dart';
import '../models/pos_models.dart';
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
  int _activityFilterIndex = 0; // 0: Semua, 1: Pesanan, 2: Pengeluaran
  Timer? _clockTimer;
  DateTime _currentTime = DateTime.now();

  static final _rupiah = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);
  static final _waktu = DateFormat.Hm('id_ID');

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
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final profile = await _db.getCurrentProfile();
    final shift = await _db.getActiveShift();

    Profile? opener;
    ShiftStats? stats;
    List<Order> recent = [];
    List<Expense> expenses = [];
    Shift? lastClosed;

    if (shift != null) {
      stats = await _db.getShiftStats(shift.id);
      recent = await _db.getOrders(shift.id);
      expenses = await _db.getExpenses(shift.id);
      if (shift.openedBy != null) {
        opener = await _db.getProfileById(shift.openedBy!);
      }
    } else {
      try {
        final closedList = await _db.getClosedShifts();
        if (closedList.isNotEmpty) {
          lastClosed = closedList.first;
        }
      } catch (_) {}
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

    final noteCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (modalContext, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(modalContext).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.receipt_long_outlined, size: 20, color: Color(0xFFDC2626)),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Catat Pengeluaran Kasir',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.3,
                              ),
                            ),
                            Text(
                              'Uang kas keluar untuk operasional shift saat ini',
                              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.pop(modalContext),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Keperluan / Keterangan',
                      hintText: 'Misal: Beli es batu kristal, gas LPG, plastik',
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Keterangan tidak boleh kosong';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Nominal Biaya (Rp)',
                      hintText: 'Contoh: 25000',
                      prefixText: 'Rp ',
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Nominal tidak boleh kosong';
                      }
                      final numVal = double.tryParse(val.replaceAll(RegExp(r'[^0-9]'), ''));
                      if (numVal == null || numVal <= 0) {
                        return 'Masukkan nominal yang valid';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: isSaving
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              setModalState(() => isSaving = true);
                              final messenger = ScaffoldMessenger.of(context);
                              final navigator = Navigator.of(modalContext);
                              try {
                                final amount = double.parse(amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''));
                                await _db.createExpense(
                                  shiftId: shift.id,
                                  note: noteCtrl.text.trim(),
                                  amount: amount,
                                );
                                if (!mounted) return;
                                navigator.pop();
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Pengeluaran berhasil dicatat.'),
                                    backgroundColor: Color(0xFF059669),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                _loadData();
                              } catch (e) {
                                setModalState(() => isSaving = false);
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text('Gagal mencatat pengeluaran: $e'),
                                    backgroundColor: const Color(0xFFDC2626),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                      child: isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Simpan Pengeluaran', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _confirmSignOut() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        title: const Text(
          'Konfirmasi Keluar',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
            letterSpacing: -0.3,
          ),
        ),
        content: const Text(
          'Apakah Anda yakin ingin keluar dari akun kasir?',
          style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Supabase.instance.client.auth.signOut();
            },
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
  }

  String _getGreeting() {
    final hour = _currentTime.hour;
    if (hour >= 4 && hour < 11) return 'Selamat pagi';
    if (hour >= 11 && hour < 15) return 'Selamat siang';
    if (hour >= 15 && hour < 18) return 'Selamat sore';
    return 'Selamat malam';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F172A)),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              color: const Color(0xFF0F172A),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 840),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 48),
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 20),
                      _buildGreetingBanner(),
                      const SizedBox(height: 20),
                      if (_activeShift != null) ...[
                        _buildHeroActiveShift(_activeShift!, _stats),
                        const SizedBox(height: 16),
                        _buildBentoStatsGrid(_stats),
                        const SizedBox(height: 24),
                        _buildShiftActivitySection(),
                      ] else ...[
                        _buildClosedShiftState(),
                      ],
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'Kaskita.',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: const Text(
            'POS TERMINAL',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: Color(0xFF64748B),
            ),
          ),
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.sync_outlined, size: 20, color: Color(0xFF64748B)),
          tooltip: 'Sinkronkan Data',
          onPressed: () {
            _loadData();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Data berhasil diperbarui'),
                duration: Duration(seconds: 1),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.logout_outlined, size: 20, color: Color(0xFF64748B)),
          tooltip: 'Keluar',
          onPressed: _confirmSignOut,
        ),
      ],
    );
  }

  Widget _buildGreetingBanner() {
    final dayFormat = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(_currentTime);
    final timeFormat = DateFormat('HH:mm:ss', 'id_ID').format(_currentTime);
    final initial = _profile?.fullName.isNotEmpty == true
        ? _profile!.fullName.characters.first.toUpperCase()
        : 'K';
    final isOpen = _activeShift != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_getGreeting()}, ${_profile?.fullName ?? 'Keluarga'}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$dayFormat • $timeFormat WIB',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isOpen ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(9999),
              border: Border.all(
                color: isOpen ? const Color(0xFF10B981).withAlpha(60) : const Color(0xFFEF4444).withAlpha(60),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isOpen ? const Color(0xFF059669) : const Color(0xFFDC2626),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isOpen ? 'SHIFT AKTIF' : 'TOKO TUTUP',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: isOpen ? const Color(0xFF059669) : const Color(0xFFDC2626),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroActiveShift(Shift shift, ShiftStats? stats) {
    final bersih = stats?.bersih ?? 0.0;
    final openerName = _opener?.fullName ?? 'Anggota';
    final omzet = stats?.omzet ?? 0.0;

    // Persentase Cash vs QRIS untuk visual ratio bar
    final cashRatio = omzet > 0 ? (_totalCash / omzet).clamp(0.0, 1.0) : 0.0;
    final qrisRatio = omzet > 0 ? (_totalQris / omzet).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x050F172A),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header info
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'KAS MASUK BERSIH SAAT INI',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _rupiah.format(bersih),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.2,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.schedule, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Text(
                      'Buka ${_waktu.format(shift.openedAt.toLocal())} WIB',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Dibuka oleh $openerName • Omzet ${_rupiah.format(stats?.omzet ?? 0)} dikurangi biaya operasional ${_rupiah.format(stats?.expenses ?? 0)}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),

          const SizedBox(height: 20),

          // Visual Ratio Bar: Tunai (Laci) vs QRIS (Digital)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 8,
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
              Row(
                children: [
                  _buildPaymentBadge(
                    dotColor: const Color(0xFF059669),
                    label: 'Tunai di Laci:',
                    value: _rupiah.format(_totalCash),
                    count: '$_cashOrderCount trx',
                  ),
                  const SizedBox(width: 16),
                  _buildPaymentBadge(
                    dotColor: const Color(0xFF4F46E5),
                    label: 'QRIS:',
                    value: _rupiah.format(_totalQris),
                    count: '$_qrisOrderCount trx',
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Action buttons bar
          Row(
            children: [
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 46,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _openPosScreen,
                    icon: const Icon(Icons.point_of_sale_rounded, size: 18),
                    label: const Text('Buka Kasir POS', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 46,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0F172A),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _showAddExpenseDialog,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Catat Biaya', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 46,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    backgroundColor: const Color(0xFFFEF2F2),
                    side: const BorderSide(color: Color(0xFFFEE2E2)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  onPressed: _closeShift,
                  icon: const Icon(Icons.lock_clock_outlined, size: 16),
                  label: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ),
            ],
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
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
        ),
        const SizedBox(width: 4),
        Text(
          '($count)',
          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
        ),
      ],
    );
  }

  // 2-Card Bento Grid (AOV Dihapus, layout menjadi seimbang 2 kolom)
  Widget _buildBentoStatsGrid(ShiftStats? stats) {
    final omzet = stats?.omzet ?? 0.0;
    final expenses = stats?.expenses ?? 0.0;
    final orderCount = stats?.orderCount ?? 0;

    return Row(
      children: [
        Expanded(
          child: _BentoMetricTile(
            title: 'Total Penjualan',
            value: _rupiah.format(omzet),
            subtitle: '$orderCount pesanan berhasil',
            icon: Icons.trending_up_rounded,
            badgeColor: const Color(0xFFECFDF5),
            badgeTextColor: const Color(0xFF059669),
            badgeLabel: 'OMZET',
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _BentoMetricTile(
            title: 'Pengeluaran Kasir',
            value: '-${_rupiah.format(expenses)}',
            subtitle: '${_recentExpenses.length} catatan pengeluaran',
            icon: Icons.trending_down_rounded,
            badgeColor: const Color(0xFFFEF2F2),
            badgeTextColor: const Color(0xFFDC2626),
            badgeLabel: 'KAS KELUAR',
          ),
        ),
      ],
    );
  }

  Widget _buildShiftActivitySection() {
    final List<_ActivityItem> allActivities = [
      ..._recentOrders.map((o) => _ActivityItem.order(o)),
      ..._recentExpenses.map((e) => _ActivityItem.expense(e)),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            // Tab Filter
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  _ActivityFilterTab(
                    label: 'Semua (${allActivities.length})',
                    isSelected: _activityFilterIndex == 0,
                    onTap: () => setState(() => _activityFilterIndex = 0),
                  ),
                  _ActivityFilterTab(
                    label: 'Pesanan (${_recentOrders.length})',
                    isSelected: _activityFilterIndex == 1,
                    onTap: () => setState(() => _activityFilterIndex = 1),
                  ),
                  _ActivityFilterTab(
                    label: 'Biaya (${_recentExpenses.length})',
                    isSelected: _activityFilterIndex == 2,
                    onTap: () => setState(() => _activityFilterIndex = 2),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredActivities.length > 8 ? 8 : filteredActivities.length,
                  separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
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
  }

  Widget _buildOrderRow(Order order) {
    final isQris = order.paymentMethod == 'qris';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
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
                    Text(
                      order.customerName?.isNotEmpty == true
                          ? order.customerName!
                          : 'Pelanggan #${order.queueNumber}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                  '${_waktu.format(order.createdAt.toLocal())} WIB • kasir: ${order.profile?.fullName ?? 'staff'}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          Text(
            _rupiah.format(order.totalAmount),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseRow(Expense expense) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.arrow_downward, size: 16, color: Color(0xFFDC2626)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.note,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_waktu.format(expense.createdAt.toLocal())} WIB • oleh ${expense.profile?.fullName ?? 'anggota'}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          Text(
            '-${_rupiah.format(expense.amount)}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: Color(0xFFDC2626),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyActivityState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Icon(Icons.receipt_outlined, size: 24, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 14),
          const Text(
            'Belum ada aktivitas di sesi ini',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Shift sudah aktif. Mulai input pesanan kasir atau catat pengeluaran operasional.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 38,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _openPosScreen,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Buat Pesanan Baru', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  // Kiosk Standby State (Saat Toko Tutup)
  Widget _buildClosedShiftState() {
    final cashierName = _profile?.fullName ?? 'Petugas';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Workstation Standby Card
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x050F172A),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_clock_outlined, size: 12, color: Color(0xFFDC2626)),
                        SizedBox(width: 4),
                        Text(
                          'KASIR OFFLINE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Kasir siap: $cashierName',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'Mulai Sesi Toko Hari Ini',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.7,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Buka sesi kasir untuk mulai mencatat pesanan, kelola antrean pelanggan, dan sinkronisasi pembayaran tunai maupun QRIS secara real-time.',
                style: TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 48,
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _openShift,
                  icon: const Icon(Icons.storefront_outlined, size: 20),
                  label: const Text(
                    'Buka Sesi Toko Sekarang',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Laporan Shift Sebelumnya jika ada
        if (_lastClosedShift != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Icon(Icons.assessment_outlined, size: 20, color: Color(0xFF0F172A)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Laporan Sesi Terakhir',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _lastClosedShift!.closedAt != null
                            ? 'Ditutup ${DateFormat('d MMMM, HH:mm', 'id_ID').format(_lastClosedShift!.closedAt!)} WIB'
                            : 'Sesi sebelumnya',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 38,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0F172A),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ReportScreen(
                            shiftId: _lastClosedShift!.id,
                            shiftTitle: 'Laporan Sesi Terakhir',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.receipt_long_outlined, size: 16),
                    label: const Text('Buka Rekap', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),

        // Quick checklist bar (clean micro-pills)
        Row(
          children: [
            _buildChecklistPill(Icons.payments_outlined, 'Kas Laci Siap'),
            const SizedBox(width: 8),
            _buildChecklistPill(Icons.cloud_done_outlined, 'Cloud Terhubung'),
            const SizedBox(width: 8),
            _buildChecklistPill(Icons.group_outlined, 'Multi-Perangkat'),
          ],
        ),
      ],
    );
  }

  Widget _buildChecklistPill(IconData icon, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: const Color(0xFF64748B)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPONENT WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _BentoMetricTile extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color badgeColor;
  final Color badgeTextColor;
  final String badgeLabel;

  const _BentoMetricTile({
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x030F172A),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badgeLabel,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: badgeTextColor,
                  ),
                ),
              ),
              const Spacer(),
              Icon(icon, size: 18, color: badgeTextColor),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
        ],
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [
                  const BoxShadow(
                    color: Color(0x080F172A),
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