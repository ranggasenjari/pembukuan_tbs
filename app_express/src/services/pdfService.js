const PDFDocument = require('pdfkit');
const { currency, date, number } = require('./format');

const A4_MARGIN = 36;
const A4_TABLE_WIDTH = 523;
const A4_BOTTOM = 805;

function collectPdf(doc) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    doc.on('data', (chunk) => chunks.push(chunk));
    doc.on('end', () => resolve(Buffer.concat(chunks)));
    doc.on('error', reject);
    doc.end();
  });
}

function safeText(value) {
  return String(value ?? '-').replace(/\s+/g, ' ').trim() || '-';
}

function ensureSpace(doc, height, onNewPage) {
  if (doc.y + height <= A4_BOTTOM) return;
  doc.addPage();
  doc.y = A4_MARGIN;
  if (onNewPage) onNewPage();
}

function drawCellText(doc, value, x, y, width, options = {}) {
  doc.text(safeText(value), x, y, {
    width,
    align: options.align || 'left',
    lineGap: options.lineGap || 1,
    ellipsis: options.ellipsis || false
  });
}

function measureRowHeight(doc, cells, columns) {
  doc.font('Helvetica').fontSize(8.2);
  const heights = cells.map((cell, index) => {
    const column = columns[index];
    return doc.heightOfString(safeText(cell), {
      width: column.width - 10,
      lineGap: 1
    });
  });
  return Math.max(25, Math.max(...heights) + 13);
}

function drawTableHeader(doc, columns) {
  const x = A4_MARGIN;
  const y = doc.y;
  const height = 24;

  doc.save();
  doc.rect(x, y, A4_TABLE_WIDTH, height).fill('#f3f6f8');
  doc.rect(x, y, A4_TABLE_WIDTH, height).stroke('#d8dee6');
  doc.fillColor('#475467').font('Helvetica-Bold').fontSize(7.4);

  let cursor = x;
  columns.forEach((column) => {
    drawCellText(doc, column.label, cursor + 5, y + 7, column.width - 10, {
      align: column.align || 'left'
    });
    cursor += column.width;
  });
  doc.restore();
  doc.y = y + height;
}

function drawTableRow(doc, columns, cells, index) {
  const rowHeight = measureRowHeight(doc, cells, columns);
  ensureSpace(doc, rowHeight + 8, () => drawTableHeader(doc, columns));

  const x = A4_MARGIN;
  const y = doc.y;
  doc.save();
  if (index % 2 === 1) {
    doc.rect(x, y, A4_TABLE_WIDTH, rowHeight).fill('#fbfcfd');
  }
  doc.rect(x, y, A4_TABLE_WIDTH, rowHeight).stroke('#e4e7ec');
  doc.fillColor('#1f2937').font('Helvetica').fontSize(8.2);

  let cursor = x;
  cells.forEach((cell, cellIndex) => {
    const column = columns[cellIndex];
    drawCellText(doc, cell, cursor + 5, y + 7, column.width - 10, {
      align: column.align || 'left'
    });
    cursor += column.width;
  });
  doc.restore();
  doc.y = y + rowHeight;
}

function drawInfoPair(doc, label, value, x, y, width) {
  doc.fillColor('#667085').font('Helvetica-Bold').fontSize(7.6).text(label, x, y, { width });
  doc.fillColor('#111827').font('Helvetica').fontSize(9).text(value || '-', x, y + 11, { width });
}

function summarizeDeductions(bons) {
  const totalBiayaBongkar = bons.reduce((sum, bon) => sum + Number(bon.biaya_bongkar || 0) * Number(bon.netto_1 || 0), 0);
  const totalBpColt = bons.reduce((sum, bon) => sum + Number(bon.bp_colt || 0), 0);
  const totalPph = bons.reduce((sum, bon) => sum + Number(bon.pph || 0), 0);
  const totalUangMinum = bons.reduce((sum, bon) => sum + Number(bon.uang_minum || 0), 0);
  const totalDp = bons.reduce((sum, bon) => sum + Number(bon.dp || 0), 0);
  const dynamic = {};

  bons.forEach((bon) => {
    (bon.bon_deductions || []).forEach((deduction) => {
      const label = safeText(deduction.label);
      dynamic[label] = (dynamic[label] || 0) + Number(deduction.amount || 0);
    });
  });

  return [
    ['Biaya Bongkar', totalBiayaBongkar],
    ['BP/Colt', totalBpColt],
    ['PPh (0.25%)', totalPph],
    ['Uang Minum', totalUangMinum],
    ['DP / Panjar', totalDp],
    ...Object.entries(dynamic)
  ].filter(([, value]) => Number(value || 0) !== 0);
}

