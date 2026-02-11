# Teachmint Cloud Migration (Supabase)

## 1) Create Supabase project
- Create a new project in Supabase.
- In **Authentication > Providers > Email**, keep Email provider enabled.
- For current app behavior (create account instantly), disable email confirmation: **Confirm email = OFF**.

## 2) Create DB tables + policies
- Open **SQL Editor** in Supabase.
- Run `/Users/farhaaan/Documents/New project/supabase-schema.sql`.

## 3) Configure app keys
- Open `/Users/farhaaan/Documents/New project/supabase-config.js`.
- Set:
  - `window.TEACHMINT_SUPABASE_URL`
  - `window.TEACHMINT_SUPABASE_ANON_KEY`

## 4) Redeploy
- Redeploy the same static app.
- Login with same email on different devices. Data will now sync via Supabase.

## Notes
- Auth + file/progress data are now cloud-backed.
- Local browser storage is no longer used for accounts/files/progress.
