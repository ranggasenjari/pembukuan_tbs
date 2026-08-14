import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../config/env_config.dart';
import '../models/bon_model.dart';
import '../models/nota_model.dart';
import '../core/enums.dart';
import '../services/nota_whatsapp_service.dart';
import 'offline_database.dart';
import 'offline_repositories.dart';
import 'offline_session_service.dart';
import 'offline_sync_service.dart';

Future<void> runOfflineApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
    postgrestOptions: PostgrestClientOptions(
      schema: SupabaseConfig.supabaseSchema,
    ),
  );
  runApp(const OfflineApp());
}

class OfflineRuntime {
  OfflineRuntime(this.session, this.database, this.client)
    : bons = OfflineBonRepository(database),
      notas = OfflineNotaRepository(database),
      masters = OfflineMasterRepository(database),
      bootstrap = OfflineBootstrapService(client, database),
      sync = OfflineSyncService(
        client: client,
        database: database,
        deviceId: session.deviceId,
      );
  final OfflineSession session;
  final OfflineDatabase database;
  final SupabaseClient client;
  final OfflineBonRepository bons;
  final OfflineNotaRepository notas;
  final OfflineMasterRepository masters;
  final OfflineBootstrapService bootstrap;
  final OfflineSyncService sync;
}

class OfflineApp extends StatefulWidget {
  const OfflineApp({super.key});
  @override
  State<OfflineApp> createState() => _OfflineAppState();
}

class _OfflineAppState extends State<OfflineApp> {
  final _sessions = OfflineSessionService();
  OfflineSession? _session;
  OfflineRuntime? _runtime;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _session = null);
    _session = await _sessions.currentSession();
    if (mounted) setState(() {});
  }

  Future<void> _open(OfflineSession session) async {
    final db = await _sessions.openDatabase(session);
    _runtime = OfflineRuntime(session, db, Supabase.instance.client);
    if (mounted) setState(() {});
    try {
      await _runtime!.bootstrap.refreshMasters();
      await _runtime!.sync.syncNow();
    } catch (_) {
      /* Offline is an expected state. */
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget home;
    if (_runtime != null)
      home = OfflineHome(runtime: _runtime!);
    else if (_session != null)
      home = OfflinePinScreen(
        session: _session!,
        sessions: _sessions,
        onUnlocked: _open,
      );
    else
      home = OfflineLoginScreen(sessions: _sessions, onActivated: _open);
    return MaterialApp(
      title: 'Pembukuan TBS Offline',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: home,
    );
  }
}

class OfflinePinScreen extends StatefulWidget {
  const OfflinePinScreen({
    super.key,
    required this.session,
    required this.sessions,
    required this.onUnlocked,
  });
  final OfflineSession session;
  final OfflineSessionService sessions;
  final Future<void> Function(OfflineSession) onUnlocked;
  @override
  State<OfflinePinScreen> createState() => _OfflinePinScreenState();
}

class _OfflinePinScreenState extends State<OfflinePinScreen> {
  final _pin = TextEditingController();
  bool _busy = false;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 56),
            const SizedBox(height: 16),
            Text(widget.session.email),
            TextField(
              controller: _pin,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              decoration: const InputDecoration(labelText: 'PIN 6 digit'),
            ),
            FilledButton(
              onPressed: _busy
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      if (await widget.sessions.unlock(_pin.text))
                        await widget.onUnlocked(widget.session);
                      else if (mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('PIN salah')),
                        );
                      if (mounted) setState(() => _busy = false);
                    },
              child: const Text('BUKA DATA LOKAL'),
            ),
          ],
        ),
      ),
    ),
  );
}

class OfflineLoginScreen extends StatefulWidget {
  const OfflineLoginScreen({
    super.key,
    required this.sessions,
    required this.onActivated,
  });
  final OfflineSessionService sessions;
  final Future<void> Function(OfflineSession) onActivated;
  @override
  State<OfflineLoginScreen> createState() => _OfflineLoginScreenState();
}

