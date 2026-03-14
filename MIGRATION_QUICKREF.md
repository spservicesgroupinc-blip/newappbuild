# Supabase Migration - Quick Reference Card

## 🔑 Credentials Setup

```bash
# .env.local
VITE_SUPABASE_URL=https://YOUR-PROJECT-ID.supabase.co
VITE_SUPABASE_ANON_KEY=YOUR-ANON-KEY
```

Get from: **Dashboard → Settings → API**

---

## 📦 Install & Setup

```bash
# Install dependencies
npm install

# Run dev server
npm run dev

# Install Supabase CLI (optional)
npm install -g supabase
```

---

## 🗄️ Database Migration

**Run in order:**

1. `supabase/migrations/001_initial_schema.sql` - Tables & RLS
2. `supabase/migrations/002_functions_triggers.sql` - Business logic
3. `supabase/migrations/003_rpc_functions.sql` - API endpoints
4. `supabase/migrations/004_storage_buckets.sql` - Storage config

**Via Dashboard:** SQL Editor → Paste → Run

**Via CLI:** `npx supabase db push`

---

## 📁 Storage Buckets

Create 3 private buckets:

| Bucket | Size Limit | Purpose |
|--------|-----------|---------|
| `estimate-pdfs` | 10MB | PDFs |
| `site-images` | 50MB | Photos/logos |
| `work-orders` | 10MB | Work orders |

**Dashboard → Storage → New Bucket**

---

## 🔄 Key Changes

| Old (GAS) | New (Supabase) |
|-----------|----------------|
| `spreadsheetId` | `username` (as userId) |
| `GOOGLE_SCRIPT_URL` | Supabase client |
| `services/api.ts` | `services/supabase.ts` |
| Google Sheets | PostgreSQL tables |
| Google Drive | Supabase Storage |

---

## 🧪 Test Checklist

```bash
# 1. Run app
npm run dev

# 2. Create account
# - Click Sign Up
# - Username: admin
# - Password: Test123!
# - Company: Test Foam Inc

# 3. Test features
# ✓ Login/logout
# ✓ Create estimate
# ✓ Save customer
# ✓ Update inventory
# ✓ Upload logo
# ✓ Sync works
```

---

## 🐛 Common Issues

### "permission denied for table"
→ User not authenticated or RLS issue
```sql
SELECT auth.uid(); -- Check auth
SELECT * FROM users WHERE auth_user_id = auth.uid(); -- Check user record
```

### "function does not exist"
→ Migration not run
→ Run missing migration file

### "credentials not configured"
→ Check `.env.local` exists with correct values
→ Restart dev server

### Upload fails
→ Check storage bucket exists
→ Verify RLS policies applied

---

## 📊 Debug Queries

```sql
-- Check current user
SELECT auth.uid();

-- Get user's estimates count
SELECT COUNT(*) FROM estimates 
WHERE user_id = (SELECT id FROM users WHERE auth_user_id = auth.uid());

-- View storage usage
SELECT bucket_id, COUNT(*) FROM storage.objects GROUP BY bucket_id;

-- Check P&L records
SELECT * FROM profit_loss_records ORDER BY recorded_at DESC LIMIT 10;
```

---

## 📚 File Changes

### Created
- ✅ `services/supabase.ts` - Supabase client
- ✅ `.env.local` - Environment config
- ✅ `supabase/migrations/*.sql` - Database schema
- ✅ `SUPABASE_MIGRATION.md` - Full guide
- ✅ `MIGRATION_QUICKREF.md` - This file

### Updated
- ✅ `constants.ts` - Removed GAS URL
- ✅ `hooks/useSync.ts` - Uses Supabase
- ✅ `hooks/useEstimates.ts` - Uses Supabase
- ✅ `components/SprayFoamCalculator.tsx` - Updated imports
- ✅ `components/Profile.tsx` - Uses Supabase storage
- ✅ `components/LoginPage.tsx` - Uses Supabase auth
- ✅ `components/CrewDashboard.tsx` - Uses Supabase

### Unchanged (Legacy)
- ⚠️ `services/api.ts` - Kept for reference/rollback

---

## 🎯 Next Steps

1. **Run migrations** in Supabase SQL Editor
2. **Create storage buckets** in Dashboard
3. **Configure `.env.local`** with credentials
4. **Test locally** with `npm run dev`
5. **Migrate data** from Google Sheets (optional)
6. **Deploy to production** when ready

---

## 📞 Support

- **Docs**: `supabase/README.md`, `SUPABASE_MIGRATION.md`
- **Supabase**: [supabase.com/docs](https://supabase.com/docs)
- **Discord**: [discord.supabase.com](https://discord.supabase.com)

---

**Migration Status**: ✅ Complete - Ready for deployment
