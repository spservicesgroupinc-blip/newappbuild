
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

-- ============================================================
-- SUPABASE RPC FUNCTIONS
-- Replicate Google Apps Script API Endpoints
-- ============================================================

-- ============================================================
-- 1. LOGIN RPC
-- ============================================================

CREATE OR REPLACE FUNCTION public.rpc_login(
    p_username TEXT,
    p_password TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_user RECORD;
    v_password_hash TEXT;
    v_token TEXT;
BEGIN
    -- Find user by username
    SELECT * INTO v_user
    FROM public.users
    WHERE username = p_username;
    
    IF v_user IS NULL THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'message', 'Invalid username or password'
        );
    END IF;
    
    -- Verify password (for legacy migrated users with password_hash)
    -- Note: New users should use Supabase Auth directly
    IF v_user.password_hash IS NOT NULL THEN
        -- Compare hashed passwords
        -- This assumes the same hashing algorithm was used during migration
        v_password_hash := encode(digest(p_password || current_setting('app.secret_salt', TRUE), 'sha256'), 'base64');
        
        IF v_password_hash != v_user.password_hash THEN
            RETURN jsonb_build_object(
                'success', FALSE,
                'message', 'Invalid username or password'
            );
        END IF;
    END IF;
    
    -- Generate a session token (for legacy compatibility)
    -- For new implementations, use Supabase Auth sessions directly
    v_token := encode(digest(v_user.username || v_user.role || EXTRACT(EPOCH FROM NOW())::TEXT, 'sha256'), 'base64');
    
    RETURN jsonb_build_object(
        'success', TRUE,
        'data', jsonb_build_object(
            'username', v_user.username,
            'companyName', v_user.company_name,
            'spreadsheetId', v_user.spreadsheet_id,
            'folderId', v_user.folder_id,
            'role', v_user.role,
            'userId', v_user.id,
            'authUserId', v_user.auth_user_id,
            'token', v_token
        )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 2. SIGNUP RPC
-- ============================================================

CREATE OR REPLACE FUNCTION public.rpc_signup(
    p_username TEXT,
    p_password TEXT,
    p_company_name TEXT,
    p_email TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID;
    v_crew_code TEXT;
    v_password_hash TEXT;
BEGIN
    -- Check if username already exists
    IF EXISTS (SELECT 1 FROM public.users WHERE username = p_username) THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'message', 'Username already taken'
        );
    END IF;
    
    -- Generate crew code (4-digit PIN)
    v_crew_code := LPAD(FLOOR(RANDOM() * 9000 + 1000)::TEXT, 4, '0');
    
    -- Hash password for legacy compatibility
    v_password_hash := encode(digest(p_password || current_setting('app.secret_salt', TRUE), 'sha256'), 'base64');
    
    -- Create user record
    INSERT INTO public.users (
        username, password_hash, company_name, email, role, crew_code
    )
    VALUES (
        p_username,
        v_password_hash,
        p_company_name,
        COALESCE(p_email, p_username || '@example.com'),
        'admin',
        v_crew_code
    )
    RETURNING id INTO v_user_id;
    
    -- Create default app settings
    INSERT INTO public.app_settings (user_id)
    VALUES (v_user_id)
    ON CONFLICT (user_id) DO NOTHING;
    
    -- Create default warehouse counts
    INSERT INTO public.warehouse_counts (user_id)
    VALUES (v_user_id)
    ON CONFLICT (user_id) DO NOTHING;
    
    -- Create default lifetime usage
    INSERT INTO public.lifetime_usage (user_id)
    VALUES (v_user_id)
    ON CONFLICT (user_id) DO NOTHING;
    
    -- Create company profile
    INSERT INTO public.company_profiles (user_id, company_name, crew_access_pin)
    VALUES (v_user_id, p_company_name, v_crew_code)
    ON CONFLICT (user_id) DO NOTHING;
    
    -- Generate token
    DECLARE
        v_token TEXT;
    BEGIN
        v_token := encode(digest(p_username || 'admin' || EXTRACT(EPOCH FROM NOW())::TEXT, 'sha256'), 'base64');
        
        RETURN jsonb_build_object(
            'success', TRUE,
            'data', jsonb_build_object(
                'username', p_username,
                'companyName', p_company_name,
                'spreadsheetId', NULL,
                'folderId', NULL,
                'role', 'admin',
                'userId', v_user_id,
                'crewCode', v_crew_code,
                'token', v_token
            )
        );
    END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 3. CREW LOGIN RPC
-- ============================================================

CREATE OR REPLACE FUNCTION public.rpc_crew_login(
    p_username TEXT,
    p_pin TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_user RECORD;
    v_company RECORD;
BEGIN
    -- Find user by crew_code (PIN)
    SELECT u.*, cp.company_name INTO v_user, v_company
    FROM public.users u
    LEFT JOIN public.company_profiles cp ON cp.user_id = u.id
    WHERE u.crew_code = p_pin;
    
    IF v_user IS NULL THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'message', 'Invalid crew code'
        );
    END IF;
    
    -- Generate token
    DECLARE
        v_token TEXT;
    BEGIN
        v_token := encode(digest(v_user.username || v_user.role || EXTRACT(EPOCH FROM NOW())::TEXT, 'sha256'), 'base64');
        
        RETURN jsonb_build_object(
            'success', TRUE,
            'data', jsonb_build_object(
                'username', v_user.username,
                'companyName', COALESCE(v_company.company_name, v_user.company_name),
                'spreadsheetId', v_user.spreadsheet_id,
                'folderId', v_user.folder_id,
                'role', v_user.role,
                'userId', v_user.id,
                'crewCode', v_user.crew_code,
                'token', v_token
            )
        );
    END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 4. SYNC DOWN RPC
-- ============================================================

CREATE OR REPLACE FUNCTION public.rpc_sync_down(
    p_user_id UUID,
    p_last_sync_timestamp BIGINT DEFAULT 0
)
RETURNS JSONB AS $$
DECLARE
    v_timestamp TIMESTAMPTZ;
BEGIN
    -- Convert milliseconds to timestamp if provided
    IF p_last_sync_timestamp > 0 THEN
        v_timestamp := TO_TIMESTAMP(p_last_sync_timestamp / 1000.0);
    ELSE
        v_timestamp := '1970-01-01'::TIMESTAMPTZ;
    END IF;
    
    RETURN public.sync_down(p_user_id, v_timestamp);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 5. SYNC UP RPC
-- ============================================================

CREATE OR REPLACE FUNCTION public.rpc_sync_up(
    p_user_id UUID,
    p_state JSONB
)
RETURNS JSONB AS $$
BEGIN
    RETURN public.sync_up(p_user_id, p_state);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 6. COMPLETE JOB RPC
-- ============================================================

CREATE OR REPLACE FUNCTION public.rpc_complete_job(
    p_user_id UUID,
    p_estimate_id UUID,
    p_actuals JSONB
)
RETURNS JSONB AS $$
DECLARE
    v_success BOOLEAN;
BEGIN
    v_success := public.reconcile_inventory_on_completion(p_estimate_id, p_user_id, p_actuals);
    
    RETURN jsonb_build_object(
        'success', v_success,
        'message', CASE WHEN v_success THEN 'Job completed successfully' ELSE 'Job completion failed' END
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 7. MARK JOB PAID RPC
-- ============================================================

CREATE OR REPLACE FUNCTION public.rpc_mark_job_paid(
    p_user_id UUID,
    p_estimate_id UUID
)
RETURNS JSONB AS $$
BEGIN
    RETURN public.mark_job_as_paid(p_estimate_id, p_user_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 8. START JOB RPC
-- ============================================================

CREATE OR REPLACE FUNCTION public.rpc_start_job(
    p_user_id UUID,
    p_estimate_id UUID
)
RETURNS JSONB AS $$
BEGIN
    RETURN public.start_job(p_estimate_id, p_user_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 9. DELETE ESTIMATE RPC
-- ============================================================

CREATE OR REPLACE FUNCTION public.rpc_delete_estimate(
    p_user_id UUID,
    p_estimate_id UUID
)
RETURNS JSONB AS $$
DECLARE
    v_success BOOLEAN;
BEGIN
    v_success := public.delete_estimate(p_estimate_id, p_user_id);
    
    RETURN jsonb_build_object(
        'success', v_success,
        'message', CASE WHEN v_success THEN 'Estimate deleted successfully' ELSE 'Estimate not found or access denied' END
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 10. LOG CREW TIME RPC
-- ============================================================

CREATE OR REPLACE FUNCTION public.rpc_log_crew_time(
    p_user_id UUID,
    p_estimate_id UUID,
    p_start_time TIMESTAMPTZ,
    p_end_time TIMESTAMPTZ DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_log_id UUID;
BEGIN
    v_log_id := public.log_crew_time(p_estimate_id, p_user_id, p_start_time, p_end_time);
    
    RETURN jsonb_build_object(
        'success', TRUE,
        'logId', v_log_id
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 11. SUBMIT TRIAL RPC
-- ============================================================

CREATE OR REPLACE FUNCTION public.rpc_submit_trial(
    p_name TEXT,
    p_email TEXT,
    p_phone TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_trial_id UUID;
BEGIN
    INSERT INTO public.trial_memberships (name, email, phone)
    VALUES (p_name, p_email, p_phone)
    RETURNING id INTO v_trial_id;
    
    RETURN jsonb_build_object(
        'success', TRUE,
        'trialId', v_trial_id
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 12. GET USER BY CREW CODE RPC
-- ============================================================

CREATE OR REPLACE FUNCTION public.rpc_get_user_by_crew_code(
    p_crew_code TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID;
    v_user RECORD;
BEGIN
    SELECT * INTO v_user
    FROM public.users
    WHERE crew_code = p_crew_code;
    
    IF v_user IS NULL THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'message', 'Crew code not found'
        );
    END IF;
    
    RETURN jsonb_build_object(
        'success', TRUE,
        'data', jsonb_build_object(
            'userId', v_user.id,
            'username', v_user.username,
            'companyName', v_user.company_name,
            'role', v_user.role
        )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 13. GET USER BY USERNAME RPC
-- ============================================================

CREATE OR REPLACE FUNCTION public.rpc_get_user_by_username(
    p_username TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID;
    v_user RECORD;
BEGIN
    SELECT * INTO v_user
    FROM public.users
    WHERE username = p_username;
    
    IF v_user IS NULL THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'message', 'User not found'
        );
    END IF;
    
    RETURN jsonb_build_object(
        'success', TRUE,
        'data', jsonb_build_object(
            'userId', v_user.id,
            'authUserId', v_user.auth_user_id,
            'username', v_user.username,
            'companyName', v_user.company_name,
            'role', v_user.role,
            'email', v_user.email
        )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 14. UPDATE PASSWORD RPC
-- ============================================================

CREATE OR REPLACE FUNCTION public.rpc_update_password(
    p_user_id UUID,
    p_new_password TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_password_hash TEXT;
BEGIN
    -- Hash new password
    v_password_hash := encode(digest(p_new_password || current_setting('app.secret_salt', TRUE), 'sha256'), 'base64');
    
    UPDATE public.users
    SET password_hash = v_password_hash,
        updated_at = NOW()
    WHERE id = p_user_id;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'message', 'User not found'
        );
    END IF;
    
    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Password updated successfully'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 15. GET P&L SUMMARY RPC
-- ============================================================

CREATE OR REPLACE FUNCTION public.rpc_get_pnl_summary(
    p_user_id UUID,
    p_start_date DATE DEFAULT NULL,
    p_end_date DATE DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_summary JSONB;
BEGIN
    SELECT jsonb_build_object(
        'totalRevenue', COALESCE(SUM(revenue), 0),
        'totalCOGS', COALESCE(SUM(total_cogs), 0),
        'totalProfit', COALESCE(SUM(net_profit), 0),
        'averageMargin', COALESCE(AVG(margin), 0),
        'jobCount', COUNT(*)
    ) INTO v_summary
    FROM public.profit_loss_records
    WHERE user_id = p_user_id
      AND (p_start_date IS NULL OR recorded_at >= p_start_date)
      AND (p_end_date IS NULL OR recorded_at <= p_end_date);
    
    RETURN jsonb_build_object(
        'success', TRUE,
        'summary', v_summary
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 16. GET DASHBOARD STATS RPC
-- ============================================================

CREATE OR REPLACE FUNCTION public.rpc_get_dashboard_stats(
    p_user_id UUID
)
RETURNS JSONB AS $$
DECLARE
    v_stats JSONB;
BEGIN
    SELECT jsonb_build_object(
        'totalEstimates', (SELECT COUNT(*) FROM public.estimates WHERE user_id = p_user_id),
        'draftEstimates', (SELECT COUNT(*) FROM public.estimates WHERE user_id = p_user_id AND status = 'Draft'),
        'completedJobs', (SELECT COUNT(*) FROM public.estimates WHERE user_id = p_user_id AND execution_status = 'Completed'),
        'paidJobs', (SELECT COUNT(*) FROM public.estimates WHERE user_id = p_user_id AND status = 'Paid'),
        'totalCustomers', (SELECT COUNT(*) FROM public.customers WHERE user_id = p_user_id),
        'inventoryItems', (SELECT COUNT(*) FROM public.inventory_items WHERE user_id = p_user_id),
        'equipmentItems', (SELECT COUNT(*) FROM public.equipment_items WHERE user_id = p_user_id),
        'openCellSets', (SELECT COALESCE(open_cell_sets, 0) FROM public.warehouse_counts WHERE user_id = p_user_id),
        'closedCellSets', (SELECT COALESCE(closed_cell_sets, 0) FROM public.warehouse_counts WHERE user_id = p_user_id),
        'lifetimeOpenCell', (SELECT COALESCE(open_cell, 0) FROM public.lifetime_usage WHERE user_id = p_user_id),
        'lifetimeClosedCell', (SELECT COALESCE(closed_cell, 0) FROM public.lifetime_usage WHERE user_id = p_user_id)
    ) INTO v_stats;
    
    RETURN jsonb_build_object(
        'success', TRUE,
        'stats', v_stats
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- GRANT EXECUTE PERMISSIONS ON RPC FUNCTIONS
-- ============================================================

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION public.rpc_login TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.rpc_signup TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.rpc_crew_login TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.rpc_sync_down TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_sync_up TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_complete_job TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_mark_job_paid TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_start_job TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_delete_estimate TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_log_crew_time TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_submit_trial TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.rpc_get_user_by_crew_code TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.rpc_get_user_by_username TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_update_password TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_get_pnl_summary TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_get_dashboard_stats TO authenticated;

