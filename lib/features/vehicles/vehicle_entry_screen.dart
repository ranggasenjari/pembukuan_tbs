import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../models/payment_relation_model.dart';
import '../../models/vehicle_model.dart';
import '../../providers/providers.dart';
import '../payment_relations/payment_relation_entry_screen.dart';

class VehicleEntryScreen extends ConsumerStatefulWidget {
  final VehicleModel? vehicle;
  const VehicleEntryScreen({super.key, this.vehicle});

  @override
  ConsumerState<VehicleEntryScreen> createState() => _VehicleEntryScreenState();
}

class _VehicleEntryScreenState extends ConsumerState<VehicleEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _plateController = TextEditingController();
  final _driverController = TextEditingController();
  final _hargaController = TextEditingController();
  final _uangMinumController = TextEditingController();
  double _potonganBp = 100000;
  bool _isSuper = false;
  String? _relationId;
  List<PaymentRelationOption> _relations = [];
  bool _saving = false;

  static const _bpOptions = [0, 50000, 70000, 100000, 150000];

  @override
  void initState() {
    super.initState();
    final vehicle = widget.vehicle;
    if (vehicle != null) {
      _plateController.text = vehicle.plateNumber;
      _driverController.text = vehicle.driverName ?? '';
      _hargaController.text = vehicle.harga?.toInt().toString() ?? '';
      _uangMinumController.text = vehicle.uangMinum?.toInt().toString() ?? '';
      _potonganBp = vehicle.potonganBp;
      _isSuper = vehicle.isSuper;
      _relationId = vehicle.paymentRelationId;
    }
    _loadRelations();
  }

  Future<void> _loadRelations() async {
    try {
      final relations = await ref
          .read(vehicleRepositoryProvider)
          .getPaymentRelationOptions();
      if (mounted) setState(() => _relations = relations);
    } catch (_) {}
  }

  Future<void> _openAddRelation() async {
    final created = await Navigator.push<PaymentRelationModel>(
      context,
      MaterialPageRoute(builder: (_) => const PaymentRelationEntryScreen()),
    );
    if (created != null && mounted) {
      await _loadRelations();
      setState(() => _relationId = created.id);
    }
  }

  @override
  void dispose() {
    _plateController.dispose();
    _driverController.dispose();
    _hargaController.dispose();
    _uangMinumController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final id = widget.vehicle?.id ?? const Uuid().v4();
    final hargaText = _hargaController.text.trim();
    final uangMinumText = _uangMinumController.text.trim();
    final vehicle = VehicleModel(
      id: id,
      plateNumber: _plateController.text.trim().toUpperCase(),
      driverName: _driverController.text.trim().isEmpty
          ? null
          : _driverController.text.trim().toUpperCase(),
      potonganBp: _potonganBp,
      harga: hargaText.isEmpty ? null : double.tryParse(hargaText) ?? 0,
      uangMinum: uangMinumText.isEmpty
          ? null
          : double.tryParse(uangMinumText) ?? 0,
      isSuper: _isSuper,
      paymentRelationId: _relationId,
      createdAt: widget.vehicle?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
    try {
      final repo = ref.read(vehicleRepositoryProvider);
      if (widget.vehicle == null) {
        await repo.createVehicle(vehicle);
      } else {
        await repo.updateVehicle(vehicle);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kendaraan berhasil disimpan'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Kendaraan'),
        content: Text('Yakin hapus ${widget.vehicle!.plateNumber}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ref
          .read(vehicleRepositoryProvider)
          .deleteVehicle(widget.vehicle!.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      appBar: AppBar(
        title: Text(
          widget.vehicle == null ? 'Tambah Kendaraan' : 'Edit Kendaraan',
          style: const TextStyle(
            color: Color(0xFF1B2559),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1B2559)),
        actions: [
          if (widget.vehicle != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: _saving ? null : _delete,
              tooltip: 'Hapus Kendaraan',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _card('Data Kendaraan', Icons.local_shipping_outlined, [
                _field(
                  controller: _plateController,
                  label: 'Plat Nomor',
                  icon: Icons.confirmation_number_outlined,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
                ),
                const SizedBox(height: 16),
                _field(
                  controller: _driverController,
                  label: 'Nama Driver',
                  icon: Icons.person_outline,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Potongan BP',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: _bpOptions.map((value) {
                    final active = _potonganBp == value;
                    return InkWell(
                      onTap: () => setState(() => _potonganBp = value.toDouble()),
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
                const SizedBox(height: 16),
                TextFormField(
                  controller: _hargaController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9-]'))],
                  decoration: _decoration(
                    label: 'Harga / Kg (Rp)',
                    icon: Icons.price_change_outlined,
                  ).copyWith(
                    helperText:
                        'Di luar -100 s.d. 100 = harga tetap. Antara -100 s.d. 100 = offset (±) dari harga pabrik.',
                    helperStyle: const TextStyle(fontSize: 10),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _uangMinumController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9-]'))],
                  decoration: _decoration(
                    label: 'Uang Minum (Rp)',
                    icon: Icons.volunteer_activism_outlined,
                  ).copyWith(
                    helperText:
                        'Kosongkan untuk ikut relasi bayar atau default (10.000/20.000).',
                    helperStyle: const TextStyle(fontSize: 10),
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: _isSuper,
                  onChanged: (value) => setState(() => _isSuper = value),
                  title: const Text('Buah Super', style: TextStyle(fontSize: 14)),
                  contentPadding: EdgeInsets.zero,
                  activeTrackColor: Colors.indigo,
                ),
              ]),
              const SizedBox(height: 16),
              _card('Relasi Bayar', Icons.handshake_outlined, [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _relationId,
                        isExpanded: true,
                        decoration: _decoration(
                          label: 'Relasi Bayar',
                          icon: Icons.account_balance_outlined,
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('(Tidak ada)'),
                          ),
                          ..._relations.map(
                            (relation) => DropdownMenuItem<String>(
                              value: relation.id,
                              child: Text(
                                relation.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => _relationId = value),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      onPressed: _saving ? null : _openAddRelation,
                      tooltip: 'Tambah Relasi Bayar',
                      icon: const Icon(
                        Icons.add_circle_outline,
                        color: Color(0xFF4318FF),
                        size: 26,
                      ),
                    ),
                  ],
                ),
              ]),
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('Simpan Kendaraan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(String title, IconData icon, List<Widget> children) {
    return Container(
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
          Row(
            children: [
              Icon(icon, color: Colors.indigo, size: 20),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Color(0xFF1B2559),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      textCapitalization: TextCapitalization.characters,
      validator: validator,
      decoration: _decoration(label: label, icon: icon),
    );
  }

  InputDecoration _decoration({required String label, IconData? icon}) {
    return InputDecoration(
      labelText: label,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      filled: true,
      fillColor: Colors.grey.shade50,
      prefixIcon: icon != null
          ? Icon(icon, color: Colors.grey.shade400, size: 20)
          : null,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF4318FF), width: 1.5),
      ),
    );
  }
}