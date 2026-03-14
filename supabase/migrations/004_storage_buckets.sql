-- ============================================================
-- SUPABASE STORAGE BUCKET CONFIGURATION
-- For PDFs, Images, and Work Order Sheets
-- ============================================================

-- ============================================================
-- 1. CREATE STORAGE BUCKETS
-- ============================================================

-- Note: Storage buckets are typically created via the Supabase Dashboard or API
-- This script sets up the necessary policies and configurations

-- Insert bucket configurations (run via Supabase Dashboard SQL editor or API)
-- The storage schema is separate from public schema

-- Create PDFs bucket for estimate/invoice PDFs
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'estimate-pdfs',
    'estimate-pdfs',
    FALSE,  -- Private bucket
    10485760,  -- 10MB limit
    ARRAY['application/pdf']::TEXT[]
)
ON CONFLICT (id) DO NOTHING;

-- Create images bucket for site photos and logos
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'site-images',
    'site-images',
    FALSE,  -- Private bucket
    52428800,  -- 50MB limit
    ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp']::TEXT[]
)
ON CONFLICT (id) DO NOTHING;

-- Create work-orders bucket for work order sheets
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'work-orders',
    'work-orders',
    FALSE,  -- Private bucket
    10485760,  -- 10MB limit
    ARRAY['application/pdf', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 'application/vnd.ms-excel']::TEXT[]
)
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- 2. STORAGE RLS POLICIES
-- ============================================================

-- Enable RLS on storage.objects
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- PDFs Bucket Policies
-- ============================================================

-- Users can view their own PDFs
CREATE POLICY "Users can view own PDFs"
    ON storage.objects FOR SELECT
    USING (
        bucket_id = 'estimate-pdfs'
        AND (storage.foldername(name))[1] = auth.uid()::TEXT
    );

-- Users can upload their own PDFs
CREATE POLICY "Users can upload own PDFs"
    ON storage.objects FOR INSERT
    WITH CHECK (
        bucket_id = 'estimate-pdfs'
        AND (storage.foldername(name))[1] = auth.uid()::TEXT
    );

-- Users can update their own PDFs
CREATE POLICY "Users can update own PDFs"
    ON storage.objects FOR UPDATE
    USING (
        bucket_id = 'estimate-pdfs'
        AND (storage.foldername(name))[1] = auth.uid()::TEXT
    );

-- Users can delete their own PDFs
CREATE POLICY "Users can delete own PDFs"
    ON storage.objects FOR DELETE
    USING (
        bucket_id = 'estimate-pdfs'
        AND (storage.foldername(name))[1] = auth.uid()::TEXT
    );

-- ============================================================
-- Images Bucket Policies
-- ============================================================

-- Users can view their own images
CREATE POLICY "Users can view own images"
    ON storage.objects FOR SELECT
    USING (
        bucket_id = 'site-images'
        AND (
            (storage.foldername(name))[1] = auth.uid()::TEXT
            OR (storage.foldername(name))[1] = 'logos'
        )
    );

-- Users can upload their own images
CREATE POLICY "Users can upload own images"
    ON storage.objects FOR INSERT
    WITH CHECK (
        bucket_id = 'site-images'
        AND (
            (storage.foldername(name))[1] = auth.uid()::TEXT
            OR (storage.foldername(name))[1] = 'logos'
        )
    );

-- Users can update their own images
CREATE POLICY "Users can update own images"
    ON storage.objects FOR UPDATE
    USING (
        bucket_id = 'site-images'
        AND (
            (storage.foldername(name))[1] = auth.uid()::TEXT
            OR (storage.foldername(name))[1] = 'logos'
        )
    );

-- Users can delete their own images
CREATE POLICY "Users can delete own images"
    ON storage.objects FOR DELETE
    USING (
        bucket_id = 'site-images'
        AND (
            (storage.foldername(name))[1] = auth.uid()::TEXT
            OR (storage.foldername(name))[1] = 'logos'
        )
    );

-- ============================================================
-- Work Orders Bucket Policies
-- ============================================================

-- Users can view their own work orders
CREATE POLICY "Users can view own work orders"
    ON storage.objects FOR SELECT
    USING (
        bucket_id = 'work-orders'
        AND (storage.foldername(name))[1] = auth.uid()::TEXT
    );

-- Users can upload their own work orders
CREATE POLICY "Users can upload own work orders"
    ON storage.objects FOR INSERT
    WITH CHECK (
        bucket_id = 'work-orders'
        AND (storage.foldername(name))[1] = auth.uid()::TEXT
    );

-- Users can update their own work orders
CREATE POLICY "Users can update own work orders"
    ON storage.objects FOR UPDATE
    USING (
        bucket_id = 'work-orders'
        AND (storage.foldername(name))[1] = auth.uid()::TEXT
    );

