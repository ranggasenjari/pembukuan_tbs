import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/enums.dart'; // Added import
import '../../models/nota_model.dart';
import '../../models/bon_model.dart';
import '../../models/factory_model.dart';
import '../../providers/providers.dart';
import 'nota_create_screen.dart';
import 'nota_detail_screen.dart';

class NotaListScreen extends ConsumerStatefulWidget {
  const NotaListScreen({super.key});

  @override
  ConsumerState<NotaListScreen> createState() => _NotaListScreenState();
}

class _NotaListScreenState extends ConsumerState<NotaListScreen> {
  late Future<List<NotaModel>> _notasFuture;
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
  final Set<String> _expandedNotaIds = {};
  final Map<String, Future<List<BonModel>>> _notaBonsFutures = {};

  @override
  void initState() {
    super.initState();
    _refreshNotas();
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

  void _refreshNotas() {
    setState(() {
      _notasFuture = ref
          .read(notaRepositoryProvider)
          .getNotas(
            startDate: _selectedDateRange?.start,
            endDate: _selectedDateRange?.end,
            factoryId: _selectedFactoryId,
          );
    });
  }

  Future<List<BonModel>> _notaBons(String notaId) {
    return _notaBonsFutures.putIfAbsent(
      notaId,
      () => ref.read(notaRepositoryProvider).getNotaBons(notaId),
    );
  }

  Future<bool> _matchesSearchQuery(NotaModel nota, String query) async {
    if (query.isEmpty) return true;

    final lowerQuery = query.toLowerCase();

    // Check recipient name
    final relName = nota.relationAgentName ?? nota.recipientName;
    if (relName?.toLowerCase().contains(lowerQuery) ?? false) {
      return true;
    }

    // Check driver names from associated bons
    try {
      final bons = await ref.read(notaRepositoryProvider).getNotaBons(nota.id);
      for (var bon in bons) {
        if (bon.driverName?.toLowerCase().contains(lowerQuery) ?? false) {
          return true;
        }
      }
    } catch (_) {}

    return false;
  }

  Future<List<NotaModel>> _filterNotas(
    List<NotaModel> notas,
    String query,
  ) async {
    if (query.isEmpty) return notas;

    final filtered = <NotaModel>[];
    for (var nota in notas) {
      if (await _matchesSearchQuery(nota, query)) {
        filtered.add(nota);
      }
    }
    return filtered;
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
      _refreshNotas();
    }
  }

