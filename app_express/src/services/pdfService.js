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

function drawTableHeader(doc, columns, tableWidth) {
  const x = A4_MARGIN;
  const y = doc.y;
  const height = 24;
  const tw = tableWidth || A4_TABLE_WIDTH;

  doc.save();
  doc.rect(x, y, tw, height).fill('#1f2937');
  doc.rect(x, y, tw, height).stroke('#d8dee6');
  doc.fillColor('#ffffff').font('Helvetica-Bold').fontSize(7.4);

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

function drawTableRow(doc, columns, cells, index, tableWidth) {
  const rowHeight = measureRowHeight(doc, cells, columns);
  const tw = tableWidth || A4_TABLE_WIDTH;
  ensureSpace(doc, rowHeight + 8, () => drawTableHeader(doc, columns, tw));

  const x = A4_MARGIN;
  const y = doc.y;
  doc.save();
  if (index % 2 === 1) {
    doc.rect(x, y, tw, rowHeight).fill('#fbfcfd');
  }
  doc.rect(x, y, tw, rowHeight).stroke('#e4e7ec');
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

function measureText(doc, value, width, options = {}) {
  doc.save();
  doc.font(options.font || 'Helvetica').fontSize(options.size || 9);
  const height = doc.heightOfString(safeText(value), {
    width,
    lineGap: options.lineGap || 1
  });
  doc.restore();
  return height;
}

function drawInfoColumn(doc, label, value, x, y, width) {
  doc.fillColor('#667085').font('Helvetica-Bold').fontSize(7.6).text(label, x, y, { width });
  doc.fillColor('#111827').font('Helvetica').fontSize(9).text(safeText(value), x, y + 13, {
    width,
    lineGap: 1
  });
}

function drawNotaInfoPanel(doc, nota) {
  const relAgent = nota.relation_agents || {};
  const accounts = relAgent.relation_agent_accounts || [];
  const rekText = accounts.length
    ? accounts.map((a) => [a.account_name, a.account_number].filter(Boolean).join(' ').trim()).filter(Boolean).join(', ')
    : '-';

  const panelX = A4_MARGIN;
  const panelWidth = A4_TABLE_WIDTH;
  const paddingX = 14;
  const paddingY = 13;
  const gap = 24;
  const colWidth = (panelWidth - paddingX * 2 - gap) / 2;
  const valueWidth = colWidth;
  const recipient = safeText(nota.relation_agents?.name || nota.recipient_name);
  const address = safeText(nota.recipient_address);
  const contentHeight = Math.max(
    measureText(doc, recipient, valueWidth, { size: 9, lineGap: 1 }),
    measureText(doc, address, valueWidth, { size: 9, lineGap: 1 })
  ) + (accounts.length ? 32 : 8);
  const panelHeight = Math.max(66, paddingY * 2 + 13 + contentHeight);

  ensureSpace(doc, panelHeight + 28);
  const panelY = doc.y;

  doc.save();
  doc.roundedRect(panelX, panelY, panelWidth, panelHeight, 8).fillAndStroke('#ffffff', '#d8dee6');
  doc.moveTo(panelX + paddingX + colWidth + gap / 2, panelY + 10)
    .lineTo(panelX + paddingX + colWidth + gap / 2, panelY + panelHeight - 10)
    .stroke('#edf0f3');
  doc.restore();

  drawInfoColumn(doc, 'RELASI/AGEN', recipient, panelX + paddingX, panelY + paddingY, colWidth);
  drawInfoColumn(doc, 'ALAMAT', address, panelX + paddingX + colWidth + gap, panelY + paddingY, colWidth);
  drawInfoColumn(doc, 'REK. BAYAR', rekText, panelX + paddingX, panelY + paddingY + 35, panelWidth - paddingX * 2);
  doc.y = panelY + panelHeight + 18;
}

function summarizeDeductions(bons) {
  const totalBiayaBongkar = bons.reduce((sum, bon) => sum + spsiAmount(bon), 0);
  const totalBpColt = bons.reduce((sum, bon) => sum + Number(bon.bp_colt || 0), 0);
  const totalPph = bons.reduce((sum, bon) => sum + Number(bon.pph || 0), 0);
  const totalUangMinum = bons.reduce((sum, bon) => sum + Number(bon.uang_minum || 0), 0);
  const dynamic = {};

  bons.forEach((bon) => {
    (bon.bon_deductions || []).forEach((deduction) => {
      const label = safeText(deduction.label);
      dynamic[label] = (dynamic[label] || 0) + Number(deduction.amount || 0);
    });
  });

  return [
    ['SPSI / Bongkar', totalBiayaBongkar],
    ['BP/Colt', totalBpColt],
    ['PPh (0.25%)', totalPph],
    ['Uang Minum', totalUangMinum],
    ...Object.entries(dynamic)
  ].filter(([, value]) => Number(value || 0) !== 0);
}

function totalDp(bons) {
  return bons.reduce((sum, bon) => sum + Number(bon.dp || 0), 0);
}

function plainCurrency(value) {
  return new Intl.NumberFormat('id-ID', {
    maximumFractionDigits: 0
  }).format(Number(value || 0));
}

function spsiAmount(bon) {
  if (bon?.spsi_amount !== null && bon?.spsi_amount !== undefined) return Number(bon.spsi_amount || 0);
  return Number(bon?.biaya_bongkar || 0) * Number(bon?.netto_1 || 0);
}

function spsiLabel(bon) {
  if (bon?.spsi_type_name) return `SPSI ${bon.spsi_type_name}`;
  if (bon?.spsi_calculation_mode === 'FIX') return 'SPSI Fix';
  return `SPSI (${number(bon?.netto_1)} Kg x Rp ${plainCurrency(bon?.biaya_bongkar)})`;
}

function slashDate(value) {
  if (!value) return '-';
  return new Intl.DateTimeFormat('id-ID', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric'
  }).format(new Date(value));
}

function shortTime(value) {
  if (!value) return '';
  return new Intl.DateTimeFormat('id-ID', {
    hour: '2-digit',
    minute: '2-digit',
    hour12: false
  }).format(new Date(value)).replace('.', ':');
}

function estimateThermalHeight(nota, bon, deductionCount) {
  const recipientLength = safeText(nota.recipient_name).length;
  const recipientExtra = Math.max(0, Math.ceil((recipientLength - 24) / 24)) * 10;

  const relAgent = nota.relation_agents || {};
  const accounts = relAgent.relation_agent_accounts || [];
  const rekText = accounts.length
    ? accounts.map((a) => [a.account_name, a.account_number].filter(Boolean).join(' ').trim()).filter(Boolean).join(', ')
    : '-';
  const rekLength = rekText.length;
  const rekExtra = Math.max(0, Math.ceil((rekLength - 24) / 24)) * 10;

  return Math.max(340, 260 + recipientExtra + rekExtra + deductionCount * 11);
}

function drawThermalDivider(doc, y, dashed = false) {
  doc.save();
  if (dashed) doc.dash(2, { space: 2 });
  doc.moveTo(4, y).lineTo(158, y).lineWidth(dashed ? 0.5 : 1).stroke('#111111');
  doc.undash();
  doc.restore();
}

function drawThermalInfoRow(doc, label, value, y) {
  const labelWidth = 52;
  const valueX = 56;
  const valueWidth = 94;

  doc.font('Helvetica').fontSize(8).fillColor('#111111');
  doc.text(label, 4, y, { width: labelWidth });
  doc.font(label === 'Relasi/Agen' ? 'Helvetica-Bold' : 'Helvetica').text(`: ${safeText(value)}`, valueX, y, {
    width: valueWidth
  });
  return y + Math.max(
    doc.heightOfString(label, { width: labelWidth }),
    doc.heightOfString(`: ${safeText(value)}`, { width: valueWidth })
  ) + 2;
}

function drawThermalAmountRow(doc, label, value, y, options = {}) {
  const labelSize = options.labelSize || 8;
  const valueSize = options.valueSize || 8;
  const leftX = 8;
  const labelWidth = 82;
  const amountX = 95;
  const amountWidth = 55;

  doc.font(options.bold ? 'Helvetica-Bold' : 'Helvetica').fontSize(labelSize).fillColor('#111111');
  doc.text(label, leftX, y, { width: labelWidth, lineGap: 0 });
  doc.font(options.valueBold ? 'Helvetica-Bold' : 'Helvetica').fontSize(valueSize).text(value, amountX, y, {
    width: amountWidth,
    align: 'right',
    lineGap: 0
  });

  return y + Math.max(
    doc.heightOfString(label, { width: labelWidth, lineGap: 0 }),
    doc.heightOfString(value, { width: amountWidth, lineGap: 0 })
  ) + 2;
}

function drawSummary(doc, nota, bons) {
  const deductionRows = summarizeDeductions(bons);
  const subtotal = bons.reduce((sum, bon) => sum + Number(bon.netto_2 || 0) * Number(bon.price || 0), 0);
  const totalDeductions = deductionRows.reduce((sum, [, value]) => sum + Number(value || 0), 0);
  const panelWidth = 250;
  const x = A4_MARGIN + A4_TABLE_WIDTH - panelWidth;
  const rowHeight = 16;
  const dpAmount = totalDp(bons);
  const rows = [
    ['Subtotal Bruto', subtotal],
    ...deductionRows,
    ['Total Potongan', totalDeductions]
  ];
  const padding = 12;
  const titleHeight = 19;
  const dividerGap = 11;
  const totalBandHeight = 32;
  const dpRowsHeight = dpAmount > 0 ? 36 : 0;
  const bottomPadding = 12;
  const panelHeight =
    padding +
    titleHeight +
    rows.length * rowHeight +
    dividerGap +
    totalBandHeight +
    dpRowsHeight +
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

  const totalNotaBeforeDp = Number(nota.total_amount) + dpAmount;
  doc.roundedRect(x + 8, y, panelWidth - 16, totalBandHeight, 6).fill('#e6f5f2');
  doc.fillColor('#0f766e').font('Helvetica-Bold').fontSize(10.6).text('TOTAL NOTA', x + 16, y + 9, { width: 92 });
  doc.fillColor('#0f766e').font('Helvetica-Bold').fontSize(10.6).text(currency(totalNotaBeforeDp), x + 108, y + 9, {
    width: panelWidth - 124,
    align: 'right'
  });

  y += totalBandHeight + 6;
  if (dpAmount > 0) {
    doc.fillColor('#475467').font('Helvetica').fontSize(8.2).text('DP / Panjar', x + 12, y, { width: 112 });
    doc.fillColor('#111827').font('Helvetica').fontSize(8.2).text(currency(dpAmount), x + 124, y, { width: panelWidth - 136, align: 'right' });
    y += 16;
    doc.fillColor('#111827').font('Helvetica-Bold').fontSize(9.5).text('Total Akhir', x + 12, y, { width: 112 });
    doc.fillColor('#111827').font('Helvetica-Bold').fontSize(9.5).text(currency(Number(nota.total_amount)), x + 124, y, { width: panelWidth - 136, align: 'right' });
    y += 20;
  }

  const statusLabel = nota.status === 'LUNAS' ? 'LUNAS' : 'MENUNGGU BAYAR';
  const statusColor = nota.status === 'LUNAS' ? '#16a34a' : '#ea580c';
  doc.fillColor(statusColor).font('Helvetica-Bold').fontSize(8.6).text(statusLabel, x + 16, y, { width: panelWidth - 32, align: 'right' });

  doc.roundedRect(x, panelY, panelWidth, panelHeight, 8).stroke('#d8dee6');
  doc.restore();
  doc.y = panelY + panelHeight + 10;
}

async function generateNotaPdf(nota, bons) {
  const doc = new PDFDocument({
    size: 'A4',
    margin: A4_MARGIN
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
  drawNotaInfoPanel(doc, nota);

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

  return collectPdf(doc);
}

async function generateThermalNotaPdf(nota, bon) {
  const deductions = (bon.bon_deductions || []).map((deduction) => ({
    label: safeText(deduction.label),
    amount: Number(deduction.amount || 0)
  }));
  const pageHeight = estimateThermalHeight(nota, bon, deductions.length);
  const doc = new PDFDocument({
    size: [162, pageHeight],
    margins: {
      top: 10,
      bottom: 10,
      left: 4,
      right: 4
    }
  });

  const subtotal = Number(bon.netto_2 || 0) * Number(bon.price || 0);
  const spsiResult = spsiAmount(bon);
  const pphPercent = subtotal > 0 ? ((Number(bon.pph || 0) / subtotal) * 100).toFixed(2) : '0.25';
  const pphDisplay = Number(pphPercent) > 0 ? pphPercent : '0.25';
  const notaDate = nota.created_at || nota.invoice_date;

  let y = 10;

  doc.fillColor('#111111');
  doc.font('Helvetica-Bold').fontSize(12).text('NOTA TIMBANGAN', 4, y, {
    width: 154,
    align: 'center'
  });
  y += 14;

  doc.font('Helvetica-Oblique').fontSize(6).text(`No. ${safeText(nota.invoice_number)}`, 4, y, {
    width: 154,
    align: 'center'
  });
  y += 10;
  drawThermalDivider(doc, y);
  y += 7;

  y = drawThermalInfoRow(doc, 'Relasi/Agen', nota.relation_agents?.name || nota.recipient_name || '-', y);
  y = drawThermalInfoRow(doc, 'Tanggal', `${slashDate(notaDate)} ${shortTime(notaDate)}`.trim(), y);
  const relAgent = nota.relation_agents || {};
  const accounts = relAgent.relation_agent_accounts || [];
  const rekText = accounts.length
    ? accounts.map((a) => [a.account_name, a.account_number].filter(Boolean).join(' ').trim()).filter(Boolean).join(', ')
    : '-';
  y = drawThermalInfoRow(doc, 'Rek. Bayar', rekText, y);
  y += 6;
  drawThermalDivider(doc, y, true);
  y += 6;

  doc.font('Helvetica-Bold').fontSize(8).text('Subtotal:', 4, y, { width: 154 });
  y += 12;
  y = drawThermalAmountRow(
    doc,
    `${number(bon.netto_2)} Kg x Rp ${plainCurrency(bon.price)}`,
    `Rp ${plainCurrency(subtotal)}`,
    y
  );

  y += 6;
  doc.font('Helvetica-Bold').fontSize(8).text('Potongan:', 4, y, { width: 154 });
  y += 12;

  y = drawThermalAmountRow(doc, `PPh (${pphDisplay}%)`, plainCurrency(bon.pph), y, { labelSize: 7.5 });
  y = drawThermalAmountRow(
    doc,
    spsiLabel(bon),
    plainCurrency(spsiResult),
    y,
    { labelSize: 7 }
  );
  y = drawThermalAmountRow(doc, 'BP', plainCurrency(bon.bp_colt), y);
  y = drawThermalAmountRow(doc, 'Uang minum', plainCurrency(bon.uang_minum), y);
  deductions.forEach((deduction) => {
    y = drawThermalAmountRow(doc, deduction.label, plainCurrency(deduction.amount), y);
  });

  y += 4;
  drawThermalDivider(doc, y);
  y += 7;

  const dpAmount = Number(bon.dp || 0);
  const totalNotaBeforeDp = Number(nota.total_amount) + dpAmount;
  doc.font('Helvetica-Bold').fontSize(10).text('TOTAL', 4, y, { width: 52 });
  doc.font('Helvetica-Bold').fontSize(10).text(`Rp ${plainCurrency(totalNotaBeforeDp)}`, 56, y, {
    width: 100,
    align: 'right'
  });
  y += 16;

  if (dpAmount > 0) {
    doc.font('Helvetica').fontSize(8).text('DP / Panjar', 4, y, { width: 52 });
    doc.font('Helvetica').fontSize(8).text(`Rp ${plainCurrency(dpAmount)}`, 56, y, { width: 100, align: 'right' });
    y += 14;
    doc.font('Helvetica-Bold').fontSize(9).text('Total Akhir', 4, y, { width: 52 });
    doc.font('Helvetica-Bold').fontSize(9).text(`Rp ${plainCurrency(Number(nota.total_amount))}`, 56, y, { width: 100, align: 'right' });
    y += 16;
  }

  const statusLabel = nota.status === 'LUNAS' ? 'LUNAS' : 'MENUNGGU BAYAR';
  doc.font('Helvetica-Bold').fontSize(8).fillColor(nota.status === 'LUNAS' ? '#16a34a' : '#ea580c')
    .text(`STATUS: ${statusLabel}`, 4, y, { width: 154, align: 'center' });
  y += 26;

  doc.font('Helvetica-Oblique').fontSize(8).text('TERIMA KASIH', 4, y, {
    width: 154,
    align: 'center'
  });

  return collectPdf(doc);
}

async function generateHarianPdf(bons, summary, filters, factories) {
  const doc = new PDFDocument({ size: 'A4', margin: A4_MARGIN });
  const pageBottom = A4_BOTTOM;
  const pageWidth = A4_TABLE_WIDTH + A4_MARGIN * 2;
  const margin = A4_MARGIN;
  const bodyWidth = A4_TABLE_WIDTH;
  const blue = '#1e3a5f';
  const accent = '#2563eb';
  const gray = '#475569';
  const lightBg = '#f8fafc';

  // ── Header bar ──
  doc.rect(margin, 20, bodyWidth, 48).fill(blue);
  doc.fillColor('#ffffff').font('Helvetica-Bold').fontSize(18).text('REKAP HARIAN', margin + 16, 28, { width: bodyWidth - 32 });
  doc.fillColor('#94a3b8').font('Helvetica').fontSize(8).text(`Dicetak: ${new Date().toLocaleString('id-ID', { timeZone: 'Asia/Jakarta' })}`, margin + 16, 50, { width: bodyWidth - 32, align: 'right' });

  // ── Info bar ──
  const infoY = 80;
  doc.rect(margin, infoY, bodyWidth, 44).fill(lightBg).stroke('#e2e8f0');
  doc.fillColor(gray).font('Helvetica-Bold').fontSize(9);
  doc.text('PERIODE', margin + 12, infoY + 6, { width: 80 });
  doc.text('PABRIK', margin + 200, infoY + 6, { width: 80 });
  doc.text('TOTAL BON', margin + 380, infoY + 6, { width: 80 });
  doc.fillColor('#111827').font('Helvetica').fontSize(10);
  doc.text(`${date(filters.start)}`, margin + 12, infoY + 22, { width: 170 });
  doc.text(filters.factory_name || '-', margin + 200, infoY + 22, { width: 160 });
  doc.text(`${bons.length} slip`, margin + 380, infoY + 22, { width: 100 });

  // ── Table ──
  const columns = [
    { label: '#', width: 24, align: 'center' },
    { label: 'Tanggal', width: 70 },
    { label: 'Plat', width: 78 },
    { label: 'Netto', width: 70, align: 'right' },
    { label: 'Kumulatif', width: 75, align: 'right' },
    { label: 'Harga', width: 85, align: 'right' },
    { label: 'Total', width: 121, align: 'right' }
  ];
  const tableWidth = columns.reduce((s, c) => s + c.width, 0);

  // Register font for number spacing
  doc.y = infoY + 56;
  drawTableHeader(doc, columns, tableWidth);

  let cumulative = 0;
  let totalNetto = 0;
  let totalAmount = 0;
  let pageNum = 1;

  bons.forEach((bon, index) => {
    if (doc.y + 28 > pageBottom) {
      // Footer with page number
      doc.fillColor('#94a3b8').font('Helvetica').fontSize(7).text(`Hal. ${pageNum}`, margin, pageBottom - 10, { width: bodyWidth, align: 'center' });
      pageNum++;
      doc.addPage();
      drawTableHeader(doc, columns, tableWidth);
    }

    const netto = Number(bon.netto_2 || 0);
    cumulative += netto;
    totalNetto += netto;
    totalAmount += Number(bon.total || 0);

    drawTableRow(doc, columns, [
      String(index + 1),
      date(bon.bon_date),
      bon.plate_number || '-',
      `${number(netto)} kg`,
      `${number(cumulative)} kg`,
      currency(bon.price),
      currency(bon.total)
    ], index, tableWidth);
  });

  // ── Total row ──
  const totalRowY = doc.y + 10;
  let cX = margin;
  const nettoCol = columns[3], kumCol = columns[4], totalCol = columns[6];
  const nettoStart = columns.slice(0, 3).reduce((s, c) => s + c.width, 0);
  const kumStart = columns.slice(0, 4).reduce((s, c) => s + c.width, 0);
  const totalStart = columns.slice(0, 6).reduce((s, c) => s + c.width, 0);

  doc.rect(margin, totalRowY, tableWidth, 32).fill(blue);
  doc.fillColor('#ffffff').font('Helvetica-Bold').fontSize(10);
  doc.text('TOTAL', margin + 10, totalRowY + 8, { width: 120 });
  doc.font('Helvetica-Bold').fontSize(9);
  doc.text(`${number(totalNetto)} kg`, margin + nettoStart + 5, totalRowY + 8, { width: nettoCol.width - 10, align: 'right' });
  doc.text(`${number(cumulative)} kg`, margin + kumStart + 5, totalRowY + 8, { width: kumCol.width - 10, align: 'right' });
  doc.text(currency(totalAmount), margin + totalStart + 5, totalRowY + 8, { width: totalCol.width - 10, align: 'right' });

  // ── Footer ──
  doc.fillColor('#94a3b8').font('Helvetica').fontSize(7).text(`Hal. ${pageNum}`, margin, pageBottom - 10, { width: bodyWidth, align: 'center' });

  return collectPdf(doc);
}

module.exports = { generateHarianPdf, generateLedgerPdf, generateNotaPdf, generateThermalNotaPdf };

async function generateLedgerPdf(bons, summary, filters, factories) {
  const doc = new PDFDocument({ layout: 'landscape', margin: A4_MARGIN });
  const pageBottom = doc.page.height - A4_MARGIN;

  const colW = (doc.page.width - 2 * A4_MARGIN);
  const columns = [
    { label: 'Tanggal', width: 75 },
    { label: 'Plat', width: 65 },
    { label: 'Agen/Driver', width: 120 },
    { label: 'Pabrik', width: 110 },
    { label: 'Netto', width: 70, align: 'right' },
    { label: 's/d', width: 75, align: 'right' },
    { label: 'Harga', width: 85, align: 'right' },
    { label: 'Total', width: 95, align: 'right' },
    { label: 'Nota', width: 35, align: 'center' },
    { label: 'Bayar', width: 35, align: 'center' }
  ];

  const titleY = 30;
  doc.fillColor('#000000').font('Helvetica-Bold').fontSize(16).text('BUKU BESAR', A4_MARGIN, titleY, { width: colW, align: 'center' });
  doc.fillColor('#1f2937').font('Helvetica-Bold').fontSize(10).text(`Periode: ${date(filters.start)} - ${date(filters.end)}`, A4_MARGIN, titleY + 22, { width: colW, align: 'center' });
  if (filters.factory_name) {
    doc.fillColor('#1f2937').font('Helvetica').fontSize(10).text(`Pabrik: ${filters.factory_name}`, A4_MARGIN, titleY + 38, { width: colW, align: 'center' });
  }
  doc.y = titleY + (filters.factory_name ? 56 : 50);

  const tableWidth = columns.reduce((s, c) => s + c.width, 0);
  drawTableHeader(doc, columns, tableWidth);

  let cumulative = 0;
  let totalNetto = 0;
  let totalAmount = 0;

  bons.forEach((bon, index) => {
    if (doc.y + 30 > pageBottom) {
      doc.addPage();
      drawTableHeader(doc, columns);
    }

    const netto = Number(bon.netto_2 || 0);
    cumulative += netto;
    totalNetto += netto;
    totalAmount += Number(bon.total || 0);

    const hasNota = bon.nota_items && bon.nota_items.length > 0;
    const hasPayment = hasNota && bon.nota_items[0].notas?.payments?.length > 0;
    const driverLabel = [bon.driver_name, bon.relation_agents?.name].filter(Boolean).join(' / ') || '-';

    drawTableRow(doc, columns, [
      date(bon.bon_date),
      bon.plate_number || '-',
      driverLabel,
      bon.factories?.name || '-',
      `${number(netto)} kg`,
      `${number(cumulative)} kg`,
      currency(bon.price),
      currency(bon.total),
      hasNota ? 'V' : '-',
      hasPayment ? 'V' : '-'
    ], index, tableWidth);
  });

  const totalRowY = doc.y + 12;
  doc.fillColor('#000000').font('Helvetica-Bold').fontSize(10);
  doc.text('TOTAL', A4_MARGIN, totalRowY, { width: columns.slice(0, 4).reduce((s, c) => s + c.width, 0) });
  doc.fillColor('#1f2937').font('Helvetica-Bold').fontSize(9);
  const nettoColEnd = columns.slice(0, 5).reduce((s, c) => s + c.width, 0);
  const sdColEnd = columns.slice(0, 6).reduce((s, c) => s + c.width, 0);
  const totalColEnd = columns.slice(0, 8).reduce((s, c) => s + c.width, 0);
  doc.text(`${number(totalNetto)} kg`, A4_MARGIN + nettoColEnd - 70, totalRowY, { width: 70, align: 'right' });
  doc.text(`${number(cumulative)} kg`, A4_MARGIN + sdColEnd - 75, totalRowY, { width: 75, align: 'right' });
  doc.text(currency(totalAmount), A4_MARGIN + totalColEnd - 95, totalRowY, { width: 95, align: 'right' });

  return collectPdf(doc);
}
