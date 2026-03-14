-- ============================================================
-- QUICK FIX: Run this in Supabase Dashboard SQL Editor
-- ============================================================
-- URL: https://app.supabase.com/project/yjxxisvpcorbgreqkofc/sql/new
-- Copy this entire file and paste it in the SQL Editor, then click Run
-- ============================================================

-- Step 1: Drop old trigger
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;

-- Step 2: Create new trigger function
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  v_user_id UUID;
  v_crew_code TEXT;
BEGIN
  v_crew_code := LPAD(FLOOR(RANDOM() * 9000 + 1000)::TEXT, 4, '0');

  INSERT INTO public.users (auth_user_id, username, company_name, email, role, crew_code)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'username', NEW.email),
    COALESCE(NEW.raw_user_meta_data->>'company_name', 'Unknown Company'),
    NEW.email,
    COALESCE((NEW.raw_user_meta_data->>'role')::user_role, 'admin'),
    v_crew_code
  )
  RETURNING id INTO v_user_id;

  INSERT INTO public.app_settings (user_id) VALUES (v_user_id) ON CONFLICT (user_id) DO NOTHING;
  INSERT INTO public.warehouse_counts (user_id) VALUES (v_user_id) ON CONFLICT (user_id) DO NOTHING;
  INSERT INTO public.lifetime_usage (user_id) VALUES (v_user_id) ON CONFLICT (user_id) DO NOTHING;
  INSERT INTO public.company_profiles (user_id, company_name, crew_access_pin)
  VALUES (v_user_id, COALESCE(NEW.raw_user_meta_data->>'company_name', 'Unknown Company'), v_crew_code)
  ON CONFLICT (user_id) DO NOTHING;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 3: Create trigger
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Step 4: Verify (should return 1 row)
SELECT tgname FROM pg_trigger WHERE tgname = 'on_auth_user_created';
