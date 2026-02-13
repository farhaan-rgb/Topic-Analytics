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

## 5) Onboarding for new signups
- Re-run `/Users/farhaaan/Documents/New project/supabase-schema.sql` in Supabase SQL Editor.
- This adds `user_onboarding` table used between signup and Library page.
  - If you already created this table, add the new column:

```sql
alter table public.user_onboarding
add column if not exists age_group text;
```

```sql
alter table public.user_onboarding
add column if not exists start_subject text;
```

## 6) Question bank (chat onboarding)
- Re-run `/Users/farhaaan/Documents/New project/supabase-schema.sql` in Supabase SQL Editor.
- This adds `question_bank` table used to fetch onboarding chat questions.

## Notes
- Auth + file/progress data are now cloud-backed.
- Local browser storage is no longer used for accounts/files/progress.

## Cleanup (if you previously enabled A/B tables)
Run this in Supabase SQL Editor to remove the old A/B schema:

```sql
drop function if exists public.apply_ab_segment_rollout(
  text, text, text, text, int, boolean
);

drop table if exists public.ab_segment_rollouts;
drop table if exists public.ab_segment_params;
drop table if exists public.ab_user_features;
drop table if exists public.ab_test_configs;
drop table if exists public.ab_features;
drop table if exists public.app_admins;

drop policy if exists "read_ab_test_configs_authenticated" on public.ab_test_configs;
drop policy if exists "write_ab_test_configs_authenticated" on public.ab_test_configs;
drop policy if exists "users_read_own_ab_user_features" on public.ab_user_features;
drop policy if exists "open_write_ab_user_features" on public.ab_user_features;
drop policy if exists "read_ab_segment_params_authenticated" on public.ab_segment_params;
drop policy if exists "admins_write_ab_segment_params" on public.ab_segment_params;
drop policy if exists "read_ab_segment_rollouts_authenticated" on public.ab_segment_rollouts;
drop policy if exists "admins_write_ab_segment_rollouts" on public.ab_segment_rollouts;
drop policy if exists "users_view_own_admin_row" on public.app_admins;
drop policy if exists "read_ab_features_authenticated" on public.ab_features;
drop policy if exists "admins_write_ab_features" on public.ab_features;
```
