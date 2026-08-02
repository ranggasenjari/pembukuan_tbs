import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/enums.dart';
import '../../models/nota_model.dart';
import '../../providers/providers.dart';
import 'payment_entry_screen.dart';

class PaymentNotaSelectScreen extends ConsumerStatefulWidget {
  const PaymentNotaSelectScreen({super.key});

  @override
  ConsumerState<PaymentNotaSelectScreen> createState() =>
      _PaymentNotaSelectScreenState();
}

class _PaymentNotaSelectScreenState
    extends ConsumerState<PaymentNotaSelectScreen> {
  // We reuse NotaRepo to get notas, filtering for waiting-payment notas locally or via query

  @override
  Widget build(BuildContext context) {
    // Ideally create a specific provider for 'unpaid' notas
    final notaFuture = ref.read(notaRepositoryProvider).getNotas();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      appBar: AppBar(
        title: const Text(
          'Pilih Nota Belum Lunas',
          style: TextStyle(
            color: Color(0xFF1B2559),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1B2559)),
      ),
      body: FutureBuilder<List<NotaModel>>(
        future: notaFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final notas = snapshot.data ?? [];
          final unpaidNotas = notas
              .where((i) => i.status == PaymentStatus.tertagih)
              .toList();

          if (unpaidNotas.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 64,
                    color: Colors.green.shade200,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tidak ada nota menunggu pembayaran.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: unpaidNotas.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final nota = unpaidNotas[index];
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
                  contentPadding: const EdgeInsets.all(16),
                  title: Text(
                    nota.notaNumber,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B2559),
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: Color(0xFFA3AED0),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('dd MMM yyyy').format(nota.notaDate),
                          style: const TextStyle(
                            color: Color(0xFFA3AED0),
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          NumberFormat.currency(
                            locale: 'id_ID',
                            symbol: 'Rp ',
                            decimalDigits: 0,
                          ).format(nota.totalAmount),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4318FF),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4318FF).withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: Color(0xFF4318FF),
                    ),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PaymentEntryScreen(nota: nota),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
