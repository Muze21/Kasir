import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PosCartPane extends StatelessWidget {
  final List<Map<String, dynamic>> cart;
  final VoidCallback onClearCart;
  final void Function(int index, int delta) onUpdateQty;
  final void Function(int index) onRemoveItem;
  final String paymentMethod;
  final ValueChanged<String> onPaymentMethodChanged;
  final TextEditingController cashInputCtrl;
  final double cartTotal;
  final int cartItemCount;
  final double cashReceived;
  final double cashChange;
  final bool isSubmitting;
  final VoidCallback onSubmitOrder;

  static final _rupiah = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

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
    required this.cashReceived,
    required this.cashChange,
    required this.isSubmitting,
    required this.onSubmitOrder,
  });

  bool get _canSubmit {
    if (cart.isEmpty || isSubmitting) return false;
    if (paymentMethod == 'cash') {
      return cashReceived >= cartTotal && cartTotal > 0;
    }
    return cartTotal > 0;
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
                'Keranjang ($cartItemCount item)',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const Spacer(),
              if (cart.isNotEmpty)
                TextButton(
                  onPressed: onClearCart,
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
          if (cart.isEmpty)
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
              itemCount: cart.length,
              separatorBuilder: (context, index) => const Divider(height: 12, color: Color(0xFFF1F5F9)),
              itemBuilder: (context, index) {
                final item = cart[index];
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
                            onTap: () => onUpdateQty(index, -1),
                            child: const Padding(padding: EdgeInsets.all(3), child: Icon(Icons.remove, size: 13)),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text('$qty', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                          ),
                          InkWell(
                            onTap: () => onUpdateQty(index, 1),
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
                      onTap: () => onRemoveItem(index),
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
                  _rupiah.format(cartTotal),
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
                  onTap: () => onPaymentMethodChanged('cash'),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: paymentMethod == 'cash' ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: paymentMethod == 'cash' ? const Color(0xFF059669) : const Color(0xFFE2E8F0),
                        width: paymentMethod == 'cash' ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.payments_outlined, size: 16, color: paymentMethod == 'cash' ? const Color(0xFF059669) : const Color(0xFF64748B)),
                        const SizedBox(width: 6),
                        Text(
                          'TUNAI',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: paymentMethod == 'cash' ? const Color(0xFF059669) : const Color(0xFF64748B),
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
                  onTap: () => onPaymentMethodChanged('qris'),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: paymentMethod == 'qris' ? const Color(0xFFEEF2FF) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: paymentMethod == 'qris' ? const Color(0xFF4F46E5) : const Color(0xFFE2E8F0),
                        width: paymentMethod == 'qris' ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code_2_rounded, size: 16, color: paymentMethod == 'qris' ? const Color(0xFF4F46E5) : const Color(0xFF64748B)),
                        const SizedBox(width: 6),
                        Text(
                          'QRIS',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: paymentMethod == 'qris' ? const Color(0xFF4F46E5) : const Color(0xFF64748B),
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
          if (paymentMethod == 'cash') ...[
            const SizedBox(height: 14),
            TextField(
              controller: cashInputCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Uang Diterima dari Pelanggan',
                hintText: '0',
                prefixText: 'Rp ',
              ),
            ),
            const SizedBox(height: 8),
            // Quick Cash Denomination Chips
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _buildQuickCashChip('Uang Pas', cartTotal),
                _buildQuickCashChip('10rb', 10000),
                _buildQuickCashChip('20rb', 20000),
                _buildQuickCashChip('50rb', 50000),
                _buildQuickCashChip('100rb', 100000),
              ],
            ),
            const SizedBox(height: 10),
            // Kotak Kembalian
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: cashInputCtrl.text.isEmpty
                    ? const Color(0xFFF8FAFC)
                    : (cashChange >= 0 ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2)),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: cashInputCtrl.text.isEmpty
                      ? const Color(0xFFE2E8F0)
                      : (cashChange >= 0 ? const Color(0xFF10B981).withAlpha(80) : const Color(0xFFEF4444).withAlpha(80)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    cashChange >= 0 ? 'KEMBALIAN:' : 'UANG KURANG:',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: cashChange >= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626),
                    ),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      cashInputCtrl.text.isEmpty
                          ? 'Rp0'
                          : _rupiah.format(cashChange.abs()),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: cashChange >= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626),
                      ),
                    ),
                  ),
                ],
              ),
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
              onPressed: _canSubmit ? onSubmitOrder : null,
              icon: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_circle_outline, size: 18),
              label: Text(
                isSubmitting
                    ? 'Memproses Transaksi...'
                    : (paymentMethod == 'cash'
                        ? 'Selesaikan Tunai (${_rupiah.format(cartTotal)})'
                        : 'Selesaikan QRIS (${_rupiah.format(cartTotal)})'),
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
        cashInputCtrl.text = value.toStringAsFixed(0);
      },
    );
  }
}
