-- Horizen CRM — core schema
--
-- `clients` is the hub table; almost everything else references it with
-- `on delete cascade` so removing a client cleans up its whole history.
-- `deals` uses `on delete set null` instead, because a deal can legitimately
-- outlive being reassigned (see 06_booking_sync_triggers.sql for why deals
-- once carried a nullable booking_id).

create table if not exists clients (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  company text,
  email text unique,
  phone text,
  instagram text,
  source text,
  notes text,
  website text,
  lead_status text,
  category text,
  rating numeric,
  reviews int,
  outreach jsonb default '{}'::jsonb,
  kanal text,                    -- preferred contact channel: viber | instagram | email | telefon_fiksni
  last_contact_at timestamptz,
  created_at timestamptz default now()
);

create table if not exists deals (
  id uuid primary key default gen_random_uuid(),
  client_id uuid references clients(id) on delete cascade,
  title text,
  package text,
  stage text not null default 'discovery',   -- discovery -> proposal -> follow_up -> onboarding -> delivery -> client / lost
  value numeric,
  billing_type text,
  next_action text,
  follow_up_date date,
  follow_up_time time,
  staging_link text,
  deadline date,
  notes text,
  created_at timestamptz default now()
);

create table if not exists activities (
  id uuid primary key default gen_random_uuid(),
  client_id uuid references clients(id) on delete cascade,
  deal_id uuid references deals(id) on delete set null,
  type text default 'note',      -- note | call | email
  body text,
  created_at timestamptz default now()
);

create table if not exists tasks (
  id uuid primary key default gen_random_uuid(),
  client_id uuid references clients(id) on delete cascade,
  deal_id uuid references deals(id) on delete set null,
  title text not null,
  due_date date,
  done boolean default false,
  created_at timestamptz default now()
);

create table if not exists invoices (
  id uuid primary key default gen_random_uuid(),
  client_id uuid references clients(id) on delete cascade,
  deal_id uuid references deals(id) on delete set null,
  broj text,
  iznos numeric not null default 0,
  status text default 'ceka',
  datum_slanja date,
  datum_placanja date,
  napomena text,
  created_at timestamptz default now()
);

create table if not exists subscriptions (
  id uuid primary key default gen_random_uuid(),
  client_id uuid references clients(id) on delete cascade,
  deal_id uuid references deals(id) on delete set null,
  naziv text,
  iznos numeric not null default 0,
  interval text default 'monthly',
  status text default 'active',
  start_date date,
  next_billing_date date,
  created_at timestamptz default now()
);

create table if not exists projects (
  id uuid primary key default gen_random_uuid(),
  client_id uuid references clients(id) on delete cascade,
  deal_id uuid references deals(id) on delete set null,
  naziv text,
  paket text,
  faza text default 'kickoff',   -- kickoff -> development -> staging -> revision -> demo -> live
  staging_link text,
  rok date,
  napomena text,
  created_at timestamptz default now()
);

create table if not exists proposals (
  id uuid primary key default gen_random_uuid(),
  client_id uuid references clients(id) on delete cascade,
  deal_id uuid references deals(id) on delete set null,
  paket text,
  iznos numeric default 0,
  mrr numeric default 0,
  status text default 'poslata',
  datum_slanja date,
  vazi_do date,
  napomena text,
  created_at timestamptz default now()
);

-- Aggregate, per-channel funnel counters (not per-client) — feeds the
-- Analitika dashboard's outreach -> engaged -> booked conversion view.
create table if not exists channel_funnel (
  channel text primary key,
  outreach int default 0,
  angazovan int default 0,
  zakazao int default 0,
  updated_at timestamptz default now()
);

alter table clients       enable row level security;
alter table deals         enable row level security;
alter table activities    enable row level security;
alter table tasks         enable row level security;
alter table invoices      enable row level security;
alter table subscriptions enable row level security;
alter table projects      enable row level security;
alter table channel_funnel enable row level security;
alter table proposals     enable row level security;
