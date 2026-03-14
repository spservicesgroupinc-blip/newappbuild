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
// AUTHENTICATION SERVICES
// ============================================================

/**
 * Login with email and password
 * Uses RPC login for database-authenticated users
 */
export const loginUser = async (email: string, password: string): Promise<UserSession | null> => {
  try {
    // Try RPC login first (for users created via rpc_signup)
    const { data, error } = await supabase.rpc('rpc_login', {
      p_username: email,
      p_password: password
    });

    if (error) {
      console.error('RPC login error:', error);
      throw new Error(error.message || 'Login failed');
    }

    if (!data || !(data as Record<string, unknown>).success) {
      const message = (data as Record<string, unknown>)?.message as string || 'Login failed';
      throw new Error(message);
    }

    const result = data as Record<string, unknown>;
    const userData = result.data as Record<string, unknown>;

    return {
      username: userData.username as string,
      companyName: userData.companyName as string,
      spreadsheetId: (userData.spreadsheetId as string) || '',
      folderId: (userData.folderId as string) || '',
      role: (userData.role as 'admin' | 'crew') || 'admin',
      token: userData.token as string
    };
  } catch (error: unknown) {
    console.error('Login error:', error);
    throw error;
  }
};

/**
 * Signup with email, password, and company name
 * Uses RPC signup for immediate access (bypasses email confirmation)
 */
export const signupUser = async (
  email: string,
  password: string,
  companyName: string,
  username?: string
): Promise<UserSession | null> => {
  try {
    // Use RPC signup - creates user directly in database
    const { data, error } = await supabase.rpc('rpc_signup', {
      p_username: email,
      p_password: password,
      p_company_name: companyName,
      p_email: username || email
    });

    if (error) {
      console.error('RPC signup error:', error);
      throw new Error(error.message || 'Signup failed');
    }

    if (!data || !(data as Record<string, unknown>).success) {
      const message = (data as Record<string, unknown>)?.message as string || 'Signup failed';
      throw new Error(message);
    }

    const result = data as Record<string, unknown>;
    const userData = result.data as Record<string, unknown>;

    // Return session with RPC-generated token
    return {
      username: userData.username as string,
      companyName: userData.companyName as string,
      spreadsheetId: (userData.spreadsheetId as string) || '',
      folderId: (userData.folderId as string) || '',
      role: (userData.role as 'admin' | 'crew') || 'admin',
      token: userData.token as string
    };
  } catch (error: unknown) {
    console.error('Signup error:', error);
    throw error;
  }
};

/**
 * Crew login with PIN
 */
export const loginCrew = async (username: string, pin: string): Promise<UserSession | null> => {
  try {
    const { data, error } = await supabase.rpc('rpc_crew_login', {
      p_username: username,
      p_pin: pin
    });

    if (error || !data || !(data as Record<string, unknown>).success) {
      throw new Error((data as Record<string, unknown>)?.message as string || 'Crew login failed');
    }

    const result = data as Record<string, unknown>;
    const userData = result.data as Record<string, unknown>;

    return {
      username: userData.username as string,
      companyName: userData.companyName as string,
      spreadsheetId: (userData.spreadsheetId as string) || '',
      folderId: (userData.folderId as string) || '',
      role: (userData.role as 'admin' | 'crew') || 'crew',
      token: userData.token as string
    };
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
 * Get current session
 */
export const getCurrentSession = async (): Promise<UserSession | null> => {
  const { data: { session } } = await supabase.auth.getSession();

  if (!session?.user) {
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
