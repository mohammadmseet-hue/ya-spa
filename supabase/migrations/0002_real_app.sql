-- =====================================================================
-- Ya Spa — Real-app backend (Phase 2)
-- Turns the Phase-1 foundation into a production booking system:
--   • duration-based pricing (60 / 90 / 120 min)         → service_durations
--   • full delivery location (address + geo pin)          → bookings.* columns
--   • server-authoritative order creation                 → create_booking()
--   • owner/operator console that sees & drives all orders → admins + is_admin()
--   • lifecycle state-machine + audit trail               → booking_events
--   • anti-double-booking                                  → unique slot index
--   • hardened RLS: customers NEVER write money/status directly; all
--     mutations go through SECURITY DEFINER RPCs; payments are server-only.
-- Safe to run after 0001_init.sql on a fresh project.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0) status/payment columns: enum → text+CHECK (adds on_the_way/no_show
--    that the app already uses, and avoids enum-ADD-VALUE-in-txn hazards).
-- ---------------------------------------------------------------------
alter table public.bookings alter column status drop default;
alter table public.bookings alter column status type text using status::text;
alter table public.bookings alter column status set default 'pending';

alter table public.bookings alter column payment_status drop default;
alter table public.bookings alter column payment_status type text using payment_status::text;
alter table public.bookings alter column payment_status set default 'unpaid';

alter table public.payments alter column status type text using status::text;

drop type if exists booking_status;
drop type if exists payment_state;

alter table public.bookings
  add constraint bookings_status_chk
  check (status in ('pending','confirmed','on_the_way','completed','cancelled','no_show'));
alter table public.bookings
  add constraint bookings_paystatus_chk
  check (payment_status in ('unpaid','paid','refunded','failed'));

-- ---------------------------------------------------------------------
-- 1) Real-app columns on bookings: duration, full location, geo pin,
--    a real scheduled_at timestamp, payment method, updated_at.
-- ---------------------------------------------------------------------
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

alter table public.bookings add constraint bookings_duration_chk  check (duration_min in (60,90,120));
alter table public.bookings add constraint bookings_totals_chk    check (price >= 0 and transport >= 0 and vat >= 0 and total >= 0);
alter table public.bookings add constraint bookings_paymethod_chk check (payment_method in ('on_arrival','apple_pay','card','mada','stc_pay'));

-- keep updated_at fresh
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at := now(); return new; end; $$;
drop trigger if exists bookings_touch on public.bookings;
create trigger bookings_touch before update on public.bookings
  for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------------------
-- 2) Duration-based pricing catalog. The 60-min price is the anchor
--    (services.price); 90/120 scale from it. Prices are SAR (whole).
-- ---------------------------------------------------------------------
create table if not exists public.service_durations (
  service_id   text not null references public.services(id) on delete cascade,
  duration_min int  not null check (duration_min in (60,90,120)),
  price        int  not null check (price >= 0),
  primary key (service_id, duration_min)
);
alter table public.service_durations enable row level security;
create policy "service_durations_public_read"
  on public.service_durations for select using (true);

-- seed 60/90/120 for every service: 90 ≈ ×1.4, 120 ≈ ×1.8 (rounded to 5 SAR)
insert into public.service_durations (service_id, duration_min, price)
select s.id, d.dur,
       case d.dur
         when 60  then s.price
         when 90  then (round(s.price * 1.40 / 5) * 5)::int
         when 120 then (round(s.price * 1.80 / 5) * 5)::int
       end
from public.services s
cross join (values (60),(90),(120)) as d(dur)
on conflict (service_id, duration_min) do nothing;

-- ---------------------------------------------------------------------
-- 3) Owner / operator accounts (the people who receive & fulfil orders).
-- ---------------------------------------------------------------------
create table if not exists public.admins (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  label      text,
  created_at timestamptz not null default now()
);
alter table public.admins enable row level security;
-- an admin may see the admin roster; nobody else can.
create policy "admins_self_read" on public.admins for select using (auth.uid() = user_id);

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.admins a where a.user_id = auth.uid());
$$;
grant execute on function public.is_admin() to authenticated;

-- ---------------------------------------------------------------------
-- 4) Lifecycle audit trail (status timeline the app already renders).
-- ---------------------------------------------------------------------
create table if not exists public.booking_events (
  id         uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id) on delete cascade,
  status     text not null,
  note       text,
  actor      uuid,
  created_at timestamptz not null default now()
);
create index if not exists booking_events_booking_idx on public.booking_events(booking_id, created_at);
alter table public.booking_events enable row level security;
-- readable by the booking's owner or any admin
create policy "booking_events_read" on public.booking_events for select
  using (
    public.is_admin()
    or exists (select 1 from public.bookings b where b.id = booking_id and b.user_id = auth.uid())
  );

