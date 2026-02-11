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

## 5) Enable admin access for feature targeting
- Open **Authentication > Users** and copy the `UID` of the account that should control flags.
- Run this SQL in **SQL Editor** (replace UID):

```sql
insert into public.app_admins (user_id)
values ('REPLACE_WITH_ADMIN_UID')
on conflict (user_id) do nothing;
```

## 6) Control Analytics visibility by UID suffix
- Login with the admin account.
- Open `/admin.html` in your hosted app.
- Set suffix start/end. Example: `0` to `4` means only users with UID ending hex digit in that range will see Analytics.

## Notes
- Auth + file/progress data are now cloud-backed.
- Local browser storage is no longer used for accounts/files/progress.
