import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react()],
  base: process.env.NODE_ENV === 'production' ? '/poppiesgame/' : '/',
  server: {
    host: true,
    open: false,
  },
  build: {
    outDir: './dist',
    emptyOutDir: true,
    sourcemap: false,
  },
  define: {
    global: 'globalThis',
  },
  optimizeDeps: {
    include: ['buffer'],
  },
});