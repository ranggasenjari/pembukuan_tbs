import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../core/enums.dart';
import '../../core/widgets/zoomable_image_preview.dart';
import '../../models/bon_model.dart';
import '../../models/nota_model.dart';
import '../../models/payment_model.dart';
import '../../models/factory_model.dart';
import '../../models/relation_agent_model.dart';
import '../../models/sub_nota_model.dart';
import '../../providers/providers.dart';
import '../notas/nota_detail_screen.dart';

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

class BonEntryScreen extends ConsumerStatefulWidget {
  final BonModel? bon;
  final File? initialImage;
  const BonEntryScreen({super.key, this.bon, this.initialImage});

  @override
  ConsumerState<BonEntryScreen> createState() => _BonEntryScreenState();
}

class _BonEntryScreenState extends ConsumerState<BonEntryScreen> {
  static const String _ocrCancel = '__cancel__';
  static const String _ocrDefault = '__default__';
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  XFile? _imageFile;
  Uint8List? _imageBytes;
  String? _ocrImageUrl;
  bool _isProcessing = false;
  bool _dataLoaded = false;
  List<RelationAgentModel> _relationAgents = [];
  List<FactoryModel> _factories = [];
  String? _selectedRelationAgentId;
  String? _selectedFactoryId;
  String? _selectedSpsiTypeId;

  // Controllers
  final _ticketNumberController = TextEditingController();
  final _dateController = TextEditingController();
  final _plateNumberController = TextEditingController();
  final _driverNameController = TextEditingController();
  final _relationNameController = TextEditingController();
  final _fruitOriginController = TextEditingController();
  final _notesController = TextEditingController();
  final _netto1Controller = TextEditingController();
  final _netto2Controller = TextEditingController();

  final _biayaBongkarController = TextEditingController();
  final _bpColtController = TextEditingController();
  final _uangMinumController = TextEditingController();
  final _pphController = TextEditingController();

  final _priceController = TextEditingController();
  final _dpController = TextEditingController();
  final List<({TextEditingController label, TextEditingController amount})>
  _deductionControllers = [];

  List<SubNotaModel> _subNotas = [];
  bool _subNotasLoading = true;

  void _setTextIfDifferent(TextEditingController controller, String value) {
    if (controller.text != value) {
      controller.text = value;
    }
  }

  // Calculated
  double get _netto1 =>
      (double.tryParse(_netto1Controller.text) ?? 0).roundToDouble();
  double get _netto2 =>
      (double.tryParse(_netto2Controller.text) ?? 0).roundToDouble();
  double get _price =>
      (double.tryParse(_priceController.text) ?? 0).roundToDouble();
  double get _dp => (double.tryParse(_dpController.text) ?? 0).roundToDouble();
  double get _potonganLain => _deductionControllers.fold(
    0.0,
    (sum, c) => sum + (double.tryParse(c.amount.text) ?? 0),
  );

  double get _biayaBongkarRate =>
      double.tryParse(_biayaBongkarController.text) ?? 0;
  FactorySpsiType? get _selectedSpsiType {
    for (final factory in _factories) {
      for (final type in factory.spsiTypes) {
        if (type.id == _selectedSpsiTypeId) return type;
      }
    }
    return null;
  }

  double get _spsiRate => _selectedFactoryId == null
      ? _biayaBongkarRate
      : (_selectedSpsiType?.amount ?? 0);
  String get _spsiMode => _selectedSpsiType?.calculationMode ?? 'PER_KG';
  double get _totalBiayaBongkar =>
      _spsiMode == 'FIX' ? _spsiRate : _spsiRate * _netto1;
  double get _bpColt => double.tryParse(_bpColtController.text) ?? 0;
  double get _uangMinum => double.tryParse(_uangMinumController.text) ?? 0;
  double get _pph => double.tryParse(_pphController.text) ?? 0;

  double get _subtotal => _price * _netto2;

  double get _total =>
      (_price * _netto2) -
      (_dp + _totalBiayaBongkar + _bpColt + _pph + _uangMinum + _potonganLain);

  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.bon != null) {
      final b = widget.bon!;
      _ticketNumberController.text = b.ticketNumber ?? '';
      _selectedDate = b.bonDate;
      _dateController.text = DateFormat('yyyy-MM-dd').format(b.bonDate);
      _plateNumberController.text = b.plateNumber;
      _driverNameController.text = b.driverName ?? '';
      _relationNameController.text = b.relationName ?? '';
      _selectedRelationAgentId = b.relationAgentId;
      _selectedFactoryId = b.factoryId;
      _selectedSpsiTypeId = b.factorySpsiTypeId;
      _fruitOriginController.text = b.fruitOrigin ?? '';
      _notesController.text = b.notes ?? '';
      _netto1Controller.text = b.netto1.toInt().toString();
      _netto2Controller.text = b.netto2.toInt().toString();
      _priceController.text = b.price.toInt().toString();
      _dpController.text = b.dp.toInt().toString();

      // Initialize deductions
      for (var d in b.deductions) {
        _addDeductionController(
          label: d.label,
          amount: d.amount.toInt().toString(),
        );
      }
      if (b.deductions.isEmpty) {
        _addDeductionController();
      }

      _biayaBongkarController.text =
          (b.spsiRate > 0 ? b.spsiRate : b.biayaBongkar).toInt().toString();
      _bpColtController.text = b.bpColt.toInt().toString();
      _uangMinumController.text = b.uangMinum.toInt().toString();
      _pphController.text = b.pph.toInt().toString();

      if (b.status == PaymentStatus.belumDibayar) {
        if (b.bpColt == 0) _bpColtController.text = '100000';
        if (b.uangMinum == 0) _uangMinumController.text = '10000';
      }
    } else {
      _dateController.text = DateFormat('yyyy-MM-dd').format(_selectedDate);
      _netto1Controller.text = '0';
      _netto2Controller.text = '0';
      _priceController.text = '0';
      _dpController.text = '0';
      _addDeductionController();

      _biayaBongkarController.text = '12';
      _bpColtController.text = '100000';
      _uangMinumController.text = '10000';
      _pphController.text = '0';
      _fetchLatestPrice();
    }
    _masterDataFuture = _loadMasterData();

    if (widget.bon != null) _loadSubNotas();

    _ticketNumberController.addListener(
      _toUpperCaseListener(_ticketNumberController),
    );
    _plateNumberController.addListener(
      _toUpperCaseListener(_plateNumberController),
    );
    _driverNameController.addListener(
      _toUpperCaseListener(_driverNameController),
    );
    _relationNameController.addListener(
      _toUpperCaseListener(_relationNameController),
    );
    _fruitOriginController.addListener(
      _toUpperCaseListener(_fruitOriginController),
    );

    _netto1Controller.addListener(_recalcPPh);
    _netto2Controller.addListener(_recalcPPh);
    _priceController.addListener(_recalcPPh);

    _dpController.addListener(_updateCalc);
    _pphController.addListener(_updateCalc);
    _biayaBongkarController.addListener(_updateCalc);

    if (widget.initialImage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleInitialImage(widget.initialImage!);
      });
    }
  }

