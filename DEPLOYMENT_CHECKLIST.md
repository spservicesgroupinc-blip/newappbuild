# ✅ Supabase Migration - Deployment Checklist

## Migration Status: COMPLETE ✅

All code has been successfully migrated from Google Apps Script to Supabase.
The application builds successfully with no TypeScript errors.

---

## 📋 Pre-Deployment Checklist

### 1. Supabase Project Setup ⏳

- [ ] Create Supabase project at [supabase.com](https://supabase.com)
- [ ] Save database password securely
- [ ] Note your project URL: `https://_____.supabase.co`
- [ ] Note your anon/public key
- [ ] Note your service_role key (keep secret!)

### 2. Environment Configuration ⏳

- [ ] Copy `.env.local.example` to `.env.local`
- [ ] Set `VITE_SUPABASE_URL`
- [ ] Set `VITE_SUPABASE_ANON_KEY`
- [ ] Verify feature flags are set correctly

### 3. Database Migration ⏳

**Run these SQL files in order (Supabase Dashboard → SQL Editor):**

- [ ] Run `supabase/migrations/001_initial_schema.sql`
- [ ] Run `supabase/migrations/002_functions_triggers.sql`
- [ ] Run `supabase/migrations/003_rpc_functions.sql`
- [ ] Run `supabase/migrations/004_storage_buckets.sql`

**Verify tables created:**

```sql
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public' ORDER BY table_name;
```

Expected: 14 tables

### 4. Storage Buckets ⏳

**Create in Supabase Dashboard → Storage:**

- [ ] Create bucket: `estimate-pdfs` (Private, 10MB limit)
- [ ] Create bucket: `site-images` (Private, 50MB limit)
- [ ] Create bucket: `work-orders` (Private, 10MB limit)

**Or run migration 004 which creates them automatically.**

### 5. Authentication Setup ⏳

- [ ] Go to Dashboard → Authentication → Settings
- [ ] Enable Email Signup: Yes
- [ ] Email Confirmations: No (for internal app)
- [ ] Set Site URL: Your production URL
- [ ] Set Redirect URLs: Your app URLs

### 6. Local Testing ⏳

```bash
# Install dependencies (if not done)
npm install

# Run development server
npm run dev
```

**Test at:** http://localhost:3000

**Test Scenarios:**

- [ ] Signup with username, password, company name
- [ ] Login with credentials
- [ ] Crew login with PIN
- [ ] Create new estimate
- [ ] Save customer
- [ ] Add inventory items
- [ ] Upload company logo
- [ ] Sync works (check sync status indicator)
- [ ] Mark job as Work Order
- [ ] Complete job
- [ ] Mark job as paid
- [ ] View P&L

### 7. Data Migration (Optional) ⏳

**If migrating from Google Sheets:**

- [ ] Export Google Sheets as CSV
- [ ] Import customers via Dashboard → Table Editor
- [ ] Import estimates
- [ ] Import inventory
- [ ] Verify data integrity
- [ ] Test with migrated data

---

## 🚀 Production Deployment

### Option A: Vercel (Recommended)

```bash
# Install Vercel CLI
npm install -g vercel

# Login
vercel login

# Deploy
vercel --prod
```

**Environment Variables in Vercel Dashboard:**
- `VITE_SUPABASE_URL`
- `VITE_SUPABASE_ANON_KEY`

### Option B: Netlify

```bash
# Install Netlify CLI
npm install -g netlify-cli

# Login
netlify login

# Deploy
netlify deploy --prod
```

**Environment Variables in Netlify Dashboard:**
- `VITE_SUPABASE_URL`
- `VITE_SUPABASE_ANON_KEY`

### Option C: Your Own Server

```bash
# Build production bundle
npm run build

# Upload /dist folder to your web server
# Configure server to serve index.html for all routes
```

**Environment Variables:**
- Set during build: `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY`

---

## 🔧 Post-Deployment

### 1. Verify Production Build

- [ ] App loads without errors
- [ ] Login works
- [ ] Sync works
- [ ] File uploads work
- [ ] No console errors

### 2. Configure Custom Domain (Optional)

- [ ] Add domain in Vercel/Netlify
- [ ] Update DNS records
- [ ] Add domain to Supabase allowed URLs
- [ ] Update Site URL in Supabase Auth settings

### 3. Set Up Monitoring

- [ ] Enable Supabase query monitoring
- [ ] Set up error tracking (Sentry)
- [ ] Configure log retention
- [ ] Set up alerts for errors

### 4. Backup Configuration

- [ ] Enable daily backups in Supabase
- [ ] Set backup retention period (30 days recommended)
- [ ] Test point-in-time recovery

---

## 🔒 Security Checklist

- [ ] RLS enabled on all tables (verified in migration)
- [ ] Storage buckets are private
- [ ] Service role key NOT exposed in frontend
- [ ] CORS configured for your domain
- [ ] Password requirements enforced (min 8 characters)
- [ ] Session expiry configured (7 days default)

---

## 📊 Performance Optimization

### Database Indexes (Already Created)

The migration creates these indexes automatically:

- `idx_users_username` - Fast login
- `idx_estimates_user_id` - Fast estimate queries
- `idx_customers_user_id` - Fast customer lookups
- `idx_inventory_user_id` - Fast inventory queries
- And more...

### Frontend Optimization

- [ ] Enable code splitting (already configured in Vite)
- [ ] Lazy load heavy components
- [ ] Optimize images
- [ ] Enable CDN caching

---

## 🧪 User Acceptance Testing

### Admin User Tests

- [ ] Can signup and login
- [ ] Can create estimates
- [ ] Can manage customers
- [ ] Can update inventory
- [ ] Can view dashboard
- [ ] Can generate PDFs
- [ ] Can upload files
- [ ] Can mark jobs as paid
- [ ] Can view P&L

### Crew User Tests

- [ ] Can login with PIN
- [ ] Can view assigned jobs
- [ ] Can start jobs
- [ ] Can complete jobs
- [ ] Can log time
- [ ] Can upload site photos
- [ ] Can view work orders

---

## 📱 PWA Testing

- [ ] Install prompt appears
- [ ] App installs on desktop
- [ ] App installs on mobile
- [ ] Works offline (cached data)
- [ ] Syncs when back online
- [ ] Icon displays correctly

---

## 🐛 Known Issues & Workarounds

### 1. Work Order Sheet Creation

**Status:** Returns placeholder URL
**Workaround:** Generate PDF work orders instead
**Future:** Implement Edge Function for Google Sheets creation

### 2. Legacy Password Hashing

**Status:** Handled by RPC functions
**Note:** New users use Supabase Auth (bcrypt)

### 3. Large File Uploads

**Limit:** 50MB for images, 10MB for PDFs
**Workaround:** Compress images before upload

---

## 📞 Support & Resources

### Documentation

- `SUPABASE_MIGRATION.md` - Complete guide
- `MIGRATION_QUICKREF.md` - Quick reference
- `MIGRATION_SUMMARY.md` - Summary
- `supabase/README.md` - Technical docs

### External Resources

- [Supabase Docs](https://supabase.com/docs)
- [Supabase Discord](https://discord.supabase.com)
- [Vite Docs](https://vitejs.dev)
- [React Docs](https://react.dev)

### Debug Commands

```bash
# Check build
npm run build

# Check TypeScript
npx tsc --noEmit

# Run dev server
npm run dev

# View Supabase logs
supabase logs

# Check database
supabase db diff
```

---

## ✅ Final Verification

Before going live, verify:

- [ ] All tests pass
- [ ] No console errors in production
- [ ] Sync works reliably
- [ ] File uploads work
- [ ] Authentication secure
- [ ] RLS prevents unauthorized access
- [ ] Backups configured
- [ ] Monitoring active
- [ ] Domain configured (if using custom)
- [ ] SSL certificate active

---

## 🎉 Go Live!

When all checkboxes are complete:

1. Update DNS to point to production
2. Announce to users
3. Monitor for issues
4. Gather feedback
5. Iterate and improve

---

## 📈 Post-Launch Monitoring

### First Week

- [ ] Monitor error logs daily
- [ ] Check sync success rate
- [ ] Review user feedback
- [ ] Track performance metrics

### First Month

- [ ] Analyze usage patterns
- [ ] Optimize slow queries
- [ ] Review storage usage
- [ ] Check backup integrity

### Ongoing

- [ ] Weekly error log review
- [ ] Monthly performance audit
- [ ] Quarterly security review
- [ ] Regular dependency updates

---

**Migration Date:** March 14, 2026
**Build Status:** ✅ SUCCESS
**TypeScript Errors:** 0
**Ready for Deployment:** YES

**Next Action:** Follow this checklist to deploy to production.
