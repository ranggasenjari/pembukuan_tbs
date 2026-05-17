import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../models/deposit_model.dart';
import '../../providers/providers.dart';

class SaldoEntryDialog extends ConsumerStatefulWidget {
  final DepositModel? depositToEdit;
  const SaldoEntryDialog({super.key, this.depositToEdit});

  @override
  ConsumerState<SaldoEntryDialog> createState() => _SaldoEntryDialogState();
}

class _SaldoEntryDialogState extends ConsumerState<SaldoEntryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _sourceController = TextEditingController();
  final _amountController = TextEditingController();
  String? _selectedCategory;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    if (widget.depositToEdit != null) {
      _sourceController.text = widget.depositToEdit!.source;
      _amountController.text = widget.depositToEdit!.amount.toString();
      _selectedCategory = widget.depositToEdit!.category;
    }
  }

  @override
  void dispose() {
    _sourceController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isProcessing = true);

    try {
      final amount = int.parse(
        _amountController.text.replaceAll(RegExp(r'[^0-9]'), ''),
      );

      if (widget.depositToEdit != null) {
        final updated = widget.depositToEdit!.copyWith(
          source: _sourceController.text.trim(),
          amount: amount,
          category: _selectedCategory,
        );
        await ref.read(depositRepositoryProvider).updateDeposit(updated);
      } else {
        final deposit = DepositModel(
          id: const Uuid().v4(),
          source: _sourceController.text.trim(),
          amount: amount,
          category: _selectedCategory,
          createdAt: DateTime.now(),
        );
        await ref.read(depositRepositoryProvider).createDeposit(deposit);
      }

      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: const Color(0xFFF4F7FE),
      surfaceTintColor: Colors.white,
      title: Text(
        widget.depositToEdit == null ? 'Tambah Saldo' : 'Edit Saldo',
        style: const TextStyle(
          color: Color(0xFF1B2559),
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Kategori',
                  labelStyle: const TextStyle(color: Color(0xFFA3AED0)),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(
                    Icons.category_outlined,
                    color: Color(0xFFA3AED0),
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 'piutang', child: Text('Piutang')),
                  DropdownMenuItem(value: 'kredit', child: Text('Kredit')),
                ],
                onChanged: (val) => setState(() => _selectedCategory = val),
                validator: (val) => val == null ? 'Harap pilih kategori' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _sourceController,
                decoration: InputDecoration(
                  labelText: 'Keterangan Sumber',
                  labelStyle: const TextStyle(color: Color(0xFFA3AED0)),
                  hintText: 'Misal: Setoran Modal',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(
                    Icons.description_outlined,
                    color: Color(0xFFA3AED0),
                  ),
                ),
                validator: (value) => value == null || value.isEmpty
                    ? 'Harap isi keterangan'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: 'Besaran (Rp)',
                  labelStyle: const TextStyle(color: Color(0xFFA3AED0)),
                  prefixText: 'Rp ',
                  prefixStyle: const TextStyle(
                    color: Color(0xFF1B2559),
                    fontWeight: FontWeight.bold,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(
                    Icons.payments_outlined,
                    color: Color(0xFFA3AED0),
                  ),
                ),
                keyboardType: TextInputType.number,
                validator: (value) =>
                    value == null || value.isEmpty ? 'Harap isi jumlah' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isProcessing ? null : () => Navigator.pop(context),
          child: const Text(
            'Batal',
            style: TextStyle(color: Color(0xFFA3AED0)),
          ),
        ),
        ElevatedButton(
          onPressed: _isProcessing ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4318FF),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            elevation: 0,
          ),
          child: _isProcessing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text(
                  'Simpan',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
        ),
      ],
    );
  }
}
