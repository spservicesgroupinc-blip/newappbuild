import { readFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const SUPABASE_URL = 'https://yjxxisvpcorbgreqkofc.supabase.co';
const SUPABASE_SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlqeHhpc3ZwY29yYmdyZXFrb2ZjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MzQ3NTU0NCwiZXhwIjoyMDg5MDUxNTQ0fQ.IXa47kJ_YCsNTT-vBJsfuxf4IG1VRTG9yCM7Qyk7nLY';

// Read the migration SQL
const migrationPath = join(__dirname, 'supabase', 'migrations', '003_rpc_functions.sql');
const migrationSQL = readFileSync(migrationPath, 'utf-8');

// Create the full SQL with config check
const fullSQL = `
-- Ensure app.secret_salt exists
DO $$
BEGIN
    IF current_setting('app.secret_salt', true) IS NULL THEN
        PERFORM set_config('app.secret_salt', 'rfe_foam_pro_salt_' || substr(md5(random()::text || now()::text), 1, 12), false);
        RAISE NOTICE 'Created app.secret_salt config';
    ELSE
        RAISE NOTICE 'app.secret_salt already exists';
    END IF;
END $$;

${migrationSQL}
`;

console.log('============================================');
console.log('Supabase RPC Migration - SQL Execution');
console.log('============================================\n');

// Function to execute SQL via Supabase REST API
async function executeSQL(sql) {
  // Use the Supabase REST API to execute SQL via a temporary function
  // Since direct SQL execution isn't available via REST, we need to use a workaround
  
  const url = `${SUPABASE_URL}/rest/v1/rpc/apply_migration`;
  
  try {
    // First, try to create a temporary function that executes our SQL
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'apikey': SUPABASE_SERVICE_ROLE_KEY,
        'Authorization': `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
        'Prefer': 'return=representation'
      },
      body: JSON.stringify({})
    });
    
    return await response.json();
  } catch (error) {
    throw error;
  }
}

// Alternative approach: Use the Supabase API to create functions one by one
async function applyMigration() {
  console.log('📋 Preparing to apply RPC functions migration...\n');
  
  // Split SQL into individual statements
  const statements = fullSQL
    .split(';')
    .map(s => s.trim())
    .filter(s => s.length > 0 && !s.startsWith('--'));
  
  console.log(`Found ${statements.length} SQL statements to execute\n`);
  
  const results = {
    success: [],
    error: []
  };
  
  // Process CREATE FUNCTION statements
  let currentStatement = '';
  let inFunction = false;
  let functionName = '';
  
  for (const line of fullSQL.split('\n')) {
    if (line.trim().startsWith('CREATE OR REPLACE FUNCTION')) {
      inFunction = true;
      const match = line.match(/FUNCTION\s+(?:public\.)?(\w+)/i);
      functionName = match ? match[1] : 'unknown';
      currentStatement = line;
    } else if (inFunction) {
      currentStatement += '\n' + line;
      if (line.trim().endsWith('$$ LANGUAGE')) {
        // Continue to capture the rest
      } else if (line.trim().endsWith(';')) {
        inFunction = false;
        // We have a complete function
        console.log(`📝 Found function: ${functionName}`);
      }
    }
  }
  
  // For actual execution, we need to use the Supabase Dashboard or psql
  // The REST API doesn't support arbitrary SQL execution
  
  console.log('\n============================================');
  console.log('⚠️  Direct SQL Execution Limitation');
  console.log('============================================\n');
  console.log('The Supabase REST API does not support arbitrary SQL execution.');
  console.log('To apply this migration, you have the following options:\n');
  console.log('1. **Supabase Dashboard SQL Editor** (Recommended)');
  console.log(`   - Go to: ${SUPABASE_URL}/project/editor`);
  console.log('   - Copy and paste the SQL from: supabase/.temp/003_rpc_functions_with_config.sql');
  console.log('   - Click "Run" to execute\n');
  console.log('2. **Supabase CLI with proper authentication');
  console.log('   - Run: supabase login');
  console.log('   - Run: supabase link --project-ref yjxxisvpcorbgreqkofc');
  console.log('   - Run: supabase db push\n');
  console.log('3. **psql command line');
  console.log('   - Connect: psql "postgresql://postgres:[PASSWORD]@yjxxisvpcorbgreqkofc.supabase.co:5432/postgres"');
  console.log('   - Run: \\i supabase/.temp/003_rpc_functions_with_config.sql\n');
  
  // Save the complete SQL for manual execution
  const outputPath = join(__dirname, 'supabase', '.temp', '003_rpc_functions_with_config.sql');
  writeFileSync(outputPath, fullSQL);
  console.log(`✅ Migration SQL saved to: ${outputPath}`);
  
  return { status: 'pending_manual_execution', sqlFile: outputPath };
}

applyMigration().then(result => {
  console.log('\n============================================');
  console.log('Migration Status:', result.status);
  console.log('============================================');
}).catch(console.error);
