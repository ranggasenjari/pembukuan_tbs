import 'package:intl/intl.dart';
import '../models/bon_model.dart';
import '../models/nota_model.dart';

class NotaWhatsappService {
  static final _currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  static String buildMessage(NotaModel nota, List<BonModel> bons) {
    final lines = <String>[
      '*${nota.notaNumber}*',
      'Relasi: ${nota.relationAgentName ?? nota.recipientName ?? '-'}',
      '',
    ];

    var grandTotal = 0.0;
    var totalDp = 0.0;
    for (var i = 0; i < bons.length; i++) {
      final bon = bons[i];
      final bruto = bon.netto2 * bon.price;
      final bonDp = bon.dp;
      final bonTotalBeforeDp = bon.total + bonDp;
      grandTotal += bonTotalBeforeDp;
      totalDp += bonDp;

      lines.add('*${i + 1}. ${bon.plateNumber}* — ${bon.driverName ?? '-'}');
      lines.add('   ${bon.netto2.toInt()} kg x ${_currency.format(bon.price)}');
      lines.add('   *${_currency.format(bruto)}*');
      lines.add('');

      lines.add('   *Potongan:*');
      if (bon.spsiAmount > 0) {
        lines.add('      SPSI: ${_currency.format(bon.spsiAmount)}');
      }
      if (bon.bpColt > 0) {
        lines.add('      BP/Colt: ${_currency.format(bon.bpColt)}');
      }
      if (bon.pph > 0) {
        lines.add('      PPh: ${_currency.format(bon.pph)}');
      }
      if (bon.uangMinum > 0) {
        lines.add('      Uang Minum: ${_currency.format(bon.uangMinum)}');
      }
      for (final d in bon.deductions) {
        if (d.amount > 0) {
          lines.add('      ${d.label}: ${_currency.format(d.amount.toDouble())}');
        }
      }
      lines.add('   *Total bon: ${_currency.format(bonTotalBeforeDp)}*');
      lines.add('');
    }

    lines.add('*TOTAL NOTA: ${_currency.format(grandTotal)}*');
    if (totalDp > 0) {
      lines.add('DP / Panjar: ${_currency.format(totalDp)}');
      lines.add('*Total Akhir: ${_currency.format(grandTotal - totalDp)}*');
    }
    return lines.join('\n');
  }
}
