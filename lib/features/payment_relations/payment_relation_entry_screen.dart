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

  /// Kendaraan yang otomatis dicentang saat membuat relasi baru (misal dari layar Kendaraan).
  final String? initialVehicleId;
  const PaymentRelationEntryScreen({
    super.key,
    this.paymentRelation,
    this.initialVehicleId,
  });

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
  final _feeController = TextEditingController();
  final _potonganBpController = TextEditingController();
  final _hargaController = TextEditingController();
  final _uangMinumController = TextEditingController();
  final List<
    ({
      TextEditingController bank,
      TextEditingController number,
      TextEditingController name,
    })
  >
  _accountControllers = [];
  final List<
    ({
      TextEditingController tanggal,
      TextEditingController amount,
      TextEditingController notes,
    })
  >
  _hutangControllers = [];
  final List<
    ({
      TextEditingController tanggal,
      TextEditingController amount,
      TextEditingController notes,
    })
  >
  _rollingControllers = [];
  final List<TextEditingController> _giringanControllers = [];
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
      _feeController.text = item.fee?.toString() ?? '';
      _potonganBpController.text = item.potonganBp?.toString() ?? '';
      _hargaController.text = item.harga?.toString() ?? '';
      _uangMinumController.text = item.uangMinum?.toString() ?? '';
      _selectedVehicleIds.addAll(item.vehicles.map((vehicle) => vehicle.vehicleId));
      for (final account in item.accounts) {
        _addAccount(
          bank: account.bankName,
          number: account.accountNumber,
          name: account.accountName,
        );
      }
      for (final row in item.hutang) {
        _addDatedRow(
          _hutangControllers,
          tanggal: row.tanggal,
          amount: row.amount,
          notes: row.notes,
        );
      }
      for (final row in item.rolling) {
        _addDatedRow(
          _rollingControllers,
          tanggal: row.tanggal,
          amount: row.amount,
          notes: row.notes,
        );
      }
      for (final row in item.giringan) {
        _addGiringan(name: row.name);
      }
    }
    if (widget.initialVehicleId != null) {
      _selectedVehicleIds.add(widget.initialVehicleId!);
    }
    if (_accountControllers.isEmpty) _addAccount();
    if (_hutangControllers.isEmpty) _addDatedRow(_hutangControllers);
    if (_rollingControllers.isEmpty) _addDatedRow(_rollingControllers);
    if (_giringanControllers.isEmpty) _addGiringan();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    _feeController.dispose();
    _potonganBpController.dispose();
    _hargaController.dispose();
    _uangMinumController.dispose();
    for (final item in _accountControllers) {
      item.bank.dispose();
      item.number.dispose();
      item.name.dispose();
    }
    for (final item in _hutangControllers) {
      item.tanggal.dispose();
      item.amount.dispose();
      item.notes.dispose();
    }
    for (final item in _rollingControllers) {
      item.tanggal.dispose();
      item.amount.dispose();
      item.notes.dispose();
    }
    for (final item in _giringanControllers) {
      item.dispose();
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

  void _addDatedRow(
    List<({TextEditingController tanggal, TextEditingController amount, TextEditingController notes})> list, {
    DateTime? tanggal,
    int amount = 0,
    String? notes,
  }) {
    setState(() {
      list.add((
        tanggal: TextEditingController(
          text: tanggal != null
              ? '${tanggal.year.toString().padLeft(4, '0')}-${tanggal.month.toString().padLeft(2, '0')}-${tanggal.day.toString().padLeft(2, '0')}'
              : '',
        ),
        amount: TextEditingController(text: amount == 0 ? '' : amount.toString()),
        notes: TextEditingController(text: notes ?? ''),
      ));
    });
  }

  void _addGiringan({String name = ''}) {
    setState(() {
      _giringanControllers.add(TextEditingController(text: name));
    });
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final initial = DateTime.tryParse(controller.text) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      controller.text =
          '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final id = widget.paymentRelation?.id ?? const Uuid().v4();
      final now = DateTime.now();

      List<PaymentRelationDatedRow> buildDatedRows(
        List<({TextEditingController tanggal, TextEditingController amount, TextEditingController notes})> list,
      ) {
        return list
            .map((item) {
              final tanggal = DateTime.tryParse(item.tanggal.text) ?? DateTime.now();
              final amount = int.tryParse(item.amount.text) ?? 0;
              return PaymentRelationDatedRow(
                paymentRelationId: id,
                tanggal: tanggal,
                amount: amount,
                notes: item.notes.text.trim().isEmpty
                    ? null
                    : item.notes.text.trim(),
              );
            })
            .where((row) => row.amount != 0)
            .toList();
      }

      final paymentRelation = PaymentRelationModel(
        id: id,
        name: _nameController.text.trim().toUpperCase(),
        contact: _contactController.text.trim(),
        address: _addressController.text.trim().toUpperCase(),
        notes: _notesController.text.trim(),
        fee: int.tryParse(_feeController.text.trim()),
        potonganBp: int.tryParse(_potonganBpController.text.trim()),
        harga: int.tryParse(_hargaController.text.trim()),
        uangMinum: int.tryParse(_uangMinumController.text.trim()),
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
        hutang: buildDatedRows(_hutangControllers),
        rolling: buildDatedRows(_rollingControllers),
        giringan: _giringanControllers
            .map(
              (item) => PaymentRelationGiringan(
                paymentRelationId: id,
                name: item.text.trim().toUpperCase(),
              ),
            )
            .where((row) => row.name.isNotEmpty)
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
      if (mounted) Navigator.pop(context, paymentRelation);
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
              _numberField(_feeController, 'Fee (Rp)'),
              const SizedBox(height: 12),
              _numberField(_potonganBpController, 'Potongan BP (Rp)'),
              const SizedBox(height: 12),
              _numberField(_hargaController, 'Harga / Kg (Rp)'),
              const SizedBox(height: 4),
              Text(
                'Kosongkan untuk ikut kendaraan/default. Di luar -100 s.d. 100 = harga tetap; antara -100 s.d. 100 = offset (±) dari harga pabrik.',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              _numberField(_uangMinumController, 'Uang Minum (Rp)'),
              const SizedBox(height: 12),
              _textField(_notesController, 'Catatan', forceUpperCase: false),
            ]),
            const SizedBox(height: 16),
            _vehicleSection(),
            const SizedBox(height: 16),
            _datedSection(
              'Hutang',
              Icons.request_quote_outlined,
              _hutangControllers,
              () => _addDatedRow(_hutangControllers),
            ),
            const SizedBox(height: 16),
            _datedSection(
              'Rolling',
              Icons.autorenew_outlined,
              _rollingControllers,
              () => _addDatedRow(_rollingControllers),
            ),
            const SizedBox(height: 16),
            _sectionHeader(
              'Giringan',
              Icons.groups_outlined,
              () => _addGiringan(),
            ),
            ..._giringanControllers.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(child: _textField(item, 'Nama Giringan')),
                    if (_giringanControllers.length > 1)
                      IconButton(
                        onPressed: () =>
                            setState(() => _giringanControllers.removeAt(index)),
                        icon: const Icon(
                          Icons.remove_circle_outline,
                          color: Colors.red,
                        ),
                      ),
                  ],
                ),
              );
            }),
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
          final selectedVehicles = vehicles
              .where((vehicle) => _selectedVehicleIds.contains(vehicle.id))
              .toList();
          return InkWell(
            onTap: _isSaving ? null : () => _openVehiclePicker(vehicles),
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Kendaraan (pilih beberapa)',
                floatingLabelBehavior: FloatingLabelBehavior.always,
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: const Icon(
                  Icons.arrow_drop_down,
                  color: Colors.grey,
                ),
              ),
              child: selectedVehicles.isEmpty
                  ? Text(
                      'Ketuk untuk memilih plat / nama supir...',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 13,
                      ),
                    )
                  : Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: selectedVehicles.map((vehicle) {
                        final driver =
                            vehicle.driverName?.isNotEmpty == true
                            ? vehicle.driverName
                            : null;
                        return InputChip(
                          label: Text(
                            driver != null
                                ? '${vehicle.plateNumber} — $driver'
                                : vehicle.plateNumber,
                            style: const TextStyle(fontSize: 12),
                          ),
                          visualDensity: VisualDensity.compact,
                          onDeleted: () {
                            setState(() {
                              _selectedVehicleIds.remove(vehicle.id);
                            });
                          },
                        );
                      }).toList(),
                    ),
            ),
          );
        },
      ),
    ]);
  }

  Future<void> _openVehiclePicker(List<VehicleOption> vehicles) async {
    final selected = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _VehiclePickerSheet(
        vehicles: vehicles,
        selectedIds: _selectedVehicleIds,
      ),
    );
    if (selected != null && mounted) {
      setState(() {
        _selectedVehicleIds
          ..clear()
          ..addAll(selected);
      });
    }
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

  Widget _numberField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9-]'))],
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );
  }

  Widget _dateField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      onTap: () => _pickDate(controller),
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        suffixIcon: const Icon(Icons.calendar_today, size: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );
  }

  Widget _datedSection(
    String title,
    IconData icon,
    List<({TextEditingController tanggal, TextEditingController amount, TextEditingController notes})> list,
    VoidCallback onAdd,
  ) {
    return _section(title, icon, [
      Align(
        alignment: Alignment.centerRight,
        child: OutlinedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Tambah'),
        ),
      ),
      ...list.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        return Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _dateField(item.tanggal, 'Tanggal')),
                  const SizedBox(width: 8),
                  Expanded(child: _numberField(item.amount, 'Rp')),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _textField(
                      item.notes,
                      'Catatan',
                      forceUpperCase: false,
                    ),
                  ),
                  if (list.length > 1)
                    IconButton(
                      onPressed: () => setState(() => list.removeAt(index)),
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
      }),
    ]);
  }
}

