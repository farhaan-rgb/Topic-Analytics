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

create table if not exists public.user_onboarding (
  user_id uuid primary key references auth.users(id) on delete cascade,
  age_group text,
  exam_target text,
  daily_practice_time text,
  start_subject text,
  completed_at timestamptz,
  updated_at timestamptz not null default now()
);

create table if not exists public.question_bank (
  id text primary key,
  exam text not null,
  subject text not null,
  chapter text not null,
  prompt text not null,
  options jsonb not null default '[]'::jsonb,
  correct_option text not null,
  explanation text,
  wrong_explanations jsonb,
  difficulty text not null default 'easy',
  concept text,
  created_at timestamptz not null default now()
);

-- Backfill column for existing installs
alter table public.question_bank
add column if not exists explanation text;
alter table public.question_bank
add column if not exists wrong_explanations jsonb;
alter table public.question_bank
add column if not exists difficulty text;
alter table public.question_bank
add column if not exists concept text;

create index if not exists question_bank_exam_subject_idx on public.question_bank (exam, subject);

alter table public.question_bank enable row level security;

drop policy if exists "read_question_bank_authenticated" on public.question_bank;
create policy "read_question_bank_authenticated"
on public.question_bank
for select
using (auth.role() = 'authenticated');

insert into public.question_bank (id, exam, subject, chapter, prompt, options, correct_option)
values (
  'jee-maths-sets-001',
  'JEE',
  'Maths',
  'Sets, Relations and Functions',
  'Let f(x) = |x^2 - 4x + 3|. The number of points where f(x) is not differentiable is:',
  '["0","1","2","3"]'::jsonb,
  'C'
)
on conflict (id) do nothing;

update public.question_bank
set explanation = 'Step 1: Factor the quadratic: x^2 - 4x + 3 = (x-1)(x-3); zeros at x=1 and x=3.
Step 2: Sign changes of (x-1)(x-3): for x<1 product positive; 1<x<3 product negative; x>3 product positive. So modulus switches sign at x=1 and x=3.
Step 3: Non-differentiable where the inside changes sign → sharp corners at x=1 and x=3. Therefore f(x) is not differentiable at 2 points: x=1, x=3.'
where id = 'jee-maths-sets-001';

update public.question_bank
set wrong_explanations = jsonb_build_object(
  'A', 'You likely treated the expression as a regular polynomial and forgot that absolute value can create sharp corners',
  'B', 'You probably identified only one zero of the quadratic and missed that it changes sign at two points',
  'D', 'You may have counted the vertex as non-differentiable, but smooth turning points are still differentiable'
)
where id = 'jee-maths-sets-001';

update public.question_bank
set difficulty = 'easy',
    concept = 'Absolute value causes non-differentiability where inside changes sign; roots at x=1,3 → 2 corners.'
where id = 'jee-maths-sets-001';

-- Additional starter questions for chat (JEE Maths)
insert into public.question_bank (id, exam, subject, chapter, prompt, options, correct_option, explanation, wrong_explanations, difficulty, concept)
values
('jee-maths-limits-001','JEE','Maths','Limits and Continuity',
 'Evaluate lim_{x→0} (sin x)/x',
 '[{"id":"A","text":"0"},{"id":"B","text":"1"},{"id":"C","text":"∞"},{"id":"D","text":"Does not exist"}]'::jsonb,
 'B',
 'Standard limit: (sin x)/x → 1 as x→0 using series or L''Hospital.',
 jsonb_build_object(
 'A','You may have confused sin x with its numerator going to 0 but denominator also goes to 0.',
 'C','Both numerator and denominator go to 0; the ratio does not blow up.',
 'D','The two-sided limit exists and equals 1.'
),
'easy',
'Fundamental trigonometric limit at zero'),

('jee-maths-derivative-001','JEE','Maths','Differentiation',
 'The derivative of x^3 at x = 1 equals:',
 '[{"id":"A","text":"1"},{"id":"B","text":"2"},{"id":"C","text":"3"},{"id":"D","text":"4"}]'::jsonb,
 'C',
 'd/dx (x^3) = 3x^2, so at x=1 the value is 3.',
 jsonb_build_object(
 'A','x^3 itself is 1 at x=1; derivative is different.',
 'B','Plugging 1 into 2x would be for x^2, not x^3.',
 'D','3x^2 at x=1 is 3, not 4.'
),
'easy',
'Power rule for derivatives'),

('jee-maths-integration-001','JEE','Maths','Definite Integrals',
 '∫₀¹ 2x dx equals:',
 '[{"id":"A","text":"0"},{"id":"B","text":"1"},{"id":"C","text":"2"},{"id":"D","text":"4"}]'::jsonb,
 'B',
 '∫ 2x dx = x². Evaluate 0→1 gives 1²−0 = 1.',
 jsonb_build_object(
   'A','The integral of 2x is not constant zero; limits are positive.',
   'C','2 is the value at upper limit for the integrand, not the area.',
   'D','You likely integrated twice; correct definite value is 1.'
 ),
 'easy',
 'Basic polynomial definite integral'),

