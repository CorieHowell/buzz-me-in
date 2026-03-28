import { sveltekit } from '@sveltejs/kit/vite';
import tailwindcss from '@tailwindcss/vite';
import { defineConfig } from 'vite';
import path from 'path';

export default defineConfig({
  plugins: [tailwindcss(), sveltekit()],
  server: {
    port: process.env.PORT ? parseInt(process.env.PORT) : 5173,
    strictPort: !!process.env.PORT,
    fs: {
      allow: [
        path.resolve('..', '..', '..'),
      ]
    }
  }
});