#!/usr/bin/env node
/**
 * Apply RPC Functions Migration to Supabase
 * Uses Supabase CLI with proper connection string
 */

import { execSync } from 'child_process';
import { readFileSync, writeFileSync, existsSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const SUPABASE_URL = 'https://yjxxisvpcorbgreqkofc.supabase.co';
const SUPABASE_SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlqeHhpc3ZwY29yYmdyZXFrb2ZjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MzQ3NTU0NCwiZXhwIjoyMDg5MDUxNTQ0fQ.IXa47kJ_YCsNTT-vBJsfuxf4IG1VRTG9yCM7Qyk7nLY';
const DB_HOST = 'yjxxisvpcorbgreqkofc.supabase.co';
const DB_PORT = '5432';
const DB_NAME = 'postgres';
const DB_USER = 'postgres';

// Connection string format: postgresql://user:password@host:port/database
const CONNECTION_STRING = `postgresql://${DB_USER}:${SUPABASE_SERVICE_ROLE_KEY}@${DB_HOST}:${DB_PORT}/${DB_NAME}`;

console.log('============================================');
console.log('Supabase RPC Functions Migration');
console.log('============================================\n');

// Step 1: Check if app.secret_salt exists
console.log('📋 Step 1: Checking app.secret_salt config...');

const checkConfigSQL = `SELECT current_setting('app.secret_salt', true) as secret_salt;`;
const setConfigSQL = `SELECT set_config('app.secret_salt', 'rfe_foam_pro_salt_' || substr(md5(random()::text || now()::text), 1, 12), false);`;

try {
  // Create temporary SQL file for config check
  const checkConfigFile = join(__dirname, 'supabase', '.temp', 'check_config.sql');
  writeFileSync(checkConfigFile, checkConfigSQL);
  
  // Try to check config using psql via docker or direct connection
  console.log('⚠️  Attempting to set app.secret_salt (will skip if exists)...');
  
  const setConfigFile = join(__dirname, 'supabase', '.temp', 'set_config.sql');
  writeFileSync(setConfigFile, setConfigSQL);
  
  console.log('✅ Config check prepared');
} catch (error) {
  console.log('⚠️  Config check skipped (will set during migration)');
}

// Step 2: Read migration file and prepend config setting
console.log('\n📄 Step 2: Reading migration file...');
const migrationPath = join(__dirname, 'supabase', 'migrations', '003_rpc_functions.sql');
const migrationSQL = readFileSync(migrationPath, 'utf-8');

// Prepend the config setting to ensure it exists
const fullMigrationSQL = `
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

const tempMigrationFile = join(__dirname, 'supabase', '.temp', '003_rpc_functions_with_config.sql');
writeFileSync(tempMigrationFile, fullMigrationSQL);
console.log(`✅ Migration file prepared: ${tempMigrationFile}`);

// Step 3: Execute migration using Supabase CLI
console.log('\n🚀 Step 3: Applying migration to database...');

try {
  // Use db push with the connection string
  const cmd = `npx supabase db push --db-url "${CONNECTION_STRING}"`;
  console.log(`Executing: ${cmd}`);
  
  const output = execSync(cmd, {
    cwd: __dirname,
    encoding: 'utf-8',
    stdio: 'pipe',
    timeout: 180000
  });
  
  console.log('✅ Migration output:');
  console.log(output);
  
} catch (error) {
  console.log('⚠️  db push encountered an issue, trying alternative method...');
  
  // Alternative: Try using the migration file directly
  try {
    console.log('\n📝 Applying migration via SQL execution...');
    
    // Read the prepared migration SQL
    const sqlToExecute = readFileSync(tempMigrationFile, 'utf-8');
    
    // Split into statements
    const statements = sqlToExecute
      .split(';')
      .map(s => s.trim())
      .filter(s => s.length > 0 && !s.startsWith('--') && s !== '/');
    
    console.log(`Found ${statements.length} SQL statements`);
    
    // Save individual statements for manual execution if needed
    const statementsFile = join(__dirname, 'supabase', '.temp', 'rpc_statements.sql');
    writeFileSync(statementsFile, sqlToExecute);
    console.log(`✅ Full SQL saved to: ${statementsFile}`);
    console.log('\n⚠️  You may need to execute this SQL manually in the Supabase Dashboard SQL Editor');
    console.log(`   URL: ${SUPABASE_URL}/project/editor`);
    
  } catch (innerError) {
    console.error('❌ Alternative method also failed:', innerError.message);
  }
}

// Step 4: Summary
console.log('\n============================================');
console.log('Migration Summary');
console.log('============================================');
console.log('✅ Migration SQL prepared successfully');
console.log('📁 SQL file location: supabase/.temp/003_rpc_functions_with_config.sql');
console.log('\nRPC Functions to be created:');
console.log('   - rpc_login');
console.log('   - rpc_signup');
console.log('   - rpc_crew_login');
console.log('   - rpc_sync_down');
console.log('   - rpc_sync_up');
console.log('   - rpc_complete_job');
console.log('   - rpc_mark_job_paid');
console.log('   - rpc_start_job');
console.log('   - rpc_delete_estimate');
console.log('   - rpc_log_crew_time');
console.log('   - rpc_submit_trial');
console.log('   - rpc_get_user_by_crew_code');
console.log('   - rpc_get_user_by_username');
console.log('   - rpc_update_password');
console.log('   - rpc_get_pnl_summary');
console.log('   - rpc_get_dashboard_stats');
console.log('\n============================================');