('jee-maths-vectors-001','JEE','Maths','Vectors',
 'The dot product of (1,2,3) and (3,2,1) is:',
 '[{"id":"A","text":"6"},{"id":"B","text":"8"},{"id":"C","text":"10"},{"id":"D","text":"12"}]'::jsonb,
 'C',
 'Dot product = 1·3 + 2·2 + 3·1 = 3 + 4 + 3 = 10.',
 jsonb_build_object(
 'A','You added only two terms; there are three components.',
 'B','2·2=4 helps, but include all components to reach 10.',
 'D','That would be 3·3+2·2+1·1; not the given vectors.'
),
'easy',
'Dot product is sum of component-wise products'),

('jee-maths-probability-001','JEE','Maths','Probability',
 'A fair coin is tossed once. Probability of getting a head is:',
 '[{"id":"A","text":"0"},{"id":"B","text":"1/4"},{"id":"C","text":"1/2"},{"id":"D","text":"1"}]'::jsonb,
 'C',
 'A fair coin has two equally likely outcomes; probability of head is 1/2.',
 jsonb_build_object(
 'A','Head is possible; probability is not zero.',
 'B','1/4 would be for two independent events both happening.',
 'D','There is also a chance of tail, so not certain.'
),
'easy',
'Uniform sample space with two outcomes')
on conflict (id) do nothing;

create table if not exists public.chat_question_attempts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  question_id text not null references public.question_bank(id) on delete cascade,
  exam text not null,
  subject text not null,
  chapter text not null,
  correct boolean not null,
  time_ms int,
  created_at timestamptz not null default now()
);

create index if not exists chat_attempts_user_idx on public.chat_question_attempts (user_id);
create index if not exists chat_attempts_user_exam_idx on public.chat_question_attempts (user_id, exam);
create index if not exists chat_attempts_user_chapter_idx on public.chat_question_attempts (user_id, chapter);

alter table public.chat_question_attempts enable row level security;

-- Bulk seed: 5 chapters per subject (Maths, Physics, Chemistry), 5 questions for each difficulty level (easy/medium/hard)
do $$
declare
  maths_chapters text[] := array[
    'Sets, Relations and Functions',
    'Complex Numbers and Quadratic Equations',
    'Limit, Continuity and Differentiability',
    'Integral Calculus',
    'Vector Algebra'
  ];
  physics_chapters text[] := array[
    'Kinematics',
    'Laws of Motion',
    'Work, Energy and Power',
    'Electrostatics',
    'Optics'
  ];
  chemistry_chapters text[] := array[
    'Atomic Structure',
    'Chemical Bonding and Molecular Structure',
    'Chemical Thermodynamics',
    'Chemical Kinetics',
    'Basic Principles of Organic Chemistry'
  ];
  diffs text[] := array['easy','medium','hard','pyq','extras'];
  subj text;
  chap text;
  diff text;
  i int;
  qid text;
  prompt text;
  opts jsonb;
  wrong jsonb;
  expl text;
  concept text;
begin
  -- helper function via loops per subject
  for subj, chap in
    select 'Maths', unnest(maths_chapters)
    union all
    select 'Physics', unnest(physics_chapters)
    union all
    select 'Chemistry', unnest(chemistry_chapters)
  loop
    foreach diff in array diffs loop
      for i in 1..5 loop
        qid := format('jee-%s-%s-%s-%02s',
                      lower(subj),
                      regexp_replace(lower(chap), '[^a-z0-9]+', '-', 'g'),
                      diff,
                      i);
        prompt := format('(%s) %s: question %s', upper(diff), chap, i);
        opts := jsonb_build_array(
          jsonb_build_object('id','A','text', format('Concept check %s for %s', i, chap)),
          jsonb_build_object('id','B','text', format('Key idea %s applied correctly', i)),
          jsonb_build_object('id','C','text', format('Trick option %s', i)),
          jsonb_build_object('id','D','text', format('Numerical distraction %s', i))
        );
        wrong := jsonb_build_object(
          'A', format('A misses a key condition in %s.', chap),
          'C', format('C is a common trap; re-check constraints for %s.', chap),
          'D', format('D mixes numbers without the governing rule for %s.', chap)
        );
        expl := format('%s – focus on the core principle (q%s, %s). Correct choice uses the defining idea.', chap, i, diff);
        concept := format('Core principle practice for %s', chap);
        insert into public.question_bank (id, exam, subject, chapter, prompt, options, correct_option, explanation, wrong_explanations, difficulty, concept)
        values (qid, 'JEE', subj, chap, prompt, opts, 'B', expl, wrong, diff, concept)
        on conflict (id) do nothing;
      end loop;
    end loop;
  end loop;
end $$;

drop policy if exists "read_chat_attempts" on public.chat_question_attempts;
create policy "read_chat_attempts"
on public.chat_question_attempts
for select
using (auth.uid() = user_id);

drop policy if exists "insert_chat_attempts" on public.chat_question_attempts;
create policy "insert_chat_attempts"
on public.chat_question_attempts
for insert
with check (auth.uid() = user_id);

alter table public.files enable row level security;
alter table public.file_progress enable row level security;
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

drop policy if exists "users_manage_own_onboarding" on public.user_onboarding;
create policy "users_manage_own_onboarding"
on public.user_onboarding
for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);
