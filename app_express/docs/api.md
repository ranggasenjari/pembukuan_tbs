# API Eksternal v1

Base URL lokal: `http://localhost:3000/api/v1`

Jika app dipublish melalui reverse proxy subpath, misalnya `/bon/`, set `BASE_PATH=/bon` dan gunakan base URL `https://domain/bon/api/v1`.

Semua endpoint wajib mengirim header:

```http
X-API-Key: <EXTERNAL_API_KEY>
```

Konfigurasi `.env` yang dibutuhkan:

```env
EXTERNAL_API_KEY=isi-dengan-random-string-panjang
SUPABASE_API_USER_EMAIL=email-user-sistem
SUPABASE_API_USER_PASSWORD=password-user-sistem
```

Respons JSON sukses:

```json
{ "ok": true, "data": {}, "meta": {} }
```

Respons JSON error:

```json
{ "ok": false, "error": { "code": "BAD_REQUEST", "message": "Pesan error" } }
```

Endpoint PDF mengembalikan `application/pdf` saat sukses.

## Bon

### Simpan bon

`POST /bons`

Payload JSON:

```json
{
  "ticket_number": "BON-001",
  "bon_date": "2026-05-16",
  "plate_number": "BK 1234 XY",
  "driver_name": "BUDI",
  "relation_name": "CV MAJU",
  "fruit_origin": "LANGKAT",
  "netto_1": 9000,
  "netto_2": 8500,
  "price": 2500,
  "dp": 100000,
  "biaya_bongkar": 12,
  "bp_colt": 100000,
  "deductions": [
    { "label": "POTONGAN LAIN", "amount": 25000 }
  ]
}
```

Contoh curl:

```bash
curl -X POST http://localhost:3000/api/v1/bons \
  -H "X-API-Key: $EXTERNAL_API_KEY" \
  -H "Content-Type: application/json" \
  -d @bon.json
```

Upload foto memakai multipart field `image`:

```bash
curl -X POST http://localhost:3000/api/v1/bons \
  -H "X-API-Key: $EXTERNAL_API_KEY" \
  -F "ticket_number=BON-001" \
  -F "bon_date=2026-05-16" \
  -F "plate_number=BK 1234 XY" \
  -F "netto_1=9000" \
  -F "netto_2=8500" \
  -F "price=2500" \
  -F "image=@bon.jpg"
```

Endpoint lain:

- `GET /bons?start=2026-05-01&end=2026-05-31&status=BELUM_DIBAYAR&q=BK`
- `GET /bons/:id`
- `PATCH /bons/:id`
- `DELETE /bons/:id`
- `POST /bons/ocr` multipart field `file`

## Nota dan PDF

`bon_codes` selalu berarti `ticket_number`.

Jika kode bon tidak ditemukan, API mengembalikan `404`. Jika kode bon duplikat, API mengembalikan `409`.

### Buat nota dari kode bon

`POST /notas`

```json
{
  "recipient_name": "PT MAKMUR",
  "recipient_address": "MEDAN",
  "bon_codes": ["BON-001", "BON-002"]
}
```

### Buat nota dan langsung cetak PDF

`POST /notas/pdf/from-bons`

```bash
curl -X POST http://localhost:3000/api/v1/notas/pdf/from-bons \
  -H "X-API-Key: $EXTERNAL_API_KEY" \
  -H "Content-Type: application/json" \
  -o nota.pdf \
  -d '{
    "recipient_name": "PT MAKMUR",
    "recipient_address": "MEDAN",
    "bon_codes": ["BON-001", "BON-002"]
  }'
```

Endpoint ini membuat nota dari bon berstatus `BELUM_DIBAYAR`, mengubah status bon menjadi `TERTAGIH`, lalu mengembalikan PDF. Jika nota berisi 1 bon, format otomatis thermal. Jika nota berisi lebih dari 1 bon, format otomatis A4. Header respons berisi `X-Nota-Id`, `X-Invoice-Number`, dan `X-Pdf-Format`.

Endpoint lain:

- `GET /notas`
- `GET /notas/search/by-recipient?recipient_name=PT%20MAKMUR`
- `GET /notas/:id`
- `PATCH /notas/:id`
- `DELETE /notas/:id`
- `GET /notas/:id/pdf`
- `GET /notas/:id/pdf/thermal`

## Pembayaran

Create pembayaran wajib multipart field `proof`.

```bash
curl -X POST http://localhost:3000/api/v1/payments \
  -H "X-API-Key: $EXTERNAL_API_KEY" \
  -F "invoice_id=<nota-id>" \
  -F "payment_date=2026-05-16" \
  -F "amount_paid=1000000" \
  -F "proof=@transfer.jpg"
```

Endpoint:

- `GET /payments`
- `GET /payments/payable-notas`
- `GET /payments/:id`
- `PATCH /payments/:id`
- `DELETE /payments/:id`

## Saldo, Margin, Pengeluaran

Saldo:

- `GET /deposits`
- `POST /deposits`
- `GET /deposits/:id`
- `PATCH /deposits/:id`
- `DELETE /deposits/:id`

Margin:

- `GET /margins`
- `GET /margins/form-payments`
- `POST /margins` dengan `payment_ids`
- `GET /margins/:id`
- `PATCH /margins/:id`
- `DELETE /margins/:id`

Pengeluaran:

- `GET /expenses`
- `POST /expenses` dengan `margin_ids`
- `GET /expenses/:id`
- `PATCH /expenses/:id`
- `DELETE /expenses/:id`

Kategori expense `DEPOSIT (SALDO)` tetap otomatis membuat deposit `source=Deposit dari profit` dan `category=kredit`.

## Laporan

- `GET /reports/ledger?start=2026-05-01&end=2026-05-31`
- `GET /reports/summary?since=2026-05-01`
- `GET /dashboard/summary?start=2026-05-01&end=2026-05-31`
