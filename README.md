<div align="center">
<img width="1200" height="475" alt="GHBanner" src="https://github.com/user-attachments/assets/0aa67016-6eaf-458a-adb2-6e31a0763ed6" />
</div>

# RFE Foam Pro - Spray Foam Insulation Business Management Tool

A comprehensive business management tool for spray foam insulation professionals, featuring estimation, inventory management, crew coordination, and financial tracking.

---

## 🚀 Quick Start

### Run Locally

**Prerequisites:** Node.js 18+

1. **Install dependencies:**
   ```bash
   npm install
   ```

2. **Set up environment variables:**
   ```bash
   # Copy the example file
   cp .env.example .env.local

   # Edit .env.local and add your Supabase credentials:
   # VITE_SUPABASE_URL=https://your-project.supabase.co
   # VITE_SUPABASE_ANON_KEY=your-anon-key
   ```

3. **Run the development server:**
   ```bash
   npm run dev
   ```

4. **Open your browser:**
   Navigate to `http://localhost:3000`

---

## ☁️ Deploy to Vercel

### One-Click Deploy

[![Deploy with Vercel](https://vercel.com/button)](https://vercel.com/new/clone?repository-url=https://github.com/yourusername/rfe-foam-pro)

### Deploy via CLI

```bash
# Install Vercel CLI
npm install -g vercel

# Deploy
vercel --prod
```

📖 **Full deployment guide:** See [VERCEL_DEPLOYMENT.md](./VERCEL_DEPLOYMENT.md)

### Quick Deploy Script

**Windows (PowerShell):**
```powershell
.\deploy-vercel.ps1
```

**macOS/Linux (Bash):**
```bash
bash deploy-vercel.sh
```
