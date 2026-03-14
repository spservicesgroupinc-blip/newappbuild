# Vercel Deployment Quick Start Script (PowerShell)
# Run this script to quickly deploy to Vercel on Windows

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  RFE Foam Pro - Vercel Deployment" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if Vercel CLI is installed
Write-Host "📦 Checking Vercel CLI..." -ForegroundColor Yellow
if (-not (Get-Command vercel -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Vercel CLI..." -ForegroundColor Green
    npm install -g vercel
}

# Check if logged in
Write-Host "🔐 Checking Vercel login status..." -ForegroundColor Yellow
try {
    vercel whoami | Out-Null
} catch {
    Write-Host "Please login to Vercel..." -ForegroundColor Yellow
    vercel login
}

# Link project
Write-Host "🔗 Linking to Vercel project..." -ForegroundColor Yellow
vercel link

# Check environment variables
Write-Host "📋 Checking environment variables..." -ForegroundColor Yellow
if (-not (Test-Path .env.local)) {
    Write-Host "⚠️  .env.local not found. Creating from .env.example..." -ForegroundColor Yellow
    Copy-Item .env.example .env.local
    Write-Host "Please edit .env.local and fill in your Supabase credentials:" -ForegroundColor Yellow
    Write-Host "  - VITE_SUPABASE_URL" -ForegroundColor Cyan
    Write-Host "  - VITE_SUPABASE_ANON_KEY" -ForegroundColor Cyan
    Write-Host ""
    Read-Host "Press Enter after you've updated .env.local"
}

# Build locally first
Write-Host "🔨 Building locally..." -ForegroundColor Green
npm run build

# Deploy
Write-Host "🚀 Deploying to Vercel..." -ForegroundColor Green
$deploy = Read-Host "Deploy to production? (y/n)"
if ($deploy -eq "y" -or $deploy -eq "Y") {
    vercel --prod
    Write-Host ""
    Write-Host "✅ Deployment complete!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📝 Next steps:" -ForegroundColor Cyan
    Write-Host "   1. Update Supabase Authentication URLs with your Vercel domain"
    Write-Host "   2. Update Supabase Storage CORS settings"
    Write-Host "   3. Test authentication and all features"
} else {
    Write-Host "Deploying to preview..." -ForegroundColor Yellow
    vercel
}
