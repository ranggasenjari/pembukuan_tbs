import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/payment_relation_model.dart';
import '../../models/vehicle_model.dart';
import '../../providers/providers.dart';
import '../payment_relations/payment_relation_entry_screen.dart';
import 'vehicle_entry_screen.dart';

class VehicleListScreen extends ConsumerStatefulWidget {
  const VehicleListScreen({super.key});

  @override
  ConsumerState<VehicleListScreen> createState() => _VehicleListScreenState();
}

class _VehicleListScreenState extends ConsumerState<VehicleListScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  List<VehicleModel> _items = [];
  List<PaymentRelationOption> _relations = [];
  bool _loading = true;
  final Set<String> _expanded = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ref.read(vehicleRepositoryProvider).getVehicles(query: _query),
        ref.read(vehicleRepositoryProvider).getPaymentRelationOptions(),
      ]);
      if (!mounted) return;
      setState(() {
        _items = results[0] as List<VehicleModel>;
        _relations = results[1] as List<PaymentRelationOption>;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open([VehicleModel? item]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => VehicleEntryScreen(vehicle: item)),
    );
    _load();
  }

  void _toggleInline(VehicleModel vehicle) {
    setState(() {
      if (!_expanded.remove(vehicle.id)) {
        _expanded.add(vehicle.id);
      }
    });
  }

  Future<void> _saveInline(
    VehicleModel vehicle, {
    required double potonganBp,
    required double harga,
    required String relationId,
  }) async {
    setState(() => _saving = true);
    try {
      final updated = VehicleModel(
        id: vehicle.id,
        plateNumber: vehicle.plateNumber,
        driverName: vehicle.driverName,
        potonganBp: potonganBp,
        harga: harga,
        isSuper: vehicle.isSuper,
        paymentRelationId: relationId.isEmpty ? null : relationId,
        createdAt: vehicle.createdAt,
        updatedAt: DateTime.now(),
      );
      await ref.read(vehicleRepositoryProvider).updateVehicle(updated);
      if (!mounted) return;
      setState(() => _expanded.remove(vehicle.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kendaraan diperbarui'),
          backgroundColor: Colors.green,
        ),
      );
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _handleRelationCreated(
    PaymentRelationModel created,
    VehicleModel vehicle,
  ) async {
    try {
      await ref
          .read(vehicleRepositoryProvider)
          .updateVehicleRelation(vehicle.id, created.id);
    } catch (_) {}
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Relasi bayar baru dibuat & dihubungkan'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  String _formatHarga(double? harga) {
    if (harga == null) return '-';
    if (harga > 100 || harga < -100) {
      return NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
        decimalDigits: 0,
      ).format(harga);
    }
    if (harga >= -100 && harga <= 100 && harga != 0) {
      return '${harga >= 0 ? '+' : ''}${harga.toInt()} (offset)';
    }
    return '-';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      appBar: AppBar(
        title: const Text(
          'Kendaraan',
          style: TextStyle(
            color: Color(0xFF1B2559),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1B2559)),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _open(),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _items.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 120),
                              Center(
                                child: Text(
                                  'Belum ada data kendaraan',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _items.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final vehicle = _items[index];
                              return _buildVehicleCard(vehicle);
                            },
                          ),
                  ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
          hintText: 'Cari plat nomor / driver...',
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          prefixIcon: Icon(Icons.search, color: Colors.indigo.shade300),
          suffixIcon: _query.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _query = '');
                    _load();
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
          setState(() => _query = value);
          _load();
        },
      ),
    );
  }

  Widget _buildVehicleCard(VehicleModel vehicle) {
    final currencyFmt = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final isExpanded = _expanded.contains(vehicle.id);

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.local_shipping, color: Colors.indigo),
            ),
            title: Row(
              children: [
                Text(
                  vehicle.plateNumber,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF1B2559),
                  ),
                ),
                if (vehicle.isSuper) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'SUPER',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(vehicle.driverName ?? '-'),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: [
                    Text(
                      'BP: ${currencyFmt.format(vehicle.potonganBp)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      'Harga: ${_formatHarga(vehicle.harga)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                if (vehicle.paymentRelationName != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Relasi Bayar: ${vehicle.paymentRelationName}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ],
            ),
            trailing: IconButton(
              icon: Icon(
                isExpanded ? Icons.expand_less : Icons.edit_outlined,
                color: Colors.indigo,
              ),
              onPressed: _saving ? null : () => _toggleInline(vehicle),
            ),
            onTap: () => _open(vehicle),
          ),
          if (isExpanded) ...[
            const Divider(height: 1),
            _InlineVehicleForm(
              vehicle: vehicle,
              relations: _relations,
              saving: _saving,
              onSave: _saveInline,
              onRelationCreated: _handleRelationCreated,
            ),
          ],
        ],
      ),
    );
  }
}

