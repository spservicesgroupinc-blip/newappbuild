import { Client } from 'pg';
import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Supabase connection details
const SUPABASE_URL = 'yjxxisvpcorbgreqkofc.supabase.co';
const SUPABASE_SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlqeHhpc3ZwY29yYmdyZXFrb2ZjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MzQ3NTU0NCwiZXhwIjoyMDg5MDUxNTQ0fQ.IXa47kJ_YCsNTT-vBJsfuxf4IG1VRTG9yCM7Qyk7nLY';

async function applyMigration() {
  const client = new Client({
    host: SUPABASE_URL,
    port: 5432,
    database: 'postgres',
    user: 'postgres',
    password: SUPABASE_SERVICE_ROLE_KEY,
    ssl: { rejectUnauthorized: false }
  });

  try {
    console.log('🔌 Connecting to Supabase database...');
    await client.connect();
    console.log('✅ Connected successfully!');

    // Step 1: Check if app.secret_salt exists
    console.log('\n📋 Checking app.secret_salt config...');
    const configCheck = await client.query("SELECT current_setting('app.secret_salt', true) as secret_salt;");
    const currentSalt = configCheck.rows[0]?.secret_salt;

    if (!currentSalt) {
      console.log('⚠️  app.secret_salt not found. Creating it...');
      // Generate a random salt
      const randomSalt = 'rfe_foam_pro_salt_' + Math.random().toString(36).substring(2, 15) + Date.now();
      await client.query(`SELECT set_config('app.secret_salt', $1, false);`, [randomSalt]);
      console.log(`✅ Created app.secret_salt: ${randomSalt.substring(0, 20)}...`);
    } else {
      console.log(`✅ app.secret_salt already exists: ${currentSalt.substring(0, 20)}...`);
    }

    // Step 2: Read and execute the migration SQL
    console.log('\n📄 Reading migration file...');
    const migrationPath = join(__dirname, 'supabase', 'migrations', '003_rpc_functions.sql');
    const migrationSQL = readFileSync(migrationPath, 'utf-8');
    console.log('✅ Migration file loaded!');

    // Step 3: Execute the migration
    console.log('\n🚀 Applying RPC functions migration...');
    await client.query(migrationSQL);
    console.log('✅ Migration applied successfully!');

    // Step 4: Verify rpc_signup function exists
    console.log('\n🔍 Verifying rpc_signup function...');
    const verifyQuery = await client.query(`
      SELECT routine_name, routine_schema 
      FROM information_schema.routines 
      WHERE routine_name = 'rpc_signup' 
      AND routine_schema = 'public';
    `);

    if (verifyQuery.rows.length > 0) {
      console.log('✅ rpc_signup function is now available!');
    } else {
      console.log('❌ rpc_signup function was not created!');
    }

    // Step 5: List all RPC functions created
    console.log('\n📊 Listing all RPC functions:');
    const rpcFunctions = await client.query(`
      SELECT routine_name 
      FROM information_schema.routines 
      WHERE routine_name LIKE 'rpc_%' 
      AND routine_schema = 'public'
      ORDER BY routine_name;
    `);

    rpcFunctions.rows.forEach(row => {
      console.log(`   - ${row.routine_name}`);
    });

    console.log('\n✅ Migration complete!');

  } catch (error) {
    console.error('❌ Error during migration:', error.message);
    throw error;
  } finally {
    await client.end();
    console.log('\n👋 Database connection closed.');
  }
}

applyMigration().catch(console.error);
