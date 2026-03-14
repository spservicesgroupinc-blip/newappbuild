-- ============================================================
-- EMERGENCY FIX: Unblock User Creation
-- Run this FIRST before trying to create users
-- URL: https://app.supabase.com/project/yjxxisvpcorbgreqkofc/sql/new
-- ============================================================
-- This script removes ALL blocking policies and recreates them properly
-- ============================================================

-- STEP 0: Disable the problematic trigger temporarily
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;

-- STEP 1: Drop ALL existing policies that might be blocking
DROP POLICY IF EXISTS "Users can view own data" ON public.users;
DROP POLICY IF EXISTS "Users can insert own data" ON public.users;
DROP POLICY IF EXISTS "Users can update own data" ON public.users;
DROP POLICY IF EXISTS "Users can delete own data" ON public.users;
DROP POLICY IF EXISTS "Enable insert for authenticated users only" ON public.users;
DROP POLICY IF EXISTS "Enable read access for all users" ON public.users;
DROP POLICY IF EXISTS "Enable read access for own users" ON public.users;
DROP POLICY IF EXISTS "Public users are viewable by service_role only" ON public.users;
DROP POLICY IF EXISTS "Users can view all users" ON public.users;

-- Also drop policies on other tables that might conflict
DROP POLICY IF EXISTS "Users can view own settings" ON public.app_settings;
DROP POLICY IF EXISTS "Users can insert own settings" ON public.app_settings;
DROP POLICY IF EXISTS "Users can update own settings" ON public.app_settings;
DROP POLICY IF EXISTS "Enable insert for authenticated users only" ON public.app_settings;
DROP POLICY IF EXISTS "Enable read access for all users" ON public.app_settings;

DROP POLICY IF EXISTS "Users can view own warehouse" ON public.warehouse_counts;
DROP POLICY IF EXISTS "Users can insert own warehouse" ON public.warehouse_counts;
DROP POLICY IF EXISTS "Users can update own warehouse" ON public.warehouse_counts;

DROP POLICY IF EXISTS "Users can view own lifetime usage" ON public.lifetime_usage;
DROP POLICY IF EXISTS "Users can insert own lifetime usage" ON public.lifetime_usage;
DROP POLICY IF EXISTS "Users can update own lifetime usage" ON public.lifetime_usage;

DROP POLICY IF EXISTS "Users can view own company profile" ON public.company_profiles;
DROP POLICY IF EXISTS "Users can insert own company profile" ON public.company_profiles;
DROP POLICY IF EXISTS "Users can update own company profile" ON public.company_profiles;

-- STEP 2: Temporarily disable RLS on public.users to allow manual creation
ALTER TABLE public.users DISABLE ROW LEVEL SECURITY;

-- STEP 3: Recreate enum type safely
DO $$ BEGIN
  CREATE TYPE public.user_role AS ENUM ('admin', 'crew');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- STEP 4: Ensure users table has correct structure
ALTER TABLE public.users 
  DROP CONSTRAINT IF EXISTS users_auth_user_id_fkey CASCADE;

ALTER TABLE public.users 
  ADD CONSTRAINT users_auth_user_id_fkey 
  FOREIGN KEY (auth_user_id) 
  REFERENCES auth.users(id) 
  ON DELETE CASCADE;

-- STEP 5: Create a SIMPLIFIED trigger function that doesn't use complex operations
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  v_user_id UUID;
  v_crew_code TEXT;
