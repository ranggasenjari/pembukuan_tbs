import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// Sinyal bahwa layar awal aplikasi sudah selesai ditentukan (StartupGate).
/// Dipakai handler share agar tidak menabrak navigasi splash saat cold start.
final ValueNotifier<bool> appStartupReady = ValueNotifier(false);

class SharingService {
  static final SharingService _instance = SharingService._internal();
  factory SharingService() => _instance;
  SharingService._internal();

  StreamSubscription? _intentDataStreamSubscription;
  Future<void> Function(List<SharedMediaFile>)? _onSharingReceived;

  void init({
    required Future<void> Function(List<SharedMediaFile>) onSharingReceived,
  }) {
    _onSharingReceived = onSharingReceived;

    // Sharing gambar saat aplikasi sedang berjalan di memori
    _intentDataStreamSubscription = ReceiveSharingIntent.instance
        .getMediaStream()
        .listen(
          (List<SharedMediaFile> value) {
            if (value.isNotEmpty) {
              _onSharingReceived?.call(value);
            }
          },
          onError: (err) {
            debugPrint("getIntentDataStream error: $err");
          },
        );

    // Sharing gambar saat aplikasi dibuka dari luar (cold start)
    ReceiveSharingIntent.instance.getInitialMedia().then((value) async {
      if (value.isNotEmpty) {
        await _onSharingReceived?.call(value);
      }
      // Reset agar intent berikutnya tetap bisa diterima.
      ReceiveSharingIntent.instance.reset();
    });
  }

  void dispose() {
    _intentDataStreamSubscription?.cancel();
  }
}