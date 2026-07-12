-- =====================================================================
-- Ya Spa — catalog extension (Phase 3)
-- Adds the detail-screen fields the iOS DataStore already decodes, and the
-- reviews table it reads, so the catalog is fully server-editable (change
-- services / therapists / prices / reviews with no app update). The app has
-- built-in fallbacks, so this is additive and safe.
-- =====================================================================

-- services: richer detail-screen copy (DataStore.ServiceRow)
alter table public.services add column if not exists pressure_ar text;
alter table public.services add column if not exists pressure_en text;
alter table public.services add column if not exists benefits_ar text[];
alter table public.services add column if not exists benefits_en text[];

-- therapists: profile fields (DataStore.TherapistRow)
alter table public.therapists add column if not exists reviews      int  not null default 0;
alter table public.therapists add column if not exists specialty_ar text;
alter table public.therapists add column if not exists specialty_en text;
alter table public.therapists add column if not exists bio_ar       text;
alter table public.therapists add column if not exists bio_en       text;

-- reviews the app lists (DataStore.refresh() reads public.reviews)
create table if not exists public.reviews (
  id         uuid primary key default gen_random_uuid(),
  name_ar    text,
  name_en    text,
  rating     int  not null check (rating between 1 and 5),
  text_ar    text,
  text_en    text,
  created_at timestamptz not null default now()
);
alter table public.reviews enable row level security;
create policy "reviews_public_read" on public.reviews for select using (true);

-- seed a few reviews so the social-proof section has live data
insert into public.reviews (name_ar, name_en, rating, text_ar, text_en) values
 ('نورة','Noura',5,'تجربة راقية وخصوصية تامة، المعالِجة محترفة جدًا.','An elegant experience with total privacy — very professional.'),
 ('ليان','Layan',5,'حجزت بسهولة وجت المعالِجة بالوقت بالضبط.','Booked in seconds and she arrived right on time.'),
 ('أمل','Amal',5,'أفضل مساج جربته بجدة، رجعت أحجز ثاني مرة.','Best massage I''ve had in Jeddah — already booked again.')
on conflict do nothing;