class _OfflineLoginScreenState extends State<OfflineLoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _pin = TextEditingController();
  bool _busy = false;
  Future<void> _login() async {
    setState(() => _busy = true);
    try {
      final result = await Supabase.instance.client.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
      final user = result.user;
      if (user == null) throw StateError('Login gagal');
      final session = await widget.sessions.activate(
        userId: user.id,
        email: user.email ?? _email.text.trim(),
        pin: _pin.text,
      );
      await widget.onActivated(session);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Aktivasi Offline')),
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          TextField(
            controller: _email,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
          ),
          TextField(
            controller: _pin,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 6,
            decoration: const InputDecoration(labelText: 'PIN offline 6 digit'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _login,
            child: const Text('LOGIN & AKTIFKAN'),
          ),
        ],
      ),
    ),
  );
}

class OfflineHome extends StatefulWidget {
  const OfflineHome({super.key, required this.runtime});
  final OfflineRuntime runtime;
  @override
  State<OfflineHome> createState() => _OfflineHomeState();
}

class _OfflineHomeState extends State<OfflineHome> {
  Future<void> _addBon() async {
    final result = await Navigator.push<BonModel>(
      context,
      MaterialPageRoute(
        builder: (_) => OfflineBonForm(runtime: widget.runtime),
      ),
    );
    if (result != null && mounted) setState(() {});
  }

  Future<void> _addNota() async {
    final result = await Navigator.push<NotaModel>(
      context,
      MaterialPageRoute(
        builder: (_) => OfflineNotaForm(runtime: widget.runtime),
      ),
    );
    if (result != null && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Operasional Offline'),
      actions: [
        ValueListenableBuilder<OfflineSyncSnapshot>(
          valueListenable: widget.runtime.sync.snapshots,
          builder: (_, state, __) => TextButton.icon(
            onPressed: widget.runtime.sync.syncNow,
            icon: const Icon(Icons.sync),
            label: Text('${state.pending} antrean'),
          ),
        ),
      ],
    ),
    body: FutureBuilder(
      future: Future.wait([
        widget.runtime.bons.getBons(),
        widget.runtime.notas.getNotas(),
      ]),
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null)
          return const Center(child: CircularProgressIndicator());
        final bons = data[0] as List<BonModel>;
        final notas = data[1] as List<NotaModel>;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Bon aktif (${bons.length})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            ...bons.map(
              (b) => ListTile(
                title: Text(b.plateNumber),
                subtitle: Text(
                  '${b.driverName ?? '-'} · Rp ${b.total.toInt()}',
                ),
                trailing: Text(b.status.value),
              ),
            ),
            const Divider(),
            Text(
              'Nota lokal (${notas.length})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            ...notas.map(
              (n) => ListTile(
                title: Text(n.notaNumber),
                subtitle: Text('Rp ${n.totalAmount.toInt()}'),
              ),
            ),
          ],
        );
      },
    ),
    floatingActionButton: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton.extended(
          heroTag: 'nota',
          onPressed: _addNota,
          icon: const Icon(Icons.description),
          label: const Text('NOTA'),
        ),
        const SizedBox(height: 12),
        FloatingActionButton.extended(
          heroTag: 'bon',
          onPressed: _addBon,
          icon: const Icon(Icons.add),
          label: const Text('BON'),
        ),
      ],
    ),
  );
}

class OfflineBonForm extends StatefulWidget {
  const OfflineBonForm({super.key, required this.runtime});
  final OfflineRuntime runtime;
  @override
  State<OfflineBonForm> createState() => _OfflineBonFormState();
}

