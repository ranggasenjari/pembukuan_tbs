import 'dart:async';
import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

class SharingService {
  static final SharingService _instance = SharingService._internal();
  factory SharingService() => _instance;
  SharingService._internal();

  StreamSubscription? _intentDataStreamSubscription;
  Function(List<SharedMediaFile>)? _onSharingReceived;

  void init({required Function(List<SharedMediaFile>) onSharingReceived}) {
    _onSharingReceived = onSharingReceived;

    // For sharing images coming from outside the app while the app is in the memory
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

    // For sharing images coming from outside the app while the app is closed
    ReceiveSharingIntent.instance.getInitialMedia().then((
      List<SharedMediaFile> value,
    ) {
      if (value.isNotEmpty) {
        _onSharingReceived?.call(value);
      }
    });
  }

  void dispose() {
    _intentDataStreamSubscription?.cancel();
  }
}