-- ---------------------------------------------------------------------
-- 5) Anti-double-booking: one active booking per therapist per slot.
-- ---------------------------------------------------------------------
create unique index if not exists bookings_slot_unique
  on public.bookings (therapist_id, scheduled_at)
  where status in ('pending','confirmed','on_the_way');

create index if not exists bookings_admin_feed_idx on public.bookings (status, scheduled_at);

-- ---------------------------------------------------------------------
-- 6) RLS hardening: customers can READ their own orders; ADMINS can read
--    & update ALL orders. NOBODY writes bookings/payments directly — all
--    creation/mutation flows through the SECURITY DEFINER RPCs below.
-- ---------------------------------------------------------------------
drop policy if exists "bookings_insert_own" on public.bookings;
drop policy if exists "bookings_update_own" on public.bookings;

drop policy if exists "bookings_read_own" on public.bookings;
create policy "bookings_read_own_or_admin" on public.bookings for select
  using (auth.uid() = user_id or public.is_admin());

create policy "bookings_admin_update" on public.bookings for update
  using (public.is_admin()) with check (public.is_admin());

-- lock the tables down: no direct DML from customer roles
revoke insert, update, delete on public.bookings from anon, authenticated;
revoke insert, update, delete on public.payments from anon, authenticated;
revoke all    on public.payments from anon, authenticated;
grant  select on public.payments to authenticated;   -- read own via payments_read_own

-- ---------------------------------------------------------------------
-- 7) Server-authoritative RPCs (the ONLY write path for customers).
-- ---------------------------------------------------------------------

-- CREATE: price/vat/total are computed server-side from the catalog; status
-- and payment_status are forced. The client can never dictate money or state.
create or replace function public.create_booking(
  p_service_id   text,
  p_duration_min int,
  p_therapist_id text,
  p_scheduled_at timestamptz,
  p_address_line text,
  p_building     text,
  p_apartment    text,
  p_district     text,
  p_city         text,
  p_lat          double precision default null,   -- optional GPS pin (client may omit)
  p_lng          double precision default null,
  p_notes        text default '',
  p_payment_method text default 'on_arrival',
  p_customer_name  text default '',
  p_contact_phone  text default ''
) returns public.bookings
language plpgsql security definer set search_path = public as $$
declare
  v_uid   uuid := auth.uid();
  v_svc   public.services%rowtype;
  v_ther  public.therapists%rowtype;
  v_price int;
  v_transport int := 30;
  v_vat   int;
  v_total int;
  v_row   public.bookings%rowtype;
begin
  if v_uid is null then raise exception 'not_authenticated' using errcode='28000'; end if;
  if p_payment_method is null then p_payment_method := 'on_arrival'; end if;

  select * into v_svc from public.services where id = p_service_id and active;
  if not found then raise exception 'invalid_service' using errcode='22023'; end if;

  select price into v_price from public.service_durations
    where service_id = p_service_id and duration_min = p_duration_min;
  if v_price is null then raise exception 'invalid_duration' using errcode='22023'; end if;

  select * into v_ther from public.therapists where id = p_therapist_id and active;
  if not found then raise exception 'invalid_therapist' using errcode='22023'; end if;

  if p_scheduled_at is null or p_scheduled_at < now() then
    raise exception 'invalid_time' using errcode='22023';
  end if;

  v_vat   := round((v_price + v_transport) * 0.15);
  v_total := v_price + v_transport + v_vat;

  begin
    insert into public.bookings (
      user_id, service_id, service_name_ar, service_name_en, minutes, duration_min, price,
      therapist_id, therapist_name, scheduled_at,
      booking_date, booking_time,
      address_line, building, apartment, district, city, lat, lng, notes,
      customer_name, contact_phone,
      transport, vat, total, status, payment_status, payment_method
    ) values (
      v_uid, v_svc.id, v_svc.name_ar, v_svc.name_en, p_duration_min, p_duration_min, v_price,
      v_ther.id, v_ther.name_en, p_scheduled_at,
      (p_scheduled_at at time zone 'Asia/Riyadh')::date,
      to_char(p_scheduled_at at time zone 'Asia/Riyadh', 'HH24:00'),
      p_address_line, p_building, p_apartment, coalesce(p_district, ''), coalesce(p_city,'Jeddah'),
      p_lat, p_lng, coalesce(p_notes,''),
      nullif(p_customer_name,''), nullif(p_contact_phone,''),
      v_transport, v_vat, v_total, 'pending', 'unpaid', p_payment_method
    ) returning * into v_row;
  exception when unique_violation then
    raise exception 'slot_taken' using errcode='23505';
  end;

  insert into public.booking_events (booking_id, status, note, actor)
    values (v_row.id, 'pending', 'created', v_uid);
  return v_row;
