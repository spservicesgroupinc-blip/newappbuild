# Supabase Setup Script for Windows PowerShell
# Run this after installing Supabase CLI to set up your project

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Supabase Setup for RFE Foam Pro" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Check if Supabase CLI is installed
try {
    $null = Get-Command supabase -ErrorAction Stop
} catch {
    Write-Host "❌ Supabase CLI not found. Installing..." -ForegroundColor Yellow
    npm install -g supabase
}

# Login to Supabase
Write-Host "🔐 Logging in to Supabase..." -ForegroundColor Cyan
supabase login

# Initialize Supabase project (if not already initialized)
if (-not (Test-Path "supabase")) {
    Write-Host "📁 Initializing Supabase project..." -ForegroundColor Cyan
    supabase init
}

# Link to existing project
Write-Host ""
Write-Host "🔗 Link to your Supabase project" -ForegroundColor Cyan
Write-Host "Enter your project ref (found in Dashboard → Settings → API):"
$PROJECT_REF = Read-Host

supabase link --project-ref $PROJECT_REF

# Push migrations
Write-Host ""
Write-Host "📤 Pushing database migrations..." -ForegroundColor Cyan
supabase db push

# Generate TypeScript types
Write-Host ""
Write-Host "📝 Generating TypeScript types..." -ForegroundColor Cyan
supabase gen types typescript --linked > services/supabase-types.ts

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "✅ Setup Complete!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor White
Write-Host "1. Copy .env.local.example to .env.local" -ForegroundColor White
Write-Host "2. Add your Supabase URL and anon key to .env.local" -ForegroundColor White
Write-Host "3. Create storage buckets in Dashboard → Storage" -ForegroundColor White
Write-Host "4. Run: npm install" -ForegroundColor White
Write-Host "5. Run: npm run dev" -ForegroundColor White
Write-Host ""
