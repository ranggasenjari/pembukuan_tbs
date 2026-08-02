# Panduan Deploy ke Production

## Server

| Detail | Value |
|--------|-------|
| **Host** | `ns1.langkatkab.go.id` |
| **User** | `supplytanijaya` |
| **App path** | `/home/supplytanijaya/dashboard/bon` |
| **Base URL** | `https://supplytanijaya.web.id/bon/` |
| **Node** | v22.21.1 via nvm (`/home/supplytanijaya/.nvm/versions/node/v22.21.1/bin`) |
| **PM2** | Terinstal di user `supplytanijaya` (bukan root) |

## Stack

- **Express 5** + **EJS** untuk web app + API
- **Supabase** (PostgreSQL schema `inv`) untuk database & storage
- **PM2** untuk process manager
- **NVM** untuk manajemen Node.js

## Cara Deploy

### 1. Build archive

Jalankan dari folder `app_express/`:

```bash
cd app_express
tar czf deploy.tar.gz \
  --exclude=node_modules \
  --exclude=.env \
  --exclude=server.log \
  --exclude=app_express.zip \
  --exclude=tmpdeploy \
  --exclude=scripts/*.js \
  .
```

### 2. Upload & ekstrak + restart

```bash
scp deploy.tar.gz supplytanijaya@ns1.langkatkab.go.id:/home/supplytanijaya/dashboard/bon/deploy.tar.gz
```

```bash
ssh supplytanijaya@ns1.langkatkab.go.id 'export PATH=/home/supplytanijaya/.nvm/versions/node/v22.21.1/bin:$PATH; cd /home/supplytanijaya/dashboard/bon && tar xzf deploy.tar.gz && rm deploy.tar.gz && pm2 restart bon'
```

> **Catatan:** Gunakan **single quotes** di SSH command agar `$PATH` tidak di-expand oleh shell lokal. PATH harus di-set karena SSH session tidak load nvm secara otomatis.

### Cek status

```bash
pm2 list
pm2 logs bon --lines 20
```

## Struktur di Server

```
/home/supplytanijaya/dashboard/bon/
├── src/              # Source code Express
│   ├── app.js        # Entry app
│   ├── server.js     # HTTP server startup
│   ├── config/       # Env, Supabase client, Multer
│   ├── middleware/   # Auth, flash, error handler
│   ├── repositories/ # Data access layer (Supabase queries)
│   ├── routes/       # Route handlers
│   ├── services/     # Business logic, PDF, OCR, format
│   └── views/        # EJS templates
├── public/           # Static files (CSS, JS, images)
├── docs/             # Dokumentasi
├── scripts/          # Utility scripts
├── node_modules/     # Dependencies
├── package.json
├── .env              # Environment variables (tidak di-commit)
└── server.log        # Log output
```

## API

### Endpoints publik (tanpa auth)

| Endpoint | Method | Deskripsi |
|----------|--------|-----------|
| `/api/docs` | GET | Swagger UI |
| `/api/v1/swagger.json` | GET | OpenAPI spec |

### Endpoints dengan auth session (web app)

Semua route di bawah `/bons`, `/notas`, `/payments`, `/deposits`, `/margins`, `/expenses`, `/factories`, `/relation-agents`, `/reports` — membutuhkan session login via Supabase Auth.

### Endpoints API v1 (dengan `x-api-key`)

Prefix: `/api/v1`

Auth via header `x-api-key` (cocok dengan `EXTERNAL_API_KEY` di `.env`).

#### Bon

| Method | Path | Deskripsi |
|--------|------|-----------|
| GET | `/bons` | Daftar bon (filter: `start`, `end`, `q`, `status`) |
| POST | `/bons/ocr` | OCR gambar bon |
| POST | `/bons` | Buat bon baru (multipart) |
| POST | `/bons/from-ocr` | Buat bon dari data OCR eksternal (JSON) |
| GET | `/bons/:id` | Detail bon + relasi |
| PATCH | `/bons/:id` | Update bon |
| DELETE | `/bons/:id` | Hapus bon |

#### Nota

| Method | Path | Deskripsi |
|--------|------|-----------|
| GET | `/notas` | Daftar nota |
| POST | `/notas` | Buat nota |
| GET | `/notas/search/by-recipient` | Cari nota by penerima |
| POST | `/notas/pdf/from-bons` | Buat nota + generate PDF |
| GET | `/notas/:id` | Detail nota |
| PATCH | `/notas/:id` | Update nota |
| DELETE | `/notas/:id` | Hapus nota |
| GET | `/notas/:id/pdf` | PDF A4 |
| GET | `/notas/:id/pdf/thermal` | PDF thermal/struk |

#### Payment, Deposit, Margin, Expense

CRUD standar untuk masing-masing modul.

#### Report & Dashboard

| Method | Path | Deskripsi |
|--------|------|-----------|
| GET | `/reports/ledger` | Data buku besar |
| GET | `/reports/summary` | Ringkasan laporan |
| GET | `/dashboard/summary` | Statistik dashboard |

## Environment Variables (`.env`)

Contoh isi `.env`:

```
SUPABASE_URL=https://supabase.langkatkab.go.id
SUPABASE_ANON_KEY=eyJ...
SUPABASE_SCHEMA=inv
SESSION_SECRET=random-string
EXTERNAL_API_KEY=random-key-untuk-api
SUPABASE_API_USER_EMAIL=api@user
SUPABASE_API_USER_PASSWORD=password
BASE_PATH=/bon
PORT=3000
MAX_UPLOAD_MB=5
OCR_WEBHOOK_URL=https://n8n.langkatkab.go.id/webhook/bon
```

## Modul & Alur Data

```
Bon (BELUM_DIBAYAR)
  → Masuk ke Nota → status jadi TERTAGIH
    → Pembayaran → status nota & bon jadi LUNAS
      → Payment dikaitkan ke Margin (offtaker)
        → Pengeluaran bisa diambil dari margin
          → Saldo bertambah jika kategori DEPOSIT (SALDO)
```

## Catatan Penting

- PATH di SSH session kosong, selalu export PATH nvm sebelum running node/npm/pm2
- Bucket Supabase yang digunakan: `receipts` (foto bon), `payments` (bukti bayar), `cetakan` (PDF harian)
- OCR backend adalah webhook n8n di `OCR_WEBHOOK_URL`, bukan bagian dari repo ini
- Database migration tidak include di repo — schema `inv` harus sudah ada
