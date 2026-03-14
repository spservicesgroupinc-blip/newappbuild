# Supabase Setup Verification Script
# Run this after configuring your Supabase project to verify everything is set up correctly

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Supabase Setup Verification" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Check if .env.local exists
if (Test-Path ".env.local") {
    Write-Host "✓ .env.local file exists" -ForegroundColor Green
    
    # Read and check for placeholder values
    $envContent = Get-Content ".env.local" -Raw
    if ($envContent -match "your-project-id\.supabase\.co") {
        Write-Host "⚠ VITE_SUPABASE_URL contains placeholder value - please update with your actual project URL" -ForegroundColor Yellow
    } else {
        Write-Host "✓ VITE_SUPABASE_URL appears to be configured" -ForegroundColor Green
    }
    
    if ($envContent -match "your-anon-key-here") {
        Write-Host "⚠ VITE_SUPABASE_ANON_KEY contains placeholder value - please update with your actual anon key" -ForegroundColor Yellow
    } else {
        Write-Host "✓ VITE_SUPABASE_ANON_KEY appears to be configured" -ForegroundColor Green
    }
} else {
    Write-Host "✗ .env.local file not found - please create it from .env.local.example" -ForegroundColor Red
}

Write-Host ""
Write-Host "--------------------------------------------" -ForegroundColor Cyan
Write-Host "Checking Supabase CLI..." -ForegroundColor Cyan
Write-Host ""

# Check if Supabase CLI is installed
try {
    $null = Get-Command supabase -ErrorAction Stop
    Write-Host "✓ Supabase CLI is installed" -ForegroundColor Green
    
    # Check if logged in
    Write-Host "Checking Supabase authentication..." -ForegroundColor Cyan
    $loginStatus = supabase whoami 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Logged in to Supabase as: $loginStatus" -ForegroundColor Green
    } else {
        Write-Host "⚠ Not logged in to Supabase. Run: supabase login" -ForegroundColor Yellow
    }
} catch {
    Write-Host "✗ Supabase CLI not found. Install with: npm install -g supabase" -ForegroundColor Red
}

Write-Host ""
Write-Host "--------------------------------------------" -ForegroundColor Cyan
Write-Host "Checking Migration Files..." -ForegroundColor Cyan
Write-Host ""

# Check migration files
$migrations = @(
    "supabase/migrations/001_initial_schema.sql",
    "supabase/migrations/002_functions_triggers.sql",
    "supabase/migrations/003_rpc_functions.sql",
    "supabase/migrations/004_storage_buckets.sql"
)

foreach ($migration in $migrations) {
    if (Test-Path $migration) {
        $size = (Get-Item $migration).Length
        Write-Host "✓ $migration ($size bytes)" -ForegroundColor Green
    } else {
        Write-Host "✗ $migration not found" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "--------------------------------------------" -ForegroundColor Cyan
Write-Host "Checking Project Structure..." -ForegroundColor Cyan
Write-Host ""

# Check critical files
$criticalFiles = @(
    "services/supabase.ts",
    "services/api.ts",
    "hooks/useSync.ts",
    "hooks/useEstimates.ts",
    "components/LoginPage.tsx",
    "package.json"
)

foreach ($file in $criticalFiles) {
    if (Test-Path $file) {
        Write-Host "✓ $file" -ForegroundColor Green
    } else {
        Write-Host "✗ $file not found" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "--------------------------------------------" -ForegroundColor Cyan
Write-Host "Checking Dependencies..." -ForegroundColor Cyan
Write-Host ""

# Check if node_modules exists
if (Test-Path "node_modules") {
    Write-Host "✓ node_modules directory exists" -ForegroundColor Green
    
    # Check for Supabase package
    if (Test-Path "node_modules/@supabase/supabase-js") {
        Write-Host "✓ @supabase/supabase-js installed" -ForegroundColor Green
    } else {
        Write-Host "⚠ @supabase/supabase-js not found. Run: npm install" -ForegroundColor Yellow
    }
} else {
    Write-Host "⚠ node_modules not found. Run: npm install" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Next Steps:" -ForegroundColor White
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Create a Supabase project at https://supabase.com" -ForegroundColor White
Write-Host "2. Get your project URL and anon key from Dashboard → Settings → API" -ForegroundColor White
Write-Host "3. Update .env.local with your credentials" -ForegroundColor White
Write-Host "4. Run the database migrations (see SUPABASE_MIGRATION.md)" -ForegroundColor White
Write-Host "5. Create storage buckets in Dashboard → Storage" -ForegroundColor White
Write-Host "6. Run: npm install" -ForegroundColor White
Write-Host "7. Run: npm run dev" -ForegroundColor White
Write-Host ""
Write-Host "For detailed instructions, see:" -ForegroundColor Cyan
Write-Host "  - SUPABASE_MIGRATION.md (complete migration guide)" -ForegroundColor Cyan
Write-Host "  - supabase/README.md (technical documentation)" -ForegroundColor Cyan
Write-Host "  - MIGRATION_QUICKREF.md (quick reference)" -ForegroundColor Cyan
Write-Host ""
