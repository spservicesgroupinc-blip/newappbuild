# Supabase Auth Setup - Login Screen

## Overview

The login screen has been rebuilt to work correctly with **Supabase Auth** using email/password authentication.

## Changes Made

### 1. LoginPage Component (`components/LoginPage.tsx`)

**New Features:**
- ✅ Email-based authentication (instead of username)
- ✅ Password visibility toggle
- ✅ Password strength indicator with requirements:
  - Minimum 8 characters
  - Contains at least one number
  - Contains at least one special character (!@#$%^&*)
- ✅ Forgot Password flow with email reset
- ✅ Better error handling and user feedback
- ✅ Success messages for account creation and password reset
- ✅ Improved form validation

**Auth Modes:**
1. **Login** - Email + Password
2. **Sign Up** - Email + Password + Company Name
3. **Forgot Password** - Send reset email

**Crew Login** (unchanged):
- Company Username + 4-digit PIN

### 2. Supabase Service (`services/supabase.ts`)

**Updated Functions:**
- `loginUser(email, password)` - Now uses email as primary identifier
- `signupUser(email, password, companyName, username?)` - Email-first signup

**New Functions:**
- `resetPassword(email)` - Sends password reset email via Supabase Auth
- `updatePassword(newPassword)` - Updates password for current user

**Removed:**
- Old `updatePassword(userId, newPassword)` RPC-based function

## How It Works

### Authentication Flow

```
┌─────────────────┐
│  User enters    │
│  email/password │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Supabase Auth   │
│ signInWithPass  │
└────────┬────────┘
         │
    ┌────┴────┐
    │ Success │
    └────┬────┘
         │
         ▼
┌─────────────────┐
│ Get user record │
│ from public.users│
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Return session  │
│ to app          │
└─────────────────┘
```

### Password Reset Flow

```
1. User clicks "Forgot Password"
2. Enters email address
3. System calls `resetPassword(email)`
4. Supabase sends reset email
5. User clicks link in email
6. App handles redirect with access_token
7. User enters new password
8. System calls `updatePassword(newPassword)`
```

## Environment Variables

Ensure these are set in `.env.local`:

```env
VITE_SUPABASE_URL=https://yjxxisvpcorbgreqkofc.supabase.co
VITE_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

## Supabase Configuration

### Required Setup

1. **Enable Email Auth** in Supabase Dashboard:
   - Go to Authentication → Providers
   - Enable "Email" provider
   - Configure email templates (optional)

2. **Set up Triggers** for automatic user creation:
   ```sql
   -- Trigger to create user record on auth.users insert
   CREATE OR REPLACE FUNCTION public.handle_new_user()
   RETURNS trigger AS $$
   BEGIN
     INSERT INTO public.users (
       auth_user_id,
       username,
       company_name,
       email,
       role
     ) VALUES (
       NEW.id,
       NEW.raw_user_meta_data->>'username',
       NEW.raw_user_meta_data->>'company_name',
       NEW.email,
       COALESCE(NEW.raw_user_meta_data->>'role', 'admin')
     );
     RETURN NEW;
   END;
   $$ LANGUAGE plpgsql SECURITY DEFINER;

   CREATE TRIGGER on_auth_user_created
     AFTER INSERT ON auth.users
     FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
   ```

3. **Configure Site URL** for password reset:
   - Go to Authentication → URL Configuration
   - Set "Site URL" to your app URL
   - Add redirect URLs for password recovery

## Testing

### Test User Signup
1. Open the app
2. Click "Don't have an account? Sign up"
3. Enter:
   - Email: `test@example.com`
   - Password: `Test123!` (meets requirements)
   - Company Name: `Test Company`
4. Click "Create Account"
5. Check email for verification link (if email confirmation enabled)

### Test Login
1. Enter registered email and password
2. Click "Login"
3. Should redirect to main app

### Test Password Reset
1. Click "Forgot your password?"
2. Enter registered email
3. Click "Send Reset Email"
4. Check email for reset link
5. Click link and set new password

## Migration from Legacy Auth

If you have existing users with username/password in the database:

1. **Option A: Manual Migration**
   - Export user list
   - Create users in Supabase Auth via Admin API
   - Preserve password hashes (if using compatible hashing)

2. **Option B: Hybrid Approach** (implemented)
   - Login function falls back to RPC for legacy users
   - New users use Supabase Auth
   - Gradually migrate users as they log in

## Security Considerations

- ✅ Passwords are hashed by Supabase Auth (bcrypt)
- ✅ RLS policies protect user data
- ✅ Session tokens are automatically managed
- ✅ Password reset requires email ownership
- ✅ Rate limiting on auth endpoints (Supabase default)

## Troubleshooting

### "Invalid credentials" error
- Check email spelling
- Verify password meets requirements
- Ensure user is verified (if email confirmation enabled)

### Password reset email not received
- Check spam folder
- Verify email address is correct
- Check Supabase email quota/logs

### Build errors
- Run `npm run build` to verify compilation
- Check TypeScript errors with `npx tsc --noEmit`

## Next Steps

1. Apply database migrations (if not done)
2. Configure email templates in Supabase
3. Test auth flows end-to-end
4. Set up monitoring for auth events
5. Consider adding OAuth providers (Google, Microsoft)
