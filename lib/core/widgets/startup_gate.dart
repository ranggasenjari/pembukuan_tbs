import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/login_screen.dart';
import '../../features/auth/offline_unlock_screen.dart';
import '../../features/home/home_screen.dart';
import '../../providers/providers.dart';
import '../services/sharing_service.dart';

/// Layar awal yang tampil seketika (splash) sambil menentukan tujuan:
/// Home (sesi online/offline terbuka), unlock PIN offline, atau Login.
/// Mencegah layar hitam panjang saat startup menunggu sinkronisasi.
class StartupGate extends ConsumerStatefulWidget {
  const StartupGate({super.key});

  @override
  ConsumerState<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends ConsumerState<StartupGate> {
  @override
  void initState() {
    super.initState();
    _resolve();
  }

  /// Menunggu sesi Supabase ter-recover (tanpa memblokir UI), lalu arahkan.
  Future<void> _resolve() async {
    final coordinator = ref.read(coordinatorProvider);
    Widget target = const LoginScreen();

    try {
      final offlineSession = await coordinator.loadSession();
      final onlineUser = await _initialUser();

      if (onlineUser != null) {
        if (offlineSession != null && offlineSession.userId == onlineUser.id) {
          try {
            await coordinator.attach(offlineSession);
          } catch (_) {}
        }
        target = const HomeScreen();
      } else if (offlineSession != null) {
        target = OfflineUnlockScreen(session: offlineSession);
      }
    } catch (_) {
      target = const LoginScreen();
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => target),
    );
    appStartupReady.value = true;
  }

  Future<User?> _initialUser() async {
    final auth = Supabase.instance.client.auth;
    final current = auth.currentSession?.user;
    if (current != null) return current;
    // Sesi kadang baru ter-recover beberapa saat setelah initialize (terutama
    // cold start via share). Tunggu singkat sebelum memutuskan layar tujuan
    // agar tidak salah menampilkan PIN offline saat user sebenarnya sudah login.
    final deadline = DateTime.now().add(const Duration(seconds: 6));
    while (auth.currentSession?.user == null &&
        DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 120));
    }
    return auth.currentSession?.user;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.local_shipping,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Pembukuan TBS',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B2559),
              ),
            ),
            const SizedBox(height: 24),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
          ],
        ),
      ),
    );
  }
}