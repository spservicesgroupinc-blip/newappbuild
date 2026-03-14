/**
 * Supabase Client Service
 * Replaces Google Apps Script API with Supabase backend
 */

import { createClient, SupabaseClient } from '@supabase/supabase-js';
import { CalculatorState, EstimateRecord, UserSession, CustomerProfile, InventoryItem, EquipmentItem, PurchaseOrder } from '../types';

// Environment variables
const SUPABASE_URL = import.meta.env.VITE_SUPABASE_URL;
const SUPABASE_ANON_KEY = import.meta.env.VITE_SUPABASE_ANON_KEY;

if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
  console.warn('Supabase credentials not configured. Please set VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY');
}

// Create Supabase client
export const supabase: SupabaseClient = createClient(
  SUPABASE_URL || '',
  SUPABASE_ANON_KEY || ''
);

// ============================================================
// TYPE DEFINITIONS
// ============================================================

export interface Database {
  public: {
    Tables: {
      users: {
        Row: {
          id: string;
          auth_user_id: string | null;
          username: string;
          company_name: string;
          crew_code: string | null;
          email: string | null;
          role: 'admin' | 'crew';
          created_at: string;
        };
      };
      customers: {
        Row: {
          id: string;
          name: string;
          address: string | null;
          city: string | null;
          state: string | null;
          zip: string | null;
          phone: string | null;
          email: string | null;
          status: 'Active' | 'Archived' | 'Lead';
          notes: string | null;
          user_id: string;
          created_at: string;
          updated_at: string;
        };
      };
      estimates: {
        Row: {
          id: string;
          date: string;
          customer_id: string;
          total_value: number;
          status: 'Draft' | 'Work Order' | 'Invoiced' | 'Paid' | 'Archived';
          execution_status: 'Not Started' | 'In Progress' | 'Completed';
          invoice_number: string | null;
          pdf_link: string | null;
          work_order_sheet_url: string | null;
          user_id: string;
          inputs_json: Record<string, unknown>;
          results_json: Record<string, unknown>;
          materials_json: Record<string, unknown>;
          wall_settings_json: Record<string, unknown>;
          roof_settings_json: Record<string, unknown>;
          expenses_json: Record<string, unknown>;
          actuals_json: Record<string, unknown>;
          financials_json: Record<string, unknown>;
          sqft_rates_json: Record<string, unknown>;
          notes: string | null;
          pricing_mode: 'level_pricing' | 'sqft_pricing';
          scheduled_date: string | null;
          invoice_date: string | null;
          payment_terms: string | null;
          inventory_processed: boolean;
          site_photos: string[];
          created_at: string;
          updated_at: string;
        };
      };
      inventory_items: {
        Row: {
          id: string;
          name: string;
          quantity: number;
          unit: string;
          unit_cost: number;
          user_id: string;
          created_at: string;
          updated_at: string;
        };
      };
      equipment_items: {
        Row: {
          id: string;
          name: string;
          status: 'Available' | 'In Use' | 'Maintenance' | 'Lost';
          last_seen_json: Record<string, unknown>;
          user_id: string;
          created_at: string;
          updated_at: string;
        };
      };
      warehouse_counts: {
        Row: {
          user_id: string;
          open_cell_sets: number;
          closed_cell_sets: number;
          updated_at: string;
        };
      };
      lifetime_usage: {
        Row: {
          user_id: string;
          open_cell: number;
          closed_cell: number;
          updated_at: string;
        };
      };
      app_settings: {
        Row: {
          user_id: string;
          yields_json: Record<string, unknown>;
          costs_json: Record<string, unknown>;
          expenses_json: Record<string, unknown>;
          job_notes: string | null;
          sqft_rates_json: Record<string, unknown>;
          pricing_mode: 'level_pricing' | 'sqft_pricing';
          updated_at: string;
        };
      };
      company_profiles: {
        Row: {
          user_id: string;
          company_name: string;
          address_line1: string | null;
          address_line2: string | null;
          city: string | null;
          state: string | null;
          zip: string | null;
          phone: string | null;
          email: string | null;
          website: string | null;
          logo_url: string | null;
          crew_access_pin: string | null;
          updated_at: string;
        };
      };
      material_logs: {
        Row: {
          id: string;
          date: string;
          job_id: string | null;
          customer_name: string;
          material_name: string;
          quantity: number;
          unit: string;
          logged_by: string;
          user_id: string;
          created_at: string;
        };
      };
      purchase_orders: {
        Row: {
          id: string;
          date: string;
          vendor_name: string;
          status: 'Draft' | 'Sent' | 'Received' | 'Cancelled';
          items_json: Record<string, unknown>;
          total_cost: number;
          notes: string | null;
          user_id: string;
          created_at: string;
          updated_at: string;
        };
      };
      profit_loss_records: {
        Row: {
          id: string;
          estimate_id: string | null;
          recorded_at: string;
          customer_name: string | null;
          invoice_number: string | null;
          revenue: number;
          chemical_cost: number;
          labor_cost: number;
          inventory_cost: number;
          misc_cost: number;
          total_cogs: number;
          net_profit: number;
          margin: number;
          user_id: string;
        };
      };
    };
    Views: {
      storage_usage: {
        Row: {
          user_folder: string | null;
          bucket_id: string;
          file_count: number | null;
          total_bytes: number | null;
        };
      };
    };
    Functions: {
      rpc_login: {
        Args: { p_username: string; p_password: string };
        Returns: Record<string, unknown>;
      };
      rpc_signup: {
        Args: { p_username: string; p_password: string; p_company_name: string; p_email?: string };
        Returns: Record<string, unknown>;
      };
      rpc_crew_login: {
        Args: { p_username: string; p_pin: string };
        Returns: Record<string, unknown>;
      };
      rpc_sync_down: {
        Args: { p_user_id: string; p_last_sync_timestamp?: number };
        Returns: Record<string, unknown>;
      };
      rpc_sync_up: {
        Args: { p_user_id: string; p_state: Record<string, unknown> };
        Returns: Record<string, unknown>;
      };
      rpc_complete_job: {
        Args: { p_user_id: string; p_estimate_id: string; p_actuals: Record<string, unknown> };
        Returns: Record<string, unknown>;
      };
      rpc_mark_job_paid: {
        Args: { p_user_id: string; p_estimate_id: string };
        Returns: Record<string, unknown>;
      };
      rpc_start_job: {
        Args: { p_user_id: string; p_estimate_id: string };
        Returns: Record<string, unknown>;
      };
      rpc_delete_estimate: {
        Args: { p_user_id: string; p_estimate_id: string };
        Returns: Record<string, unknown>;
      };
      rpc_log_crew_time: {
        Args: { p_user_id: string; p_estimate_id: string; p_start_time: string; p_end_time?: string };
        Returns: Record<string, unknown>;
      };
      rpc_submit_trial: {
        Args: { p_name: string; p_email: string; p_phone?: string };
        Returns: Record<string, unknown>;
      };
      rpc_get_user_by_crew_code: {
        Args: { p_crew_code: string };
        Returns: Record<string, unknown>;
      };
      rpc_get_user_by_username: {
        Args: { p_username: string };
        Returns: Record<string, unknown>;
      };
      rpc_update_password: {
        Args: { p_user_id: string; p_new_password: string };
        Returns: Record<string, unknown>;
      };
      rpc_get_pnl_summary: {
        Args: { p_user_id: string; p_start_date?: string; p_end_date?: string };
        Returns: Record<string, unknown>;
      };
      rpc_get_dashboard_stats: {
        Args: { p_user_id: string };
        Returns: Record<string, unknown>;
      };
    };
  };
}