function drawSummary(doc, nota, bons) {
  const deductionRows = summarizeDeductions(bons);
  const subtotal = bons.reduce((sum, bon) => sum + Number(bon.netto_2 || 0) * Number(bon.price || 0), 0);
  const totalDeductions = deductionRows.reduce((sum, [, value]) => sum + Number(value || 0), 0);
  const panelWidth = 250;
  const x = A4_MARGIN + A4_TABLE_WIDTH - panelWidth;
  const rowHeight = 16;
  const rows = [
    ['Subtotal Bruto', subtotal],
    ...deductionRows,
    ['Total Potongan', totalDeductions]
  ];
  const padding = 12;
  const titleHeight = 19;
  const dividerGap = 11;
  const totalBandHeight = 32;
  const bottomPadding = 12;
  const panelHeight =
    padding +
    titleHeight +
    rows.length * rowHeight +
    dividerGap +
    totalBandHeight +
    bottomPadding;

  ensureSpace(doc, panelHeight + 18);
  const panelY = doc.y + 14;
  let y = panelY + padding;

  doc.save();
  doc.roundedRect(x, panelY, panelWidth, panelHeight, 8).fill('#fbfcfd');

  doc.fillColor('#111827').font('Helvetica-Bold').fontSize(9.5).text('Ringkasan Nota', x + 12, y, {
    width: panelWidth - 24
  });
  y += titleHeight;

  rows.forEach(([label, value], index) => {
    const isTotalDeduction = index === rows.length - 1;
    doc.fillColor(isTotalDeduction ? '#111827' : '#475467')
      .font(isTotalDeduction ? 'Helvetica-Bold' : 'Helvetica')
      .fontSize(8.2)
      .text(label, x + 12, y, { width: 112 });
    doc.fillColor('#111827')
      .font(isTotalDeduction ? 'Helvetica-Bold' : 'Helvetica')
      .fontSize(8.2)
      .text(currency(value), x + 124, y, { width: panelWidth - 136, align: 'right' });
    y += rowHeight;
  });

  doc.moveTo(x + 12, y + 2).lineTo(x + panelWidth - 12, y + 2).stroke('#d8dee6');
  y += dividerGap;

  doc.roundedRect(x + 8, y, panelWidth - 16, totalBandHeight, 6).fill('#e6f5f2');
  doc.fillColor('#0f766e').font('Helvetica-Bold').fontSize(10.6).text('TOTAL NOTA', x + 16, y + 9, { width: 92 });
  doc.fillColor('#0f766e').font('Helvetica-Bold').fontSize(10.6).text(currency(nota.total_amount), x + 108, y + 9, {
    width: panelWidth - 124,
    align: 'right'
  });
  doc.roundedRect(x, panelY, panelWidth, panelHeight, 8).stroke('#d8dee6');
  doc.restore();
  doc.y = panelY + panelHeight + 10;
}