class _InlineVehicleForm extends StatefulWidget {
  final VehicleModel vehicle;
  final List<PaymentRelationOption> relations;
  final bool saving;
  final Future<void> Function(
    VehicleModel vehicle, {
    required double potonganBp,
    required double harga,
    required String relationId,
  }) onSave;
  final Future<void> Function(
    PaymentRelationModel created,
    VehicleModel vehicle,
  )?
  onRelationCreated;

  const _InlineVehicleForm({
    required this.vehicle,
    required this.relations,
    required this.saving,
    required this.onSave,
    this.onRelationCreated,
  });

  @override
  State<_InlineVehicleForm> createState() => _InlineVehicleFormState();
}

class _InlineVehicleFormState extends State<_InlineVehicleForm> {
  late double _potonganBp;
  late final TextEditingController _hargaController;
  late String _relationId;

  @override
  void initState() {
    super.initState();
    _potonganBp = widget.vehicle.potonganBp;
    _hargaController = TextEditingController(
      text: widget.vehicle.harga?.toInt().toString() ?? '',
    );
    _relationId = widget.vehicle.paymentRelationId ?? '';
  }

  @override
  void dispose() {
    _hargaController.dispose();
    super.dispose();
  }

  Future<void> _openAddRelation() async {
    final created = await Navigator.push<PaymentRelationModel>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PaymentRelationEntryScreen(initialVehicleId: widget.vehicle.id),
      ),
    );
    if (created != null && mounted) {
      await widget.onRelationCreated?.call(created, widget.vehicle);
    }
  }

  static const _bpOptions = [0, 50000, 70000, 100000, 150000];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Potongan BP',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: _bpOptions.map((value) {
              final active = _potonganBp == value;
              return InkWell(
                onTap: widget.saving
                    ? null
                    : () => setState(() => _potonganBp = value.toDouble()),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: active ? const Color(0xFF4318FF) : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: active ? const Color(0xFF4318FF) : Colors.grey.shade300,
                    ),
                  ),
                  child: Text(
                    value == 0 ? '0' : (value ~/ 1000).toString(),
                    style: TextStyle(
                      color: active ? Colors.white : Colors.grey.shade700,
                      fontWeight: active ? FontWeight.bold : FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _hargaController,
            keyboardType: TextInputType.number,
            enabled: !widget.saving,
            decoration: InputDecoration(
              labelText: 'Harga / Kg (Rp)',
              hintText: 'Di luar -100..100 = tetap; dalam = offset (±)',
              hintStyle: const TextStyle(fontSize: 11),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _relationId.isEmpty ? null : _relationId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Relasi Bayar',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('(Tidak ada)'),
                    ),
                    ...widget.relations.map(
                      (relation) => DropdownMenuItem<String>(
                        value: relation.id,
                        child: Text(
                          relation.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: widget.saving
                      ? null
                      : (value) => setState(() => _relationId = value ?? ''),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                onPressed: widget.saving ? null : _openAddRelation,
                tooltip: 'Tambah Relasi Bayar',
                icon: const Icon(
                  Icons.add_circle_outline,
                  color: Color(0xFF4318FF),
                  size: 26,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: widget.saving
                  ? null
                  : () {
                      final harga = double.tryParse(_hargaController.text) ?? 0;
                      widget.onSave(
                        widget.vehicle,
                        potonganBp: _potonganBp,
                        harga: _hargaController.text.trim().isEmpty ? 0 : harga,
                        relationId: _relationId,
                      );
                    },
              icon: const Icon(Icons.save_outlined, size: 18),
              label: Text(widget.saving ? 'Menyimpan...' : 'Simpan'),
            ),
          ),
        ],
      ),
    );
  }
}