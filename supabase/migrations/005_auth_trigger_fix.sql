-- ============================================================
-- SUPABASE AUTH TRIGGER FIX
-- Migration 005: Fix handle_new_user trigger for Supabase Auth
-- ============================================================
-- This migration fixes the auth trigger to properly work with 
-- Supabase's built-in authentication system.
-- 
-- Run this in your Supabase Dashboard SQL Editor:
-- https://app.supabase.com/project/yjxxisvpcorbgreqkofc/sql/new
-- ============================================================

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- Drop existing function if it exists  
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;

-- Create new trigger function that works with Supabase Auth
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

-- Create trigger on auth.users
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO postgres, service_role;

-- ============================================================
-- VERIFICATION QUERIES
-- Run these to confirm the trigger was created successfully
-- ============================================================

-- Check if trigger exists
SELECT 
  tgname as trigger_name,
  tgrelid::regclass as table_name,
  tgenabled as enabled
FROM pg_trigger 
WHERE tgname = 'on_auth_user_created';

-- Check if function exists
SELECT 
  proname as function_name,
  langname as language
FROM pg_proc p
JOIN pg_language l ON p.prolang = l.oid
WHERE proname = 'handle_new_user';
