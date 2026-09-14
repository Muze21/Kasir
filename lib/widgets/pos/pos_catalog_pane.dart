import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PosCatalogPane extends StatefulWidget {
  final TextEditingController customerNameCtrl;
  final TextEditingController customNameCtrl;
  final TextEditingController customPriceCtrl;
  final int customQty;
  final ValueChanged<int> onCustomQtyChanged;
  final void Function(String name, double price, int qty) onAddToCart;
  final List<Map<String, dynamic>> presetItems;
  final VoidCallback? onManageMenu;

  const PosCatalogPane({
    super.key,
    required this.customerNameCtrl,
    required this.customNameCtrl,
    required this.customPriceCtrl,
    required this.customQty,
    required this.onCustomQtyChanged,
    required this.onAddToCart,
    required this.presetItems,
    this.onManageMenu,
  });

  @override
  State<PosCatalogPane> createState() => _PosCatalogPaneState();
}

class _PosCatalogPaneState extends State<PosCatalogPane> {
  String _selectedCategory = 'Semua';
  static final _rupiah = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

  List<String> get _categories {
    final set = <String>{'Semua'};
    for (final item in widget.presetItems) {
      final cat = item['category']?.toString();
      if (cat != null && cat.isNotEmpty) {
        // Format Title Case untuk kategori
        set.add(cat[0].toUpperCase() + cat.substring(1).toLowerCase());
      }
    }
    return set.toList();
  }

  List<Map<String, dynamic>> get _filteredPresets {
    if (_selectedCategory == 'Semua') {
      return widget.presetItems;
    }
    return widget.presetItems.where((item) {
      final cat = item['category']?.toString().toLowerCase() ?? '';
      return cat == _selectedCategory.toLowerCase();
    }).toList();
  }

  void _handleAddCustomItem() {
    final name = widget.customNameCtrl.text.trim();
    final price = double.tryParse(widget.customPriceCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''));
    if (name.isNotEmpty && price != null && price > 0) {
      widget.onAddToCart(name, price, widget.customQty);
      widget.customNameCtrl.clear();
      widget.customPriceCtrl.clear();
      widget.onCustomQtyChanged(1);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Masukkan nama barang dan harga yang valid'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 400;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Card Input Nama Pelanggan / No. Meja
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_outline, size: 20, color: Color(0xFF64748B)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: widget.customerNameCtrl,
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: 'Nama Pelanggan / No. Meja (opsional)',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Header Filter Kategori & Chips
            Row(
              children: [
                const Icon(Icons.grid_view_rounded, size: 16, color: Color(0xFF64748B)),
                const SizedBox(width: 6),
                const Text(
                  'Katalog Barang Cepat',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                ),
                if (widget.onManageMenu != null) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: widget.onManageMenu,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.tune_rounded, size: 12, color: Color(0xFF334155)),
                          SizedBox(width: 4),
                          Text(
                            'Kelola Menu',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  '${_filteredPresets.length} item',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Kategori Chips (Horizontal Scrollable agar tidak overflow di HP)
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
                      backgroundColor: Colors.white,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? Colors.white : const Color(0xFF64748B),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 12),

            // Grid Preset Menu
            if (_filteredPresets.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.inventory_2_outlined, size: 32, color: Color(0xFF94A3B8)),
                      const SizedBox(height: 8),
                      const Text(
                        'Belum ada menu di kategori ini.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      if (widget.onManageMenu != null) ...[
                        const SizedBox(height: 10),
                        TextButton.icon(
                          onPressed: widget.onManageMenu,
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF059669),
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Tambah Menu Sekarang', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ],
                  ),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _filteredPresets.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isNarrow ? 2 : 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: isNarrow ? 1.6 : 1.7,
                ),
                itemBuilder: (context, index) {
                  final item = _filteredPresets[index];
                  final name = item['name'] as String;
                  final price = (item['price'] as num).toDouble();

                  return InkWell(
                    onTap: () => widget.onAddToCart(name, price, 1),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.2,
                            ),
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _rupiah.format(price),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF059669),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

            const SizedBox(height: 18),

            // Card Input Barang Kustom / Manual
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.edit_note_rounded, size: 18, color: Color(0xFF64748B)),
                      SizedBox(width: 8),
                      Text(
                        'Input Barang Kustom / Tambahan',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: widget.customNameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Nama Barang',
                            hintText: 'Contoh: Nasi Uduk Komplit',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: widget.customPriceCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Harga (Rp)',
                            hintText: '15000',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Stepper & Tombol Tambah: Adaptif jika layar sangat sempit
                  Row(
                    children: [
                      // Stepper Qty
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, size: 15),
                              padding: const EdgeInsets.all(6),
                              constraints: const BoxConstraints(),
                              onPressed: widget.customQty > 1
                                  ? () => widget.onCustomQtyChanged(widget.customQty - 1)
                                  : null,
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                '${widget.customQty}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, size: 15),
                              padding: const EdgeInsets.all(6),
                              constraints: const BoxConstraints(),
                              onPressed: () => widget.onCustomQtyChanged(widget.customQty + 1),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SizedBox(
                          height: 42,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F172A),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                            ),
                            onPressed: _handleAddCustomItem,
                            icon: const Icon(Icons.add_shopping_cart, size: 15),
                            label: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('Tambah ke Keranjang', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
