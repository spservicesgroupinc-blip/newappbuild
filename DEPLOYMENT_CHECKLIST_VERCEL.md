# Vercel Deployment Checklist

Use this checklist to ensure a smooth deployment to Vercel.

## Pre-Deployment

### 1. Environment Setup
- [ ] Create `.env.local` file with Supabase credentials
- [ ] Verify `VITE_SUPABASE_URL` is correct
- [ ] Verify `VITE_SUPABASE_ANON_KEY` is correct
- [ ] Test locally with `npm run dev`

### 2. Code Quality
- [ ] Run `npm run build` locally (no errors)
- [ ] Test all major features locally
- [ ] Check browser console for errors
- [ ] Verify PWA functionality works

### 3. Git Repository
- [ ] Initialize Git repository (if not done)
- [ ] Create `.gitignore` (already configured)
- [ ] Commit all changes
- [ ] Push to GitHub/GitLab/Bitbucket

## Vercel Setup

### 4. Vercel Account
- [ ] Sign up/login at [vercel.com](https://vercel.com)
- [ ] Install Vercel CLI: `npm install -g vercel`
- [ ] Login via CLI: `vercel login`

### 5. Project Configuration
- [ ] Link project: `vercel link`
- [ ] Configure environment variables in Vercel dashboard
- [ ] Verify `vercel.json` is in root directory
- [ ] Confirm build settings:
  - Build Command: `npm run build`
  - Output Directory: `dist`
  - Install Command: `npm install`

### 6. Deploy
- [ ] Run initial deployment: `vercel --prod`
- [ ] Note your Vercel URL (e.g., `your-app.vercel.app`)
- [ ] Verify deployment succeeded

## Post-Deployment Configuration

### 7. Supabase Configuration
- [ ] Go to Supabase Dashboard → Authentication → URL Configuration
- [ ] Add Vercel URL to **Site URL**
- [ ] Add Vercel URL pattern to **Redirect URLs** (e.g., `https://*.vercel.app/*`)
- [ ] Save changes

### 8. Storage CORS (if using file uploads)
- [ ] Go to Supabase Dashboard → Storage
- [ ] Update CORS settings to include Vercel domain
- [ ] Test file uploads

### 9. Authentication Testing
- [ ] Test user signup
- [ ] Verify email confirmation (if enabled)
- [ ] Test login flow
- [ ] Test password reset
- [ ] Test crew login (if enabled)

## Feature Testing

### 10. Core Features
- [ ] Create new estimate
- [ ] Save estimate as Work Order
- [ ] Generate PDF documents
- [ ] Complete job with actuals
- [ ] Mark job as paid
- [ ] View dashboard analytics

### 11. Inventory & Warehouse
- [ ] Update warehouse counts
- [ ] Create purchase orders
- [ ] Log material usage
- [ ] Track equipment

### 12. Customer Management
- [ ] Add new customer
- [ ] Edit customer details
- [ ] Archive customer
- [ ] View customer history

### 13. Crew Features (if enabled)
- [ ] Crew login with PIN
- [ ] Clock in/out functionality
- [ ] View assigned work orders
- [ ] Submit job completion

## Performance & Optimization

### 14. Performance Checks
- [ ] Run Lighthouse audit in Chrome DevTools
- [ ] Check Core Web Vitals in Vercel Dashboard
- [ ] Verify asset caching is working
- [ ] Test on mobile devices

### 15. Monitoring
- [ ] Enable Vercel Analytics (optional)
- [ ] Enable Vercel Speed Insights (optional)
- [ ] Set up error monitoring (optional)

## Custom Domain (Optional)

### 16. Domain Configuration
- [ ] Purchase domain (if needed)
- [ ] Add domain in Vercel Dashboard → Settings → Domains
- [ ] Update DNS records as instructed
- [ ] Wait for DNS propagation (up to 48 hours)
- [ ] Update Supabase redirect URLs with custom domain
- [ ] Test SSL certificate (should be automatic)

## Final Steps

### 17. Documentation
- [ ] Update README with deployment URL
- [ ] Document environment variables for team
- [ ] Create operations manual (optional)

### 18. Team Onboarding
- [ ] Share Vercel URL with team
- [ ] Provide login credentials
- [ ] Train team on new features
- [ ] Set up support channel

### 19. Backup & Recovery
- [ ] Document Supabase backup strategy
- [ ] Set up automated database backups
- [ ] Create disaster recovery plan

---

## Quick Deploy Commands

### First Time Setup
```bash
# Install dependencies
npm install

# Create environment file
cp .env.example .env.local

# Edit .env.local with your credentials
# Then test locally
npm run dev

# Build to verify
npm run build

# Deploy to Vercel
vercel --prod
```

### Subsequent Deployments
```bash
# Pull latest changes
git pull

# Install any new dependencies
npm install

# Deploy
vercel --prod
```

### Using Deploy Script (Windows)
```powershell
.\deploy-vercel.ps1
```

### Using Deploy Script (macOS/Linux)
```bash
bash deploy-vercel.sh
```

---

## Troubleshooting

### Build Fails
```bash
# Test build locally
npm run build

# Check for TypeScript errors
npx tsc --noEmit

# Clear cache and reinstall
rm -rf node_modules package-lock.json
npm install
npm run build
```

### Environment Variables Not Working
- Ensure variables start with `VITE_`
- Redeploy after adding new variables
- Check Vercel Function Logs for errors

### 404 on Refresh
- Verify `vercel.json` rewrites are configured
- Check client-side routing setup

### Authentication Issues
- Verify Supabase URL configuration
- Check redirect URLs include your domain
- Ensure anon key is correct

---

## Support Resources

- **Vercel Documentation**: https://vercel.com/docs
- **Supabase Documentation**: https://supabase.com/docs
- **Vite Documentation**: https://vitejs.dev
- **React Documentation**: https://react.dev

---

**Deployment Date**: _______________

**Deployed By**: _______________

**Vercel URL**: _______________

**Notes**: _______________
