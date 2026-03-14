# Supabase Auth Setup Fix

## Problem
The app was using custom RPC-based authentication instead of Supabase's built-in Auth system. This has been fixed.

## Quick Start (Do This First!)

1. **Open Supabase Dashboard**: https://app.supabase.com/project/yjxxisvpcorbgreqkofc/sql/new
2. **Copy & Paste**: Open `RUN_THIS_IN_SUPABASE.sql` and copy all contents
3. **Run SQL**: Paste into SQL Editor and click **Run**
4. **Done!** The auth trigger is now fixed.

## What Was Changed

### 1. Updated `services/supabase.ts`
- `loginUser()` now uses `supabase.auth.signInWithPassword()`
- `signupUser()` now uses `supabase.auth.signUp()` with metadata
- `loginCrew()` still uses database lookup (for temporary field access)
- Session management now integrates with Supabase Auth

### 2. Created Migration: `005_auth_trigger_fix.sql`
This migration fixes the `handle_new_user` trigger to properly work with Supabase Auth.

## Setup Steps

### Step 1: Apply the Auth Trigger Fix

1. Go to your Supabase Dashboard: https://app.supabase.com/project/yjxxisvpcorbgreqkofc/sql/new
2. Copy the contents of `RUN_THIS_IN_SUPABASE.sql` (or `supabase/migrations/005_auth_trigger_fix.sql`)
3. Paste into the SQL Editor
4. Click **Run**

### Step 2: Configure Supabase Auth Settings

1. Go to **Authentication** → **Providers** in Supabase Dashboard
2. Ensure **Email** provider is enabled
3. Go to **Authentication** → **Settings**
4. Under **Auth Providers**, verify Email is toggled ON
5. (Optional) Disable email confirmation for testing:
   - Go to **Authentication** → **Settings**
   - Find **Enable email confirmations** and toggle OFF (for development only)

### Step 3: Update Site URL

1. Go to **Authentication** → **URL Configuration**
2. Set **Site URL** to: `http://localhost:3000` (for development)
3. Under **Redirect URLs**, add:
   - `http://localhost:3000/*`
   - `http://localhost:3000`

### Step 4: Test the Setup

1. Start the dev server: `npm run dev`
2. Click **Sign Up** on the login page
3. Create an account with:
   - Email: `test@example.com`
   - Password: `Test123!` (must be 8+ chars, with number and special char)
   - Company Name: `Test Company`
4. You should be logged in automatically
5. Check the **Authentication** → **Users** table in Supabase - you should see the new user
6. Check the `public.users` table - you should see the linked user record

## Troubleshooting

### Error: "User profile not found"
This means the trigger didn't create the `public.users` record. Run the migration SQL again.

### Error: "Invalid login credentials"
Make sure you're using the email and password you signed up with. Check Supabase Dashboard → Authentication → Users.

### Email confirmation required
For development, you can disable email confirmation:
- Go to **Authentication** → **Settings**
- Toggle OFF **Enable email confirmations**

Or, confirm the email by clicking the link sent to the email address.

### Crew login not working
Make sure the admin user has a `crew_code` generated. Check the `public.users` table.

## Database Schema

After signup, the following records are automatically created:

1. `auth.users` - Supabase Auth user
2. `public.users` - User profile with role and crew_code
3. `public.app_settings` - Default app settings
4. `public.warehouse_counts` - Default warehouse inventory (0 sets)
5. `public.lifetime_usage` - Lifetime foam usage (0)
6. `public.company_profiles` - Company profile

## Security Notes

- The anon key is safe to use in client-side code
- RLS (Row Level Security) ensures users can only access their own data
- The service_role key should NEVER be exposed in client code
- Crew login is a lightweight auth for temporary/field access

## Next Steps

1. Test creating estimates
2. Test sync up/down functionality
3. Test storage uploads (PDFs, images)
4. Test crew login with the generated PIN