async function generateNotaPdf(nota, bons) {
  const doc = new PDFDocument({
    size: 'A4',
    margin: A4_MARGIN,
    bufferPages: true
  });

  const columns = [
    { label: 'Tanggal', width: 54 },
    { label: 'No Tiket', width: 68 },
    { label: 'Plat', width: 62 },
    { label: 'Driver / Relasi', width: 98 },
    { label: 'Netto', width: 58, align: 'right' },
    { label: 'Harga', width: 78, align: 'right' },
    { label: 'Total', width: 105, align: 'right' }
  ];

  doc.save();
  doc.rect(0, 0, doc.page.width, 96).fill('#f8fafc');
  doc.restore();

  doc.fillColor('#111827').font('Helvetica-Bold').fontSize(18).text('NOTA TIMBANGAN', A4_MARGIN, 34, {
    width: 260
  });
  doc.fillColor('#475467').font('Helvetica').fontSize(9).text('Pembukuan TBS', A4_MARGIN, 58, {
    width: 220
  });
  doc.fillColor('#0f766e').font('Helvetica-Bold').fontSize(12).text(nota.invoice_number || '-', A4_MARGIN + 290, 36, {
    width: 233,
    align: 'right'
  });
  doc.fillColor('#667085').font('Helvetica').fontSize(8.5).text(date(nota.invoice_date || nota.created_at), A4_MARGIN + 290, 55, {
    width: 233,
    align: 'right'
  });

  doc.y = 112;
  doc.save();
  doc.roundedRect(A4_MARGIN, doc.y, A4_TABLE_WIDTH, 64, 8).stroke('#d8dee6');
  doc.restore();
  drawInfoPair(doc, 'KEPADA', safeText(nota.recipient_name), A4_MARGIN + 14, doc.y + 13, 230);
  drawInfoPair(doc, 'ALAMAT', safeText(nota.recipient_address), A4_MARGIN + 265, doc.y + 13, 220);
  doc.y += 82;

  drawTableHeader(doc, columns);
  bons.forEach((bon, index) => {
    drawTableRow(
      doc,
      columns,
      [
        date(bon.bon_date),
        bon.ticket_number || '-',
        bon.plate_number || '-',
        `${bon.driver_name || '-'}${bon.relation_name ? ` / ${bon.relation_name}` : ''}`,
        `${number(bon.netto_2)} kg`,
        currency(bon.price),
        currency(bon.total)
      ],
      index
    );
  });

  drawSummary(doc, nota, bons);

  const range = doc.bufferedPageRange();
  for (let i = range.start; i < range.start + range.count; i += 1) {
    doc.switchToPage(i);
    doc.fillColor('#98a2b3').font('Helvetica').fontSize(7.5).text(
      `Halaman ${i + 1} dari ${range.count}`,
      A4_MARGIN,
      818,
      { width: A4_TABLE_WIDTH, align: 'right' }
    );
  }

  return collectPdf(doc);
}

async function generateThermalNotaPdf(nota, bon) {
  const doc = new PDFDocument({
    size: [162, 420],
    margin: 8
  });

  const subtotal = Number(bon.netto_2 || 0) * Number(bon.price || 0);
  const totalBiayaBongkar = Number(bon.netto_1 || 0) * Number(bon.biaya_bongkar || 0);
  const pphPercent = subtotal > 0 ? ((Number(bon.pph || 0) / subtotal) * 100).toFixed(2) : '0.25';

  doc.font('Helvetica-Bold').fontSize(11).text('NOTA TIMBANGAN', { align: 'center' });
  doc.font('Helvetica').fontSize(7).text(`No. ${nota.invoice_number}`, { align: 'center' });
  doc.moveDown(0.6).moveTo(8, doc.y).lineTo(154, doc.y).stroke().moveDown(0.6);
  doc.fontSize(8).text(`Kepada: ${nota.recipient_name || '-'}`);
  doc.text(`Tanggal: ${date(nota.created_at || nota.invoice_date)}`);
  doc.moveDown(0.6);
  doc.font('Helvetica-Bold').text('Subtotal:');
  doc.font('Helvetica').text(`${number(bon.netto_2)} Kg x ${currency(bon.price)}`);
  doc.text(currency(subtotal), { align: 'right' });
  doc.moveDown(0.5);
  doc.font('Helvetica-Bold').text('Potongan:');
  doc.font('Helvetica').fontSize(7.5);
  doc.text(`PPh (${pphPercent}%): ${currency(bon.pph)}`);
  doc.text(`SPSI (${number(bon.netto_1)} Kg x ${currency(bon.biaya_bongkar)}): ${currency(totalBiayaBongkar)}`);
  doc.text(`BP: ${currency(bon.bp_colt)}`);
  doc.text(`Uang minum: ${currency(bon.uang_minum)}`);
  doc.text(`DP / Panjar: ${currency(bon.dp)}`);
  (bon.bon_deductions || []).forEach((deduction) => {
    doc.text(`${deduction.label}: ${currency(deduction.amount)}`);
  });
  doc.moveDown(0.6).moveTo(8, doc.y).lineTo(154, doc.y).stroke().moveDown(0.4);
  doc.font('Helvetica-Bold').fontSize(10).text(`TOTAL ${currency(nota.total_amount)}`, { align: 'right' });
  doc.moveDown().font('Helvetica-Oblique').fontSize(8).text('TERIMA KASIH', { align: 'center' });

  return collectPdf(doc);
}

module.exports = { generateNotaPdf, generateThermalNotaPdf };