class _OfflineBonFormState extends State<OfflineBonForm> {
  final _plate = TextEditingController();
  final _driver = TextEditingController();
  final _netto = TextEditingController();
  final _price = TextEditingController();
  String? _factoryId;
  String? _relationId;
  Future<void> _save() async {
    final now = DateTime.now();
    final netto = double.tryParse(_netto.text) ?? 0;
    final price = double.tryParse(_price.text) ?? 0;
    final bon = BonModel(
      id: const Uuid().v4(),
      bonDate: now,
      plateNumber: _plate.text.toUpperCase(),
      driverName: _driver.text.toUpperCase(),
      relationAgentId: _relationId,
      factoryId: _factoryId,
      netto1: netto,
      netto2: netto,
      price: price,
      biayaBongkar: 0,
      bpColt: 0,
      pph: 0,
      uangMinum: 0,
      total: netto * price,
      status: PaymentStatus.belumDibayar,
      createdAt: now,
      updatedAt: now,
    );
    await widget.runtime.bons.createBon(bon, null, null);
    if (mounted) Navigator.pop(context, bon);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Bon Offline')),
    body: FutureBuilder(
      future: Future.wait([
        widget.runtime.masters.factories(),
        widget.runtime.masters.relations(),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final fs = snapshot.data![0] as List;
        final rs = snapshot.data![1] as List;
        return Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              TextField(
                controller: _plate,
                decoration: const InputDecoration(labelText: 'Plat nomor'),
              ),
              TextField(
                controller: _driver,
                decoration: const InputDecoration(labelText: 'Supir'),
              ),
              DropdownButtonFormField<String>(
                value: _factoryId,
                items: fs
                    .map<DropdownMenuItem<String>>(
                      (f) => DropdownMenuItem(
                        value: f.id as String,
                        child: Text(f.name as String),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _factoryId = v),
                decoration: const InputDecoration(labelText: 'Pabrik'),
              ),
              DropdownButtonFormField<String>(
                value: _relationId,
                items: rs
                    .map<DropdownMenuItem<String>>(
                      (r) => DropdownMenuItem(
                        value: r.id as String,
                        child: Text(r.name as String),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _relationId = v),
                decoration: const InputDecoration(labelText: 'Relasi'),
              ),
              TextField(
                controller: _netto,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Netto (kg)'),
              ),
              TextField(
                controller: _price,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Harga'),
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: _save, child: const Text('SIMPAN LOKAL')),
            ],
          ),
        );
      },
    ),
  );
}

class OfflineNotaForm extends StatefulWidget {
  const OfflineNotaForm({super.key, required this.runtime});
  final OfflineRuntime runtime;
  @override
  State<OfflineNotaForm> createState() => _OfflineNotaFormState();
}

class _OfflineNotaFormState extends State<OfflineNotaForm> {
  final Set<String> _selected = {};
  Future<void> _save(List<BonModel> bons) async {
    final picked = bons.where((b) => _selected.contains(b.id)).toList();
    if (picked.isEmpty) return;
    final now = DateTime.now();
    final uuid = const Uuid();
    final nota = NotaModel(
      id: uuid.v4(),
      notaNumber:
          'NOTA-${now.toUtc().toIso8601String().replaceAll(RegExp(r'[^0-9]'), '')}-${uuid.v4().substring(0, 6).toUpperCase()}',
      notaDate: now,
      totalAmount: picked.fold(0, (sum, b) => sum + b.total),
      status: PaymentStatus.tertagih,
      createdAt: now,
      updatedAt: now,
    );
    await widget.runtime.notas.createNota(
      nota,
      picked.map((b) => b.id).toList(),
    );
    final message = NotaWhatsappService.buildMessage(nota, picked);
    await launchUrl(
      Uri.parse('whatsapp://send?text=${Uri.encodeComponent(message)}'),
      mode: LaunchMode.externalApplication,
    );
    if (mounted) Navigator.pop(context, nota);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Buat Nota Offline')),
    body: FutureBuilder<List<BonModel>>(
      future: widget.runtime.bons.getBons(),
      builder: (context, snapshot) {
        final bons = (snapshot.data ?? [])
            .where((b) => b.status == PaymentStatus.belumDibayar)
            .toList();
        return Column(
          children: [
            Expanded(
              child: ListView(
                children: bons
                    .map(
                      (b) => CheckboxListTile(
                        value: _selected.contains(b.id),
                        onChanged: (v) => setState(
                          () => v == true
                              ? _selected.add(b.id)
                              : _selected.remove(b.id),
                        ),
                        title: Text(b.plateNumber),
                        subtitle: Text('Rp ${b.total.toInt()}'),
                      ),
                    )
                    .toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: () => _save(bons),
                child: const Text('BUAT NOTA & KIRIM WA'),
              ),
            ),
          ],
        );
      },
    ),
  );
}