// ============================================================
// AUTHENTICATION SERVICES (Using Supabase Auth)
// ============================================================

/**
 * Login with email and password using Supabase Auth
 */
export const loginUser = async (email: string, password: string): Promise<UserSession | null> => {
  try {
    console.log('[Login] Attempting login for:', email);

    // Use Supabase Auth for authentication
    const { data, error } = await supabase.auth.signInWithPassword({
      email,
      password
    });

    if (error) {
      console.error('[Login] Supabase Auth error:', error);
      // Handle common errors
      if (error.message.includes('Invalid login credentials')) {
        throw new Error('Invalid email or password');
      }
      if (error.message.includes('Email not confirmed')) {
        throw new Error('Please verify your email address');
      }
      throw new Error(error.message || 'Login failed');
    }

    if (!data.user) {
      console.error('[Login] No user data returned');
      throw new Error('Login failed - no user found');
    }

    console.log('[Login] Auth successful, user ID:', data.user.id);

    // Fetch user data from public.users table
    const { data: userData, error: userError } = await supabase
      .from('users')
      .select('*')
      .eq('auth_user_id', data.user.id)
      .single();

    if (userError) {
      console.error('[Login] Error fetching user profile:', userError);
      throw new Error('User profile not found. Please contact support.');
    }

    if (!userData) {
      console.error('[Login] User profile not found for auth user:', data.user.id);
      throw new Error('User profile not found');
    }

    console.log('[Login] User profile found:', userData.username);

    const session: UserSession = {
      username: userData.username,
      companyName: userData.company_name,
      spreadsheetId: userData.spreadsheet_id || '',
      folderId: userData.folder_id || '',
      role: userData.role,
      token: data.session.access_token
    };

    // Save session to localStorage
    localStorage.setItem('foamProSession', JSON.stringify(session));
    console.log('[Login] Login successful');

    return session;
  } catch (error: unknown) {
    console.error('[Login] Final error:', error);
    if (error instanceof Error) {
      throw error;
    }
    throw new Error('An unexpected error occurred during login');
  }
};

