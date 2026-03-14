-- ============================================================
-- SUPABASE MIGRATION SCRIPT
-- Spray Foam Insulation Business Management Tool
-- Migration from Google Apps Script Backend
-- ============================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================
-- 1. ENUM TYPES
-- ============================================================

-- User roles
CREATE TYPE user_role AS ENUM ('admin', 'crew');

-- Customer status
CREATE TYPE customer_status AS ENUM ('Active', 'Archived', 'Lead');

-- Estimate status
CREATE TYPE estimate_status AS ENUM ('Draft', 'Work Order', 'Invoiced', 'Paid', 'Archived');

-- Estimate execution status
CREATE TYPE estimate_execution_status AS ENUM ('Not Started', 'In Progress', 'Completed');

-- Inventory unit types
CREATE TYPE inventory_unit AS ENUM ('Sets', 'Gallons', 'Pounds', 'Feet', 'Pieces', 'Boxes', 'Each');

-- Equipment status
CREATE TYPE equipment_status AS ENUM ('Available', 'In Use', 'Maintenance', 'Lost');

-- Purchase order status
CREATE TYPE purchase_order_status AS ENUM ('Draft', 'Sent', 'Received', 'Cancelled');

-- Pricing mode
CREATE TYPE pricing_mode_type AS ENUM ('level_pricing', 'sqft_pricing');

-- ============================================================
-- 2. CORE TABLES
-- ============================================================

-- Users table (extends Supabase auth.users via metadata)
CREATE TABLE public.users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    auth_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT UNIQUE NOT NULL,
    password_hash TEXT, -- For legacy migration, new users use Supabase Auth
    company_name TEXT NOT NULL,
    spreadsheet_id TEXT, -- Legacy Google Sheets ID for migration
    folder_id TEXT, -- Legacy Google Drive folder ID
    crew_code TEXT UNIQUE, -- 4-digit PIN for crew login
    email TEXT,
    role user_role DEFAULT 'admin',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Company profiles
