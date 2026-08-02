#!/bin/bash
set +H
APIKEY="${SUPABASE_ANON_KEY:?Set SUPABASE_ANON_KEY before running this script}"
for ep in /api/pg /pg /api/v1/pg /meta /api/meta /api/v1/meta; do
  echo "--- $ep ---"
  curl -s "https://supabase.langkatkab.go.id$ep" --header "apikey: $APIKEY" --header "Accept: application/json" | head -3
  echo ""
done
