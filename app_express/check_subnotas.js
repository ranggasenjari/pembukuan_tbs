const http = require('http');
const url = `http://localhost:3000/api/v2/bons?start=2026-08-01&end=2026-08-19`;
http.get(url, (res) => {
  let data = '';
  res.on('data', (c) => (data += c));
  res.on('end', () => {
    try {
      const arr = JSON.parse(data);
      const withSubs = arr.filter((b) => Array.isArray(b.sub_notas) && b.sub_notas.length > 0);
      console.log('BONS_TOTAL=' + arr.length);
      console.log('BONS_WITH_SUBNOTAS=' + withSubs.length);
      withSubs.slice(0, 5).forEach((b) => {
        console.log('BON ' + b.plate_number + ' ' + b.bon_date + ' sub=' + JSON.stringify(b.sub_notas.map((s) => ({ name: s.name, price: s.price_per_kg, netto: s.netto_2, amount: s.amount }))));
      });
      if (!withSubs.length && arr.length) {
        const sample = arr[0];
        console.log('SAMPLE_BON sub_notas=' + JSON.stringify(sample.sub_notas) + ' typeof=' + (typeof sample.sub_notas));
      }
    } catch (e) {
      console.log('PARSE_ERR ' + e.message);
      console.log('RAW_HEAD ' + data.slice(0, 300));
    }
  });
}).on('error', (e) => console.log('HTTP_ERR ' + e.message));