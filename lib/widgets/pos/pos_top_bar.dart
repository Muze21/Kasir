import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/pos_models.dart';

class PosTopBar extends StatelessWidget implements PreferredSizeWidget {
  final Shift shift;
  final DateTime currentTime;
  final VoidCallback onViewReport;
  final VoidCallback onCloseShift;

  static final _waktu = DateFormat.Hm('id_ID');

  const PosTopBar({
    super.key,
    required this.shift,
    required this.currentTime,
    required this.onViewReport,
    required this.onCloseShift,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 1);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final timeStr = DateFormat(isMobile ? 'HH:mm' : 'HH:mm:ss', 'id_ID').format(currentTime);

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Color(0xFF0F172A)),
        tooltip: 'Kembali ke Dashboard',
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Flexible(
            child: Text(
              'Terminal Kasir',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: -0.4,
              ),
            ),
          ),
          if (!isMobile) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFF10B981).withAlpha(60)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(color: Color(0xFF059669), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Buka ${_waktu.format(shift.openedAt.toLocal())}',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF059669)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        // Jam Digital Compact
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Text(
            '$timeStr WIB',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
          ),
        ),
        const SizedBox(width: 4),

        // Tombol Laporan
        IconButton(
          icon: const Icon(Icons.assessment_outlined, size: 20, color: Color(0xFF0F172A)),
          tooltip: 'Laporan Sesi',
          onPressed: onViewReport,
        ),

        // Tombol Tutup Toko
        IconButton(
          icon: const Icon(Icons.lock_outline, size: 20, color: Color(0xFFDC2626)),
          tooltip: 'Tutup Shift',
          onPressed: onCloseShift,
        ),
        const SizedBox(width: 6),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: Color(0xFFE2E8F0)),
      ),
    );
  }
}
