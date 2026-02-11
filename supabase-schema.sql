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

create table if not exists public.ab_user_features (
  user_id uuid not null references auth.users(id) on delete cascade,
  feature_key text not null,
  is_enabled boolean not null default true,
  updated_at timestamptz not null default now(),
  primary key (user_id, feature_key)
);

create table if not exists public.ab_segment_params (
  param_key text primary key,
  display_name text not null,
  data_type text not null default 'date',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.ab_segment_rollouts (
  feature_key text not null,
  param_key text not null references public.ab_segment_params(param_key) on delete restrict,
  operator text not null check (operator in ('gt', 'gte', 'lt', 'lte', 'eq')),
  value_text text not null,
  rollout_percent int not null check (rollout_percent >= 0 and rollout_percent <= 100),
  is_enabled boolean not null default true,
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now(),
  primary key (feature_key, param_key)
);

create table if not exists public.app_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.ab_features (
  feature_key text primary key,
  display_name text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.user_onboarding (
  user_id uuid primary key references auth.users(id) on delete cascade,
  exam_target text,
  daily_practice_time text,
  completed_at timestamptz,
  updated_at timestamptz not null default now()
);

alter table public.files enable row level security;
alter table public.file_progress enable row level security;
alter table public.ab_test_configs enable row level security;
alter table public.ab_user_features enable row level security;
alter table public.ab_segment_params enable row level security;
alter table public.ab_segment_rollouts enable row level security;
alter table public.app_admins enable row level security;
alter table public.ab_features enable row level security;
alter table public.user_onboarding enable row level security;

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

drop policy if exists "users_read_own_ab_user_features" on public.ab_user_features;
create policy "users_read_own_ab_user_features"
on public.ab_user_features
for select
using (auth.uid() = user_id);

drop policy if exists "admins_manage_ab_user_features" on public.ab_user_features;
create policy "open_write_ab_user_features"
on public.ab_user_features
for all
using (true)
with check (true);

drop policy if exists "read_ab_segment_params_authenticated" on public.ab_segment_params;
create policy "read_ab_segment_params_authenticated"
on public.ab_segment_params
for select
using (auth.role() = 'authenticated');

drop policy if exists "admins_write_ab_segment_params" on public.ab_segment_params;
create policy "admins_write_ab_segment_params"
on public.ab_segment_params
for all
using (exists (select 1 from public.app_admins a where a.user_id = auth.uid()))
with check (exists (select 1 from public.app_admins a where a.user_id = auth.uid()));

drop policy if exists "read_ab_segment_rollouts_authenticated" on public.ab_segment_rollouts;
create policy "read_ab_segment_rollouts_authenticated"
on public.ab_segment_rollouts
for select
using (auth.role() = 'authenticated');

drop policy if exists "admins_write_ab_segment_rollouts" on public.ab_segment_rollouts;
create policy "admins_write_ab_segment_rollouts"
on public.ab_segment_rollouts
for all
using (exists (select 1 from public.app_admins a where a.user_id = auth.uid()))
with check (exists (select 1 from public.app_admins a where a.user_id = auth.uid()));

drop policy if exists "users_view_own_admin_row" on public.app_admins;
create policy "users_view_own_admin_row"
on public.app_admins
for select
using (auth.uid() = user_id);

drop policy if exists "read_ab_features_authenticated" on public.ab_features;
create policy "read_ab_features_authenticated"
on public.ab_features
for select
using (auth.role() = 'authenticated');

drop policy if exists "admins_write_ab_features" on public.ab_features;
create policy "admins_write_ab_features"
on public.ab_features
for all
using (exists (select 1 from public.app_admins a where a.user_id = auth.uid()))
with check (exists (select 1 from public.app_admins a where a.user_id = auth.uid()));

drop policy if exists "users_manage_own_onboarding" on public.user_onboarding;
create policy "users_manage_own_onboarding"
on public.user_onboarding
for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create or replace function public.apply_ab_segment_rollout(
  p_feature_key text,
  p_param_key text,
  p_operator text,
  p_value_text text,
  p_rollout_percent int,
  p_is_enabled boolean default true
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_feature_key text;
  v_param_key text;
  v_operator text;
  v_rollout int;
  v_value_date date;
  v_total_users int := 0;
  v_matched_users int := 0;
  v_enabled_users int := 0;
begin
  if not (
    auth.role() = 'service_role'
    or exists (select 1 from public.app_admins a where a.user_id = auth.uid())
  ) then
    raise exception 'Not authorized to apply segment rollout';
  end if;

  v_feature_key := lower(trim(coalesce(p_feature_key, '')));
  v_param_key := lower(trim(coalesce(p_param_key, '')));
  v_operator := lower(trim(coalesce(p_operator, '')));
  v_rollout := greatest(0, least(100, coalesce(p_rollout_percent, 0)));

  if v_feature_key = '' then
    raise exception 'feature_key is required';
  end if;
  if v_param_key = '' then
    raise exception 'param_key is required';
  end if;
  if not (v_operator in ('gt', 'gte', 'lt', 'lte', 'eq')) then
    raise exception 'Invalid operator. Use one of gt, gte, lt, lte, eq';
  end if;

  if not exists (
    select 1
    from public.ab_segment_params p
    where p.param_key = v_param_key
      and p.is_active = true
  ) then
    raise exception 'Unknown or inactive segment param: %', v_param_key;
  end if;

  if v_param_key <> 'created_date' then
    raise exception 'Only created_date is supported currently';
  end if;

  begin
    v_value_date := p_value_text::date;
  exception when others then
    raise exception 'Invalid date value. Use YYYY-MM-DD';
  end;

  insert into public.ab_segment_rollouts (
    feature_key,
    param_key,
    operator,
    value_text,
    rollout_percent,
    is_enabled,
    updated_by,
    updated_at
  )
  values (
    v_feature_key,
    v_param_key,
    v_operator,
    p_value_text,
    v_rollout,
    coalesce(p_is_enabled, true),
    auth.uid(),
    now()
  )
  on conflict (feature_key, param_key)
  do update
  set operator = excluded.operator,
      value_text = excluded.value_text,
      rollout_percent = excluded.rollout_percent,
      is_enabled = excluded.is_enabled,
      updated_by = excluded.updated_by,
      updated_at = now();

  with candidates as (
    select
      u.id as user_id,
      case
        when v_operator = 'gt' then (u.created_at::date > v_value_date)
        when v_operator = 'gte' then (u.created_at::date >= v_value_date)
        when v_operator = 'lt' then (u.created_at::date < v_value_date)
        when v_operator = 'lte' then (u.created_at::date <= v_value_date)
        else (u.created_at::date = v_value_date)
      end as matches_segment
    from auth.users u
  ),
  assignments as (
    select
      c.user_id,
      case
        when not coalesce(p_is_enabled, true) then false
        when not c.matches_segment then false
        else (
          abs((('x' || substr(md5(c.user_id::text || ':' || v_feature_key), 1, 8))::bit(32)::int)) % 100
        ) < v_rollout
      end as is_enabled
    from candidates c
  ),
  upserted as (
    insert into public.ab_user_features (user_id, feature_key, is_enabled, updated_at)
    select a.user_id, v_feature_key, a.is_enabled, now()
    from assignments a
    on conflict (user_id, feature_key)
    do update
    set is_enabled = excluded.is_enabled,
        updated_at = now()
    returning user_id, is_enabled
  )
  select
    (select count(*) from auth.users),
    (select count(*) from candidates where matches_segment),
    (select count(*) from upserted where is_enabled)
  into v_total_users, v_matched_users, v_enabled_users;

  return jsonb_build_object(
    'feature_key', v_feature_key,
    'param_key', v_param_key,
    'operator', v_operator,
    'value', p_value_text,
    'rollout_percent', v_rollout,
    'total_users', v_total_users,
    'matched_users', v_matched_users,
    'enabled_users', v_enabled_users
  );
end;
$$;

revoke all on function public.apply_ab_segment_rollout(text, text, text, text, int, boolean) from public;
grant execute on function public.apply_ab_segment_rollout(text, text, text, text, int, boolean) to authenticated;
grant execute on function public.apply_ab_segment_rollout(text, text, text, text, int, boolean) to service_role;

insert into public.ab_test_configs (feature_key, test_percent, is_enabled)
values ('analytics_library', 100, true)
on conflict (feature_key) do nothing;

insert into public.ab_features (feature_key, display_name, is_active)
values ('analytics_library', 'Analytics (Library)', true)
on conflict (feature_key) do update
set display_name = excluded.display_name,
    is_active = excluded.is_active,
    updated_at = now();

insert into public.ab_segment_params (param_key, display_name, data_type, is_active)
values ('created_date', 'Created Date', 'date', true)
on conflict (param_key) do update
set display_name = excluded.display_name,
    data_type = excluded.data_type,
    is_active = excluded.is_active,
    updated_at = now();
