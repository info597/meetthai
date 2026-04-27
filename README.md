# Meet Thai — Flutter Starter

This is a minimal starter skeleton for the Meet Thai app (Flutter + Supabase + RevenueCat).

## Prerequisites
- Flutter SDK (stable)
- Supabase project (EU region recommended). Copy your URL and anon key.
- (Optional) RevenueCat project with products: premium_month, gold_month.

## Configure
Set your Supabase credentials via `--dart-define`:

```
flutter run -d chrome   --dart-define=SUPABASE_URL=https://YOUR-PROJECT.supabase.co   --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLIC_ANON_KEY
```

On mobile:
```
flutter run   --dart-define=SUPABASE_URL=https://...   --dart-define=SUPABASE_ANON_KEY=...
```

## SQL Backend
Run the provided `init_meet_thai.sql` in Supabase SQL editor first.

## Folders
- `lib/screens/*` — feature screens
- `lib/services/*` — API helpers
- `lib/widgets/*` — shared UI
- `assets/translations` — i18n ARB files
- `assets/icons` — MTH logo/icon

## Notes
- Replace placeholders with your actual UI.
- Supabase RPCs used here: send_like, send_message, get_profile_photos, get_profile_reels, add_profile_comment, search_profiles, update_last_seen, grant_media_in_chat.