CREATE TABLE public.company_profiles (
    user_id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    company_name TEXT NOT NULL,
    address_line1 TEXT,
    address_line2 TEXT,
    city TEXT,
    state TEXT,
    zip TEXT,
    phone TEXT,
    email TEXT,
    website TEXT,
    logo_url TEXT,
    crew_access_pin TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Customers
CREATE TABLE public.customers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    address TEXT,
    city TEXT,
    state TEXT,
    zip TEXT,
    phone TEXT,
    email TEXT,
    status customer_status DEFAULT 'Active',
    notes TEXT,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Estimates (main job records)
CREATE TABLE public.estimates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    date DATE NOT NULL DEFAULT CURRENT_DATE,
    customer_id UUID NOT NULL REFERENCES public.customers(id) ON DELETE CASCADE,
    total_value NUMERIC(12, 2) DEFAULT 0,
    status estimate_status DEFAULT 'Draft',
    execution_status estimate_execution_status DEFAULT 'Not Started',
    invoice_number TEXT,
    pdf_link TEXT,
    work_order_sheet_url TEXT,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    
    -- JSON fields for complex data
    inputs_json JSONB DEFAULT '{}'::jsonb,
    results_json JSONB DEFAULT '{}'::jsonb,
    materials_json JSONB DEFAULT '{}'::jsonb,
    wall_settings_json JSONB DEFAULT '{}'::jsonb,
    roof_settings_json JSONB DEFAULT '{}'::jsonb,
    expenses_json JSONB DEFAULT '{}'::jsonb,
    actuals_json JSONB DEFAULT '{}'::jsonb,
    financials_json JSONB DEFAULT '{}'::jsonb,
    sqft_rates_json JSONB DEFAULT '{}'::jsonb,
    
    notes TEXT,
    pricing_mode pricing_mode_type DEFAULT 'level_pricing',
    
    scheduled_date DATE,
    invoice_date DATE,
    payment_terms TEXT,
    
    inventory_processed BOOLEAN DEFAULT FALSE,
    site_photos TEXT[] DEFAULT '{}',
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Inventory items
CREATE TABLE public.inventory_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    quantity NUMERIC(10, 2) DEFAULT 0,
    unit inventory_unit DEFAULT 'Each',
    unit_cost NUMERIC(10, 2) DEFAULT 0,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Equipment items
CREATE TABLE public.equipment_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    status equipment_status DEFAULT 'Available',
    last_seen_json JSONB DEFAULT '{}'::jsonb,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Warehouse counts (foam sets tracking)
CREATE TABLE public.warehouse_counts (
    user_id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    open_cell_sets NUMERIC(10, 2) DEFAULT 0,
    closed_cell_sets NUMERIC(10, 2) DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Lifetime usage tracking
CREATE TABLE public.lifetime_usage (
    user_id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    open_cell NUMERIC(10, 2) DEFAULT 0,
    closed_cell NUMERIC(10, 2) DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Material logs
CREATE TABLE public.material_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    job_id UUID REFERENCES public.estimates(id) ON DELETE SET NULL,
    customer_name TEXT NOT NULL,
    material_name TEXT NOT NULL,
    quantity NUMERIC(10, 2) NOT NULL,
    unit TEXT NOT NULL,
    logged_by TEXT NOT NULL,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Purchase orders
CREATE TABLE public.purchase_orders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    date DATE NOT NULL DEFAULT CURRENT_DATE,
    vendor_name TEXT NOT NULL,
    status purchase_order_status DEFAULT 'Draft',
    items_json JSONB DEFAULT '[]'::jsonb,
    total_cost NUMERIC(12, 2) DEFAULT 0,
    notes TEXT,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- App settings (per user)
CREATE TABLE public.app_settings (
    user_id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    yields_json JSONB DEFAULT '{"openCell": 0, "closedCell": 0, "openCellStrokes": 0, "closedCellStrokes": 0}'::jsonb,
    costs_json JSONB DEFAULT '{"openCell": 0, "closedCell": 0, "laborRate": 0}'::jsonb,
    expenses_json JSONB DEFAULT '{}'::jsonb,
    job_notes TEXT,
    sqft_rates_json JSONB DEFAULT '{"wall": 0, "roof": 0}'::jsonb,
    pricing_mode pricing_mode_type DEFAULT 'level_pricing',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Trial memberships (leads)
CREATE TABLE public.trial_memberships (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    email TEXT NOT NULL,
    phone TEXT,
    submitted_at TIMESTAMPTZ DEFAULT NOW()
);

-- Profit & Loss records (auto-generated)
CREATE TABLE public.profit_loss_records (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    estimate_id UUID REFERENCES public.estimates(id) ON DELETE SET NULL,
    recorded_at TIMESTAMPTZ DEFAULT NOW(),
    customer_name TEXT,
    invoice_number TEXT,
    revenue NUMERIC(12, 2) DEFAULT 0,
    chemical_cost NUMERIC(12, 2) DEFAULT 0,
    labor_cost NUMERIC(12, 2) DEFAULT 0,
    inventory_cost NUMERIC(12, 2) DEFAULT 0,
    misc_cost NUMERIC(12, 2) DEFAULT 0,
    total_cogs NUMERIC(12, 2) DEFAULT 0,
    net_profit NUMERIC(12, 2) DEFAULT 0,
    margin NUMERIC(5, 4) DEFAULT 0, -- Decimal 0-1
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE
);

-- Crew time logs
CREATE TABLE public.crew_time_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    estimate_id UUID REFERENCES public.estimates(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 3. INDEXES FOR PERFORMANCE
-- ============================================================

-- Users
CREATE INDEX idx_users_username ON public.users(username);
CREATE INDEX idx_users_auth_user_id ON public.users(auth_user_id);
CREATE INDEX idx_users_crew_code ON public.users(crew_code);

-- Customers
CREATE INDEX idx_customers_user_id ON public.customers(user_id);
CREATE INDEX idx_customers_name ON public.customers(name);
CREATE INDEX idx_customers_status ON public.customers(status);

-- Estimates
CREATE INDEX idx_estimates_user_id ON public.estimates(user_id);
CREATE INDEX idx_estimates_customer_id ON public.estimates(customer_id);
CREATE INDEX idx_estimates_status ON public.estimates(status);
CREATE INDEX idx_estimates_execution_status ON public.estimates(execution_status);
CREATE INDEX idx_estimates_date ON public.estimates(date);
CREATE INDEX idx_estimates_updated_at ON public.estimates(updated_at);
CREATE INDEX idx_estimates_inventory_processed ON public.estimates(inventory_processed);

-- Inventory
CREATE INDEX idx_inventory_items_user_id ON public.inventory_items(user_id);
CREATE INDEX idx_inventory_items_name ON public.inventory_items(name);

-- Equipment
CREATE INDEX idx_equipment_items_user_id ON public.equipment_items(user_id);
CREATE INDEX idx_equipment_items_status ON public.equipment_items(status);

-- Material logs
CREATE INDEX idx_material_logs_user_id ON public.material_logs(user_id);
CREATE INDEX idx_material_logs_job_id ON public.material_logs(job_id);
CREATE INDEX idx_material_logs_date ON public.material_logs(date);

-- Purchase orders
CREATE INDEX idx_purchase_orders_user_id ON public.purchase_orders(user_id);
CREATE INDEX idx_purchase_orders_status ON public.purchase_orders(status);
CREATE INDEX idx_purchase_orders_date ON public.purchase_orders(date);

-- P&L records
CREATE INDEX idx_profit_loss_records_user_id ON public.profit_loss_records(user_id);
CREATE INDEX idx_profit_loss_records_estimate_id ON public.profit_loss_records(estimate_id);
CREATE INDEX idx_profit_loss_records_recorded_at ON public.profit_loss_records(recorded_at);

-- Crew time logs
CREATE INDEX idx_crew_time_logs_estimate_id ON public.crew_time_logs(estimate_id);
CREATE INDEX idx_crew_time_logs_user_id ON public.crew_time_logs(user_id);

-- ============================================================
-- 4. ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================

-- Enable RLS on all tables
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.company_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.estimates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.equipment_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.warehouse_counts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lifetime_usage ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.material_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.purchase_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profit_loss_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.crew_time_logs ENABLE ROW LEVEL SECURITY;

-- Helper function to get current user's user_id from auth
CREATE OR REPLACE FUNCTION public.get_current_user_id()
RETURNS UUID AS $$
BEGIN
    RETURN (
        SELECT id FROM public.users 
        WHERE auth_user_id = auth.uid()
        LIMIT 1
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Users: Users can only see their own record
CREATE POLICY "Users can view own record"
    ON public.users FOR SELECT
    USING (auth_user_id = auth.uid() OR id = get_current_user_id());

CREATE POLICY "Users can insert own record (signup)"
    ON public.users FOR INSERT
    WITH CHECK (auth_user_id = auth.uid());

CREATE POLICY "Users can update own record"
    ON public.users FOR UPDATE
    USING (auth_user_id = auth.uid() OR id = get_current_user_id());

-- Company profiles
CREATE POLICY "Users can view own company profile"
    ON public.company_profiles FOR SELECT
    USING (user_id = get_current_user_id());

CREATE POLICY "Users can insert own company profile"
    ON public.company_profiles FOR INSERT
    WITH CHECK (user_id = get_current_user_id());

CREATE POLICY "Users can update own company profile"
    ON public.company_profiles FOR UPDATE
    USING (user_id = get_current_user_id());

-- Customers: Multi-tenant isolation
CREATE POLICY "Users can view own customers"
    ON public.customers FOR SELECT
    USING (user_id = get_current_user_id());

CREATE POLICY "Users can insert own customers"
    ON public.customers FOR INSERT
    WITH CHECK (user_id = get_current_user_id());

CREATE POLICY "Users can update own customers"
    ON public.customers FOR UPDATE
    USING (user_id = get_current_user_id());

CREATE POLICY "Users can delete own customers"
    ON public.customers FOR DELETE
    USING (user_id = get_current_user_id());

-- Estimates: Multi-tenant isolation
CREATE POLICY "Users can view own estimates"
    ON public.estimates FOR SELECT
    USING (user_id = get_current_user_id());

CREATE POLICY "Users can insert own estimates"
    ON public.estimates FOR INSERT
    WITH CHECK (user_id = get_current_user_id());

CREATE POLICY "Users can update own estimates"
    ON public.estimates FOR UPDATE
    USING (user_id = get_current_user_id());

CREATE POLICY "Users can delete own estimates"
    ON public.estimates FOR DELETE
    USING (user_id = get_current_user_id());

-- Inventory items
CREATE POLICY "Users can view own inventory"
    ON public.inventory_items FOR SELECT
    USING (user_id = get_current_user_id());

CREATE POLICY "Users can insert own inventory"
    ON public.inventory_items FOR INSERT
    WITH CHECK (user_id = get_current_user_id());

CREATE POLICY "Users can update own inventory"
    ON public.inventory_items FOR UPDATE
    USING (user_id = get_current_user_id());

CREATE POLICY "Users can delete own inventory"
    ON public.inventory_items FOR DELETE
    USING (user_id = get_current_user_id());

-- Equipment items
CREATE POLICY "Users can view own equipment"
    ON public.equipment_items FOR SELECT
    USING (user_id = get_current_user_id());

CREATE POLICY "Users can insert own equipment"
    ON public.equipment_items FOR INSERT
    WITH CHECK (user_id = get_current_user_id());

CREATE POLICY "Users can update own equipment"
    ON public.equipment_items FOR UPDATE
    USING (user_id = get_current_user_id());

CREATE POLICY "Users can delete own equipment"
    ON public.equipment_items FOR DELETE
    USING (user_id = get_current_user_id());

-- Warehouse counts
CREATE POLICY "Users can view own warehouse counts"
    ON public.warehouse_counts FOR SELECT
    USING (user_id = get_current_user_id());

CREATE POLICY "Users can insert own warehouse counts"
    ON public.warehouse_counts FOR INSERT
    WITH CHECK (user_id = get_current_user_id());

CREATE POLICY "Users can update own warehouse counts"
    ON public.warehouse_counts FOR UPDATE
    USING (user_id = get_current_user_id());

-- Lifetime usage
CREATE POLICY "Users can view own lifetime usage"
    ON public.lifetime_usage FOR SELECT
    USING (user_id = get_current_user_id());

CREATE POLICY "Users can insert own lifetime usage"
    ON public.lifetime_usage FOR INSERT
    WITH CHECK (user_id = get_current_user_id());

CREATE POLICY "Users can update own lifetime usage"
    ON public.lifetime_usage FOR UPDATE
    USING (user_id = get_current_user_id());

-- Material logs
CREATE POLICY "Users can view own material logs"
    ON public.material_logs FOR SELECT
    USING (user_id = get_current_user_id());

CREATE POLICY "Users can insert own material logs"
    ON public.material_logs FOR INSERT
    WITH CHECK (user_id = get_current_user_id());

-- Purchase orders
CREATE POLICY "Users can view own purchase orders"
    ON public.purchase_orders FOR SELECT
    USING (user_id = get_current_user_id());

CREATE POLICY "Users can insert own purchase orders"
    ON public.purchase_orders FOR INSERT
    WITH CHECK (user_id = get_current_user_id());

CREATE POLICY "Users can update own purchase orders"
    ON public.purchase_orders FOR UPDATE
    USING (user_id = get_current_user_id());

CREATE POLICY "Users can delete own purchase orders"
    ON public.purchase_orders FOR DELETE
    USING (user_id = get_current_user_id());

-- App settings
CREATE POLICY "Users can view own app settings"
    ON public.app_settings FOR SELECT
    USING (user_id = get_current_user_id());

CREATE POLICY "Users can insert own app settings"
    ON public.app_settings FOR INSERT
    WITH CHECK (user_id = get_current_user_id());

CREATE POLICY "Users can update own app settings"
    ON public.app_settings FOR UPDATE
    USING (user_id = get_current_user_id());

-- Profit & Loss records
CREATE POLICY "Users can view own P&L records"
    ON public.profit_loss_records FOR SELECT
    USING (user_id = get_current_user_id());

CREATE POLICY "System can insert P&L records"
    ON public.profit_loss_records FOR INSERT
    WITH CHECK (user_id = get_current_user_id());

-- Crew time logs
CREATE POLICY "Users can view own crew time logs"
    ON public.crew_time_logs FOR SELECT
    USING (user_id = get_current_user_id());

CREATE POLICY "Users can insert own crew time logs"
    ON public.crew_time_logs FOR INSERT
    WITH CHECK (user_id = get_current_user_id());

CREATE POLICY "Users can update own crew time logs"
    ON public.crew_time_logs FOR UPDATE
    USING (user_id = get_current_user_id());

-- Trial memberships (public insert for trial signup)
CREATE POLICY "Anyone can submit trial membership"
    ON public.trial_memberships FOR INSERT
    WITH CHECK (true);

-- ============================================================
-- 5. TRIGGERS FOR AUTOMATIC TIMESTAMPS
-- ============================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply trigger to all tables with updated_at
CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON public.users
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_company_profiles_updated_at
    BEFORE UPDATE ON public.company_profiles
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_customers_updated_at
    BEFORE UPDATE ON public.customers
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_estimates_updated_at
    BEFORE UPDATE ON public.estimates
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_inventory_items_updated_at
    BEFORE UPDATE ON public.inventory_items
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_equipment_items_updated_at
    BEFORE UPDATE ON public.equipment_items
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_warehouse_counts_updated_at
    BEFORE UPDATE ON public.warehouse_counts
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_lifetime_usage_updated_at
    BEFORE UPDATE ON public.lifetime_usage
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_purchase_orders_updated_at
    BEFORE UPDATE ON public.purchase_orders
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_app_settings_updated_at
    BEFORE UPDATE ON public.app_settings
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================================
-- 6. TRIGGER FOR AUTH.USER INTEGRATION
-- ============================================================

-- Function to create user record when auth.users is inserted
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.users (auth_user_id, username, email, role, crew_code)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'username', NEW.email),
        NEW.email,
        COALESCE((NEW.raw_user_meta_data->>'role')::user_role, 'admin'),
        COALESCE(NEW.raw_user_meta_data->>'crew_code', LPAD(FLOOR(RANDOM() * 9000 + 1000)::TEXT, 4, '0'))
    )
    ON CONFLICT (auth_user_id) DO NOTHING;
    
    -- Create default app settings
    INSERT INTO public.app_settings (user_id)
    SELECT id FROM public.users WHERE auth_user_id = NEW.id
    ON CONFLICT (user_id) DO NOTHING;
    
    -- Create default warehouse counts
    INSERT INTO public.warehouse_counts (user_id)
    SELECT id FROM public.users WHERE auth_user_id = NEW.id
    ON CONFLICT (user_id) DO NOTHING;
    
    -- Create default lifetime usage
    INSERT INTO public.lifetime_usage (user_id)
    SELECT id FROM public.users WHERE auth_user_id = NEW.id
    ON CONFLICT (user_id) DO NOTHING;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger on auth.users
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================
-- 7. COMMENTS FOR DOCUMENTATION
-- ============================================================

COMMENT ON TABLE public.users IS 'User accounts with company and role information';
COMMENT ON TABLE public.company_profiles IS 'Company profile details for estimates and invoices';
COMMENT ON TABLE public.customers IS 'Customer contact information';
COMMENT ON TABLE public.estimates IS 'Job estimates, work orders, and invoices';
COMMENT ON TABLE public.inventory_items IS 'Inventory items (materials, supplies)';
COMMENT ON TABLE public.equipment_items IS 'Equipment tracking (spray rigs, generators, etc.)';
COMMENT ON TABLE public.warehouse_counts IS 'Current foam set counts in warehouse';
COMMENT ON TABLE public.lifetime_usage IS 'Lifetime foam usage statistics';
COMMENT ON TABLE public.material_logs IS 'Material usage logs for jobs';
COMMENT ON TABLE public.purchase_orders IS 'Purchase orders for inventory restocking';
COMMENT ON TABLE public.app_settings IS 'Per-user application settings (yields, costs, rates)';
COMMENT ON TABLE public.trial_memberships IS 'Trial membership leads';
COMMENT ON TABLE public.profit_loss_records IS 'Auto-generated P&L records for paid jobs';
COMMENT ON TABLE public.crew_time_logs IS 'Crew time tracking for jobs';
