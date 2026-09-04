# 🤖 Bot de Telegram — Bingo Star Online

Este bot te escribe a TI, en privado. No publica nada en ningún grupo ni
canal. Cada vez que alguien reserva cartones y registra un pago, te llega
un mensaje con:

- Nombre del jugador
- Cuántos cartones pagó
- Cuánto dice haber pagado (y si cuadra con lo esperado)
- La referencia
- La foto del comprobante que adjuntó (el bot te la reenvía debajo del mensaje)

No necesita que le escribas nada — solo revisa la base de datos de Supabase
cada pocos segundos y te avisa automáticamente cuando hay un pago nuevo.

---

## PASO 1 — Crea el bot en Telegram

1. Abre Telegram y busca **@BotFather**.
2. Envíale `/newbot`, ponle un nombre (ej: `Bingo Star Online`) y un usuario
   que termine en `bot` (ej: `bingo_star_online_bot`).
3. BotFather te da un **token** parecido a `123456789:AAExampleToken...`.
   Guárdalo, lo vas a necesitar.

## PASO 2 — Consigue TU Chat ID (en privado, no en un grupo)

1. Busca tu bot por su usuario y ábrele un chat **privado** (uno a uno,
   como si fuera un contacto normal).
2. Escríbele `/start` y luego `/chatid`.
3. El bot te responde con tu Chat ID (un número, puede ser negativo).
   Cópialo — lo vas a pegar en el panel admin de la web (sección 📢 Telegram).

> ⚠️ No agregues el bot a ningún grupo. Todo funciona por privado entre tú
> y el bot.

## PASO 3 — Consigue tu Supabase Service Role Key

1. Ve a tu proyecto de Supabase → **Settings → API**.
2. Copia la clave **`service_role`** (NO la `anon public` — esa es la que usa
   la página web; el bot necesita la `service_role`, que es secreta).
3. Nunca la pongas en `index.html` ni la subas a un repositorio público.

## PASO 4 — Crea el bucket de comprobantes en Supabase

Si vas a correr (o ya corriste antes) `bingo_star_online_schema.sql`, esto
ya está incluido: crea el bucket público `comprobantes` y sus políticas de
acceso, para que las fotos de pago se puedan subir desde la web y el bot
las pueda reenviar por URL. Si ya habías corrido el schema antes de este
cambio, solo vuelve a correrlo — todas las migraciones son seguras
(`IF NOT EXISTS` / `ON CONFLICT DO NOTHING`) y no borran nada.

## PASO 5 — Despliega el bot (Railway o Render)

### Opción A — Railway (recomendado, más simple)
1. Ve a https://railway.app y crea una cuenta (puedes usar GitHub).
2. Click en **"New Project" → "Deploy from GitHub repo"** (sube esta carpeta
   `telegram-bot` a un repo de GitHub primero), o usa **"Empty Project"** y
   luego arrastra los archivos con la CLI de Railway.
3. En **Settings → Variables**, agrega:
   - `TELEGRAM_BOT_TOKEN` = el token de BotFather
   - `SUPABASE_URL` = la URL de tu proyecto Supabase
   - `SUPABASE_SERVICE_KEY` = tu service_role key
   - `CHECK_INTERVAL_SECONDS` = `15` (opcional, así viene por defecto)
4. Railway detecta automáticamente que es un proyecto Node.js (por el
   `package.json`) y ejecuta `npm install && npm start`.
5. Verifica en los "Logs" que veas: `🤖 Bot de Bingo Star Online iniciado.`

### Opción B — Render
1. Ve a https://render.com y crea una cuenta.
2. **New → Background Worker** (no "Web Service", porque este bot no expone
   ningún puerto HTTP, solo hace polling).
3. Conecta tu repo de GitHub con esta carpeta `telegram-bot`.
4. Build command: `npm install` — Start command: `npm start`.
5. Agrega las mismas variables de entorno del paso anterior en
   **Environment**.
6. Deploy. Revisa los logs para confirmar que arrancó bien.

## PASO 6 — Prueba

1. En el panel admin de la web (`/#adminmm`), ve a la sección **📢 Telegram**
   y pega tu Chat ID (el que te dio `/chatid` por privado).
2. Desde el sitio (como jugador), reserva un cartón, pon una referencia y
   adjunta cualquier imagen como comprobante.
3. En unos segundos debe llegarte a ti, en privado, el mensaje con los
   datos del pago y la foto reenviada.

---

## Notas técnicas

- El bot usa **polling** (revisa la base de datos cada pocos segundos) en
  vez de esperar eventos en tiempo real — es más simple y muy confiable
  para este tamaño de proyecto. Por defecto revisa cada 15 segundos
  (`CHECK_INTERVAL_SECONDS`).
- Si reinicias el bot a mitad de una partida, no reenvía pagos viejos —
  solo detecta pagos nuevos a partir de que arranca.
- El bot ya NO anuncia cuenta regresiva, números cantados en vivo ni
  ganadores — esas transmisiones quedaron desactivadas a propósito, solo
  quedan los avisos de pago.
- Comandos disponibles: `/start`, `/chatid`.
