import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/database_service.dart';
import '../models/pos_models.dart';
import 'pos_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _db = DatabaseService();
  Profile? _profile;
  Shift? _activeShift;
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

    if (shift != null) {
      stats = await _db.getShiftStats(shift.id);
      recent = await _db.getOrders(shift.id);
      expenses = await _db.getExpenses(shift.id);
      if (shift.openedBy != null) {
        opener = await _db.getProfileById(shift.openedBy!);
      }
    }

    if (!mounted) return;
    setState(() {
      _profile = profile;
      _activeShift = shift;
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
            backgroundColor: Color(0xFF346538),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal Buka Toko: $e'),
            backgroundColor: const Color(0xFF9F2F2D),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
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
                          color: const Color(0xFFFDEBEC),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.receipt_long_outlined, size: 20, color: Color(0xFF9F2F2D)),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Catat Pengeluaran Shift',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF111111),
                                letterSpacing: -0.3,
                              ),
                            ),
                            Text(
                              'Biaya operasional atau kas keluar pada sesi ini',
                              style: TextStyle(fontSize: 12, color: Color(0xFF787774)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20, color: Color(0xFF787774)),
                        onPressed: () => Navigator.pop(modalContext),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Keterangan Pengeluaran',
                      hintText: 'Misal: Beli es batu, kantong kresek, gas LPG',
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
                      onPressed: isSaving
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              setModalState(() => isSaving = true);
                              final messenger = ScaffoldMessenger.of(context);
                              final navigator = Navigator.of(modalContext);
                              try {
                                final amount = double.parse(amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''));
                                await _db.createExpense(shift.id, noteCtrl.text.trim(), amount);
                                if (!mounted) return;
                                navigator.pop();
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Pengeluaran berhasil dicatat.'),
                                    backgroundColor: Color(0xFF346538),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                _loadData();
                              } catch (e) {
                                setModalState(() => isSaving = false);
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text('Gagal mencatat pengeluaran: $e'),
                                    backgroundColor: const Color(0xFF9F2F2D),
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
                          : const Text('Simpan Pengeluaran'),
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
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFEAEAEA)),
        ),
        title: const Text(
          'Konfirmasi Keluar',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111111),
            letterSpacing: -0.3,
          ),
        ),
        content: const Text(
          'Apakah Anda yakin ingin keluar dari akun kasir?',
          style: TextStyle(fontSize: 14, color: Color(0xFF787774)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Color(0xFF787774))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9F2F2D),
              foregroundColor: Colors.white,
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
      backgroundColor: const Color(0xFFFBFBFA),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF111111)),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              color: const Color(0xFF111111),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 860),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 48),
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 24),
                      _buildGreetingBanner(),
                      const SizedBox(height: 20),
                      if (_activeShift != null) ...[
                        _buildHeroActiveShift(_activeShift!, _stats),
                        const SizedBox(height: 16),
                        _buildBentoStatsGrid(_stats),
                        const SizedBox(height: 16),
                        _buildQuickActionsRow(),
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
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'Kaskita.',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.6,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F6F3),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFFEAEAEA)),
          ),
          child: const Text(
            'POS KASIR',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: Color(0xFF787774),
            ),
          ),
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.sync_outlined, size: 20, color: Color(0xFF787774)),
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
          icon: const Icon(Icons.logout_outlined, size: 20, color: Color(0xFF787774)),
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
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEAEAEA)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF111111),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
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
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.4,
                    color: Color(0xFF111111),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$dayFormat • $timeFormat WIB',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF787774)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isOpen ? const Color(0xFFEDF3EC) : const Color(0xFFFDEBEC),
              borderRadius: BorderRadius.circular(9999),
              border: Border.all(
                color: isOpen ? const Color(0xFF346538).withAlpha(40) : const Color(0xFF9F2F2D).withAlpha(40),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isOpen ? const Color(0xFF346538) : const Color(0xFF9F2F2D),
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
                    color: isOpen ? const Color(0xFF346538) : const Color(0xFF9F2F2D),
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

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2B2B2B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'KAS BERSIH SHIFT SAAT INI',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: Color(0xFF999999),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _rupiah.format(bersih),
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF333333)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.schedule, size: 14, color: Color(0xFFB7B7B7)),
                    const SizedBox(width: 6),
                    Text(
                      'Buka ${_waktu.format(shift.openedAt.toLocal())} WIB',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFE5E5E5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Sesi dibuka oleh $openerName • Omzet ${_rupiah.format(stats?.omzet ?? 0)} dikurangi biaya ${_rupiah.format(stats?.expenses ?? 0)}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E8E)),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF111111),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: _openPosScreen,
                    icon: const Icon(Icons.point_of_sale_rounded, size: 18),
                    label: const Text('Buka Kasir POS', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 44,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF3A3A3A)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  onPressed: _showAddExpenseDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Biaya', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBentoStatsGrid(ShiftStats? stats) {
    final omzet = stats?.omzet ?? 0.0;
    final expenses = stats?.expenses ?? 0.0;
    final orderCount = stats?.orderCount ?? 0;
    final aov = orderCount > 0 ? (omzet / orderCount) : 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 600;

        if (isNarrow) {
          return Column(
            children: [
              _BentoMetricTile(
                title: 'Total Omzet',
                value: _rupiah.format(omzet),
                subtitle: '$orderCount pesanan berhasil',
                icon: Icons.trending_up_rounded,
                badgeColor: const Color(0xFFEDF3EC),
                badgeTextColor: const Color(0xFF346538),
                badgeLabel: 'PENJUALAN',
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _BentoMetricTile(
                      title: 'Pengeluaran',
                      value: _rupiah.format(expenses),
                      subtitle: '${_recentExpenses.length} catatan biaya',
                      icon: Icons.trending_down_rounded,
                      badgeColor: const Color(0xFFFDEBEC),
                      badgeTextColor: const Color(0xFF9F2F2D),
                      badgeLabel: 'KAS KELUAR',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _BentoMetricTile(
                      title: 'Rata-rata Order',
                      value: _rupiah.format(aov),
                      subtitle: 'Per transaksi',
                      icon: Icons.shopping_basket_outlined,
                      badgeColor: const Color(0xFFE1F3FE),
                      badgeTextColor: const Color(0xFF1F6C9F),
                      badgeLabel: 'AOV',
                    ),
                  ),
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: _BentoMetricTile(
                title: 'Total Omzet',
                value: _rupiah.format(omzet),
                subtitle: '$orderCount pesanan berhasil',
                icon: Icons.trending_up_rounded,
                badgeColor: const Color(0xFFEDF3EC),
                badgeTextColor: const Color(0xFF346538),
                badgeLabel: 'PENJUALAN',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _BentoMetricTile(
                title: 'Pengeluaran',
                value: _rupiah.format(expenses),
                subtitle: '${_recentExpenses.length} catatan biaya',
                icon: Icons.trending_down_rounded,
                badgeColor: const Color(0xFFFDEBEC),
                badgeTextColor: const Color(0xFF9F2F2D),
                badgeLabel: 'KAS KELUAR',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _BentoMetricTile(
                title: 'Rata-rata Order',
                value: _rupiah.format(aov),
                subtitle: 'Nilai per keranjang',
                icon: Icons.shopping_basket_outlined,
                badgeColor: const Color(0xFFE1F3FE),
                badgeTextColor: const Color(0xFF1F6C9F),
                badgeLabel: 'AOV',
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuickActionsRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEAEAEA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.bolt_outlined, size: 18, color: Color(0xFF787774)),
          const SizedBox(width: 8),
          const Text(
            'Aksi Sesi:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF787774),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                _QuickActionChip(
                  icon: Icons.add_circle_outline,
                  label: 'Catat Biaya',
                  onTap: _showAddExpenseDialog,
                ),
                _QuickActionChip(
                  icon: Icons.point_of_sale_outlined,
                  label: 'Masuk POS',
                  isPrimary: true,
                  onTap: _openPosScreen,
                ),
              ],
            ),
          ),
        ],
      ),
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
              'AKTIVITAS SHIFT',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: Color(0xFF787774),
              ),
            ),
            const Spacer(),
            // Filter Pills
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F6F3),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFEAEAEA)),
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
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFEAEAEA)),
          ),
          child: filteredActivities.isEmpty
              ? _buildEmptyActivityState()
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredActivities.length > 8 ? 8 : filteredActivities.length,
                  separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFEAEAEA)),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF7F6F3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFEAEAEA)),
            ),
            alignment: Alignment.center,
            child: Text(
              '#${order.queueNumber}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111111),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.customerName?.isNotEmpty == true
                      ? order.customerName!
                      : 'Pelanggan #${order.queueNumber}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111111),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_waktu.format(order.createdAt.toLocal())} WIB • oleh ${order.profile?.fullName ?? 'kasir'}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF787774)),
                ),
              ],
            ),
          ),
          Text(
            _rupiah.format(order.totalAmount),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              color: Color(0xFF111111),
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
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFFDEBEC),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.arrow_downward, size: 16, color: Color(0xFF9F2F2D)),
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
                    color: Color(0xFF111111),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_waktu.format(expense.createdAt.toLocal())} WIB • oleh ${expense.profile?.fullName ?? 'anggota'}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF787774)),
                ),
              ],
            ),
          ),
          Text(
            '-${_rupiah.format(expense.amount)}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              color: Color(0xFF9F2F2D),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyActivityState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF7F6F3),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFEAEAEA)),
            ),
            child: const Icon(Icons.receipt_outlined, size: 24, color: Color(0xFF787774)),
          ),
          const SizedBox(height: 14),
          const Text(
            'Belum ada aktivitas transaksi',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111111),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Shift sudah terbuka. Mulai catat pesanan atau pengeluaran operasional hari ini.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF787774)),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 38,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF111111),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onPressed: _openPosScreen,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Buat Pesanan Baru', style: TextStyle(fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClosedShiftState() {
    final cashierName = _profile?.fullName ?? 'Petugas';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Workstation Hero Card
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFEAEAEA)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDEBEC),
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_clock_outlined, size: 12, color: Color(0xFF9F2F2D)),
                        SizedBox(width: 4),
                        Text(
                          'SESI KASIR NON-AKTIF',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: Color(0xFF9F2F2D),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Kasir: $cashierName',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF787774)),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'Toko Siap Memulai Penjualan?',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  color: Color(0xFF111111),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Buka sesi shift kasir hari ini. Seluruh pesanan, nomor antrean pelanggan, dan pengeluaran operasional akan tercatat dan tersinkron otomatis antar anggota keluarga.',
                style: TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF787774)),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 48,
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF111111),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

        const SizedBox(height: 20),

        // Bento Section: Persiapan & Standar Sesi Kasir
        const Text(
          'PERSIAPAN SEBELUM MEMBUKA SHIFT',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: Color(0xFF787774),
          ),
        ),
        const SizedBox(height: 12),

        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 650;

            final checklistCards = [
              const _ChecklistBentoCard(
                icon: Icons.payments_outlined,
                badgeLabel: 'KAS FISIK',
                badgeBg: Color(0xFFFBF3DB),
                badgeColor: Color(0xFF956400),
                title: 'Modal & Kembalian',
                desc: 'Siapkan uang pecahan kecil di laci kasir untuk kelancaran kembalian pelanggan.',
              ),
              const _ChecklistBentoCard(
                icon: Icons.cloud_done_outlined,
                badgeLabel: 'SINKRONISASI',
                badgeBg: Color(0xFFEDF3EC),
                badgeColor: Color(0xFF346538),
                title: 'Koneksi Cloud Siap',
                desc: 'Supabase cloud aktif. Pesanan otomatis terupdate di semua perangkat kasir.',
              ),
              const _ChecklistBentoCard(
                icon: Icons.group_outlined,
                badgeLabel: 'MULTI-KASIR',
                badgeBg: Color(0xFFE1F3FE),
                badgeColor: Color(0xFF1F6C9F),
                title: 'Akses Kolaboratif',
                desc: 'Satu shift cukup dibuka satu kali, seluruh anggota keluarga bisa langsung input kasir.',
              ),
            ];

            if (isNarrow) {
              return Column(
                children: [
                  checklistCards[0],
                  const SizedBox(height: 10),
                  checklistCards[1],
                  const SizedBox(height: 10),
                  checklistCards[2],
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: checklistCards[0]),
                const SizedBox(width: 12),
                Expanded(child: checklistCards[1]),
                const SizedBox(width: 12),
                Expanded(child: checklistCards[2]),
              ],
            );
          },
        ),

        const SizedBox(height: 20),

        // Workflow Steps Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F6F3),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFEAEAEA)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Alur Operasional Kasir Kaskita',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111111),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildStepItem('1', 'Buka Shift', 'Mulai sesi kerja toko'),
                  const Icon(Icons.chevron_right, size: 18, color: Color(0xFFB7B7B7)),
                  _buildStepItem('2', 'Input POS', 'Catat pesanan & antrean'),
                  const Icon(Icons.chevron_right, size: 18, color: Color(0xFFB7B7B7)),
                  _buildStepItem('3', 'Rekap Bersih', 'Pantau omzet real-time'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepItem(String number, String title, String subtitle) {
    return Expanded(
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: Color(0xFF111111),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              number,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF111111)),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 10, color: Color(0xFF787774)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEAEAEA)),
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
              Icon(icon, size: 16, color: badgeTextColor),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF787774)),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: Color(0xFF111111),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: Color(0xFF787774)),
          ),
        ],
      ),
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  const _QuickActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isPrimary ? const Color(0xFF111111) : const Color(0xFFF7F6F3),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isPrimary ? const Color(0xFF111111) : const Color(0xFFEAEAEA)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isPrimary ? Colors.white : const Color(0xFF111111)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isPrimary ? Colors.white : const Color(0xFF111111),
              ),
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
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: isSelected ? Border.all(color: const Color(0xFFEAEAEA)) : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? const Color(0xFF111111) : const Color(0xFF787774),
          ),
        ),
      ),
    );
  }
}

class _ChecklistBentoCard extends StatelessWidget {
  final IconData icon;
  final String badgeLabel;
  final Color badgeBg;
  final Color badgeColor;
  final String title;
  final String desc;

  const _ChecklistBentoCard({
    required this.icon,
    required this.badgeLabel,
    required this.badgeBg,
    required this.badgeColor,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEAEAEA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badgeLabel,
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: badgeColor),
                ),
              ),
              const Spacer(),
              Icon(icon, size: 18, color: const Color(0xFF787774)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              color: Color(0xFF111111),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            desc,
            style: const TextStyle(fontSize: 12, height: 1.4, color: Color(0xFF787774)),
          ),
        ],
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