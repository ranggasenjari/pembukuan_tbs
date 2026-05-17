import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../providers/providers.dart';
import '../../models/expense_model.dart';
import '../../models/margin_model.dart';
import '../../models/deposit_model.dart';

class ExpenseEntryScreen extends ConsumerStatefulWidget {
  const ExpenseEntryScreen({super.key});

  @override
  ConsumerState<ExpenseEntryScreen> createState() => _ExpenseEntryScreenState();
}

class _ExpenseEntryScreenState extends ConsumerState<ExpenseEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _recipientController = TextEditingController();
  final _amountController = TextEditingController();
  String _category = 'MITRA';
  DateTime _selectedDate = DateTime.now();

  List<MarginModel> _availableMargins = [];
  final Set<String> _selectedMarginIds = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMargins();
  }

  Future<void> _loadMargins() async {
    try {
      // For simplicity, we fetch recent margins.
      // Ideally we'd fetch "unshared" margins if we had that flag,
      // but here we just let user pick from all margins.
      final margins = await ref.read(marginRepositoryProvider).getMargins();
      setState(() {
        _availableMargins = margins;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      setState(() => _isLoading = false);
    }
  }

  double get _selectedProfit {
    double total = 0;
    for (var m in _availableMargins) {
      if (_selectedMarginIds.contains(m.id)) {
        total += m.marginAmount;
      }
    }
    return total;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedMarginIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih minimal satu data Profit (Margin)'),
        ),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount > _selectedProfit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Jumlah melebihi total profit yang dipilih!'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final expense = ExpenseModel(
        id: const Uuid().v4(),
        createdAt: DateTime.now(),
        expenseDate: _selectedDate,
        recipientName: _recipientController.text,
        category: _category,
        amount: amount,
      );

      await ref
          .read(expenseRepositoryProvider)
          .createExpense(
            expense: expense,
            marginIds: _selectedMarginIds.toList(),
          );

      if (_category == 'DEPOSIT (SALDO)') {
        final deposit = DepositModel(
          id: const Uuid().v4(),
          source: 'Deposit dari profit',
          amount: amount.toInt(),
          category: 'kredit',
          createdAt: DateTime.now(),
        );
        await ref.read(depositRepositoryProvider).createDeposit(deposit);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.indigo,
              onPrimary: Colors.white,
              onSurface: Color(0xFF1B2559),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      appBar: AppBar(
        title: const Text(
          'Tambah Pengeluaran',
          style: TextStyle(
            color: Color(0xFF1B2559),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1B2559)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Informasi Pengeluaran',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.indigo.shade800,
                                ),
                              ),
                              const Divider(height: 24),
                              TextFormField(
                                controller: _recipientController,
                                decoration: _inputDecoration(
                                  'Nama Penerima',
                                  Icons.person,
                                ),
                                validator: (v) => v == null || v.isEmpty
                                    ? 'Wajib diisi'
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<String>(
                                value: _category,
                                decoration: _inputDecoration(
                                  'Kategori',
                                  Icons.category,
                                ),
                                items:
                                    [
                                          'MITRA',
                                          'OPERASIONAL',
                                          'DEPOSIT (SALDO)',
                                          'LAINNYA',
                                        ]
                                        .map(
                                          (c) => DropdownMenuItem(
                                            value: c,
                                            child: Text(c),
                                          ),
                                        )
                                        .toList(),
                                onChanged: (v) =>
                                    setState(() => _category = v!),
                              ),
                              const SizedBox(height: 16),
                              InkWell(
                                onTap: _pickDate,
                                borderRadius: BorderRadius.circular(12),
                                child: InputDecorator(
                                  decoration: _inputDecoration(
                                    'Tanggal',
                                    Icons.calendar_today,
                                  ),
                                  child: Text(
                                    DateFormat(
                                      'dd MMMM yyyy',
                                    ).format(_selectedDate),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _amountController,
                                decoration: _inputDecoration(
                                  'Jumlah Rp',
                                  Icons.monetization_on,
                                  helper:
                                      'Maksimum sebesar profit yang dipilih',
                                ),
                                keyboardType: TextInputType.number,
                                validator: (v) => v == null || v.isEmpty
                                    ? 'Wajib diisi'
                                    : null,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Pilih Sumber Profit / Margin',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo.shade900,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.05),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.indigo.shade50,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(16),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Total Terpilih:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.indigo.shade900,
                                      ),
                                    ),
                                    Text(
                                      NumberFormat.currency(
                                        locale: 'id_ID',
                                        symbol: 'Rp ',
                                        decimalDigits: 0,
                                      ).format(_selectedProfit),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.indigo.shade700,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                padding: const EdgeInsets.all(8),
                                itemCount: _availableMargins.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final m = _availableMargins[index];
                                  final isSelected = _selectedMarginIds
                                      .contains(m.id);
                                  return CheckboxListTile(
                                    value: isSelected,
                                    activeColor: Colors.indigo,
                                    title: Text(
                                      'Profit: ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(m.marginAmount)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isSelected
                                            ? Colors.indigo
                                            : Colors.black87,
                                      ),
                                    ),
                                    subtitle: Text(
                                      DateFormat(
                                        'dd MMM yyyy',
                                      ).format(m.transactionDate),
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    onChanged: (val) {
                                      setState(() {
                                        if (val == true)
                                          _selectedMarginIds.add(m.id);
                                        else
                                          _selectedMarginIds.remove(m.id);
                                      });
                                    },
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 80), // Bottom padding
                      ],
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              blurRadius: 20,
              color: Colors.black.withOpacity(0.05),
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4318FF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text(
                    'SIMPAN PENGELUARAN',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
    String label,
    IconData icon, {
    String? helper,
  }) {
    return InputDecoration(
      labelText: label,
      helperText: helper,
      prefixIcon: Icon(icon, color: Colors.grey.shade400),
      floatingLabelBehavior: FloatingLabelBehavior.always,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.indigo, width: 2),
      ),
      filled: true,
      fillColor: Colors.grey.shade50,
    );
  }
}
