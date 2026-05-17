# 🔒 Security Guide - Mengamankan Kredensial

## ⚠️ Penting: Jangan Pernah Commit Kredensial ke Git!

Project ini mengandung kredensial sensitif (API keys, passwords, tokens) yang HARUS diamankan sebelum push ke repository publik.

---

## 📋 Daftar File yang Harus Diamankan

### ✅ Yang Sudah Di-Gitignore
- `android/key.properties` - Android keystore credentials
- `android/local.properties` - Local SDK paths
- `android/**/*.keystore` dan `**/*.jks` - Keystore files
- `app_express/.env` - Node/Express environment variables
- `.env` dan `.env.local` - Root environment files

### ⚠️ TINDAKAN DIPERLUKAN SEGERA

Jika Anda sudah commit file-file di atas sebelumnya, **SEGERA RESET** kredensial:

```bash
# 1. Lakukan git history rewrite (hati-hati!)
git filter-branch --tree-filter 'rm -f android/key.properties' HEAD

# ATAU lebih aman: buat repo baru dan push ulang

# 2. Reset semua password yang terbuka
# - Change Android keystore password
# - Regenerate Supabase anon keys
# - Generate new API keys
# - Change database credentials
```

---

## 🚀 Setup Lokal untuk Development

### 1. Flutter App Setup (lib/config/env_config.dart)

Gunakan `--dart-define` untuk pass credentials saat run/build:

```bash
# Development (lokal)
flutter run \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGc... \
  --dart-define=SUPABASE_SCHEMA=inv

# Release build
flutter build apk \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGc... \
  --dart-define=SUPABASE_SCHEMA=inv
```

**Jangan** simpan credentials di file! Gunakan CI/CD secrets atau pass manual saat build.

### 2. Android Release Configuration

Buat file `android/key.properties` (jangan commit!):

```properties
# Copy dari key.properties.example dan isi dengan credential lokal Anda
RELEASE_STORE_FILE=/absolute/path/to/your.keystore
RELEASE_STORE_PASSWORD=your_secure_password
RELEASE_KEY_ALIAS=your_alias
RELEASE_KEY_PASSWORD=your_key_password
```

**Setup CI/CD Secret:** Di GitHub Actions, simpan keystore credentials sebagai secret dan inject saat build.

### 3. Express App Setup (app_express)

Buat `.env` file di `app_express/`:

```bash
cd app_express
cp .env.example .env
```

Edit `.env` dengan credentials lokal Anda:

```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=eyJhbGc...
SUPABASE_SCHEMA=inv
SESSION_SECRET=your-random-secret-min-32-chars
EXTERNAL_API_KEY=your-random-api-key-min-32-chars
SUPABASE_API_USER_EMAIL=api@your-company.com
SUPABASE_API_USER_PASSWORD=secure_password_here
```

**PENTING:** `.env` file TIDAK boleh di-commit (sudah di .gitignore).

---

## 🔐 Credential Management Best Practices

### Untuk Development

```bash
# Simpan di local machine variables (jangan di repo)
export SUPABASE_URL="https://your-project.supabase.co"
export SUPABASE_ANON_KEY="eyJhbGc..."
export SUPABASE_SCHEMA="inv"

# Run Flutter dengan env vars
flutter run \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY \
  --dart-define=SUPABASE_SCHEMA=$SUPABASE_SCHEMA
```

### Untuk Production / CI/CD

**GitHub Actions Example:**

```yaml
name: Build Release APK

on: [workflow_dispatch]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x'
      
      - run: flutter pub get
      
      - name: Build APK
        run: |
          flutter build apk \
            --dart-define=SUPABASE_URL=${{ secrets.SUPABASE_URL }} \
            --dart-define=SUPABASE_ANON_KEY=${{ secrets.SUPABASE_ANON_KEY }} \
            --dart-define=SUPABASE_SCHEMA=inv
        env:
          KEY_STORE_PASSWORD: ${{ secrets.ANDROID_KEYSTORE_PASSWORD }}
          KEY_PASSWORD: ${{ secrets.ANDROID_KEY_PASSWORD }}
```

**GitHub Secrets Setup:**
1. Go to Settings → Secrets and variables → Actions
2. Add these secrets:
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
   - `ANDROID_KEYSTORE_PASSWORD`
   - `ANDROID_KEY_PASSWORD`

### Untuk Express Backend

Gunakan `.env` file lokal dengan environment-specific values:

```bash
# .env.production (jangan commit!)
NODE_ENV=production
SUPABASE_URL=https://prod-project.supabase.co
SESSION_SECRET=generated-random-string-here
```

---

## ✅ Pre-Commit Checklist

Sebelum `git push`, pastikan:

- [ ] Tidak ada `.env` file (hardcoded credentials) 
- [ ] Tidak ada `android/key.properties` 
- [ ] Tidak ada hardcoded tokens di source code
- [ ] `.gitignore` sudah updated dengan semua file sensitif
- [ ] `.env.example` ada untuk dokumentasi apa saja yang dibutuhkan
- [ ] Semua credentials menggunakan environment variables / dart-define

**Verifikasi dengan:**
```bash
# Check apa yang akan di-commit
git status

# Atau gunakan tool seperti git-secrets
git secrets --scan
```

---

## 🔄 Git History Cleanup (jika sudah terlanjur commit)

Jika credentials sudah masuk ke git history:

```bash
# OPSI 1: BFG Repo Cleaner (recommended)
bfg --delete-files android/key.properties

# OPSI 2: git filter-branch (slow tapi standard)
git filter-branch --tree-filter 'rm -f android/key.properties' -f HEAD

# OPSI 3: Buat repo baru (safest)
git clone --mirror https://github.com/old-repo.git
cd old-repo.git
git push --mirror https://github.com/new-repo.git
```

Setelah cleanup:
```bash
# Force push (hati-hati - coordinate dengan team)
git push --force --all origin
git push --force --tags origin
```

---

## 📚 Referensi Keamanan

- [OWASP: Sensitive Data Exposure](https://owasp.org/Top10/A02_2021-Cryptographic_Failures/)
- [Git Secrets - AWS](https://github.com/awslabs/git-secrets)
- [Flutter Security](https://flutter.dev/docs/testing/security-testing)
- [Supabase Auth Best Practices](https://supabase.com/docs/guides/auth)

---

## 🆘 Emergency: Credentials Leaked?

Jika credentials terbuka di publik:

1. **SEGERA rotate credentials:**
   - Regenerate Supabase API keys
   - Change keystore password
   - Reset API keys
   - Change database passwords

2. **Audit logs:**
   - Check siapa yang access resources
   - Monitor untuk suspicious activity

3. **Notify team:**
   - Inform team tentang security incident
   - Update semua .env files dengan new credentials

4. **Update git history:**
   - Gunakan BFG atau filter-branch untuk remove from history
   - Force push ke repository

---

**Last Updated:** May 17, 2026  
**Version:** 1.0
