# Vercel Deployment Guide

## RFE Foam Pro - Spray Foam Insulation Business Management Tool

This guide will help you deploy your RFE Foam Pro application to Vercel.

---

## Prerequisites

1. **Vercel Account**: Sign up at [vercel.com](https://vercel.com)
2. **Supabase Project**: Your backend should be set up and running
3. **Node.js**: Version 18+ installed locally

---

## Quick Deploy (Recommended)

### Option 1: Vercel CLI

```bash
# Install Vercel CLI globally
npm install -g vercel

# Login to Vercel
vercel login

# Deploy to production
vercel --prod
```

### Option 2: Vercel Dashboard

1. Go to [vercel.com/new](https://vercel.com/new)
2. Import your Git repository
3. Configure the project:
   - **Framework Preset**: Vite
   - **Build Command**: `npm run build`
   - **Output Directory**: `dist`
   - **Install Command**: `npm install`
4. Click **Deploy**

---

## Environment Variables

You **MUST** configure these environment variables in Vercel:

### Required Variables

Go to your Vercel project → **Settings** → **Environment Variables**

| Variable | Description | Example |
|----------|-------------|---------|
| `VITE_SUPABASE_URL` | Your Supabase project URL | `https://xxxxx.supabase.co` |
| `VITE_SUPABASE_ANON_KEY` | Supabase anon/public key | `eyJhbG...` |

### Optional Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `VITE_APP_NAME` | App display name | `RFE Foam Pro` |
| `VITE_ENABLE_CREW_LOGIN` | Enable crew login feature | `true` |
| `VITE_ENABLE_TRIAL_MODE` | Enable trial mode | `true` |
| `VITE_TRIAL_PERIOD_DAYS` | Trial period in days | `14` |
| `VITE_DEBUG` | Enable debug logging | `false` |

---

## Configuration Files

The following files have been configured for Vercel deployment:

### `vercel.json`
- Configures build and output settings
- Sets up SPA rewrites for client-side routing
- Configures caching headers for assets

### `vite.config.ts`
- Already configured with proper build settings
- No changes needed

---

## Deployment Steps

### 1. Connect to Git (Recommended)

```bash
# Initialize git if not already done
git init
git add .
git commit -m "Initial commit"

# Push to GitHub/GitLab/Bitbucket
git remote add origin <your-repo-url>
git push -u origin main
```

### 2. Link to Vercel

```bash
# In your project directory
vercel link
```

### 3. Set Environment Variables

```bash
# Set each variable
vercel env add VITE_SUPABASE_URL production
vercel env add VITE_SUPABASE_ANON_KEY production

# Or import from .env file
vercel env pull .env.production.local
```

### 4. Deploy

```bash
# Deploy to preview
vercel

# Deploy to production
vercel --prod
```

---

## Post-Deployment

### 1. Update Supabase Settings

In your Supabase Dashboard:

1. Go to **Authentication** → **URL Configuration**
2. Add your Vercel URL to:
   - **Site URL**: `https://your-app.vercel.app`
   - **Redirect URLs**: `https://your-app.vercel.app/**`

### 2. Update Storage CORS

In Supabase Storage, ensure CORS allows your Vercel domain:

```json
[
  {
    "Origin": ["https://your-app.vercel.app"],
    "Methods": ["GET", "POST", "PUT", "DELETE"],
    "CacheControl": 3600
  }
]
```

### 3. Test Authentication

- Test signup and login flows
- Verify email confirmations work
- Test password reset functionality

---

## Custom Domain

To use a custom domain:

1. Go to Vercel Dashboard → Your Project → **Settings** → **Domains**
2. Add your domain (e.g., `foampro.yourcompany.com`)
3. Update DNS records as instructed
4. Update Supabase redirect URLs with your custom domain

---

## Continuous Deployment

When connected to Git, Vercel automatically deploys:

- **Push to main**: Production deployment
- **Push to other branches**: Preview deployments
- **Pull Requests**: Preview deployments with unique URLs

---

## Troubleshooting

### Build Fails

```bash
# Test build locally
npm run build

# Check for TypeScript errors
npx tsc --noEmit
```

### Environment Variables Not Working

- Ensure variables are prefixed with `VITE_`
- Redeploy after adding new environment variables
- Check Vercel function logs for errors

### SPA Routing Issues

The `vercel.json` file includes rewrites for client-side routing. If you experience 404s on refresh:

1. Verify `vercel.json` is in the root directory
2. Check the rewrites configuration
3. Redeploy the application

---

## Performance Optimization

### Automatic Optimizations by Vercel

- ✅ Automatic HTTPS
- ✅ Global CDN (Edge Network)
- ✅ Automatic Brotli compression
- ✅ Asset optimization
- ✅ Image optimization (if using Next.js Image)

### Manual Optimizations

1. **Code Splitting**: Already configured via Vite
2. **Lazy Loading**: Implement for heavy components
3. **Caching**: Configure in `vercel.json` (already done)

---

## Monitoring

### Vercel Analytics

Enable analytics in Vercel Dashboard → **Analytics**

### Vercel Speed Insights

Enable in Vercel Dashboard → **Speed Insights**

### Error Monitoring

Check deployment logs in Vercel Dashboard → **Deployments** → Select deployment → **Function Logs**

---

## Support

- **Vercel Docs**: [vercel.com/docs](https://vercel.com/docs)
- **Vite Docs**: [vitejs.dev](https://vitejs.dev)
- **Supabase Docs**: [supabase.com/docs](https://supabase.com/docs)

---

## Deployment Checklist

- [ ] Environment variables configured
- [ ] Supabase URL configuration updated
- [ ] Storage CORS configured
- [ ] Authentication flows tested
- [ ] All features tested in production
- [ ] Custom domain configured (optional)
- [ ] Analytics enabled (optional)

---

**Last Updated**: March 2026
**Version**: 1.0.0
