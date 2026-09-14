import 'package:flutter/material.dart';
import '../models/pos_models.dart';
import '../services/database_service.dart';

class PosScreen extends StatefulWidget {
  final Shift shift;
  const PosScreen({super.key, required this.shift});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final _db = DatabaseService();
  List<Order> _orders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    final orders = await _db.getOrders(widget.shift.id);
    setState(() {
      _orders = orders;
      _isLoading = false;
    });
  }

  void _showNewOrderDialog() {
    final nameCtrl = TextEditingController();
    final itemCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    final priceCtrl = TextEditingController();

    List<Map<String, dynamic>> items = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          double total = items.fold(0, (sum, i) => sum + (i['qty'] * i['price']));

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 16,
              right: 16,
              top: 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Transaksi Baru', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Nama Pelanggan (Opsional)'),
                  ),
                  const Divider(),
                  Row(
                    children: [
                      Expanded(flex: 2, child: TextField(controller: itemCtrl, decoration: const InputDecoration(labelText: 'Item'))),
                      const SizedBox(width: 8),
                      Expanded(child: TextField(controller: qtyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Qty'))),
                      const SizedBox(width: 8),
                      Expanded(flex: 2, child: TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Harga'))),
                      IconButton(
                        icon: const Icon(Icons.add_circle, color: Colors.green),
                        onPressed: () {
                          if (itemCtrl.text.isNotEmpty && priceCtrl.text.isNotEmpty) {
                            setModalState(() {
                              items.add({
                                'name': itemCtrl.text,
                                'qty': int.tryParse(qtyCtrl.text) ?? 1,
                                'price': double.tryParse(priceCtrl.text) ?? 0,
                              });
                              itemCtrl.clear();
                              qtyCtrl.text = '1';
                              priceCtrl.clear();
                            });
                          }
                        },
                      )
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...items.map((i) => ListTile(
                        dense: true,
                        title: Text('${i['name']} x${i['qty']}'),
                        trailing: Text('Rp ${(i['qty'] * i['price']).toStringAsFixed(0)}'),
                      )),
                  const Divider(),
                  Text('Total: Rp ${total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: items.isEmpty
                        ? null
                        : () async {
                            await _db.createOrder(
                              widget.shift.id,
                              total,
                              items,
                              customerName: nameCtrl.text.trim().isEmpty ? null : nameCtrl.text.trim(),
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                            _loadOrders();
                          },
                    child: const Text('Simpan Transaksi'),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kasir (POS)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOrders,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
              ? const Center(child: Text('Belum ada transaksi di shift ini.'))
              : ListView.builder(
                  itemCount: _orders.length,
                  itemBuilder: (ctx, idx) {
                    final order = _orders[idx];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        title: Text(order.customerName ?? 'Pelanggan ${order.queueNumber}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Total: Rp ${order.totalAmount.toStringAsFixed(0)}'),
                            Text('Diinput oleh: ${order.profile?.fullName ?? 'Kasir'}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showNewOrderDialog,
        child: const Icon(Icons.add_shopping_cart),
      ),
    );
  }
}
