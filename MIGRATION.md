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

## 5) Enable A/B config table
- Re-run `/Users/farhaaan/Documents/New project/supabase-schema.sql` in Supabase SQL Editor.
- This adds `ab_test_configs` table and policies.

## 6) Use separate A/B control app
- Open `/Users/farhaaan/Documents/New project/ab-control.html` (or hosted `.../ab-control.html`).
- Select feature and set `% of users in test`.
- Save changes. Teachmint app will pick this config for feature rollout.

## 7) Admin-only feature catalog
- Re-run `/Users/farhaaan/Documents/New project/supabase-schema.sql` in Supabase SQL Editor.
- Add your admin UID:

```sql
insert into public.app_admins (user_id)
values ('REPLACE_WITH_ADMIN_UID')
on conflict (user_id) do nothing;
```

- Open `/Users/farhaaan/Documents/New project/ab-admin.html` (or hosted `.../ab-admin.html`).
- Admin can add/edit feature keys and display names shown in A/B Control feature dropdown.

## 8) Onboarding for new signups
- Re-run `/Users/farhaaan/Documents/New project/supabase-schema.sql` in Supabase SQL Editor.
- This adds `user_onboarding` table used between signup and Library page.

## Notes
- Auth + file/progress data are now cloud-backed.
- Local browser storage is no longer used for accounts/files/progress.

## 9) Direct per-user feature targeting (for external platform)
- Re-run `/Users/farhaaan/Documents/New project/supabase-schema.sql` in Supabase SQL Editor.
- New table: `public.ab_user_features`
  - `user_id` (uuid from `auth.users.id`)
  - `feature_key` (example: `analytics_library`)
  - `is_enabled` (true/false)
- App behavior:
  - If a row exists for `(user_id, feature_key)`, that value is used directly.
  - If no row exists, app falls back to rollout config in `ab_test_configs`.

External app can upsert with:

```sql
insert into public.ab_user_features (user_id, feature_key, is_enabled, updated_at)
values ('REPLACE_USER_UUID', 'analytics_library', true, now())
on conflict (user_id, feature_key)
do update set
  is_enabled = excluded.is_enabled,
  updated_at = now();
```

## 10) Segment-based rollout (created_date + % rollout)
- Re-run `/Users/farhaaan/Documents/New project/supabase-schema.sql` in Supabase SQL Editor.
- This adds:
  - `ab_segment_params`: list of allowed segmentation parameters (you control this list).
  - `ab_segment_rollouts`: saved rollout setting per feature+param.
  - RPC function `apply_ab_segment_rollout(...)`.
- Seeded param currently: `created_date`.

### How external platform should use it
1. Load allowed params:
```sql
select param_key, display_name, data_type
from public.ab_segment_params
where is_active = true
order by display_name;
```

2. Apply rollout:
```sql
select public.apply_ab_segment_rollout(
  'analytics_library',  -- feature key
  'created_date',       -- param key
  'gt',                 -- operator: gt/gte/lt/lte/eq
  '2025-01-01',         -- value (YYYY-MM-DD)
  50,                   -- rollout %
  true                  -- feature enabled
);
```

### Result behavior
- Function writes deterministic assignments into `ab_user_features` for all current users.
- For users matching the segment (example: `created_date > 2025-01-01`), only the selected percent (example: 50%) gets `is_enabled=true`.
- Everyone else gets `is_enabled=false` for that feature.
