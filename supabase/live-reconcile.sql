-- =====================================================================
-- Ya Spa — LIVE reconcile (project plzdjimvrvuhxnenrdgt)
-- The live project was hand-evolved beyond the committed 0001 (it already has
-- the full booking_status enum, a booking_transition_guard trigger, cancel_booking,
-- taken_slots, and the uniq_active_slot index). The committed 0002 assumes a clean
-- 0001 and converts the enum→text, which conflicts. This script adds ONLY what the
-- real app needs, keeping the existing enum/trigger/index/functions. Idempotent.
-- (Committed 0002/0003 remain the clean path for a fresh project.)
-- =====================================================================

-- 1) new booking columns (keep enums; no type conversion)
alter table public.bookings add column if not exists duration_min   int not null default 60;
alter table public.bookings add column if not exists scheduled_at   timestamptz;
alter table public.bookings add column if not exists address_line   text;
alter table public.bookings add column if not exists building       text;
alter table public.bookings add column if not exists apartment      text;
alter table public.bookings add column if not exists city           text not null default 'Jeddah';
alter table public.bookings add column if not exists lat            double precision;
alter table public.bookings add column if not exists lng            double precision;
alter table public.bookings add column if not exists payment_method text not null default 'on_arrival';
alter table public.bookings add column if not exists customer_name  text;
alter table public.bookings add column if not exists contact_phone  text;
alter table public.bookings add column if not exists updated_at     timestamptz not null default now();

do $$ begin alter table public.bookings add constraint bookings_duration_chk  check (duration_min in (60,90,120));
exception when duplicate_object then null; end $$;
do $$ begin alter table public.bookings add constraint bookings_paymethod_chk check (payment_method in ('on_arrival','apple_pay','card','mada','stc_pay'));
exception when duplicate_object then null; end $$;

create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$ begin new.updated_at := now(); return new; end; $$;
drop trigger if exists bookings_touch on public.bookings;
create trigger bookings_touch before update on public.bookings for each row execute function public.touch_updated_at();

-- 2) duration-based pricing
create table if not exists public.service_durations (
  service_id text not null references public.services(id) on delete cascade,
  duration_min int not null check (duration_min in (60,90,120)),
  price int not null check (price >= 0),
  primary key (service_id, duration_min));
alter table public.service_durations enable row level security;
drop policy if exists "service_durations_public_read" on public.service_durations;
create policy "service_durations_public_read" on public.service_durations for select using (true);
insert into public.service_durations (service_id, duration_min, price)
select s.id, d.dur,
       case d.dur when 60 then s.price
                  when 90 then (round(s.price*1.40/5)*5)::int
                  when 120 then (round(s.price*1.80/5)*5)::int end
from public.services s cross join (values (60),(90),(120)) as d(dur)
on conflict (service_id, duration_min) do nothing;

-- 3) owner/operator accounts
create table if not exists public.admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  label text, created_at timestamptz not null default now());
alter table public.admins enable row level security;
drop policy if exists "admins_self_read" on public.admins;
create policy "admins_self_read" on public.admins for select using (auth.uid() = user_id);
create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path=public as $$
  select exists (select 1 from public.admins a where a.user_id = auth.uid()); $$;
grant execute on function public.is_admin() to authenticated;

-- 4) lifecycle audit trail
create table if not exists public.booking_events (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id) on delete cascade,
  status text not null, note text, actor uuid, created_at timestamptz not null default now());
create index if not exists booking_events_booking_idx on public.booking_events(booking_id, created_at);
alter table public.booking_events enable row level security;
drop policy if exists "booking_events_read" on public.booking_events;
create policy "booking_events_read" on public.booking_events for select using (
  public.is_admin() or exists (select 1 from public.bookings b where b.id=booking_id and b.user_id=auth.uid()));

-- 5) broaden the existing transition guard so the owner can drive the lifecycle
create or replace function public.enforce_booking_transition() returns trigger language plpgsql as $$
begin
  if new.status = old.status then return new; end if;
  if old.status = 'pending'    and new.status in ('confirmed','cancelled','no_show') then return new; end if;
  if old.status = 'confirmed'  and new.status in ('on_the_way','completed','cancelled','no_show') then return new; end if;
  if old.status = 'on_the_way' and new.status in ('completed','cancelled','no_show') then return new; end if;
  raise exception 'ILLEGAL_STATUS_TRANSITION from % to %', old.status, new.status;
end; $$;

-- 6) server-authoritative order creation (server computes price/total; forces state)
create or replace function public.create_booking(
  p_service_id text, p_duration_min int, p_therapist_id text, p_scheduled_at timestamptz,
  p_address_line text, p_building text, p_apartment text, p_district text, p_city text,
  p_lat double precision default null, p_lng double precision default null,
  p_notes text default '', p_payment_method text default 'on_arrival',
  p_customer_name text default '', p_contact_phone text default ''
) returns public.bookings language plpgsql security definer set search_path=public as $$
declare v_uid uuid := auth.uid(); v_svc public.services%rowtype; v_ther public.therapists%rowtype;
        v_price int; v_transport int := 30; v_vat int; v_total int; v_row public.bookings%rowtype;