Future<void> _handleInitialImage(File file) async {
    if (_masterDataFuture != null) {
      await _masterDataFuture;
    }
    final bytes = await file.readAsBytes();
    setState(() {
      _imageFile = XFile(file.path);
      _imageBytes = bytes;
      _ocrImageUrl = null;
    });
    final factoryId = await _promptOcrFactorySelection();
    if (!mounted) return;
    if (factoryId == _ocrCancel) return;
    await _performOCR(
      bytes,
      file.path.split('/').last,
      factoryId: factoryId,
    );
  }

  void _recalcPPh() {
    if (!_isReadOnly) {
      final netto = _netto2;
      final price = _price;
      // Rule khusus: Pabrik Pengurus → BP, PPh & Uang Minum = 0
      if (_selectedFactoryId == '376b98eb-0eb4-4a4e-84aa-902429f85669') {
        _setTextIfDifferent(_bpColtController, '0');
        _setTextIfDifferent(_pphController, '0');
        _setTextIfDifferent(_uangMinumController, '0');
      } else if (_selectedFactoryId == 'a536e3c0-7ea0-4003-9df0-c38721a9439b') {
        // Rule khusus: PT. AWAN ALAM ANUGRA → PPh & Uang Minum = 0
        _setTextIfDifferent(_pphController, '0');
        _setTextIfDifferent(_uangMinumController, '0');
      } else {
        // PPh = 0.25% * (Harga * Netto2)
        _setTextIfDifferent(
          _pphController,
          (0.0025 * (price * netto)).toInt().toString(),
        );
        // Update uang minum berdasarkan netto2
        final uangMinumValue = netto > 7000 ? '20000' : '10000';
        _setTextIfDifferent(_uangMinumController, uangMinumValue);
      }
    }
    _updateCalc();
  }

  VoidCallback _toUpperCaseListener(TextEditingController controller) {
    return () {
      final text = controller.text;
      if (text != text.toUpperCase()) {
        controller.value = controller.value.copyWith(
          text: text.toUpperCase(),
          selection: controller.selection,
        );
      }
    };
  }

  void _updateCalc() {
    setState(() {});
  }

  Future<void> _fetchLatestPrice() async {
    // Hanya untuk bon baru
    if (widget.bon != null) return;
    if (_selectedFactoryId != null) {
      final factory = _factories
          .where((f) => f.id == _selectedFactoryId)
          .firstOrNull;
      final defaultPrice = factory?.prices
          .where((p) => p.isDefault)
          .firstOrNull;
      if (defaultPrice != null && defaultPrice.price > 0 && mounted) {
        _priceController.text = defaultPrice.price.toInt().toString();
        return;
      }
    }
    try {
      final price = await ref.read(bonRepositoryProvider).getLatestPrice();
      if (price > 0 && mounted) {
        setState(() {
          _priceController.text = price.toInt().toString();
        });
      }
    } catch (_) {}
  }

  Future<void>? _masterDataFuture;

  Future<void> _loadMasterData() async {
    try {
      final results = await Future.wait([
        ref.read(relationAgentRepositoryProvider).getRelationAgents(),
        ref.read(factoryRepositoryProvider).getFactories(),
      ]);
      if (!mounted) return;
      setState(() {
        _dataLoaded = true;
        _relationAgents = results[0] as List<RelationAgentModel>;
        _factories = results[1] as List<FactoryModel>;
        _selectedRelationAgentId ??= _matchRelationIdByName();
        if (_selectedRelationAgentId != null &&
            !_relationAgents.any(
              (item) => item.id == _selectedRelationAgentId,
            )) {
          _selectedRelationAgentId = null;
        }
      });
    } catch (_) {
      if (mounted) setState(() => _dataLoaded = true);
    }
  }

  String? _matchRelationIdByName() {
    final current = _relationNameController.text.trim().toUpperCase();
    if (current.isEmpty) return null;
    for (final item in _relationAgents) {
      if (item.name.toUpperCase() == current) return item.id;
    }
    return null;
  }

  String? _matchFactoryIdByName(String factoryName) {
    final current = factoryName.trim().toUpperCase();
    if (current.isEmpty) return null;
    for (final item in _factories) {
      if (item.name.toUpperCase() == current) return item.id;
    }
    return null;
  }

  RelationAgentModel? get _selectedRelationAgent {
    for (final item in _relationAgents) {
      if (item.id == _selectedRelationAgentId) return item;
    }
    return null;
  }

  void _selectFactory(String? factoryId) {
    setState(() {
      _selectedFactoryId = factoryId;
      _selectedSpsiTypeId = null;
      if (factoryId == null) {
        _setTextIfDifferent(_biayaBongkarController, '12');
      } else {
        _setTextIfDifferent(_biayaBongkarController, '0');
        // Harga default hanya untuk bon baru
        if (widget.bon == null) {
          final factory = _factories
              .where((f) => f.id == factoryId)
              .firstOrNull;
          final defaultPrice = factory?.prices
              .where((p) => p.isDefault)
              .firstOrNull;
          if (defaultPrice != null && defaultPrice.price > 0) {
            _setTextIfDifferent(
              _priceController,
              defaultPrice.price.toInt().toString(),
            );
          }
        }
        // Auto-pilih SPSI default pabrik (tabel tidak punya flag default → ambil pertama)
        final factory = _factories
            .where((f) => f.id == factoryId)
            .firstOrNull;
        final spsiList = factory?.spsiTypes ?? const [];
        if (spsiList.isNotEmpty) {
          final first = spsiList.first;
          _selectedSpsiTypeId = first.id;
          _setTextIfDifferent(
            _biayaBongkarController,
            first.amount.toInt().toString(),
          );
        }
      }
    });
    _recalcPPh();
  }

  void _selectSpsiType(String? spsiTypeId) {
    FactorySpsiType? selected;
    for (final factory in _factories) {
      for (final type in factory.spsiTypes) {
        if (type.id == spsiTypeId) {
          selected = type;
          break;
        }
      }
      if (selected != null) break;
    }
    setState(() {
      _selectedSpsiTypeId = spsiTypeId;
      if (selected != null) {
        _setTextIfDifferent(
          _biayaBongkarController,
          selected.amount.toInt().toString(),
        );
      }
    });
  }

  void _addDeductionController({String label = '', String amount = '0'}) {
    final labelCtrl = TextEditingController(text: label);
    final amountCtrl = TextEditingController(text: amount);

    labelCtrl.addListener(_updateCalc);
    amountCtrl.addListener(_updateCalc);

    setState(() {
      _deductionControllers.add((label: labelCtrl, amount: amountCtrl));
    });
  }

  void _removeDeductionController(int index) {
    setState(() {
      final controllers = _deductionControllers.removeAt(index);
      controllers.label.dispose();
      controllers.amount.dispose();
    });
  }

  @override
  void dispose() {
    for (var c in _deductionControllers) {
      c.label.dispose();
      c.amount.dispose();
    }
    _ticketNumberController.dispose();
    _dateController.dispose();
    _plateNumberController.dispose();
    _driverNameController.dispose();
    _relationNameController.dispose();
    _fruitOriginController.dispose();
    _notesController.dispose();
    _netto1Controller.dispose();
    _netto2Controller.dispose();
    _priceController.dispose();
    _dpController.dispose();
    _biayaBongkarController.dispose();
    _bpColtController.dispose();
    _uangMinumController.dispose();
    _pphController.dispose();
    super.dispose();
  }

Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source);
    if (picked != null) {
      if (_masterDataFuture != null) {
        await _masterDataFuture;
      }
      final bytes = await picked.readAsBytes();
      setState(() {
        _imageFile = picked;
        _imageBytes = bytes;
        _ocrImageUrl = null;
      });
      final factoryId = await _promptOcrFactorySelection();
      if (!mounted) return;
      if (factoryId == _ocrCancel) return;
      // Perform OCR sesuai pengaturan pabrik yang dipilih
      await _performOCR(bytes, picked.name, factoryId: factoryId);
    }
  }

  Future<String> _promptOcrFactorySelection() async {
    // Deklarasi di luar builder agar pilihan user tidak hilang saat setDialogState rebuild.
    String? selected = _selectedFactoryId ?? _ocrDefault;
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Pilih Pabrik'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pilih pabrik agar OCR menggunakan prompt & schema '
                  'khususnya (bila tersedia).',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selected,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Pabrik',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: _ocrDefault,
                      child: Text('(Default)', overflow: TextOverflow.ellipsis),
                    ),
                    ..._factories.map(
                      (factory) => DropdownMenuItem<String>(
                        value: factory.id,
                        child: Text(
                          factory.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => selected = value),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, _ocrCancel),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, selected),
                child: const Text('Proses OCR'),
              ),
            ],
          );
        },
      ),
    );
    return result ?? _ocrCancel;
  }

  Future<void> _performOCR(
    Uint8List bytes,
    String fileName, {
    String? factoryId,
  }) async {
    setState(() => _isProcessing = true);

    try {
      final settings = await ref
          .read(ocrSettingsRepositoryProvider)
          .getSettings();
      final effectiveFactoryId = (factoryId == null ||
              factoryId.isEmpty ||
              factoryId == _ocrDefault)
          ? null
          : factoryId;
      final factory = effectiveFactoryId == null
          ? null
          : _factories
                .where((f) => f.id == effectiveFactoryId)
                .firstOrNull;
      final factorySettings =
          effectiveFactoryId == null
              ? null
              : settings.factorySettings[effectiveFactoryId];
      final result = await ref.read(ocrServiceProvider).processBonImage(
            bytes: bytes,
            fileName: fileName,
            settings: settings,
            factoryName: factory?.name,
            factorySettings: factorySettings,
          );

      _applyOcrData(
        result.data,
        imageUrl: result.imageUrl,
        forcedFactoryId: effectiveFactoryId,
      );
      if (effectiveFactoryId != null) _recalcPPh();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data bon berhasil terbaca'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchLatestPrice();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Data bon gagal terbaca: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _applyOcrData(
    Map<String, dynamic> bonData, {
    String? imageUrl,
    String? forcedFactoryId,
  }) {
    setState(() {
      if (imageUrl != null && imageUrl.isNotEmpty) {
        _ocrImageUrl = imageUrl;
      }
      if (bonData['ticket_number'] != null) {
        _ticketNumberController.text = bonData['ticket_number'].toString();
      }
      if (bonData['bon_date'] != null) {
        try {
          final date = DateTime.parse(bonData['bon_date'].toString());
          _selectedDate = date;
          _dateController.text = DateFormat('yyyy-MM-dd').format(date);
        } catch (_) {}
      }
      if (bonData['plate_number'] != null) {
        _plateNumberController.text = bonData['plate_number'].toString();
      }
      if (bonData['driver_name'] != null) {
        _driverNameController.text = bonData['driver_name'].toString();
      }
      if (bonData['relation_name'] != null) {
        _relationNameController.text = bonData['relation_name'].toString();
      }
      if (bonData['fruit_origin'] != null) {
        _fruitOriginController.text = bonData['fruit_origin'].toString();
      }
      if (bonData['notes'] != null) {
        _notesController.text = bonData['notes'].toString();
      }
      if (bonData['netto_1'] != null) {
        _netto1Controller.text = bonData['netto_1'].toString();
      }
      if (bonData['netto_2'] != null) {
        _netto2Controller.text = bonData['netto_2'].toString();
      }
      _selectedRelationAgentId = _matchRelationIdByName();
      _selectedSpsiTypeId = null;
    });
    // Pabrik hasil OCR: terapkan ke form (field pabrik, SPSI, harga default).
    if (forcedFactoryId != null && forcedFactoryId.isNotEmpty) {
      _selectFactory(forcedFactoryId);
    } else if (bonData['factory_name'] != null) {
      final matched = _matchFactoryIdByName(
        bonData['factory_name'].toString(),
      );
      if (matched != null) _selectFactory(matched);
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.indigo),
                title: const Text('Ambil Foto Kamera'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.indigo),
                title: const Text('Pilih dari Galeri'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<BonModel?> _performSave() async {
    if (!_formKey.currentState!.validate()) return null;

    final bon = BonModel(
      id: widget.bon?.id ?? const Uuid().v4(),
      ticketNumber: _ticketNumberController.text,
      bonDate: _selectedDate,
      plateNumber: _plateNumberController.text,
      driverName: _driverNameController.text,
      relationName: _relationNameController.text,
      relationAgentId: _selectedRelationAgentId,
      factoryId: _selectedFactoryId,
      factoryName: null,
      factorySpsiTypeId: _selectedSpsiTypeId,
      spsiTypeName: _selectedSpsiType?.name,
      spsiCalculationMode: _spsiMode,
      spsiRate: _spsiRate,
      spsiAmount: _totalBiayaBongkar,
      fruitOrigin: _fruitOriginController.text,
      notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      netto1: _netto1,
      netto2: _netto2,
      price: _price,
      dp: _dp,
      biayaBongkar: _biayaBongkarRate,
      bpColt: _bpColt,
      pph: _pph,
      uangMinum: _uangMinum,
      deductions: _deductionControllers
          .where((c) => c.label.text.isNotEmpty || c.amount.text != '0')
          .map(
            (c) => BonDeduction(
              label: c.label.text,
              amount: int.tryParse(c.amount.text) ?? 0,
            ),
          )
          .toList(),
      total: _total,
      status: widget.bon?.status ?? PaymentStatus.belumDibayar,
      imageUrl: widget.bon?.imageUrl,
      createdAt: widget.bon?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    if (widget.bon == null) {
      return await ref
          .read(bonRepositoryProvider)
          .createBon(
            bon,
            _imageBytes,
            _imageFile?.name,
            existingImageUrl: _ocrImageUrl,
          );
    } else {
      await ref.read(bonRepositoryProvider).updateBon(bon);
      return (await ref.read(bonRepositoryProvider).getBons()).firstWhere(
        (b) => b.id == bon.id,
      );
    }
  }

  Future<void> _save() async {
    setState(() => _isProcessing = true);
    try {
      final savedBon = await _performSave();
      if (savedBon != null && mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving: $e')));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _saveAndShare() async {
    if (!_formKey.currentState!.validate()) return;
    final relation = _selectedRelationAgent;
    if (relation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih Relasi / Agen terlebih dahulu.')),
      );
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final savedBon = await _performSave();
      if (savedBon == null) return;

      // Create an automatic Nota for this Bon
      final nota = NotaModel(
        id: const Uuid().v4(),
        notaNumber: 'NOTA-${DateTime.now().millisecondsSinceEpoch}',
        notaDate: DateTime.now(),
        totalAmount: savedBon.total,
        status: PaymentStatus.tertagih,
        relationAgentId: relation.id,
        recipientName: relation.name,
        recipientAddress: relation.address,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final notaRepo = ref.read(notaRepositoryProvider);
      final createdNota = await notaRepo.createNota(nota, [savedBon.id]);

      // Generate and Share PDF
      final pdfService = ref.read(pdfServiceProvider);
      final pdfBytes = await pdfService.generateThermalNota(
        createdNota,
        savedBon,
      );

      final directory = await getTemporaryDirectory();
      final filename = pdfService.getNotaFilename(createdNota, [savedBon]);
      final file = File('${directory.path}/$filename');
      await file.writeAsBytes(pdfBytes);

      if (mounted) {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            text: pdfService.getNotaShareCaption(createdNota, [savedBon]),
          ),
        );

        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error Save & Share: $e')));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _deleteBon() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Bon'),
        content: const Text(
          'Yakin ingin menghapus data bon ini secara permanen?',
        ),
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

    if (confirm == true) {
      setState(() => _isProcessing = true);
      try {
        await ref.read(bonRepositoryProvider).deleteBon(widget.bon!.id);
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
          setState(() => _isProcessing = false);
        }
      }
    }
  }

  bool get _isReadOnly =>
      widget.bon != null && widget.bon!.status == PaymentStatus.lunas;

  Future<void> _loadSubNotas() async {
    if (widget.bon == null) return;
    try {
      final list = await ref
          .read(subNotaRepositoryProvider)
          .getByBon(widget.bon!.id);
      if (mounted) {
        setState(() {
          _subNotas = list;
          _subNotasLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _subNotasLoading = false);
    }
  }

  Future<void> _showAddSubNotaDialog() async {
    final bon = widget.bon!;
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final currencyFmt = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final price = int.tryParse(priceCtrl.text) ?? 0;
          final total = bon.netto2.toInt() * price;
          return AlertDialog(
            title: const Text('Tambah Sub Nota'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameCtrl,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Nama',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Wajib diisi'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: priceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Harga (Rp/kg)',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                      validator: (v) {
                        final value = int.tryParse(v ?? '');
                        if (value == null || value <= 0) {
                          return 'Harus lebih dari 0';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Catatan (opsional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Netto 2: ${bon.netto2.toInt()} kg',
                            style: const TextStyle(fontSize: 13),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Total (murni, tanpa potongan): '
                            '${currencyFmt.format(total)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.indigo,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  try {
                    await ref.read(subNotaRepositoryProvider).create(
                      bonId: bon.id,
                      name: nameCtrl.text.trim(),
                      pricePerKg: int.tryParse(priceCtrl.text) ?? 0,
                      netto2: bon.netto2.toInt(),
                      notes: notesCtrl.text.trim(),
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    await _loadSubNotas();
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('Gagal menyimpan: $e')),
                      );
                    }
                  }
                },
                child: const Text('Simpan'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteSubNota(SubNotaModel sub) async {
    final currencyFmt = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Sub Nota'),
        content: Text(
          'Hapus ${sub.name} '
          '(${currencyFmt.format(sub.amount)})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(subNotaRepositoryProvider).delete(sub.id);
      await _loadSubNotas();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal: $e')));
      }
    }
  }

  Widget _buildSubNotaSection() {
    final currencyFmt = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _buildSectionCard(
        title: 'Sub Nota',
        icon: Icons.handshake_outlined,
        children: [
          if (_subNotasLoading)
            const LinearProgressIndicator()
          else if (_subNotas.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Belum ada sub nota.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            )
          else ...[
            ..._subNotas.map(
              (sub) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  sub.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                subtitle: Text(
                  '${sub.netto2} kg x Rp '
                  '${NumberFormat.decimalPattern().format(sub.pricePerKg)}'
                  '${sub.notes != null && sub.notes!.isNotEmpty ? ' - ${sub.notes}' : ''}',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      currencyFmt.format(sub.amount),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo,
                        fontSize: 13,
                      ),
                    ),
                    if (!_isReadOnly) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        onPressed: () => _deleteSubNota(sub),
                        icon: Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: Colors.red.shade300,
                        ),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const Divider(height: 8),
          ],
          if (!_isReadOnly)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _showAddSubNotaDialog,
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: const Text('Tambah Sub Nota'),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      appBar: AppBar(
        title: Text(
          widget.bon == null ? 'Input Bon Baru' : 'Edit Slip Timbangan',
          style: const TextStyle(
            color: Color(0xFF1B2559),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1B2559)),
        actions: [
          if (widget.bon != null && !_isReadOnly)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: _isProcessing ? null : _deleteBon,
              tooltip: 'Hapus Bon',
            ),
        ],
      ),
      body: _dataLoaded
          ? Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSectionCard(
                          title: 'Ambil Foto Bon',
                          icon: Icons.camera_alt_outlined,
                          children: [_buildImagePicker()],
                        ),
                        const SizedBox(height: 16),
                        if (_isReadOnly) _buildReadOnlyWarning(),
                        _buildRelatedDocuments(),
                        if (widget.bon != null) _buildSubNotaSection(),
                        _buildSectionCard(
                          title: 'Info Kendaraan & Supir',
                          icon: Icons.local_shipping_outlined,
                          children: [
                            _buildTextField(
                              controller: _plateNumberController,
                              label: 'Nomor Polisi (BK)',
                              icon: Icons.confirmation_number_outlined,
                              validator: (v) =>
                                  v!.isEmpty ? 'Wajib diisi' : null,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _driverNameController,
                              label: 'Nama Supir',
                              icon: Icons.person_outline,
                            ),
                            const SizedBox(height: 16),
                            _buildRelationDropdown(),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(child: _buildFactoryDropdown()),
                                const SizedBox(width: 16),
                                Expanded(child: _buildSpsiTypeDropdown()),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _fruitOriginController,
                              label: 'Asal Buah',
                              icon: Icons.location_on_outlined,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _notesController,
                              label: 'Catatan',
                              icon: Icons.notes_outlined,
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),
                        _buildSectionCard(
                          title: 'Data Timbangan (Tiket)',
                          icon: Icons.scale,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildTextField(
                                    controller: _ticketNumberController,
                                    label: 'No. Tiket / Bon',
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _dateController,
                                    readOnly: true,
                                    decoration: _inputDecoration(
                                      label: 'Tanggal',
                                      icon: Icons.calendar_today,
                                    ),
                                    onTap: _isReadOnly
                                        ? null
                                        : () async {
                                            final picked = await showDatePicker(
                                              context: context,
                                              initialDate: _selectedDate,
                                              firstDate: DateTime(2000),
                                              lastDate: DateTime(2100),
                                            );
                                            if (picked != null) {
                                              setState(() {
                                                _selectedDate = picked;
                                                _dateController.text =
                                                    DateFormat(
                                                      'yyyy-MM-dd',
                                                    ).format(picked);
                                              });
                                            }
                                          },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildTextField(
                                    controller: _netto1Controller,
                                    label: 'Netto 1 (Bongkar)',
                                    isNumber: true,
                                    suffixText: 'kg',
                                    validator: (v) =>
                                        v!.isEmpty ? 'Wajib' : null,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildTextField(
                                    controller: _netto2Controller,
                                    label: 'Netto 2 (Bayar)',
                                    isNumber: true,
                                    suffixText: 'kg',
                                    validator: (v) =>
                                        v!.isEmpty ? 'Wajib' : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),

                        const SizedBox(height: 16),
                        _buildSectionCard(
                          title: 'Kalkulasi Keuangan',
                          icon: Icons.monetization_on_outlined,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildTextField(
                                    controller: _priceController,
                                    label: 'Harga / kg',
                                    isNumber: true,
                                    prefixText: 'Rp',
                                    validator: (v) =>
                                        v!.isEmpty ? 'Wajib' : null,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildTextField(
                                    controller: _dpController,
                                    label: 'DP / Panjar',
                                    isNumber: true,
                                    prefixText: 'Rp',
                                  ),
                                ),
                              ],
                            ),
                            if (!_isReadOnly) ...[
                              const SizedBox(height: 12),
                              _buildFactoryPricePills(),
                            ],
                            const SizedBox(height: 24),
                            _buildCalcRow(
                              'Subtotal (Netto 2 x Harga)',
                              _subtotal,
                              isSubTotal: true,
                            ),
                            const Divider(height: 24),

                            const Text(
                              'Potongan & Biaya',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.indigo,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildTextField(
                                    controller: _biayaBongkarController,
                                    label: _spsiMode == 'FIX'
                                        ? 'Bongkar / SPSI (Fix)'
                                        : 'Bongkar (Rp/Kg)',
                                    isNumber: true,
                                    hint: '12',
                                    readOnlyOverride:
                                        _selectedFactoryId != null ||
                                        _isReadOnly,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildTextField(
                                    controller: _bpColtController,
                                    label: 'BP Colt',
                                    isNumber: true,
                                    hint: '100.000',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildTextField(
                                    controller: _pphController,
                                    label: 'PPh 0.25%',
                                    isNumber: true,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildTextField(
                                    controller: _uangMinumController,
                                    label: 'Uang Minum',
                                    isNumber: true,
                                    hint: '10.000',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Potongan Lain-lain',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Colors.indigo,
                                  ),
                                ),
                                if (!_isReadOnly)
                                  IconButton(
                                    onPressed: _addDeductionController,
                                    icon: const Icon(
                                      Icons.add_circle_outline,
                                      color: Colors.indigo,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _deductionControllers.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final ctrls = _deductionControllers[index];
                                return Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: _buildTextField(
                                        controller: ctrls.label,
                                        label: 'Nama Potongan',
                                        forceUpperCase: false,
                                        // hint: 'Contoh: Roling',
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      flex: 1,
                                      child: _buildTextField(
                                        controller: ctrls.amount,
                                        label: 'Besaran',
                                        isNumber: true,
                                      ),
                                    ),
                                    if (!_isReadOnly &&
                                        _deductionControllers.length > 1)
                                      IconButton(
                                        onPressed: () =>
                                            _removeDeductionController(index),
                                        icon: const Icon(
                                          Icons.remove_circle_outline,
                                          color: Colors.red,
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),

                            const Divider(height: 32, thickness: 1.5),
                            _buildCalcRow(
                              'TOTAL DIBAYAR',
                              _total,
                              isTotal: true,
                            ),
                          ],
                        ),

                        const SizedBox(height: 32),
                        if (!_isReadOnly)
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: SizedBox(
                                  height: 54,
                                  child: ElevatedButton(
                                    onPressed: _isProcessing ? null : _save,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: const Color(0xFF4318FF),
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        side: const BorderSide(
                                          color: Color(0xFF4318FF),
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                    child: _isProcessing
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Color(0xFF4318FF),
                                            ),
                                          )
                                        : const Text(
                                            'SIMPAN',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 3,
                                child: SizedBox(
                                  height: 54,
                                  child: ElevatedButton.icon(
                                    onPressed: _isProcessing
                                        ? null
                                        : _saveAndShare,
                                    icon: const Icon(Icons.share, size: 18),
                                    label: _isProcessing
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text(
                                            'SIMPAN & SHARE',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF4318FF),
                                      foregroundColor: Colors.white,
                                      elevation: 5,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      shadowColor: const Color(
                                        0xFF4318FF,
                                      ).withOpacity(0.4),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
                if (_isProcessing)
                  Container(
                    color: Colors.black.withOpacity(0.3),
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Color(0xFF4318FF)),
                          SizedBox(height: 16),
                          Text(
                            'Membaca data bon...',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildFactoryPricePills() {
    if (_selectedFactoryId == null) return const SizedBox.shrink();
    final factory = _factories
        .where((f) => f.id == _selectedFactoryId)
        .firstOrNull;
    final prices = factory?.prices ?? const <FactoryPrice>[];
    if (prices.isEmpty) return const SizedBox.shrink();
    final currencyFmt = NumberFormat.decimalPattern('id_ID');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Jenis Harga Pabrik',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: prices.map((p) {
            final active = _price.toInt() == p.price.toInt();
            return InkWell(
              onTap: () {
                setState(() {
                  _priceController.text = p.price.toInt().toString();
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: active ? const Color(0xFF4318FF) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: active
                        ? const Color(0xFF4318FF)
                        : Colors.grey.shade300,
                  ),
                ),
                child: Text(
                  '${p.name}: ${currencyFmt.format(p.price.toInt())}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: active ? Colors.white : const Color(0xFF1B2559),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
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

  Widget _buildRelationDropdown() {
    return FormField<String>(
      key: ValueKey('relation-form-$_selectedRelationAgentId'),
      initialValue: _selectedRelationAgentId,
      validator: (value) =>
          value == null || value.isEmpty ? 'Wajib diisi' : null,
      builder: (state) {
        final selectedAgent = _relationAgents
            .where((a) => a.id == _selectedRelationAgentId)
            .firstOrNull;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              readOnly: true,
              onTap: _isReadOnly ? null : _showRelationSearchBottomSheet,
              controller: TextEditingController(text: selectedAgent?.name ?? ''),
              decoration: _inputDecoration(
                label: 'Relasi / Agen',
                icon: Icons.business_outlined,
                hint: 'Ketik untuk mencari...',
              ),
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF1B2559),
              ),
            ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 12),
                child: Text(
                  state.errorText ?? '',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red.shade700,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _showRelationSearchBottomSheet() async {
    String query = '';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final filtered = _relationAgents
                .where((a) =>
                    a.name.toLowerCase().contains(query.toLowerCase()))
                .toList();
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Cari nama relasi...',
                        prefixIcon:
                            const Icon(Icons.search, color: Colors.grey),
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
                          borderSide: const BorderSide(
                              color: Color(0xFF4318FF), width: 1.5),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        isDense: true,
                      ),
                      onChanged: (v) => setSheetState(() => query = v),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filtered.length + 1,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: Colors.grey.shade200),
                      itemBuilder: (ctx, index) {
                        if (index == 0) {
                          return ListTile(
                            leading: const Icon(Icons.add_circle_outline,
                                color: Color(0xFF4318FF), size: 22),
                            title: const Text(
                              '+ Tambah Relasi Baru',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF4318FF),
                                fontSize: 14,
                              ),
                            ),
                            onTap: () {
                              Navigator.pop(ctx);
                              _showAddRelationDialog();
                            },
                          );
                        }
                        final agent = filtered[index - 1];
                        final isSelected = agent.id == _selectedRelationAgentId;
                        return ListTile(
                          leading: isSelected
                              ? const Icon(Icons.check_circle,
                                  color: Color(0xFF4318FF), size: 22)
                              : const Icon(Icons.radio_button_unchecked,
                                  color: Colors.grey, size: 22),
                          title: Text(
                            agent.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight:
                                  isSelected ? FontWeight.w600 : FontWeight.normal,
                              color: isSelected
                                  ? const Color(0xFF4318FF)
                                  : const Color(0xFF1B2559),
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(ctx);
                            setState(() {
                              _selectedRelationAgentId = agent.id;
                              _relationNameController.text = agent.name;
                            });
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showAddRelationDialog() async {
    final nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<RelationAgentModel>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tambah Relasi Baru'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Nama Relasi / Agen',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.characters,
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                final repo = ref.read(relationAgentRepositoryProvider);
                final now = DateTime.now();
                final id = const Uuid().v4();
                await repo.createRelationAgent(
                  RelationAgentModel(
                    id: id,
                    name: nameController.text.trim().toUpperCase(),
                    createdAt: now,
                    updatedAt: now,
                  ),
                );
                final updated = await repo.getRelationAgents();
                if (ctx.mounted) {
                  Navigator.pop(
                    ctx,
                    RelationAgentModel(
                      id: id,
                      name: nameController.text.trim().toUpperCase(),
                      createdAt: now,
                      updatedAt: now,
                    ),
                  );
                }
                if (mounted) {
                  setState(() => _relationAgents = updated);
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Gagal menyimpan: $e')),
                  );
                }
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (result != null && mounted) {
      // Relasi baru langsung tampil & terpilih tanpa perlu OCR ulang.
      setState(() {
        if (!_relationAgents.any((r) => r.id == result.id)) {
          _relationAgents.add(result);
        }
        _selectedRelationAgentId = result.id;
        _relationNameController.text = result.name;
      });
    }
  }

  Widget _buildFactoryDropdown() {
    return DropdownButtonFormField<String>(
      key: ValueKey('factory-$_selectedFactoryId'),
      initialValue: _selectedFactoryId,
      isExpanded: true,
      decoration: _inputDecoration(
        label: 'Pabrik',
        icon: Icons.factory_outlined,
      ),
      items: [
        const DropdownMenuItem<String>(
          value: null,
          child: Text('Tanpa Pabrik'),
        ),
        ..._factories.map(
          (factory) => DropdownMenuItem<String>(
            value: factory.id,
            child: Text(factory.name, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
      onChanged: _isReadOnly ? null : _selectFactory,
    );
  }

  Widget _buildSpsiTypeDropdown() {
    final factoryTypes = _factories
        .where((item) => item.id == _selectedFactoryId)
        .expand((item) => item.spsiTypes)
        .toList();
    return DropdownButtonFormField<String>(
      key: ValueKey('spsi-$_selectedFactoryId-$_selectedSpsiTypeId'),
      initialValue: _selectedSpsiTypeId,
      isExpanded: true,
      decoration: _inputDecoration(
        label: 'Jenis SPSI',
        icon: Icons.price_check_outlined,
      ),
      items: [
        const DropdownMenuItem<String>(value: null, child: Text('Pilih SPSI')),
        ...factoryTypes.map(
          (type) => DropdownMenuItem<String>(
            value: type.id,
            child: Text(
              '${type.name} (${type.calculationMode == 'FIX' ? 'Fix' : 'Per/Kg'})',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
      onChanged: _isReadOnly ? null : _selectSpsiType,
      validator: (value) =>
          _selectedFactoryId != null && (value == null || value.isEmpty)
          ? 'Wajib diisi'
          : null,
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    bool isNumber = false,
    bool forceUpperCase = true,
    String? prefixText,
    String? suffixText,
    String? Function(String?)? validator,
    String? hint,
    bool? readOnlyOverride,
  }) {
    return Focus(
      onFocusChange: (hasFocus) {
        if (isNumber) {
          if (hasFocus) {
            if (controller.text == '0') {
              controller.clear();
            }
          } else {
            if (controller.text.isEmpty) {
              controller.text = '0';
            }
          }
        }
      },
      child: TextFormField(
        controller: controller,
        readOnly: readOnlyOverride ?? _isReadOnly,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        inputFormatters: isNumber || !forceUpperCase
            ? null
            : [UpperCaseTextFormatter()],
        validator: validator,
        decoration: _inputDecoration(
          label: label,
          icon: icon,
          prefixText: prefixText,
          suffixText: suffixText,
          hint: hint,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    IconData? icon,
    String? prefixText,
    String? suffixText,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      prefixIcon: icon != null
          ? Icon(icon, color: Colors.grey.shade400, size: 20)
          : null,
      prefixText: prefixText != null ? '$prefixText ' : null,
      suffixText: suffixText,
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
        borderSide: const BorderSide(color: Color(0xFF4318FF), width: 1.5),
      ),
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      isDense: true,
    );
  }

  Widget _buildReadOnlyWarning() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock, color: Colors.orange),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Data bon ini dikunci karena sudah dibuat nota atau sudah lunas.',
              style: TextStyle(
                color: Colors.orangeAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRelatedDocuments() {
    if (!_isReadOnly || widget.bon == null) return const SizedBox.shrink();

    return ref
        .watch(bonRelatedRecordsProvider(widget.bon!.id))
        .when(
          data: (data) {
            final invoices = data['notas'] as List<NotaModel>;
            final payments = data['payments'] as List<PaymentModel>;

            if (invoices.isEmpty && payments.isEmpty)
              return const SizedBox.shrink();

            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: _buildSectionCard(
                title: 'Dokumen Terkait',
                icon: Icons.link,
                children: [
                  ...invoices.map(
                    (inv) => _buildDocTile(
                      title: 'Nota ${inv.notaNumber}',
                      subtitle: NumberFormat.currency(
                        locale: 'id_ID',
                        symbol: 'Rp ',
                        decimalDigits: 0,
                      ).format(inv.totalAmount),
                      icon: Icons.description,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => NotaDetailScreen(nota: inv),
                        ),
                      ),
                    ),
                  ),
                  ...payments.map(
                    (p) => _buildDocTile(
                      title: 'Pembayaran',
                      subtitle: NumberFormat.currency(
                        locale: 'id_ID',
                        symbol: 'Rp ',
                        decimalDigits: 0,
                      ).format(p.amountPaid),
                      icon: Icons.payment,
                      color: Colors.green,
                      onTap: () {
                        if (p.proofUrl != null) {
                          showDialog(
                            context: context,
                            builder: (context) => Dialog(
                              child: ZoomableImagePreview(
                                imageUrl: p.proofUrl!,
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => const SizedBox.shrink(),
        );
  }

  Widget _buildDocTile({
    required String title,
    required String subtitle,
    required IconData icon,
    Color color = Colors.blue,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
      trailing: const Icon(Icons.chevron_right, size: 16),
      onTap: onTap,
    );
  }

  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Foto Bon / Tiket',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        if (_imageBytes != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ZoomableImagePreview(imageBytes: _imageBytes!),
          )
        else if (widget.bon?.imageUrl != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ZoomableImagePreview(imageUrl: widget.bon!.imageUrl!),
          )
        else
          Container(
            height: 100,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Center(
              child: Text(
                'Belum ada foto',
                style: TextStyle(color: Colors.grey.shade400),
              ),
            ),
          ),

        if (!_isReadOnly) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _showImagePickerOptions,
            icon: const Icon(Icons.camera_alt, size: 16),
            label: const Text('Ambil / Pilih Foto'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCalcRow(
    String label,
    double value, {
    bool isTotal = false,
    bool isSubTotal = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: (isTotal || isSubTotal)
                ? FontWeight.bold
                : FontWeight.normal,
            fontSize: isTotal ? 14 : 12,
            color: isTotal ? Colors.black87 : Colors.grey.shade700,
          ),
        ),
        Text(
          NumberFormat.currency(
            locale: 'id_ID',
            symbol: 'Rp ',
            decimalDigits: 0,
          ).format(value),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: isTotal ? 18 : (isSubTotal ? 14 : 12),
            color: isTotal ? const Color(0xFF4318FF) : Colors.black87,
          ),
        ),
      ],
    );
  }
}
