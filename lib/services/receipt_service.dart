import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class ReceiptService {
  static final _rupiah = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

  /// Format teks nota struk digital yang rapi untuk WhatsApp / Clipboard
  static String generateReceiptText({
    required int queueNumber,
    required double total,
    required String paymentMethod,
    double? cashReceived,
    double? change,
    String? customerName,
    String? cashierName,
    DateTime? timestamp,
    List<dynamic>? items,
  }) {
    final time = timestamp ?? DateTime.now();
    final timeStr = DateFormat('dd/MM/yyyy HH:mm', 'id_ID').format(time.toLocal());
    final isCash = paymentMethod.toLowerCase() == 'cash';

    final buffer = StringBuffer();
    buffer.writeln('================================');
    buffer.writeln('         *KASKITA POS*');
    buffer.writeln('    Nota Pembayaran Digital');
    buffer.writeln('================================');
    buffer.writeln('No. Antrean : #$queueNumber');
    buffer.writeln('Waktu       : $timeStr WIB');
    if (customerName != null && customerName.trim().isNotEmpty) {
      buffer.writeln('Pelanggan   : ${customerName.trim()}');
    }
    if (cashierName != null && cashierName.trim().isNotEmpty) {
      buffer.writeln('Kasir       : ${cashierName.trim()}');
    }
    buffer.writeln('--------------------------------');
    buffer.writeln('*RINCIAN PESANAN:*');

    if (items != null && items.isNotEmpty) {
      for (final item in items) {
        final name = (item['name'] ?? item['item_name'] ?? 'Item').toString();
        final rawQty = item['qty'] ?? item['quantity'] ?? 1;
        final qty = (rawQty is num) ? rawQty.toInt() : 1;
        final rawPrice = item['price'] ?? 0;
        final price = (rawPrice is num) ? rawPrice.toDouble() : 0.0;
        final rawSubtotal = item['subtotal'] ?? (price * qty);
        final subtotal = (rawSubtotal is num) ? rawSubtotal.toDouble() : (price * qty);

        buffer.writeln('• $name x$qty');
        buffer.writeln('  @${_rupiah.format(price)} = ${_rupiah.format(subtotal)}');
      }
    } else {
      buffer.writeln('• Pesanan (Total: ${_rupiah.format(total)})');
    }

    buffer.writeln('--------------------------------');
    buffer.writeln('Total Belanja : ${_rupiah.format(total)}');
    buffer.writeln('Metode Bayar  : ${isCash ? 'TUNAI' : 'QRIS'}');

    if (isCash && cashReceived != null && cashReceived > 0) {
      buffer.writeln('Uang Diterima : ${_rupiah.format(cashReceived)}');
      final changeAmt = change ?? (cashReceived - total);
      buffer.writeln('Kembalian     : ${_rupiah.format(changeAmt >= 0 ? changeAmt : 0)}');
    }

    buffer.writeln('================================');
    buffer.writeln(' Terima kasih atas kunjungan Anda!');
    buffer.writeln('   Semoga harimu menyenangkan 😊');
    buffer.writeln('================================');

    return buffer.toString();
  }

  /// Salin teks nota ke Clipboard perangkat
  static Future<void> copyToClipboard(BuildContext context, String receiptText) async {
    await Clipboard.setData(ClipboardData(text: receiptText));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Color(0xFF10B981), size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Nota struk berhasil disalin ke clipboard!',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: Color(0xFF0F172A),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// Buka WhatsApp dengan teks nota
  static Future<void> shareToWhatsApp(
    BuildContext context,
    String receiptText, {
    String? phoneNumber,
  }) async {
    String cleanPhone = '';
    if (phoneNumber != null && phoneNumber.trim().isNotEmpty) {
      cleanPhone = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
      if (cleanPhone.startsWith('0')) {
        cleanPhone = '62${cleanPhone.substring(1)}';
      } else if (cleanPhone.startsWith('8')) {
        cleanPhone = '62$cleanPhone';
      }
    }

    final Uri uri;
    if (cleanPhone.isNotEmpty) {
      uri = Uri.parse('https://wa.me/$cleanPhone?text=${Uri.encodeComponent(receiptText)}');
    } else {
      uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(receiptText)}');
    }

    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak dapat membuka WhatsApp. Silakan gunakan opsi Salin Nota.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuka WhatsApp: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Tampilkan Modal Dialog untuk Share / Salin Struk
  static void showShareReceiptModal({
    required BuildContext context,
    required int queueNumber,
    required double total,
    required String paymentMethod,
    double? cashReceived,
    double? change,
    String? customerName,
    String? cashierName,
    DateTime? timestamp,
    List<dynamic>? items,
  }) {
    final receiptText = generateReceiptText(
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

    final phoneCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF059669), size: 20),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Kirim Struk Digital',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Input nomor WhatsApp opsional
                const Text(
                  'Nomor WhatsApp Pelanggan (opsional):',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.phone_android, size: 18, color: Color(0xFF64748B)),
                    hintText: 'Contoh: 081234567890',
                    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF059669), width: 1.5),
                    ),
                  ),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),

                // Preview Struk Teks
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: SingleChildScrollView(
                    child: Text(
                      receiptText,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: Color(0xFF1E293B),
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              // Tombol Salin Teks
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    copyToClipboard(context, receiptText);
                  },
                  icon: const Icon(Icons.copy_rounded, size: 15, color: Color(0xFF334155)),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Salin Nota',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Tombol Kirim WhatsApp
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    final phone = phoneCtrl.text.trim();
                    Navigator.pop(ctx);
                    shareToWhatsApp(context, receiptText, phoneNumber: phone);
                  },
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 15),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Kirim WA',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Format teks rekap laporan shift yang rapi untuk dikirim via WhatsApp / Clipboard
  static String generateShiftSummaryText({
    required String shiftStatus,
    required DateTime openedAt,
    DateTime? closedAt,
    String? openerName,
    String? closerName,
    required double omzet,
    required double cashTotal,
    required double qrisTotal,
    required int cashCount,
    required int qrisCount,
    required double expensesTotal,
    required int expenseCount,
    required double bersih,
    required int completedOrdersCount,
    required int voidedOrdersCount,
    required double voidedTotal,
    required List<Map<String, dynamic>> perKasir,
  }) {
    final openStr = DateFormat('dd/MM/yyyy HH:mm', 'id_ID').format(openedAt.toLocal());
    final closeStr = closedAt != null ? DateFormat('dd/MM/yyyy HH:mm', 'id_ID').format(closedAt.toLocal()) : 'Masih Berjalan (Aktif)';
    final duration = (closedAt ?? DateTime.now()).difference(openedAt);
    final hours = duration.inHours;
    final mins = duration.inMinutes.remainder(60);
    final durationStr = '${hours > 0 ? '$hours jam ' : ''}$mins menit';

    final buffer = StringBuffer();
    buffer.writeln('================================');
    buffer.writeln('     *REKAP SESI SHIFT KASKITA*');
    buffer.writeln('================================');
    buffer.writeln('Status Sesi   : ${shiftStatus.toUpperCase()}');
    buffer.writeln('Waktu Buka    : $openStr WIB');
    buffer.writeln('Waktu Tutup   : $closeStr${closedAt != null ? ' WIB' : ''}');
    buffer.writeln('Durasi Sesi   : $durationStr');
    if (openerName != null && openerName.isNotEmpty) {
      buffer.writeln('Petugas Buka  : $openerName');
    }
    if (closerName != null && closerName.isNotEmpty && closerName != openerName) {
      buffer.writeln('Petugas Tutup : $closerName');
    }
    buffer.writeln('--------------------------------');
    buffer.writeln('*RINGKASAN KEUANGAN:*');
    buffer.writeln('• Total Penjualan (Omzet) : ${_rupiah.format(omzet)}');
    buffer.writeln('  └ Tunai (Cash di Laci) : ${_rupiah.format(cashTotal)} ($cashCount trx)');
    buffer.writeln('  └ QRIS                 : ${_rupiah.format(qrisTotal)} ($qrisCount trx)');
    buffer.writeln('• Kas Keluar (Biaya)     : -${_rupiah.format(expensesTotal)} ($expenseCount item)');
    buffer.writeln('--------------------------------');
    buffer.writeln('*KAS MASUK BERSIH*        : *${_rupiah.format(bersih)}*');
    buffer.writeln('--------------------------------');
    buffer.writeln('*STATISTIK OPERASIONAL:*');
    buffer.writeln('• Pesanan Selesai         : $completedOrdersCount transaksi');
    if (completedOrdersCount > 0) {
      final aov = omzet / completedOrdersCount;
      buffer.writeln('• Rata-rata per Pesanan   : ${_rupiah.format(aov)}');
    }
    if (voidedOrdersCount > 0) {
      buffer.writeln('• Pesanan Dibatalkan/Void : $voidedOrdersCount transaksi (${_rupiah.format(voidedTotal)})');
    }

    if (perKasir.isNotEmpty) {
      buffer.writeln('--------------------------------');
      buffer.writeln('*KONTRIBUSI KASIR:*');
      for (final k in perKasir) {
        final name = k['name'] ?? 'Kasir';
        final kOmzet = (k['omzet'] as num?)?.toDouble() ?? 0.0;
        final kExp = (k['exp'] as num?)?.toDouble() ?? 0.0;
        final kJum = k['jum'] ?? 0;
        buffer.writeln('• $name: $kJum trx | Omzet ${_rupiah.format(kOmzet)}${kExp > 0 ? ' | Biaya -${_rupiah.format(kExp)}' : ''}');
      }
    }

    buffer.writeln('================================');
    buffer.writeln('  Laporan Otomatis KasKita POS');
    buffer.writeln('================================');

    return buffer.toString();
  }

  /// Modal dialog untuk membagikan rekap shift via WhatsApp / Clipboard
  static void showShareShiftReportModal({
    required BuildContext context,
    required String shiftStatus,
    required DateTime openedAt,
    DateTime? closedAt,
    String? openerName,
    String? closerName,
    required double omzet,
    required double cashTotal,
    required double qrisTotal,
    required int cashCount,
    required int qrisCount,
    required double expensesTotal,
    required int expenseCount,
    required double bersih,
    required int completedOrdersCount,
    required int voidedOrdersCount,
    required double voidedTotal,
    required List<Map<String, dynamic>> perKasir,
  }) {
    final reportText = generateShiftSummaryText(
      shiftStatus: shiftStatus,
      openedAt: openedAt,
      closedAt: closedAt,
      openerName: openerName,
      closerName: closerName,
      omzet: omzet,
      cashTotal: cashTotal,
      qrisTotal: qrisTotal,
      cashCount: cashCount,
      qrisCount: qrisCount,
      expensesTotal: expensesTotal,
      expenseCount: expenseCount,
      bersih: bersih,
      completedOrdersCount: completedOrdersCount,
      voidedOrdersCount: voidedOrdersCount,
      voidedTotal: voidedTotal,
      perKasir: perKasir,
    );

    final phoneCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.assessment_rounded, color: Color(0xFF0F172A), size: 22),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Bagikan Rekap Shift',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Kirim ringkasan sesi shift ini ke WhatsApp Owner/Grup atau salin ke clipboard.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: SingleChildScrollView(
                child: Text(
                  reportText,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    height: 1.4,
                    color: Color(0xFF334155),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Nomor WhatsApp Tujuan (Opsional)',
                hintText: 'Contoh: 08123456789 atau kosongkan untuk pilih kontak',
                prefixIcon: const Icon(Icons.phone_outlined, size: 18, color: Color(0xFF64748B)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0F172A),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      copyToClipboard(context, reportText);
                    },
                    icon: const Icon(Icons.copy_outlined, size: 16),
                    label: const Text(
                      'Salin Teks',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      final phone = phoneCtrl.text.trim();
                      Navigator.pop(ctx);
                      shareToWhatsApp(context, reportText, phoneNumber: phone);
                    },
                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                    label: const Text(
                      'Kirim ke WA',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
