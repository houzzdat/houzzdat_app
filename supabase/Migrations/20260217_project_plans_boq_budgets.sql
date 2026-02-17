-- Migration: Project Plans, Milestones, Budgets, BOQ, and Health Score Weights
-- Purpose: Enable progress vs plan, budget vs actuals, and material consumption vs BOQ tracking

-- Guard: ensure baseline tables exist before running this migration
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'projects'
  ) THEN
    RAISE EXCEPTION
      'Prerequisite table "projects" does not exist. '
      'Run 0000_baseline.sql first before applying this migration.';
  END IF;
  IF NOT EXISTS (
    SELECT FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'accounts'
  ) THEN
    RAISE EXCEPTION
      'Prerequisite table "accounts" does not exist. '
      'Run 0000_baseline.sql first before applying this migration.';
  END IF;
END
$$;

-- ============================================================
-- 1. PROJECT PLANS (project-level plan metadata)
-- ============================================================
create table if not exists project_plans (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references projects(id) on delete cascade,
  account_id uuid not null references accounts(id) on delete cascade,
  name text not null,
  total_budget numeric(14,2),
  start_date date,
  end_date date,
  uploaded_by uuid references auth.users(id),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

alter table project_plans enable row level security;

create policy "Users can view project plans in their account"
  on project_plans for select
  using (account_id in (
    select account_id from users where id = auth.uid()
    union
    select account_id from user_company_associations where user_id = auth.uid() and status = 'active'
  ));

create policy "Managers and admins can manage project plans"
  on project_plans for all
  using (account_id in (
    select account_id from users where id = auth.uid() and role in ('admin', 'manager', 'owner')
    union
    select account_id from user_company_associations where user_id = auth.uid() and status = 'active' and role in ('admin', 'manager', 'owner')
  ));

-- ============================================================
-- 2. PROJECT MILESTONES (individual phases from uploaded plan)
-- ============================================================
create table if not exists project_milestones (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references project_plans(id) on delete cascade,
  project_id uuid not null references projects(id) on delete cascade,
  account_id uuid not null references accounts(id) on delete cascade,
  name text not null,
  description text,
  planned_start date,
  planned_end date,
  actual_start date,
  actual_end date,
  weight_percent numeric(5,2) default 0,
  status text default 'not_started' check (status in ('not_started', 'in_progress', 'completed', 'delayed')),
  sort_order int default 0,
  created_at timestamptz default now()
);

alter table project_milestones enable row level security;

create policy "Users can view milestones in their account"
  on project_milestones for select
  using (account_id in (
    select account_id from users where id = auth.uid()
    union
    select account_id from user_company_associations where user_id = auth.uid() and status = 'active'
  ));

create policy "Managers and admins can manage milestones"
  on project_milestones for all
  using (account_id in (
    select account_id from users where id = auth.uid() and role in ('admin', 'manager', 'owner')
    union
    select account_id from user_company_associations where user_id = auth.uid() and status = 'active' and role in ('admin', 'manager', 'owner')
  ));

-- ============================================================
-- 3. PROJECT BUDGETS (line-item budget breakdown)
-- ============================================================
create table if not exists project_budgets (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references project_plans(id) on delete cascade,
  project_id uuid not null references projects(id) on delete cascade,
  account_id uuid not null references accounts(id) on delete cascade,
  category text not null check (category in ('material', 'labour', 'overhead', 'equipment', 'other')),
  line_item text not null,
  budgeted_amount numeric(14,2) not null,
  budgeted_quantity numeric(10,2),
  unit text,
  created_at timestamptz default now()
);

alter table project_budgets enable row level security;

create policy "Users can view budgets in their account"
  on project_budgets for select
  using (account_id in (
    select account_id from users where id = auth.uid()
    union
    select account_id from user_company_associations where user_id = auth.uid() and status = 'active'
  ));

create policy "Managers and admins can manage budgets"
  on project_budgets for all
  using (account_id in (
    select account_id from users where id = auth.uid() and role in ('admin', 'manager', 'owner')
    union
    select account_id from user_company_associations where user_id = auth.uid() and status = 'active' and role in ('admin', 'manager', 'owner')
  ));

-- ============================================================
-- 4. BOQ ITEMS (Bill of Quantities - material budget baseline)
-- ============================================================
create table if not exists boq_items (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references project_plans(id) on delete cascade,
  project_id uuid not null references projects(id) on delete cascade,
  account_id uuid not null references accounts(id) on delete cascade,
  material_name text not null,
  category text,
  planned_quantity numeric(10,2) not null,
  unit text not null,
  budgeted_rate numeric(14,2),
  budgeted_total numeric(14,2),
  consumed_quantity numeric(10,2) default 0,
  actual_spend numeric(14,2) default 0,
  status text default 'planned' check (status in ('planned', 'partially_consumed', 'fully_consumed', 'over_consumed')),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

alter table boq_items enable row level security;

create policy "Users can view BOQ items in their account"
  on boq_items for select
  using (account_id in (
    select account_id from users where id = auth.uid()
    union
    select account_id from user_company_associations where user_id = auth.uid() and status = 'active'
  ));

create policy "Managers and admins can manage BOQ items"
  on boq_items for all
  using (account_id in (
    select account_id from users where id = auth.uid() and role in ('admin', 'manager', 'owner')
    union
    select account_id from user_company_associations where user_id = auth.uid() and status = 'active' and role in ('admin', 'manager', 'owner')
  ));

-- ============================================================
-- 5. HEALTH SCORE WEIGHTS (configurable by super admin)
-- ============================================================
create table if not exists health_score_weights (
  id uuid primary key default gen_random_uuid(),
  account_id uuid references accounts(id) on delete cascade,
  task_completion_weight numeric(5,2) default 20,
  schedule_adherence_weight numeric(5,2) default 25,
  blocker_severity_weight numeric(5,2) default 20,
  activity_recency_weight numeric(5,2) default 15,
  worker_attendance_weight numeric(5,2) default 10,
  overdue_penalty_weight numeric(5,2) default 10,
  updated_by uuid references auth.users(id),
  updated_at timestamptz default now(),
  constraint weights_sum_100 check (
    task_completion_weight + schedule_adherence_weight + blocker_severity_weight +
    activity_recency_weight + worker_attendance_weight + overdue_penalty_weight = 100
  ),
  unique(account_id)
);

-- Insert global defaults (account_id = null means global)
insert into health_score_weights (account_id) values (null);

-- Super admins can manage health score weights
alter table health_score_weights enable row level security;

create policy "Anyone can read health score weights"
  on health_score_weights for select
  using (true);

create policy "Super admins can manage health score weights"
  on health_score_weights for all
  using (
    auth.uid() in (select id from super_admins)
  );

-- ============================================================
-- 6. INDEXES for performance
-- ============================================================
create index if not exists idx_project_plans_project on project_plans(project_id);
create index if not exists idx_project_plans_account on project_plans(account_id);
create index if not exists idx_project_milestones_plan on project_milestones(plan_id);
create index if not exists idx_project_milestones_project on project_milestones(project_id);
create index if not exists idx_project_budgets_plan on project_budgets(plan_id);
create index if not exists idx_project_budgets_project on project_budgets(project_id);
create index if not exists idx_boq_items_plan on boq_items(plan_id);
create index if not exists idx_boq_items_project on boq_items(project_id);
create index if not exists idx_health_score_weights_account on health_score_weights(account_id);

-- ============================================================
-- 7. TRIGGER: Auto-update updated_at on boq_items
-- ============================================================
create or replace function update_boq_item_timestamp()
returns trigger as $$
begin
  new.updated_at = now();
  -- Auto-compute status based on consumption
  if new.consumed_quantity >= new.planned_quantity * 1.0 and new.consumed_quantity > new.planned_quantity then
    new.status = 'over_consumed';
  elsif new.consumed_quantity >= new.planned_quantity then
    new.status = 'fully_consumed';
  elsif new.consumed_quantity > 0 then
    new.status = 'partially_consumed';
  else
    new.status = 'planned';
  end if;
  -- Auto-compute budgeted_total if rate and quantity are set
  if new.budgeted_rate is not null and new.planned_quantity is not null then
    new.budgeted_total = new.budgeted_rate * new.planned_quantity;
  end if;
  return new;
end;
$$ language plpgsql;

create trigger boq_items_before_update
  before update on boq_items
  for each row
  execute function update_boq_item_timestamp();

-- Also compute budgeted_total on insert
create trigger boq_items_before_insert
  before insert on boq_items
  for each row
  execute function update_boq_item_timestamp();
