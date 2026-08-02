# 🚀 Development Setup Guide

Project ini mengandung Flutter mobile app dan Express.js backend. Ikuti panduan ini untuk setup lokal development dengan aman.

## 📋 Prerequisites

Pastikan sudah install:
- ✅ Flutter 3.x ([install guide](https://flutter.dev/docs/get-started/install))
- ✅ Dart SDK (bundled dengan Flutter)
- ✅ Android SDK (untuk Android development)
- ✅ Node.js 18+ ([download](https://nodejs.org/))
- ✅ Git

## 🔐 1. Dapatkan Credentials

Hubungi tech lead atau ops untuk dapatkan:
- Supabase URL
- Supabase Anon Key  
- Express API Key
- Database credentials (untuk API user)

**Jangan pernah share credentials via email atau chat!**  
Gunakan password manager atau secure vault yang sudah di-setup team.

---

## 🎯 2. Flutter App Setup

### Option A: Gunakan Script (Recommended - Windows & macOS/Linux)

**Windows:**
```bash
# Edit scripts/dev/run-dev.bat dan isi credentials lokal Anda
# Buka scripts/dev/run-dev.bat dengan text editor, cari EDIT SECTION

# Kemudian run:
scripts/dev/run-dev.bat

# atau untuk device specific:
scripts/dev/run-dev.bat -d <device-id>
```

**macOS/Linux:**
```bash
# Edit scripts/dev/run-dev.sh dan isi credentials lokal Anda
chmod +x scripts/dev/run-dev.sh
scripts/dev/run-dev.sh

# atau untuk device specific:
scripts/dev/run-dev.sh -d <device-id>
```

### Option B: Manual Run (Semua OS)

```bash
# Terminal / Command Prompt

flutter run \
    --dart-define=SUPABASE_URL=https://your-project.supabase.co \
    --dart-define=SUPABASE_ANON_KEY=eyJhbGc... \
    --dart-define=SUPABASE_SCHEMA=inv
```

**Windows PowerShell:**
```powershell
flutter run `
    --dart-define=SUPABASE_URL=https://your-project.supabase.co `
    --dart-define=SUPABASE_ANON_KEY=eyJhbGc... `
    --dart-define=SUPABASE_SCHEMA=inv
```

### Option C: Environment Variables (macOS/Linux)

```bash
# Simpan di ~/.zshrc atau ~/.bashrc
export SUPABASE_URL="https://your-project.supabase.co"
export SUPABASE_ANON_KEY="eyJhbGc..."
export SUPABASE_SCHEMA="inv"

# Reload shell
source ~/.zshrc

# Kemudian run:
flutter run
```

---

## 🎨 3. Express Backend Setup

```bash
cd app_express

# Install dependencies
npm install

# Copy environment template
cp .env.example .env

# Edit .env dengan credentials Anda
# (gunakan text editor favorit)

# Run development server
npm run dev
# Server siap di http://localhost:3000
```

### .env File Template

```env
# Server
NODE_ENV=development
PORT=3000

# Supabase (sama seperti Flutter app)
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=eyJhbGc...
SUPABASE_SCHEMA=inv

# Session (generate unique random string min 32 chars)
SESSION_SECRET=your-random-session-secret-at-least-32-characters

# API Authentication (generate unique random string min 32 chars)
EXTERNAL_API_KEY=your-random-api-key-at-least-32-characters

# System User untuk API operations
SUPABASE_API_USER_EMAIL=api-user@your-domain.com
SUPABASE_API_USER_PASSWORD=secure-password-for-api-user-account

# OCR Service (optional, default value provided)
OCR_WEBHOOK_URL=https://n8n.langkatkab.go.id/webhook/bon

# Upload size limit
MAX_UPLOAD_MB=10
```

**Generate Secure Random Strings:**

```bash
# macOS/Linux:
openssl rand -base64 32

# Windows PowerShell:
[Convert]::ToBase64String((1..32 | ForEach-Object {[byte](Get-Random -Maximum 256)}))

# Online (pastikan tidak sensitive):
https://generate-random.org/
```

---

## ✅ 4. Verify Setup

### Flutter App
```bash
# Check configuration
flutter run --verbose

# Harus terlihat di output:
# SUPABASE_URL=https://your-project.supabase.co
# SUPABASE_ANON_KEY=...
# (pastikan bukan hardcoded default values!)
```

### Express Backend
```bash
# Check server running
curl http://localhost:3000/api/v1/bons
# Harus return error 401 (API key required) atau data valid

# Check environment loaded
npm run dev
# Harus ada output: "Listening on port 3000"
```

---

## 📚 5. Project Structure

```
project-root/
├── lib/                       # Flutter source code
│   ├── main.dart             # App entry point (NO hardcoded credentials)
│   ├── config/
│   │   └── env_config.dart   # Environment configuration
│   ├── features/             # Feature modules
│   ├── models/               # Data models
│   ├── providers/            # Riverpod providers
│   └── services/             # Services layer
│
├── app_express/              # Express.js backend
│   ├── src/
│   │   ├── app.js           # Express app setup
│   │   ├── config/          # Configuration files
│   │   ├── middleware/      # Express middleware
│   │   ├── routes/          # API routes
│   │   └── services/        # Business logic
│   ├── .env.example         # Environment template
│   ├── .env                 # ❌ DON'T COMMIT - Local credentials
│   └── package.json
│
├── android/                  # Android project
│   ├── key.properties.example  # Android keystore template
│   ├── key.properties          # ❌ DON'T COMMIT - Local credentials
│   └── ...
│
├── scripts/dev/run-dev.sh              # 🚀 Development launcher (Linux/macOS)
├── scripts/dev/run-dev.bat             # 🚀 Development launcher (Windows)
├── SECURITY.md             # 🔒 Security documentation
└── ...
```

---

## 🔄 6. Daily Development Workflow

### Start Working on Feature

```bash
# 1. Update Flutter
flutter pub get

# 2. Start Express backend
cd app_express
npm run dev
# Leave running in background

# 3. In new terminal, start Flutter
# Use scripts/dev/run-dev.sh/bat or flutter run --dart-define...

# 4. Start making changes!
```

### Before Committing

```bash
# ✅ Check no credentials exposed
git status
# Harus TIDAK include: .env, key.properties, *.keystore

# ✅ Check git diff
git diff
# Harus TIDAK ada hardcoded API keys atau passwords

# ✅ Run tests
flutter test
cd app_express && npm test

# ✅ Format code
flutter format lib/
cd app_express && npm run lint:fix

# ✅ Now safe to commit!
git add .
git commit -m "feat: description of your changes"
```

---

## 🐛 Troubleshooting

### Flutter Error: "SUPABASE_URL not configured"

**Problem:** 
```
Exception: SUPABASE_URL not configured. Set via: flutter run --dart-define=SUPABASE_URL=your_url
```

**Solution:**
```bash
# Pastikan pass --dart-define saat run
flutter run --dart-define=SUPABASE_URL=https://your-project.supabase.co
```

### Express Error: "Missing required environment variables"

**Problem:**
```
Error: Missing required environment variables: SUPABASE_URL, SUPABASE_ANON_KEY
```

**Solution:**
```bash
# Check .env file exists
ls -la app_express/.env

# Check content
cat app_express/.env

# Jika kosong, copy dari example
cp app_express/.env.example app_express/.env

# Edit dengan credentials yang benar
```

### Connection Refused: Cannot connect to Express from Flutter

**Problem:**
```
ConnectionException: Failed to connect to localhost:3000
```

**Solution:**
```bash
# 1. Check Express running
curl http://localhost:3000/api/v1/bons
# Should return JSON (not connection error)

# 2. Check on emulator/device
# Android emulator: use 10.0.2.2 instead of localhost
# iOS simulator: use localhost or 127.0.0.1
# Real device: use machine's local IP (ipconfig / ifconfig)

# 3. Check firewall
# Allow port 3000 di Windows Defender / macOS firewall
```

---

## 📖 Referensi Lengkap

- **Security:** Baca [SECURITY.md](SECURITY.md)
- **Express Backend:** Baca [app_express/README.md](app_express/README.md)
- **Flutter Official:** https://flutter.dev/docs
- **Supabase Auth:** https://supabase.com/docs/guides/auth
- **Express.js:** https://expressjs.com/

---

## 🤝 Getting Help

Jika stuck:
1. Baca dokumentasi di atas
2. Check [SECURITY.md](SECURITY.md) untuk credential issues
3. Ask tech lead atau team di Discord/Slack
4. **JANGAN share credentials saat asking for help!**

---

**Last Updated:** May 17, 2026  
**Version:** 1.0
