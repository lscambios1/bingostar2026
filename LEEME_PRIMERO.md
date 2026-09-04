# 📦 Bingo Star Online — Paquete completo

Este zip trae TODO el proyecto junto, pero ¡ojo! son **dos despliegues
separados** — no subas la carpeta completa a un solo lugar.

## Qué va dónde

| Carpeta / archivo                                              | Va en...              |
|------------------------------------------------------------------|------------------------|
| `index.html`, `vercel.json`, `manifest.json`, `sw.js`, `*.png`   | **Vercel** (la web — sube TODOS estos juntos, mismo nivel) |
| `bingo_star_online_schema.sql`                                   | **Supabase** (SQL Editor, una sola vez) |
| `telegram-bot/` (carpeta completa)                                | **Railway o Render** (el bot, corre 24/7) |
| `INSTRUCCIONES.md`                                                | Léelo, tiene la guía paso a paso completa |

## Antes de subir la web a Vercel

Abre `index.html` con un editor de texto simple, busca `SUPABASE_URL` cerca
del inicio del código, y confirma que tus valores reales de Supabase estén
ahí (Project URL y clave anon/publishable — Supabase → Settings → API).

## Novedad: la web ahora es instalable (PWA)

Sube `manifest.json`, `sw.js` y los `.png` junto con `index.html` — sin
ellos, el botón "Instalar App" no funcionará.

## Si algo no funciona

Revisa `INSTRUCCIONES.md` primero. Si sigue sin funcionar, abre la consola
del navegador (F12 → Console) y guarda cualquier error en rojo que aparezca.
