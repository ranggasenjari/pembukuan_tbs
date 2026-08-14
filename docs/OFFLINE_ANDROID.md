# Android Offline Flavor

Build the operational APK with:

```bash
flutter build apk --flavor offline -t lib/main_offline.dart
```

The first activation requires a valid Supabase login and a six-digit local PIN.
The offline build caches only master data; cloud transaction history is not
downloaded. Apply `supabase/migrations/202608140001_offline_sync.sql` and deploy
the three `offline-*` Edge Functions before distributing the APK.
