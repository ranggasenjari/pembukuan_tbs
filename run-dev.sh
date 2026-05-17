#!/bin/bash
# run-dev.sh - Convenient script untuk run Flutter development dengan credentials

# Instructions:
# 1. Copy file ini ke project root
# 2. chmod +x run-dev.sh
# 3. Edit file ini dan isi SUPABASE_URL dan SUPABASE_ANON_KEY
# 4. Run: ./run-dev.sh [device-id]

# ============================================
# EDIT SECTION: Set credentials lokal Anda
# ============================================

export SUPABASE_URL="${SUPABASE_URL:-https://supabase.langkatkab.go.id}"
export SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-your-anon-key-here}"
export SUPABASE_SCHEMA="${SUPABASE_SCHEMA:-inv}"

# ============================================
# Script logic (jangan edit di bawah ini)
# ============================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if variables are empty
if [ -z "$SUPABASE_URL" ] || [ "$SUPABASE_URL" = "https://supabase.langkatkab.go.id" ]; then
    echo -e "${RED}❌ ERROR: SUPABASE_URL is not set or using default value${NC}"
    echo "Edit run-dev.sh and set your actual SUPABASE_URL"
    exit 1
fi

if [ -z "$SUPABASE_ANON_KEY" ] || [ "$SUPABASE_ANON_KEY" = "your-anon-key-here" ]; then
    echo -e "${RED}❌ ERROR: SUPABASE_ANON_KEY is not set or using default value${NC}"
    echo "Edit run-dev.sh and set your actual SUPABASE_ANON_KEY"
    exit 1
fi

echo -e "${YELLOW}🚀 Starting Flutter development server...${NC}"
echo -e "${GREEN}📍 Supabase: $SUPABASE_URL${NC}"
echo -e "${GREEN}📍 Schema: $SUPABASE_SCHEMA${NC}"

# Get device ID if provided
DEVICE_ID="${1:--d}"

# Run Flutter with dart-define
flutter run \
    --dart-define=SUPABASE_URL=$SUPABASE_URL \
    --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY \
    --dart-define=SUPABASE_SCHEMA=$SUPABASE_SCHEMA \
    $DEVICE_ID

echo -e "${GREEN}✅ Done!${NC}"
