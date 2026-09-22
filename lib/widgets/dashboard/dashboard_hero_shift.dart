import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/pos_models.dart';

class DashboardHeroShift extends StatelessWidget {
  final Shift shift;
  final ShiftStats? stats;
  final Profile? opener;
  final double totalCash;
  final double totalQris;
  final int cashOrderCount;
  final int qrisOrderCount;
  final VoidCallback onOpenPos;
  final VoidCallback onAddExpense;
  final VoidCallback onViewReport;
  final VoidCallback onCloseShift;

  static final _rupiah = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);
  static final _waktu = DateFormat.Hm('id_ID');

  const DashboardHeroShift({
    super.key,
    required this.shift,
    required this.stats,
    required this.opener,
    required this.totalCash,
    required this.totalQris,
    required this.cashOrderCount,
    required this.qrisOrderCount,
    required this.onOpenPos,
    required this.onAddExpense,
    required this.onViewReport,
    required this.onCloseShift,
  });

  @override
  Widget build(BuildContext context) {
    final bersih = stats?.bersih ?? 0.0;
    final openerName = opener?.fullName ?? 'Petugas';
    final omzet = stats?.omzet ?? 0.0;
    final expenses = stats?.expenses ?? 0.0;
    final cashInDrawer = totalCash - expenses;

    final cashRatio = omzet > 0 ? (totalCash / omzet).clamp(0.0, 1.0) : 0.0;
    final qrisRatio = omzet > 0 ? (totalQris / omzet).clamp(0.0, 1.0) : 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 500;

        return Container(
          padding: EdgeInsets.all(isMobile ? 16 : 22),
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
              // Header Info Shift
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'KAS MASUK BERSIH SAAT INI',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _rupiah.format(bersih),
                            style: TextStyle(
                              fontSize: isMobile ? 26 : 32,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.0,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.schedule, size: 12, color: Color(0xFF64748B)),
                            const SizedBox(width: 4),
                            Text(
                              'Buka ${_waktu.format(shift.openedAt.toLocal())}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onViewReport,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.analytics_outlined, size: 13, color: Color(0xFF0F172A)),
                                SizedBox(width: 4),
                                Text(
                                  'Rekap Shift',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 8),
              Text(
                'Oleh $openerName • Omzet ${_rupiah.format(stats?.omzet ?? 0)} - Biaya ${_rupiah.format(stats?.expenses ?? 0)}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),

              const SizedBox(height: 18),

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
                          if (omzet == 0)
                            Expanded(
                              child: Container(color: const Color(0xFFE2E8F0)),
                            )
                          else ...[
                            if (cashRatio > 0)
                              Expanded(
                                flex: (cashRatio * 100).round().clamp(1, 100),
                                child: Container(color: const Color(0xFF059669)),
                              ),
                            if (qrisRatio > 0)
                              Expanded(
                                flex: (qrisRatio * 100).round().clamp(1, 100),
                                child: Container(color: const Color(0xFF2563EB)),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Menggunakan Wrap untuk mencegah overflow badge pada HP
                  Wrap(
                    spacing: 16,
                    runSpacing: 6,
                    children: [
                      _buildPaymentBadge(
                        dotColor: const Color(0xFF059669),
                        label: 'Tunai di Laci:',
                        value: _rupiah.format(cashInDrawer),
                        count: '$cashOrderCount trx',
                      ),
                      _buildPaymentBadge(
                        dotColor: const Color(0xFF2563EB),
                        label: 'QRIS:',
                        value: _rupiah.format(totalQris),
                        count: '$qrisOrderCount trx',
                      ),
                      if (expenses > 0)
                        _buildPaymentBadge(
                          dotColor: const Color(0xFFDC2626),
                          label: 'Kas Keluar:',
                          value: '-${_rupiah.format(expenses)}',
                          count: '',
                        ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Action buttons bar: Responsif untuk Mobile HP
              if (isMobile) ...[
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: SizedBox(
                        height: 44,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: onOpenPos,
                          icon: const Icon(Icons.point_of_sale_rounded, size: 16),
                          label: const Text('Kasir POS', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 44,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0F172A),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: onViewReport,
                          icon: const Icon(Icons.analytics_outlined, size: 15),
                          label: const Text('Rekap', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 42,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0F172A),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: onAddExpense,
                          icon: const Icon(Icons.payments_outlined, size: 15),
                          label: const Text('Kas Keluar', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 42,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFDC2626),
                            backgroundColor: const Color(0xFFFEF2F2),
                            side: const BorderSide(color: Color(0xFFFEE2E2)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: onCloseShift,
                          icon: const Icon(Icons.lock_clock_outlined, size: 15),
                          label: const Text('Tutup Toko', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
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
                          onPressed: onOpenPos,
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
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: onViewReport,
                          icon: const Icon(Icons.analytics_outlined, size: 16),
                          label: const Text('Laporan Shift', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
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
                          onPressed: onAddExpense,
                          icon: const Icon(Icons.payments_outlined, size: 16),
                          label: const Text('Kas Keluar', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
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
                        onPressed: onCloseShift,
                        icon: const Icon(Icons.lock_clock_outlined, size: 16),
                        label: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
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
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
        ),
        const SizedBox(width: 3),
        Text(
          '($count)',
          style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
        ),
      ],
    );
  }
}
