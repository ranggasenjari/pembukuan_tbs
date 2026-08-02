import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../core/widgets/zoomable_image_preview.dart';
import '../../models/nota_model.dart';
import '../../models/payment_model.dart';
import '../../providers/providers.dart';

class PaymentEntryScreen extends ConsumerStatefulWidget {
  final NotaModel nota;
  final PaymentModel? paymentToEdit;

  const PaymentEntryScreen({super.key, required this.nota, this.paymentToEdit});

  @override
  ConsumerState<PaymentEntryScreen> createState() => _PaymentEntryScreenState();
}

class _PaymentEntryScreenState extends ConsumerState<PaymentEntryScreen> {
  final _picker = ImagePicker();
  XFile? _proofFile;
  Uint8List? _proofBytes;
  bool _isProcessing = false;
  late TextEditingController _amountController;
  int _totalDeposits = 0;
  int _totalPayments = 0;
  bool _isLoadingBalance = true;

  @override
  void initState() {
    super.initState();
    final initialAmount =
        widget.paymentToEdit?.amountPaid ?? widget.nota.totalAmount;
    _amountController = TextEditingController(
      text: initialAmount.toInt().toString(),
    );
    _fetchBalanceInfo();
  }

  Future<void> _fetchBalanceInfo() async {
    try {
      final depositRepo = ref.read(depositRepositoryProvider);
      final paymentRepo = ref.read(paymentRepositoryProvider);

      final deposits = await depositRepo.getTotalDeposits();
      final payments = await paymentRepo.getTotalPayments();

      if (mounted) {
        setState(() {
          _totalDeposits = deposits;
          _totalPayments = payments;
          _isLoadingBalance = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingBalance = false);
        debugPrint('Error loading balance: $e');
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickProof() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _proofFile = picked;
        _proofBytes = bytes;
      });
    }
  }

  Future<void> _submitPayment() async {
    // For edit, proof is optional if already exists
    if (_proofBytes == null &&
        widget.paymentToEdit?.proofUrl == null &&
        widget.paymentToEdit == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harap upload bukti pembayaran')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final amount =
          int.tryParse(_amountController.text) ?? widget.nota.totalAmount;

      // Validation Check
      // Effective Available = (Total Deposits - Total Payments)
      // If Editing: We must add back the old amount of THIS payment to the available pool before checking.
      // Because Total Payments includes the old amount.

      int currentAvailable = _totalDeposits - _totalPayments;
      if (widget.paymentToEdit != null) {
        currentAvailable += widget.paymentToEdit!.amountPaid;
      }

      if (amount > currentAvailable) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Saldo Tidak Mencukupi'),
            content: Text(
              'Saldo tersedia: ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(currentAvailable)}\n'
              'Jumlah bayar: ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(amount)}\n\n'
              'Tetap simpan pembayaran?',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ya, Simpan')),
            ],
          ),
        );
        if (proceed != true) return;
      }

      if (widget.paymentToEdit != null) {
        // Update
        final updatedPayment = PaymentModel(
          id: widget.paymentToEdit!.id,
          notaId: widget.paymentToEdit!.notaId,
          paymentDate: widget
              .paymentToEdit!
              .paymentDate, // Keep original date or update? Keeping original
          amountPaid: amount.toInt(),
          createdAt: widget.paymentToEdit!.createdAt,
          proofUrl: widget
              .paymentToEdit!
              .proofUrl, // Will be handled if new file uploaded?
          marginId: widget.paymentToEdit!.marginId,
        );

        // We skip file upload logic for edit for simplicity as discussed
        await ref.read(paymentRepositoryProvider).updatePayment(updatedPayment);
      } else {
        // Create
        final payment = PaymentModel(
          id: const Uuid().v4(),
          notaId: widget.nota.id,
          paymentDate: DateTime.now(),
          amountPaid: amount.toInt(),
          createdAt: DateTime.now(),
        );

        await ref
            .read(paymentRepositoryProvider)
            .createPayment(payment, _proofBytes, _proofFile?.name);
      }

      if (mounted) {
        Navigator.pop(context); // Pop entry
        Navigator.pop(context); // Pop selection list (if pushed from there)
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.paymentToEdit != null;

    int currentAvailable = _totalDeposits - _totalPayments;
    if (isEdit) {
      currentAvailable += widget.paymentToEdit!.amountPaid;
    }

    final currencyFmt = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      appBar: AppBar(
        title: Text(
          isEdit ? 'Edit Pembayaran' : 'Entri Pembayaran Nota',
          style: const TextStyle(
            color: Color(0xFF1B2559),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1B2559)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Balance Info
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
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4318FF).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet,
                      color: Color(0xFF4318FF),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Saldo Tersedia',
                          style: TextStyle(
                            color: Color(0xFFA3AED0),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (_isLoadingBalance)
                          const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF4318FF),
                            ),
                          )
                        else
                          Text(
                            currencyFmt.format(currentAvailable),
                            style: const TextStyle(
                              color: Color(0xFF1B2559),
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Nota details
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
                children: [
                  _buildInfoRow('Nomor Nota', widget.nota.notaNumber),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1, color: Color(0xFFF4F7FE)),
                  ),
                  _buildInfoRow(
                    'Total Tagihan',
                    currencyFmt.format(widget.nota.totalAmount),
                    valueColor: const Color(0xFF4318FF),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'Form Pembayaran',
              style: TextStyle(
                color: Color(0xFF1B2559),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: 'Jumlah Bayar',
                labelStyle: const TextStyle(color: Color(0xFFA3AED0)),
                hintText: 'Masukkan jumlah pembayaran',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(
                    color: Color(0xFF4318FF),
                    width: 1,
                  ),
                ),
                prefixIcon: const Icon(Icons.money, color: Color(0xFFA3AED0)),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),

            if (_proofBytes != null || widget.paymentToEdit?.proofUrl != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bukti Pembayaran',
                    style: TextStyle(
                      color: Color(0xFF1B2559),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFF4F7FE)),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: _proofBytes != null
                          ? ZoomableImagePreview(imageBytes: _proofBytes!)
                          : ZoomableImagePreview(
                              imageUrl: widget.paymentToEdit!.proofUrl!,
                            ),
                    ),
                  ),
                ],
              )
            else
              Container(
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF4F7FE)),
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.image_outlined,
                      size: 48,
                      color: const Color(0xFFA3AED0).withOpacity(0.5),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Belum ada bukti pembayaran',
                      style: TextStyle(color: Color(0xFFA3AED0), fontSize: 13),
                    ),
                  ],
                ),
              ),

            if (!isEdit)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: OutlinedButton.icon(
                  onPressed: _pickProof,
                  icon: const Icon(Icons.add_a_photo_outlined, size: 20),
                  label: const Text('UNGGAH BUKTI TRANSFER'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF4318FF),
                    side: const BorderSide(color: Color(0xFF4318FF)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _isProcessing ? null : _submitPayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4318FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 0,
              ),
              child: _isProcessing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      isEdit ? 'UPDATE PEMBAYARAN' : 'SIMPAN PEMBAYARAN',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFFA3AED0), fontSize: 14),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: valueColor ?? const Color(0xFF1B2559),
          ),
        ),
      ],
    );
  }
}
