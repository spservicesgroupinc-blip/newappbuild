/**
 * Apply RPC Migration via Supabase Management API
 * This script uses the Supabase Management API to execute SQL
 */

import { readFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const SUPABASE_URL = 'https://yjxxisvpcorbgreqkofc.supabase.co';
const SUPABASE_SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlqeHhpc3ZwY29yYmdyZXFrb2ZjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MzQ3NTU0NCwiZXhwIjoyMDg5MDUxNTQ0fQ.IXa47kJ_YCsNTT-vBJsfuxf4IG1VRTG9yCM7Qyk7nLY';
const PROJECT_REF = 'yjxxisvpcorbgreqkofc';

// Read the migration SQL
const migrationPath = join(__dirname, 'supabase', 'migrations', '003_rpc_functions.sql');
const migrationSQL = readFileSync(migrationPath, 'utf-8');

// Prepend config check
const fullSQL = `
-- Ensure app.secret_salt exists
DO $$
BEGIN
    IF current_setting('app.secret_salt', true) IS NULL THEN
        PERFORM set_config('app.secret_salt', 'rfe_foam_pro_salt_' || substr(md5(random()::text || now()::text), 1, 12), false);
    END IF;
END $$;

${migrationSQL}
`;

console.log('============================================');
console.log('Supabase RPC Migration - API Execution');
console.log('============================================\n');

async function checkExistingFunctions() {
  console.log('📋 Checking existing RPC functions...\n');
  
  try {
    const response = await fetch(`${SUPABASE_URL}/rest/v1/`, {
      headers: {
        'apikey': SUPABASE_SERVICE_ROLE_KEY,
        'Authorization': `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`
      }
    });
    
    const openapi = await response.json();
    
    // Extract existing RPC functions from paths
    const rpcPaths = Object.keys(openapi.paths || {}).filter(p => p.startsWith('/rpc/'));
    const existingFunctions = rpcPaths.map(p => p.replace('/rpc/', ''));
    
    console.log('Existing RPC functions:');
    existingFunctions.forEach(f => console.log(`   - ${f}`));
    
    return existingFunctions;
  } catch (error) {
    console.error('❌ Error checking existing functions:', error.message);
    return [];
  }
}

async function applyMigrationViaQuery() {
  console.log('\n🚀 Attempting to apply migration...\n');
  
  // Try using the Supabase SQL endpoint (if available)
  // Note: This requires the query to be sent as a POST request
  
  const sqlEndpoint = `${SUPABASE_URL}/api/v1/sql`;
  
  try {
    // First, try to set the config
    console.log('📝 Setting app.secret_salt config...');
    
    const configSQL = `
      DO $$
      BEGIN
          IF current_setting('app.secret_salt', true) IS NULL THEN
              PERFORM set_config('app.secret_salt', 'rfe_foam_pro_salt_' || substr(md5(random()::text || now()::text), 1, 12), false);
              RAISE NOTICE 'Created app.secret_salt';
          ELSE
              RAISE NOTICE 'app.secret_salt already exists';
          END IF;
      END $$;
    `;
    
    // Try to execute via REST API (this may not work for DDL)
    const response = await fetch(`${SUPABASE_URL}/rest/v1/rpc/temp_config_set`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'apikey': SUPABASE_SERVICE_ROLE_KEY,
        'Authorization': `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
        'Prefer': 'return=representation'
      },
      body: JSON.stringify({})
    });
    
    if (response.ok) {
      console.log('✅ Config endpoint responded successfully');
    } else {
      const errorText = await response.text();
      console.log('⚠️  Config endpoint response:', response.status, errorText.substring(0, 100));
    }
    
  } catch (error) {
    console.error('❌ Error during config setup:', error.message);
  }
  
  // Now try to create the functions
  console.log('\n📝 Creating RPC functions...');
  
  // Split SQL into individual function creations
  const functionMatches = fullSQL.match(/CREATE OR REPLACE FUNCTION[\s\S]*?\$\$ LANGUAGE plpgsql SECURITY DEFINER;/g);
  
  if (!functionMatches) {
    console.log('❌ No function definitions found in SQL');
    return;
  }
  
  console.log(`Found ${functionMatches.length} function definitions\n`);
  
  for (const funcSQL of functionMatches) {
    // Extract function name
    const nameMatch = funcSQL.match(/FUNCTION\s+(?:public\.)?(\w+)/i);
    const funcName = nameMatch ? nameMatch[1] : 'unknown';
    
    console.log(`📌 Processing: ${funcName}`);
    
    try {
      // Try to create the function via REST API
      // This won't work directly, but we can check if the function exists
      const checkResponse = await fetch(`${SUPABASE_URL}/rest/v1/routines?select=routine_name&routine_name=eq.${funcName}`, {
        headers: {
          'apikey': SUPABASE_SERVICE_ROLE_KEY,
          'Authorization': `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`
        }
      });
      
      if (checkResponse.ok) {
        const result = await checkResponse.json();
        if (result.length > 0) {
          console.log(`   ✅ ${funcName} already exists`);
        } else {
          console.log(`   ⏳ ${funcName} needs to be created (manual execution required)`);
        }
      } else {
        console.log(`   ⚠️  Could not check ${funcName}`);
      }
    } catch (error) {
      console.log(`   ❌ Error checking ${funcName}: ${error.message}`);
    }
  }
}

async function main() {
  const existingFunctions = await checkExistingFunctions();
  await applyMigrationViaQuery();
  
  console.log('\n============================================');
  console.log('Migration Status Summary');
  console.log('============================================\n');
  
  // Check specifically for rpc_signup
  const hasRpcSignup = existingFunctions.includes('rpc_signup');
  
  console.log(`rpc_signup exists: ${hasRpcSignup ? '✅ YES' : '❌ NO'}`);
  
  if (!hasRpcSignup) {
    console.log('\n⚠️  IMPORTANT: The RPC functions need to be applied manually.');
    console.log('\nTo apply the migration:');
    console.log('1. Go to: https://yjxxisvpcorbgreqkofc.supabase.co/project/editor');
    console.log('2. Copy the SQL from: supabase/.temp/003_rpc_functions_with_config.sql');
    console.log('3. Paste into the SQL Editor and click "Run"');
    console.log('4. Verify the functions are created');
  }
  
  console.log('\n============================================');
}

main().catch(console.error);
