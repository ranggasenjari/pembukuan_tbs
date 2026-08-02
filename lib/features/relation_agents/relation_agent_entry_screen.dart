import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../models/relation_agent_model.dart';
import '../../providers/providers.dart';
import '../bons/bon_entry_screen.dart';

class RelationAgentEntryScreen extends ConsumerStatefulWidget {
  final RelationAgentModel? relationAgent;
  const RelationAgentEntryScreen({super.key, this.relationAgent});

  @override
  ConsumerState<RelationAgentEntryScreen> createState() =>
      _RelationAgentEntryScreenState();
}

class _RelationAgentEntryScreenState
    extends ConsumerState<RelationAgentEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _contactController = TextEditingController();
  final List<({TextEditingController name, TextEditingController number})>
  _accountControllers = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final item = widget.relationAgent;
    if (item != null) {
      _nameController.text = item.name;
      _addressController.text = item.address ?? '';
      _contactController.text = item.contact ?? '';
      for (final account in item.accounts) {
        _addAccount(name: account.accountName, number: account.accountNumber);
      }
    }
    if (_accountControllers.isEmpty) _addAccount();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _contactController.dispose();
    for (final item in _accountControllers) {
      item.name.dispose();
      item.number.dispose();
    }
    super.dispose();
  }

  void _addAccount({String name = '', String number = ''}) {
    setState(() {
      _accountControllers.add((
        name: TextEditingController(text: name),
        number: TextEditingController(text: number),
      ));
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final id = widget.relationAgent?.id ?? const Uuid().v4();
      final now = DateTime.now();
      final relationAgent = RelationAgentModel(
        id: id,
        name: _nameController.text.trim().toUpperCase(),
        address: _addressController.text.trim().toUpperCase(),
        contact: _contactController.text.trim(),
        accounts: _accountControllers
            .map(
              (item) => RelationAgentAccount(
                relationAgentId: id,
                accountName: item.name.text.trim().toUpperCase(),
                accountNumber: item.number.text.trim(),
              ),
            )
            .toList(),
        createdAt: widget.relationAgent?.createdAt ?? now,
        updatedAt: now,
      );

      final repo = ref.read(relationAgentRepositoryProvider);
      if (widget.relationAgent == null) {
        await repo.createRelationAgent(relationAgent);
      } else {
        await repo.updateRelationAgent(relationAgent);
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
        title: const Text('Hapus Relasi / Agen'),
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
    if (confirm != true || widget.relationAgent == null) return;
    await ref
        .read(relationAgentRepositoryProvider)
        .deleteRelationAgent(widget.relationAgent!.id);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      appBar: AppBar(
        title: Text(
          widget.relationAgent == null
              ? 'Tambah Relasi / Agen'
              : 'Edit Relasi / Agen',
          style: const TextStyle(
            color: Color(0xFF1B2559),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1B2559)),
        actions: [
          if (widget.relationAgent != null)
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
            _section('Data Relasi / Agen', Icons.groups_outlined, [
              _textField(_nameController, 'Nama Relasi / Agen', required: true),
              const SizedBox(height: 12),
              _textField(_contactController, 'Kontak', forceUpperCase: false),
              const SizedBox(height: 12),
              _textField(_addressController, 'Alamat'),
            ]),
            const SizedBox(height: 16),
            _sectionHeader(
              'Rekening',
              Icons.account_balance_outlined,
              _addAccount,
            ),
            ..._accountControllers.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return _dynamicRow(
                first: _textField(item.name, 'Nama Rekening'),
                second: _textField(
                  item.number,
                  'No Rekening',
                  forceUpperCase: false,
                ),
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
                    'SIMPAN RELASI / AGEN',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ),
    );
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
              Icon(icon, color: Colors.indigo),
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

  Widget _dynamicRow({
    required Widget first,
    required Widget second,
    VoidCallback? onRemove,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(child: first),
          const SizedBox(width: 8),
          Expanded(child: second),
          if (onRemove != null)
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
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
      inputFormatters: forceUpperCase ? [UpperCaseTextFormatter()] : null,
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
