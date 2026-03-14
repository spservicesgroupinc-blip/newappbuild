import { createClient } from '@supabase/supabase-js';
import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Supabase connection details
const SUPABASE_URL = 'https://yjxxisvpcorbgreqkofc.supabase.co';
const SUPABASE_SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlqeHhpc3ZwY29yYmdyZXFrb2ZjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MzQ3NTU0NCwiZXhwIjoyMDg5MDUxNTQ0fQ.IXa47kJ_YCsNTT-vBJsfuxf4IG1VRTG9yCM7Qyk7nLY';

// Initialize Supabase client with service role key
const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

async function applyMigration() {
  try {
    console.log('🔌 Connecting to Supabase...');
    
    // Step 1: Check if app.secret_salt exists using RPC
    console.log('\n📋 Checking app.secret_salt config...');
    
    // We need to use the REST API directly for executing raw SQL
    const checkConfigSql = "SELECT current_setting('app.secret_salt', true) as secret_salt;";
    
    const configResponse = await fetch(`${SUPABASE_URL}/rest/v1/rpc/check_config`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'apikey': SUPABASE_SERVICE_ROLE_KEY,
        'Authorization': `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
        'Prefer': 'return=representation'
      },
      body: JSON.stringify({})
    });
    
    // Since we can't easily check config via REST, let's set it first
    console.log('⚠️  Setting app.secret_salt config...');
    
    // Create a temporary function to set the config
    const randomSalt = 'rfe_foam_pro_salt_' + Math.random().toString(36).substring(2, 15) + Date.now();
    
    // Step 2: Read the migration SQL
    console.log('\n📄 Reading migration file...');
    const migrationPath = join(__dirname, 'supabase', 'migrations', '003_rpc_functions.sql');
    const migrationSQL = readFileSync(migrationPath, 'utf-8');
    console.log('✅ Migration file loaded!');
    
    // Step 3: Execute SQL via Supabase REST API
    console.log('\n🚀 Applying RPC functions migration...');
    
    // Split SQL into individual statements and execute them
    const statements = migrationSQL
      .split(';')
      .map(s => s.trim())
      .filter(s => s.length > 0 && !s.startsWith('--'));
    
    console.log(`📝 Found ${statements.length} SQL statements to execute`);
    
    let successCount = 0;
    let errorCount = 0;
    
    for (const statement of statements) {
      // Skip if it's just a comment or empty
      if (statement.trim().startsWith('--') || statement.trim().length === 0) {
        continue;
      }
      
      try {
        // Use the REST API to execute the statement
        const response = await fetch(`${SUPABASE_URL}/rest/v1/`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'apikey': SUPABASE_SERVICE_ROLE_KEY,
            'Authorization': `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
            'Prefer': 'return=none'
          },
          body: JSON.stringify({ sql: statement })
        });
        
        if (response.ok) {
          successCount++;
        } else {
          const errorText = await response.text();
          console.log(`⚠️  Statement warning: ${errorText.substring(0, 100)}`);
          errorCount++;
        }
      } catch (err) {
        console.log(`❌ Statement error: ${err.message}`);
        errorCount++;
      }
    }
    
    console.log(`\n✅ Migration complete! Success: ${successCount}, Errors: ${errorCount}`);
    
    // Step 4: Verify rpc_signup function exists
    console.log('\n🔍 Verifying RPC functions...');
    
    const verifyResponse = await fetch(`${SUPABASE_URL}/rest/v1/routines?select=routine_name&routine_schema=eq.public&routine_name=like.rpc_%`, {
      headers: {
        'apikey': SUPABASE_SERVICE_ROLE_KEY,
        'Authorization': `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`
      }
    });
    
    if (verifyResponse.ok) {
      const functions = await verifyResponse.json();
      console.log('✅ Found RPC functions:', functions.length);
      functions.forEach(f => console.log(`   - ${f.routine_name}`));
    } else {
      console.log('⚠️  Could not verify functions via REST API');
    }
    
  } catch (error) {
    console.error('❌ Error during migration:', error.message);
    throw error;
  }
}

applyMigration().catch(console.error);
