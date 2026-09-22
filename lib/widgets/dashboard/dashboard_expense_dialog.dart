import 'package:flutter/material.dart';
import '../../models/pos_models.dart';

/// Preset cepat pengeluaran warung: kata kunci + nominal default + kategori default.
class _ExpensePreset {
  final String label;
  final String note;
  final double amount;
  final String category;
  const _ExpensePreset(this.label, this.note, this.amount, [this.category = 'Operasional']);
}

class DashboardExpenseDialog extends StatefulWidget {
  final Future<void> Function(String note, double amount, String category) onSubmit;
  final Future<void> Function()? onDelete;
  final String? initialNote;
  final double? initialAmount;
  final String initialCategory;

  const DashboardExpenseDialog({
    super.key,
    required this.onSubmit,
    this.onDelete,
    this.initialNote,
    this.initialAmount,
    this.initialCategory = 'Operasional',
  });

  @override
  State<DashboardExpenseDialog> createState() => _DashboardExpenseDialogState();
}

class _DashboardExpenseDialogState extends State<DashboardExpenseDialog> {
  late final _noteCtrl = TextEditingController(text: widget.initialNote ?? '');
  late final _amountCtrl = TextEditingController(
    text: widget.initialAmount != null ? widget.initialAmount!.toStringAsFixed(0) : '',
  );
  late String _category = widget.initialCategory;
  bool _isSubmitting = false;
  bool _isDeleting = false;

  static const Color _ink = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _panel = Color(0xFFF8FAFC);
  static const Color _danger = Color(0xFFDC2626);

  static const List<_ExpensePreset> _presets = [
    _ExpensePreset('Beli Es', 'Beli es batu', 5000, 'Operasional'),
    _ExpensePreset('Gas LPG', 'Isi gas LPG', 22000, 'Operasional'),
    _ExpensePreset('Plastik', 'Beli plastik & kresek', 5000, 'Operasional'),
    _ExpensePreset('Restok Bahan', 'Belanja bahan / stok toko', 50000, 'Bahan Baku'),
    _ExpensePreset('Ambil Pribadi', 'Tarik uang pribadi (Prive)', 50000, 'Pribadi'),
    _ExpensePreset('Uang Makan', 'Uang makan / jatah kasir', 15000, 'Pribadi'),
    _ExpensePreset('Parkir', 'Parkir', 2000, 'Transport'),
  ];

  bool get _isEditMode => widget.onDelete != null;

  @override
  void dispose() {
    _noteCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  void _applyPreset(_ExpensePreset preset) {
    setState(() {
      _noteCtrl.text = preset.note;
      _amountCtrl.text = preset.amount.toStringAsFixed(0);
      _category = preset.category;
    });
  }

  Future<void> _submit() async {
    final note = _noteCtrl.text.trim();
    final amountClean = _amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    final amount = double.tryParse(amountClean);

    if (note.isEmpty || amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lengkapi keterangan dan nominal pengeluaran.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await widget.onSubmit(note, amount, _category);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan pengeluaran: $e'),
            backgroundColor: _danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _border),
        ),
        title: const Text('Hapus Pengeluaran?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text('"${_noteCtrl.text.trim()}" (${_amountCtrl.text}) akan dihapus dan tidak ikut dalam laporan shift.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Hapus'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isDeleting = true);
    try {
      await widget.onDelete!();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menghapus pengeluaran: $e'),
            backgroundColor: _danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  InputDecoration _fieldDecoration({required String label, String? hint, String? prefixText}) {
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixText: prefixText,
      filled: true,
      fillColor: Colors.white,
      labelStyle: const TextStyle(color: _muted, fontSize: 13),
      hintStyle: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: border(_border, 1),
      enabledBorder: border(_border, 1),
      focusedBorder: border(_ink, 1.4),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: _muted),
      );

  Widget _categoryCard(String cat) {
    final selected = _category == cat;
    final tint = ExpenseCategories.textColor(cat);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _category = cat),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 84,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: selected ? tint.withAlpha(18) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? tint : _border, width: selected ? 1.4 : 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ExpenseCategories.icons[cat], size: 20, color: selected ? tint : _muted),
            const SizedBox(height: 6),
            Text(
              cat,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? tint : _ink,
                height: 1.15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _presetPill(_ExpensePreset p) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _applyPreset(p),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bolt, size: 13, color: Color(0xFF94A3B8)),
            const SizedBox(width: 5),
            Text(p.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _ink)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _danger.withAlpha(18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _isEditMode ? Icons.edit_outlined : Icons.arrow_downward,
                      size: 18,
                      color: _danger,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _isEditMode ? 'Ubah Pengeluaran' : 'Catat Kas Keluar',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _ink, letterSpacing: -0.2),
                    ),
                  ),
                  if (_isEditMode)
                    IconButton(
                      onPressed: _isSubmitting || _isDeleting ? null : _delete,
                      icon: _isDeleting
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: _danger))
                          : const Icon(Icons.delete_outline, size: 19, color: _danger),
                      tooltip: 'Hapus',
                      splashRadius: 18,
                    ),
                  IconButton(
                    onPressed: _isSubmitting || _isDeleting ? null : () => Navigator.pop(context, false),
                    icon: const Icon(Icons.close, size: 18, color: _muted),
                    splashRadius: 18,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _isEditMode
                    ? 'Perubahan langsung diterapkan ke laporan shift ini.'
                    : 'Langsung motong kas fisik di laci — restok, operasional, atau pribadi.',
                style: const TextStyle(fontSize: 12.5, color: _muted, height: 1.35),
              ),
              const SizedBox(height: 16),

              // Kategori — kartu, bukan chip kecil
              _sectionLabel('KATEGORI'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ExpenseCategories.all.map(_categoryCard).toList(),
              ),

              if (!_isEditMode) ...[
                const SizedBox(height: 16),
                _sectionLabel('ISI CEPAT'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _presets.map(_presetPill).toList(),
                ),
              ],

              const SizedBox(height: 18),
              TextField(
                controller: _noteCtrl,
                style: const TextStyle(fontSize: 14),
                decoration: _fieldDecoration(
                  label: 'Keterangan Pengeluaran',
                  hint: 'Contoh: Beli Es Batu, Belanja Beras/Stok',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                decoration: _fieldDecoration(
                  label: 'Nominal Kas Keluar',
                  hint: '0',
                  prefixText: 'Rp ',
                ),
              ),
              const SizedBox(height: 18),

              // Footer
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting || _isDeleting ? null : () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _muted,
                        side: const BorderSide(color: _border),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Batal', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _danger,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isSubmitting || _isDeleting ? null : _submit,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              _isEditMode ? 'Simpan Perubahan' : 'Simpan Pengeluaran',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}