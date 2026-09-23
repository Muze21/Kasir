import 'package:flutter/material.dart';
import '../models/pos_models.dart';
import '../services/database_service.dart';
import '../widgets/restock/restock_cart_pane.dart';
import '../widgets/restock/restock_catalog_pane.dart';
import 'manage_material_screen.dart';

class RestockScreen extends StatefulWidget {
  const RestockScreen({super.key});

  @override
  State<RestockScreen> createState() => _RestockScreenState();
}

class _RestockScreenState extends State<RestockScreen> {
  final _db = DatabaseService();

  // Keranjang Belanja Pagi
  final List<Map<String, dynamic>> _cart = [];

  // Master Bahan Mentah dari Supabase
  List<MaterialItem> _materials = [];
  bool _loadingMaterials = true;

  @override
  void initState() {
    super.initState();
    _loadMaterials();
  }

  Future<void> _loadMaterials() async {
    try {
      final materials = await _db.getMaterials();
      if (!mounted) return;
      setState(() {
        _materials = materials;
        _loadingMaterials = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMaterials = false);
    }
  }

  void _openManageMaterials() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ManageMaterialScreen()),
    ).then((_) {
      _loadMaterials();
    });
  }

  double get _cartTotal => _cart.fold(
        0.0,
        (sum, item) => sum + (((item['price'] as num).toDouble()) * ((item['qty'] as int?) ?? 1)),
      );

  int get _cartItemCount => _cart.fold(0, (sum, item) => sum + ((item['qty'] as int?) ?? 1));

  Map<String, int> get _cartItemCounts {
    final map = <String, int>{};
    for (final item in _cart) {
      final name = item['name'] as String;
      map[name] = (map[name] ?? 0) + ((item['qty'] as int?) ?? 1);
    }
    return map;
  }

  void _addToCart(String name, double price, int qty) {
    setState(() {
      _cart.add({
        'name': name,
        'price': price,
        'qty': qty,
      });
    });
  }

  void _updateQty(int index, int delta) {
    setState(() {
      final qty = ((_cart[index]['qty'] as int?) ?? 1) + delta;
      if (qty <= 0) {
        _cart.removeAt(index);
      } else {
        _cart[index]['qty'] = qty;
      }
    });
  }

  void _removeItem(int index) {
    setState(() => _cart.removeAt(index));
  }

  void _clearCart() {
    setState(() => _cart.clear());
  }

  void _submit() {
    if (_cart.isEmpty) return;
    // Return list dalam format yang sama seperti morning expenses di dashboard
    final result = _cart.map((item) {
      return {
        'name': item['name'],
        'price': (item['price'] as num).toDouble(),
        'qty': (item['qty'] as int?) ?? 1,
      };
    }).toList();
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, size: 22, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Catat Belanja Pagi',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
            letterSpacing: -0.4,
          ),
        ),
        actions: [
          if (_cart.isNotEmpty)
            TextButton.icon(
              onPressed: _clearCart,
              icon: const Icon(Icons.delete_sweep_outlined, size: 18, color: Color(0xFFDC2626)),
              label: const Text('Kosongkan', style: TextStyle(fontSize: 12, color: Color(0xFFDC2626))),
            ),
          const SizedBox(width: 6),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE2E8F0)),
        ),
      ),
      body: _loadingMaterials
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A)))
          : LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 600;

                if (isNarrow) {
                  // Mobile: catalog di atas, cart disematkan di bawah
                  return Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              RestockCatalogPane(
                                materials: _materials,
                                onAddToCart: _addToCart,
                                onManageMaterials: _openManageMaterials,
                                cartItemCounts: _cartItemCounts,
                              ),
                              const SizedBox(height: 16),
                              // Ringkasan Keranjang (compact) di bawah
                              RestockCartPane(
                                cart: _cart,
                                onClearCart: _clearCart,
                                onUpdateQty: _updateQty,
                                onRemoveItem: _removeItem,
                                cartTotal: _cartTotal,
                                cartItemCount: _cartItemCount,
                                onSubmit: _submit,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                } else {
                  // Tablet/Desktop: catalog kiri, cart kanan (fixed saat scroll)
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: RestockCatalogPane(
                            materials: _materials,
                            onAddToCart: _addToCart,
                            onManageMaterials: _openManageMaterials,
                            cartItemCounts: _cartItemCounts,
                          ),
                        ),
                      ),
                      Container(width: 1, color: const Color(0xFFE2E8F0)),
                      Expanded(
                        flex: 4,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: RestockCartPane(
                            cart: _cart,
                            onClearCart: _clearCart,
                            onUpdateQty: _updateQty,
                            onRemoveItem: _removeItem,
                            cartTotal: _cartTotal,
                            cartItemCount: _cartItemCount,
                            onSubmit: _submit,
                          ),
                        ),
                      ),
                    ],
                  );
                }
              },
            ),
    );
  }
}