# Supabase Setup Script
# Run this after installing Supabase CLI to set up your project

#!/bin/bash

echo "============================================"
echo "Supabase Setup for RFE Foam Pro"
echo "============================================"
echo ""

# Check if Supabase CLI is installed
if ! command -v supabase &> /dev/null; then
    echo "❌ Supabase CLI not found. Installing..."
    npm install -g supabase
fi

# Login to Supabase
echo "🔐 Logging in to Supabase..."
supabase login

# Initialize Supabase project (if not already initialized)
if [ ! -d "supabase" ]; then
    echo "📁 Initializing Supabase project..."
    supabase init
fi

# Link to existing project
echo ""
echo "🔗 Link to your Supabase project"
echo "Enter your project ref (found in Dashboard → Settings → API):"
read PROJECT_REF

supabase link --project-ref $PROJECT_REF

# Push migrations
echo ""
echo "📤 Pushing database migrations..."
supabase db push

# Generate TypeScript types
echo ""
echo "📝 Generating TypeScript types..."
supabase gen types typescript --linked > services/supabase-types.ts

# Create storage buckets (via SQL)
echo ""
echo "🗄️  Setting up storage buckets..."
supabase db execute --file supabase/migrations/004_storage_buckets.sql

echo ""
echo "============================================"
echo "✅ Setup Complete!"
echo "============================================"
echo ""
echo "Next steps:"
echo "1. Copy .env.local.example to .env.local"
echo "2. Add your Supabase URL and anon key to .env.local"
echo "3. Create storage buckets in Dashboard → Storage"
echo "4. Run: npm install"
echo "5. Run: npm run dev"
echo ""
