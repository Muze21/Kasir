import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/pos_models.dart';

class DashboardClosedShift extends StatelessWidget {
  final Profile? profile;
  final Shift? lastClosedShift;
  final VoidCallback onOpenShift;
  final void Function(String shiftId) onViewReport;

  static final _waktu = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');

  const DashboardClosedShift({
    super.key,
    required this.profile,
    required this.lastClosedShift,
    required this.onOpenShift,
    required this.onViewReport,
  });

  @override
  Widget build(BuildContext context) {
    final cashierName = profile?.fullName ?? 'Petugas';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Workstation Standby Card
        Container(
          padding: const EdgeInsets.all(20),
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
                  Flexible(
                    child: Text(
                      'Kasir siap: $cashierName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Mulai Sesi Toko Hari Ini',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.7,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Buka sesi kasir untuk mulai mencatat pesanan, kelola antrean pelanggan, dan sinkronisasi pembayaran tunai maupun QRIS secara real-time.',
                style: TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 48,
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: onOpenShift,
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
        if (lastClosedShift != null) ...[
          const SizedBox(height: 14),
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
                        'Ditutup: ${lastClosedShift!.closedAt != null ? _waktu.format(lastClosedShift!.closedAt!.toLocal()) : '-'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0F172A),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onPressed: () => onViewReport(lastClosedShift!.id),
                  child: const Text('Lihat Laporan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