/**
 * Signup with email, password, and company name using Supabase Auth
 */
export const signupUser = async (
  email: string,
  password: string,
  companyName: string,
  username?: string
): Promise<UserSession | null> => {
  try {
    console.log('[Signup] Starting signup process for:', email);

    // Use Supabase Auth for signup
    const { data, error } = await supabase.auth.signUp({
      email,
      password,
      options: {
        data: {
          username: username || email,
          company_name: companyName,
          role: 'admin'
        },
        // Don't require email confirmation for immediate access
        emailRedirectTo: window.location.origin
      }
    });

    if (error) {
      console.error('[Signup] Supabase Auth error:', error);
      throw new Error(error.message || 'Signup failed');
    }

    if (!data.user) {
      console.error('[Signup] No user data returned');
      throw new Error('Signup failed - no user created');
    }

    console.log('[Signup] User created in auth:', data.user.id);

    // Email confirmation required — session is null until user confirms email
    if (!data.session) {
      return null;
    }

    // Wait for the trigger to create the public.users record
    await new Promise(resolve => setTimeout(resolve, 1000));

    // Fetch the newly created user data from public.users
    const { data: userData, error: userError } = await supabase
      .from('users')
      .select('*')
      .eq('auth_user_id', data.user.id)
      .single();

    if (userError) {
      console.error('[Signup] Error fetching user from public.users:', userError);
    }

    if (!userData) {
      // Trigger didn't create the user - create manually
      console.log('[Signup] Creating user manually in public.users');
      const crewCode = String(Math.floor(1000 + Math.random() * 9000));

      const { data: manualUser, error: insertError } = await supabase
        .from('users')
        .insert({
          auth_user_id: data.user.id,
          username: username || email,
          company_name: companyName,
          email: email,
          role: 'admin',
          crew_code: crewCode
        })
        .select()
        .single();

      if (insertError) {
        console.error('[Signup] Manual insert error:', insertError);
        throw new Error('Failed to create user profile: ' + insertError.message);
      }

      if (!manualUser) {
        throw new Error('Failed to create user profile - no data returned');
      }

      console.log('[Signup] Manual user created:', manualUser.id);

      // Create default app_settings
      const { error: settingsError } = await supabase.from('app_settings').insert({
        user_id: manualUser.id
      });
      if (settingsError) console.error('[Signup] app_settings error:', settingsError);

      // Create default warehouse_counts
      const { error: warehouseError } = await supabase.from('warehouse_counts').insert({
        user_id: manualUser.id
      });
      if (warehouseError) console.error('[Signup] warehouse_counts error:', warehouseError);

      // Create default lifetime_usage
      const { error: usageError } = await supabase.from('lifetime_usage').insert({
        user_id: manualUser.id
      });
      if (usageError) console.error('[Signup] lifetime_usage error:', usageError);

      // Create company profile
      const { error: profileError } = await supabase.from('company_profiles').insert({
        user_id: manualUser.id,
        company_name: companyName,
        crew_access_pin: crewCode
      });
      if (profileError) console.error('[Signup] company_profiles error:', profileError);

      const session: UserSession = {
        username: manualUser.username,
        companyName: manualUser.company_name,
        spreadsheetId: '',
        folderId: '',
        role: 'admin',
        token: data.session?.access_token || ''
      };

      localStorage.setItem('foamProSession', JSON.stringify(session));
      console.log('[Signup] Session created for manual user');
      return session;
    }

    console.log('[Signup] User found in public.users:', userData.id);

    const session: UserSession = {
      username: userData.username,
      companyName: userData.company_name,
      spreadsheetId: userData.spreadsheet_id || '',
      folderId: userData.folder_id || '',
      role: userData.role,
      token: data.session?.access_token || ''
    };

    localStorage.setItem('foamProSession', JSON.stringify(session));
    console.log('[Signup] Session created for trigger-created user');
    return session;
  } catch (error: unknown) {
    console.error('[Signup] Final error:', error);
    if (error instanceof Error) {
      throw error;
    }
    throw new Error('An unexpected error occurred during signup');
  }
};

