-- The public site's only write path into the CRM.
--
-- The contact form has no appointment time, so it can't (and shouldn't)
-- write into `deals`/`clients` directly with an anon key — RLS blocks the
-- `anon` role from those tables entirely (02_rls_policies.sql). Instead it
-- calls this single `security definer` function, which runs with the
-- function owner's privileges for the couple of writes it actually needs
-- to make, and nothing else. That's the whole trust boundary: one function,
-- one job, reviewable in one place — instead of granting `anon` broad
-- insert rights on CRM tables to work around RLS.
--
-- `set search_path = public` pins name resolution inside the function body.
-- Without it, a `security definer` function is vulnerable to a schema-
-- squatting attack: someone creates a same-named object in a schema earlier
-- in the caller's search_path, and the function silently operates on that
-- instead of the real table.

create or replace function submit_website_inquiry(p_name text, p_contact text, p_message text)
returns uuid
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_client_id uuid;
  v_email text;
  v_phone text;
begin
  -- The contact field is a single free-text input on the form; accept
  -- either an email address or a phone number and store it in the right
  -- column instead of forcing the visitor to pick a field type.
  if p_contact ~ '^[^\s@]+@[^\s@]+\.[^\s@]+$' then
    v_email := p_contact;
  else
    v_phone := p_contact;
  end if;

  -- Find-or-create by email, case-insensitively, so the same person
  -- submitting twice doesn't create two client records.
  if v_email is not null then
    select id into v_client_id from clients where lower(email) = lower(v_email) limit 1;
  end if;

  if v_client_id is null then
    insert into clients (name, email, phone, source, notes)
    values (p_name, v_email, v_phone, 'website', p_message)
    returning id into v_client_id;
  end if;

  insert into deals (client_id, stage, title, next_action, notes)
  values (v_client_id, 'discovery', 'Website inquiry', 'Discovery call', p_message);

  -- Atomic upsert: a fresh channel gets seeded at 1, an existing one gets
  -- incremented — either way in one statement, no read-then-write race.
  insert into channel_funnel (channel, outreach, updated_at)
  values ('website', 1, now())
  on conflict (channel) do update set
    outreach = channel_funnel.outreach + 1,
    updated_at = now();

  return v_client_id;
end;
$fn$;

-- The public site calls this as the anon role — grant execute on the
-- function itself, not on the underlying tables.
grant execute on function submit_website_inquiry(text, text, text) to anon;
