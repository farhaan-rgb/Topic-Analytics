-- Teachmint cloud schema (Supabase)

create table if not exists public.files (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  uploaded_at timestamptz not null default now(),
  text_content text not null,
  questions jsonb not null default '[]'::jsonb
);

create index if not exists files_user_uploaded_idx on public.files (user_id, uploaded_at desc);

create table if not exists public.file_progress (
  user_id uuid not null references auth.users(id) on delete cascade,
  file_id text not null references public.files(id) on delete cascade,
  practice_attempted int[] not null default '{}',
  practice_correct int[] not null default '{}',
  practice_first_try_correct int[] not null default '{}',
  practice_time_ms_by_question jsonb not null default '{}'::jsonb,
  review_attempted int[] not null default '{}',
  review_first_try_correct int[] not null default '{}',
  review_time_ms_by_question jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  primary key (user_id, file_id)
);

create table if not exists public.app_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.feature_rules (
  feature_key text primary key,
  suffix_start int not null check (suffix_start >= 0 and suffix_start <= 15),
  suffix_end int not null check (suffix_end >= 0 and suffix_end <= 15),
  is_enabled boolean not null default true,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null
);

alter table public.files enable row level security;
alter table public.file_progress enable row level security;
alter table public.app_admins enable row level security;
alter table public.feature_rules enable row level security;

drop policy if exists "users_manage_own_files" on public.files;
create policy "users_manage_own_files"
on public.files
for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "users_manage_own_progress" on public.file_progress;
create policy "users_manage_own_progress"
on public.file_progress
for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "users_view_own_admin_row" on public.app_admins;
create policy "users_view_own_admin_row"
on public.app_admins
for select
using (auth.uid() = user_id);

drop policy if exists "read_feature_rules_authenticated" on public.feature_rules;
create policy "read_feature_rules_authenticated"
on public.feature_rules
for select
using (auth.role() = 'authenticated');

drop policy if exists "admins_insert_feature_rules" on public.feature_rules;
create policy "admins_insert_feature_rules"
on public.feature_rules
for insert
with check (exists (select 1 from public.app_admins a where a.user_id = auth.uid()));

drop policy if exists "admins_update_feature_rules" on public.feature_rules;
create policy "admins_update_feature_rules"
on public.feature_rules
for update
using (exists (select 1 from public.app_admins a where a.user_id = auth.uid()))
with check (exists (select 1 from public.app_admins a where a.user_id = auth.uid()));

insert into public.feature_rules (feature_key, suffix_start, suffix_end, is_enabled)
values ('analytics_library', 0, 4, true)
on conflict (feature_key) do update
set suffix_start = excluded.suffix_start,
    suffix_end = excluded.suffix_end,
    is_enabled = excluded.is_enabled;
