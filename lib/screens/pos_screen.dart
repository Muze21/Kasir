import 'dart:async';
import 'package:flutter/material.dart';
import '../models/pos_models.dart';
import '../services/database_service.dart';
import '../widgets/pos/pos_cart_pane.dart';
import '../widgets/pos/pos_catalog_pane.dart';
import '../widgets/pos/pos_ticket_dialog.dart';
import '../widgets/pos/pos_top_bar.dart';
import 'manage_menu_screen.dart';
import 'report_screen.dart';

class PosScreen extends StatefulWidget {
  final Shift shift;
  const PosScreen({super.key, required this.shift});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final _db = DatabaseService();

  // Keranjang Belanja
  final List<Map<String, dynamic>> _cart = [];

  // Controllers Form
  final TextEditingController _customerNameCtrl = TextEditingController();
  final TextEditingController _customNameCtrl = TextEditingController();
  final TextEditingController _customPriceCtrl = TextEditingController();
  final TextEditingController _cashInputCtrl = TextEditingController();
  int _customQty = 1;

  // Status & Pembayaran
  String _paymentMethod = 'cash'; // 'cash' | 'qris'
  bool _isSubmitting = false;
  Timer? _clockTimer;
  DateTime _currentTime = DateTime.now();

  // Preset Barang Toko (Dinamis dari Database / Fallback)
  List<Map<String, dynamic>> _presetItems = [
    {'name': 'soto nasi', 'price': 12000.0, 'category': 'makanan'},
    {'name': 'kerupuk gede', 'price': 5000.0, 'category': 'makanan'},
    {'name': 'kerupuk kecil', 'price': 2000.0, 'category': 'makanan'},
  ];

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _cashInputCtrl.addListener(() {
      if (mounted) setState(() {});
    });
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _currentTime = DateTime.now());
      }
    });
  }

  Future<void> _loadProducts() async {
    try {
      final products = await _db.getProducts();
      if (!mounted) return;
      if (products.isNotEmpty) {
        setState(() {
          _presetItems = products.map((p) => p.toMap()).toList();
        });
      }
    } catch (_) {
      // Pertahankan menu fallback jika gagal/offline
    }
  }

  void _openManageMenu() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ManageMenuScreen()),
    ).then((_) {
      _loadProducts();
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _customerNameCtrl.dispose();
    _customNameCtrl.dispose();
    _customPriceCtrl.dispose();
    _cashInputCtrl.dispose();
    super.dispose();
  }

  // Perhitungan Keranjang
  double get _cartTotal => _cart.fold(
        0.0,
        (sum, item) => sum + ((item['price'] as num).toDouble() * (item['qty'] as int)),
      );

  int get _cartItemCount => _cart.fold(0, (sum, item) => sum + (item['qty'] as int));

  double get _cashReceived {
    final clean = _cashInputCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    return double.tryParse(clean) ?? 0.0;
  }

  double get _cashChange => _cashReceived - _cartTotal;

  // Operasi Keranjang
  void _addToCart(String name, double price, int qty) {
    setState(() {
      final existingIndex = _cart.indexWhere((i) => i['name'] == name);
      if (existingIndex >= 0) {
        _cart[existingIndex]['qty'] = (_cart[existingIndex]['qty'] as int) + qty;
      } else {
        _cart.add({
          'name': name,
          'price': price,
          'qty': qty,
        });
      }
    });
  }

  void _updateCartQty(int index, int delta) {
    setState(() {
      final newQty = (_cart[index]['qty'] as int) + delta;
      if (newQty <= 0) {
        _cart.removeAt(index);
      } else {
        _cart[index]['qty'] = newQty;
      }
    });
  }

  void _removeFromCart(int index) {
    setState(() {
      _cart.removeAt(index);
    });
  }

  void _clearCart() {
    setState(() {
      _cart.clear();
      _customerNameCtrl.clear();
      _cashInputCtrl.clear();
    });
  }

  // Proses Transaksi
  Future<void> _submitOrder() async {
    if (_cart.isEmpty) return;

    if (_paymentMethod == 'cash' && _cashReceived < _cartTotal) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nominal uang tunai yang diterima kurang dari total belanja!'),
          backgroundColor: Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final orderItems = _cart.map((item) {
        final price = (item['price'] as num).toDouble();
        final qty = (item['qty'] as num).toInt();
        return {
          'name': item['name'] as String,
          'item_name': item['name'] as String,
          'price': price,
          'qty': qty,
          'quantity': qty,
          'subtotal': price * qty,
        };
      }).toList();

      final customerName = _customerNameCtrl.text.trim();
      final totalPaid = _cartTotal;
      final cashGiven = _cashReceived;
      final changeAmount = _cashChange;
      final payMethod = _paymentMethod;

      final queueNumber = await _db.createOrder(
        shiftId: widget.shift.id,
        total: totalPaid,
        paymentMethod: payMethod,
        items: orderItems,
        customerName: customerName.isNotEmpty ? customerName : null,
      );

      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _cart.clear();
        _customerNameCtrl.clear();
        _cashInputCtrl.clear();
      });

      _showSuccessTicketDialog(
        queueNumber: queueNumber,
        total: totalPaid,
        paymentMethod: payMethod,
        cashReceived: cashGiven,
        change: changeAmount,
        customerName: customerName,
        items: orderItems,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memproses transaksi: $e'),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showSuccessTicketDialog({
    required int queueNumber,
    required double total,
    required String paymentMethod,
    required double cashReceived,
    required double change,
    required String customerName,
    required List<Map<String, dynamic>> items,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PosTicketDialog(
        queueNumber: queueNumber,
        total: total,
        paymentMethod: paymentMethod,
        cashReceived: cashReceived,
        change: change,
        customerName: customerName,
        items: items,
        onNextTransaction: () => Navigator.pop(ctx),
        onBackToDashboard: () {
          Navigator.pop(ctx);
          Navigator.pop(context);
        },
      ),
    );
  }

  // Tutup Toko
  Future<void> _closeShift() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tutup Sesi Toko?'),
        content: const Text('Setelah ditutup, Anda akan diarahkan ke laporan akhir dan rekap shift.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Tutup Toko'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;
    try {
      await _db.closeShift(widget.shift.id);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ReportScreen(shiftId: widget.shift.id, shiftTitle: 'Rekap Sesi Ditutup'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal tutup toko: $e')));
    }
  }

  void _viewReport() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ReportScreen(shiftId: widget.shift.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: PosTopBar(
        shift: widget.shift,
        currentTime: _currentTime,
        onViewReport: _viewReport,
        onCloseShift: _closeShift,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 820;

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Panel Kiri: Input & Katalog Barang Cepat (55% width)
                Expanded(
                  flex: 55,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: PosCatalogPane(
                      customerNameCtrl: _customerNameCtrl,
                      customNameCtrl: _customNameCtrl,
                      customPriceCtrl: _customPriceCtrl,
                      customQty: _customQty,
                      onCustomQtyChanged: (q) => setState(() => _customQty = q),
                      onAddToCart: _addToCart,
                      presetItems: _presetItems,
                      onManageMenu: _openManageMenu,
                    ),
                  ),
                ),
                // Divider Garis Vertikal
                Container(width: 1, color: const Color(0xFFE2E8F0)),
                // Panel Kanan: Keranjang & Checkout (45% width)
                Expanded(
                  flex: 45,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: PosCartPane(
                      cart: _cart,
                      onClearCart: _clearCart,
                      onUpdateQty: _updateCartQty,
                      onRemoveItem: _removeFromCart,
                      paymentMethod: _paymentMethod,
                      onPaymentMethodChanged: (m) => setState(() => _paymentMethod = m),
                      cashInputCtrl: _cashInputCtrl,
                      cartTotal: _cartTotal,
                      cartItemCount: _cartItemCount,
                      cashReceived: _cashReceived,
                      cashChange: _cashChange,
                      isSubmitting: _isSubmitting,
                      onSubmitOrder: _submitOrder,
                    ),
                  ),
                ),
              ],
            );
          }

          // Layout Mobile / Layar Sempit (Stacked Vertically)
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                PosCatalogPane(
                  customerNameCtrl: _customerNameCtrl,
                  customNameCtrl: _customNameCtrl,
                  customPriceCtrl: _customPriceCtrl,
                  customQty: _customQty,
                  onCustomQtyChanged: (q) => setState(() => _customQty = q),
                  onAddToCart: _addToCart,
                  presetItems: _presetItems,
                  onManageMenu: _openManageMenu,
                ),
                const SizedBox(height: 16),
                PosCartPane(
                  cart: _cart,
                  onClearCart: _clearCart,
                  onUpdateQty: _updateCartQty,
                  onRemoveItem: _removeFromCart,
                  paymentMethod: _paymentMethod,
                  onPaymentMethodChanged: (m) => setState(() => _paymentMethod = m),
                  cashInputCtrl: _cashInputCtrl,
                  cartTotal: _cartTotal,
                  cartItemCount: _cartItemCount,
                  cashReceived: _cashReceived,
                  cashChange: _cashChange,
                  isSubmitting: _isSubmitting,
                  onSubmitOrder: _submitOrder,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
