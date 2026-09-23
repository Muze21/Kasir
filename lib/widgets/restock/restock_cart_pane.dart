import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RestockCartPane extends StatefulWidget {
  final List<Map<String, dynamic>> cart;
  final VoidCallback onClearCart;
  final void Function(int index, int delta) onUpdateQty;
  final void Function(int index) onRemoveItem;
  final double cartTotal;
  final int cartItemCount;
  final VoidCallback onSubmit;

  const RestockCartPane({
    super.key,
    required this.cart,
    required this.onClearCart,
    required this.onUpdateQty,
    required this.onRemoveItem,
    required this.cartTotal,
    required this.cartItemCount,
    required this.onSubmit,
  });

  @override
  State<RestockCartPane> createState() => _RestockCartPaneState();
}

class _RestockCartPaneState extends State<RestockCartPane> {
  static final _rupiah = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

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
          // Header
          Row(
            children: [
              const Icon(Icons.shopping_cart_outlined, size: 18, color: Color(0xFF0F172A)),
              const SizedBox(width: 8),
              Text(
                'Belanja Pagi (${widget.cartItemCount} item)',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
              const Spacer(),
              if (widget.cart.isNotEmpty)
                InkWell(
                  onTap: widget.onClearCart,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.delete_sweep_outlined, size: 14, color: Color(0xFFDC2626)),
                        SizedBox(width: 4),
                        Text('Kosongkan', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFDC2626))),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 10),

          // Isi Keranjang
          if (widget.cart.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Column(
                children: [
                  Icon(Icons.shopping_cart_outlined, size: 28, color: Color(0xFFCBD5E1)),
                  SizedBox(height: 6),
                  Text(
                    'Belum ada item belanja',
                    style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.cart.length,
              itemBuilder: (context, index) {
                final item = widget.cart[index];
                final name = item['name'] as String;
                final price = (item['price'] as num).toDouble();
                final qty = (item['qty'] as int?) ?? 1;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Qty Stepper
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () => widget.onUpdateQty(index, -1),
                              child: const Padding(
                                padding: EdgeInsets.all(5),
                                child: Icon(Icons.remove, size: 15),
                              ),
                            ),
                            Text('$qty', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                            InkWell(
                              onTap: () => widget.onUpdateQty(index, 1),
                              child: const Padding(
                                padding: EdgeInsets.all(5),
                                child: Icon(Icons.add, size: 15),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _rupiah.format(price * qty),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFFDC2626)),
                            ),
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: () => widget.onRemoveItem(index),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.close, size: 18, color: Color(0xFF94A3B8)),
                        ),
                      ),
                    ],
                  ),
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

          // Info bahwa ini mengurangi modal pagi
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 15, color: Color(0xFFDC2626)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Daftar ini akan mengurangi modal awal laci ketika toko dibuka.',
                    style: TextStyle(fontSize: 11, height: 1.4, color: Color(0xFFB91C1C)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Tombol Simpan
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFF94A3B8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: widget.cart.isEmpty ? null : widget.onSubmit,
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text(
                'Simpan Belanja Pagi',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}