
// Supabase Configuration
declare const process: { env: { [key: string]: string | undefined } };

export const SUPABASE_CONFIGURED = Boolean(
  typeof window !== 'undefined' && 
  (window as any).VITE_SUPABASE_URL && 
  (window as any).VITE_SUPABASE_ANON_KEY
);

// Legacy Google Apps Script URL (kept for migration reference)
// export const GOOGLE_SCRIPT_URL: string = 'https://script.google.com/macros/s/.../exec';

