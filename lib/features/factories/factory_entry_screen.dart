import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../models/factory_model.dart';
import '../../providers/providers.dart';

class FactoryEntryScreen extends ConsumerStatefulWidget {
  final FactoryModel? factory;
  const FactoryEntryScreen({super.key, this.factory});

  @override
  ConsumerState<FactoryEntryScreen> createState() => _FactoryEntryScreenState();
}

class _FactoryEntryScreenState extends ConsumerState<FactoryEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _address = TextEditingController();
  final List<({TextEditingController name, String mode, TextEditingController amount})> _types = [];
  final List<({TextEditingController name, TextEditingController price, bool isDefault})> _prices = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final factory = widget.factory;
    if (factory != null) {
      _name.text = factory.name;
      _address.text = factory.address ?? '';
      for (final type in factory.spsiTypes) {
        _types.add((name: TextEditingController(text: type.name), mode: type.calculationMode, amount: TextEditingController(text: type.amount.toInt().toString())));
      }
      for (final p in factory.prices) {
        _prices.add((name: TextEditingController(text: p.name), price: TextEditingController(text: p.price.toInt().toString()), isDefault: p.isDefault));
      }
    }
    if (_types.isEmpty) _addType();
    if (_prices.isEmpty) _addPrice();
  }

  void _addType() => setState(() => _types.add((name: TextEditingController(), mode: 'PER_KG', amount: TextEditingController(text: '0'))));
  void _addPrice() => setState(() => _prices.add((name: TextEditingController(), price: TextEditingController(text: '0'), isDefault: false)));

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final id = widget.factory?.id ?? const Uuid().v4();
    final factory = FactoryModel(
      id: id,
      name: _name.text.trim().toUpperCase(),
      address: _address.text.trim().isEmpty ? null : _address.text.trim().toUpperCase(),
      spsiTypes: _types.where((t) => t.name.text.trim().isNotEmpty).map((t) => FactorySpsiType(factoryId: id, name: t.name.text.trim().toUpperCase(), calculationMode: t.mode, amount: double.tryParse(t.amount.text) ?? 0)).toList(),
      prices: _prices.where((p) => p.name.text.trim().isNotEmpty && (double.tryParse(p.price.text) ?? 0) > 0).map((p) => FactoryPrice(factoryId: id, name: p.name.text.trim().toUpperCase(), price: double.tryParse(p.price.text) ?? 0, isDefault: p.isDefault)).toList(),
      createdAt: widget.factory?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
    try {
      if (widget.factory == null) {
        await ref.read(factoryRepositoryProvider).createFactory(factory);
      } else {
        await ref.read(factoryRepositoryProvider).updateFactory(factory);
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      appBar: AppBar(title: Text(widget.factory == null ? 'Tambah Pabrik' : 'Edit Pabrik', style: const TextStyle(color: Color(0xFF1B2559), fontWeight: FontWeight.bold)), backgroundColor: Colors.transparent, elevation: 0, iconTheme: const IconThemeData(color: Color(0xFF1B2559))),
      body: Form(
        key: _formKey,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          TextFormField(controller: _name, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Nama Pabrik'), validator: (v) => v == null || v.trim().isEmpty ? 'Wajib diisi' : null),
          const SizedBox(height: 12),
          TextFormField(controller: _address, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Alamat')),
          const SizedBox(height: 20),
          Row(children: [const Expanded(child: Text('Jenis SPSI', style: TextStyle(fontWeight: FontWeight.bold))), TextButton.icon(onPressed: _addType, icon: const Icon(Icons.add), label: const Text('Tambah'))]),
          ..._types.asMap().entries.map((e) {
            final i = e.key; final t = e.value;
            return Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [
              Expanded(child: TextFormField(controller: t.name, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Nama Jenis'))),
              const SizedBox(width: 8),
              SizedBox(width: 110, child: DropdownButtonFormField<String>(value: t.mode, items: const [DropdownMenuItem(value: 'PER_KG', child: Text('Per/Kg')), DropdownMenuItem(value: 'FIX', child: Text('Fix'))], onChanged: (v) => setState(() => _types[i] = (name: t.name, mode: v ?? 'PER_KG', amount: t.amount)))),
              const SizedBox(width: 8),
              Expanded(child: TextFormField(controller: t.amount, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: const InputDecoration(labelText: 'Nominal'))),
              IconButton(onPressed: _types.length <= 1 ? null : () => setState(() => _types.removeAt(i)), icon: const Icon(Icons.remove_circle_outline, color: Colors.red)),
            ]));
          }),
          const SizedBox(height: 20),
          Row(children: [const Expanded(child: Text('Harga Hari Ini', style: TextStyle(fontWeight: FontWeight.bold))), TextButton.icon(onPressed: _addPrice, icon: const Icon(Icons.add), label: const Text('Tambah'))]),
          ..._prices.asMap().entries.map((e) {
            final i = e.key; final p = e.value;
            return Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [
              Expanded(child: TextFormField(controller: p.name, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Jenis'))),
              const SizedBox(width: 8),
              Expanded(child: TextFormField(controller: p.price, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: const InputDecoration(labelText: 'Harga'))),
              const SizedBox(width: 4),
              Column(children: [
                const Text('Default', style: TextStyle(fontSize: 10)),
                Checkbox(value: p.isDefault, onChanged: (v) => setState(() => _prices[i] = (name: p.name, price: p.price, isDefault: v ?? false))),
              ]),
              IconButton(onPressed: _prices.length <= 1 ? null : () => setState(() => _prices.removeAt(i)), icon: const Icon(Icons.remove_circle_outline, color: Colors.red)),
            ]));
          }),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Menyimpan...' : 'Simpan')),
        ]),
      ),
    );
  }
}
