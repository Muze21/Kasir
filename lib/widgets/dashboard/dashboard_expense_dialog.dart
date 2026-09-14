import 'package:flutter/material.dart';

class DashboardExpenseDialog extends StatefulWidget {
  final Future<void> Function(String note, double amount) onSubmit;

  const DashboardExpenseDialog({
    super.key,
    required this.onSubmit,
  });

  @override
  State<DashboardExpenseDialog> createState() => _DashboardExpenseDialogState();
}

class _DashboardExpenseDialogState extends State<DashboardExpenseDialog> {
  final _noteCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _noteCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
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
      await widget.onSubmit(note, amount);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mencatat pengeluaran: $e'),
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
      title: const Row(
        children: [
          Icon(Icons.arrow_downward, size: 20, color: Color(0xFFDC2626)),
          SizedBox(width: 8),
          Text(
            'Catat Biaya Operasional',
            style: TextStyle(
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
            const Text(
              'Biaya ini akan langsung memotong kas masuk bersih shift yang sedang berjalan.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
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
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context, false),
          child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B))),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Simpan Pengeluaran'),
        ),
      ],
    );
  }
}
