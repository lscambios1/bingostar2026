# 🚀 GUÍA COMPLETA — BINGO STAR ONLINE

Tienes 3 piezas que conectar entre sí:

1. **Supabase** — la base de datos (guarda partidas, cartones, pagos, ganadores).
2. **Vercel** — donde vive la página web del bingo (`index.html`).
3. **Telegram bot** — corre 24/7 en Railway o Render, avisa el inicio,
   canta los números en vivo y anuncia al ganador en tu grupo.

Sigue los pasos en orden — Supabase primero, porque tanto la web como el
bot dependen de él.

---

## PARTE 1 — SUPABASE (la base de datos)

1. Ve a https://supabase.com → crea una cuenta gratis → **New Project**.
   - Elige una contraseña de base de datos y guárdala (no la necesitas para
     esto, pero por si acaso).
2. Cuando el proyecto termine de crearse, ve a **SQL Editor → New Query**.
3. Abre el archivo `bingo_star_online_schema.sql` de esta entrega, copia
   **todo** el contenido y pégalo en el editor.
4. Clic en **Run**. Deberías ver "Success. No rows returned" — eso confirma
   que se crearon las tablas.
5. Ve a **Settings → API** y copia dos cosas (las vas a necesitar en el
   Paso 2):
   - **Project URL**
   - **anon public** key

---

## PARTE 2 — LA PÁGINA WEB (Vercel)

### 2.1 — Conecta `index.html` con Supabase
1. Abre `index.html` con cualquier editor de texto.
2. Busca estas dos líneas cerca del inicio del `<script>`:
   ```js
   var SUPABASE_URL = 'https://TU-PROYECTO.supabase.co';
   var SUPABASE_KEY = 'TU-ANON-PUBLIC-KEY';
   ```
3. Reemplaza con los valores que copiaste en la Parte 1 (Project URL y
   anon public key). Guarda el archivo.

### 2.2 — Sube a Vercel
1. Ve a https://vercel.com → Sign Up → "Continue with GitHub".
2. Ve a https://vercel.com/new
3. Arrastra la carpeta con `index.html` y `vercel.json` (o sube por GitHub
   si prefieres actualizaciones automáticas — crea un repo, sube los
   archivos, e "Import Git Repository" en Vercel).
4. Clic en **Deploy**. En ~30 segundos tienes tu URL, algo como:
   `https://bingo-star-online.vercel.app`

### 2.3 — Panel de administración
Para entrar al panel admin ve a:
```
https://bingo-star-online.vercel.app/#adminmm
```
⚠️ Guarda esa URL en un lugar seguro y no la compartas — es la puerta de
entrada al panel donde apruebas pagos, controlas el sorteo y cambias la
configuración. La contraseña por defecto es `star2025`; cámbiala en el
panel apenas entres (📢 sección "🔐 Seguridad" o similar).

---

## PARTE 3 — EL BOT DE TELEGRAM

Instrucciones completas en `telegram-bot/README.md`. En resumen:

1. Crea el bot con **@BotFather** en Telegram (te da un token).
2. Agrega el bot a tu grupo/canal y usa `/chatid` para obtener el Chat ID.
3. Despliega la carpeta `telegram-bot/` en **Railway** o **Render**
   (necesita correr 24/7 — Vercel no sirve para esto, solo para la web).
4. Configura las variables de entorno: `TELEGRAM_BOT_TOKEN`,
   `SUPABASE_URL`, `SUPABASE_SERVICE_KEY` (esta es la clave `service_role`
   de Supabase, distinta a la `anon` que usa la web — la consigues en
   Settings → API).
5. Pega el Chat ID en el panel admin de la web, sección **📢 Telegram**.

Una vez desplegado, el bot solo, sin que hagas nada más:
- Avisa "comienza en X minutos" según la hora que programes en el admin.
- Va cantando cada número en vivo en el grupo mientras corre la partida.
- Anuncia al ganador con su premio apenas se detecta un bingo.

---

## ✅ CHECKLIST ANTES DE LANZAR

- [ ] Corriste el script SQL en Supabase y no dio error
- [ ] Pegaste SUPABASE_URL / SUPABASE_KEY en `index.html`
- [ ] La web está desplegada en Vercel
- [ ] Entraste al admin (`/#adminmm`) y cambiaste la contraseña
- [ ] Configuraste el precio por cartón y los datos de Pago Móvil
- [ ] Configuraste las rondas (cuántas y qué modo: líneas / esquinas / cartón lleno)
- [ ] Creaste el bot en @BotFather y lo agregaste a tu grupo de Telegram
- [ ] Desplegaste `telegram-bot/` en Railway o Render con sus variables de entorno
- [ ] Pegaste el Chat ID en el panel admin (sección 📢 Telegram)
- [ ] Hiciste una prueba completa: comprar un cartón desde otra pestaña,
      aprobar el pago desde el admin, programar una hora de inicio y
      verificar que el bot avisa, inicia el juego y confirma que el bot
      canta los números y anuncia al ganador

## 📲 INSTALAR LA APP EN EL CELULAR (sin Play Store ni App Store)

La web ahora funciona como una **app instalable (PWA)**. En la pantalla de
inicio aparece un botón **"📲 Instalar App en tu celular"**:

- **Android/Chrome:** al tocarlo, el navegador pregunta si quieres instalarla.
  Le queda un ícono en la pantalla de inicio como cualquier app normal.
- **iPhone/iPad (Safari):** Apple no permite instalar con un solo toque, así
  que el botón muestra instrucciones: tocar "Compartir" ⬆️ → "Agregar a
  Inicio" → "Agregar".

No necesitas subir nada a Play Store ni a App Store — la gente instala
directo desde el link de tu web. Asegúrate de subir también los archivos
`manifest.json`, `sw.js`, `icon-192.png`, `icon-512.png`,
`icon-512-maskable.png` y `apple-touch-icon.png` junto con `index.html` en
Vercel (deben quedar todos en la misma carpeta/nivel).

## 📱 CÓMO COMPARTIR CON LOS JUGADORES
Solo envíales el link de la web:
```
https://bingo-star-online.vercel.app
```
Pueden abrirlo desde el celular sin descargar nada. La transmisión en vivo
del sorteo (números cantados y ganador) la ven directamente en el grupo de
Telegram donde vive el bot.
