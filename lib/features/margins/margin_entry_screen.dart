import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/margin_model.dart';
import '../../models/payment_model.dart';
import '../../providers/providers.dart';

class MarginEntryScreen extends ConsumerStatefulWidget {
  final MarginModel? marginToEdit;

  const MarginEntryScreen({super.key, this.marginToEdit});

  @override
  ConsumerState<MarginEntryScreen> createState() => _MarginEntryScreenState();
}

class _MarginEntryScreenState extends ConsumerState<MarginEntryScreen> {
  List<Map<String, dynamic>> _payments = [];
  bool _isLoading = true;
  String? _errorMessage;

  final Set<String> _selectedPaymentIds = {};
  final Map<String, PaymentModel> _paymentMap = {};
  final TextEditingController _amountController = TextEditingController();
  DateTime _transactionDate = DateTime.now();
  final _formKey = GlobalKey<FormState>();
  bool _isSubstituting = false;

  @override
  void initState() {
    super.initState();
    if (widget.marginToEdit != null) {
      _transactionDate = widget.marginToEdit!.transactionDate;
      _amountController.text = NumberFormat.currency(
        locale: 'id_ID',
        symbol: '',
        decimalDigits: 0,
      ).format(widget.marginToEdit!.offtakerAmount).trim();
    }
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final items = await ref
          .read(paymentRepositoryProvider)
          .getUnassignedPayments(includeMarginId: widget.marginToEdit?.id);

      final Map<String, PaymentModel> tempMap = {};
      final Set<String> initialSelection = {};

      for (var item in items) {
        final p = PaymentModel.fromJson(item);
        tempMap[p.id] = p;

        // Pre-select if this payment belongs to the margin being edited
        if (widget.marginToEdit != null &&
            p.marginId == widget.marginToEdit!.id) {
          initialSelection.add(p.id);
        }
      }

      if (mounted) {
        setState(() {
          _payments = items;
          _paymentMap.addAll(tempMap);
          _selectedPaymentIds.addAll(initialSelection);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  int get _totalRealAmount {
    int total = 0;
    for (var id in _selectedPaymentIds) {
      if (_paymentMap.containsKey(id)) {
        total += _paymentMap[id]!.amountPaid;
      }
    }
    return total;
  }

  Future<void> _saveMargin() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPaymentIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih minimal satu pembayaran')),
      );
      return;
    }

    setState(() => _isSubstituting = true);

    try {
      final offtakerAmount = int.parse(
        _amountController.text.replaceAll('.', ''),
      );
      final selectedPayments = _selectedPaymentIds
          .map((id) => _paymentMap[id]!)
          .toList();

      if (widget.marginToEdit != null) {
        // Update existing
        final updatedMargin = MarginModel(
          id: widget.marginToEdit!.id,
          transactionDate: _transactionDate,
          offtakerAmount: offtakerAmount,
          realAmount: _totalRealAmount,
          marginAmount: offtakerAmount - _totalRealAmount,
          createdAt: widget.marginToEdit!.createdAt,
        );

        await ref
            .read(marginRepositoryProvider)
            .updateMargin(
              margin: updatedMargin,
              selectedPayments: selectedPayments,
            );
      } else {
        // Create new
        await ref
            .read(marginRepositoryProvider)
            .createMargin(
              transactionDate: _transactionDate,
              offtakerAmount: offtakerAmount,
              selectedPayments: selectedPayments,
            );
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubstituting = false);
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _transactionDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
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
    if (picked != null && picked != _transactionDate) {
      setState(() {
        _transactionDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.marginToEdit == null ? 'Input Margin' : 'Edit Margin';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(
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
          : _errorMessage != null
          ? Center(child: Text('Error: $_errorMessage'))
          : Column(
              children: [
                Expanded(
                  child: _payments.isEmpty
                      ? const Center(
                          child: Text('Tidak ada pembayaran yang tersedia.'),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          itemCount: _payments.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = _payments[index];
                            final paymentId = item['id'];
                            final notaNumber = item['notas'] != null
                                ? item['notas']['invoice_number']
                                : '-';
                            final amount = (item['amount_paid'] as num)
                                .toDouble();
                            final date = DateTime.parse(item['payment_date']);
                            final marginId = item['margin_id'];

                            final isSelected = _selectedPaymentIds.contains(
                              paymentId,
                            );

                            // Visual indicator if this payment was originally part of this margin
                            final bool isOriginal =
                                widget.marginToEdit != null &&
                                marginId == widget.marginToEdit!.id;

                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: isSelected
                                    ? Border.all(color: Colors.indigo, width: 2)
                                    : null,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.05),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: CheckboxListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                value: isSelected,
                                activeColor: Colors.indigo,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedPaymentIds.add(paymentId);
                                    } else {
                                      _selectedPaymentIds.remove(paymentId);
                                    }
                                  });
                                },
                                title: Text(
                                  notaNumber,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isOriginal
                                        ? Colors.green.shade700
                                        : const Color(0xFF1B2559),
                                  ),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    '${DateFormat('dd MMM').format(date)} • ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(amount)}',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                secondary: isOriginal
                                    ? const Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                      )
                                    : null,
                              ),
                            );
                          },
                        ),
                ),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(30),
                    ),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 20,
                        color: Colors.grey.withOpacity(0.1),
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        InkWell(
                          onTap: _selectDate,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade200),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today,
                                  color: Colors.indigo,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Tanggal Input',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                      Text(
                                        DateFormat(
                                          'dd MMMM yyyy',
                                        ).format(_transactionDate),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1B2559),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total Real (Pembayaran)',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1B2559),
                              ),
                            ),
                            Text(
                              NumberFormat.currency(
                                locale: 'id_ID',
                                symbol: 'Rp ',
                                decimalDigits: 0,
                              ).format(_totalRealAmount),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Color(0xFF1B2559),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _amountController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Jumlah Bayar Offtaker',
                            hintText: 'Masukkan jumlah',
                            floatingLabelBehavior: FloatingLabelBehavior.always,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.grey.shade200,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.grey.shade200,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Colors.indigo,
                                width: 2,
                              ),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty)
                              return 'Wajib diisi';
                            final amount = double.tryParse(
                              value.replaceAll('.', ''),
                            );
                            if (amount == null) return 'Format angka salah';
                            if (amount <= _totalRealAmount) {
                              return 'Harus lebih besar dari Total Real';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isSubstituting ? null : _saveMargin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4318FF),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: _isSubstituting
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                : Text(
                                    widget.marginToEdit == null
                                        ? 'Simpan Margin'
                                        : 'Update Margin',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