begin
  if v_uid is null then raise exception 'not_authenticated' using errcode='28000'; end if;
  select * into v_svc from public.services where id=p_service_id and active;
  if not found then raise exception 'invalid_service' using errcode='22023'; end if;
  select price into v_price from public.service_durations where service_id=p_service_id and duration_min=p_duration_min;
  if v_price is null then raise exception 'invalid_duration' using errcode='22023'; end if;
  select * into v_ther from public.therapists where id=p_therapist_id and active;
  if not found then raise exception 'invalid_therapist' using errcode='22023'; end if;
  if p_scheduled_at is null or p_scheduled_at < now() then raise exception 'invalid_time' using errcode='22023'; end if;
  v_vat := round((v_price+v_transport)*0.15); v_total := v_price+v_transport+v_vat;
  begin
    insert into public.bookings (user_id, service_id, service_name_ar, service_name_en, minutes, duration_min, price,
      therapist_id, therapist_name, scheduled_at, booking_date, booking_time,
      address_line, building, apartment, district, city, lat, lng, notes, customer_name, contact_phone,
      transport, vat, total, status, payment_status, payment_method)
    values (v_uid, v_svc.id, v_svc.name_ar, v_svc.name_en, p_duration_min, p_duration_min, v_price,
      v_ther.id, v_ther.name_en, p_scheduled_at, (p_scheduled_at at time zone 'Asia/Riyadh')::date,
      to_char(p_scheduled_at at time zone 'Asia/Riyadh','HH24:00'),
      p_address_line, p_building, p_apartment, coalesce(p_district,''), coalesce(p_city,'Jeddah'),
      p_lat, p_lng, coalesce(p_notes,''), nullif(p_customer_name,''), nullif(p_contact_phone,''),
      v_transport, v_vat, v_total, 'pending', 'unpaid', p_payment_method)
    returning * into v_row;
  exception when unique_violation then raise exception 'slot_taken' using errcode='23505'; end;
  insert into public.booking_events (booking_id, status, note, actor) values (v_row.id, 'pending', 'created', v_uid);
  return v_row;
end; $$;

-- 7) owner drives an order through the lifecycle
create or replace function public.admin_set_status(p_id uuid, p_status text)
returns public.bookings language plpgsql security definer set search_path=public as $$
declare v_uid uuid := auth.uid(); v_row public.bookings%rowtype; v_old text;
begin
  if not public.is_admin() then raise exception 'forbidden' using errcode='42501'; end if;
  if p_status not in ('confirmed','on_the_way','completed','cancelled','no_show') then raise exception 'invalid_status' using errcode='22023'; end if;
  select status::text into v_old from public.bookings where id=p_id;
  if v_old is null then raise exception 'not_found' using errcode='22023'; end if;
  update public.bookings set status = p_status::booking_status where id=p_id returning * into v_row;
  insert into public.booking_events (booking_id, status, note, actor) values (v_row.id, p_status, format('admin: %s -> %s', v_old, p_status), v_uid);
  return v_row;
end; $$;

-- 8) RLS hardening: customers can't write bookings directly — only via the RPCs
drop policy if exists "bookings_insert_own" on public.bookings;
drop policy if exists "bookings_update_own" on public.bookings;
drop policy if exists "bookings_read_own" on public.bookings;
drop policy if exists "bookings_read_own_or_admin" on public.bookings;
create policy "bookings_read_own_or_admin" on public.bookings for select using (auth.uid()=user_id or public.is_admin());
drop policy if exists "bookings_admin_update" on public.bookings;
create policy "bookings_admin_update" on public.bookings for update using (public.is_admin()) with check (public.is_admin());
revoke insert, update, delete on public.bookings from anon, authenticated;

grant execute on function public.create_booking(text,int,text,timestamptz,text,text,text,text,text,double precision,double precision,text,text,text,text) to anon, authenticated;
grant execute on function public.admin_set_status(uuid,text) to authenticated;
grant execute on function public.cancel_booking(uuid) to authenticated;
grant execute on function public.taken_slots(text,date) to anon, authenticated;

-- 9) customer self-service reschedule (move an existing pending/confirmed order to a new
--    slot). Enum-correct for the LIVE schema: bookings.status is a booking_status enum, so
--    the booking_events.status (text) insert casts v_row.status::text — unlike the committed
--    0002 which runs in a text-status world. security definer bypasses the direct-write revoke;
--    the trigger is a no-op because status is unchanged; a slot collision → 'slot_taken'.
create or replace function public.reschedule_booking(p_id uuid, p_scheduled_at timestamptz)
returns public.bookings language plpgsql security definer set search_path=public as $$
declare v_uid uuid := auth.uid(); v_row public.bookings%rowtype;
begin
  if p_scheduled_at is null or p_scheduled_at < now() then raise exception 'invalid_time' using errcode='22023'; end if;
  begin
    update public.bookings
       set scheduled_at = p_scheduled_at,
           booking_date = (p_scheduled_at at time zone 'Asia/Riyadh')::date,
           booking_time = to_char(p_scheduled_at at time zone 'Asia/Riyadh','HH24:00')
     where id = p_id and user_id = v_uid and status in ('pending','confirmed')
    returning * into v_row;
  exception when unique_violation then raise exception 'slot_taken' using errcode='23505'; end;
  if not found then raise exception 'reschedule_not_allowed' using errcode='22023'; end if;
  insert into public.booking_events (booking_id, status, note, actor)
    values (v_row.id, v_row.status::text, 'rescheduled', v_uid);
  return v_row;
end; $$;
revoke all on function public.reschedule_booking(uuid,timestamptz) from public;
grant execute on function public.reschedule_booking(uuid,timestamptz) to authenticated;
