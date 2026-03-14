# Supabase Sign Up Fix

## Problem
The sign up page was not working with Supabase authentication.

## Solution Applied

### 1. Code Fixes (Already Done)
I've updated `services/supabase.ts` with:
- Better error handling and logging
- Improved signup flow with fallback manual user creation
- Better error messages for common issues
- Console logging for debugging

### 2. Database Setup (REQUIRED - Do This Now!)

**You need to run the SQL migration to fix the database trigger.**

#### Steps:

1. **Open Supabase SQL Editor**
   - Go to: https://app.supabase.com/project/yjxxisvpcorbgreqkofc/sql/new

2. **Run the Complete Fix Script**
   - Open the file: `FIX_SUPABASE_AUTH_COMPLETE.sql` in this project
   - Copy the ENTIRE contents
   - Paste into the Supabase SQL Editor
   - Click **Run**

3. **Verify the Fix**
   - The script will show verification results at the end
   - All results should show "true" or existing

4. **Configure Supabase Auth Settings**
   - Go to **Authentication** → **URL Configuration**
   - Set **Site URL** to: `http://localhost:3000`
   - Add to **Redirect URLs**: 
     - `http://localhost:3000/*`
     - `http://localhost:3000`
   
5. **Disable Email Confirmation (for testing)**
   - Go to **Authentication** → **Settings**
   - Find **Enable email confirmations**
   - Toggle it **OFF** (you can enable it later for production)

### 3. Test the Fix

1. Start the dev server:
   ```bash
   npm run dev
   ```

2. Click **Sign Up** on the login page

3. Create an account:
   - Email: Use a real email or test@example.com
   - Password: Must be 8+ chars with a number and special char (e.g., `Test123!`)
   - Company Name: Any name (e.g., "Test Company")

4. You should be logged in automatically

5. Check the browser console for logs starting with `[Signup]` to see the flow

## What Was Wrong

### Possible Issues Fixed:

1. **Missing Trigger**: The database trigger that creates user profiles wasn't set up correctly
2. **Missing Enum Type**: The `user_role` enum type wasn't created
3. **Missing Tables**: Required tables (`app_settings`, `warehouse_counts`, etc.) weren't created
4. **Missing RLS Policies**: Row Level Security policies weren't configured
5. **Email Confirmation**: Supabase requires email confirmation by default

## Troubleshooting

### Error: "Invalid login credentials"
- Make sure you're using the correct email and password
- Check if the user exists in Supabase Dashboard → Authentication → Users

### Error: "User profile not found"
- The trigger didn't create the profile - run the SQL script again
- Check the `public.users` table in Supabase Dashboard

### Error: "Email not confirmed"
- Either disable email confirmation (see step 5 above)
- Or check your email and click the confirmation link

### No error but can't login
- Open browser DevTools (F12) → Console
- Look for logs starting with `[Signup]` or `[Login]`
- Share the error messages if you need help

## Files Changed

- `services/supabase.ts` - Improved auth functions with better error handling
- `FIX_SUPABASE_AUTH_COMPLETE.sql` - Complete database fix script (NEW)
- `SUPABASE_SIGNUP_FIX.md` - This documentation (NEW)

## Next Steps After Fix

1. Test creating estimates
2. Test login with the same credentials
3. Test password reset functionality
4. Re-enable email confirmation for production

## Support

If you still have issues:
1. Check browser console for error messages
2. Check Supabase Dashboard → Logs
3. Verify all verification queries in the SQL script returned positive results
