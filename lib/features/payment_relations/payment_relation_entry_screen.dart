import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../models/payment_relation_model.dart';
import '../../providers/providers.dart';

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

class PaymentRelationEntryScreen extends ConsumerStatefulWidget {
  final PaymentRelationModel? paymentRelation;
  const PaymentRelationEntryScreen({super.key, this.paymentRelation});

  @override
  ConsumerState<PaymentRelationEntryScreen> createState() =>
      _PaymentRelationEntryScreenState();
}

class _PaymentRelationEntryScreenState
    extends ConsumerState<PaymentRelationEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  final List<
    ({
      TextEditingController bank,
      TextEditingController number,
      TextEditingController name,
    })
  >
  _accountControllers = [];
  final Set<String> _selectedVehicleIds = {};
  late Future<List<VehicleOption>> _vehiclesFuture;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _vehiclesFuture = ref.read(paymentRelationRepositoryProvider).getVehicles();
    final item = widget.paymentRelation;
    if (item != null) {
      _nameController.text = item.name;
      _contactController.text = item.contact ?? '';
      _addressController.text = item.address ?? '';
      _notesController.text = item.notes ?? '';
      _selectedVehicleIds.addAll(item.vehicles.map((vehicle) => vehicle.vehicleId));
      for (final account in item.accounts) {
        _addAccount(
          bank: account.bankName,
          number: account.accountNumber,
          name: account.accountName,
        );
      }
    }
    if (_accountControllers.isEmpty) _addAccount();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    for (final item in _accountControllers) {
      item.bank.dispose();
      item.number.dispose();
      item.name.dispose();
    }
    super.dispose();
  }

  void _addAccount({String bank = '', String number = '', String name = ''}) {
    setState(() {
      _accountControllers.add((
        bank: TextEditingController(text: bank),
        number: TextEditingController(text: number),
        name: TextEditingController(text: name),
      ));
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final id = widget.paymentRelation?.id ?? const Uuid().v4();
      final now = DateTime.now();
      final paymentRelation = PaymentRelationModel(
        id: id,
        name: _nameController.text.trim().toUpperCase(),
        contact: _contactController.text.trim(),
        address: _addressController.text.trim().toUpperCase(),
        notes: _notesController.text.trim(),
        accounts: _accountControllers
            .map(
              (item) => PaymentRelationAccount(
                paymentRelationId: id,
                bankName: item.bank.text.trim().toUpperCase(),
                accountNumber: item.number.text.trim(),
                accountName: item.name.text.trim().toUpperCase(),
              ),
            )
            .toList(),
        vehicles: _selectedVehicleIds
            .map(
              (vehicleId) => PaymentRelationVehicle(
                paymentRelationId: id,
                vehicleId: vehicleId,
              ),
            )
            .toList(),
        createdAt: widget.paymentRelation?.createdAt ?? now,
        updatedAt: now,
      );

      final repo = ref.read(paymentRelationRepositoryProvider);
      if (widget.paymentRelation == null) {
        await repo.createPaymentRelation(paymentRelation);
      } else {
        await repo.updatePaymentRelation(paymentRelation);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Relasi Bayar'),
        content: const Text('Yakin ingin menghapus data ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true || widget.paymentRelation == null) return;
    await ref
        .read(paymentRelationRepositoryProvider)
        .deletePaymentRelation(widget.paymentRelation!.id);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      appBar: AppBar(
        title: Text(
          widget.paymentRelation == null
              ? 'Tambah Relasi Bayar'
              : 'Edit Relasi Bayar',
          style: const TextStyle(
            color: Color(0xFF1B2559),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1B2559)),
        actions: [
          if (widget.paymentRelation != null)
            IconButton(
              onPressed: _isSaving ? null : _delete,
              icon: const Icon(Icons.delete_outline, color: Colors.red),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _section('Data Relasi Bayar', Icons.handshake_outlined, [
              _textField(_nameController, 'Nama Relasi Bayar', required: true),
              const SizedBox(height: 12),
              _textField(_contactController, 'Kontak', forceUpperCase: false),
              const SizedBox(height: 12),
              _textField(_addressController, 'Alamat / Asal'),
              const SizedBox(height: 12),
              _textField(_notesController, 'Catatan', forceUpperCase: false),
            ]),
            const SizedBox(height: 16),
            _vehicleSection(),
            const SizedBox(height: 16),
            _sectionHeader(
              'Rekening',
              Icons.account_balance_outlined,
              _addAccount,
            ),
            ..._accountControllers.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return _accountRow(
                bank: _textField(item.bank, 'Nama Bank'),
                number: _textField(
                  item.number,
                  'No Rekening',
                  forceUpperCase: false,
                ),
                name: _textField(item.name, 'Nama Rekening'),
                onRemove: _accountControllers.length > 1
                    ? () => setState(() => _accountControllers.removeAt(index))
                    : null,
              );
            }),
            const SizedBox(height: 90),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(20),
        child: SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4318FF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _isSaving
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text(
                    'SIMPAN RELASI BAYAR',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _vehicleSection() {
    return _section('Kendaraan', Icons.local_shipping_outlined, [
      FutureBuilder<List<VehicleOption>>(
        future: _vehiclesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Text('Error: ${snapshot.error}');
          }
          final vehicles = snapshot.data ?? [];
          if (vehicles.isEmpty) {
            return Text(
              'Belum ada kendaraan. Tambahkan dahulu dari modul Kendaraan.',
              style: TextStyle(color: Colors.grey.shade600),
            );
          }
          return Column(
            children: vehicles.map((vehicle) {
              final selected = _selectedVehicleIds.contains(vehicle.id);
              return CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: selected,
                title: Text(vehicle.plateNumber),
                subtitle: Text(vehicle.driverName ?? '-'),
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selectedVehicleIds.add(vehicle.id);
                    } else {
                      _selectedVehicleIds.remove(vehicle.id);
                    }
                  });
                },
              );
            }).toList(),
          );
        },
      ),
    ]);
  }

  Widget _section(String title, IconData icon, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.teal),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const Divider(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon, VoidCallback onAdd) {
    return _section(title, icon, [
      Align(
        alignment: Alignment.centerRight,
        child: OutlinedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Tambah'),
        ),
      ),
    ]);
  }

  Widget _accountRow({
    required Widget bank,
    required Widget number,
    required Widget name,
    VoidCallback? onRemove,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          bank,
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: number),
              const SizedBox(width: 8),
              Expanded(child: name),
              if (onRemove != null)
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(
                    Icons.remove_circle_outline,
                    color: Colors.red,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label, {
    bool required = false,
    bool forceUpperCase = true,
  }) {
    return TextFormField(
      controller: controller,
      inputFormatters: forceUpperCase
          ? [UpperCaseTextFormatter()]
          : null,
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      validator: required
          ? (value) => value == null || value.isEmpty ? 'Wajib diisi' : null
          : null,
    );
  }
}
