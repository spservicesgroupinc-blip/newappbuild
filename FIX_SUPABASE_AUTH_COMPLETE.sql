-- ============================================================
-- COMPLETE SUPABASE AUTH FIX
-- Run this ENTIRE script in Supabase Dashboard SQL Editor
-- URL: https://app.supabase.com/project/yjxxisvpcorbgreqkofc/sql/new
-- ============================================================
-- This script fixes all authentication issues including:
-- 1. Creates/fixes the user_role enum type
-- 2. Creates/fixes the users table with proper columns
-- 3. Creates/fixes the auth trigger
-- 4. Verifies the setup
-- ============================================================

-- STEP 1: Create enum type if it doesn't exist
DO $$ BEGIN
  CREATE TYPE public.user_role AS ENUM ('admin', 'crew');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- STEP 2: Drop existing trigger and function
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;

-- STEP 3: Create users table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid() UNIQUE,
  auth_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  username TEXT NOT NULL,
  company_name TEXT NOT NULL,
  email TEXT,
  role user_role DEFAULT 'admin',
  crew_code TEXT,
  spreadsheet_id TEXT,
  folder_id TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create index on auth_user_id for faster lookups
CREATE INDEX IF NOT EXISTS idx_users_auth_user_id ON public.users(auth_user_id);
CREATE INDEX IF NOT EXISTS idx_users_crew_code ON public.users(crew_code);

