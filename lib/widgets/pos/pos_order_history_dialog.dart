import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/pos_models.dart';
import '../../services/database_service.dart';
import 'pos_ticket_dialog.dart';

class PosOrderHistoryDialog extends StatefulWidget {
  final String shiftId;
  final VoidCallback onOrderVoided;
  final bool isBottomSheet;

  const PosOrderHistoryDialog({
    super.key,
    required this.shiftId,
    required this.onOrderVoided,
    this.isBottomSheet = false,
  });

  @override
  State<PosOrderHistoryDialog> createState() => _PosOrderHistoryDialogState();
}

class _PosOrderHistoryDialogState extends State<PosOrderHistoryDialog> {
  final _db = DatabaseService();
  static final _rupiah = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);
  static final _timeFmt = DateFormat('HH:mm', 'id_ID');

  bool _isLoading = true;
  List<Order> _orders = [];
  String? _errorMessage;

  // State tampilan: null = List View, non-null = Void Confirmation View
  Order? _selectedOrderToVoid;
  String _selectedReason = 'Salah input menu / pesanan';
  final TextEditingController _customReasonCtrl = TextEditingController();
  bool _isSubmittingVoid = false;

  final List<Map<String, dynamic>> _reasonsList = [
    {
      'title': 'Salah input menu / pesanan',
      'subtitle': 'Kasir salah mencatat kuantitas atau menu',
      'icon': Icons.edit_note_rounded,
    },
    {
      'title': 'Pelanggan membatalkan pesanan',
      'subtitle': 'Pembeli tidak jadi beli sebelum makanan dibuat',
      'icon': Icons.person_off_outlined,
    },
    {
      'title': 'Salah metode pembayaran',
      'subtitle': 'Seharusnya QRIS tertekan Tunai (atau sebaliknya)',
      'icon': Icons.swap_horiz_rounded,
    },
    {
      'title': 'Alasan lainnya',
      'subtitle': 'Ketik catatan alasan khusus di bawah',
      'icon': Icons.more_horiz_rounded,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  @override
  void dispose() {
    _customReasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final orders = await _db.getOrders(widget.shiftId);
      if (!mounted) return;
      setState(() {
        _orders = orders;
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

  int get _activeOrdersCount => _orders.where((o) => !o.isVoided).length;

  double get _activeOmzet => _orders
      .where((o) => !o.isVoided)
      .fold(0.0, (sum, o) => sum + o.totalAmount);

  void _showReprintDialog(Order order) {
    final itemsList = order.items.map((i) => {
      'name': i.itemName,
      'price': i.price,
      'qty': i.qty,
      'subtotal': i.subtotal,
    }).toList();

    showDialog(
      context: context,
      builder: (ctx) => PosTicketDialog(
        queueNumber: order.queueNumber,
        total: order.totalAmount,
        paymentMethod: order.paymentMethod,
        cashReceived: order.totalAmount,
        change: 0.0,
        customerName: order.customerName ?? 'Pelanggan ${order.queueNumber}',
        items: itemsList,
        cashierName: order.profile?.fullName,
        timestamp: order.createdAt,
        onNextTransaction: () => Navigator.pop(ctx),
        onBackToDashboard: () => Navigator.pop(ctx),
      ),
    );
  }

  Future<void> _submitVoidOrder() async {
    if (_selectedOrderToVoid == null) return;
    final order = _selectedOrderToVoid!;

    String finalReason = _selectedReason;
    if (_selectedReason == 'Alasan lainnya') {
      final custom = _customReasonCtrl.text.trim();
      finalReason = custom.isNotEmpty ? custom : 'Alasan lainnya';
    }

    setState(() => _isSubmittingVoid = true);

    try {
      await _db.voidOrder(order.id, reason: finalReason);
      widget.onOrderVoided();

      if (!mounted) return;
      setState(() {
        _isSubmittingVoid = false;
        _selectedOrderToVoid = null;
        _customReasonCtrl.clear();
        _selectedReason = 'Salah input menu / pesanan';
      });

      await _loadOrders();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Transaksi #${order.queueNumber} berhasil dibatalkan'),
          backgroundColor: const Color(0xFF0F172A),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmittingVoid = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membatalkan transaksi: $e'),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    final content = AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: _selectedOrderToVoid == null
          ? _buildHistoryListView(key: const ValueKey('history_list'))
          : _buildVoidConfirmationView(key: const ValueKey('void_view')),
    );

    if (widget.isBottomSheet) {
      return Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        constraints: BoxConstraints(
          maxHeight: screenHeight * 0.92,
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              Expanded(child: content),
            ],
          ),
        ),
      );
    }

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 540,
          maxHeight: screenHeight * 0.88,
        ),
        child: content,
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // VIEW 1: DAFTAR RIWAYAT TRANSAKSI
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildHistoryListView({required Key key}) {
    return Column(
      key: key,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.receipt_long_rounded, size: 20, color: Color(0xFF0F172A)),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Riwayat Transaksi Shift',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: -0.3),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Daftar pesanan sesi kasir saat ini',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 20, color: Color(0xFF64748B)),
                tooltip: 'Muat Ulang',
                onPressed: _loadOrders,
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                tooltip: 'Tutup',
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),

        const Divider(height: 1, color: Color(0xFFE2E8F0)),

        // Banner Ringkasan Omzet & Transaksi Aktif
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$_activeOrdersCount Transaksi',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                  if (_orders.length - _activeOrdersCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${_orders.length - _activeOrdersCount} batal',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFDC2626)),
                      ),
                    ),
                  ],
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'TOTAL OMZET AKTIF',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _rupiah.format(_activeOmzet),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF059669), letterSpacing: -0.3),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Konten Daftar Pesanan
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 32),
                            const SizedBox(height: 8),
                            Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                            const SizedBox(height: 12),
                            ElevatedButton(onPressed: _loadOrders, child: const Text('Coba Lagi')),
                          ],
                        ),
                      ),
                    )
                  : _orders.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.receipt_outlined, size: 24, color: Color(0xFF94A3B8)),
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Belum Ada Transaksi',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Transaksi yang diselesaikan di kasir akan muncul di sini.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          itemCount: _orders.length,
                          separatorBuilder: (ctx, index) => const SizedBox(height: 10),
                          itemBuilder: (ctx, idx) {
                            final order = _orders[idx];
                            return _buildOrderCard(order);
                          },
                        ),
        ),
      ],
    );
  }

  Widget _buildOrderCard(Order order) {
    final isVoid = order.isVoided;
    final itemsSummary = order.items.isNotEmpty
        ? order.items.map((i) => '${i.qty}x ${i.itemName}').join(', ')
        : 'Pesanan #${order.queueNumber}';
    final customer = (order.customerName != null && order.customerName!.isNotEmpty)
        ? order.customerName!
        : 'Pelanggan #${order.queueNumber}';
    final isCash = order.paymentMethod.toLowerCase() == 'cash';

    return Container(
      decoration: BoxDecoration(
        color: isVoid ? const Color(0xFFFAFAFA) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isVoid ? const Color(0xFFFCA5A5).withAlpha(120) : const Color(0xFFE2E8F0),
        ),
        boxShadow: isVoid
            ? []
            : const [
                BoxShadow(color: Color(0x050F172A), blurRadius: 6, offset: Offset(0, 2)),
              ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Baris 1: Nomor Antrean, Nama Pelanggan, Jam, Status Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: isVoid ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '#${order.queueNumber.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  customer,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isVoid ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                    decoration: isVoid ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              Text(
                '${_timeFmt.format(order.createdAt.toLocal())} WIB',
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isVoid ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isVoid ? 'BATAL' : 'SUKSES',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: isVoid ? const Color(0xFFDC2626) : const Color(0xFF059669),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Baris 2: Ringkasan Menu
          Text(
            itemsSummary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              color: isVoid ? const Color(0xFF94A3B8) : const Color(0xFF475569),
              decoration: isVoid ? TextDecoration.lineThrough : null,
            ),
          ),

          if (isVoid && order.voidReason != null && order.voidReason!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.info_outline, size: 12, color: Color(0xFFDC2626)),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'Alasan: ${order.voidReason}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFFDC2626)),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 8),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 8),

          // Baris 3: Metode Bayar, Total Nominal, dan Tombol Aksi
          Row(
            children: [
              // Badge Metode Bayar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isCash ? const Color(0xFFECFDF5) : const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isCash ? const Color(0xFF10B981).withAlpha(60) : const Color(0xFF6366F1).withAlpha(60),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isCash ? Icons.payments_outlined : Icons.qr_code_2_rounded,
                      size: 12,
                      color: isCash ? const Color(0xFF059669) : const Color(0xFF4F46E5),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isCash ? 'TUNAI' : 'QRIS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isCash ? const Color(0xFF059669) : const Color(0xFF4F46E5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Total Nominal
              Text(
                _rupiah.format(order.totalAmount),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isVoid ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                  decoration: isVoid ? TextDecoration.lineThrough : null,
                ),
              ),

              const Spacer(),

              // Tombol Lihat / Bagikan Ulang Struk
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: const Color(0xFF0F172A),
                ),
                onPressed: () => _showReprintDialog(order),
                icon: const Icon(Icons.receipt_outlined, size: 14),
                label: const Text('Struk', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
              ),

              // Tombol Batalkan / Void (Hanya jika belum batal)
              if (!isVoid) ...[
                const SizedBox(width: 4),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: const Color(0xFFDC2626),
                  ),
                  onPressed: () {
                    setState(() {
                      _selectedOrderToVoid = order;
                      _selectedReason = 'Salah input menu / pesanan';
                      _customReasonCtrl.clear();
                    });
                  },
                  icon: const Icon(Icons.delete_outline_rounded, size: 14),
                  label: const Text('Batalkan', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // VIEW 2: TAMPILAN KONFIRMASI PEMBATALAN (ELEGAN & TERPADU)
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildVoidConfirmationView({required Key key}) {
    final order = _selectedOrderToVoid!;
    final customer = (order.customerName != null && order.customerName!.isNotEmpty)
        ? order.customerName!
        : 'Pelanggan #${order.queueNumber}';
    final isCash = order.paymentMethod.toLowerCase() == 'cash';

    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header Transisi
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 12),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, size: 20, color: Color(0xFF0F172A)),
                tooltip: 'Kembali',
                onPressed: _isSubmittingVoid
                    ? null
                    : () {
                        setState(() => _selectedOrderToVoid = null);
                      },
              ),
              const SizedBox(width: 4),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Konfirmasi Pembatalan',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: -0.3),
                    ),
                    Text(
                      'Pilih alasan pembatalan transaksi kasir',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                onPressed: _isSubmittingVoid ? null : () => Navigator.pop(context),
              ),
            ],
          ),
        ),

        const Divider(height: 1, color: Color(0xFFE2E8F0)),

        // Konten Form Pembatalan (Scrollable)
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Kartu Ringkasan Pesanan yang Akan Dibatalkan
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '#${order.queueNumber.toString().padLeft(2, '0')}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              customer,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                            ),
                          ),
                          Text(
                            '${_timeFmt.format(order.createdAt.toLocal())} WIB',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      const SizedBox(height: 10),

                      // Daftar Item Ringkas
                      if (order.items.isNotEmpty)
                        Column(
                          children: order.items.map((it) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${it.qty}x ${it.itemName}',
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF334155), fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                  Text(
                                    _rupiah.format(it.subtotal),
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        )
                      else
                        const Text(
                          'Rincian item tidak tersedia',
                          style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontStyle: FontStyle.italic),
                        ),

                      const SizedBox(height: 10),
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      const SizedBox(height: 10),

                      // Baris Total & Metode
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isCash ? Icons.payments_outlined : Icons.qr_code_2_rounded,
                                size: 14,
                                color: isCash ? const Color(0xFF059669) : const Color(0xFF4F46E5),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                isCash ? 'TUNAI' : 'QRIS',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isCash ? const Color(0xFF059669) : const Color(0xFF4F46E5),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            _rupiah.format(order.totalAmount),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFDC2626),
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // 2. Pilihan Alasan Pembatalan (Kartu Bersih)
                const Text(
                  'PILIH ALASAN PEMBATALAN',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 8),

                Column(
                  children: _reasonsList.map((r) {
                    final title = r['title'] as String;
                    final subtitle = r['subtitle'] as String;
                    final icon = r['icon'] as IconData;
                    final isSelected = _selectedReason == title;

                    return InkWell(
                      onTap: () {
                        setState(() => _selectedReason = title);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFFEF2F2) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? const Color(0xFFDC2626) : const Color(0xFFE2E8F0),
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFFFEE2E2) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                icon,
                                size: 16,
                                color: isSelected ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                      color: isSelected ? const Color(0xFF991B1B) : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    subtitle,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: isSelected ? const Color(0xFFB91C1C) : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected ? const Color(0xFFDC2626) : Colors.transparent,
                                border: Border.all(
                                  color: isSelected ? const Color(0xFFDC2626) : const Color(0xFFCBD5E1),
                                  width: isSelected ? 2 : 1.5,
                                ),
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

                // Kolom teks jika "Alasan lainnya" dipilih
                if (_selectedReason == 'Alasan lainnya') ...[
                  const SizedBox(height: 4),
                  TextField(
                    controller: _customReasonCtrl,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Ketik alasan pembatalan (misal: stok habis mendadak)...',
                      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A)),
                  ),
                ],

                const SizedBox(height: 14),

                // 3. Banner Peringatan Pengurangan Omzet
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFFB45309)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Omzet shift ini akan otomatis dikurangi ${_rupiah.format(order.totalAmount)}. Status transaksi ditandai batal secara permanen.',
                          style: const TextStyle(fontSize: 11, height: 1.35, color: Color(0xFF92400E)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const Divider(height: 1, color: Color(0xFFE2E8F0)),

        // Bottom Action Bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                flex: 40,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isSubmittingVoid
                      ? null
                      : () {
                          setState(() => _selectedOrderToVoid = null);
                        },
                  child: const Text('Batal', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 60,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isSubmittingVoid ? null : _submitVoidOrder,
                  icon: _isSubmittingVoid
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.delete_forever_rounded, size: 18),
                  label: Text(
                    _isSubmittingVoid ? 'Membatalkan...' : 'Batalkan (${_rupiah.format(order.totalAmount)})',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
