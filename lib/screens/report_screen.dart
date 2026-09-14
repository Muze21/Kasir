import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../services/receipt_service.dart';

class ReportScreen extends StatefulWidget {
  final String shiftId;
  final String? shiftTitle;

  const ReportScreen({
    super.key,
    required this.shiftId,
    this.shiftTitle,
  });

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _supabase = Supabase.instance.client;

  bool _loading = true;
  String? _error;

  double _omzet = 0;
  int _jumlah = 0;
  double _pengeluaran = 0;
  double _bersih = 0;

  double _mixCash = 0;
  double _mixQris = 0;

  List<Map<String, dynamic>> _transaksi = [];
  List<Map<String, dynamic>> _pengeluaranList = [];
  List<Map<String, dynamic>> _perKasir = [];

  static final _rupiah = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);
  static final _timeFmt = DateFormat.Hm('id_ID');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 1. Semua order di shift itu + profil siapa yang input
      final ordersRes = await _supabase
          .from('orders')
          .select('*, profiles(id, full_name), order_items(item_name, qty, price, subtotal)')
          .eq('shift_id', widget.shiftId)
          .order('queue_number', ascending: true);

      final expensesRes = await _supabase
          .from('expenses')
          .select('id, note, amount, user_id, created_at, profiles(id, full_name)')
          .eq('shift_id', widget.shiftId)
          .order('created_at', ascending: true);

      final orders = (ordersRes as List<dynamic>).cast<Map<String, dynamic>>();
      final expenses = (expensesRes as List<dynamic>).cast<Map<String, dynamic>>();

      // 2. HITUNG TOTAL TOKO
      double omzet = 0;
      double cCash = 0;
      double cQris = 0;

      for (final o in orders) {
        final status = (o['status'] as String?) ?? 'completed';
        if (status == 'voided') continue;

        final amt = (o['total_amount'] as num).toDouble();
        omzet += amt;
        final p = (o['payment_method'] as String?) ?? 'cash';
        if (p == 'qris') {
          cQris += amt;
        } else {
          cCash += amt;
        }
      }

      double totalExp = 0;
      for (final e in expenses) {
        totalExp += (e['amount'] as num).toDouble();
      }

      double bersih = omzet - totalExp;

      // 3. STRUKTUR TRANSAKSI / PENGELUARAN UNTUK UI
      final transaksi = orders.map((o) {
        final prof = o['profiles'];
        final status = (o['status'] as String?) ?? 'completed';
        return {
          'queue': o['queue_number'] ?? 0,
          'name': o['customer_name'] ?? 'Pelanggan ${o['queue_number']}',
          'total': (o['total_amount'] as num).toDouble(),
          'pay': (o['payment_method'] as String?) ?? 'cash',
          'status': status,
          'voidReason': o['void_reason'] as String?,
          'inputBy': prof != null ? (prof['full_name'] as String) : 'anggota',
          'items': (o['order_items'] as List<dynamic>?) ?? [],
          'created': o['created_at'] != null ? DateTime.parse(o['created_at'] as String).toLocal() : null,
        };
      }).toList();

      final pengeluaranList = expenses.map((e) {
        final prof = e['profiles'];
        return {
          'note': e['note'] as String,
          'amount': (e['amount'] as num).toDouble(),
          'inputBy': prof != null ? (prof['full_name'] as String) : 'anggota',
          'created': e['created_at'] != null ? DateTime.parse(e['created_at'] as String).toLocal() : null,
        };
      }).toList();

      // 4. REKAP PER KASIR
      Map<String, _Acc> acc = {};

      for (final o in orders) {
        final status = (o['status'] as String?) ?? 'completed';
        if (status == 'voided') continue;

        final uid = o['user_id'] as String;
        final prof = o['profiles'];
        final nama = prof != null ? (prof['full_name'] as String) : 'User ($uid)';
        final amt = (o['total_amount'] as num).toDouble();
        acc.putIfAbsent(uid, () => _Acc(name: nama, uid: uid));
        acc[uid]!.omzet += amt;
        acc[uid]!.jumOrder += 1;
      }

      for (final e in expenses) {
        final uid = e['user_id'] as String;
        final prof = e['profiles'];
        final nama = prof != null ? (prof['full_name'] as String) : 'User ($uid)';
        final amt = (e['amount'] as num).toDouble();
        acc.putIfAbsent(uid, () => _Acc(name: nama, uid: uid));
        acc[uid]!.pengeluaran += amt;
      }

      final perKasir = acc.values.map((a) => {
        'name': a.name,
        'omzet': a.omzet,
        'exp': a.pengeluaran,
        'jum': a.jumOrder,
        'bersih': a.omzet - a.pengeluaran,
      }).toList();

      if (!mounted) return;
      setState(() {
        _omzet = omzet;
        _jumlah = orders.length;
        _pengeluaran = totalExp;
        _bersih = bersih;
        _mixCash = cCash;
        _mixQris = cQris;
        _transaksi = transaksi;
        _pengeluaranList = pengeluaranList;
        _perKasir = perKasir;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.shiftTitle ?? 'Laporan Shift'),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFEAEAEA)),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF111111)))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, style: const TextStyle(color: Color(0xFF9F2F2D))),
                        const SizedBox(height: 16),
                        OutlinedButton(onPressed: _load, child: const Text('Coba lagi')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: const Color(0xFF111111),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Susunan total perlu di-highlight paling atas
                        _SectionLabel('Ringkasan Toko'),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF111111),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              _DarkStat(label: 'Total Omzet', value: _rupiah.format(_omzet), highlight: true),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(child: _DarkStatSmall(label: 'Transaksi', value: '$_jumlah')),
                                  const SizedBox(width: 12),
                                  Expanded(child: _DarkStatSmall(label: 'Pengeluaran', value: _rupiah.format(_pengeluaran))),
                                  const SizedBox(width: 12),
                                  Expanded(child: _DarkStatSmall(label: 'Bersih', value: _rupiah.format(_bersih), isGreen: true)),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Container(height: 1, color: const Color(0xFF2A2A2A)),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(child: _DarkStatSmall(label: 'Cash', value: _rupiah.format(_mixCash))),
                                  const SizedBox(width: 12),
                                  Expanded(child: _DarkStatSmall(label: 'QRIS', value: _rupiah.format(_mixQris))),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Perkiraan rekap per kasir (by user_id)
                        if (_perKasir.isNotEmpty) ...[
                          const _SectionLabel('Kontribusi Per Anggota'),
                          const SizedBox(height: 12),
                          for (final k in _perKasir)
                            Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFEAEAEA)),
                              ),
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    k['name'] as String,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF111111),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(child: _LightStat(label: 'Transaksi', value: '${k['jum']}x')),
                                      const SizedBox(width: 12),
                                      Expanded(child: _LightStat(label: 'Omzet', value: _rupiah.format(k['omzet']))),
                                      const SizedBox(width: 12),
                                      Expanded(child: _LightStat(label: 'Pengeluaran', value: _rupiah.format(k['exp']))),
                                      const SizedBox(width: 12),
                                      Expanded(child: _LightStat(label: 'Bersih', value: _rupiah.format(k['bersih']), highlight: true)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 24),
                        ],

                        // Daftar transaksi full
                        const _SectionLabel('Daftar Transaksi'),
                        if (_transaksi.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: Text('Belum ada transaksi di shift ini.', style: TextStyle(color: Color(0xFF787774))),
                          )
                        else
                          for (final t in _transaksi)
                            Container(
                              margin: const EdgeInsets.only(top: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFEAEAEA)),
                              ),
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF7F6F3),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '${t['queue']}',
                                          style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF111111)),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              t['name'] as String,
                                              style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF111111)),
                                            ),
                                            Text(
                                              'Diinput oleh: ${t['inputBy']}  |  ${t['pay'] == 'qris' ? 'QRIS' : 'Cash'}${t['created'] != null ? '  ·  ${_timeFmt.format(t['created'] as DateTime)}' : ''}',
                                              style: const TextStyle(fontSize: 12, color: Color(0xFF787774)),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (t['status'] == 'voided') ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFEF2F2),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text('BATAL', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFFDC2626))),
                                        ),
                                        const SizedBox(width: 6),
                                      ],
                                      Text(
                                        _rupiah.format(t['total']),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: t['status'] == 'voided' ? const Color(0xFF94A3B8) : const Color(0xFF111111),
                                          decoration: t['status'] == 'voided' ? TextDecoration.lineThrough : null,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        icon: const Icon(Icons.share_outlined, size: 18, color: Color(0xFF64748B)),
                                        tooltip: 'Kirim / Salin Struk',
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () {
                                          ReceiptService.showShareReceiptModal(
                                            context: context,
                                            queueNumber: (t['queue'] as num).toInt(),
                                            total: (t['total'] as num).toDouble(),
                                            paymentMethod: t['pay'] as String,
                                            customerName: t['name'] as String,
                                            cashierName: t['inputBy'] as String?,
                                            timestamp: t['created'] as DateTime?,
                                            items: (t['items'] as List<dynamic>?) ?? [],
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                  if ((t['items'] as List).isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFBFBFA),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFEAEAEA)),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      child: Column(
                                        children: [
                                          for (final it in (t['items'] as List))
                                            Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 4),
                                              child: Row(
                                                children: [
                                                  Expanded(child: Text('${it['item_name']} × ${it['qty']}', style: const TextStyle(fontSize: 13, color: Color(0xFF111111)))),
                                                  Text(_rupiah.format(it['subtotal']), style: const TextStyle(fontSize: 12, color: Color(0xFF787774))),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                        const SizedBox(height: 24),

                        // Daftar pengeluaran
                        const _SectionLabel('Daftar Pengeluaran'),
                        if (_pengeluaranList.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: Text('Belum ada pengeluaran.', style: TextStyle(color: Color(0xFF787774))),
                          )
                        else
                          for (final p in _pengeluaranList)
                            Container(
                              margin: const EdgeInsets.only(top: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFEAEAEA)),
                              ),
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(p['note'] as String, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF111111))),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Diinput oleh: ${p['inputBy']}${p['created'] != null ? '  ·  ${_timeFmt.format(p['created'] as DateTime)}' : ''}',
                                          style: const TextStyle(fontSize: 12, color: Color(0xFF787774)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(_rupiah.format(p['amount']), style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF9F2F2D))),
                                ],
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
    );
  }
}

class _DarkStat extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _DarkStat({required this.label, required this.value, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.6, color: Color(0xFFB7B7B7))),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: highlight ? const Color(0xFF7BC96F) : Colors.white,
          ),
        ),
      ],
    );
  }
}

class _DarkStatSmall extends StatelessWidget {
  final String label;
  final String value;
  final bool isGreen;

  const _DarkStatSmall({required this.label, required this.value, this.isGreen = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.6, color: Color(0xFFB7B7B7))),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isGreen ? const Color(0xFF7BC96F) : Colors.white)),
      ],
    );
  }
}

class _LightStat extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _LightStat({required this.label, required this.value, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.6, color: Color(0xFF787774))),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: highlight ? const Color(0xFF346538) : const Color(0xFF111111),
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: Color(0xFF787774),
      ),
    );
  }
}

class _Acc {
  String name;
  String uid;
  int jumOrder = 0;
  double omzet = 0;
  double pengeluaran = 0;

  _Acc({required this.name, required this.uid});
}