-- STEP 4: Create other required tables if they don't exist
CREATE TABLE IF NOT EXISTS public.app_settings (
  user_id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  yields_json JSONB DEFAULT '{}',
  costs_json JSONB DEFAULT '{}',
  expenses_json JSONB DEFAULT '{}',
  job_notes TEXT,
  sqft_rates_json JSONB DEFAULT '{}',
  pricing_mode TEXT DEFAULT 'level_pricing',
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.warehouse_counts (
  user_id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  open_cell_sets INTEGER DEFAULT 0,
  closed_cell_sets INTEGER DEFAULT 0,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.lifetime_usage (
  user_id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  open_cell NUMERIC DEFAULT 0,
  closed_cell NUMERIC DEFAULT 0,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.company_profiles (
  user_id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  company_name TEXT NOT NULL,
  address_line1 TEXT,
  address_line2 TEXT,
  city TEXT,
  state TEXT,
  zip TEXT,
  phone TEXT,
  email TEXT,
  website TEXT,
  logo_url TEXT,
  crew_access_pin TEXT,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- STEP 5: Create the trigger function
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  v_user_id UUID;
  v_crew_code TEXT;
BEGIN
  -- Generate crew code (4-digit PIN)
  v_crew_code := LPAD(FLOOR(RANDOM() * 9000 + 1000)::TEXT, 4, '0');

  -- Insert into public.users
  INSERT INTO public.users (
    auth_user_id,
    username,
    company_name,
    email,
    role,
    crew_code
  )
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'username', NEW.email),
    COALESCE(NEW.raw_user_meta_data->>'company_name', 'Unknown Company'),
    NEW.email,
    COALESCE((NEW.raw_user_meta_data->>'role')::user_role, 'admin'),
    v_crew_code
  )
  RETURNING id INTO v_user_id;

  -- Create default app settings
  INSERT INTO public.app_settings (user_id)
  VALUES (v_user_id)
  ON CONFLICT (user_id) DO NOTHING;

  -- Create default warehouse counts
  INSERT INTO public.warehouse_counts (user_id)
  VALUES (v_user_id)
  ON CONFLICT (user_id) DO NOTHING;

  -- Create default lifetime usage
  INSERT INTO public.lifetime_usage (user_id)
  VALUES (v_user_id)
  ON CONFLICT (user_id) DO NOTHING;

  -- Create company profile
  INSERT INTO public.company_profiles (user_id, company_name, crew_access_pin)
  VALUES (
    v_user_id,
    COALESCE(NEW.raw_user_meta_data->>'company_name', 'Unknown Company'),
    v_crew_code
  )
  ON CONFLICT (user_id) DO NOTHING;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- STEP 6: Create trigger
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- STEP 7: Grant permissions
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO postgres, service_role;

-- STEP 8: Enable Row Level Security (RLS) on all tables
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.warehouse_counts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lifetime_usage ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.company_profiles ENABLE ROW LEVEL SECURITY;

-- STEP 9: Create RLS policies
-- Users can only see their own data
DROP POLICY IF EXISTS "Users can view own data" ON public.users;
CREATE POLICY "Users can view own data" ON public.users
  FOR SELECT USING (auth.uid() = auth_user_id);

DROP POLICY IF EXISTS "Users can insert own data" ON public.users;
CREATE POLICY "Users can insert own data" ON public.users
  FOR INSERT WITH CHECK (auth.uid() = auth_user_id);

DROP POLICY IF EXISTS "Users can update own data" ON public.users;
CREATE POLICY "Users can update own data" ON public.users
  FOR UPDATE USING (auth.uid() = auth_user_id);

-- App settings policies
DROP POLICY IF EXISTS "Users can view own settings" ON public.app_settings;
CREATE POLICY "Users can view own settings" ON public.app_settings
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own settings" ON public.app_settings;
CREATE POLICY "Users can insert own settings" ON public.app_settings
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own settings" ON public.app_settings;
CREATE POLICY "Users can update own settings" ON public.app_settings
  FOR UPDATE USING (auth.uid() = user_id);

-- Warehouse counts policies
DROP POLICY IF EXISTS "Users can view own warehouse" ON public.warehouse_counts;
CREATE POLICY "Users can view own warehouse" ON public.warehouse_counts
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own warehouse" ON public.warehouse_counts;
CREATE POLICY "Users can insert own warehouse" ON public.warehouse_counts
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own warehouse" ON public.warehouse_counts;
CREATE POLICY "Users can update own warehouse" ON public.warehouse_counts
  FOR UPDATE USING (auth.uid() = user_id);

-- Lifetime usage policies
DROP POLICY IF EXISTS "Users can view own lifetime usage" ON public.lifetime_usage;
CREATE POLICY "Users can view own lifetime usage" ON public.lifetime_usage
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own lifetime usage" ON public.lifetime_usage;
CREATE POLICY "Users can insert own lifetime usage" ON public.lifetime_usage
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own lifetime usage" ON public.lifetime_usage;
CREATE POLICY "Users can update own lifetime usage" ON public.lifetime_usage
  FOR UPDATE USING (auth.uid() = user_id);

-- Company profiles policies
DROP POLICY IF EXISTS "Users can view own company profile" ON public.company_profiles;
CREATE POLICY "Users can view own company profile" ON public.company_profiles
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own company profile" ON public.company_profiles;
CREATE POLICY "Users can insert own company profile" ON public.company_profiles
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own company profile" ON public.company_profiles;
CREATE POLICY "Users can update own company profile" ON public.company_profiles
  FOR UPDATE USING (auth.uid() = user_id);

-- STEP 10: Verification queries
SELECT '=== VERIFICATION RESULTS ===' as status;

-- Check trigger exists
SELECT 'Trigger exists: ' || EXISTS (
  SELECT 1 FROM pg_trigger WHERE tgname = 'on_auth_user_created'
) as result;

-- Check function exists
SELECT 'Function exists: ' || EXISTS (
  SELECT 1 FROM pg_proc WHERE proname = 'handle_new_user'
) as result;

-- Check enum type exists
SELECT 'Enum type exists: ' || EXISTS (
  SELECT 1 FROM pg_type WHERE typname = 'user_role'
) as result;

-- Count existing users
SELECT 'Current user count: ' || COUNT(*) as result FROM public.users;

-- ============================================================
-- DONE! You can now test signup at http://localhost:3000
-- ============================================================
