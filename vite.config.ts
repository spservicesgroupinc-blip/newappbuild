import path from 'path';
import { defineConfig, loadEnv } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig(({ mode }) => {
    const env = loadEnv(mode, '.', '');
    return {
      server: {
        port: 3000,
        host: '0.0.0.0',
      },
      plugins: [react()],
      define: {
        'process.env.API_KEY': JSON.stringify(env.GEMINI_API_KEY),
        'process.env.GEMINI_API_KEY': JSON.stringify(env.GEMINI_API_KEY),
        // Vercel environment variables
        'process.env.VERCEL': JSON.stringify(env.VERCEL),
        'process.env.VERCEL_ENV': JSON.stringify(env.VERCEL_ENV),
        'process.env.VERCEL_URL': JSON.stringify(env.VERCEL_URL)
      },
      resolve: {
        alias: {
          '@': path.resolve(__dirname, '.'),
        }
      },
      // Vercel build optimizations
      build: {
        outDir: 'dist',
        sourcemap: mode === 'production',
        minify: 'esbuild',
        target: 'esnext',
        rollupOptions: {
          output: {
            manualChunks: {
              vendor: ['react', 'react-dom'],
              supabase: ['@supabase/supabase-js'],
              pdf: ['jspdf', 'jspdf-autotable'],
              icons: ['lucide-react']
            }
          }
        }
      }
    };
});
