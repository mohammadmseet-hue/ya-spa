-- =====================================================================
-- Ya Spa — Supabase schema (Phase 1: backend foundation)
-- Accounts (phone auth) · therapists · services · bookings · payments
-- with Row-Level Security so each user only sees their own data.
-- =====================================================================

-- ---------- Profiles: one row per authenticated (phone) user ----------
create table if not exists public.profiles (
  id         uuid primary key references auth.users(id) on delete cascade,
  phone      text,
  full_name  text,
  district   text,
  created_at timestamptz not null default now()
);

-- ---------- Massage services catalog ----------
create table if not exists public.services (
  id       text primary key,
  name_ar  text not null,
  name_en  text not null,
  desc_ar  text,
  desc_en  text,
  minutes  int  not null,
  price    int  not null,           -- SAR
  symbol   text,                    -- SF Symbol
  active   boolean not null default true,
  sort     int not null default 0
);

-- ---------- Therapists (women-only providers) ----------
create table if not exists public.therapists (
  id       text primary key,
  name_ar  text not null,
  name_en  text not null,
  rating   numeric(3,2) not null default 5.0,
  years    int not null default 0,
  verified boolean not null default true,
  active   boolean not null default true
);

-- ---------- Bookings ----------
do $$ begin
  create type booking_status as enum ('pending','confirmed','completed','cancelled');
exception when duplicate_object then null; end $$;

do $$ begin
  create type payment_state as enum ('unpaid','paid','refunded','failed');
exception when duplicate_object then null; end $$;

create table if not exists public.bookings (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references auth.users(id) on delete cascade,
  service_id      text references public.services(id),
  service_name_ar text,
  service_name_en text,
  minutes         int,
  price           int,
  therapist_id    text references public.therapists(id),
  therapist_name  text,
  booking_date    date not null,
  booking_time    text not null,
  district        text,
  notes           text,
  transport       int not null default 30,
  vat             int not null default 0,
  total           int not null,
  status          booking_status not null default 'pending',
  payment_status  payment_state  not null default 'unpaid',
  created_at      timestamptz not null default now()
);
create index if not exists bookings_user_idx on public.bookings(user_id, created_at desc);

-- ---------- Payments (Moyasar) ----------
create table if not exists public.payments (
  id         uuid primary key default gen_random_uuid(),
  booking_id uuid references public.bookings(id) on delete cascade,
  user_id    uuid not null references auth.users(id) on delete cascade,
  moyasar_id text,
  amount     int not null,          -- halalas
  method     text,                  -- creditcard / applepay / stcpay / mada
  status     text not null default 'initiated',
  created_at timestamptz not null default now()
);

-- ---------- Row-Level Security ----------
alter table public.profiles   enable row level security;
alter table public.bookings   enable row level security;
alter table public.payments   enable row level security;
alter table public.services   enable row level security;
alter table public.therapists enable row level security;

-- profiles: a user manages only their own
create policy "profiles_read_own"   on public.profiles for select using (auth.uid() = id);
create policy "profiles_insert_own" on public.profiles for insert with check (auth.uid() = id);
create policy "profiles_update_own" on public.profiles for update using (auth.uid() = id);

-- bookings: a user manages only their own
create policy "bookings_read_own"   on public.bookings for select using (auth.uid() = user_id);
create policy "bookings_insert_own" on public.bookings for insert with check (auth.uid() = user_id);
create policy "bookings_update_own" on public.bookings for update using (auth.uid() = user_id);

-- payments: a user reads/creates only their own (server verifies via service role)
create policy "payments_read_own"   on public.payments for select using (auth.uid() = user_id);
create policy "payments_insert_own" on public.payments for insert with check (auth.uid() = user_id);

-- catalog: public read
create policy "services_public_read"   on public.services   for select using (true);
create policy "therapists_public_read" on public.therapists for select using (true);

-- ---------- Auto-create a profile row when a user signs up ----------
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, phone) values (new.id, new.phone)
  on conflict (id) do nothing;
  return new;
end; $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------- Seed the catalog ----------
insert into public.services (id,name_ar,name_en,desc_ar,desc_en,minutes,price,symbol,sort) values
 ('swedish','المساج السويدي','Swedish Massage','مساج استرخاء لطيف يحسّن الدورة الدموية ويذيب التوتر.','A gentle relaxation massage that boosts circulation and melts tension.',60,199,'leaf.fill',1),
 ('deep','مساج الأنسجة العميقة','Deep Tissue','ضغط أعمق يستهدف عقد العضلات والشدّ المزمن.','Deeper pressure targeting muscle knots and chronic tightness.',60,249,'hand.raised.fill',2),
 ('stone','مساج الأحجار الساخنة','Hot Stone','أحجار بركانية دافئة ترخي العضلات بعمق.','Warm volcanic stones deeply relax muscles.',75,279,'flame.fill',3),
 ('thai','المساج التايلندي','Thai Massage','تمدّد ومطّ لطيف يعيد المرونة والطاقة.','Assisted stretching that restores flexibility and energy.',90,289,'figure.cooldown',4),
 ('aroma','العلاج بالزيوت العطرية','Aromatherapy','زيوت عطرية مهدّئة لاسترخاءٍ عميق.','Calming essential oils for deep relaxation.',60,219,'drop.fill',5),
 ('foot','مساج القدمين الانعكاسي','Foot Reflexology','ضغط على نقاط القدم يريح كامل الجسم.','Pressure-point foot work that relaxes the whole body.',45,149,'figure.walk',6)
on conflict (id) do nothing;

insert into public.therapists (id,name_ar,name_en,rating,years) values
 ('reem','ريم الغامدي','Reem G.',4.97,7),
 ('hind','هند العتيبي','Hind A.',4.92,5),
 ('sara','سارة القحطاني','Sara Q.',4.89,4)
on conflict (id) do nothing;