  Widget _buildNotaStatsCard(int total, int tertagih, int lunas, double amount) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
      child: Row(
        children: [
          _statItem(Icons.description_outlined, '$total', 'Total', Colors.indigo),
          _statDivider(),
          _statItem(Icons.hourglass_bottom, '$tertagih', 'Tertagih', Colors.orange),
          _statDivider(),
          _statItem(Icons.check_circle_outline, '$lunas', 'Lunas', Colors.green),
          _statDivider(),
          _statItem(Icons.attach_money, NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(amount), 'Nilai', Colors.teal),
        ],
      ),
    );
  }

  Widget _statItem(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _statDivider() {
    return Container(width: 1, height: 32, color: Colors.grey.shade200);
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
        _refreshNotas();
      },
    );
  }

  Widget _buildSearchHeader() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Cari Supir atau Relasi/Agen...',
          border: InputBorder.none,
          icon: const Icon(Icons.search, color: Colors.grey),
          suffixIcon: _driverQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _driverQuery = '');
                    _refreshNotas();
                  },
                )
              : null,
        ),
        onChanged: (value) {
          setState(() => _driverQuery = value);
          _refreshNotas();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      appBar: AppBar(
        title: const Text(
          'Daftar Nota Penjualan',
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
                  _refreshNotas();
                },
                tooltip: 'Reset Filter',
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSearchHeader(),
                const SizedBox(height: 8),
                _buildFactoryFilter(),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                _refreshNotas();
                await _notasFuture;
              },
              child: FutureBuilder<List<NotaModel>>(
                future: _notasFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  var notas = snapshot.data ?? [];
                  // Sort by createdAt descending (newest first)
                  notas.sort((a, b) => b.createdAt.compareTo(a.createdAt));

                  // Filter by search query
                  return FutureBuilder<List<NotaModel>>(
                    future: _filterNotas(notas, _driverQuery),
                    builder: (context, filteredSnapshot) {
                      if (filteredSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      var filteredNotas = filteredSnapshot.data ?? [];
                      if (filteredNotas.isEmpty) {
                        return SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(height: 100),
                              Icon(
                                Icons.receipt_long_outlined,
                                size: 80,
                                color: Colors.indigo.withOpacity(0.2),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                "Belum ada data nota",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      final totalAmount = filteredNotas.fold<double>(
                        0, (sum, n) => sum + n.totalAmount,
                      );
                      final tertagihCount = filteredNotas.where(
                        (n) => n.status == PaymentStatus.tertagih,
                      ).length;
                      final lunasCount = filteredNotas.where(
                        (n) => n.status == PaymentStatus.lunas,
                      ).length;

                      return Column(
                        children: [
                          _buildNotaStatsCard(
                            filteredNotas.length,
                            tertagihCount,
                            lunasCount,
                            totalAmount,
                          ),
                          Expanded(
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                              separatorBuilder: (c, i) => const SizedBox(height: 12),
                              itemCount: filteredNotas.length,
                              itemBuilder: (context, index) {
                                final nota = filteredNotas[index];
                                return _buildNotaCard(nota);
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF4318FF),
        icon: const Icon(Icons.add),
        label: const Text('Buat Nota Baru'),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotaCreateScreen()),
          ).then((_) => _refreshNotas());
        },
      ),
    );
  }

  Widget _buildNotaCard(NotaModel nota) {
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
              MaterialPageRoute(builder: (_) => NotaDetailScreen(nota: nota)),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 4, 16, 0),
                child: Text(
                  'Waktu input: ${DateFormat('dd/MM/yyyy HH:mm:ss').format(nota.createdAt)}',
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nota.notaNumber,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Color(0xFF1B2559),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              (nota.relationAgentName ?? nota.recipientName ?? '-').toUpperCase(),
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today,
                                  size: 12,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  DateFormat(
                                    'dd MMM yyyy',
                                  ).format(nota.notaDate),
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            _buildStatusPill(nota.status),
                            const SizedBox(width: 4),
                            PopupMenuButton<String>(
                              icon: const Icon(
                                Icons.more_vert,
                                color: Color(0xFFA3AED0),
                                size: 20,
                              ),
                              onSelected: (value) async {
                                if (value == 'edit') {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          NotaCreateScreen(notaToEdit: nota),
                                    ),
                                  );
                                  _refreshNotas();
                                } else if (value == 'delete') {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      title: const Text('Hapus Nota'),
                                      content: const Text(
                                        'Yakin ingin menghapus nota ini? Status bon akan dikembalikan menjadi Belum Dibuat Nota.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text(
                                            'Batal',
                                            style: TextStyle(
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
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
                                          .read(notaRepositoryProvider)
                                          .deleteNota(nota.id);
                                      _refreshNotas();
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(content: Text('Error: $e')),
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
                      ],
                    ),
                    const Divider(height: 24, thickness: 1),
                    GestureDetector(
                      onTap: () => setState(() {
                        if (!_expandedNotaIds.remove(nota.id)) {
                          _expandedNotaIds.add(nota.id);
                        }
                      }),
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.receipt,
                                      color: Colors.blue,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  FutureBuilder<List<BonModel>>(
                                    future: _notaBons(nota.id),
                                    builder: (context, snapshot) {
                                      final bons = snapshot.data ?? [];
                                      final isExpanded =
                                          _expandedNotaIds.contains(nota.id);
                                      if (snapshot.connectionState ==
                                          ConnectionState.waiting) {
                                        return Text(
                                          '${nota.itemCount} Bon',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        );
                                      }
                                      if (bons.isEmpty) {
                                        return Text(
                                          '${nota.itemCount} Bon',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        );
                                      }
                                      final plates = bons
                                          .map((b) => b.plateNumber)
                                          .toList();
                                      final shown = isExpanded
                                          ? plates
                                          : plates.take(2).toList();
                                      final extra = plates.length - shown.length;
                                      return Text(
                                        '${plates.length} Bon · ${shown.join(', ')}${extra > 0 ? ' +$extra' : ''}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                          fontSize: 13,
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    _expandedNotaIds.contains(nota.id)
                                        ? Icons.expand_less
                                        : Icons.expand_more,
                                    size: 18,
                                    color: Colors.grey,
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text(
                                    'Total Tagihan',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  Text(
                                    NumberFormat.currency(
                                      locale: 'id_ID',
                                      symbol: 'Rp ',
                                      decimalDigits: 0,
                                    ).format(nota.totalAmount),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Color(0xFF4318FF),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (_expandedNotaIds.contains(nota.id))
                            FutureBuilder<List<BonModel>>(
                              future: _notaBons(nota.id),
                              builder: (context, snapshot) {
                                final bons = snapshot.data ?? [];
                                if (bons.isEmpty) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Column(
                                    children: [
                                      for (final bon in bons)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 6,
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    bon.plateNumber,
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 12,
                                                      color: Colors.indigo
                                                          .shade700,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    bon.driverName ?? '-',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.grey.shade700,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Text(
                                                NumberFormat.currency(
                                                  locale: 'id_ID',
                                                  symbol: 'Rp ',
                                                  decimalDigits: 0,
                                                ).format(bon.total),
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
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

  Widget _buildStatusPill(PaymentStatus status) {
    Color bgColor;
    Color textColor;

    switch (status) {
      case PaymentStatus.lunas:
        bgColor = Colors.green.shade100;
        textColor = Colors.green.shade800;
        break;
      case PaymentStatus.tertagih:
        bgColor = Colors.orange.shade100;
        textColor = Colors.orange.shade800;
        break;
      default:
        bgColor = Colors.red.shade100;
        textColor = Colors.red.shade800;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.notaLabel.toUpperCase(),
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }
}
