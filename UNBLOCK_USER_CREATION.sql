-- ============================================================
-- QUICK FIX: Just let me create users manually!
-- Run this to unblock manual user creation in Supabase
-- URL: https://app.supabase.com/project/yjxxisvpcorbgreqkofc/sql/new
-- ============================================================

-- 1. Remove the problematic trigger
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;

-- 2. Disable RLS on users table (allows manual creation)
ALTER TABLE public.users DISABLE ROW LEVEL SECURITY;

-- 3. Drop all blocking policies
DROP POLICY IF EXISTS "service_role_full_access_users" ON public.users;
DROP POLICY IF EXISTS "users_read_own_data" ON public.users;
DROP POLICY IF EXISTS "users_insert_own_data" ON public.users;
DROP POLICY IF EXISTS "users_update_own_data" ON public.users;
DROP POLICY IF EXISTS "Enable insert for authenticated users only" ON public.users;
DROP POLICY IF EXISTS "Enable read access for all users" ON public.users;
DROP POLICY IF EXISTS "Public users are viewable by service_role only" ON public.users;
DROP POLICY IF EXISTS "Users can view all users" ON public.users;
DROP POLICY IF EXISTS "Users can view own data" ON public.users;
DROP POLICY IF EXISTS "Users can insert own data" ON public.users;
DROP POLICY IF EXISTS "Users can update own data" ON public.users;

-- 4. Ensure enum type exists
DO $$ BEGIN
  CREATE TYPE public.user_role AS ENUM ('admin', 'crew');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- 5. Verify users table structure
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

-- 6. Create indexes
CREATE INDEX IF NOT EXISTS idx_users_auth_user_id ON public.users(auth_user_id);
CREATE INDEX IF NOT EXISTS idx_users_crew_code ON public.users(crew_code);

-- ============================================================
-- VERIFICATION
-- ============================================================
SELECT 'RLS disabled on users: ' || 
  CASE WHEN relrowsecurity = false THEN 'YES' ELSE 'NO' END as result
FROM pg_class WHERE relname = 'users';

SELECT 'Trigger removed: ' || 
  CASE WHEN NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'on_auth_user_created') 
  THEN 'YES' ELSE 'NO' END as result;

-- ============================================================
-- NOW YOU CAN CREATE USERS MANUALLY IN SUPABASE DASHBOARD
-- After creating user in Authentication, add them to public.users:
--
-- INSERT INTO public.users (auth_user_id, username, company_name, email, role, crew_code)
-- VALUES ('AUTH-USER-ID-HERE', 'username', 'Company Name', 'email@example.com', 'admin', '1234');
-- ============================================================
