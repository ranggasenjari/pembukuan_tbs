import 'package:pembukuan/core/enums.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/bon_model.dart';
import '../../models/nota_model.dart';
import '../../models/factory_model.dart';
import '../../models/relation_agent_model.dart';
import '../../providers/providers.dart';
import '../../services/nota_whatsapp_service.dart';
import '../../core/widgets/zoomable_image_preview.dart';
import 'bon_entry_screen.dart';
import '../notas/nota_detail_screen.dart';

class _InlineEditState {
  final TextEditingController netto1Ctrl;
  final TextEditingController netto2Ctrl;
  final TextEditingController priceCtrl;
  String? spsiTypeId;
  bool pphEnabled;
  final TextEditingController uangMinumCtrl;
  final TextEditingController bpColtCtrl;
  bool dirty;

  _InlineEditState(BonModel bon)
    : netto1Ctrl = TextEditingController(text: bon.netto1.toInt().toString()),
      netto2Ctrl = TextEditingController(text: bon.netto2.toInt().toString()),
      priceCtrl = TextEditingController(text: bon.price.toInt().toString()),
      spsiTypeId = bon.factorySpsiTypeId,
      pphEnabled = bon.pph > 0,
      uangMinumCtrl = TextEditingController(
        text: bon.uangMinum.toInt().toString(),
      ),
      bpColtCtrl = TextEditingController(text: bon.bpColt.toInt().toString()),
      dirty = false;
}

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
  List<FactoryModel> _factories = [];
  String? _selectedFactoryId;
  final Map<String, _InlineEditState> _editStates = {};
  final Set<String> _savingBonIds = {};
  final Set<String> _expandedCardIds = {};
  bool _selectMode = false;
  final Set<String> _selectedBonIds = {};
  final Map<String, Future<NotaModel?>> _notaFutures = {};

  @override
  void initState() {
    super.initState();
    _refreshBons();
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

  void _refreshBons() {
    setState(() {
      _bonsFuture = ref
          .read(bonRepositoryProvider)
          .getBons(
            startDate: _selectedDateRange?.start,
            endDate: _selectedDateRange?.end,
            driverQuery: _driverQuery,
            factoryId: _selectedFactoryId,
          );
    });
  }

  Future<NotaModel?> _getNotaForBon(String bonId) {
    return _notaFutures.putIfAbsent(bonId, () => _loadNotaForBon(bonId));
  }

  Future<NotaModel?> _loadNotaForBon(String bonId) async {
    try {
      final notaId = await ref
          .read(notaRepositoryProvider)
          .getNotaIdByBonId(bonId);
      if (notaId == null) return null;
      return await ref.read(notaRepositoryProvider).getNotaById(notaId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _openNotaForBon(String bonId, NotaModel? nota) async {
    final resolved = nota ?? await _getNotaForBon(bonId);
    if (!mounted) return;
    if (resolved == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nota terkait tidak ditemukan')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NotaDetailScreen(nota: resolved)),
    );
  }

  Future<void> _shareNotaForBon(String bonId, NotaModel? nota) async {
    final resolved = nota ?? await _getNotaForBon(bonId);
    if (!mounted) return;
    if (resolved == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nota terkait tidak ditemukan')),
      );
      return;
    }
    _shareNotaWhatsappAsync(resolved);
  }

  void _createNotaSatuan(BonModel bon) async {
    if ((bon.relationName ?? '').trim().isEmpty) {
      _showCreateNotaSatuanModal(bon);
      return;
    }
    try {
      final nota = NotaModel(
        id: const Uuid().v4(),
        notaNumber: 'NOTA-${DateTime.now().millisecondsSinceEpoch}',
        notaDate: DateTime.now(),
        totalAmount: bon.total,
        status: PaymentStatus.tertagih,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        recipientName: bon.relationName!,
        recipientAddress: bon.fruitOrigin ?? '',
      );

      await ref.read(notaRepositoryProvider).createNota(nota, [bon.id]);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nota berhasil dibuat'),
            duration: Duration(seconds: 2),
          ),
        );
        _refreshBons();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showCreateNotaSatuanModal(BonModel bon) async {
    final repo = ref.read(relationAgentRepositoryProvider);
    final agents = await repo.getRelationAgents();
    if (!mounted) return;

    String? selectedAgentId;
    final nameCtrl = TextEditingController();
    final addressCtrl = TextEditingController(text: bon.fruitOrigin ?? '');
    final screenContext = context;
    bool isAddingNew = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isAddingNew ? 'Tambah Relasi Baru' : 'Pilih Relasi'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isAddingNew)
                  TextField(
                    controller: nameCtrl,
                    inputFormatters: [UpperCaseTextFormatter()],
                    decoration: InputDecoration(
                      labelText: 'Nama Relasi',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  )
                else ...[
                  DropdownButtonFormField<String>(
                    value: selectedAgentId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Pilih Relasi',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    items: [
                      ...agents.map(
                        (a) => DropdownMenuItem(
                          value: a.id,
                          child: Text(a.name, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                      const DropdownMenuItem(
                        value: '__add__',
                        child: Text(
                          '+ Tambah Relasi Baru',
                          style: TextStyle(
                            color: Colors.indigo,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (v) {
                      if (v == '__add__') {
                        setDialogState(() => isAddingNew = true);
                      } else {
                        setDialogState(() => selectedAgentId = v);
                      }
                    },
                  ),
                  if (selectedAgentId != null) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: addressCtrl,
                      inputFormatters: [UpperCaseTextFormatter()],
                      decoration: InputDecoration(
                        labelText: 'Alamat (opsional)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ],
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
                String recipientName;
                String? relationAgentId;

                if (isAddingNew) {
                  if (nameCtrl.text.trim().isEmpty) {
                    if (mounted)
                      ScaffoldMessenger.of(screenContext).showSnackBar(
                        const SnackBar(
                          content: Text('Nama relasi wajib diisi'),
                        ),
                      );
                    return;
                  }
                  recipientName = nameCtrl.text.trim().toUpperCase();
                  final newId = const Uuid().v4();
                  await repo.createRelationAgent(
                    RelationAgentModel(
                      id: newId,
                      name: recipientName,
                      address: addressCtrl.text.trim().toUpperCase(),
                      contact: '',
                      accounts: [],
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    ),
                  );
                  relationAgentId = newId;
                } else {
                  if (selectedAgentId == null) {
                    if (mounted)
                      ScaffoldMessenger.of(screenContext).showSnackBar(
                        const SnackBar(
                          content: Text('Pilih relasi terlebih dahulu'),
                        ),
                      );
                    return;
                  }
                  final agent = agents.firstWhere(
                    (a) => a.id == selectedAgentId,
                  );
                  recipientName = agent.name;
                  relationAgentId = selectedAgentId;
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
                    recipientName: recipientName,
                    recipientAddress: addressCtrl.text.trim().toUpperCase(),
                    relationAgentId: relationAgentId,
                  );
                  await ref.read(notaRepositoryProvider).createNota(nota, [
                    bon.id,
                  ]);
                  if (mounted) {
                    ScaffoldMessenger.of(screenContext).showSnackBar(
                      const SnackBar(
                        content: Text('Nota berhasil dibuat'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                    _refreshBons();
                  }
                } catch (e) {
                  if (mounted)
                    ScaffoldMessenger.of(
                      screenContext,
                    ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: const Text('Cetak'),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleBonSelection(BonModel bon) {
    if (bon.status == PaymentStatus.lunas) return;
    setState(() {
      if (!_selectMode) _selectMode = true;
      if (!_selectedBonIds.remove(bon.id)) {
        _selectedBonIds.add(bon.id);
      }
      if (_selectedBonIds.isEmpty) _selectMode = false;
    });
  }

  void _cancelSelectMode() {
    setState(() {
      _selectMode = false;
      _selectedBonIds.clear();
    });
  }

  Future<void> _mergeSelectedBons() async {
    final ids = _selectedBonIds.toList();
    final repo = ref.read(notaRepositoryProvider);
    try {
      final nota = await repo.mergeBonsIntoNota(ids);
      if (!mounted) return;
      setState(() {
        _selectMode = false;
        _selectedBonIds.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nota ${nota.notaNumber} berhasil dibuat dari ${ids.length} bon'),
        ),
      );
      _refreshBons();
    } on Exception catch (e) {
      final message = e.toString();
      if (message.contains('Relasi antar bon berbeda')) {
        await _pickRelationForMerge(ids);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $message')));
        }
      }
    }
  }

  Future<void> _pickRelationForMerge(List<String> bonIds) async {
    final agents = await ref.read(relationAgentRepositoryProvider).getRelationAgents();
    if (!mounted) return;

    String? selectedId;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Pilih Relasi Nota Gabungan'),
        content: DropdownButtonFormField<String>(
          value: selectedId,
          items: agents
              .map(
                (agent) => DropdownMenuItem(
                  value: agent.id,
                  child: Text(agent.name),
                ),
              )
              .toList(),
          onChanged: (value) => selectedId = value,
          decoration: const InputDecoration(labelText: 'Relasi / Agen'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Gabung'),
          ),
        ],
      ),
    );

    final id = selectedId;
    if (confirmed != true || id == null || id.isEmpty) return;

    try {
      final nota = await ref
          .read(notaRepositoryProvider)
          .mergeBonsIntoNota(bonIds, relationAgentId: id);
      if (!mounted) return;
      setState(() {
        _selectMode = false;
        _selectedBonIds.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nota ${nota.notaNumber} berhasil dibuat dari ${bonIds.length} bon'),
        ),
      );
      _refreshBons();
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _applyInlineEdit(BonModel bon) async {
    final state = _editStates[bon.id];
    if (state == null || !state.dirty) return;

    setState(() => _savingBonIds.add(bon.id));

    try {
      final repo = ref.read(bonRepositoryProvider);
      final n1 = int.tryParse(state.netto1Ctrl.text) ?? bon.netto1.toInt();
      final n2 = int.tryParse(state.netto2Ctrl.text) ?? bon.netto2.toInt();
      final price = int.tryParse(state.priceCtrl.text) ?? bon.price.toInt();
      final bp = int.tryParse(state.bpColtCtrl.text) ?? bon.bpColt.toInt();
      final um =
          int.tryParse(state.uangMinumCtrl.text) ?? bon.uangMinum.toInt();
      final pph = state.pphEnabled ? (0.0025 * price * n2).toInt() : 0;

      // SPSI calculation
      String? spsiTypeId = state.spsiTypeId;
      String? spsiMode;
      int spsiRate = 12;
      int spsiAmount = 0;
      if (spsiTypeId != null) {
        for (final f in _factories) {
          for (final t in f.spsiTypes) {
            if (t.id == spsiTypeId) {
              spsiMode = t.calculationMode;
              spsiRate = t.amount.toInt();
              break;
            }
          }
        }
      }
      if (spsiMode == 'FIX') {
        spsiAmount = spsiRate;
      } else {
        spsiAmount = spsiRate * n1;
      }

      final deductionTotal = bon.deductions.fold<int>(
        0,
        (sum, d) => sum + d.amount,
      );
      final dp = bon.dp.toInt();
      final subtotal = price * n2;
      final total = subtotal - dp - spsiAmount - bp - pph - um - deductionTotal;

      await repo.quickUpdateBon(bon.id, {
        'netto_1': n1,
        'netto_2': n2,
        'price': price,
        'bp_colt': bp,
        'pph': pph,
        'uang_minum': um,
        'total': total.toInt(),
      });

      // Juga update SPSI fields di Supabase langsung
      if (spsiTypeId != null && spsiTypeId.isNotEmpty) {
        await repo.updateRaw(bon.id, {
          'factory_spsi_type_id': spsiTypeId,
          'spsi_calculation_mode': spsiMode,
          'spsi_rate': spsiRate,
          'spsi_amount': spsiAmount,
          'biaya_bongkar': spsiRate,
        });
      }

      // If bon sudah dalam nota, update total nota (query langsung via nota_items)
      if (bon.status == PaymentStatus.tertagih) {
        final notaId = await ref
            .read(notaRepositoryProvider)
            .getNotaIdByBonId(bon.id);
        if (notaId != null) {
          final notaBons = await ref
              .read(notaRepositoryProvider)
              .getNotaBons(notaId);
          final newTotal = notaBons.fold<double>(0, (sum, b) {
            if (b.id == bon.id) return sum + total;
            return sum + b.total;
          });
          await ref
              .read(notaRepositoryProvider)
              .updateNotaTotal(notaId, newTotal);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tersimpan'),
            duration: Duration(seconds: 1),
          ),
        );
      }
      state.dirty = false;
      _editStates.remove(bon.id);
      _refreshBons();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal: $e')));
      }
    } finally {
      if (mounted) setState(() => _savingBonIds.remove(bon.id));
    }
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
          if (_selectMode)
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: _cancelSelectMode,
                icon: const Icon(Icons.close, color: Colors.indigo, size: 18),
                label: Text(
                  'Batal (${_selectedBonIds.length})',
                  style: const TextStyle(color: Colors.indigo, fontSize: 13),
                ),
              ),
            ),
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
          _buildFactoryFilter(),
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
                  final totalTonnage = bons.fold<double>(
                    0,
                    (sum, b) => sum + b.netto2,
                  );
                  final unbilledCount = bons
                      .where((b) => b.status == PaymentStatus.belumDibayar)
                      .length;

                  return Column(
                    children: [
                      _buildBonStatsCard(
                        bons.length,
                        unbilledCount,
                        totalTonnage,
                      ),
                      Expanded(
                        child: bons.isEmpty
                            ? _buildEmptyState()
                            : ListView.separated(
                                padding: const EdgeInsets.all(16),
                                itemCount: bons.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final bon = bons[index];
                                  return _buildModernBonCard(bon);
                                },
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _selectedBonIds.length >= 2
          ? FloatingActionButton.extended(
              onPressed: _mergeSelectedBons,
              backgroundColor: Colors.indigo,
              icon: const Icon(Icons.merge_type),
              label: Text('Gabung Nota (${_selectedBonIds.length})'),
            )
          : null,
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

  Widget _buildBonStatsCard(int total, int unbilled, double tonnage) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
          _statItem(
            Icons.receipt_long_outlined,
            '$total',
            'Total Bon',
            Colors.indigo,
          ),
          _statDivider(),
          _statItem(
            Icons.pending_outlined,
            '$unbilled',
            'Belum Nota',
            Colors.orange,
          ),
          _statDivider(),
          _statItem(
            Icons.scale_outlined,
            '${(tonnage / 1000).toStringAsFixed(1)} ton',
            'Tonase',
            Colors.teal,
          ),
          _statDivider(),
          _statItem(
            Icons.add_circle_outline,
            'Baru',
            'Input Bon',
            Colors.amber,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BonEntryScreen()),
              ).then((_) => _refreshBons());
            },
          ),
        ],
      ),
    );
  }

  Widget _statItem(
    IconData icon,
    String value,
    String label,
    Color color, {
    VoidCallback? onTap,
  }) {
    final content = Column(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
        ),
      ],
    );
    if (onTap == null) return Expanded(child: content);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: content,
      ),
    );
  }

  Widget _statDivider() {
    return Container(width: 1, height: 32, color: Colors.grey.shade200);
  }

  Widget _buildFactoryFilter() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: DropdownButtonFormField<String>(
        value: _selectedFactoryId,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: 'Filter Pabrik',
          prefixIcon: Icon(
            Icons.factory_outlined,
            color: Colors.indigo.shade300,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
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

  double _computeInlineTotal(BonModel bon, _InlineEditState state) {
    final n1 = int.tryParse(state.netto1Ctrl.text) ?? bon.netto1.toInt();
    final n2 = int.tryParse(state.netto2Ctrl.text) ?? bon.netto2.toInt();
    final price = int.tryParse(state.priceCtrl.text) ?? bon.price.toInt();
    final bp = int.tryParse(state.bpColtCtrl.text) ?? bon.bpColt.toInt();
    final um = int.tryParse(state.uangMinumCtrl.text) ?? bon.uangMinum.toInt();
    final pph = state.pphEnabled ? (0.0025 * price * n2).toInt() : 0;

    String? spsiMode;
    int spsiRate = 12;
    int spsiAmount = 0;
    if (state.spsiTypeId != null) {
      for (final f in _factories) {
        for (final t in f.spsiTypes) {
          if (t.id == state.spsiTypeId) {
            spsiMode = t.calculationMode;
            spsiRate = t.amount.toInt();
            break;
          }
        }
      }
    }
    spsiAmount = spsiMode == 'FIX' ? spsiRate : spsiRate * n1;

    final dp = bon.dp.toInt();
    final deductionTotal = bon.deductions.fold<int>(
      0,
      (sum, d) => sum + d.amount,
    );
    return (price * n2 - dp - spsiAmount - bp - pph - um - deductionTotal)
        .toDouble();
  }

  Widget _buildModernBonCard(BonModel bon) {
    final currencyFmt = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final dateFmt = DateFormat('dd MMM yyyy');
    final isUnpaid = bon.status == PaymentStatus.belumDibayar;
    final isExpanded = _expandedCardIds.contains(bon.id);
    final editState = _editStates.putIfAbsent(
      bon.id,
      () => _InlineEditState(bon),
    );
    final isSaving = _savingBonIds.contains(bon.id);
    final showLive = editState.dirty;
    final liveNetto2 =
        int.tryParse(editState.netto2Ctrl.text) ?? bon.netto2.toInt();
    final livePrice =
        int.tryParse(editState.priceCtrl.text) ?? bon.price.toInt();
    final liveTotal = _computeInlineTotal(bon, editState);
    final displayNetto2 = showLive ? liveNetto2 : bon.netto2.toInt();
    final displayPrice = showLive ? livePrice : bon.price.toInt();
    final displayTotal = showLive ? liveTotal : bon.total;

    _InlineField(String label, TextEditingController ctrl, {int flex = 1}) {
      return Expanded(
        flex: flex,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 8, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Colors.indigo),
                ),
              ),
              onChanged: (_) => setState(() => editState.dirty = true),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: _selectedBonIds.contains(bon.id)
            ? Border.all(color: Colors.indigo, width: 2)
            : (_selectMode && isUnpaid
                  ? Border.all(color: Colors.indigo.shade200, width: 1)
                  : null),
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
            if (_selectMode) {
              _toggleBonSelection(bon);
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => BonEntryScreen(bon: bon)),
              ).then((_) => _refreshBons());
            }
          },
          onLongPress: () => _toggleBonSelection(bon),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_selectMode && isUnpaid)
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _selectedBonIds.contains(bon.id)
                              ? Colors.indigo
                              : Colors.white,
                          border: Border.all(
                            color: _selectedBonIds.contains(bon.id)
                                ? Colors.indigo
                                : Colors.grey.shade400,
                            width: 1.5,
                          ),
                        ),
                        child: _selectedBonIds.contains(bon.id)
                            ? const Icon(
                                Icons.check,
                                size: 15,
                                color: Colors.white,
                              )
                            : null,
                      )
                    else
                      const SizedBox(width: 22),
                    Text(
                      'Waktu input: ${DateFormat('dd/MM/yyyy HH:mm:ss').format(bon.createdAt)}',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.grey.shade500,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
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
                        Row(
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
                            if (bon.ticketNumber != null &&
                                bon.ticketNumber!.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Text(
                                bon.ticketNumber!,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ],
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
                            bon.status == PaymentStatus.belumDibayar
                                ? 'BELUM NOTA'
                                : bon.status == PaymentStatus.tertagih
                                ? 'BELUM BAYAR'
                                : 'LUNAS',
                            style: TextStyle(
                              color: _getStatusColor(bon.status),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
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
                              const SizedBox(height: 2),
                              _buildMetaData(
                                Icons.business,
                                bon.relationAgentName ?? bon.relationName ?? '-',
                              ),
                              const SizedBox(height: 2),
                              _buildMetaData(
                                Icons.calendar_today,
                                dateFmt.format(bon.bonDate),
                              ),
                              if (bon.factoryName != null &&
                                  bon.factoryName!.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                _buildMetaData(
                                  Icons.factory_outlined,
                                  bon.factoryName!,
                                  fontSize: 10,
                                  color: Colors.grey.shade500,
                                ),
                              ],
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  if (isUnpaid) ...[
                                    if (bon.imageUrl != null &&
                                        bon.imageUrl!.isNotEmpty)
                                      OutlinedButton(
                                        onPressed: () =>
                                            ZoomableImagePreview.showImageDialog(
                                              context,
                                              imageUrl: bon.imageUrl,
                                            ),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.grey.shade600,
                                          side: BorderSide(
                                            color: Colors.grey.shade300,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                          ),
                                          minimumSize: const Size(0, 26),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.image_outlined,
                                          size: 14,
                                        ),
                                      ),
                                    OutlinedButton.icon(
                                      onPressed: () => _createNotaSatuan(bon),
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
                                    ),
                                  ] else if (bon.status ==
                                      PaymentStatus.tertagih)
                                    FutureBuilder<NotaModel?>(
                                      future: _getNotaForBon(bon.id),
                                      builder: (context, snapshot) {
                                        final nota = snapshot.data;
                                        return Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (bon.imageUrl != null &&
                                                bon.imageUrl!.isNotEmpty)
                                              OutlinedButton(
                                                onPressed: () =>
                                                    ZoomableImagePreview.showImageDialog(
                                                      context,
                                                      imageUrl: bon.imageUrl,
                                                    ),
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor:
                                                      Colors.grey.shade600,
                                                  side: BorderSide(
                                                    color: Colors.grey.shade300,
                                                  ),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                      ),
                                                  minimumSize: const Size(
                                                    0,
                                                    26,
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                  ),
                                                ),
                                                child: const Icon(
                                                  Icons.image_outlined,
                                                  size: 14,
                                                ),
                                              ),
                                            OutlinedButton.icon(
                                              onPressed: () =>
                                                  _openNotaForBon(bon.id, nota),
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
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                    ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 2),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.chat_outlined,
                                                size: 18,
                                                color: Colors.green,
                                              ),
                                              onPressed: () =>
                                                  _shareNotaForBon(bon.id, nota),
                                              visualDensity:
                                                  VisualDensity.compact,
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(),
                                              tooltip: 'Share WhatsApp',
                                            ),
                                            const SizedBox(width: 4),
                                            IconButton(
                                              icon: Icon(
                                                isExpanded
                                                    ? Icons.expand_less
                                                    : Icons.expand_more,
                                                size: 20,
                                              ),
                                              onPressed: () => setState(() {
                                                if (isExpanded) {
                                                  _expandedCardIds.remove(
                                                    bon.id,
                                                  );
                                                } else {
                                                  _expandedCardIds.add(bon.id);
                                                }
                                              }),
                                              visualDensity:
                                                  VisualDensity.compact,
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  if (isUnpaid)
                                    IconButton(
                                      icon: Icon(
                                        isExpanded
                                            ? Icons.expand_less
                                            : Icons.expand_more,
                                        size: 20,
                                      ),
                                      onPressed: () => setState(() {
                                        if (isExpanded) {
                                          _expandedCardIds.remove(bon.id);
                                        } else {
                                          _expandedCardIds.add(bon.id);
                                        }
                                      }),
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
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
                              '$displayNetto2 kg',
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
                              currencyFmt.format(displayPrice),
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
                              currencyFmt.format(displayTotal),
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
                    if (isExpanded) ...[
                      const SizedBox(height: 8),
                      const Divider(height: 1),
                      const SizedBox(height: 8),
                      // Row 1: Netto1 | Netto2 | Harga | SPSI | U.Min
                      Row(
                        children: [
                          Expanded(
                            child: _InlineField('Netto1', editState.netto1Ctrl),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _InlineField('Netto2', editState.netto2Ctrl),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _InlineField('Harga', editState.priceCtrl),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'SPSI',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                _buildSpsiDropdown(bon, editState),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _InlineField(
                              'U.Min',
                              editState.uangMinumCtrl,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Row 2: BP pills | PPh toggle | Save
                      Row(
                        children: [
                          // BP pills
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'BP',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(width: 6),
                              ...[0, 50000, 70000, 100000, 150000].map((val) {
                                final isActive =
                                    (int.tryParse(editState.bpColtCtrl.text) ??
                                        100000) ==
                                    val;
                                return GestureDetector(
                                  onTap: () {
                                    editState.bpColtCtrl.text = val.toString();
                                    setState(() => editState.dirty = true);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? Colors.indigo.shade50
                                          : null,
                                      border: Border.all(
                                        color: isActive
                                            ? Colors.indigo
                                            : Colors.grey.shade300,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${val ~/ 1000}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isActive
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: isActive
                                            ? Colors.indigo
                                            : Colors.grey.shade500,
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                          const Spacer(),
                          // PPh toggle
                          GestureDetector(
                            onTap: () => setState(() {
                              editState.pphEnabled = !editState.pphEnabled;
                              editState.dirty = true;
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: editState.pphEnabled
                                    ? Colors.indigo.shade50
                                    : Colors.grey.shade100,
                                border: Border.all(
                                  color: editState.pphEnabled
                                      ? Colors.indigo
                                      : Colors.grey.shade300,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.receipt,
                                    size: 14,
                                    color: editState.pphEnabled
                                        ? Colors.indigo
                                        : Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'PPh ${editState.pphEnabled ? "AKTIF" : "MATI"}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: editState.pphEnabled
                                          ? Colors.indigo
                                          : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Save button
                          if (editState.dirty)
                            SizedBox(
                              width: 64,
                              height: 32,
                              child: ElevatedButton(
                                onPressed: isSaving
                                    ? null
                                    : () => _applyInlineEdit(bon),
                                style: ElevatedButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  backgroundColor: Colors.indigo,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  minimumSize: const Size(0, 32),
                                ),
                                child: isSaving
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Simpan',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpsiDropdown(BonModel bon, _InlineEditState state) {
    final factory = _factories.where((f) => f.id == bon.factoryId).firstOrNull;
    final types = factory?.spsiTypes ?? [];
    final fontSize = 12.0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(6),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: types.any((t) => t.id == state.spsiTypeId)
              ? state.spsiTypeId
              : null,
          isExpanded: true,
          isDense: true,
          style: TextStyle(fontSize: fontSize, color: Colors.black87),
          hint: Text('-', style: TextStyle(fontSize: fontSize)),
          items: types
              .map(
                (t) => DropdownMenuItem(
                  value: t.id,
                  child: Text(t.name, style: TextStyle(fontSize: fontSize - 1)),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() {
            state.spsiTypeId = v;
            state.dirty = true;
          }),
        ),
      ),
    );
  }

  Widget _buildMetaData(
    IconData icon,
    String text, {
    double fontSize = 12,
    Color? color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color ?? Colors.grey.shade400),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: color ?? Colors.grey.shade600,
              fontSize: fontSize,
            ),
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
        return Colors.indigo;
    }
  }

  void _shareNotaWhatsapp(NotaModel nota, List<BonModel> bons) {
    final message = NotaWhatsappService.buildMessage(nota, bons);
    launchUrl(
      Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}'),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _shareNotaWhatsappAsync(NotaModel nota) async {
    try {
      final notaBons = await ref.read(notaRepositoryProvider).getNotaBons(nota.id);
      if (!mounted) return;
      _shareNotaWhatsapp(nota, notaBons);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal memuat data bon nota')),
        );
      }
    }
  }
}
