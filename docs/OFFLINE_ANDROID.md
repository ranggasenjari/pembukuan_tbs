# Mode Offline dalam Satu Aplikasi

App dibangun sebagai **satu APK** (tidak ada flavor terpisah) yang otomatis
berjalan offline/online. UI, form, dan seluruh komponen memakai layar yang sama;
yang membedakan hanyalah lapisan data (repository).

## Build

```bash
flutter build apk
```

## Prasyarat Cloud

Sebelum distribusi, pastikan sudah diterapkan (lihat `supabase/`):

- Migrasi `supabase/migrations/202608140001_offline_sync.sql`.
- Edge Function `offline-bootstrap`, `offline-sync`, `offline-upload-url`
  ter-deploy di Supabase self-hosted (`volumes/functions/`).

## Alur Kerja Offline-First

- **Tulis** (buat/ubah/hapus bon & nota) selalu disimpan ke SQLCipher lokal
  (keystore) + antrean, lalu disinkronkan ke cloud saat online di background.
- **Baca** bon/nota/pabrik/relasi diambil dari cache lokal yang disegarkan oleh
  koordinator sinkronisasi saat online.
- **Master data** (pabrik, relasi, kendaraan, SPSI) di-cache lewat
  `offline-bootstrap`.
- Fitur di luar scope (dashboard, saldo, pembayaran, pengeluaran, margin,
  pengelolaan pabrik/relasi) tetap berjalan saat online; saat offline muncul
  notifikasi.

## Aktivasi Offline

1. Login online seperti biasa.
2. Setelah berhasil login akan diminta PIN 6 digit (opsional, bisa "Lewati").
3. Saat berikutnya perangkat tidak punya koneksi, buka data lokal dengan PIN.

## Sinkronisasi

Otomatis saat koneksi pulih, saat app dibuka, dan bisa dipicu manual lewat
indikator status di atas layar.