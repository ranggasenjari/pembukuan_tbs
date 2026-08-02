import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../core/enums.dart';
import '../../models/nota_model.dart';
import '../../models/bon_model.dart';
import '../../providers/providers.dart';
import '../../services/nota_whatsapp_service.dart';

class NotaDetailScreen extends ConsumerStatefulWidget {
  final NotaModel nota;
  final List<BonModel>? initialBons;

  const NotaDetailScreen({super.key, required this.nota, this.initialBons});

  @override
  ConsumerState<NotaDetailScreen> createState() => _NotaDetailScreenState();
}

class _NotaDetailScreenState extends ConsumerState<NotaDetailScreen> {
  late Future<List<BonModel>> _bonsFuture;

  @override
  void initState() {
    super.initState();
    // Use initialBons if provided, otherwise fetch from repository
    if (widget.initialBons != null) {
      _bonsFuture = Future.value(widget.initialBons!);
    } else {
      _bonsFuture = ref
          .read(notaRepositoryProvider)
          .getNotaBons(widget.nota.id);
    }
  }

  Future<void> _printNota(List<BonModel> bons) async {
    await ref.read(pdfServiceProvider).printNota(widget.nota, bons);
  }

  Future<void> _printThermalNota(BonModel bon) async {
    await ref.read(pdfServiceProvider).printThermalNota(widget.nota, bon);
  }

  Future<void> _shareNota(List<BonModel> bons) async {
    final pdfService = ref.read(pdfServiceProvider);
    final Uint8List pdfBytes;

    if (bons.length == 1) {
      pdfBytes = await pdfService.generateThermalNota(widget.nota, bons.first);
    } else {
      pdfBytes = await pdfService.generateNota(widget.nota, bons);
    }

    final directory = await getTemporaryDirectory();
    final filename = pdfService.getNotaFilename(widget.nota, bons);
    final file = File('${directory.path}/$filename');
    await file.writeAsBytes(pdfBytes);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: pdfService.getNotaShareCaption(widget.nota, bons),
      ),
    );
  }

  Future<void> _sendWhatsapp(List<BonModel> bons) async {
    final message = NotaWhatsappService.buildMessage(widget.nota, bons);
    final uri = Uri.parse(
      'https://wa.me/?text=${Uri.encodeComponent(message)}',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Tidak dapat membuka WhatsApp.');
    }
  }

  void _copyToClipboard(String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Nilai berhasil disalin!')));
  }

  Color _statusBackgroundColor(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.lunas:
        return Colors.green.shade100;
      case PaymentStatus.tertagih:
        return Colors.orange.shade100;
      case PaymentStatus.belumDibayar:
        return Colors.red.shade100;
    }
  }

  Color _statusTextColor(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.lunas:
        return Colors.green.shade800;
      case PaymentStatus.tertagih:
        return Colors.orange.shade800;
      case PaymentStatus.belumDibayar:
        return Colors.red.shade800;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      appBar: AppBar(
        title: Text(
          'Detail Nota ${widget.nota.notaNumber}',
          style: const TextStyle(
            color: Color(0xFF1B2559),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1B2559)),
      ),
      body: FutureBuilder<List<BonModel>>(
        future: _bonsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final bons = snapshot.data ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
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
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Total Tagihan',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    NumberFormat.currency(
                                      locale: 'id_ID',
                                      symbol: 'Rp ',
                                      decimalDigits: 0,
                                    ).format(widget.nota.totalAmount),
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF4318FF),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.copy,
                                      size: 16,
                                      color: Colors.grey,
                                    ),
                                    onPressed: () => _copyToClipboard(
                                      widget.nota.totalAmount.toStringAsFixed(
                                        0,
                                      ),
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _statusBackgroundColor(widget.nota.status),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              widget.nota.status.notaLabel.toUpperCase(),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                                color: _statusTextColor(widget.nota.status),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildInfoRow('Nomor Nota', widget.nota.notaNumber),
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        'Tanggal',
                        DateFormat('dd MMM yyyy').format(widget.nota.notaDate),
                      ),
                      if (widget.nota.relationAgentName != null || widget.nota.recipientName != null) ...[
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          'Relasi/Agen',
                          widget.nota.relationAgentName ?? widget.nota.recipientName!,
                        ),
                      ],
                      if (widget.nota.recipientAddress != null) ...[
                        const SizedBox(height: 12),
                        _buildInfoRow('Alamat', widget.nota.recipientAddress!),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Text(
                      'Daftar Bon',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF1B2559),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ListView.separated(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: bons.length,
                  separatorBuilder: (c, i) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final bon = bons[index];
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        title: Text(
                          bon.plateNumber,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        subtitle: Text(
                          '${DateFormat('dd MMM yyyy').format(bon.bonDate)} • Netto: ${NumberFormat.decimalPattern().format(bon.netto2)} kg',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                        trailing: Text(
                          NumberFormat.currency(
                            locale: 'id_ID',
                            symbol: 'Rp ',
                            decimalDigits: 0,
                          ).format(bon.total),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4318FF),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 100), // Space for bottom buttons
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: FutureBuilder<List<BonModel>>(
        future: _bonsFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox.shrink();
          final bons = snapshot.data!;

          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  if (bons.length == 1) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _printThermalNota(bons.first),
                        icon: const Icon(Icons.print_outlined, size: 18),
                        label: const Text(
                          'NOTA KECIL',
                          style: TextStyle(fontSize: 10),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: Colors.lightGreen),
                          foregroundColor: Colors.lightGreen,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _printNota(bons),
                      icon: const Icon(Icons.print, size: 18),
                      label: Text(
                        bons.length == 1 ? 'BESAR' : 'CETAK PDF',
                        style: const TextStyle(fontSize: 10),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: Color(0xFF4318FF)),
                        foregroundColor: const Color(0xFF4318FF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _shareNota(bons),
                      icon: const Icon(Icons.share, size: 18),
                      label: const Text(
                        'SHARE',
                        style: TextStyle(fontSize: 10),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: const Color(0xFF4318FF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _sendWhatsapp(bons),
                      icon: const Icon(Icons.chat_outlined, size: 18),
                      label: const Text('WA', style: TextStyle(fontSize: 10)),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade600)),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1B2559),
          ),
        ),
      ],
    );
  }
}
