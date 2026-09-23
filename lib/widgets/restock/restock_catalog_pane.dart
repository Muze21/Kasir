import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/pos_models.dart';

class RestockCatalogPane extends StatefulWidget {
  final List<MaterialItem> materials;
  final void Function(String name, double price, int qty) onAddToCart;
  final VoidCallback? onManageMaterials;
  final Map<String, int> cartItemCounts;

  const RestockCatalogPane({
    super.key,
    required this.materials,
    required this.onAddToCart,
    this.onManageMaterials,
    this.cartItemCounts = const {},
  });

  @override
  State<RestockCatalogPane> createState() => _RestockCatalogPaneState();
}

class _RestockCatalogPaneState extends State<RestockCatalogPane> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _priceCtrl = TextEditingController();
  int _qty = 1;
  bool _isCustomExpanded = false;

  static final _rupiah = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  void _handleAddCustomItem() {
    final name = _nameCtrl.text.trim();
    final price = double.tryParse(_priceCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''));
    if (name.isNotEmpty && price != null && price > 0) {
      widget.onAddToCart(name, price, _qty);
      _nameCtrl.clear();
      _priceCtrl.clear();
      setState(() => _qty = 1);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Masukkan nama bahan dan harga yang valid'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 360;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Katalog Bahan + Tombol Kelola
            Row(
              children: [
                const Icon(Icons.category_outlined, size: 16, color: Color(0xFF64748B)),
                const SizedBox(width: 6),
                const Text(
                  'Katalog Bahan Belanja',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                ),
                if (widget.onManageMaterials != null) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: widget.onManageMaterials,
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
                            'Kelola Bahan',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  '${widget.materials.length} item',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Grid Bahan
            if (widget.materials.isEmpty)
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
                        'Belum ada bahan mentah.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      if (widget.onManageMaterials != null) ...[
                        const SizedBox(height: 10),
                        TextButton.icon(
                          onPressed: widget.onManageMaterials,
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF059669),
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Tambahkan Bahan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
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
                itemCount: widget.materials.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isNarrow ? 2 : 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: isNarrow ? 1.7 : 1.8,
                ),
                itemBuilder: (context, index) {
                  final m = widget.materials[index];
                  final inCartQty = widget.cartItemCounts[m.name] ?? 0;

                  return InkWell(
                    onTap: () => widget.onAddToCart(m.name, m.defaultPrice, 1),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: inCartQty > 0 ? const Color(0xFF059669) : const Color(0xFFE2E8F0),
                          width: inCartQty > 0 ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            m.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _rupiah.format(m.defaultPrice),
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                                ),
                              ),
                              if (inCartQty > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF059669),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'x$inCartQty',
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

            const SizedBox(height: 14),

            // Card Input Barang Manual / Kustom (Accordion)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  InkWell(
                    onTap: () => setState(() => _isCustomExpanded = !_isCustomExpanded),
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Icon(
                            _isCustomExpanded ? Icons.edit_note_rounded : Icons.add_circle_outline_rounded,
                            size: 18,
                            color: const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Input Bahan Manual / Kustom',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                            ),
                          ),
                          Icon(
                            _isCustomExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                            size: 20,
                            color: const Color(0xFF64748B),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_isCustomExpanded)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _nameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Nama Bahan',
                              hintText: 'Contoh: Ikan Bawal, Sayur Kangkung',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: _priceCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Harga Beli',
                                    hintText: '0',
                                    prefixText: 'Rp ',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Qty Stepper
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                decoration: BoxDecoration(
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove, size: 16),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 24, minHeight: 28),
                                      onPressed: () => setState(() => _qty = _qty > 1 ? _qty - 1 : 1),
                                    ),
                                    Text('$_qty', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                                    IconButton(
                                      icon: const Icon(Icons.add, size: 16),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 24, minHeight: 28),
                                      onPressed: () => setState(() => _qty++),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F172A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: _handleAddCustomItem,
                            icon: const Icon(Icons.add_shopping_cart, size: 16),
                            label: const Text('Tambahkan ke Belanja', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
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