/**
 * Crew login with PIN - looks up user by crew_code
 */
export const loginCrew = async (username: string, pin: string): Promise<UserSession | null> => {
  try {
    // Find user by crew_code (PIN)
    const { data: userData, error: userError } = await supabase
      .from('users')
      .select('*')
      .eq('crew_code', pin)
      .single();

    if (userError || !userData) {
      throw new Error('Invalid crew code');
    }

    // For crew members, we create a session without Supabase Auth
    // This is a lightweight auth for temporary/field access
    const session: UserSession = {
      username: userData.username,
      companyName: userData.company_name,
      spreadsheetId: userData.spreadsheet_id || '',
      folderId: userData.folder_id || '',
      role: 'crew',
      token: `crew_${userData.id}_${Date.now()}`
    };

    localStorage.setItem('foamProSession', JSON.stringify(session));
    return session;
  } catch (error: unknown) {
    console.error('Crew login error:', error);
    throw error;
  }
};

/**
 * Logout current user
 */
export const logoutUser = async (): Promise<void> => {
  await supabase.auth.signOut();
  localStorage.removeItem('foamProSession');
};

/**
 * Request password reset for user
 */
export const resetPassword = async (email: string): Promise<void> => {
  const { error } = await supabase.auth.resetPasswordForEmail(email, {
    redirectTo: `${window.location.origin}/#access_token`
  });

  if (error) {
    throw new Error(error.message || 'Failed to send password reset email');
  }
};

/**
 * Update user password
 */
export const updatePassword = async (newPassword: string): Promise<void> => {
  const { error } = await supabase.auth.updateUser({
    password: newPassword
  });

  if (error) {
    throw new Error(error.message || 'Failed to update password');
  }
};

/**
 * Get current session from Supabase Auth
 */
export const getCurrentSession = async (): Promise<UserSession | null> => {
  const { data: { session } } = await supabase.auth.getSession();

  if (!session?.user) {
    // Try to restore from localStorage
    const savedSession = localStorage.getItem('foamProSession');
    if (savedSession) {
      try {
        return JSON.parse(savedSession);
      } catch {
        return null;
      }
    }
    return null;
  }

  const { data: userData } = await supabase
    .from('users')
    .select('*')
    .eq('auth_user_id', session.user.id)
    .single();

  if (!userData) {
    return null;
  }

  return {
    username: userData.username,
    companyName: userData.company_name,
    spreadsheetId: userData.spreadsheet_id || '',
    folderId: userData.folder_id || '',
    role: userData.role,
    token: session.access_token
  };
};

// ============================================================
// SYNC SERVICES
// ============================================================

/**
 * Sync down - Get all data from server (with delta sync support)
 */
