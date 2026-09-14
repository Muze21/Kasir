import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PosCartPane extends StatefulWidget {
  final List<Map<String, dynamic>> cart;
  final VoidCallback onClearCart;
  final void Function(int index, int delta) onUpdateQty;
  final void Function(int index) onRemoveItem;
  final String paymentMethod;
  final ValueChanged<String> onPaymentMethodChanged;
  final TextEditingController cashInputCtrl;
  final double cartTotal;
  final int cartItemCount;
  final double? cashReceived;
  final double? cashChange;
  final bool isSubmitting;
  final VoidCallback onSubmitOrder;

  const PosCartPane({
    super.key,
    required this.cart,
    required this.onClearCart,
    required this.onUpdateQty,
    required this.onRemoveItem,
    required this.paymentMethod,
    required this.onPaymentMethodChanged,
    required this.cashInputCtrl,
    required this.cartTotal,
    required this.cartItemCount,
    this.cashReceived,
    this.cashChange,
    required this.isSubmitting,
    required this.onSubmitOrder,
  });

  @override
  State<PosCartPane> createState() => _PosCartPaneState();
}

class _PosCartPaneState extends State<PosCartPane> {
  static final _rupiah = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    widget.cashInputCtrl.addListener(_onCashChanged);
  }

  @override
  void didUpdateWidget(PosCartPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cashInputCtrl != widget.cashInputCtrl) {
      oldWidget.cashInputCtrl.removeListener(_onCashChanged);
      widget.cashInputCtrl.addListener(_onCashChanged);
    }
  }

  @override
  void dispose() {
    widget.cashInputCtrl.removeListener(_onCashChanged);
    super.dispose();
  }

  void _onCashChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  double get _cashReceived {
    final clean = widget.cashInputCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    return double.tryParse(clean) ?? 0.0;
  }

  double get _cashChange => _cashReceived - widget.cartTotal;

  bool get _canSubmit {
    if (widget.cart.isEmpty || widget.isSubmitting) return false;
    if (widget.paymentMethod == 'cash') {
      return _cashReceived >= widget.cartTotal && widget.cartTotal > 0;
    }
    return widget.cartTotal > 0;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
          // Header Keranjang
          Row(
            children: [
              const Icon(Icons.shopping_bag_outlined, size: 20, color: Color(0xFF0F172A)),
              const SizedBox(width: 8),
              Text(
                'Keranjang (${widget.cartItemCount} item)',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const Spacer(),
              if (widget.cart.isNotEmpty)
                TextButton(
                  onPressed: widget.onClearCart,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Kosongkan', style: TextStyle(color: Color(0xFFDC2626), fontSize: 12)),
                ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 12),

          // Daftar Item Keranjang
          if (widget.cart.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.remove_shopping_cart_outlined, size: 22, color: Color(0xFF94A3B8)),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Keranjang Masih Kosong',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Pilih item katalog atau ketik barang kustom untuk mulai mencatat.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.cart.length,
              separatorBuilder: (context, index) => const Divider(height: 12, color: Color(0xFFF1F5F9)),
              itemBuilder: (context, index) {
                final item = widget.cart[index];
                final name = item['name'] as String;
                final price = (item['price'] as num).toDouble();
                final qty = item['qty'] as int;
                final subtotal = price * qty;

                return Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _rupiah.format(price),
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Stepper Mini
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: () => widget.onUpdateQty(index, -1),
                            child: const Padding(padding: EdgeInsets.all(3), child: Icon(Icons.remove, size: 13)),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text('$qty', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                          ),
                          InkWell(
                            onTap: () => widget.onUpdateQty(index, 1),
                            child: const Padding(padding: EdgeInsets.all(3), child: Icon(Icons.add, size: 13)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Subtotal
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _rupiah.format(subtotal),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                    ),
                    const SizedBox(width: 4),

                    // Tombol Hapus (Kompak agar tidak overflow)
                    InkWell(
                      onTap: () => widget.onRemoveItem(index),
                      borderRadius: BorderRadius.circular(4),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.close, size: 15, color: Color(0xFF94A3B8)),
                      ),
                    ),
                  ],
                );
              },
            ),

          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 14),

          // Total Belanja
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TOTAL BELANJA',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: Color(0xFF64748B),
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _rupiah.format(widget.cartTotal),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.7,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Metode Pembayaran Selector
          const Text(
            'METODE PEMBAYARAN',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => widget.onPaymentMethodChanged('cash'),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: widget.paymentMethod == 'cash' ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: widget.paymentMethod == 'cash' ? const Color(0xFF059669) : const Color(0xFFE2E8F0),
                        width: widget.paymentMethod == 'cash' ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.payments_outlined, size: 16, color: widget.paymentMethod == 'cash' ? const Color(0xFF059669) : const Color(0xFF64748B)),
                        const SizedBox(width: 6),
                        Text(
                          'TUNAI',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: widget.paymentMethod == 'cash' ? const Color(0xFF059669) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () => widget.onPaymentMethodChanged('qris'),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: widget.paymentMethod == 'qris' ? const Color(0xFFEEF2FF) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: widget.paymentMethod == 'qris' ? const Color(0xFF4F46E5) : const Color(0xFFE2E8F0),
                        width: widget.paymentMethod == 'qris' ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code_2_rounded, size: 16, color: widget.paymentMethod == 'qris' ? const Color(0xFF4F46E5) : const Color(0xFF64748B)),
                        const SizedBox(width: 6),
                        Text(
                          'QRIS',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: widget.paymentMethod == 'qris' ? const Color(0xFF4F46E5) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Area Kalkulator Tunai (Jika Cash dipilih)
          if (widget.paymentMethod == 'cash') ...[
            const SizedBox(height: 14),
            TextField(
              controller: widget.cashInputCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Uang Diterima dari Pelanggan',
                hintText: '0',
                prefixText: 'Rp ',
              ),
            ),
            const SizedBox(height: 8),
            // Quick Cash Denomination Chips (Dinamis sesuai total belanja)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (widget.cartTotal > 0) ...[
                  _buildQuickCashChip('Uang Pas', widget.cartTotal),
                  ..._getSmartCashSuggestions(widget.cartTotal).map(
                    (val) => _buildQuickCashChip(_formatNominalLabel(val), val),
                  ),
                ] else ...[
                  _buildQuickCashChip('10rb', 10000),
                  _buildQuickCashChip('20rb', 20000),
                  _buildQuickCashChip('50rb', 50000),
                  _buildQuickCashChip('100rb', 100000),
                ],
              ],
            ),
            const SizedBox(height: 10),
            // Kotak Kembalian
            Builder(
              builder: (context) {
                final isCashEmpty = widget.cashInputCtrl.text.trim().isEmpty;
                final isOverOrExact = _cashChange >= 0;

                final Color bgColor = isCashEmpty
                    ? const Color(0xFFF8FAFC)
                    : (isOverOrExact ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2));

                final Color borderColor = isCashEmpty
                    ? const Color(0xFFE2E8F0)
                    : (isOverOrExact ? const Color(0xFF10B981).withAlpha(80) : const Color(0xFFEF4444).withAlpha(80));

                final Color textColor = isCashEmpty
                    ? const Color(0xFF64748B)
                    : (isOverOrExact ? const Color(0xFF059669) : const Color(0xFFDC2626));

                final String label = isCashEmpty
                    ? 'KEMBALIAN:'
                    : (isOverOrExact ? 'KEMBALIAN:' : 'UANG KURANG:');

                final String amountText = isCashEmpty
                    ? 'Rp0'
                    : _rupiah.format(_cashChange.abs());

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: textColor,
                        ),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          amountText,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: textColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ] else ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFC7D2FE)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Color(0xFF4F46E5)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tunjukkan QRIS toko kepada pelanggan. Pastikan dana sudah masuk sebelum menyelesaikan transaksi.',
                      style: TextStyle(fontSize: 11, height: 1.3, color: Color(0xFF4F46E5)),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Tombol Proses Transaksi
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _canSubmit ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _canSubmit ? widget.onSubmitOrder : null,
              icon: widget.isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_circle_outline, size: 18),
              label: Text(
                widget.isSubmitting
                    ? 'Memproses Transaksi...'
                    : (widget.paymentMethod == 'cash'
                        ? 'Selesaikan Tunai (${_rupiah.format(widget.cartTotal)})'
                        : 'Selesaikan QRIS (${_rupiah.format(widget.cartTotal)})'),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickCashChip(String label, double value) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      backgroundColor: const Color(0xFFF8FAFC),
      side: const BorderSide(color: Color(0xFFE2E8F0)),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      visualDensity: VisualDensity.compact,
      onPressed: () {
        widget.cashInputCtrl.text = value.toStringAsFixed(0);
        widget.cashInputCtrl.selection = TextSelection.fromPosition(
          TextPosition(offset: widget.cashInputCtrl.text.length),
        );
      },
    );
  }

  List<double> _getSmartCashSuggestions(double total) {
    if (total <= 0) return [];
    final Set<double> suggestions = {};

    // 1. Pembulatan ke kelipatan 5rb / 10rb terdekat di atas total
    final ceil5k = (total / 5000).ceil() * 5000.0;
    if (ceil5k > total) suggestions.add(ceil5k);

    final ceil10k = (total / 10000).ceil() * 10000.0;
    if (ceil10k > total) suggestions.add(ceil10k);

    final ceil20k = (total / 20000).ceil() * 20000.0;
    if (ceil20k > total) suggestions.add(ceil20k);

    // 2. Lembaran uang standar Indonesia (10rb, 20rb, 50rb, 100rb) yang lebih besar dari total
    const standardNotes = [10000.0, 20000.0, 50000.0, 100000.0];
    for (final note in standardNotes) {
      if (note > total) {
        suggestions.add(note);
      }
    }

    // Jika total di atas 100rb (misal 130rb), tambahkan opsi 150rb, 200rb
    if (total > 100000) {
      final ceil50k = (total / 50000).ceil() * 50000.0;
      if (ceil50k > total) suggestions.add(ceil50k);
      final ceil100k = (total / 100000).ceil() * 100000.0;
      if (ceil100k > total) suggestions.add(ceil100k);
    }

    final sorted = suggestions.toList()..sort();
    return sorted.take(4).toList();
  }

  String _formatNominalLabel(double value) {
    if (value >= 1000000) {
      final jt = value / 1000000;
      return jt == jt.roundToDouble() ? '${jt.toInt()}jt' : '${jt.toStringAsFixed(1)}jt';
    }
    if (value >= 1000) {
      final rb = value / 1000;
      return rb == rb.roundToDouble() ? '${rb.toInt()}rb' : '${rb.toStringAsFixed(1)}rb';
    }
    return value.toStringAsFixed(0);
  }
}
