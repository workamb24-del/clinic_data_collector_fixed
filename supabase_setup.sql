-- ============================================================
-- Clinic Data Collector - Supabase SQL Setup
-- ============================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- TABLE: profiles
-- ============================================================
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  auth_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT NOT NULL,
  phone TEXT,
  role TEXT NOT NULL CHECK (role IN ('admin', 'agent')),
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_profiles_auth_user_id ON public.profiles(auth_user_id);
CREATE INDEX IF NOT EXISTS idx_profiles_role ON public.profiles(role);

-- ============================================================
-- TABLE: clinics
-- ============================================================
CREATE TABLE IF NOT EXISTS public.clinics (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  code TEXT UNIQUE NOT NULL,
  clinic_name TEXT,
  doctor_name TEXT,
  phone TEXT,
  mobile TEXT,
  specialty TEXT,
  city TEXT,
  area TEXT,
  address_text TEXT,
  lat DOUBLE PRECISION,
  lng DOUBLE PRECISION,
  image_url TEXT,
  raw_text TEXT,
  confidence DOUBLE PRECISION,
  status TEXT DEFAULT 'New' CHECK (status IN ('New', 'Reviewed', 'Duplicate', 'Invalid')),
  created_by UUID REFERENCES public.profiles(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_clinics_created_by ON public.clinics(created_by);
CREATE INDEX IF NOT EXISTS idx_clinics_status ON public.clinics(status);
CREATE INDEX IF NOT EXISTS idx_clinics_city ON public.clinics(city);
CREATE INDEX IF NOT EXISTS idx_clinics_created_at ON public.clinics(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_clinics_code ON public.clinics(code);

-- ============================================================
-- TABLE: app_settings
-- ============================================================
CREATE TABLE IF NOT EXISTS public.app_settings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  key TEXT UNIQUE NOT NULL,
  value JSONB,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Insert default settings
INSERT INTO public.app_settings (key, value) VALUES
  ('clinic_counter', '{"count": 0}'::jsonb),
  ('ocr_provider', '"mock"'::jsonb),
  ('app_version', '"1.0.0"'::jsonb)
ON CONFLICT (key) DO NOTHING;

-- ============================================================
-- FUNCTION: auto-update updated_at
-- ============================================================
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER trigger_clinics_updated_at
  BEFORE UPDATE ON public.clinics
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- ============================================================
-- FUNCTION: generate clinic code (CL-000001)
-- ============================================================
CREATE OR REPLACE FUNCTION public.generate_clinic_code()
RETURNS TEXT AS $$
DECLARE
  v_count INTEGER;
  v_code TEXT;
BEGIN
  UPDATE public.app_settings
  SET value = jsonb_set(value, '{count}', ((value->>'count')::int + 1)::text::jsonb)
  WHERE key = 'clinic_counter'
  RETURNING (value->>'count')::int INTO v_count;

  v_code := 'CL-' || LPAD(v_count::text, 6, '0');
  RETURN v_code;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- FUNCTION: create profile on auth signup
-- ============================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  -- Only create profile if metadata exists
  IF NEW.raw_user_meta_data IS NOT NULL AND NEW.raw_user_meta_data->>'full_name' IS NOT NULL THEN
    INSERT INTO public.profiles (auth_user_id, full_name, phone, role)
    VALUES (
      NEW.id,
      NEW.raw_user_meta_data->>'full_name',
      NEW.raw_user_meta_data->>'phone',
      COALESCE(NEW.raw_user_meta_data->>'role', 'agent')
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================
-- FUNCTION: get profile by auth user id
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_my_profile()
RETURNS public.profiles AS $$
  SELECT * FROM public.profiles WHERE auth_user_id = auth.uid() LIMIT 1;
$$ LANGUAGE sql SECURITY DEFINER;

-- ============================================================
-- FUNCTION: statistics for admin dashboard
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_dashboard_stats()
RETURNS JSONB AS $$
DECLARE
  result JSONB;
BEGIN
  SELECT jsonb_build_object(
    'total_clinics', (SELECT COUNT(*) FROM public.clinics),
    'today_clinics', (SELECT COUNT(*) FROM public.clinics WHERE created_at::date = CURRENT_DATE),
    'total_agents', (SELECT COUNT(*) FROM public.profiles WHERE role = 'agent'),
    'active_agents', (SELECT COUNT(*) FROM public.profiles WHERE role = 'agent' AND is_active = true),
    'incomplete_records', (SELECT COUNT(*) FROM public.clinics WHERE clinic_name IS NULL OR phone IS NULL),
    'status_breakdown', (
      SELECT jsonb_object_agg(status, cnt)
      FROM (SELECT status, COUNT(*) as cnt FROM public.clinics GROUP BY status) s
    ),
    'by_agent', (
      SELECT jsonb_agg(row)
      FROM (
        SELECT p.full_name, COUNT(c.id) as count
        FROM public.profiles p
        LEFT JOIN public.clinics c ON c.created_by = p.id
        WHERE p.role = 'agent'
        GROUP BY p.id, p.full_name
        ORDER BY count DESC
      ) row
    )
  ) INTO result;
  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================

-- Enable RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clinics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

-- Helper function: get current user role
CREATE OR REPLACE FUNCTION public.current_user_role()
RETURNS TEXT AS $$
  SELECT role FROM public.profiles WHERE auth_user_id = auth.uid() LIMIT 1;
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Helper function: is current user active
CREATE OR REPLACE FUNCTION public.is_current_user_active()
RETURNS BOOLEAN AS $$
  SELECT is_active FROM public.profiles WHERE auth_user_id = auth.uid() LIMIT 1;
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Helper function: get current profile id
CREATE OR REPLACE FUNCTION public.current_profile_id()
RETURNS UUID AS $$
  SELECT id FROM public.profiles WHERE auth_user_id = auth.uid() LIMIT 1;
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- ---- PROFILES POLICIES ----
DROP POLICY IF EXISTS "Admin can manage all profiles" ON public.profiles;
CREATE POLICY "Admin can manage all profiles"
  ON public.profiles FOR ALL
  USING (public.current_user_role() = 'admin' AND public.is_current_user_active() = true);

DROP POLICY IF EXISTS "Agent can read own profile" ON public.profiles;
CREATE POLICY "Agent can read own profile"
  ON public.profiles FOR SELECT
  USING (auth_user_id = auth.uid() AND public.is_current_user_active() = true);

-- ---- CLINICS POLICIES ----
DROP POLICY IF EXISTS "Admin full access to clinics" ON public.clinics;
CREATE POLICY "Admin full access to clinics"
  ON public.clinics FOR ALL
  USING (public.current_user_role() = 'admin' AND public.is_current_user_active() = true);

DROP POLICY IF EXISTS "Agent can insert clinic" ON public.clinics;
CREATE POLICY "Agent can insert clinic"
  ON public.clinics FOR INSERT
  WITH CHECK (
    public.current_user_role() = 'agent'
    AND public.is_current_user_active() = true
    AND created_by = public.current_profile_id()
  );

DROP POLICY IF EXISTS "Agent can view own clinics" ON public.clinics;
CREATE POLICY "Agent can view own clinics"
  ON public.clinics FOR SELECT
  USING (
    public.current_user_role() = 'agent'
    AND public.is_current_user_active() = true
    AND created_by = public.current_profile_id()
  );

DROP POLICY IF EXISTS "Agent can update own clinics" ON public.clinics;
CREATE POLICY "Agent can update own clinics"
  ON public.clinics FOR UPDATE
  USING (
    public.current_user_role() = 'agent'
    AND public.is_current_user_active() = true
    AND created_by = public.current_profile_id()
  );

-- ---- APP_SETTINGS POLICIES ----
DROP POLICY IF EXISTS "Admin can manage settings" ON public.app_settings;
CREATE POLICY "Admin can manage settings"
  ON public.app_settings FOR ALL
  USING (public.current_user_role() = 'admin');

DROP POLICY IF EXISTS "All users can read settings" ON public.app_settings;
CREATE POLICY "All users can read settings"
  ON public.app_settings FOR SELECT
  USING (auth.uid() IS NOT NULL);

-- ============================================================
-- STORAGE BUCKET
-- ============================================================

-- Create storage bucket (run this in Supabase dashboard or via API)
-- INSERT INTO storage.buckets (id, name, public) VALUES ('clinic-signs', 'clinic-signs', false);

-- Storage RLS Policies
-- Allow authenticated users to upload to their folder
-- CREATE POLICY "Users upload to own folder"
--   ON storage.objects FOR INSERT
--   WITH CHECK (bucket_id = 'clinic-signs' AND auth.uid()::text = (storage.foldername(name))[1]);

-- Allow users to read their own files, admin reads all
-- CREATE POLICY "Users read own files"
--   ON storage.objects FOR SELECT
--   USING (bucket_id = 'clinic-signs' AND (
--     auth.uid()::text = (storage.foldername(name))[1]
--     OR public.current_user_role() = 'admin'
--   ));

-- ============================================================
-- SEED: Create first admin user (run after creating auth user)
-- Replace 'YOUR_AUTH_USER_ID' with the actual UUID from auth.users
-- ============================================================
-- INSERT INTO public.profiles (auth_user_id, full_name, phone, role, is_active)
-- VALUES ('YOUR_AUTH_USER_ID', 'مدير النظام', '0900000000', 'admin', true);

-- ============================================================
-- DONE
-- ============================================================


-- MVP patch: columns required by the current Flutter app
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
alter table clinics alter column name drop not null;

insert into storage.buckets (id, name, public)
values ('clinic-signs', 'clinic-signs', true)
on conflict (id) do update set public = true;

drop policy if exists "clinic_signs_upload" on storage.objects;
drop policy if exists "clinic_signs_read" on storage.objects;
create policy "clinic_signs_upload"
on storage.objects
for insert
to authenticated
with check (bucket_id = 'clinic-signs');
create policy "clinic_signs_read"
on storage.objects
for select
to authenticated
using (bucket_id = 'clinic-signs');
