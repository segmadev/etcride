import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    // Proxy API calls in dev to avoid CORS — adjust target to your XAMPP URL
    proxy: {
      '/api': {
        target: 'http://localhost/etcride',
        changeOrigin: true,
        rewrite: path => path,
      },
    },
  },
  build: {
    outDir: 'dist',
    sourcemap: false,
  },
});
