import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'features/home/home_screen.dart';
import 'features/auth/login_screen.dart';
import 'core/services/sharing_service.dart';
import 'features/bons/bon_entry_screen.dart';
import 'config/env_config.dart';
import 'dart:io';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  // Initialize Supabase with environment configuration
  // Credentials should be passed via --dart-define during build/run:
  // flutter run \
  //   --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  //   --dart-define=SUPABASE_ANON_KEY=your-anon-key \
  //   --dart-define=SUPABASE_SCHEMA=inv
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
    postgrestOptions: PostgrestClientOptions(
      schema: SupabaseConfig.supabaseSchema,
    ),
  );

  runApp(const ProviderScope(child: MyApp()));

  // Initialize Sharing Service
  SharingService().init(
    onSharingReceived: (List<SharedMediaFile> files) {
      if (files.isNotEmpty) {
        final path = files.first.path;
        if (path.isNotEmpty) {
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (context) => BonEntryScreen(initialImage: File(path)),
            ),
          );
        }
      }
    },
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
      home: Supabase.instance.client.auth.currentSession == null
          ? const LoginScreen()
          : const HomeScreen(),
    );
  }
}
