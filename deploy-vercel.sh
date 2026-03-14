#!/bin/bash
# Vercel Deployment Quick Start Script
# Run this script to quickly deploy to Vercel

set -e

echo "========================================"
echo "  RFE Foam Pro - Vercel Deployment"
echo "========================================"
echo ""

# Check if Vercel CLI is installed
if ! command -v vercel &> /dev/null; then
    echo "📦 Installing Vercel CLI..."
    npm install -g vercel
fi

# Check if logged in
echo "🔐 Checking Vercel login status..."
vercel whoami || (echo "Please login to Vercel..." && vercel login)

# Link project
echo "🔗 Linking to Vercel project..."
vercel link

# Check environment variables
echo "📋 Checking environment variables..."
if [ ! -f .env.local ]; then
    echo "⚠️  .env.local not found. Creating from .env.example..."
    cp .env.example .env.local
    echo "Please edit .env.local and fill in your Supabase credentials:"
    echo "  - VITE_SUPABASE_URL"
    echo "  - VITE_SUPABASE_ANON_KEY"
    echo ""
    read -p "Press Enter after you've updated .env.local..."
fi

# Import environment variables to Vercel
echo "📤 Importing environment variables to Vercel..."
if [ -f .env.local ]; then
    vercel env pull .env.vercel
fi

# Build locally first
echo "🔨 Building locally..."
npm run build

# Deploy
echo "🚀 Deploying to Vercel..."
read -p "Deploy to production? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    vercel --prod
    echo ""
    echo "✅ Deployment complete!"
    echo ""
    echo "📝 Next steps:"
    echo "   1. Update Supabase Authentication URLs with your Vercel domain"
    echo "   2. Update Supabase Storage CORS settings"
    echo "   3. Test authentication and all features"
    echo ""
else
    echo "Deploy to preview instead..."
    vercel
fi
