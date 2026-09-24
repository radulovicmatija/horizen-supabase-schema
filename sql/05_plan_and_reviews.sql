-- Internal-only tables: the outreach script library and weekly reviews used
-- by the CRM's "Plan" tab. Same access pattern as the core CRM tables —
-- full access to `authenticated`, nothing for `anon`.

create table if not exists plan_scripts (
  key text primary key,
  body text,
  updated_at timestamptz default now()
);

create table if not exists weekly_reviews (
  week_start date primary key,
  worked text,
  learned text,
  change_next text,
  created_at timestamptz default now()
);

alter table plan_scripts   enable row level security;
alter table weekly_reviews enable row level security;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='plan_scripts' AND policyname='Auth full plan_scripts')
    THEN create policy "Auth full plan_scripts" on plan_scripts for all to authenticated using (true) with check (true);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='weekly_reviews' AND policyname='Auth full weekly_reviews')
    THEN create policy "Auth full weekly_reviews" on weekly_reviews for all to authenticated using (true) with check (true);
  END IF;
END $$;
