-- ============================================================
-- SUPABASE RPC FUNCTIONS - FIXED VERSION
-- Spray Foam Insulation Business Management Tool
-- ============================================================

-- Create secret salt config if not exists
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_settings WHERE name = 'app.secret_salt') THEN
        EXECUTE 'ALTER DATABASE postgres SET app.secret_salt = ''foam-pro-secret-salt-2024''';
    END IF;
END $$;

-- ============================================================
-- 1. RPC LOGIN
-- ============================================================

CREATE OR REPLACE FUNCTION public.rpc_login(
    p_username TEXT,
    p_password TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_user RECORD;
    v_password_hash TEXT;
BEGIN
    SELECT * INTO v_user
    FROM public.users
    WHERE username = p_username;

    IF v_user IS NULL THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'message', 'Invalid username or password'
        );
    END IF;

    IF v_user.password_hash IS NOT NULL THEN
        v_password_hash := encode(digest(p_password || current_setting('app.secret_salt', TRUE), 'sha256'), 'base64');

        IF v_password_hash != v_user.password_hash THEN
            RETURN jsonb_build_object(
                'success', FALSE,
                'message', 'Invalid username or password'
            );
        END IF;
    END IF;

    RETURN jsonb_build_object(
        'success', TRUE,
        'data', jsonb_build_object(
            'username', v_user.username,
            'companyName', v_user.company_name,
            'spreadsheetId', v_user.spreadsheet_id,
            'folderId', v_user.folder_id,
            'role', v_user.role,
            'userId', v_user.id,
            'token', encode(digest(v_user.username || v_user.role || EXTRACT(EPOCH FROM NOW())::TEXT, 'sha256'), 'base64')
        )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 2. RPC SIGNUP
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
    IF EXISTS (SELECT 1 FROM public.users WHERE username = p_username) THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'message', 'Username already taken'
        );
    END IF;

    v_crew_code := LPAD(FLOOR(RANDOM() * 9000 + 1000)::TEXT, 4, '0');
    v_password_hash := encode(digest(p_password || current_setting('app.secret_salt', TRUE), 'sha256'), 'base64');

    INSERT INTO public.users (username, password_hash, company_name, email, role, crew_code)
    VALUES (p_username, v_password_hash, p_company_name, COALESCE(p_email, p_username || '@example.com'), 'admin', v_crew_code)
    RETURNING id INTO v_user_id;

    INSERT INTO public.app_settings (user_id) VALUES (v_user_id) ON CONFLICT (user_id) DO NOTHING;
    INSERT INTO public.warehouse_counts (user_id) VALUES (v_user_id) ON CONFLICT (user_id) DO NOTHING;
    INSERT INTO public.lifetime_usage (user_id) VALUES (v_user_id) ON CONFLICT (user_id) DO NOTHING;
    INSERT INTO public.company_profiles (user_id, company_name, crew_access_pin)
    VALUES (v_user_id, p_company_name, v_crew_code) ON CONFLICT (user_id) DO NOTHING;

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
            'token', encode(digest(p_username || 'admin' || EXTRACT(EPOCH FROM NOW())::TEXT, 'sha256'), 'base64')
        )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 3. RPC CREW LOGIN
-- ============================================================

CREATE OR REPLACE FUNCTION public.rpc_crew_login(
    p_username TEXT,
    p_pin TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_user RECORD;
    v_company_name TEXT;
BEGIN
    SELECT u.*, cp.company_name INTO v_user
    FROM public.users u
    LEFT JOIN public.company_profiles cp ON cp.user_id = u.id
    WHERE u.crew_code = p_pin;

    IF v_user IS NULL THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'message', 'Invalid crew code'
        );
    END IF;

    RETURN jsonb_build_object(
        'success', TRUE,
        'data', jsonb_build_object(
            'username', v_user.username,
            'companyName', COALESCE(v_user.company_name, v_user.company_name),
            'spreadsheetId', v_user.spreadsheet_id,
            'folderId', v_user.folder_id,
            'role', v_user.role,
            'userId', v_user.id,
            'crewCode', v_user.crew_code,
            'token', encode(digest(v_user.username || v_user.role || EXTRACT(EPOCH FROM NOW())::TEXT, 'sha256'), 'base64')
        )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- GRANT PERMISSIONS
-- ============================================================

GRANT EXECUTE ON FUNCTION public.rpc_login TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.rpc_signup TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.rpc_crew_login TO authenticated, anon;
