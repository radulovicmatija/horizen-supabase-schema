-- Client-side error monitoring sink.
--
-- Uncaught errors in the public site's browser get written here directly
-- from the client with the anon key, then reviewed from inside the CRM.
-- No third-party error-tracking service — just a table with an
-- intentionally asymmetric policy pair: anyone can insert, only signed-in
-- staff can read. A visitor's browser can log an error but can never see
-- what anyone else's browser has logged.

create table if not exists client_errors (
  id uuid primary key default gen_random_uuid(),
  message text,
  stack text,
  source text,
  url text,
  user_agent text,
  created_at timestamptz default now()
);

alter table client_errors enable row level security;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='client_errors' AND policyname='Anyone can log errors')
    THEN create policy "Anyone can log errors" on client_errors for insert to anon, authenticated with check (true);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='client_errors' AND policyname='Auth can read errors')
    THEN create policy "Auth can read errors" on client_errors for select to authenticated using (true);
  END IF;
END $$;
