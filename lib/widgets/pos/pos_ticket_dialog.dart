import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PosTicketDialog extends StatelessWidget {
  final int queueNumber;
  final double total;
  final String paymentMethod;
  final double cashReceived;
  final double change;
  final String customerName;
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
    required this.onNextTransaction,
    required this.onBackToDashboard,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Badge Sukses
              Container(
                width: 50,
                height: 50,
                decoration: const BoxDecoration(
                  color: Color(0xFFECFDF5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: Color(0xFF059669), size: 28),
              ),
              const SizedBox(height: 12),
              const Text(
                'Transaksi Berhasil!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Pesanan telah tercatat di server kaskita.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),

              const SizedBox(height: 16),

              // Kotak Tiket Nomor Antrean
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Text(
                      'NOMOR ANTREAN',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '#$queueNumber',
                      style: const TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                        color: Colors.white,
                      ),
                    ),
                    if (customerName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        customerName,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFCBD5E1)),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Rincian Pembayaran
              Container(
                padding: const EdgeInsets.all(12),
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
                        const Text('Total Belanja:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        Text(_rupiah.format(total), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Metode Bayar:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        Text(paymentMethod == 'cash' ? 'TUNAI' : 'QRIS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: paymentMethod == 'cash' ? const Color(0xFF059669) : const Color(0xFF4F46E5))),
                      ],
                    ),
                    if (paymentMethod == 'cash') ...[
                      const Divider(height: 12, color: Color(0xFFE2E8F0)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Uang Diterima:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                          Text(_rupiah.format(cashReceived), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Kembalian:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                          Text(_rupiah.format(change), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF059669))),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Action Buttons
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: onNextTransaction,
                  icon: const Icon(Icons.add_shopping_cart, size: 16),
                  label: const Text('Transaksi Berikutnya (+)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 38,
                child: TextButton(
                  onPressed: onBackToDashboard,
                  child: const Text('Kembali ke Dashboard', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
