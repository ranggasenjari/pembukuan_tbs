# Modul Aplikasi Pembukuan TBS

Aplikasi ini memiliki **dua versi** dengan fungsi dan modul yang sama:

1. **Flutter** (`lib/`) — Mobile app (Android/iOS/Web)
2. **Node.js Express** (`app_express/`) — Web app (server-rendered EJS) + REST API (`/api/v1`)

---

## Feature Modules

| Modul | Flutter (`lib/features/`) | Express (`app_express/src/routes/`) | Deskripsi |
|-------|--------------------------|--------------------------------------|-----------|
| **Auth** | `auth/login_screen.dart` | `authRoutes.js` | Login email/password via Supabase Auth |
| **Dashboard** | `home/` | `dashboardRoutes.js`, `reportRoutes.js` | Ringkasan saldo, laba, margin, statistik operasional |
| **Bon Timbangan** | `bons/` | `bonRoutes.js` | Slip timbangan — input manual/OCR, hitung PPh, SPSI, BP Colt, uang minum, total |
| **Nota Transaksi** | `notas/` | `notaRoutes.js` | Invoice gabungan bon, cetak PDF A4 & thermal, share WA |
| **Pembayaran** | `payments/` | `paymentRoutes.js` | Catat bayar + upload bukti, validasi saldo, ubah status LUNAS |
| **Margin/Offtaker** | `margins/` | `marginRoutes.js` | Selisih harga jual offtaker vs biaya riil ke petani |
| **Pengeluaran** | `expenses/` | `expenseRoutes.js` | Biaya MITRA/OPERASIONAL, auto-deposit ke saldo |
| **Saldo** | `saldo/` | `depositRoutes.js` | Kelola saldo kas (piutang/kredit) |
| **Relasi/Agen** | `relation_agents/` | `relationAgentRoutes.js` | Master data petani + rekening bank |
| **Relasi Bayar** | `payment_relations/` | `paymentRelationRoutes.js` | Master data pihak pembayaran; tidak dipakai di bon/nota |
| **Angkutan** | `transports/` | `transportRoutes.js` | Master data driver + plat kendaraan |
| **Pabrik** | `factories/` | `factoryRoutes.js` | Master data pabrik + tipe SPSI |
> **Catatan:** Pabrik, Relasi/Agen, dan Angkutan adalah modul **independen** — tidak ada relasi induk-anak di antara ketiganya.

---

## Lapisan Arsitektur

### Flutter (`lib/`)

| Lapisan | Path | Jml | Fungsi |
|---------|------|-----|--------|
| **Models** | `models/` | 10 | Entity classes dengan `fromJson`/`toJson` |
| **Repositories** | `repositories/` | 10 | CRUD via Supabase client |
| **Services** | `services/` | 3 | PDF, WhatsApp, sharing intent |
| **Providers** | `providers/` | 1 | Riverpod DI |
| **Core** | `core/` | 3 | Enums, widgets, utilities |

### Node.js Express (`app_express/src/`)

| Lapisan | Path | Jml | Fungsi |
|---------|------|-----|--------|
| **Config** | `config/` | 3 | Environment, Supabase client, Multer |
| **Middleware** | `middleware/` | 4 | Auth, flash, async handler, external API auth |
| **Repositories** | `repositories/` | 12 | CRUD operations via Supabase JS client |
| **Services** | `services/` | 15 | Business logic: hitung bon, PDF (PDFKit), OCR, upload, format, realtime SSE, API response, dll |
| **Routes** | `routes/` | 11 | HTTP endpoints (web + API v1) |
| **Views** | `views/` | ~20 | EJS templates (server-rendered HTML) |

### Database (Supabase PostgreSQL — `inv` schema)

- **Tabel inti**: `bons`, `notas`, `payments`, `margins`, `expenses`, `deposits`
- **Tabel master**: `relation_agents`, `relation_agent_accounts`, `payment_relations`, `payment_relation_accounts`, `payment_relation_vehicles`, `relation_agent_transports`, `factories`, `factory_spsi_types`
- **Tabel relasi**: `nota_items` (bon↔nota), `bon_deductions`, `expense_margins`

---

## API Endpoints (Express `app_express`)

Selain web UI, Express juga menyediakan REST API di `/api/v1` yang diautentikasi via `x-api-key`:

- `/api/v1/bons` — CRUD + OCR
- `/api/v1/notas` — CRUD + search + PDF genthermal
- `/api/v1/payments` — CRUD + daftar nota tertagih
- `/api/v1/deposits` — CRUD
- `/api/v1/margins` — CRUD + form payments
- `/api/v1/expenses` — CRUD
- `/api/v1/reports/ledger` — Laporan lengkap
- `/api/v1/dashboard/summary` — Ringkasan dashboard

---

## Aliran Data End-to-End

```
Bon (BELUM_DIBAYAR)
  → Masuk ke Nota → status jadi TERTAGIH
    → Pembayaran → status nota & bon jadi LUNAS
      → Payment dikaitkan ke Margin (offtaker)
        → Pengeluaran bisa diambil dari margin
          → Saldo bertambah jika kategori DEPOSIT (SALDO)
```
