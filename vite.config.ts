import tailwindcss from '@tailwindcss/vite'
import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'
import { VitePWA } from 'vite-plugin-pwa'

// GitHub Pages serves the app under /<repo>/. Set BASE=/<repo>/ when building for it.
const base = process.env.BASE ?? '/'

export default defineConfig({
  base,
  server: { host: true },
  plugins: [
    react(),
    tailwindcss(),
    VitePWA({
      // A custom service worker is needed to receive Web Push and open the app from a notification.
      strategies: 'injectManifest',
      srcDir: 'src',
      filename: 'sw.ts',
      registerType: 'autoUpdate',
      includeAssets: ['icon.svg', 'apple-touch-icon.png'],
      manifest: {
        name: 'Akşam Notu',
        short_name: 'Akşam Notu',
        description: 'Yatmadan önce üç satır: açıkta kalan problem, yarın atacağım ilk adım, bugün alarm çaldı mı.',
        lang: 'tr',
        display: 'standalone',
        orientation: 'portrait',
        background_color: '#0d100f',
        theme_color: '#173f37',
        start_url: base,
        scope: base,
        icons: [
          { src: 'pwa-192.png', sizes: '192x192', type: 'image/png' },
          { src: 'pwa-512.png', sizes: '512x512', type: 'image/png' },
          { src: 'pwa-512.png', sizes: '512x512', type: 'image/png', purpose: 'maskable' },
        ],
      },
      injectManifest: {
        globPatterns: ['**/*.{js,css,html,svg,png,woff2}'],
      },
    }),
  ],
})
