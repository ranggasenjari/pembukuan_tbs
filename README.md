# Pembukuan TBS

Aplikasi pembukuan TBS berbasis Supabase untuk mencatat bon timbangan, nota, pembayaran, saldo, margin/offtaker, pengeluaran, PDF nota, dan laporan buku besar.

Repository: `git@github.com:ranggasenjari/pembukuan_tbs.git`

## Struktur Project

Project ini terdiri dari 3 aplikasi:

1. **Main folder**: Mobile App Flutter, aplikasi utama untuk operasional harian.
2. **`ledger_report`**: Halaman web buku besar untuk display di TV.
3. **`app_express`**: Versi web dari aplikasi mobile, disertai API untuk integrasi eksternal dan AI Agent.

## Teknologi Utama

- Flutter untuk mobile app.
- ExpressJS + EJS untuk web app dan API eksternal.
- Supabase Auth, Database schema `inv`, dan Storage.
- PDF nota A4/thermal, upload bukti, OCR bon via webhook.

## Menjalankan Project

Mobile app:

```bash
flutter pub get
flutter run
```

Ledger report:

```bash
cd ledger_report
npm install
npm start
```

Web app Express:

```bash
cd app_express
npm install
cp .env.example .env
npm run dev
```

## Konfigurasi

Semua credential disimpan di `.env` masing-masing aplikasi dan tidak boleh di-commit. Isi minimal meliputi:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SCHEMA=inv`
- `SESSION_SECRET` untuk `app_express`
- `EXTERNAL_API_KEY` untuk API eksternal
- `SUPABASE_API_USER_EMAIL` dan `SUPABASE_API_USER_PASSWORD` untuk user sistem API

Dokumentasi API eksternal ada di `app_express/docs/api.md`.

## Catatan

Project ini belum include OCR backend dan Supabase schema/migration. Pastikan backend OCR, tabel schema `inv`, RLS policy, dan bucket Supabase sudah dibuat sebelum deployment penuh.
