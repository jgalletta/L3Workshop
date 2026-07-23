import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import path from 'path';
import { resolve } from 'path';
import tailwindcss from '@tailwindcss/vite';

/**
 * Production build config for the UI bundle.
 *
 * Why this exists separately from vite.config.ts:
 * The @salesforce/vite-plugin-ui-bundle plugin calls getOrgInfo() (→
 * @salesforce/core Org.create) in its config() hook and awaits it with no
 * timeout. In some environments that org/auth init hangs indefinitely, which
 * silently stalls `vite build` (exit 0, no output, no dist). That plugin is
 * only needed for the DEV proxy/HMR and to define __SF_API_VERSION__ (which
 * this app doesn't consume — the platform injects SFDC_ENV at runtime).
 *
 * So the production build drops the org-dependent plugin. Output is identical
 * in shape to a plugin-built bundle: base './', relative asset URLs, dist/.
 * Dev still uses vite.config.ts (npm run dev) with the full plugin.
 */
export default defineConfig({
  base: './',
  define: {
    // Harmless fallback in case any transitive code references it.
    __SF_API_VERSION__: JSON.stringify('v62.0'),
  },
  plugins: [tailwindcss(), react()],
  build: {
    outDir: resolve(__dirname, 'dist'),
    assetsDir: 'assets',
    sourcemap: false,
    emptyOutDir: true,
  },
  resolve: {
    dedupe: ['react', 'react-dom'],
    alias: {
      '@': path.resolve(__dirname, './src'),
      '@api': path.resolve(__dirname, './src/api'),
      '@components': path.resolve(__dirname, './src/components'),
      '@utils': path.resolve(__dirname, './src/utils'),
      '@styles': path.resolve(__dirname, './src/styles'),
      '@assets': path.resolve(__dirname, './src/assets'),
    },
  },
});