BEGIN
  -- Generate simple crew code
  v_crew_code := LPAD(FLOOR(RANDOM() * 9000 + 1000)::TEXT, 4, '0');

  -- Simple insert without complex casting
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
    COALESCE(NEW.raw_user_meta_data->>'company_name', 'New Company'),
    NEW.email,
    'admin'::user_role,
    v_crew_code
  )
  RETURNING id INTO v_user_id;

  -- Create related records with simple inserts
  INSERT INTO public.app_settings (user_id) VALUES (v_user_id) 
    ON CONFLICT (user_id) DO NOTHING;
  INSERT INTO public.warehouse_counts (user_id) VALUES (v_user_id) 
    ON CONFLICT (user_id) DO NOTHING;
  INSERT INTO public.lifetime_usage (user_id) VALUES (v_user_id) 
    ON CONFLICT (user_id) DO NOTHING;
  INSERT INTO public.company_profiles (user_id, company_name, crew_access_pin) 
    VALUES (v_user_id, COALESCE(NEW.raw_user_meta_data->>'company_name', 'New Company'), v_crew_code)
    ON CONFLICT (user_id) DO NOTHING;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- STEP 6: Re-enable RLS
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- STEP 7: Create SIMPLE, NON-BLOCKING policies
-- For public.users - allow service role to do everything, users to read own
CREATE POLICY "service_role_full_access_users" ON public.users
  FOR ALL
  USING (auth.jwt()->>'role' = 'service_role')
  WITH CHECK (auth.jwt()->>'role' = 'service_role');

CREATE POLICY "users_read_own_data" ON public.users
  FOR SELECT
  USING (auth.uid() = auth_user_id);

CREATE POLICY "users_insert_own_data" ON public.users
  FOR INSERT
  WITH CHECK (auth.uid() = auth_user_id OR auth.jwt()->>'role' = 'service_role');

CREATE POLICY "users_update_own_data" ON public.users
  FOR UPDATE
  USING (auth.uid() = auth_user_id);

-- For app_settings
CREATE POLICY "service_role_full_access_settings" ON public.app_settings
  FOR ALL
  USING (auth.jwt()->>'role' = 'service_role');

CREATE POLICY "users_read_own_settings" ON public.app_settings
  FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "users_write_own_settings" ON public.app_settings
  FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- For warehouse_counts
CREATE POLICY "service_role_full_access_warehouse" ON public.warehouse_counts
  FOR ALL
  USING (auth.jwt()->>'role' = 'service_role');

CREATE POLICY "users_read_own_warehouse" ON public.warehouse_counts
  FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "users_write_own_warehouse" ON public.warehouse_counts
  FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- For lifetime_usage
CREATE POLICY "service_role_full_access_lifetime" ON public.lifetime_usage
  FOR ALL
  USING (auth.jwt()->>'role' = 'service_role');

CREATE POLICY "users_read_own_lifetime" ON public.lifetime_usage
  FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "users_write_own_lifetime" ON public.lifetime_usage
  FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- For company_profiles
CREATE POLICY "service_role_full_access_profiles" ON public.company_profiles
  FOR ALL
  USING (auth.jwt()->>'role' = 'service_role');

CREATE POLICY "users_read_own_profiles" ON public.company_profiles
  FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "users_write_own_profiles" ON public.company_profiles
  FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- STEP 8: Recreate the trigger
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- STEP 9: Grant execute permission on the function
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO postgres, service_role, anon, authenticated;

-- ============================================================
-- VERIFICATION
-- ============================================================
SELECT '=== VERIFICATION ===' as status;

-- Check trigger
SELECT 'Trigger exists: ' || 
  CASE WHEN EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'on_auth_user_created') 
  THEN 'YES' ELSE 'NO' END as result;

-- Check function
SELECT 'Function exists: ' || 
  CASE WHEN EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'handle_new_user') 
  THEN 'YES' ELSE 'NO' END as result;

-- Check policies count
SELECT 'Policies on users table: ' || COUNT(*) as result 
FROM pg_policies WHERE tablename = 'users';

-- Show current users
SELECT 'Current users count: ' || COUNT(*) as result FROM public.users;

-- Show auth users count  
SELECT 'Auth users count: ' || COUNT(*) as result FROM auth.users;

-- ============================================================
-- NOW TRY CREATING A USER AGAIN
-- Go to Authentication → Users → Add User
-- ============================================================
