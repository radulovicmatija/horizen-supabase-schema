# Horizen CRM — database layer

The Postgres schema behind a CRM I built and run my studio on: tables, RLS policies, and the functions that let the public site write to it. The app itself is closed source (real client data), but there's nothing sensitive about how a table is locked down.

Read `sql/` in order, 01 through 06.

## One function instead of open policies

The public site runs on Supabase's anon key and has zero read or write access to any CRM table. Its only way into the database is a single `security definer` function:

```sql
create or replace function submit_website_inquiry(p_name text, p_contact text, p_message text)
returns uuid language plpgsql security definer set search_path = public as $fn$
declare
  v_client_id uuid;
begin
  select id into v_client_id from clients where lower(email) = lower(p_contact) limit 1;
  if v_client_id is null then
    insert into clients (name, email, source, notes)
    values (p_name, p_contact, 'website', p_message)
    returning id into v_client_id;
  end if;
  insert into deals (client_id, stage, title, notes)
  values (v_client_id, 'discovery', 'Website inquiry', p_message);
  return v_client_id;
end; $fn$;
```

The alternative was granting `anon` insert rights on `clients` and `deals` directly, gated by policy conditions. I didn't do that because a policy has to stay correct forever as the schema grows; a function I can read top to bottom only has to be correct once. `set search_path = public` is there so it can't be tricked into writing to a same-named table someone drops into another schema.

`06_booking_sync_triggers.sql` is the same idea from an earlier version: a booking widget wrote to a `bookings` table and a trigger created the client and deal reactively, off the insert, instead of on request. I killed it once usage data showed nobody used the booking flow — kept the file anyway, because deciding to remove working infrastructure is a real decision, not just adding it.

## What's not great

The schema was managed by hand through Supabase's SQL editor, not tracked migrations — these files are a reconstruction of the last known-good state, not real history. And one piece is left out on purpose rather than faked: a `check_booking_future_date()` trigger existed in production, but its SQL was never checked in anywhere, so it isn't reproduced here.

---

Matija Radulović · [horizen.rs](https://horizen.rs)
