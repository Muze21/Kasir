import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/receipt_service.dart';

class PosTicketDialog extends StatelessWidget {
  final int queueNumber;
  final double total;
  final String paymentMethod;
  final double cashReceived;
  final double change;
  final String customerName;
  final List<Map<String, dynamic>> items;
  final String? cashierName;
  final DateTime? timestamp;
  final VoidCallback onNextTransaction;
  final VoidCallback onBackToDashboard;

  static final _rupiah = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

  const PosTicketDialog({
    super.key,
    required this.queueNumber,
    required this.total,
    required this.paymentMethod,
    required this.cashReceived,
    required this.change,
    required this.customerName,
    this.items = const [],
    this.cashierName,
    this.timestamp,
    required this.onNextTransaction,
    required this.onBackToDashboard,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 380,
          maxHeight: screenHeight * 0.88,
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Ramping: Badge + Title + Tombol Tutup
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(
                      color: Color(0xFFECFDF5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_rounded, color: Color(0xFF059669), size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Transaksi Berhasil!',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Tercatat di server kaskita',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF94A3B8)),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Tutup',
                    onPressed: onBackToDashboard,
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Kotak Tiket Nomor Antrean Compact
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    const Text(
                      'NOMOR ANTREAN',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    Text(
                      '#$queueNumber',
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                        color: Colors.white,
                        height: 1.15,
                      ),
                    ),
                    if (customerName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          customerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFCBD5E1)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Rincian Pembayaran Compact
              Container(
                padding: const EdgeInsets.all(10),
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
                        const Text('Total Belanja:', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        Text(_rupiah.format(total), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Metode Bayar:', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        Text(paymentMethod == 'cash' ? 'TUNAI' : 'QRIS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: paymentMethod == 'cash' ? const Color(0xFF059669) : const Color(0xFF4F46E5))),
                      ],
                    ),
                    if (paymentMethod == 'cash') ...[
                      const Divider(height: 10, color: Color(0xFFE2E8F0)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Uang Diterima:', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          Text(_rupiah.format(cashReceived), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Kembalian:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                          Text(_rupiah.format(change), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF059669))),
                        ],
                      ),
                    ],
                    if (items.isNotEmpty) ...[
                      const Divider(height: 10, color: Color(0xFFE2E8F0)),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${items.length} Menu Dipesan:',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.4, color: Color(0xFF94A3B8)),
                        ),
                      ),
                      const SizedBox(height: 3),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 75),
                        child: ListView.builder(
                          shrinkWrap: true,
                          physics: const ClampingScrollPhysics(),
                          padding: EdgeInsets.zero,
                          itemCount: items.length,
                          itemBuilder: (context, idx) {
                            final it = items[idx];
                            final name = (it['name'] ?? it['item_name'] ?? 'Item').toString();
                            final qty = it['qty'] ?? it['quantity'] ?? 1;
                            final rawPrice = it['price'] ?? 0;
                            final price = (rawPrice is num) ? rawPrice : 0;
                            final subtotal = it['subtotal'] ?? (price * ((qty is num) ? qty : 1));

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 1.5),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      '$name × $qty',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _rupiah.format(subtotal),
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Tombol Struk Digital (Salin Nota & Kirim WhatsApp)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        final text = ReceiptService.generateReceiptText(
                          queueNumber: queueNumber,
                          total: total,
                          paymentMethod: paymentMethod,
                          cashReceived: cashReceived,
                          change: change,
                          customerName: customerName,
                          cashierName: cashierName,
                          timestamp: timestamp,
                          items: items,
                        );
                        ReceiptService.copyToClipboard(context, text);
                      },
                      icon: const Icon(Icons.copy_rounded, size: 14, color: Color(0xFF334155)),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Salin Nota',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        ReceiptService.showShareReceiptModal(
                          context: context,
                          queueNumber: queueNumber,
                          total: total,
                          paymentMethod: paymentMethod,
                          cashReceived: cashReceived,
                          change: change,
                          customerName: customerName,
                          cashierName: cashierName,
                          timestamp: timestamp,
                          items: items,
                        );
                      },
                      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 14),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Kirim WA',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Action Buttons
              SizedBox(
                width: double.infinity,
                height: 40,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: onNextTransaction,
                  icon: const Icon(Icons.add_shopping_cart, size: 15),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Transaksi Berikutnya (+)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                height: 32,
                child: TextButton(
                  onPressed: onBackToDashboard,
                  child: const Text('Kembali ke Dashboard', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
