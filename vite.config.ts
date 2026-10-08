import tailwindcss from '@tailwindcss/vite'
import react from '@vitejs/plugin-react'
import { defineConfig, type Plugin } from 'vite'
import { VitePWA } from 'vite-plugin-pwa'

// GitHub Pages serves the app under /<repo>/. Set BASE=/<repo>/ when building for it.
const base = process.env.BASE ?? '/'

/**
 * The published app may only talk to its own origin. Even if a dependency misbehaved,
 * the browser would refuse to send notes anywhere else. Build only: the dev server needs inline scripts.
 */
const csp = [
  "default-src 'self'",
  "script-src 'self'",
  "style-src 'self'",
  "img-src 'self' data: blob:",
  "font-src 'self'",
  "connect-src 'self'",
  "manifest-src 'self'",
  "worker-src 'self'",
  "object-src 'none'",
  "base-uri 'self'",
  "form-action 'none'",
].join('; ')

const securityHeaders: Plugin = {
  name: 'security-meta',
  apply: 'build',
  transformIndexHtml: () => [
    { tag: 'meta', attrs: { 'http-equiv': 'Content-Security-Policy', content: csp }, injectTo: 'head-prepend' },
    { tag: 'meta', attrs: { name: 'referrer', content: 'no-referrer' }, injectTo: 'head-prepend' },
  ],
}

export default defineConfig({
  base,
  server: { host: true },
  plugins: [
    react(),
    tailwindcss(),
    securityHeaders,
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
