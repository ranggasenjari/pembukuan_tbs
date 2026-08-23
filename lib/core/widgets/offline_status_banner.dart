import 'package:flutter/material.dart';

import '../../offline/offline_coordinator.dart';

/// Bilah status offline/sinkron yang ditaruh di atas seluruh layar lewat
/// `MaterialApp.builder`. Menampilkan indikator saat perangkat offline atau
/// masih ada antrean yang belum tersinkron, dengan tombol sinkron manual.
class OfflineStatusBanner extends StatelessWidget {
  const OfflineStatusBanner({
    super.key,
    required this.coordinator,
    required this.child,
  });

  final SyncCoordinator coordinator;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: coordinator.connectivity.online,
      builder: (context, online, _) {
        return ValueListenableBuilder<OfflineUiState>(
          valueListenable: coordinator.ui,
          builder: (context, state, _) {
            final showBanner = !online || state.pending > 0;
            return Column(
              children: [
                if (showBanner)
                  Material(
                    color: !online
                        ? const Color(0xFFFFF3CD)
                        : const Color(0xFFD4EDDA),
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              !online
                                  ? Icons.cloud_off
                                  : Icons.sync,
                              size: 16,
                              color: !online
                                  ? const Color(0xFF856404)
                                  : const Color(0xFF155724),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    !online
                                        ? 'Offline — perubahan tersimpan lokal'
                                        : 'Sinkronisasi… ${state.pending} antrean',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: !online
                                          ? const Color(0xFF856404)
                                          : const Color(0xFF155724),
                                    ),
                                  ),
                                  if (online &&
                                      state.pending > 0 &&
                                      state.message != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      state.message!,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: const Color(0xFF155724),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (online && state.pending > 0)
                              TextButton(
                                onPressed: coordinator.syncNow,
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                ),
                                child: const Text('Sinkron'),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                Expanded(child: child),
              ],
            );
          },
        );
      },
    );
  }
}