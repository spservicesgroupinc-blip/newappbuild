-- ============================================================
-- SUPABASE DATABASE FUNCTIONS AND TRIGGERS
-- Business Logic for Spray Foam Insulation Management
-- ============================================================

-- ============================================================
-- 1. P&L CALCULATION FUNCTION
-- ============================================================

-- Function to calculate P&L for an estimate
CREATE OR REPLACE FUNCTION public.calculate_estimate_financials(
    p_estimate_id UUID,
    p_user_id UUID
)
RETURNS JSONB AS $$
DECLARE
    v_estimate RECORD;
    v_actuals JSONB;
    v_materials JSONB;
    v_expenses JSONB;
    v_costs JSONB;
    v_open_cell_sets NUMERIC;
    v_closed_cell_sets NUMERIC;
    v_labor_hours NUMERIC;
    v_labor_rate NUMERIC;
    v_chemical_cost NUMERIC;
    v_labor_cost NUMERIC;
    v_inventory_cost NUMERIC;
    v_misc_cost NUMERIC;
    v_total_cogs NUMERIC;
    v_revenue NUMERIC;
    v_net_profit NUMERIC;
    v_margin NUMERIC;
    v_item RECORD;
BEGIN
    -- Get estimate data
    SELECT * INTO v_estimate
    FROM public.estimates
    WHERE id = p_estimate_id AND user_id = p_user_id;
    
    IF v_estimate IS NULL THEN
        RETURN NULL;
    END IF;
    
    -- Get actuals or fall back to materials
    v_actuals := COALESCE(v_estimate.actuals_json, '{}'::jsonb);
    v_materials := COALESCE(v_estimate.materials_json, '{}'::jsonb);
    v_expenses := COALESCE(v_estimate.expenses_json, '{}'::jsonb);
    
    -- Get costs from app settings
    SELECT costs_json INTO v_costs
    FROM public.app_settings
    WHERE user_id = p_user_id;
    
    v_costs := COALESCE(v_costs, '{"openCell": 0, "closedCell": 0, "laborRate": 0}'::jsonb);
    
    -- Calculate foam usage (actual or estimated)
    v_open_cell_sets := COALESCE(
        (v_actuals->>'openCellSets')::NUMERIC,
        (v_materials->>'openCellSets')::NUMERIC,
        0
    );
    
    v_closed_cell_sets := COALESCE(
        (v_actuals->>'closedCellSets')::NUMERIC,
        (v_materials->>'closedCellSets')::NUMERIC,
        0
    );
    
    -- Calculate chemical cost
    v_chemical_cost := (v_open_cell_sets * COALESCE((v_costs->>'openCell')::NUMERIC, 0)) +
                       (v_closed_cell_sets * COALESCE((v_costs->>'closedCell')::NUMERIC, 0));
    
    -- Calculate labor cost
    v_labor_hours := COALESCE(
        (v_actuals->>'laborHours')::NUMERIC,
        (v_expenses->>'manHours')::NUMERIC,
        0
    );
    
    v_labor_rate := COALESCE(
        (v_expenses->>'laborRate')::NUMERIC,
        (v_costs->>'laborRate')::NUMERIC,
        0
    );
    
    v_labor_cost := v_labor_hours * v_labor_rate;
    
    -- Calculate inventory cost
    v_inventory_cost := 0;
    FOR v_item IN SELECT * FROM jsonb_array_elements(COALESCE(
        v_actuals->'inventory',
        v_materials->'inventory',
        '[]'::jsonb
    )) AS item
    LOOP
        v_inventory_cost := v_inventory_cost + (
            COALESCE((v_item->>'quantity')::NUMERIC, 0) *
            COALESCE((v_item->>'unitCost')::NUMERIC, 0)
        );
    END LOOP;
    
    -- Calculate misc expenses
    v_misc_cost := COALESCE((v_expenses->>'tripCharge')::NUMERIC, 0) +
                   COALESCE((v_expenses->>'fuelSurcharge')::NUMERIC, 0) +
                   COALESCE((v_expenses->'other'->>'amount')::NUMERIC, 0);
    
    -- Calculate totals
    v_total_cogs := v_chemical_cost + v_labor_cost + v_inventory_cost + v_misc_cost;
    v_revenue := COALESCE(v_estimate.total_value, 0);
    v_net_profit := v_revenue - v_total_cogs;
    v_margin := CASE WHEN v_revenue > 0 THEN v_net_profit / v_revenue ELSE 0 END;
    
    -- Return financials JSONB
    RETURN jsonb_build_object(
        'revenue', v_revenue,
        'chemicalCost', v_chemical_cost,
        'laborCost', v_labor_cost,
        'inventoryCost', v_inventory_cost,
        'miscCost', v_misc_cost,
        'totalCOGS', v_total_cogs,
        'netProfit', v_net_profit,
        'margin', v_margin
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 2. INVENTORY RECONCILIATION FUNCTION
-- ============================================================

-- Function to reconcile inventory on job completion
CREATE OR REPLACE FUNCTION public.reconcile_inventory_on_completion(
    p_estimate_id UUID,
    p_user_id UUID,
    p_actuals JSONB
)
RETURNS BOOLEAN AS $$
DECLARE
    v_estimate RECORD;
    v_estimated_oc NUMERIC;
    v_estimated_cc NUMERIC;
    v_actual_oc NUMERIC;
    v_actual_cc NUMERIC;
    v_diff_oc NUMERIC;
    v_diff_cc NUMERIC;
    v_warehouse RECORD;
    v_lifetime RECORD;
    v_inventory_item RECORD;
    v_estimated_inventory JSONB;
    v_actual_inventory JSONB;
    v_item RECORD;
    v_est_item RECORD;
    v_est_qty NUMERIC;
    v_act_qty NUMERIC;
    v_diff_qty NUMERIC;
BEGIN
    -- Get estimate
    SELECT * INTO v_estimate
    FROM public.estimates
    WHERE id = p_estimate_id AND user_id = p_user_id;
    
    IF v_estimate IS NULL THEN
        RAISE EXCEPTION 'Estimate not found';
    END IF;
    
    -- Check if already processed
    IF v_estimate.inventory_processed THEN
        RAISE NOTICE 'Job already finalized';
        RETURN TRUE;
    END IF;
    
    -- Get estimated vs actual foam sets
    v_estimated_oc := COALESCE((v_estimate.materials_json->>'openCellSets')::NUMERIC, 0);
    v_estimated_cc := COALESCE((v_estimate.materials_json->>'closedCellSets')::NUMERIC, 0);
    v_actual_oc := COALESCE((p_actuals->>'openCellSets')::NUMERIC, 0);
    v_actual_cc := COALESCE((p_actuals->>'closedCellSets')::NUMERIC, 0);
    
    -- Calculate difference (what was actually used vs estimated)
    v_diff_oc := v_actual_oc - v_estimated_oc;
    v_diff_cc := v_actual_cc - v_estimated_cc;
    
    -- Update warehouse counts
    SELECT * INTO v_warehouse
    FROM public.warehouse_counts
    WHERE user_id = p_user_id;
    
    IF v_warehouse IS NOT NULL THEN
        UPDATE public.warehouse_counts
        SET 
            open_cell_sets = GREATEST(0, COALESCE(open_cell_sets, 0) - v_diff_oc),
            closed_cell_sets = GREATEST(0, COALESCE(closed_cell_sets, 0) - v_diff_cc),
            updated_at = NOW()
        WHERE user_id = p_user_id;
    ELSE
        INSERT INTO public.warehouse_counts (user_id, open_cell_sets, closed_cell_sets)
        VALUES (p_user_id, GREATEST(0, -v_diff_oc), GREATEST(0, -v_diff_cc));
    END IF;
    
    -- Update lifetime usage (add actuals)
    SELECT * INTO v_lifetime
    FROM public.lifetime_usage
    WHERE user_id = p_user_id;
    
    IF v_lifetime IS NOT NULL THEN
        UPDATE public.lifetime_usage
        SET 
            open_cell = COALESCE(open_cell, 0) + v_actual_oc,
            closed_cell = COALESCE(closed_cell, 0) + v_actual_cc,
            updated_at = NOW()
        WHERE user_id = p_user_id;
    ELSE
        INSERT INTO public.lifetime_usage (user_id, open_cell, closed_cell)
        VALUES (p_user_id, v_actual_oc, v_actual_cc);
    END IF;
    
    -- Update inventory items (delta logic)
    v_estimated_inventory := COALESCE(v_estimate.materials_json->'inventory', '[]'::jsonb);
    v_actual_inventory := COALESCE(p_actuals->'inventory', '[]'::jsonb);
    
    FOR v_item IN SELECT * FROM jsonb_array_elements(v_actual_inventory) AS item
    LOOP
        -- Find corresponding estimated item
        v_est_qty := 0;
        FOR v_est_item IN SELECT * FROM jsonb_array_elements(v_estimated_inventory) AS est
        LOOP
            IF (est->>'id') = (v_item->>'id') THEN
                v_est_qty := COALESCE((est->>'quantity')::NUMERIC, 0);
                EXIT;
            END IF;
        END LOOP;
        
        v_act_qty := COALESCE((v_item->>'quantity')::NUMERIC, 0);
        v_diff_qty := v_act_qty - v_est_qty;
        
        -- Update inventory item
        UPDATE public.inventory_items
        SET 
            quantity = GREATEST(0, quantity - v_diff_qty),
            updated_at = NOW()
        WHERE id = (v_item->>'id')::UUID AND user_id = p_user_id;
    END LOOP;
    
    -- Create material logs
    INSERT INTO public.material_logs (job_id, customer_name, material_name, quantity, unit, logged_by, user_id, date)
    SELECT 
        p_estimate_id,
        COALESCE((SELECT name FROM public.customers WHERE id = v_estimate.customer_id), 'Unknown'),
        'Open Cell Foam',
        v_actual_oc,
        'Sets',
        COALESCE(p_actuals->>'completedBy', 'Crew'),
        p_user_id,
        COALESCE((p_actuals->>'completionDate')::TIMESTAMPTZ, NOW())
    WHERE v_actual_oc > 0;
    
    INSERT INTO public.material_logs (job_id, customer_name, material_name, quantity, unit, logged_by, user_id, date)
    SELECT 
        p_estimate_id,
        COALESCE((SELECT name FROM public.customers WHERE id = v_estimate.customer_id), 'Unknown'),
        'Closed Cell Foam',
        v_actual_cc,
        'Sets',
        COALESCE(p_actuals->>'completedBy', 'Crew'),
        p_user_id,
        COALESCE((p_actuals->>'completionDate')::TIMESTAMPTZ, NOW())
    WHERE v_actual_cc > 0;
    
    -- Log inventory items
    FOR v_item IN SELECT * FROM jsonb_array_elements(v_actual_inventory) AS item
    LOOP
        IF COALESCE((v_item->>'quantity')::NUMERIC, 0) > 0 THEN
            INSERT INTO public.material_logs (job_id, customer_name, material_name, quantity, unit, logged_by, user_id, date)
            VALUES (
                p_estimate_id,
                COALESCE((SELECT name FROM public.customers WHERE id = v_estimate.customer_id), 'Unknown'),
                v_item->>'name',
                (v_item->>'quantity')::NUMERIC,
                v_item->>'unit',
                COALESCE(p_actuals->>'completedBy', 'Crew'),
                p_user_id,
                COALESCE((p_actuals->>'completionDate')::TIMESTAMPTZ, NOW())
            );
        END IF;
    END LOOP;
    
    -- Mark estimate as completed
    UPDATE public.estimates
    SET 
        execution_status = 'Completed',
        actuals_json = p_actuals,
        inventory_processed = TRUE,
        updated_at = NOW()
    WHERE id = p_estimate_id;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 3. MARK JOB PAID FUNCTION
-- ============================================================

-- Function to mark job as paid and create P&L record
CREATE OR REPLACE FUNCTION public.mark_job_as_paid(
    p_estimate_id UUID,
    p_user_id UUID
)
RETURNS JSONB AS $$
DECLARE
    v_estimate RECORD;
    v_financials JSONB;
    v_pnl_id UUID;
BEGIN
    -- Get estimate
    SELECT * INTO v_estimate
    FROM public.estimates
    WHERE id = p_estimate_id AND user_id = p_user_id;
    
    IF v_estimate IS NULL THEN
        RAISE EXCEPTION 'Estimate not found';
    END IF;
    
    -- Calculate financials
    v_financials := public.calculate_estimate_financials(p_estimate_id, p_user_id);
    
    IF v_financials IS NULL THEN
        RAISE EXCEPTION 'Could not calculate financials';
    END IF;
    
    -- Update estimate status
    UPDATE public.estimates
    SET 
        status = 'Paid',
        financials_json = v_financials,
        updated_at = NOW()
    WHERE id = p_estimate_id;
    
    -- Create P&L record
    INSERT INTO public.profit_loss_records (
        estimate_id, customer_name, invoice_number, revenue,
        chemical_cost, labor_cost, inventory_cost, misc_cost,
        total_cogs, net_profit, margin, user_id
    )
    SELECT 
        p_estimate_id,
        (SELECT name FROM public.customers WHERE id = v_estimate.customer_id),
        v_estimate.invoice_number,
        (v_financials->>'revenue')::NUMERIC,
        (v_financials->>'chemicalCost')::NUMERIC,
        (v_financials->>'laborCost')::NUMERIC,
        (v_financials->>'inventoryCost')::NUMERIC,
        (v_financials->>'miscCost')::NUMERIC,
        (v_financials->>'totalCOGS')::NUMERIC,
        (v_financials->>'netProfit')::NUMERIC,
        (v_financials->>'margin')::NUMERIC,
        p_user_id
    RETURNING id INTO v_pnl_id;
    
    -- Return updated estimate with financials
    RETURN jsonb_build_object(
        'success', TRUE,
        'estimate', jsonb_build_object(
            'id', v_estimate.id,
            'status', 'Paid',
            'financials', v_financials
        ),
        'pnl_record_id', v_pnl_id
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 4. START JOB FUNCTION
-- ============================================================

-- Function to start a job
CREATE OR REPLACE FUNCTION public.start_job(
    p_estimate_id UUID,
    p_user_id UUID
)
RETURNS JSONB AS $$
DECLARE
    v_estimate RECORD;
BEGIN
    -- Get estimate
    SELECT * INTO v_estimate
    FROM public.estimates
    WHERE id = p_estimate_id AND user_id = p_user_id;
    
    IF v_estimate IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Estimate not found');
    END IF;
    
    -- Update execution status
    UPDATE public.estimates
    SET 
        execution_status = 'In Progress',
        actuals_json = jsonb_set(
            COALESCE(actuals_json, '{}'::jsonb),
            '{lastStartedAt}',
            to_jsonb(NOW())
        ),
        updated_at = NOW()
    WHERE id = p_estimate_id;
    
    RETURN jsonb_build_object('success', TRUE, 'status', 'In Progress');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 5. DELETE ESTIMATE FUNCTION
-- ============================================================

-- Function to delete an estimate
CREATE OR REPLACE FUNCTION public.delete_estimate(
    p_estimate_id UUID,
    p_user_id UUID
)
RETURNS BOOLEAN AS $$
BEGIN
    DELETE FROM public.estimates
    WHERE id = p_estimate_id AND user_id = p_user_id;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 6. CREW TIME LOGGING FUNCTION
-- ============================================================

-- Function to log crew time
CREATE OR REPLACE FUNCTION public.log_crew_time(
    p_estimate_id UUID,
    p_user_id UUID,
    p_start_time TIMESTAMPTZ,
    p_end_time TIMESTAMPTZ DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_log_id UUID;
BEGIN
    -- Check if there's an open time log for this estimate and user
    SELECT id INTO v_log_id
    FROM public.crew_time_logs
    WHERE estimate_id = p_estimate_id 
      AND user_id = p_user_id 
      AND end_time IS NULL
    ORDER BY start_time DESC
    LIMIT 1;
    
    IF v_log_id IS NOT NULL AND p_end_time IS NOT NULL THEN
        -- Update existing log with end time
        UPDATE public.crew_time_logs
        SET end_time = p_end_time
        WHERE id = v_log_id;
        
        RETURN v_log_id;
    ELSE
        -- Create new time log
        INSERT INTO public.crew_time_logs (estimate_id, user_id, start_time, end_time)
        VALUES (p_estimate_id, p_user_id, p_start_time, p_end_time)
        RETURNING id INTO v_log_id;
        
        RETURN v_log_id;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 7. SYNC DOWN FUNCTION (DELTA SYNC)
-- ============================================================

-- Function to get delta sync data
CREATE OR REPLACE FUNCTION public.sync_down(
    p_user_id UUID,
    p_last_sync_timestamp TIMESTAMPTZ DEFAULT '1970-01-01'::TIMESTAMPTZ
)
RETURNS JSONB AS $$
DECLARE
    v_result JSONB;
    v_settings JSONB;
    v_warehouse JSONB;
    v_lifetime JSONB;
BEGIN
    -- Get app settings
    SELECT jsonb_build_object(
        'yields', yields_json,
        'costs', costs_json,
        'expenses', expenses_json,
        'jobNotes', job_notes,
        'sqftRates', sqft_rates_json,
        'pricingMode', pricing_mode
    ) INTO v_settings
    FROM public.app_settings
    WHERE user_id = p_user_id;
    
    -- Get warehouse counts
    SELECT jsonb_build_object(
        'openCellSets', open_cell_sets,
        'closedCellSets', closed_cell_sets,
        'items', (
            SELECT COALESCE(jsonb_agg(
                jsonb_build_object(
                    'id', id,
                    'name', name,
                    'quantity', quantity,
                    'unit', unit,
                    'unitCost', unit_cost,
                    'lastModified', updated_at
                )
            ), '[]'::jsonb)
            FROM public.inventory_items
            WHERE user_id = p_user_id
              AND (updated_at > p_last_sync_timestamp OR p_last_sync_timestamp = '1970-01-01'::TIMESTAMPTZ)
        )
    ) INTO v_warehouse
    FROM public.warehouse_counts
    WHERE user_id = p_user_id;
    
    -- Get lifetime usage
    SELECT jsonb_build_object(
        'openCell', open_cell,
        'closedCell', closed_cell
    ) INTO v_lifetime
    FROM public.lifetime_usage
    WHERE user_id = p_user_id;
    
    -- Build result
    SELECT jsonb_build_object(
        'settings', COALESCE(v_settings, '{}'::jsonb),
        'warehouse', COALESCE(v_warehouse, jsonb_build_object('openCellSets', 0, 'closedCellSets', 0, 'items', '[]'::jsonb)),
        'lifetimeUsage', COALESCE(v_lifetime, jsonb_build_object('openCell', 0, 'closedCell', 0)),
        'equipment', (
            SELECT COALESCE(jsonb_agg(
                jsonb_build_object(
                    'id', id,
                    'name', name,
                    'status', status,
                    'lastSeen', last_seen_json,
                    'lastModified', updated_at
                )
            ), '[]'::jsonb)
            FROM public.equipment_items
            WHERE user_id = p_user_id
              AND (updated_at > p_last_sync_timestamp OR p_last_sync_timestamp = '1970-01-01'::TIMESTAMPTZ)
        ),
        'savedEstimates', (
            SELECT COALESCE(jsonb_agg(
                jsonb_build_object(
                    'id', id,
                    'date', date,
                    'customerId', customer_id,
                    'totalValue', total_value,
                    'status', status,
                    'executionStatus', execution_status,
                    'invoiceNumber', invoice_number,
                    'pdfLink', pdf_link,
                    'workOrderSheetUrl', work_order_sheet_url,
                    'inputs', inputs_json,
                    'results', results_json,
                    'materials', materials_json,
                    'wallSettings', wall_settings_json,
                    'roofSettings', roof_settings_json,
                    'expenses', expenses_json,
                    'actuals', actuals_json,
                    'financials', financials_json,
                    'sqftRates', sqft_rates_json,
                    'notes', notes,
                    'pricingMode', pricing_mode,
                    'scheduledDate', scheduled_date,
                    'invoiceDate', invoice_date,
                    'paymentTerms', payment_terms,
                    'inventoryProcessed', inventory_processed,
                    'sitePhotos', site_photos,
                    'lastModified', updated_at
                )
            ), '[]'::jsonb)
            FROM public.estimates
            WHERE user_id = p_user_id
              AND (updated_at > p_last_sync_timestamp OR p_last_sync_timestamp = '1970-01-01'::TIMESTAMPTZ)
        ),
        'customers', (
            SELECT COALESCE(jsonb_agg(
                jsonb_build_object(
                    'id', id,
                    'name', name,
                    'address', address,
                    'city', city,
                    'state', state,
                    'zip', zip,
                    'phone', phone,
                    'email', email,
                    'status', status,
                    'notes', notes,
                    'lastModified', updated_at
                )
            ), '[]'::jsonb)
            FROM public.customers
            WHERE user_id = p_user_id
              AND (updated_at > p_last_sync_timestamp OR p_last_sync_timestamp = '1970-01-01'::TIMESTAMPTZ)
        ),
        'purchaseOrders', (
            SELECT COALESCE(jsonb_agg(
                jsonb_build_object(
                    'id', id,
                    'date', date,
                    'vendorName', vendor_name,
                    'status', status,
                    'items', items_json,
                    'totalCost', total_cost,
                    'notes', notes,
                    'lastModified', updated_at
                )
            ), '[]'::jsonb)
            FROM public.purchase_orders
            WHERE user_id = p_user_id
              AND (updated_at > p_last_sync_timestamp OR p_last_sync_timestamp = '1970-01-01'::TIMESTAMPTZ)
        ),
        'companyProfile', (
            SELECT jsonb_build_object(
                'companyName', company_name,
                'addressLine1', address_line1,
                'addressLine2', address_line2,
                'city', city,
                'state', state,
                'zip', zip,
                'phone', phone,
                'email', email,
                'website', website,
                'logoUrl', logo_url,
                'crewAccessPin', crew_access_pin
            )
            FROM public.company_profiles
            WHERE user_id = p_user_id
        ),
        'serverTimestamp', NOW()
    ) INTO v_result;
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 8. SYNC UP FUNCTION
-- ============================================================

-- Function to sync up data from client
CREATE OR REPLACE FUNCTION public.sync_up(
    p_user_id UUID,
    p_state JSONB
)
RETURNS JSONB AS $$
DECLARE
    v_customer RECORD;
    v_estimate RECORD;
    v_inventory RECORD;
    v_equipment RECORD;
    v_purchase_order RECORD;
BEGIN
    -- Update company profile
    IF p_state->'companyProfile' IS NOT NULL THEN
        INSERT INTO public.company_profiles (
            user_id, company_name, address_line1, address_line2, city, state, zip,
            phone, email, website, logo_url, crew_access_pin
        )
        SELECT 
            p_user_id,
            p_state->'companyProfile'->>'companyName',
            p_state->'companyProfile'->>'addressLine1',
            p_state->'companyProfile'->>'addressLine2',
            p_state->'companyProfile'->>'city',
            p_state->'companyProfile'->>'state',
            p_state->'companyProfile'->>'zip',
            p_state->'companyProfile'->>'phone',
            p_state->'companyProfile'->>'email',
            p_state->'companyProfile'->>'website',
            NULLIF(p_state->'companyProfile'->>'logoUrl', ''),
            p_state->'companyProfile'->>'crewAccessPin'
        ON CONFLICT (user_id) DO UPDATE SET
            company_name = EXCLUDED.company_name,
            address_line1 = EXCLUDED.address_line1,
            address_line2 = EXCLUDED.address_line2,
            city = EXCLUDED.city,
            state = EXCLUDED.state,
            zip = EXCLUDED.zip,
            phone = EXCLUDED.phone,
            email = EXCLUDED.email,
            website = EXCLUDED.website,
            logo_url = EXCLUDED.logo_url,
            crew_access_pin = EXCLUDED.crew_access_pin,
            updated_at = NOW();
    END IF;
    
    -- Update app settings
    IF p_state->'yields' IS NOT NULL OR p_state->'costs' IS NOT NULL THEN
        INSERT INTO public.app_settings (
            user_id, yields_json, costs_json, expenses_json, job_notes, sqft_rates_json, pricing_mode
        )
        SELECT 
            p_user_id,
            COALESCE(p_state->'yields', '{}'::jsonb),
            COALESCE(p_state->'costs', '{}'::jsonb),
            COALESCE(p_state->'expenses', '{}'::jsonb),
            p_state->>'jobNotes',
            COALESCE(p_state->'sqftRates', '{}'::jsonb),
            COALESCE((p_state->>'pricingMode')::pricing_mode_type, 'level_pricing')
        ON CONFLICT (user_id) DO UPDATE SET
            yields_json = EXCLUDED.yields_json,
            costs_json = EXCLUDED.costs_json,
            expenses_json = EXCLUDED.expenses_json,
            job_notes = EXCLUDED.job_notes,
            sqft_rates_json = EXCLUDED.sqft_rates_json,
            pricing_mode = EXCLUDED.pricing_mode,
            updated_at = NOW();
    END IF;
    
    -- Update lifetime usage
    IF p_state->'lifetimeUsage' IS NOT NULL THEN
        INSERT INTO public.lifetime_usage (user_id, open_cell, closed_cell)
        SELECT 
            p_user_id,
            COALESCE((p_state->'lifetimeUsage'->>'openCell')::NUMERIC, 0),
            COALESCE((p_state->'lifetimeUsage'->>'closedCell')::NUMERIC, 0)
        ON CONFLICT (user_id) DO UPDATE SET
            open_cell = EXCLUDED.open_cell,
            closed_cell = EXCLUDED.closed_cell,
            updated_at = NOW();
    END IF;
    
    -- Update warehouse counts
    IF p_state->'warehouse' IS NOT NULL THEN
        INSERT INTO public.warehouse_counts (user_id, open_cell_sets, closed_cell_sets)
        SELECT 
            p_user_id,
            COALESCE((p_state->'warehouse'->>'openCellSets')::NUMERIC, 0),
            COALESCE((p_state->'warehouse'->>'closedCellSets')::NUMERIC, 0)
        ON CONFLICT (user_id) DO UPDATE SET
            open_cell_sets = EXCLUDED.open_cell_sets,
            closed_cell_sets = EXCLUDED.closed_cell_sets,
            updated_at = NOW();
    END IF;
    
    -- Sync customers (upsert)
    FOR v_customer IN SELECT * FROM jsonb_array_elements(COALESCE(p_state->'customers', '[]'::jsonb)) AS c
    LOOP
        INSERT INTO public.customers (
            id, user_id, name, address, city, state, zip, phone, email, status, notes
        )
        VALUES (
            (v_customer->>'id')::UUID,
            p_user_id,
            v_customer->>'name',
            v_customer->>'address',
            v_customer->>'city',
            v_customer->>'state',
            v_customer->>'zip',
            v_customer->>'phone',
            v_customer->>'email',
            COALESCE((v_customer->>'status')::customer_status, 'Active'),
            v_customer->>'notes'
        )
        ON CONFLICT (id) DO UPDATE SET
            name = EXCLUDED.name,
            address = EXCLUDED.address,
            city = EXCLUDED.city,
            state = EXCLUDED.state,
            zip = EXCLUDED.zip,
            phone = EXCLUDED.phone,
            email = EXCLUDED.email,
            status = EXCLUDED.status,
            notes = EXCLUDED.notes,
            updated_at = NOW();
    END LOOP;
    
    -- Sync estimates (upsert with logic)
    FOR v_estimate IN SELECT * FROM jsonb_array_elements(COALESCE(p_state->'savedEstimates', '[]'::jsonb)) AS e
    LOOP
        INSERT INTO public.estimates (
            id, user_id, customer_id, date, total_value, status, execution_status,
            invoice_number, pdf_link, work_order_sheet_url, inputs_json, results_json,
            materials_json, wall_settings_json, roof_settings_json, expenses_json,
            actuals_json, financials_json, sqft_rates_json, notes, pricing_mode,
            scheduled_date, invoice_date, payment_terms, inventory_processed, site_photos
        )
        SELECT 
            (v_estimate->>'id')::UUID,
            p_user_id,
            (v_estimate->>'customerId')::UUID,
            COALESCE((v_estimate->>'date')::DATE, CURRENT_DATE),
            COALESCE((v_estimate->>'totalValue')::NUMERIC, 0),
            COALESCE((v_estimate->>'status')::estimate_status, 'Draft'),
            COALESCE((v_estimate->>'executionStatus')::estimate_execution_status, 'Not Started'),
            v_estimate->>'invoiceNumber',
            v_estimate->>'pdfLink',
            v_estimate->>'workOrderSheetUrl',
            COALESCE(v_estimate->'inputs', '{}'::jsonb),
            COALESCE(v_estimate->'results', '{}'::jsonb),
            COALESCE(v_estimate->'materials', '{}'::jsonb),
            COALESCE(v_estimate->'wallSettings', '{}'::jsonb),
            COALESCE(v_estimate->'roofSettings', '{}'::jsonb),
            COALESCE(v_estimate->'expenses', '{}'::jsonb),
            COALESCE(v_estimate->'actuals', '{}'::jsonb),
            COALESCE(v_estimate->'financials', '{}'::jsonb),
            COALESCE(v_estimate->'sqftRates', '{}'::jsonb),
            v_estimate->>'notes',
            COALESCE((v_estimate->>'pricingMode')::pricing_mode_type, 'level_pricing'),
            (v_estimate->>'scheduledDate')::DATE,
            (v_estimate->>'invoiceDate')::DATE,
            v_estimate->>'paymentTerms',
            COALESCE((v_estimate->>'inventoryProcessed')::BOOLEAN, FALSE),
            COALESCE(v_estimate->'sitePhotos', '[]'::TEXT[])
        ON CONFLICT (id) DO UPDATE SET
            total_value = EXCLUDED.total_value,
            status = CASE 
                WHEN estimates.status = 'Paid' THEN 'Paid'
                ELSE EXCLUDED.status
            END,
            execution_status = CASE 
                WHEN estimates.execution_status = 'Completed' AND estimates.inventory_processed THEN 'Completed'
                ELSE EXCLUDED.execution_status
            END,
            inventory_processed = CASE 
                WHEN estimates.execution_status = 'Completed' AND estimates.inventory_processed THEN TRUE
                ELSE EXCLUDED.inventory_processed
            END,
            actuals_json = CASE 
                WHEN estimates.execution_status = 'Completed' AND estimates.inventory_processed THEN estimates.actuals_json
                ELSE EXCLUDED.actuals_json
            END,
            pdf_link = COALESCE(EXCLUDED.pdf_link, estimates.pdf_link),
            work_order_sheet_url = COALESCE(EXCLUDED.work_order_sheet_url, estimates.work_order_sheet_url),
            site_photos = CASE 
                WHEN estimates.site_photos IS NOT NULL AND array_length(estimates.site_photos, 1) > 0 
                THEN estimates.site_photos 
                ELSE EXCLUDED.site_photos 
            END,
            inputs_json = EXCLUDED.inputs_json,
            results_json = EXCLUDED.results_json,
            materials_json = EXCLUDED.materials_json,
            wall_settings_json = EXCLUDED.wall_settings_json,
            roof_settings_json = EXCLUDED.roof_settings_json,
            expenses_json = EXCLUDED.expenses_json,
            financials_json = EXCLUDED.financials_json,
            sqft_rates_json = EXCLUDED.sqft_rates_json,
            notes = EXCLUDED.notes,
            pricing_mode = EXCLUDED.pricing_mode,
            scheduled_date = EXCLUDED.scheduled_date,
            invoice_date = EXCLUDED.invoice_date,
            payment_terms = EXCLUDED.payment_terms,
            updated_at = NOW();
    END LOOP;
    
    -- Sync inventory items
    FOR v_inventory IN SELECT * FROM jsonb_array_elements(COALESCE(p_state->'warehouse'->'items', '[]'::jsonb)) AS i
    LOOP
        INSERT INTO public.inventory_items (
            id, user_id, name, quantity, unit, unit_cost
        )
        VALUES (
            (v_inventory->>'id')::UUID,
            p_user_id,
            v_inventory->>'name',
            COALESCE((v_inventory->>'quantity')::NUMERIC, 0),
            COALESCE((v_inventory->>'unit')::inventory_unit, 'Each'),
            COALESCE((v_inventory->>'unitCost')::NUMERIC, 0)
        )
        ON CONFLICT (id) DO UPDATE SET
            name = EXCLUDED.name,
            quantity = EXCLUDED.quantity,
            unit = EXCLUDED.unit,
            unit_cost = EXCLUDED.unit_cost,
            updated_at = NOW();
    END LOOP;
    
    -- Sync equipment items
    FOR v_equipment IN SELECT * FROM jsonb_array_elements(COALESCE(p_state->'equipment', '[]'::jsonb)) AS e
    LOOP
        INSERT INTO public.equipment_items (
            id, user_id, name, status, last_seen_json
        )
        VALUES (
            (v_equipment->>'id')::UUID,
            p_user_id,
            v_equipment->>'name',
            COALESCE((v_equipment->>'status')::equipment_status, 'Available'),
            COALESCE(v_equipment->'lastSeen', '{}'::jsonb)
        )
        ON CONFLICT (id) DO UPDATE SET
            name = EXCLUDED.name,
            status = EXCLUDED.status,
            last_seen_json = EXCLUDED.last_seen_json,
            updated_at = NOW();
    END LOOP;
    
    -- Sync purchase orders
    FOR v_purchase_order IN SELECT * FROM jsonb_array_elements(COALESCE(p_state->'purchaseOrders', '[]'::jsonb)) AS po
    LOOP
        INSERT INTO public.purchase_orders (
            id, user_id, date, vendor_name, status, items_json, total_cost, notes
        )
        VALUES (
            (v_purchase_order->>'id')::UUID,
            p_user_id,
            COALESCE((v_purchase_order->>'date')::DATE, CURRENT_DATE),
            v_purchase_order->>'vendorName',
            COALESCE((v_purchase_order->>'status')::purchase_order_status, 'Draft'),
            COALESCE(v_purchase_order->'items', '[]'::jsonb),
            COALESCE((v_purchase_order->>'totalCost')::NUMERIC, 0),
            v_purchase_order->>'notes'
        )
        ON CONFLICT (id) DO UPDATE SET
            vendor_name = EXCLUDED.vendor_name,
            status = EXCLUDED.status,
            items_json = EXCLUDED.items_json,
            total_cost = EXCLUDED.total_cost,
            notes = EXCLUDED.notes,
            updated_at = NOW();
    END LOOP;
    
    RETURN jsonb_build_object('synced', TRUE, 'timestamp', NOW());
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 9. HELPER FUNCTION TO GET USER ID FROM CREW CODE
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_user_from_crew_code(p_crew_code TEXT)
RETURNS UUID AS $$
DECLARE
    v_user_id UUID;
BEGIN
    SELECT id INTO v_user_id
    FROM public.users
    WHERE crew_code = p_crew_code
    LIMIT 1;
    
    RETURN v_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 10. HELPER FUNCTION TO GET USER ID FROM USERNAME
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_user_from_username(p_username TEXT)
RETURNS UUID AS $$
DECLARE
    v_user_id UUID;
BEGIN
    SELECT id INTO v_user_id
    FROM public.users
    WHERE username = p_username
    LIMIT 1;
    
    RETURN v_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
