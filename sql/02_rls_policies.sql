-- Row Level Security policies for the CRM tables.
--
-- The rule is intentionally simple and uniform: every CRM table is fully
-- open to `authenticated` (the CRM is single-tenant — one studio, one
-- Supabase Auth user signs in) and completely closed to `anon`. The public
-- marketing site never reads or writes these tables directly; it only ever
-- calls the `submit_website_inquiry` security-definer RPC (03_*.sql), which
-- bypasses RLS in one narrow, audited place instead of opening it up table
-- by table.
--
-- Wrapped in `IF NOT EXISTS` checks against `pg_policies` so this file is
-- idempotent and safe to re-run against a database that already has some
-- (or all) of these policies.

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='clients' AND policyname='Auth full access clients')
    THEN create policy "Auth full access clients" on clients for all to authenticated using (true) with check (true);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='deals' AND policyname='Auth full access deals')
    THEN create policy "Auth full access deals" on deals for all to authenticated using (true) with check (true);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='activities' AND policyname='Auth full access activities')
    THEN create policy "Auth full access activities" on activities for all to authenticated using (true) with check (true);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='tasks' AND policyname='Auth full access tasks')
    THEN create policy "Auth full access tasks" on tasks for all to authenticated using (true) with check (true);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='invoices' AND policyname='Auth full access invoices')
    THEN create policy "Auth full access invoices" on invoices for all to authenticated using (true) with check (true);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='subscriptions' AND policyname='Auth full access subscriptions')
    THEN create policy "Auth full access subscriptions" on subscriptions for all to authenticated using (true) with check (true);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='projects' AND policyname='Auth full access projects')
    THEN create policy "Auth full access projects" on projects for all to authenticated using (true) with check (true);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='channel_funnel' AND policyname='Auth full access channel_funnel')
    THEN create policy "Auth full access channel_funnel" on channel_funnel for all to authenticated using (true) with check (true);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='proposals' AND policyname='Auth full access proposals')
    THEN create policy "Auth full access proposals" on proposals for all to authenticated using (true) with check (true);
  END IF;
END $$;