export const syncDown = async (userId: string, lastSyncTimestamp?: number): Promise<Partial<CalculatorState> | null> => {
  try {
    const { data, error } = await supabase.rpc('rpc_sync_down', {
      p_user_id: userId,
      p_last_sync_timestamp: lastSyncTimestamp || 0
    });

    if (error || !data) {
      console.error('Sync down error:', error);
      return null;
    }

    const result = data as Record<string, unknown>;

    // Transform database format to app state format
    const warehouse = result.warehouse as Record<string, unknown> || {};
    const settings = result.settings as Record<string, unknown> || {};

    // Type-safe transformations with defaults
    const yieldsData = (settings.yields as Record<string, unknown>) || {};
    const costsData = (settings.costs as Record<string, unknown>) || {};
    const expensesData = (settings.expenses as Record<string, unknown>) || {};

    return {
      warehouse: {
        openCellSets: (warehouse.openCellSets as number) || 0,
        closedCellSets: (warehouse.closedCellSets as number) || 0,
        items: ((warehouse.items as any[]) || []) as any
      },
      lifetimeUsage: result.lifetimeUsage as { openCell: number; closedCell: number } || { openCell: 0, closedCell: 0 },
      equipment: (result.equipment as any[]) || [],
      savedEstimates: (result.savedEstimates as any[]) || [],
      customers: (result.customers as any[]) || [],
      purchaseOrders: (result.purchaseOrders as any[]) || [],
      companyProfile: result.companyProfile as any,
      yields: {
        openCell: (yieldsData.openCell as number) || 0,
        closedCell: (yieldsData.closedCell as number) || 0,
        openCellStrokes: (yieldsData.openCellStrokes as number) || 6600,
        closedCellStrokes: (yieldsData.closedCellStrokes as number) || 6600
      },
      costs: {
        openCell: (costsData.openCell as number) || 0,
        closedCell: (costsData.closedCell as number) || 0,
        laborRate: (costsData.laborRate as number) || 85
      },
      expenses: {
        manHours: (expensesData.manHours as number) || 0,
        tripCharge: (expensesData.tripCharge as number) || 0,
        fuelSurcharge: (expensesData.fuelSurcharge as number) || 0,
        other: (expensesData.other as any) || { description: 'Misc', amount: 0 },
        laborRate: (expensesData.laborRate as number)
      } as any,
      jobNotes: settings.jobNotes as string,
      sqFtRates: (settings.sqftRates as any) || { wall: 0, roof: 0 },
      pricingMode: (settings.pricingMode as 'level_pricing' | 'sqft_pricing') || 'level_pricing'
    };
  } catch (error: unknown) {
    console.error('Sync down error:', error);
    return null;
  }
};

/**
 * Sync up - Push all data to server
 */
export const syncUp = async (state: CalculatorState, userId: string): Promise<boolean> => {
  try {
    // Transform app state to database format
    const dbState: Record<string, unknown> = {
      companyProfile: state.companyProfile,
      yields: state.yields,
      costs: state.costs,
      expenses: state.expenses,
      jobNotes: state.jobNotes,
      sqftRates: state.sqFtRates,
      pricingMode: state.pricingMode,
      lifetimeUsage: state.lifetimeUsage,
      warehouse: {
        openCellSets: state.warehouse.openCellSets,
        closedCellSets: state.warehouse.closedCellSets,
        items: state.warehouse.items
      },
      equipment: state.equipment,
      customers: state.customers,
      savedEstimates: state.savedEstimates,
      purchaseOrders: state.purchaseOrders || []
    };

    const { data, error } = await supabase.rpc('rpc_sync_up', {
      p_user_id: userId,
      p_state: dbState
    });

    if (error || !data) {
      console.error('Sync up error:', error);
      return false;
    }

    return true;
  } catch (error: unknown) {
    console.error('Sync up error:', error);
    return false;
  }
};

// ============================================================
// JOB MANAGEMENT SERVICES
// ============================================================

/**
 * Start a job
 */
export const startJob = async (estimateId: string, userId: string): Promise<{ success: boolean; status?: string }> => {
  try {
    const { data, error } = await supabase.rpc('rpc_start_job', {
      p_user_id: userId,
      p_estimate_id: estimateId
    });

    if (error || !data) {
      console.error('Start job error:', error);
      return { success: false };
    }

    const result = data as Record<string, unknown>;
    return {
      success: (result.success as boolean) || false,
      status: result.status as string
    };
  } catch (error: unknown) {
    console.error('Start job error:', error);
    return { success: false };
  }
};

/**
 * Complete a job with actuals
 */
export const completeJob = async (
  estimateId: string,
  actuals: Record<string, unknown>,
  userId: string
): Promise<boolean> => {
  try {
    const { data, error } = await supabase.rpc('rpc_complete_job', {
      p_user_id: userId,
      p_estimate_id: estimateId,
      p_actuals: actuals
    });

    if (error || !data) {
      console.error('Complete job error:', error);
      return false;
    }

    const result = data as Record<string, unknown>;
    return (result.success as boolean) || false;
  } catch (error: unknown) {
    console.error('Complete job error:', error);
    return false;
  }
};

/**
 * Mark job as paid
 */
export const markJobPaid = async (estimateId: string, userId: string): Promise<{ success: boolean; estimate?: EstimateRecord }> => {
  try {
    const { data, error } = await supabase.rpc('rpc_mark_job_paid', {
      p_user_id: userId,
      p_estimate_id: estimateId
    });

    if (error || !data) {
      console.error('Mark job paid error:', error);
      return { success: false };
    }

    const result = data as Record<string, unknown>;
    return {
      success: (result.success as boolean) || false,
      estimate: result.estimate as EstimateRecord
    };
  } catch (error: unknown) {
    console.error('Mark job paid error:', error);
    return { success: false };
  }
};

