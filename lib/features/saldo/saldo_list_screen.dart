import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/deposit_model.dart';
import '../../providers/providers.dart';
import 'saldo_entry_dialog.dart';

class SaldoListScreen extends ConsumerStatefulWidget {
  const SaldoListScreen({super.key});

  @override
  ConsumerState<SaldoListScreen> createState() => _SaldoListScreenState();
}

class _SaldoListScreenState extends ConsumerState<SaldoListScreen> {
  bool _isLoading = true;
  List<DepositModel> _deposits = [];

  DateTimeRange? _dateRange;
  String? _selectedCategoryFilter;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final depositRepo = ref.read(depositRepositoryProvider);

      final deposits = await depositRepo.getDeposits(
        startDate: _dateRange?.start,
        endDate: _dateRange?.end,
        category: _selectedCategoryFilter,
      );

      if (mounted) {
        setState(() {
          _deposits = deposits;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
      }
    }
  }

  // Future that returns global available
  Future<int> _fetchGlobalAvailable() async {
    final depositRepo = ref.read(depositRepositoryProvider);
    final paymentRepo = ref.read(paymentRepositoryProvider);
    final d = await depositRepo.getTotalDeposits();
    final p = await paymentRepo.getTotalPayments();
    return d - p;
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      appBar: AppBar(
        title: const Text(
          'Manajemen Saldo',
          style: TextStyle(
            color: Color(0xFF1B2559),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1B2559)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await showDialog(
            context: context,
            builder: (_) => const SaldoEntryDialog(),
          );
          if (result == true) {
            _loadData();
          }
        },
        label: const Text(
          'Tambah Saldo',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        icon: const Icon(Icons.add),
        backgroundColor: const Color(
          0xFF05CD99,
        ), // Green for adding balance/deposit
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        color: const Color(0xFF4318FF),
        onRefresh: _loadData,
        child: Column(
          children: [
            // FILTERS
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextButton.icon(
                        icon: const Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: Color(0xFF4318FF),
                        ),
                        label: Text(
                          _dateRange == null
                              ? 'Semua Tanggal'
                              : '${DateFormat('dd/MM').format(_dateRange!.start)} - ${DateFormat('dd/MM').format(_dateRange!.end)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF1B2559),
                          ),
                        ),
                        onPressed: () async {
                          final picked = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                            initialDateRange: _dateRange,
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: const ColorScheme.light(
                                    primary: Color(0xFF4318FF),
                                    onPrimary: Colors.white,
                                    onSurface: Color(0xFF1B2559),
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null) {
                            setState(() => _dateRange = picked);
                            _loadData();
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          icon: const Icon(
                            Icons.keyboard_arrow_down,
                            color: Color(0xFFA3AED0),
                          ),
                          hint: const Text(
                            'Kategori',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFFA3AED0),
                            ),
                          ),
                          value: _selectedCategoryFilter,
                          items: const [
                            DropdownMenuItem(
                              value: null,
                              child: Text(
                                'Semua',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'piutang',
                              child: Text(
                                'Piutang',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'kredit',
                              child: Text(
                                'Kredit',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            setState(() => _selectedCategoryFilter = val);
                            _loadData();
                          },
                        ),
                      ),
                    ),
                  ),
                  if (_dateRange != null || _selectedCategoryFilter != null)
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Color(0xFFA3AED0)),
                      onPressed: () {
                        setState(() {
                          _dateRange = null;
                          _selectedCategoryFilter = null;
                        });
                        _loadData();
                      },
                    ),
                ],
              ),
            ),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      children: [
                        FutureBuilder<int>(
                          future: _fetchGlobalAvailable(),
                          builder: (context, snapshot) {
                            return _buildSummaryCard(
                              'Total Saldo Tersedia',
                              snapshot.data ?? 0,
                              const [Color(0xFF4318FF), Color(0xFF5E36FF)],
                              currencyFormat,
                              isMain: true,
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildSummaryCard(
                          'Total Deposit Filter',
                          _deposits.fold(0, (sum, item) => sum + item.amount),
                          const [Color(0xFF05CD99), Color(0xFF00BFA5)],
                          currencyFormat,
                        ),

                        const SizedBox(height: 24),
                        const Text(
                          'Riwayat Deposit',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1B2559),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_deposits.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(48.0),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.history_outlined,
                                    size: 64,
                                    color: Colors.grey.shade300,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Belum ada data deposit.',
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ..._deposits.map((deposit) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
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
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 4,
                                ),
                                leading: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF05CD99,
                                    ).withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.arrow_downward,
                                    color: Color(0xFF05CD99),
                                    size: 20,
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        deposit.source,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1B2559),
                                        ),
                                      ),
                                    ),
                                    if (deposit.category != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: deposit.category == 'piutang'
                                              ? Colors.orange.withOpacity(0.1)
                                              : Colors.blue.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          deposit.category!.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: deposit.category == 'piutang'
                                                ? Colors.orange.shade800
                                                : Colors.blue.shade800,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                subtitle: Text(
                                  DateFormat(
                                    'dd MMM yyyy, HH:mm',
                                  ).format(deposit.createdAt),
                                  style: const TextStyle(
                                    color: Color(0xFFA3AED0),
                                    fontSize: 12,
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      currencyFormat.format(deposit.amount),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: Color(0xFF1B2559),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    PopupMenuButton<String>(
                                      icon: const Icon(
                                        Icons.more_vert,
                                        color: Color(0xFFA3AED0),
                                        size: 20,
                                      ),
                                      onSelected: (value) async {
                                        if (value == 'edit') {
                                          final result = await showDialog(
                                            context: context,
                                            builder: (_) => SaldoEntryDialog(
                                              depositToEdit: deposit,
                                            ),
                                          );
                                          if (result == true) _loadData();
                                        } else if (value == 'delete') {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                              title: const Text('Hapus Saldo'),
                                              content: const Text(
                                                'Yakin ingin menghapus data saldo ini?',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                        context,
                                                        false,
                                                      ),
                                                  child: const Text(
                                                    'Batal',
                                                    style: TextStyle(
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                                ),
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                        context,
                                                        true,
                                                      ),
                                                  child: const Text(
                                                    'Hapus',
                                                    style: TextStyle(
                                                      color: Colors.red,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );

                                          if (confirm == true) {
                                            try {
                                              await ref
                                                  .read(
                                                    depositRepositoryProvider,
                                                  )
                                                  .deleteDeposit(deposit.id);
                                              _loadData();
                                            } catch (e) {
                                              if (mounted) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text('Error: $e'),
                                                  ),
                                                );
                                              }
                                            }
                                          }
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(
                                          value: 'edit',
                                          child: Text('Edit'),
                                        ),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Text(
                                            'Delete',
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        const SizedBox(height: 80), // Space for FAB
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    int value,
    List<Color> gradientColors,
    NumberFormat fmt, {
    bool isMain = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: isMain ? 14 : 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            fmt.format(value),
            style: TextStyle(
              color: Colors.white,
              fontSize: isMain ? 26 : 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
