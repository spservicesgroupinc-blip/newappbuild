# Supabase Migration Guide - RFE Foam Pro

This document provides step-by-step instructions to migrate from Google Apps Script backend to Supabase.

---

## Migration Overview

### What Changed

| Component | Before (Google Apps Script) | After (Supabase) |
|-----------|----------------------------|------------------|
| **Database** | Google Sheets | PostgreSQL via Supabase |
| **Authentication** | Custom Users_DB table | Supabase Auth + public.users |
| **Storage** | Google Drive | Supabase Storage (S3-based) |
| **API** | `doPost()` endpoints | RPC functions + REST API |
| **Real-time** | Polling | WebSocket subscriptions (optional) |
| **Identity** | `spreadsheetId` | `username` (as user ID) |

---

## Prerequisites

1. **Node.js** v18+ installed
2. **Supabase account** at [supabase.com](https://supabase.com)
3. **Git** for version control

---

## Step 1: Create Supabase Project

1. Go to [supabase.com/dashboard](https://supabase.com/dashboard)
2. Click **"New Project"**
3. Fill in:
   - **Organization**: Your company name
   - **Project Name**: `rfe-foam-pro` (or your choice)
   - **Database Password**: **Save this securely!**
   - **Region**: Choose closest to your users (e.g., `US East`)
4. Wait ~2 minutes for provisioning

---

## Step 2: Get Credentials

1. In Supabase Dashboard, go to **Settings** (bottom left icon) → **API**
2. Copy these values:
   - **Project URL**: `https://xxxxx.supabase.co`
   - **anon/public key**: `eyJhbG...` (safe for client-side use)
   - **service_role key**: `eyJhbG...` (**NEVER expose this**)

---

## Step 3: Configure Environment

1. Open `.env.local` in your project root
2. Replace placeholder values:

```bash
VITE_SUPABASE_URL=https://your-project-id.supabase.co
VITE_SUPABASE_ANON_KEY=your-anon-key-here
```

---

## Step 4: Install Dependencies

```bash
npm install
```

This installs `@supabase/supabase-js` which is already in `package.json`.

---

## Step 5: Run Database Migrations

### Option A: Via Supabase Dashboard (Easiest)

1. Go to **SQL Editor** in Supabase Dashboard
2. Open `supabase/migrations/001_initial_schema.sql`
3. Copy entire contents
4. Paste into SQL Editor
5. Click **Run**
6. Repeat for files 002, 003, and 004 in order

### Option B: Via Supabase CLI (Recommended for production)

```bash
# Install Supabase CLI globally
npm install -g supabase

# Login to Supabase
npx supabase login

# Link to your project (get project-ref from Dashboard URL)
npx supabase link --project-ref your-project-ref

# Push all migrations
npx supabase db push
```

### Option C: Via psql

```bash
# Get connection string from Dashboard → Settings → Database
psql "postgresql://postgres:YOUR_PASSWORD@db.xxxx.supabase.co:5432/postgres" \
  -f supabase/migrations/001_initial_schema.sql

# Repeat for 002, 003, 004
```

---

## Step 6: Verify Database Setup

Run this query in **SQL Editor** to verify all tables were created:

```sql
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
ORDER BY table_name;
```

**Expected output** (14 tables):
```
app_settings
company_profiles
crew_time_logs
customers
equipment_items
estimates
inventory_items
lifetime_usage
material_logs
profit_loss_records
purchase_orders
trial_memberships
users
warehouse_counts
```

---

## Step 7: Create Storage Buckets

1. Go to **Storage** in Supabase Dashboard
2. Click **"New Bucket"**
3. Create these 3 buckets:

| Bucket Name | Public | File Size Limit | Purpose |
|-------------|--------|-----------------|---------|
| `estimate-pdfs` | ❌ Private | 10MB | PDF estimates, invoices |
| `site-images` | ❌ Private | 50MB | Photos, logos |
| `work-orders` | ❌ Private | 10MB | Work order sheets |

4. For each bucket:
   - Uncheck "Public bucket"
   - Set "File size limit" (in bytes): 10485760 (10MB) or 52428800 (50MB)
   - Click **Save**

---

## Step 8: Apply Storage Policies

The RLS policies were applied in migration 004. Verify with:

```sql
SELECT bucket_id, policy_name 
FROM storage.policies 
WHERE bucket_id IN ('estimate-pdfs', 'site-images', 'work-orders');
```

---

## Step 9: Test Authentication

### Create First User via SQL

Run this in **SQL Editor** to create a test admin user:

```sql
-- Create auth user (this will trigger the handle_new_user function)
-- Note: In production, users signup via the app UI
```

### Or Test via App UI

1. Run the app: `npm run dev`
2. Click "Sign Up" on login page
3. Create account with:
   - Username: `admin`
   - Password: `Test123!`
   - Company Name: `Test Foam Inc`
4. Check your email for confirmation (if enabled)
5. Login with credentials

---

## Step 10: Verify Frontend Integration

The following files have been updated to use Supabase:

### Updated Services
- ✅ `services/supabase.ts` - New Supabase client (created)
- ✅ `services/api.ts` - Legacy GAS client (kept for reference)

### Updated Hooks
- ✅ `hooks/useSync.ts` - Uses `syncDown/syncUp` from Supabase
- ✅ `hooks/useEstimates.ts` - Uses Supabase for job operations

### Updated Components
- ✅ `components/SprayFoamCalculator.tsx` - Updated imports
- ✅ `components/Profile.tsx` - Uses Supabase storage for uploads

### Updated Config
- ✅ `constants.ts` - Removed GAS URL, added Supabase check
- ✅ `.env.local` - Supabase credentials

---

## Step 11: Data Migration (Optional)

If you have existing data in Google Sheets, you have 3 options:

### Option 1: Manual Export/Import

1. Export each Google Sheet as CSV
2. In Supabase Dashboard → Table Editor
3. Click **"Import"** for each table
4. Map CSV columns to database fields

### Option 2: Custom Migration Script

Create `scripts/migrate-from-gas.ts`:

```typescript
import { createClient } from '@supabase/supabase-js';
import { google } from 'googleapis';

// 1. Authenticate with Google
// 2. Fetch data from Sheets
// 3. Transform to Supabase format
// 4. Insert into Supabase tables
```

### Option 3: Hybrid Migration

1. Keep Google Sheets read-only during transition
2. New data goes to Supabase
3. Migrate historical data gradually
4. Update `useSync.ts` to fetch from both sources

---

## Testing Checklist

### Authentication
- [ ] User can signup with username, password, company name
- [ ] Login with credentials works
- [ ] Crew login with PIN works
- [ ] Session persists on page refresh
- [ ] Logout clears session

### Database Operations
- [ ] Create/edit/delete customer
- [ ] Create/edit/delete estimate
- [ ] Inventory items sync correctly
- [ ] Equipment items sync correctly
- [ ] Warehouse counts update

### Job Management
- [ ] Create new estimate
- [ ] Start job (status → In Progress)
- [ ] Complete job with actuals
- [ ] Inventory reconciles on completion
- [ ] Mark job as paid
- [ ] P&L record created automatically

### Sync Operations
- [ ] Sync down retrieves all data
- [ ] Sync up saves changes
- [ ] Auto-sync works (3-second debounce)
- [ ] Manual sync works
- [ ] Offline mode uses local backup

### Storage
- [ ] Upload company logo
- [ ] Upload site photos
- [ ] Generate and save PDF estimate
- [ ] View uploaded files

---

## Troubleshooting

### Error: "Supabase credentials not configured"

**Solution**: Ensure `.env.local` exists with correct values:
```bash
VITE_SUPABASE_URL=https://your-project-id.supabase.co
VITE_SUPABASE_ANON_KEY=your-anon-key
```

Restart dev server after changes.

### Error: "permission denied for table"

**Cause**: RLS policy blocking access

**Solution**: Verify user is authenticated:
```sql
-- Check current user
SELECT auth.uid();

-- Check if user record exists
SELECT * FROM public.users WHERE auth_user_id = auth.uid();
```

### Error: "function rpc_login does not exist"

**Cause**: Migration 003 not run

**Solution**: Run `003_rpc_functions.sql` in SQL Editor

### Error: "relation 'estimates' does not exist"

**Cause**: Migration 001 not run

**Solution**: Run `001_initial_schema.sql` in SQL Editor

### Upload fails with "permission denied for bucket"

**Cause**: Storage policies not applied

**Solution**: Run `004_storage_buckets.sql` or recreate buckets with correct settings

### User created in auth.users but not in public.users

**Cause**: Trigger not firing

**Solution**: Verify trigger exists:
```sql
SELECT * FROM pg_trigger WHERE tgname = 'on_auth_user_created';
```

If missing, run migration 002.

---

## Debug Queries

```sql
-- Check current authenticated user
SELECT auth.uid();

-- Get user's data
SELECT * FROM public.users WHERE auth_user_id = auth.uid();

-- Count estimates per user
SELECT u.username, COUNT(e.id) as estimate_count
FROM public.users u
LEFT JOIN public.estimates e ON u.id = e.user_id
GROUP BY u.username;

-- Check storage usage
SELECT 
  bucket_id,
  COUNT(*) as file_count,
  SUM(metadata->>'size')::bigint as total_bytes
FROM storage.objects
GROUP BY bucket_id;

-- View recent P&L records
SELECT * FROM profit_loss_records
ORDER BY recorded_at DESC
LIMIT 10;

-- Check for orphaned records
SELECT * FROM estimates e
LEFT JOIN users u ON e.user_id = u.id
WHERE u.id IS NULL;
```

---

## Next Steps

### 1. Edge Functions (Optional)

Deploy Edge Functions for server-side operations:

```bash
# Deploy PDF generation function
supabase functions deploy generate-pdf

# Deploy work order creation function
supabase functions deploy create-work-order
```

### 2. Real-time Subscriptions (Optional)

Add real-time updates for collaborative features:

```typescript
// In useSync.ts
const channel = supabase
  .channel('estimates')
  .on('postgres_changes', 
    { event: '*', schema: 'public', table: 'estimates' },
    (payload) => {
      // Handle real-time update
    }
  )
  .subscribe();
```

### 3. Backup Strategy

Configure automated backups:
- Go to **Settings** → **Database**
- Enable **Point-in-time recovery**
- Set backup retention period

### 4. Monitoring

Set up monitoring:
- **Dashboard** → **Activity** for query logs
- **Settings** → **Logs** for function execution
- Integrate with Sentry for error tracking

---

## Security Best Practices

1. **Never expose service_role key** - Only use `anon` key in frontend
2. **RLS is enabled** on all tables - Users isolated by default
3. **Storage buckets are private** - Access via RLS policies only
4. **Password hashing** - Supabase Auth handles this automatically
5. **CORS configured** - Only your domain can access the API

---

## Support Resources

- **Supabase Docs**: [supabase.com/docs](https://supabase.com/docs)
- **Supabase Discord**: [discord.supabase.com](https://discord.supabase.com)
- **PostgreSQL Docs**: [postgresql.org/docs](https://postgresql.org/docs)
- **This Project**: Check `supabase/README.md` for detailed docs

---

## Rollback Plan

If you need to rollback to Google Apps Script:

1. Keep `services/api.ts` (legacy GAS client)
2. Revert imports in hooks/components
3. Restore `constants.ts` with GAS URL
4. Update `.env.local` with `GEMINI_API_KEY` if needed

All changes are non-destructive - Google Sheets data remains intact.

---

## Migration Complete ✅

Your app is now running on Supabase! 

**Key Benefits:**
- ⚡ Faster queries (PostgreSQL vs Sheets)
- 🔒 Better security (RLS, Auth, encrypted storage)
- 📈 Scalable (handles more users/data)
- 💰 Cost-effective (free tier: 500MB DB, 1GB storage)
- 🛠️ Developer-friendly (SQL, real-time, Edge Functions)

**Run the app:**
```bash
npm run dev
```