-- Users can delete their own work orders
CREATE POLICY "Users can delete own work orders"
    ON storage.objects FOR DELETE
    USING (
        bucket_id = 'work-orders'
        AND (storage.foldername(name))[1] = auth.uid()::TEXT
    );

-- ============================================================
-- 3. STORAGE FUNCTIONS FOR FILE OPERATIONS
-- ============================================================

-- Function to get a signed URL for a file
CREATE OR REPLACE FUNCTION public.get_signed_url(
    p_bucket TEXT,
    p_path TEXT,
    p_expiry_seconds INTEGER DEFAULT 3600
)
RETURNS TEXT AS $$
DECLARE
    v_signed_url TEXT;
BEGIN
    -- This requires the storage extension
    -- In practice, use the Supabase JS client for signed URLs
    -- This is a placeholder for database-level access
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to delete a file from storage
CREATE OR REPLACE FUNCTION public.delete_storage_file(
    p_bucket TEXT,
    p_path TEXT
)
RETURNS BOOLEAN AS $$
BEGIN
    DELETE FROM storage.objects
    WHERE bucket_id = p_bucket AND name = p_path;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to move a file within storage
CREATE OR REPLACE FUNCTION public.move_storage_file(
    p_bucket TEXT,
    p_from_path TEXT,
    p_to_path TEXT
)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE storage.objects
    SET name = p_to_path
    WHERE bucket_id = p_bucket AND name = p_from_path;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get file metadata
CREATE OR REPLACE FUNCTION public.get_file_metadata(
    p_bucket TEXT,
    p_path TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_file RECORD;
BEGIN
    SELECT * INTO v_file
    FROM storage.objects
    WHERE bucket_id = p_bucket AND name = p_path;
    
    IF v_file IS NULL THEN
        RETURN NULL;
    END IF;
    
    RETURN jsonb_build_object(
        'name', v_file.name,
        'bucketId', v_file.bucket_id,
        'owner', v_file.owner,
        'size', v_file.metadata->>'size',
        'mimeType', v_file.metadata->>'mimetype',
        'uploadedAt', v_file.created_at,
        'updatedAt', v_file.updated_at
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 4. TRIGGER TO CLEAN UP STORAGE ON USER DELETE
-- ============================================================

-- Function to clean up user's storage files when user is deleted
CREATE OR REPLACE FUNCTION public.cleanup_user_storage()
RETURNS TRIGGER AS $$
BEGIN
    -- Delete all files from estimate-pdfs bucket
    DELETE FROM storage.objects
    WHERE bucket_id = 'estimate-pdfs'
      AND (storage.foldername(name))[1] = OLD.auth_user_id::TEXT;
    
    -- Delete all files from site-images bucket
    DELETE FROM storage.objects
    WHERE bucket_id = 'site-images'
      AND (storage.foldername(name))[1] = OLD.auth_user_id::TEXT;
    
    -- Delete all files from work-orders bucket
    DELETE FROM storage.objects
    WHERE bucket_id = 'work-orders'
      AND (storage.foldername(name))[1] = OLD.auth_user_id::TEXT;
    
    RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger on users table delete
CREATE TRIGGER on_user_delete_cleanup_storage
    AFTER DELETE ON public.users
    FOR EACH ROW EXECUTE FUNCTION public.cleanup_user_storage();

-- ============================================================
-- 5. STORAGE USAGE VIEW
-- ============================================================

-- View to show storage usage per user
CREATE OR REPLACE VIEW public.storage_usage AS
SELECT 
    (storage.foldername(name))[1] AS user_folder,
    bucket_id,
    COUNT(*) AS file_count,
    SUM((metadata->>'size')::BIGINT) AS total_bytes
FROM storage.objects
GROUP BY (storage.foldername(name))[1], bucket_id;

-- ============================================================
-- NOTES FOR BUCKET CREATION
-- ============================================================

-- IMPORTANT: Storage buckets must be created via:
-- 1. Supabase Dashboard -> Storage -> Create Bucket
-- 2. Or via Supabase Management API
--
-- After creating buckets via dashboard, run the policy statements above
--
-- Bucket naming convention:
-- - estimate-pdfs: For generated PDF estimates and invoices
-- - site-images: For site photos and company logos
-- - work-orders: For work order spreadsheets and documents
--
-- Folder structure within buckets:
-- /{user_id}/estimates/{estimate_id}/{filename}
-- /{user_id}/customers/{customer_id}/{filename}
-- /{user_id}/site-photos/{estimate_id}/{filename}
-- /logos/{user_id}/{filename}