/**
 * Delete an estimate
 */
export const deleteEstimate = async (estimateId: string, userId: string): Promise<boolean> => {
  try {
    const { data, error } = await supabase.rpc('rpc_delete_estimate', {
      p_user_id: userId,
      p_estimate_id: estimateId
    });

    if (error || !data) {
      console.error('Delete estimate error:', error);
      return false;
    }

    const result = data as Record<string, unknown>;
    return (result.success as boolean) || false;
  } catch (error: unknown) {
    console.error('Delete estimate error:', error);
    return false;
  }
};

/**
 * Log crew time
 */
export const logCrewTime = async (
  estimateId: string,
  userId: string,
  startTime: string,
  endTime: string | null = null
): Promise<boolean> => {
  try {
    const { data, error } = await supabase.rpc('rpc_log_crew_time', {
      p_user_id: userId,
      p_estimate_id: estimateId,
      p_start_time: startTime,
      p_end_time: endTime
    });

    if (error || !data) {
      console.error('Log crew time error:', error);
      return false;
    }

    return true;
  } catch (error: unknown) {
    console.error('Log crew time error:', error);
    return false;
  }
};

// ============================================================
// STORAGE SERVICES
// ============================================================

/**
 * Save PDF to storage
 */
export const savePdfToDrive = async (
  fileName: string,
  base64Data: string,
  estimateId: string | undefined,
  userId: string
): Promise<string | null> => {
  try {
    // Convert base64 to blob
    const byteCharacters = atob(base64Data.split(',')[1] || base64Data);
    const byteNumbers = new Array(byteCharacters.length);
    for (let i = 0; i < byteCharacters.length; i++) {
      byteNumbers[i] = byteCharacters.charCodeAt(i);
    }
    const byteArray = new Uint8Array(byteNumbers);
    const blob = new Blob([byteArray], { type: 'application/pdf' });

    // Upload to storage
    const filePath = `${userId}/estimates/${estimateId || 'draft'}/${fileName}`;
    const { data, error } = await supabase.storage
      .from('estimate-pdfs')
      .upload(filePath, blob, { upsert: true });

    if (error || !data) {
      console.error('PDF upload error:', error);
      return null;
    }

    // Get public URL (or signed URL for private buckets)
    const { data: urlData } = supabase.storage
      .from('estimate-pdfs')
      .getPublicUrl(filePath);

    return urlData?.publicUrl || null;
  } catch (error: unknown) {
    console.error('Save PDF error:', error);
    return null;
  }
};

/**
 * Upload image to storage
 */
export const uploadImage = async (
  base64Data: string,
  userId: string,
  fileName: string = 'image.jpg',
  folder: string = 'site-photos'
): Promise<string | null> => {
  try {
    // Determine MIME type from base64
    const mimeType = base64Data.split(',')[0]?.match(/data:(.*?);/)?.[1] || 'image/jpeg';
    
    // Convert base64 to blob
    const byteCharacters = atob(base64Data.split(',')[1] || base64Data);
    const byteNumbers = new Array(byteCharacters.length);
    for (let i = 0; i < byteCharacters.length; i++) {
      byteNumbers[i] = byteCharacters.charCodeAt(i);
    }
    const byteArray = new Uint8Array(byteNumbers);
    const blob = new Blob([byteArray], { type: mimeType });

    // Upload to storage
    const timestamp = Date.now();
    const filePath = `${userId}/${folder}/${timestamp}_${fileName}`;
    const { data, error } = await supabase.storage
      .from('site-images')
      .upload(filePath, blob, { upsert: true });

    if (error || !data) {
      console.error('Image upload error:', error);
      return null;
    }

    // Get public URL
    const { data: urlData } = supabase.storage
      .from('site-images')
      .getPublicUrl(filePath);

    return urlData?.publicUrl || null;
  } catch (error: unknown) {
    console.error('Upload image error:', error);
    return null;
  }
};

/**
 * Create work order (metadata only - actual sheet creation would be done via Edge Function)
 */
export const createWorkOrderSheet = async (
  estimateData: EstimateRecord,
  userId: string
): Promise<string | null> => {
  // In Supabase, work orders would typically be:
  // 1. Generated as PDFs and stored in storage
  // 2. Or created via Edge Function that integrates with Google Sheets API
  
  // For now, return a placeholder URL
  // In production, implement an Edge Function to create Google Sheets
  return `work-orders/${userId}/${estimateData.id}/work-order`;
};

