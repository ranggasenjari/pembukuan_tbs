import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/services/sharing_service.dart';
import 'core/widgets/offline_status_banner.dart';
import 'core/widgets/startup_gate.dart';
import 'features/bons/bon_entry_screen.dart';
import 'config/env_config.dart';
import 'offline/offline_coordinator.dart';
import 'offline/offline_session_service.dart';
import 'providers/providers.dart';
import 'dart:io';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  // Initialize Supabase with environment configuration
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
    postgrestOptions: PostgrestClientOptions(
      schema: SupabaseConfig.supabaseSchema,
    ),
  );

  // Mesin offline/online (SQLCipher + antrean sinkron + konektivitas).
  final coordinator = SyncCoordinator(
    OfflineSessionService(),
    ConnectivityService(),
    Supabase.instance.client,
  );

  // Tampilkan splash secepat mungkin; StartupGate menentukan layar tujuan.
  runApp(
    ProviderScope(
      overrides: [
        coordinatorProvider.overrideWithValue(coordinator),
      ],
      child: const MyApp(),
    ),
  );

  // Initialize Sharing Service
  SharingService().init(
    onSharingReceived: (List<SharedMediaFile> files) async {
      if (files.isEmpty) return;
      final path = files.first.path;
      if (path.isEmpty) return;
      await _openBonFromSharedFile(File(path));
    },
  );
}

/// Membuka form bon dari gambar yang di-share ke aplikasi.
/// Menunggu StartupGate selesai agar push tidak ditimpa layar awal.
Future<void> _openBonFromSharedFile(File file) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (!appStartupReady.value && DateTime.now().isBefore(deadline)) {
    await Future.delayed(const Duration(milliseconds: 150));
  }
  final nav = navigatorKey.currentState;
  if (nav == null) return;
  nav.push(
    MaterialPageRoute(
      builder: (context) => BonEntryScreen(initialImage: file),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Pembukuan TBS',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32), // Green like palm oil plantation
          primary: const Color(0xFF2E7D32),
          secondary: const Color(0xFF558B2F),
          surface: Colors.grey.shade50,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2E7D32),
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 2,
        ),
        cardTheme: CardThemeData(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2E7D32),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          ),
        ),
      ),
      builder: (context, child) => OfflineStatusBanner(
        coordinator: ProviderScope.containerOf(context).read(coordinatorProvider),
        child: child ?? const SizedBox.shrink(),
      ),
      home: const StartupGate(),
    );
  }
}