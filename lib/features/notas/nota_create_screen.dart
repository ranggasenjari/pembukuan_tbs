import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../core/enums.dart';
import '../../models/bon_model.dart';
import '../../models/nota_model.dart';
import '../../models/relation_agent_model.dart';
import '../../providers/providers.dart';

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

class NotaCreateScreen extends ConsumerStatefulWidget {
  final NotaModel? notaToEdit;

  const NotaCreateScreen({super.key, this.notaToEdit});

  @override
  ConsumerState<NotaCreateScreen> createState() => _NotaCreateScreenState();
}

class _NotaCreateScreenState extends ConsumerState<NotaCreateScreen> {
  List<BonModel> _availableBons = [];
  List<RelationAgentModel> _relationAgents = [];
  final Set<String> _selectedBonIds = {};
  final Set<String> _initialBonIds = {};
  bool _isLoading = true;

  final _recipientNameController = TextEditingController();
  final _recipientAddressController = TextEditingController();
  String? _selectedRelationAgentId;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        ref.read(bonRepositoryProvider).getBons(),
        ref.read(relationAgentRepositoryProvider).getRelationAgents(),
      ]);
      final bons = results[0] as List<BonModel>;
      final relations = results[1] as List<RelationAgentModel>;

      if (widget.notaToEdit != null) {
        // If editing, we also need to know which bons are currently assigned to this invoice
        final currentBons = await ref
            .read(notaRepositoryProvider)
            .getNotaBons(widget.notaToEdit!.id);
        final currentBonIds = currentBons.map((b) => b.id).toSet();

        setState(() {
          _availableBons = bons.where((b) {
            return b.status == PaymentStatus.belumDibayar ||
                currentBonIds.contains(b.id);
          }).toList();

          _selectedBonIds.addAll(currentBonIds);
          _initialBonIds.addAll(currentBonIds);

          _recipientNameController.text =
              widget.notaToEdit!.recipientName ?? '';
          _recipientAddressController.text =
              widget.notaToEdit!.recipientAddress ?? '';
          _relationAgents = relations;
          _selectedRelationAgentId =
              widget.notaToEdit!.relationAgentId ??
              _matchRelationId(widget.notaToEdit!.recipientName, relations);

          _isLoading = false;
        });
      } else {
        // Create mode: Only show BELUM_DIBAYAR
        setState(() {
          _availableBons = bons
              .where((b) => b.status == PaymentStatus.belumDibayar)
              .toList();
          _relationAgents = relations;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
      setState(() => _isLoading = false);
    }
  }

  double get _totalAmount {
    double sum = 0;
    for (var bon in _availableBons) {
      if (_selectedBonIds.contains(bon.id)) {
        sum += bon.total;
      }
    }
    return sum;
  }

  String? _matchRelationId(String? name, List<RelationAgentModel> relations) {
    final normalized = (name ?? '').trim().toUpperCase();
    if (normalized.isEmpty) return null;
    for (final relation in relations) {
      if (relation.name.toUpperCase() == normalized) return relation.id;
    }
    return null;
  }

  RelationAgentModel? get _selectedRelation {
    for (final relation in _relationAgents) {
      if (relation.id == _selectedRelationAgentId) return relation;
    }
    return null;
  }

  Future<void> _saveNota() async {
    if (_selectedBonIds.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Pilih minimal satu bon.')));
      return;
    }

    if (!_formKey.currentState!.validate()) return;
    final relation = _selectedRelation;
    if (relation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih Relasi / Agen penerima.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final totalAmount = _totalAmount;

      if (widget.notaToEdit != null) {
        // Update
        final updatedNota = NotaModel(
          id: widget.notaToEdit!.id,
          notaNumber: widget.notaToEdit!.notaNumber,
          notaDate: widget.notaToEdit!.notaDate, // Maybe allow changing date?
          totalAmount: totalAmount,
          status: widget.notaToEdit!.status,
          createdAt: widget.notaToEdit!.createdAt,
          updatedAt: DateTime.now(),
          relationAgentId: relation.id,
          recipientName: relation.name,
          recipientAddress: relation.address,
        );

        await ref
            .read(notaRepositoryProvider)
            .updateNota(
              updatedNota,
              _initialBonIds.toList(),
              _selectedBonIds.toList(),
            );
      } else {
        // Create
        final nota = NotaModel(
          id: const Uuid().v4(), // Placeholder
          notaNumber: 'NOTA-${DateTime.now().millisecondsSinceEpoch}',
          notaDate: DateTime.now(),
          totalAmount: totalAmount,
          status: PaymentStatus.tertagih,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          relationAgentId: relation.id,
          recipientName: relation.name,
          recipientAddress: relation.address,
        );

        await ref
            .read(notaRepositoryProvider)
            .createNota(nota, _selectedBonIds.toList());
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _recipientNameController.dispose();
    _recipientAddressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.notaToEdit == null
        ? 'Buat Nota Penjualan Baru'
        : 'Edit Nota Penjualan';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(
            color: Color(0xFF1B2559),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1B2559)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        _buildSectionCard(
                          title: 'Data Relasi/Agen',
                          icon: Icons.person_outline,
                          children: [
                            DropdownButtonFormField<String>(
                              value: _selectedRelationAgentId,
                              isExpanded: true,
                              decoration: _inputDecoration(
                                label: 'Relasi / Agen',
                              ),
                              items: _relationAgents
                                  .map(
                                    (relation) => DropdownMenuItem(
                                      value: relation.id,
                                      child: Text(
                                        relation.name,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) => setState(
                                () => _selectedRelationAgentId = value,
                              ),
                              validator: (v) => v == null || v.isEmpty
                                  ? 'Relasi wajib dipilih'
                                  : null,
                            ),
                            if (_selectedRelation != null) ...[
                              const SizedBox(height: 12),
                              Text(_selectedRelation!.address ?? '-'),
                              const SizedBox(height: 8),
                              ..._selectedRelation!.accounts.map(
                                (account) => Text(
                                  '${account.accountName} - ${account.accountNumber}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildSectionCard(
                          title:
                              'Pilih Bon (${_selectedBonIds.length} item dipilih)',
                          icon: Icons.checklist_outlined,
                          children: [
                            if (_availableBons.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child: Center(
                                  child: Text(
                                    "Tidak ada bon yang tersedia",
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                              )
                            else
                              ..._availableBons.map((bon) {
                                final isSelected = _selectedBonIds.contains(
                                  bon.id,
                                );
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.indigo.withOpacity(0.05)
                                        : Colors.white,
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.indigo.withOpacity(0.3)
                                          : Colors.grey.shade200,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: CheckboxListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    value: isSelected,
                                    activeColor: Colors.indigo,
                                    title: Text(
                                      bon.plateNumber,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isSelected
                                            ? Colors.indigo
                                            : Colors.black87,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${DateFormat('dd/MM/yy').format(bon.bonDate)} - ${NumberFormat.decimalPattern().format(bon.netto2)} Kg\n${bon.factoryName ?? '-'} - ${bon.relationName ?? '-'}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    secondary: Text(
                                      NumberFormat.currency(
                                        locale: 'id_ID',
                                        symbol: 'Rp ',
                                        decimalDigits: 0,
                                      ).format(bon.total),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isSelected
                                            ? Colors.indigo
                                            : Colors.black87,
                                        fontSize: 13,
                                      ),
                                    ),
                                    onChanged: (val) {
                                      setState(() {
                                        if (val == true) {
                                          _selectedBonIds.add(bon.id);
                                        } else {
                                          _selectedBonIds.remove(bon.id);
                                        }
                                      });
                                    },
                                  ),
                                );
                              }),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _buildBottomBar(),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
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
      padding: const EdgeInsets.all(20),
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

  InputDecoration _inputDecoration({required String label, String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.indigo),
      ),
      filled: true,
      fillColor: Colors.grey.shade50,
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Total Estimasi',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  NumberFormat.currency(
                    locale: 'id_ID',
                    symbol: 'Rp ',
                    decimalDigits: 0,
                  ).format(_totalAmount),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
              ],
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _selectedBonIds.isNotEmpty ? _saveNota : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4318FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 5,
              ),
              child: Text(
                widget.notaToEdit == null ? 'GENERATE' : 'UPDATE',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