// ============================================================
// TRIAL MEMBERSHIP SERVICE
// ============================================================

/**
 * Submit trial membership
 */
export const submitTrial = async (name: string, email: string, phone: string): Promise<boolean> => {
  try {
    const { data, error } = await supabase.rpc('rpc_submit_trial', {
      p_name: name,
      p_email: email,
      p_phone: phone
    });

    if (error || !data) {
      console.error('Submit trial error:', error);
      return false;
    }

    return true;
  } catch (error: unknown) {
    console.error('Submit trial error:', error);
    return false;
  }
};

// ============================================================
// ANALYTICS SERVICES
// ============================================================

/**
 * Get P&L summary
 */
export const getPnlSummary = async (
  userId: string,
  startDate?: string,
  endDate?: string
): Promise<Record<string, unknown> | null> => {
  try {
    const { data, error } = await supabase.rpc('rpc_get_pnl_summary', {
      p_user_id: userId,
      p_start_date: startDate,
      p_end_date: endDate
    });

    if (error || !data) {
      console.error('Get P&L summary error:', error);
      return null;
    }

    const result = data as Record<string, unknown>;
    return result.summary as Record<string, unknown> || null;
  } catch (error: unknown) {
    console.error('Get P&L summary error:', error);
    return null;
  }
};

/**
 * Get dashboard statistics
 */
export const getDashboardStats = async (userId: string): Promise<Record<string, unknown> | null> => {
  try {
    const { data, error } = await supabase.rpc('rpc_get_dashboard_stats', {
      p_user_id: userId
    });

    if (error || !data) {
      console.error('Get dashboard stats error:', error);
      return null;
    }

    const result = data as Record<string, unknown>;
    return result.stats as Record<string, unknown> || null;
  } catch (error: unknown) {
    console.error('Get dashboard stats error:', error);
    return null;
  }
};

// ============================================================
// REALTIME SUBSCRIPTIONS
// ============================================================

/**
 * Subscribe to estimate changes
 */
export const subscribeToEstimates = (
  userId: string,
  callback: (estimate: EstimateRecord) => void
): (() => void) => {
  const channel = supabase
    .channel(`estimates:${userId}`)
    .on(
      'postgres_changes',
      {
        event: '*',
        schema: 'public',
        table: 'estimates',
        filter: `user_id=eq.${userId}`
      },
      (payload) => {
        callback(payload.new as unknown as EstimateRecord);
      }
    )
    .subscribe();

  return () => {
    supabase.removeChannel(channel);
  };
};

/**
 * Subscribe to inventory changes
 */
export const subscribeToInventory = (
  userId: string,
  callback: (item: InventoryItem) => void
): (() => void) => {
  const channel = supabase
    .channel(`inventory:${userId}`)
    .on(
      'postgres_changes',
      {
        event: '*',
        schema: 'public',
        table: 'inventory_items',
        filter: `user_id=eq.${userId}`
      },
      (payload) => {
        callback(payload.new as unknown as InventoryItem);
      }
    )
    .subscribe();

  return () => {
    supabase.removeChannel(channel);
  };
};

// ============================================================
// DIRECT TABLE OPERATIONS (for fine-grained control)
// ============================================================

/**
 * Get all customers for a user
 */
export const getCustomers = async (userId: string): Promise<CustomerProfile[]> => {
  const { data, error } = await supabase
    .from('customers')
    .select('*')
    .eq('user_id', userId)
    .order('name');

  if (error) {
    console.error('Get customers error:', error);
    return [];
  }

  return (data as CustomerProfile[]) || [];
};

/**
 * Create a new customer
 */
export const createCustomer = async (customer: Omit<CustomerProfile, 'id' | 'created_at' | 'updated_at'>): Promise<CustomerProfile | null> => {
  const { data, error } = await supabase
    .from('customers')
    .insert(customer)
    .select()
    .single();

  if (error) {
    console.error('Create customer error:', error);
    return null;
  }

  return data as CustomerProfile;
};

/**
 * Update a customer
 */
export const updateCustomer = async (
  id: string,
  updates: Partial<CustomerProfile>
): Promise<boolean> => {
  const { error } = await supabase
    .from('customers')
    .update({ ...updates, updated_at: new Date().toISOString() })
    .eq('id', id);

  return !error;
};

/**
 * Delete a customer
 */
