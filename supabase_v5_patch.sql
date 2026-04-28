-- Clinic Data Collector v5 Patch
-- يحافظ على مشروعك الحالي ويضيف الأعمدة/الفهارس اللازمة للنسخة v5.

alter table clinics add column if not exists name text;
alter table clinics alter column name drop not null;
alter table clinics add column if not exists clinic_name text;
alter table clinics add column if not exists doctor_name text;
alter table clinics add column if not exists mobile text;
alter table clinics add column if not exists phone text;
alter table clinics add column if not exists specialty text;
alter table clinics add column if not exists city text;
alter table clinics add column if not exists area text;
alter table clinics add column if not exists address_text text;
alter table clinics add column if not exists lat double precision;
alter table clinics add column if not exists lng double precision;
alter table clinics add column if not exists image_url text;
alter table clinics add column if not exists raw_text text;
alter table clinics add column if not exists confidence double precision;
alter table clinics add column if not exists created_by uuid;
alter table clinics add column if not exists status text default 'New';
alter table clinics add column if not exists updated_at timestamp default now();

create index if not exists idx_clinics_mobile on clinics(mobile);
create index if not exists idx_clinics_phone on clinics(phone);
create index if not exists idx_clinics_status on clinics(status);
create index if not exists idx_clinics_created_by on clinics(created_by);
create index if not exists idx_clinics_created_at on clinics(created_at desc);

-- Storage bucket
insert into storage.buckets (id, name, public)
values ('clinic-signs', 'clinic-signs', true)
on conflict (id) do update set public = true;

drop policy if exists "clinic_signs_upload" on storage.objects;
drop policy if exists "clinic_signs_read" on storage.objects;
create policy "clinic_signs_upload" on storage.objects for insert to authenticated with check (bucket_id = 'clinic-signs');
create policy "clinic_signs_read" on storage.objects for select to authenticated using (bucket_id = 'clinic-signs');

-- سياسات مؤقتة مرنة للتشغيل. شددها لاحقًا بعد استقرار النسخة.
alter table clinics enable row level security;
drop policy if exists "clinics_select_all" on clinics;
drop policy if exists "clinics_insert_all" on clinics;
drop policy if exists "clinics_update_all" on clinics;
create policy "clinics_select_all" on clinics for select to authenticated using (true);
create policy "clinics_insert_all" on clinics for insert to authenticated with check (true);
create policy "clinics_update_all" on clinics for update to authenticated using (true) with check (true);
