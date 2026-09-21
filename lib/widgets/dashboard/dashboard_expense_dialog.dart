import 'package:flutter/material.dart';
import '../../models/pos_models.dart';

/// Preset cepat pengeluaran warung: kata kunci + nominal default (editable).
class _ExpensePreset {
  final String label;
  final String note;
  final double amount;
  const _ExpensePreset(this.label, this.note, this.amount);
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

  static const List<_ExpensePreset> _presets = [
    _ExpensePreset('Beli Es', 'Beli es batu', 5000),
    _ExpensePreset('Gas', 'Isi gas LPG', 22000),
    _ExpensePreset('Parkir', 'Parkir', 2000),
    _ExpensePreset('Plastik', 'Beli plastik', 3000),
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
            backgroundColor: const Color(0xFFDC2626),
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
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        title: const Text('Hapus Pengeluaran?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text('"${_noteCtrl.text.trim()}" (${_amountCtrl.text}) akan dihapus dan tidak ikut dalam laporan shift.'),
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
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      title: Row(
        children: [
          Icon(_isEditMode ? Icons.edit_outlined : Icons.arrow_downward, size: 20, color: const Color(0xFFDC2626)),
          const SizedBox(width: 8),
          Text(
            _isEditMode ? 'Ubah Pengeluaran' : 'Catat Biaya Operasional',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEditMode
                  ? 'Perubahan akan langsung diterapkan pada laporan shift ini.'
                  : 'Biaya ini akan langsung memotong kas masuk bersih shift yang sedang berjalan.',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            if (!_isEditMode) ...[
              const SizedBox(height: 12),
              const Text(
                'CEPAT',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _presets.map((p) {
                  return ActionChip(
                    avatar: const Icon(Icons.bolt, size: 14, color: Color(0xFF0F172A)),
                    label: Text(p.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                    backgroundColor: const Color(0xFFF8FAFC),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _applyPreset(p),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 14),
            const Text(
              'KATEGORI PENGELUARAN',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ExpenseCategories.all.map((cat) {
                final selected = _category == cat;
                return ChoiceChip(
                  label: Text(
                    cat,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? Colors.white : ExpenseCategories.textColor(cat),
                    ),
                  ),
                  selected: selected,
                  onSelected: (_) => setState(() => _category = cat),
                  selectedColor: ExpenseCategories.textColor(cat),
                  backgroundColor: ExpenseCategories.background(cat),
                  avatar: Icon(
                    ExpenseCategories.icons[cat],
                    size: 15,
                    color: selected ? Colors.white : ExpenseCategories.textColor(cat),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: selected ? ExpenseCategories.textColor(cat) : ExpenseCategories.textColor(cat).withAlpha(40),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Keterangan Biaya',
                hintText: 'Contoh: Beli Es Batu, Gas LPG, Plastik',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Nominal Biaya (Rp)',
                hintText: '0',
                prefixText: 'Rp ',
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (_isEditMode)
          TextButton.icon(
            onPressed: _isSubmitting || _isDeleting ? null : _delete,
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
            icon: _isDeleting
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFDC2626)))
                : const Icon(Icons.delete_outline, size: 18),
            label: const Text('Hapus'),
          ),
        const Spacer(),
        TextButton(
          onPressed: _isSubmitting || _isDeleting ? null : () => Navigator.pop(context, false),
          child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B))),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          onPressed: _isSubmitting || _isDeleting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(_isEditMode ? 'Simpan Perubahan' : 'Simpan Pengeluaran'),
        ),
      ],
    );
  }
}