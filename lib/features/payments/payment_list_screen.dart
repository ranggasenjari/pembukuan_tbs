import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/enums.dart';
import '../../models/nota_model.dart';
import '../../models/payment_model.dart';
import '../../models/factory_model.dart';
import '../../providers/providers.dart';
import '../../core/widgets/zoomable_image_preview.dart';
import 'payment_entry_screen.dart';
import 'payment_nota_select_screen.dart';

class PaymentListScreen extends ConsumerStatefulWidget {
  const PaymentListScreen({super.key});

  @override
  ConsumerState<PaymentListScreen> createState() => _PaymentListScreenState();
}

class _PaymentListScreenState extends ConsumerState<PaymentListScreen> {
  late Future<List<Map<String, dynamic>>> _paymentsFuture;
  DateTimeRange? _selectedDateRange = DateTimeRange(
    start: DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    ),
    end: DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    ),
  );
  final TextEditingController _searchController = TextEditingController();
  String _driverQuery = '';
  List<FactoryModel> _factories = [];
  String? _selectedFactoryId;

  @override
  void initState() {
    super.initState();
    _refreshPayments();
    _loadFactories();
  }

  Future<void> _loadFactories() async {
    final factories = await ref.read(factoryRepositoryProvider).getFactories();
    if (mounted) setState(() => _factories = factories);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refreshPayments() {
    setState(() {
      _paymentsFuture = ref
          .read(paymentRepositoryProvider)
          .getAllPayments(
            startDate: _selectedDateRange?.start,
            endDate: _selectedDateRange?.end,
            driverQuery: _driverQuery,
            factoryId: _selectedFactoryId,
          );
    });
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
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
      setState(() {
        _selectedDateRange = picked;
      });
      _refreshPayments();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      appBar: AppBar(
        title: const Text(
          'Riwayat Pembayaran',
          style: TextStyle(
            color: Color(0xFF1B2559),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1B2559)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: IconButton(
              icon: Icon(
                Icons.calendar_month,
                color: _selectedDateRange != null ? Colors.indigo : Colors.grey,
              ),
              onPressed: _pickDateRange,
              tooltip: 'Filter Tanggal',
            ),
          ),
          if (_selectedDateRange != null)
            Container(
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: const Icon(Icons.cleaning_services, color: Colors.red),
                onPressed: () {
                  setState(() {
                    _selectedDateRange = null;
                  });
                  _refreshPayments();
                },
                tooltip: 'Reset Filter',
              ),
            ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _paymentsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final payments = snapshot.data ?? [];

          final totalPaid = payments.fold(
            0,
            (sum, item) => sum + (item['amount_paid'] as num).toInt(),
          );

          return Column(
            children: [
              _buildSummaryCard(totalPaid, payments.length),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cari Nama Supir',
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Color(0xFFA3AED0),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
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
                    suffixIcon: _driverQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _driverQuery = '';
                              });
                              _refreshPayments();
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _driverQuery = value;
                    });
                    _refreshPayments();
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: _buildFactoryFilter(),
              ),
              Expanded(
                child: RefreshIndicator(
                  color: const Color(0xFF4318FF),
                  onRefresh: () async {
                    _refreshPayments();
                    await _paymentsFuture;
                  },
                  child: payments.isEmpty
                      ? ListView(
                          children: [
                            const SizedBox(height: 60),
                            Center(
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.payment_outlined,
                                    size: 64,
                                    color: Colors.grey.shade300,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Belum ada riwayat pembayaran.',
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(20),
                          itemCount: payments.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final data = payments[index];
                            final notaData = data['notas'];
                            final invoiceNumber =
                                (notaData != null && notaData is Map)
                                ? notaData['invoice_number'] ??
                                      'Nota #${data['nota_id']}'
                                : 'Nota #${data['nota_id']}';

                            final amount = (data['amount_paid'] as num).toInt();
                            final date = DateTime.parse(data['payment_date']);
                            final proofUrl = data['proof_url'];

                            return _buildPaymentCard(
                              data: data,
                              invoiceNumber: invoiceNumber,
                              amount: amount,
                              date: date,
                              proofUrl: proofUrl,
                              notaData: notaData,
                            );
                          },
                        ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PaymentNotaSelectScreen()),
          ).then((_) => _refreshPayments());
        },
        backgroundColor: const Color(0xFF4318FF),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Input Pembayaran',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildFactoryFilter() {
    return DropdownButtonFormField<String>(
      value: _selectedFactoryId,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Filter Pabrik',
        prefixIcon: Icon(Icons.factory_outlined, color: Colors.indigo.shade300),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      items: [
        const DropdownMenuItem<String>(
          value: null,
          child: Text('Semua Pabrik'),
        ),
        ..._factories.map(
          (f) => DropdownMenuItem<String>(
            value: f.id,
            child: Text(f.name, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
      onChanged: (value) {
        setState(() => _selectedFactoryId = value);
        _refreshPayments();
      },
    );
  }

  Widget _buildSummaryCard(int total, int count) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4318FF), Color(0xFF5E36FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4318FF).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Total Dibayarkan',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Text(
                NumberFormat.currency(
                  locale: 'id_ID',
                  symbol: 'Rp ',
                  decimalDigits: 0,
                ).format(total),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                const Text(
                  'Transaksi',
                  style: TextStyle(color: Colors.white70, fontSize: 10),
                ),
                Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard({
    required Map<String, dynamic> data,
    required String invoiceNumber,
    required int amount,
    required DateTime date,
    String? proofUrl,
    dynamic notaData,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF4318FF).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.payment,
                color: Color(0xFF4318FF),
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    invoiceNumber,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B2559),
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('dd MMM yyyy').format(date),
                    style: const TextStyle(
                      color: Color(0xFFA3AED0),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    NumberFormat.currency(
                      locale: 'id_ID',
                      symbol: 'Rp ',
                      decimalDigits: 0,
                    ).format(amount),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            if (proofUrl != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ZoomableImagePreview(
                  imageUrl: proofUrl,
                  height: 40,
                  width: 40,
                ),
              ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Color(0xFFA3AED0)),
              onSelected: (value) async {
                final marginId = data['margin_id'];
                if (marginId != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Pembayaran ini sudah tercatat dalam margin, tidak dapat diedit atau dihapus.',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                if (value == 'edit') {
                  final nota = NotaModel(
                    id: notaData['id'],
                    notaNumber: notaData['nota_number'],
                    notaDate: DateTime.now(),
                    totalAmount: (notaData['total_amount'] as num).toDouble(),
                    status: PaymentStatus.belumDibayar,
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  );

                  final payment = PaymentModel(
                    id: data['id'],
                    notaId: data['nota_id'],
                    paymentDate: DateTime.parse(data['payment_date']),
                    amountPaid: amount,
                    createdAt: DateTime.parse(data['created_at']),
                    proofUrl: proofUrl,
                    marginId: marginId,
                  );

                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PaymentEntryScreen(
                        nota: nota,
                        paymentToEdit: payment,
                      ),
                    ),
                  );
                  _refreshPayments();
                } else if (value == 'delete') {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      title: const Text('Hapus Pembayaran'),
                      content: const Text(
                        'Yakin ingin menghapus pembayaran ini? Status Nota mungkin akan berubah.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text(
                            'Batal',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text(
                            'Hapus',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    try {
                      await ref
                          .read(paymentRepositoryProvider)
                          .deletePayment(data['id']);
                      _refreshPayments();
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    }
                  }
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
