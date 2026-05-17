@echo off
REM run-dev.bat - Convenient script untuk run Flutter development dengan credentials (Windows)

REM Instructions:
REM 1. Copy file ini ke project root
REM 2. Edit file ini dan isi SUPABASE_URL dan SUPABASE_ANON_KEY
REM 3. Run: run-dev.bat [device-id]

REM ============================================
REM EDIT SECTION: Set credentials lokal Anda
REM ============================================

set SUPABASE_URL=https://supabase.langkatkab.go.id
set SUPABASE_ANON_KEY=your-anon-key-here
set SUPABASE_SCHEMA=inv

REM ============================================
REM Script logic (jangan edit di bawah ini)
REM ============================================

if "%SUPABASE_URL%"=="" (
    echo ❌ ERROR: SUPABASE_URL is not set
    echo Edit run-dev.bat and set your actual SUPABASE_URL
    exit /b 1
)

if "%SUPABASE_ANON_KEY%"=="your-anon-key-here" (
    echo ❌ ERROR: SUPABASE_ANON_KEY is using default value
    echo Edit run-dev.bat and set your actual SUPABASE_ANON_KEY
    exit /b 1
)

echo.
echo 🚀 Starting Flutter development server...
echo 📍 Supabase: %SUPABASE_URL%
echo 📍 Schema: %SUPABASE_SCHEMA%
echo.

set DEVICE_ID=%1
if "%DEVICE_ID%"=="" set DEVICE_ID=-d

flutter run ^
    --dart-define=SUPABASE_URL=%SUPABASE_URL% ^
    --dart-define=SUPABASE_ANON_KEY=%SUPABASE_ANON_KEY% ^
    --dart-define=SUPABASE_SCHEMA=%SUPABASE_SCHEMA% ^
    %DEVICE_ID%

echo.
echo ✅ Done!