class _VehiclePickerSheet extends StatefulWidget {
  final List<VehicleOption> vehicles;
  final Set<String> selectedIds;

  const _VehiclePickerSheet({
    required this.vehicles,
    required this.selectedIds,
  });

  @override
  State<_VehiclePickerSheet> createState() => _VehiclePickerSheetState();
}

class _VehiclePickerSheetState extends State<_VehiclePickerSheet> {
  late final Set<String> _selected = Set.of(widget.selectedIds);
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.vehicles.where((vehicle) {
      final q = _query.trim().toLowerCase();
      if (q.isEmpty) return true;
      return vehicle.plateNumber.toLowerCase().contains(q) ||
          (vehicle.driverName?.toLowerCase().contains(q) ?? false);
    }).toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Column(
          children: [
            const SizedBox(height: 14),
            const Text(
              'Pilih Kendaraan',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Cari plat / nama supir...',
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'Tidak ditemukan.',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    )
                  : ListView(
                      controller: scrollController,
                      children: filtered.map((vehicle) {
                        final checked = _selected.contains(vehicle.id);
                        return CheckboxListTile(
                          value: checked,
                          title: Text(
                            vehicle.plateNumber,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(vehicle.driverName ?? '-'),
                          controlAffinity: ListTileControlAffinity.leading,
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                _selected.add(vehicle.id);
                              } else {
                                _selected.remove(vehicle.id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, _selected),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4318FF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'OK',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
