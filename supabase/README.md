# Supabase Migration Guide
## Spray Foam Insulation Business Management Tool

This document provides complete instructions for migrating from Google Apps Script backend to Supabase.

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [Prerequisites](#prerequisites)
3. [Supabase Project Setup](#supabase-project-setup)
4. [Database Schema Migration](#database-schema-migration)
5. [Storage Configuration](#storage-configuration)
6. [Authentication Setup](#authentication-setup)
7. [Frontend Integration](#frontend-integration)
8. [Data Migration from Google Sheets](#data-migration-from-google-sheets)
9. [Testing Checklist](#testing-checklist)
10. [Troubleshooting](#troubleshooting)

---

## Project Overview

### What Was Configured

| Component | Description |
|-----------|-------------|
| **Database** | 14 tables with proper relationships, indexes, and RLS policies |
| **Authentication** | Supabase Auth with email/password + crew PIN login |
| **Storage** | 3 buckets for PDFs, images, and work orders |
| **Functions** | 16 RPC functions replicating all API endpoints |
| **Triggers** | Automatic timestamps, auth integration, P&L calculations |

### Architecture Comparison

| Feature | Google Apps Script | Supabase |
|---------|-------------------|----------|
| Database | Google Sheets | PostgreSQL |
| Auth | Custom (Users_DB) | Supabase Auth + custom fields |
| Storage | Google Drive | Supabase Storage (S3) |
| API | doPost endpoints | RPC functions + REST |
| Real-time | Polling | WebSocket subscriptions |

---

## Prerequisites

1. **Supabase Account**: Sign up at [supabase.com](https://supabase.com)
2. **Node.js**: v18+ installed
3. **Supabase CLI**: Install with `npm install -g supabase`
4. **Git**: For version control

---

## Supabase Project Setup

### Step 1: Create New Project

1. Go to [supabase.com/dashboard](https://supabase.com/dashboard)
2. Click "New Project"
3. Fill in:
   - **Organization**: Your company
   - **Project Name**: `rfe-foam-pro` (or your choice)
   - **Database Password**: Save this securely
   - **Region**: Choose closest to your users
4. Wait for project provisioning (~2 minutes)

### Step 2: Get Credentials

1. Go to **Settings** → **API**
2. Copy these values:
   - **Project URL**: `https://xxxxx.supabase.co`
   - **anon/public key**: `eyJhbG...` (safe for client-side)
   - **service_role key**: `eyJhbG...` (server-side only, never expose)

### Step 3: Configure Environment

```bash
# Copy the example env file
cp .env.local.example .env.local

# Edit .env.local with your credentials
VITE_SUPABASE_URL=https://your-project-id.supabase.co
VITE_SUPABASE_ANON_KEY=your-anon-key-here
```

---

## Database Schema Migration

### Step 1: Run Migration Scripts

Option A: Via Supabase Dashboard SQL Editor

1. Go to **SQL Editor** in Supabase Dashboard
2. Copy contents of each migration file
3. Run in order:
   - `001_initial_schema.sql`
   - `002_functions_triggers.sql`
   - `003_rpc_functions.sql`
   - `004_storage_buckets.sql`

Option B: Via Supabase CLI (Recommended)

```bash
# Login to Supabase
npx supabase login

# Link to your project
npx supabase link --project-ref your-project-ref

# Push migrations
npx supabase db push
```

Option C: Via psql

```bash
# Get connection string from Dashboard → Settings → Database
psql "postgresql://postgres:password@db.xxxx.supabase.co:5432/postgres" -f supabase/migrations/001_initial_schema.sql
psql "postgresql://postgres:password@db.xxxx.supabase.co:5432/postgres" -f supabase/migrations/002_functions_triggers.sql
psql "postgresql://postgres:password@db.xxxx.supabase.co:5432/postgres" -f supabase/migrations/003_rpc_functions.sql
psql "postgresql://postgres:password@db.xxxx.supabase.co:5432/postgres" -f supabase/migrations/004_storage_buckets.sql
```

### Step 2: Verify Tables

Run this query in SQL Editor to verify all tables were created:

```sql
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
ORDER BY table_name;
```

Expected output:
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

## Storage Configuration

### Step 1: Create Storage Buckets

Go to **Storage** in Supabase Dashboard and create these buckets:

| Bucket Name | Public | File Size Limit | Allowed MIME Types |
|-------------|--------|-----------------|-------------------|
| `estimate-pdfs` | No | 10MB | `application/pdf` |
| `site-images` | No | 50MB | `image/jpeg, image/png, image/webp` |
| `work-orders` | No | 10MB | `application/pdf, application/vnd.openxmlformats-officedocument.spreadsheetml.sheet` |

### Step 2: Apply RLS Policies

Run the policies from `004_storage_buckets.sql` in SQL Editor, or they will be applied automatically if you ran all migrations.

### Step 3: Verify Storage

```sql
SELECT name, public, file_size_limit 
FROM storage.buckets;
```

---

## Authentication Setup

### Step 1: Configure Auth Settings

1. Go to **Authentication** → **Settings**
2. Configure:
   - **Enable Email Signup**: Yes
   - **Enable Email Confirmations**: No (for internal app)
   - **Site URL**: Your app URL (e.g., `https://yourapp.com`)
   - **Redirect URLs**: Add your app URLs

### Step 2: Custom User Metadata

The schema supports these custom fields in `raw_user_meta_data`:
- `username`: User's login name
- `company_name`: Company name
- `role`: 'admin' or 'crew'
- `crew_code`: 4-digit PIN for crew login

### Step 3: Password Policy

1. Go to **Authentication** → **Policies**
2. Set minimum password length: 8 characters
3. Enable breach detection (optional)

---

## Frontend Integration

### Step 1: Install Dependencies

```bash
npm install @supabase/supabase-js
```

### Step 2: Update API Service

Replace `services/api.ts` imports with the new Supabase service:

```typescript
// Old import
import { syncDown, syncUp, loginUser } from './api';

// New import
import { syncDown, syncUp, loginUser } from './supabase';
```

### Step 3: Update Constants

Update `constants.ts`:

```typescript
// Remove or comment out Google Script URL
// export const GOOGLE_SCRIPT_URL = '...';

// Supabase is configured via environment variables
export const SUPABASE_CONFIGURED = 
  import.meta.env.VITE_SUPABASE_URL && 
  import.meta.env.VITE_SUPABASE_ANON_KEY;
```

### Step 4: Update Auth Components

Update login/signup components to use new service:

```typescript
import { loginUser, signupUser, loginCrew } from './services/supabase';

// Login
const session = await loginUser(username, password);

// Crew Login  
const crewSession = await loginCrew(username, pin);

// Signup
const newSession = await signupUser(username, password, companyName);
```

---

## Data Migration from Google Sheets

### Option 1: Manual Export/Import

1. Export Google Sheets data as CSV
2. Use Supabase Dashboard → Table Editor → Import
3. Map columns to database fields

### Option 2: Migration Script

Create a Node.js migration script:

```typescript
// migrate-from-gas.ts
import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  process.env.VITE_SUPABASE_URL!,
  process.env.VITE_SUPABASE_ANON_KEY!
);

// Fetch data from Google Sheets API
// Transform to Supabase format
// Insert into Supabase tables
```

### Option 3: Hybrid Migration

Keep Google Sheets read-only during transition:
1. Run both backends in parallel
2. New data goes to Supabase
3. Historical data migrated gradually

---

## Testing Checklist

### Authentication Tests

- [ ] User can signup with username, password, company name
- [ ] User receives confirmation email (if enabled)
- [ ] User can login with credentials
- [ ] Crew member can login with PIN
- [ ] Invalid credentials show appropriate error
- [ ] Session persists across page refresh
- [ ] Logout clears session

### Database Tests

- [ ] User can only see their own data (RLS verification)
- [ ] Customers CRUD operations work
- [ ] Estimates CRUD operations work
- [ ] Inventory items sync correctly
- [ ] Equipment items sync correctly
- [ ] Warehouse counts update on job completion
- [ ] Lifetime usage tracks correctly

### Job Management Tests

- [ ] Can create new estimate
- [ ] Can start a job (status → In Progress)
- [ ] Can complete a job with actuals
- [ ] Inventory reconciles on job completion
- [ ] Can mark job as paid
- [ ] P&L record created when job marked paid
- [ ] Can delete estimate

### Sync Tests

- [ ] Sync down retrieves all data
- [ ] Delta sync only fetches changed data
- [ ] Sync up saves all changes
- [ ] Concurrent edits handled correctly
- [ ] Offline changes sync when back online

### Storage Tests

- [ ] Can upload PDF estimate
- [ ] Can upload site photos
- [ ] Can view uploaded files
- [ ] Can delete uploaded files
- [ ] Files organized by user folder

### Real-time Tests

- [ ] Estimate changes propagate to other tabs
- [ ] Inventory updates visible in real-time
- [ ] Multiple users don't overwrite each other

### Performance Tests

- [ ] Initial sync completes in < 5 seconds
- [ ] Delta sync completes in < 2 seconds
- [ ] Job completion processes in < 3 seconds
- [ ] No N+1 query issues

---

## Troubleshooting

### Common Issues

#### 1. RLS Policy Errors

**Symptom**: "permission denied for table"

**Solution**: Check that user is authenticated and RLS policies are correctly configured:

```sql
-- Check current user
SELECT auth.uid();

-- Check if policies exist
SELECT * FROM pg_policies WHERE tablename = 'estimates';
```

#### 2. Storage Upload Fails

**Symptom**: "permission denied for bucket"

**Solution**: Verify bucket policies:

```sql
SELECT * FROM storage.policies WHERE bucket_id = 'estimate-pdfs';
```

#### 3. Trigger Not Firing

**Symptom**: User created in auth.users but not in public.users

**Solution**: Check trigger exists:

```sql
SELECT * FROM pg_trigger WHERE tgname = 'on_auth_user_created';
```

#### 4. RPC Function Not Found

**Symptom**: "function rpc_login does not exist"

**Solution**: Verify functions were created:

```sql
SELECT routine_name 
FROM information_schema.routines 
WHERE routine_schema = 'public' 
  AND routine_name LIKE 'rpc_%';
```

#### 5. Foreign Key Violation

**Symptom**: "insert violates foreign key constraint"

**Solution**: Ensure parent record exists before inserting child:

```typescript
// Create customer first, then estimate with customer_id
```

### Debug Queries

```sql
-- Check user's data
SELECT * FROM public.users WHERE auth_user_id = auth.uid();

-- Check estimates count
SELECT COUNT(*) FROM estimates WHERE user_id = (
  SELECT id FROM users WHERE auth_user_id = auth.uid()
);

-- Check storage usage
SELECT * FROM public.storage_usage;

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

1. **Edge Functions**: Create Edge Functions for:
   - PDF generation
   - Google Sheets integration (for work orders)
   - Email notifications

2. **Backup Strategy**: Configure:
   - Daily automated backups
   - Point-in-time recovery
   - Export to S3

3. **Monitoring**: Set up:
   - Database query monitoring
   - Function execution logs
   - Error tracking (Sentry)

4. **Security Audit**:
   - Review all RLS policies
   - Audit storage access
   - Rotate API keys

5. **Performance Optimization**:
   - Add query indexes based on usage patterns
   - Implement connection pooling
   - Cache frequently accessed data

---

## Support

- **Supabase Docs**: [supabase.com/docs](https://supabase.com/docs)
- **Supabase Discord**: [discord.supabase.com](https://discord.supabase.com)
- **PostgreSQL Docs**: [postgresql.org/docs](https://postgresql.org/docs)

---

## Appendix: File Structure

```
supabase/
├── migrations/
│   ├── 001_initial_schema.sql      # Tables, indexes, RLS
│   ├── 002_functions_triggers.sql  # Business logic functions
│   ├── 003_rpc_functions.sql       # API endpoint replicas
│   └── 004_storage_buckets.sql     # Storage configuration
└── README.md

services/
├── api.ts                          # Legacy Google Apps Script API
└── supabase.ts                     # New Supabase API client

.env.example                        # Environment template
.env.local.example                  # Local dev template
```
