import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/pos_models.dart';

class DashboardStatsGrid extends StatelessWidget {
  final ShiftStats? stats;
  final int expenseCount;

  static final _rupiah = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

  const DashboardStatsGrid({
    super.key,
    required this.stats,
    required this.expenseCount,
  });

  @override
  Widget build(BuildContext context) {
    final omzet = stats?.omzet ?? 0.0;
    final expenses = stats?.expenses ?? 0.0;
    final orderCount = stats?.orderCount ?? 0;

    return Row(
      children: [
        Expanded(
          child: _BentoMetricTile(
            title: 'Total Penjualan',
            value: _rupiah.format(omzet),
            subtitle: '$orderCount pesanan',
            icon: Icons.trending_up_rounded,
            badgeColor: const Color(0xFFECFDF5),
            badgeTextColor: const Color(0xFF059669),
            badgeLabel: 'OMZET',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _BentoMetricTile(
            title: 'Pengeluaran Kasir',
            value: '-${_rupiah.format(expenses)}',
            subtitle: '$expenseCount pengeluaran',
            icon: Icons.trending_down_rounded,
            badgeColor: const Color(0xFFFEF2F2),
            badgeTextColor: const Color(0xFFDC2626),
            badgeLabel: 'KAS KELUAR',
          ),
        ),
      ],
    );
  }
}

class _BentoMetricTile extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color badgeColor;
  final Color badgeTextColor;
  final String badgeLabel;

  const _BentoMetricTile({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.badgeColor,
    required this.badgeTextColor,
    required this.badgeLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badgeLabel,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: badgeTextColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(icon, size: 12, color: const Color(0xFF94A3B8)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