export const deleteCustomer = async (id: string): Promise<boolean> => {
  const { error } = await supabase
    .from('customers')
    .delete()
    .eq('id', id);

  return !error;
};

/**
 * Get all estimates for a user
 */
export const getEstimates = async (userId: string): Promise<EstimateRecord[]> => {
  const { data, error } = await supabase
    .from('estimates')
    .select('*')
    .eq('user_id', userId)
    .order('date', { ascending: false });

  if (error) {
    console.error('Get estimates error:', error);
    return [];
  }

  // Transform database records to EstimateRecord format
  return (data as unknown[])?.map((record: Record<string, unknown>) => ({
    id: record.id as string,
    customerId: record.customer_id as string,
    date: record.date as string,
    customer: {} as CustomerProfile, // Will need to be populated separately
    status: record.status as EstimateRecord['status'],
    executionStatus: record.execution_status as EstimateRecord['executionStatus'],
    inputs: record.inputs_json as EstimateRecord['inputs'],
    results: record.results_json as EstimateRecord['results'],
    materials: record.materials_json as EstimateRecord['materials'],
    totalValue: record.total_value as number,
    wallSettings: record.wall_settings_json as EstimateRecord['wallSettings'],
    roofSettings: record.roof_settings_json as EstimateRecord['roofSettings'],
    expenses: record.expenses_json as EstimateRecord['expenses'],
    notes: record.notes as string,
    pricingMode: record.pricing_mode as EstimateRecord['pricingMode'],
    sqFtRates: record.sqft_rates_json as EstimateRecord['sqFtRates'],
    scheduledDate: record.scheduled_date as string,
    invoiceDate: record.invoice_date as string,
    invoiceNumber: record.invoice_number as string,
    paymentTerms: record.payment_terms as string,
    actuals: record.actuals_json as EstimateRecord['actuals'],
    financials: record.financials_json as EstimateRecord['financials'],
    workOrderSheetUrl: record.work_order_sheet_url as string,
    pdfLink: record.pdf_link as string,
    sitePhotos: record.site_photos as string[],
    inventoryProcessed: record.inventory_processed as boolean,
    lastModified: record.updated_at as string
  })) || [];
};

/**
 * Get app settings for a user
 */
export const getAppSettings = async (userId: string): Promise<Record<string, unknown> | null> => {
  const { data, error } = await supabase
    .from('app_settings')
    .select('*')
    .eq('user_id', userId)
    .single();

  if (error) {
    console.error('Get app settings error:', error);
    return null;
  }

  return {
    yields: data.yields_json,
    costs: data.costs_json,
    expenses: data.expenses_json,
    jobNotes: data.job_notes,
    sqftRates: data.sqft_rates_json,
    pricingMode: data.pricing_mode
  };
};

/**
 * Get warehouse counts for a user
 */
export const getWarehouseCounts = async (userId: string): Promise<{ openCellSets: number; closedCellSets: number } | null> => {
  const { data, error } = await supabase
    .from('warehouse_counts')
    .select('open_cell_sets, closed_cell_sets')
    .eq('user_id', userId)
    .single();

  if (error) {
    console.error('Get warehouse counts error:', error);
    return null;
  }

  return {
    openCellSets: data.open_cell_sets,
    closedCellSets: data.closed_cell_sets
  };
};

/**
 * Get lifetime usage for a user
 */
export const getLifetimeUsage = async (userId: string): Promise<{ openCell: number; closedCell: number } | null> => {
  const { data, error } = await supabase
    .from('lifetime_usage')
    .select('open_cell, closed_cell')
    .eq('user_id', userId)
    .single();

  if (error) {
    console.error('Get lifetime usage error:', error);
    return null;
  }

  return {
    openCell: data.open_cell,
    closedCell: data.closed_cell
  };
};

/**
 * Get company profile for a user
 */
export const getCompanyProfile = async (userId: string): Promise<import('../types').CompanyProfile | null> => {
  const { data, error } = await supabase
    .from('company_profiles')
    .select('*')
    .eq('user_id', userId)
    .single();

  if (error) {
    console.error('Get company profile error:', error);
    return null;
  }

  return {
    companyName: data.company_name,
    addressLine1: data.address_line1 || '',
    addressLine2: data.address_line2 || '',
    city: data.city || '',
    state: data.state || '',
    zip: data.zip || '',
    phone: data.phone || '',
    email: data.email || '',
    website: data.website || '',
    logoUrl: data.logo_url || '',
    crewAccessPin: data.crew_access_pin || ''
  };
};
