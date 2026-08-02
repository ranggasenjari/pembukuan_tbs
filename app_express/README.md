# Pembukuan Express

Web app ExpressJS untuk menjalankan fungsi utama aplikasi Flutter Pembukuan TBS.

## Setup

### 1. Install Dependencies
```bash
cd app_express
npm install
```

### 2. Configure Environment Variables

**⚠️ SECURITY WARNING:** Jangan pernah commit `.env` file ke Git!

```bash
# Copy template
cp .env.example .env

# Edit dengan text editor favorit Anda
# Isi dengan credentials lokal:
# - SUPABASE_URL: Dapatkan dari Supabase project settings
# - SUPABASE_ANON_KEY: Dapatkan dari Supabase API keys
# - SUPABASE_SCHEMA: Schema database aplikasi, default inv
# - SESSION_SECRET: Generate random string (min 32 chars)
# - EXTERNAL_API_KEY: Generate random string (min 32 chars)
# - SUPABASE_API_USER_EMAIL: Email user sistem untuk API
# - SUPABASE_API_USER_PASSWORD: Password user sistem (JANGAN sama dengan other users!)
# - BASE_PATH: Isi jika app dipublish di subpath, contoh /bon
```

**Minimal required variables di `.env`:**
```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
SUPABASE_SCHEMA=inv
SESSION_SECRET=very-long-random-secret-at-least-32-characters
EXTERNAL_API_KEY=very-long-random-api-key-at-least-32-characters
SUPABASE_API_USER_EMAIL=api-user@your-company.com
SUPABASE_API_USER_PASSWORD=secure-password-for-api-user
BASE_PATH=/bon
```

Jika dipasang di reverse proxy path `/bon/`, set `BASE_PATH=/bon` agar redirect, asset, form, PDF, dan API memakai prefix yang sama.

### 3. Run Development Server

```bash
npm run dev
# Server akan run di http://localhost:3000
```

### ✅ Security Checklist

- [ ] `.env` file tidak di-git (sudah di .gitignore)
- [ ] Semua credentials di `.env` (bukan hardcoded di source)
- [ ] SESSION_SECRET adalah random string yang unik per environment
- [ ] EXTERNAL_API_KEY adalah random string yang unik
- [ ] SUPABASE_API_USER_EMAIL berbeda dari user authentication reguler
- [ ] Tidak ada credentials di `.env.example` (hanya placeholders)

### 🔒 Production Deployment

Di production (Railway, Heroku, etc):
1. **Jangan** gunakan `.env` file
2. Set environment variables di platform dashboard:
   - Railway: Project → Variables
   - Heroku: Settings → Config Vars
   - Docker: `docker run -e SUPABASE_URL=...`
3. Rotate credentials setiap 3-6 bulan
4. Monitor API key usage di Supabase dashboard

Untuk lebih lengkap, baca [SECURITY.md](../docs/SECURITY.md) dan [DEPLOY.md](docs/DEPLOY.md).

## Fitur

- Supabase Auth email/password
- Dashboard pembukuan
- CRUD slip/bon timbangan, nota, pembayaran, saldo, margin, dan pengeluaran
- Upload foto bon dan bukti pembayaran ke Supabase Storage
- OCR bon via webhook n8n
- PDF nota A4 dan thermal
- Laporan buku besar realtime dengan SSE
