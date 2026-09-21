import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/pos_models.dart';
import '../services/database_service.dart';

class ManageMenuScreen extends StatefulWidget {
  const ManageMenuScreen({super.key});

  @override
  State<ManageMenuScreen> createState() => _ManageMenuScreenState();
}

class _ManageMenuScreenState extends State<ManageMenuScreen> {
  final _db = DatabaseService();
  final _searchCtrl = TextEditingController();

  List<Product> _allProducts = [];
  bool _isLoading = true;
  String _selectedCategory = 'Semua';
  String _searchQuery = '';

  static final _rupiah = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      final products = await _db.getProducts();
      if (!mounted) return;
      setState(() {
        _allProducts = products;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  List<String> get _categories {
    final set = <String>{'Semua', 'Makanan', 'Minuman', 'Camilan'};
    for (final p in _allProducts) {
      if (p.category.isNotEmpty) {
        set.add(p.category[0].toUpperCase() + p.category.substring(1).toLowerCase());
      }
    }
    return set.toList();
  }

  List<Product> get _filteredProducts {
    return _allProducts.where((p) {
      final matchCat = _selectedCategory == 'Semua' ||
          p.category.toLowerCase() == _selectedCategory.toLowerCase();
      final matchSearch = _searchQuery.isEmpty || p.name.toLowerCase().contains(_searchQuery);
      return matchCat && matchSearch;
    }).toList();
  }

  void _showAddEditProductDialog({Product? product}) {
    final isEditing = product != null;
    final nameCtrl = TextEditingController(text: product?.name ?? '');
    final priceCtrl = TextEditingController(
      text: product != null ? product.price.toStringAsFixed(0) : '',
    );
    String category = product?.category ?? 'Makanan';
    final customCatCtrl = TextEditingController();
    bool isCustomCat = !['Makanan', 'Minuman', 'Camilan'].contains(category);
    if (isCustomCat) {
      customCatCtrl.text = category;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dlgContext, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          title: Text(
            isEditing ? 'Edit Menu Toko' : 'Tambah Menu Baru',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nama Menu / Barang',
                    hintText: 'Contoh: Es Teh Manis',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Harga Jual (Rp)',
                    hintText: '5000',
                    prefixText: 'Rp ',
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Kategori Menu:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: ['Makanan', 'Minuman', 'Camilan', 'Lainnya'].map((cat) {
                    final isSel = isCustomCat ? cat == 'Lainnya' : category == cat;
                    return ChoiceChip(
                      label: Text(cat),
                      selected: isSel,
                      onSelected: (_) {
                        setDialogState(() {
                          if (cat == 'Lainnya') {
                            isCustomCat = true;
                          } else {
                            isCustomCat = false;
                            category = cat;
                          }
                        });
                      },
                      selectedColor: const Color(0xFF0F172A),
                      backgroundColor: Colors.white,
                      labelStyle: TextStyle(
                        fontSize: 11,
                        fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                        color: isSel ? Colors.white : const Color(0xFF64748B),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                        side: BorderSide(
                          color: isSel ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
                ),
                if (isCustomCat) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: customCatCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nama Kategori Kustom',
                      hintText: 'Contoh: Paket Hemat',
                      isDense: true,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final priceClean = priceCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
                final price = double.tryParse(priceClean);
                final finalCat = isCustomCat
                    ? (customCatCtrl.text.trim().isNotEmpty ? customCatCtrl.text.trim() : 'Lainnya')
                    : category;

                if (name.isEmpty || price == null || price <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Lengkapi nama dan harga menu dengan benar.')),
                  );
                  return;
                }

                Navigator.pop(ctx);
                final messenger = ScaffoldMessenger.of(context);
                setState(() => _isLoading = true);

                try {
                  if (isEditing) {
                    await _db.updateProduct(
                      id: product.id,
                      name: name,
                      price: price,
                      category: finalCat,
                    );
                  } else {
                    await _db.addProduct(
                      name: name,
                      price: price,
                      category: finalCat,
                    );
                  }

                  _loadProducts();
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(isEditing ? 'Menu berhasil diperbarui' : 'Menu baru berhasil ditambahkan'),
                        backgroundColor: const Color(0xFF059669),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    setState(() => _isLoading = false);
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Gagal menyimpan menu: $e'),
                        backgroundColor: const Color(0xFFDC2626),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
              child: Text(isEditing ? 'Simpan Perubahan' : 'Tambah Menu'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteProduct(Product product) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        title: const Text('Hapus Menu?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text('Menu "${product.name}" akan dihapus dari katalog kasir toko.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _db.deleteProduct(product.id);
        _loadProducts();
        if (mounted) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Menu berhasil dihapus'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          messenger.showSnackBar(
            SnackBar(
              content: Text('Gagal menghapus menu: $e'),
              backgroundColor: const Color(0xFFDC2626),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredProducts;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context, true), // Return true to indicate reload needed
        ),
        title: const Text(
          'Kelola Menu Toko',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
            letterSpacing: -0.4,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, size: 22, color: Color(0xFF0F172A)),
            tooltip: 'Tambah Menu Baru',
            onPressed: () => _showAddEditProductDialog(),
          ),
          const SizedBox(width: 8),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE2E8F0)),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A)))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Search & Filter Header
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    children: [
                      // Search Field
                      TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          hintText: 'Cari menu toko...',
                          prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF64748B)),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Category Filter Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _categories.map((cat) {
                            final isSelected = _selectedCategory == cat;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(cat),
                                selected: isSelected,
                                onSelected: (_) => setState(() => _selectedCategory = cat),
                                selectedColor: const Color(0xFF0F172A),
                                backgroundColor: const Color(0xFFF8FAFC),
                                labelStyle: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  side: BorderSide(
                                    color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                visualDensity: VisualDensity.compact,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1, color: Color(0xFFE2E8F0)),

                // Total Menu Count Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Text(
                        'Total Menu (${filtered.length})',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                      ),
                      const Spacer(),
                      InkWell(
                        onTap: () => _showAddEditProductDialog(),
                        child: const Row(
                          children: [
                            Icon(Icons.add, size: 14, color: Color(0xFF059669)),
                            SizedBox(width: 4),
                            Text(
                              '+ Tambah Menu',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF059669)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Daftar Item Menu
                Expanded(
                  child: filtered.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          itemCount: filtered.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final p = filtered[index];

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  // Icon Kategori
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Icon(
                                      p.category.toLowerCase().contains('minum')
                                          ? Icons.local_cafe_outlined
                                          : Icons.restaurant_outlined,
                                      size: 18,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Nama & Kategori
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          p.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF1F5F9),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                p.category,
                                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              _rupiah.format(p.price),
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF059669),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Action Buttons
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF64748B)),
                                    tooltip: 'Edit Menu',
                                    onPressed: () => _showAddEditProductDialog(product: p),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFDC2626)),
                                    tooltip: 'Hapus Menu',
                                    onPressed: () => _confirmDeleteProduct(p),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.restaurant_menu, size: 24, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 12),
            const Text(
              'Belum Ada Menu',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tambahkan menu makanan atau minuman pertama toko Anda.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => _showAddEditProductDialog(),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Tambah Menu Sekarang'),
            ),
          ],
        ),
      ),
    );
  }
}
