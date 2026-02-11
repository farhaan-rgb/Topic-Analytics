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

create table if not exists public.ab_test_configs (
  feature_key text primary key,
  test_percent int not null check (test_percent >= 0 and test_percent <= 100),
  is_enabled boolean not null default true,
  updated_at timestamptz not null default now()
);

alter table public.files enable row level security;
alter table public.file_progress enable row level security;
alter table public.ab_test_configs enable row level security;

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

drop policy if exists "read_ab_test_configs_authenticated" on public.ab_test_configs;
create policy "read_ab_test_configs_authenticated"
on public.ab_test_configs
for select
using (auth.role() = 'authenticated');

drop policy if exists "write_ab_test_configs_authenticated" on public.ab_test_configs;
create policy "write_ab_test_configs_authenticated"
on public.ab_test_configs
for all
using (auth.role() = 'authenticated')
with check (auth.role() = 'authenticated');

insert into public.ab_test_configs (feature_key, test_percent, is_enabled)
values ('analytics_library', 100, true)
on conflict (feature_key) do nothing;