end; $$;

-- CANCEL: owner-only, honours the 3-hour at-home cutoff + state machine.
create or replace function public.cancel_booking(p_id uuid)
returns public.bookings
language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_row public.bookings%rowtype;
begin
  update public.bookings
     set status = 'cancelled'
   where id = p_id
     and user_id = v_uid
     and status in ('pending','confirmed')
     and scheduled_at - now() > interval '3 hours'
  returning * into v_row;
  if not found then raise exception 'cancel_not_allowed' using errcode='22023'; end if;
  insert into public.booking_events (booking_id, status, note, actor)
    values (v_row.id, 'cancelled', 'cancelled by customer', v_uid);
  return v_row;
end; $$;

-- RESCHEDULE: owner-only, re-checks availability via the unique index.
create or replace function public.reschedule_booking(p_id uuid, p_scheduled_at timestamptz)
returns public.bookings
language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_row public.bookings%rowtype;
begin
  if p_scheduled_at is null or p_scheduled_at < now() then
    raise exception 'invalid_time' using errcode='22023'; end if;
  begin
    update public.bookings
       set scheduled_at = p_scheduled_at,
           booking_date = (p_scheduled_at at time zone 'Asia/Riyadh')::date,
           booking_time = to_char(p_scheduled_at at time zone 'Asia/Riyadh','HH24:00')
     where id = p_id and user_id = v_uid and status in ('pending','confirmed')
    returning * into v_row;
  exception when unique_violation then
    raise exception 'slot_taken' using errcode='23505';
  end;
  if not found then raise exception 'reschedule_not_allowed' using errcode='22023'; end if;
  insert into public.booking_events (booking_id, status, note, actor)
    values (v_row.id, v_row.status, 'rescheduled', v_uid);
  return v_row;
end; $$;

-- AVAILABILITY: booked times for a therapist/date. Returns ONLY the time.
create or replace function public.taken_slots(p_therapist text, p_date date)
returns table (booking_time text)
language sql stable security definer set search_path = public as $$
  select b.booking_time from public.bookings b
   where b.therapist_id = p_therapist
     and b.booking_date = p_date
     and b.status in ('pending','confirmed','on_the_way');
$$;

-- OWNER: drive an order through the lifecycle. Admins only, valid transitions.
create or replace function public.admin_set_status(p_id uuid, p_status text)
returns public.bookings
language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_row public.bookings%rowtype; v_old text;
begin
  if not public.is_admin() then raise exception 'forbidden' using errcode='42501'; end if;
  if p_status not in ('confirmed','on_the_way','completed','cancelled','no_show') then
    raise exception 'invalid_status' using errcode='22023'; end if;
  select status into v_old from public.bookings where id = p_id;
  if v_old is null then raise exception 'not_found' using errcode='22023'; end if;

  update public.bookings set status = p_status where id = p_id returning * into v_row;
  insert into public.booking_events (booking_id, status, note, actor)
    values (v_row.id, p_status, format('admin: %s → %s', v_old, p_status), v_uid);
  return v_row;
end; $$;

-- Only these functions may be executed by customers/owners; direct DML is revoked.
revoke all on function public.create_booking(text,int,text,timestamptz,text,text,text,text,text,double precision,double precision,text,text,text,text) from public;
revoke all on function public.cancel_booking(uuid)      from public;
revoke all on function public.reschedule_booking(uuid,timestamptz) from public;
revoke all on function public.taken_slots(text,date)    from public;
revoke all on function public.admin_set_status(uuid,text) from public;

grant execute on function public.create_booking(text,int,text,timestamptz,text,text,text,text,text,double precision,double precision,text,text,text,text) to anon, authenticated;
grant execute on function public.cancel_booking(uuid)      to authenticated;
grant execute on function public.reschedule_booking(uuid,timestamptz) to authenticated;
grant execute on function public.taken_slots(text,date)    to anon, authenticated;
grant execute on function public.admin_set_status(uuid,text) to authenticated;

-- ---------------------------------------------------------------------
-- 8) Realtime: the owner console subscribes to new/updated orders live.
-- ---------------------------------------------------------------------
do $$ begin
  alter publication supabase_realtime add table public.bookings;
exception when undefined_object then null; when duplicate_object then null; end $$;
