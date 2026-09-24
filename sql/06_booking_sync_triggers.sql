-- HISTORICAL — retired.
--
-- Before the CRM had `submit_website_inquiry` (03_*.sql), leads came in
-- through a booking widget at /zakazi: a visitor picked a date/time, the
-- browser inserted a row into `bookings` with the anon key, and this
-- trigger did the same "find-or-create client, open a discovery deal, bump
-- the funnel" work that the RPC does today — except reactively, off a
-- table insert, instead of being called directly.
--
-- `bookings` predates any tracked schema file; its shape below is
-- reconstructed from the columns actually referenced in the trigger body
-- and documented in an internal system audit, not copied from an original
-- CREATE TABLE (none was ever version-controlled).
--
-- The booking widget was removed once usage data showed 0 real bookings
-- against a working direct-inquiry path — one write path is easier to
-- reason about than two that both mutate the same tables. Kept here,
-- unmodified from the last version that ran in production, because a
-- trigger-driven sync with a `security definer` boundary and idempotent
-- writes is exactly the kind of database-level logic worth showing —
-- even retired.

-- deals.booking_id existed only while the booking widget was live; the
-- current schema (01_core_schema.sql) no longer has it.
alter table deals add column if not exists booking_id uuid;

create table if not exists bookings (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  email text,
  company text,
  message text,
  date date,
  time time,
  status text default 'pending',   -- pending | confirmed | cancelled | completed | no_show
  source text,                      -- attribution channel, e.g. ?ref= on the booking link
  admin_note text,
  cancel_reason text,
  created_at timestamptz default now()
);

alter table bookings enable row level security;

-- Note: production also had a `check_booking_future_date()` BEFORE INSERT
-- trigger rejecting past/today dates at the database level (defense in
-- depth against a bypassed frontend check). Its exact body was never
-- checked into version control, so it isn't reproduced here — flagged in
-- README.md as a known gap in this repo's history, not silently omitted.

create or replace function handle_new_booking()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_client_id uuid;
  v_channel text := coalesce(nullif(new.source, ''), 'website');
begin
  select id into v_client_id from clients where lower(email) = lower(new.email) limit 1;

  if v_client_id is null then
    insert into clients (name, email, company, source, notes)
    values (new.name, new.email, new.company, v_channel, new.message)
    returning id into v_client_id;
  end if;

  if not exists (select 1 from deals where booking_id = new.id) then
    -- new.date/new.time arrive from `bookings` typed as text in some client
    -- payloads; deals.follow_up_date/time are date/time. Skipping the
    -- explicit cast here fails with 42804 and, because this fires inside
    -- the same transaction as the booking insert (AFTER INSERT), takes the
    -- whole booking down with it — the booking never gets saved at all.
    insert into deals (client_id, booking_id, stage, title, next_action, follow_up_date, follow_up_time, notes)
    values (v_client_id, new.id, 'discovery', 'Booking inquiry', 'Discovery call', new.date::date, new.time::time, new.message);
  end if;

  -- A completed booking is simultaneously outreach + engagement + a booked
  -- call for its channel — the visitor self-served the whole funnel in one
  -- action, so all three counters move together instead of just one.
  insert into channel_funnel (channel, outreach, angazovan, zakazao, updated_at)
  values (v_channel, 1, 1, 1, now())
  on conflict (channel) do update set
    outreach = channel_funnel.outreach + 1,
    angazovan = channel_funnel.angazovan + 1,
    zakazao = channel_funnel.zakazao + 1,
    updated_at = now();

  return new;
end;
$fn$;

drop trigger if exists on_new_booking on bookings;
create trigger on_new_booking after insert on bookings for each row execute function handle_new_booking();

-- A cancelled/deleted booking should only clean up the empty discovery deal
-- it created — never a deal that has since progressed (has a value or a
-- package attached), since that would silently destroy real pipeline data.
create or replace function handle_booking_delete()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
begin
  delete from deals
  where booking_id = old.id
    and stage = 'discovery'
    and value is null
    and package is null;
  return old;
end;
$fn$;

drop trigger if exists on_delete_booking on bookings;
create trigger on_delete_booking after delete on bookings for each row execute function handle_booking_delete();
