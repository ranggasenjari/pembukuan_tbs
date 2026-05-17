import 'package:pembukuan/core/enums.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../models/bon_model.dart';
import '../../models/nota_model.dart';
import '../../providers/providers.dart';
import 'bon_entry_screen.dart';
import '../notas/nota_detail_screen.dart';

// Formatter agar input selalu huruf besar
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

class BonListScreen extends ConsumerStatefulWidget {
  const BonListScreen({super.key});

  @override
  ConsumerState<BonListScreen> createState() => _BonListScreenState();
}

class _BonListScreenState extends ConsumerState<BonListScreen> {
  late Future<List<BonModel>> _bonsFuture;
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

  @override
  void initState() {
    super.initState();
    _refreshBons();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refreshBons() {
    setState(() {
      _bonsFuture = ref
          .read(bonRepositoryProvider)
          .getBons(
            startDate: _selectedDateRange?.start,
            endDate: _selectedDateRange?.end,
            driverQuery: _driverQuery,
          );
    });
  }

  Future<NotaModel?> _getNotaForBon(String bonId) async {
    try {
      final notas = await ref.read(notaRepositoryProvider).getNotas();
      for (var nota in notas) {
        final bons = await ref
            .read(notaRepositoryProvider)
            .getNotaBons(nota.id);
        if (bons.any((b) => b.id == bonId)) {
          return nota;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  void _showCreateNotaSatuanModal(BonModel bon) {
    final recipientNameController = TextEditingController();
    final addressController = TextEditingController();
    final screenContext = context; // Save the screen context

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cetak Nota Satuan?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: recipientNameController,
                inputFormatters: [UpperCaseTextFormatter()],
                decoration: InputDecoration(
                  labelText: 'Nama Penerima',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  hintText: 'Contoh: PT. SUPPLY TANI JAYA',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: addressController,
                inputFormatters: [UpperCaseTextFormatter()],
                decoration: InputDecoration(
                  labelText: 'Alamat',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  hintText: 'Contoh: LANGKAT, SUMATERA UTARA',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4318FF),
            ),
            onPressed: () async {
              if (recipientNameController.text.isEmpty) {
                if (mounted) {
                  ScaffoldMessenger.of(screenContext).showSnackBar(
                    const SnackBar(content: Text('Nama penerima wajib diisi')),
                  );
                }
                return;
              }

              Navigator.pop(dialogContext);

              try {
                final nota = NotaModel(
                  id: const Uuid().v4(),
                  notaNumber: 'NOTA-${DateTime.now().millisecondsSinceEpoch}',
                  notaDate: DateTime.now(),
                  totalAmount: bon.total,
                  status: PaymentStatus.tertagih,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                  recipientName: recipientNameController.text.trim(),
                  recipientAddress: addressController.text.trim(),
                );

                await ref.read(notaRepositoryProvider).createNota(nota, [
                  bon.id,
                ]);

                if (mounted) {
                  Navigator.push(
                    screenContext,
                    MaterialPageRoute(
                      builder: (_) =>
                          NotaDetailScreen(nota: nota, initialBons: [bon]),
                    ),
                  ).then((_) => _refreshBons());
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    screenContext,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Ya, Cetak'),
          ),
        ],
      ),
    );
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
      _refreshBons();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      appBar: AppBar(
        title: const Text(
          'Daftar Slip Timbangan',
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
                  _refreshBons();
                },
                tooltip: 'Reset Filter',
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchHeader(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                _refreshBons();
                await _bonsFuture;
              },
              child: FutureBuilder<List<BonModel>>(
                future: _bonsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  final bons = snapshot.data ?? [];
                  if (bons.isEmpty) {
                    return _buildEmptyState();
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: bons.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final bon = bons[index];
                      return _buildModernBonCard(bon);
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BonEntryScreen()),
          ).then((_) => _refreshBons());
        },
        backgroundColor: Colors.amber,
        icon: const Icon(Icons.add),
        label: const Text('Input Bon Baru'),
      ),
    );
  }

  Widget _buildSearchHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Cari Supir, Plat, atau Relasi...',
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          prefixIcon: Icon(Icons.search, color: Colors.indigo.shade300),
          suffixIcon: _driverQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _driverQuery = '');
                    _refreshBons();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
        onChanged: (value) {
          setState(() => _driverQuery = value);
          _refreshBons();
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: Colors.indigo.shade200,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Belum ada data bon',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Silakan input bon baru untuk memulai',
            style: TextStyle(color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  Widget _buildModernBonCard(BonModel bon) {
    final currencyFmt = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final dateFmt = DateFormat('dd MMM yyyy');

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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => BonEntryScreen(bon: bon)),
            ).then((_) => _refreshBons());
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 4, 16, 0),
                child: Text(
                  'Waktu input: ${DateFormat('dd/MM/yyyy HH:mm:ss').format(bon.createdAt)}',
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.grey.shade500,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.indigo.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            bon.plateNumber,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo.shade700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(bon.status).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _getStatusColor(
                                bon.status,
                              ).withOpacity(0.2),
                            ),
                          ),
                          child: Text(
                            bon.status.label.toUpperCase(),
                            style: TextStyle(
                              color: _getStatusColor(bon.status),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildMetaData(
                                Icons.person_outline,
                                bon.driverName ?? '-',
                              ),
                              const SizedBox(height: 3),
                              _buildMetaData(
                                Icons.business,
                                bon.relationName ?? '-',
                              ),
                              const SizedBox(height: 3),
                              _buildMetaData(
                                Icons.calendar_today,
                                dateFmt.format(bon.bonDate),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  if (bon.status == PaymentStatus.belumDibayar)
                                    OutlinedButton.icon(
                                      onPressed: () =>
                                          _showCreateNotaSatuanModal(bon),
                                      icon: const Icon(
                                        Icons.receipt_long,
                                        size: 14,
                                      ),
                                      label: const Text('Cetak Nota'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.indigo,
                                        side: const BorderSide(
                                          color: Colors.indigo,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                    )
                                  else if (bon.status == PaymentStatus.tertagih)
                                    FutureBuilder<NotaModel?>(
                                      future: _getNotaForBon(bon.id),
                                      builder: (context, snapshot) {
                                        final nota = snapshot.data;
                                        return OutlinedButton.icon(
                                          onPressed: nota != null
                                              ? () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          NotaDetailScreen(
                                                            nota: nota,
                                                          ),
                                                    ),
                                                  );
                                                }
                                              : null,
                                          icon: const Icon(
                                            Icons.description,
                                            size: 14,
                                          ),
                                          label: const Text('Lihat Nota'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.green,
                                            side: const BorderSide(
                                              color: Colors.green,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Berat Bersih',
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 10,
                              ),
                            ),
                            Text(
                              '${bon.netto2.toInt()} kg',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Harga/Kg',
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 10,
                              ),
                            ),
                            Text(
                              currencyFmt.format(bon.price),
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                                color: Colors.indigo,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Total Harga',
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 10,
                              ),
                            ),
                            Text(
                              currencyFmt.format(bon.total),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Color(0xFF1B2559),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetaData(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade400),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.lunas:
        return Colors.green;
      case PaymentStatus.tertagih:
        return Colors.orange;
      case PaymentStatus.belumDibayar:
        return Colors.red;
    }
  }
}
