-- ================================================================
-- BINGO STAR ONLINE
-- Script SQL completo para Supabase
-- Ve a: Supabase → SQL Editor → New Query → pega todo → Run
-- ================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ────────────────────────────────────────
-- TABLA 1: CONFIGURACIÓN GLOBAL
-- ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS configuracion (
  id             SERIAL PRIMARY KEY,
  precio_carton  DECIMAL(10,2) NOT NULL DEFAULT 10.00,
  limite_cartones INTEGER      NOT NULL DEFAULT 300,
  voz_genero     TEXT          NOT NULL DEFAULT 'female'
                   CHECK (voz_genero IN ('male','female')),
  pm_banco       TEXT          NOT NULL DEFAULT 'Tu Banco',
  pm_titular     TEXT          NOT NULL DEFAULT 'Tu Nombre',
  pm_cedula      TEXT          NOT NULL DEFAULT 'V-00000000',
  pm_telefono    TEXT          NOT NULL DEFAULT '0412-0000000',
  admin_pwd_hash TEXT          NOT NULL DEFAULT 'star2025',
  partida_activa_id UUID,      -- puntero a la ÚNICA partida activa (evita que se creen 2 partidas por accidente)
  updated_at     TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

INSERT INTO configuracion (id) VALUES (1)
  ON CONFLICT (id) DO NOTHING;

-- ────────────────────────────────────────
-- TABLA 2: PARTIDAS
-- ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS partidas (
  id              UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
  nombre          TEXT         NOT NULL DEFAULT 'Partida Principal',
  estado          TEXT         NOT NULL DEFAULT 'esperando'
                    CHECK (estado IN ('esperando','jugando','pausado','finalizado')),
  total_cartones  INTEGER      NOT NULL DEFAULT 0,
  precio_carton   DECIMAL(10,2) NOT NULL DEFAULT 10.00,
  limite_cartones INTEGER      NOT NULL DEFAULT 300,
  intervalo_seg   INTEGER      NOT NULL DEFAULT 8,
  voz_genero      TEXT         NOT NULL DEFAULT 'female',
  hora_inicio_prog TIMESTAMPTZ,              -- hora programada para el próximo bingo (opcional, usada por el bot)
  avisos_enviados  INTEGER[]   NOT NULL DEFAULT '{}', -- minutos de aviso ya notificados por el bot (evita duplicados)
  created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ────────────────────────────────────────
-- TABLA 3: RONDAS
-- ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS rondas (
  id               UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  partida_id       UUID        NOT NULL REFERENCES partidas(id) ON DELETE CASCADE,
  numero_ronda     INTEGER     NOT NULL,
  nombre           TEXT        NOT NULL DEFAULT 'Ronda 1',
  modo             TEXT        NOT NULL DEFAULT 'lines'
                     CHECK (modo IN ('lines','corners','full','letter','letraL','letraT')),
  estado           TEXT        NOT NULL DEFAULT 'pendiente'
                     CHECK (estado IN ('pendiente','jugando','finalizado')),
  numeros_cantados INTEGER[]   NOT NULL DEFAULT '{}',
  numero_actual    INTEGER,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (partida_id, numero_ronda)
);

-- ────────────────────────────────────────
-- TABLA 4: JUGADORES
-- ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS jugadores (
  id                  UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  nombre              TEXT        NOT NULL,
  apellido            TEXT        NOT NULL DEFAULT '',
  celular             TEXT        NOT NULL,               -- WhatsApp, para contactarlo
  telefono_pago_movil TEXT,                                -- número con el que paga (para cuadrar con el banco). ÚNICO: 1 persona = 1 número.
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Un mismo número de Pago Móvil no puede pertenecer a 2 jugadores distintos
CREATE UNIQUE INDEX IF NOT EXISTS idx_jugadores_pm_unico
  ON jugadores(telefono_pago_movil)
  WHERE telefono_pago_movil IS NOT NULL;

-- Migración segura para quien YA había corrido este script antes
ALTER TABLE jugadores ADD COLUMN IF NOT EXISTS apellido TEXT NOT NULL DEFAULT '';
ALTER TABLE jugadores ADD COLUMN IF NOT EXISTS telefono_pago_movil TEXT;

-- ────────────────────────────────────────
-- TABLA 5: CARTONES 5x5
-- Columnas B I N G O guardadas en JSON
-- Ejemplo: [[1,7,13,2,9],[16,22,28,17,24],[31,0,42,35,38],...]
-- El 0 en posición N[2] = LIBRE
-- ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS cartones (
  id         UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  partida_id UUID        NOT NULL REFERENCES partidas(id) ON DELETE CASCADE,
  jugador_id UUID        NOT NULL REFERENCES jugadores(id),
  numeros    JSONB       NOT NULL,
  marcados   INTEGER[]   NOT NULL DEFAULT '{}',
  pagado     BOOLEAN     NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ────────────────────────────────────────
-- TABLA 6: DEPÓSITOS / PAGO MÓVIL
-- ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS depositos (
  id                UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  partida_id        UUID        NOT NULL REFERENCES partidas(id) ON DELETE CASCADE,
  jugador_id        UUID        REFERENCES jugadores(id),
  nombre            TEXT        NOT NULL,
  celular           TEXT        NOT NULL,
  referencia        TEXT        NOT NULL,
  cantidad_cartones INTEGER     NOT NULL DEFAULT 1,
  monto_bs          DECIMAL(10,2) NOT NULL,  -- monto ESPERADO (cantidad_cartones × precio_carton, lo calcula el sistema)
  monto_declarado   DECIMAL(10,2),           -- monto que la persona dice haber pagado (para comparar con el banco)
  estado            TEXT        NOT NULL DEFAULT 'pendiente'
                      CHECK (estado IN ('pendiente','aprobado','rechazado','expirado')),
  expira_at         TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '10 minutes'),
  nota              TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Migración segura para quien YA había corrido este script antes
ALTER TABLE depositos ADD COLUMN IF NOT EXISTS monto_declarado DECIMAL(10,2);
ALTER TABLE depositos ADD COLUMN IF NOT EXISTS comprobante_url TEXT; -- foto del comprobante de pago

-- Índice único para evitar referencia duplicada por partida
CREATE UNIQUE INDEX IF NOT EXISTS idx_depositos_ref_unica
  ON depositos(partida_id, referencia)
  WHERE estado NOT IN ('rechazado','expirado');

-- ────────────────────────────────────────
-- STORAGE: bucket para las fotos de comprobante
-- ────────────────────────────────────────
-- Bucket público (así el bot de Telegram puede reenviar la foto por URL directa,
-- y el panel admin puede mostrarla). Nadie puede "listar" el bucket, solo acceder
-- a una foto si conoce su URL exacta (que solo guarda el sistema).
INSERT INTO storage.buckets (id, name, public)
VALUES ('comprobantes', 'comprobantes', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "comprobantes_insert_publico" ON storage.objects;
CREATE POLICY "comprobantes_insert_publico"
  ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'comprobantes');

DROP POLICY IF EXISTS "comprobantes_lectura_publica" ON storage.objects;
CREATE POLICY "comprobantes_lectura_publica"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'comprobantes');

-- ────────────────────────────────────────
-- TABLA 7: GANADORES (historial)
-- ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS ganadores (
  id                     UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  partida_id             UUID        NOT NULL REFERENCES partidas(id) ON DELETE CASCADE,
  ronda_id               UUID        NOT NULL REFERENCES rondas(id) ON DELETE CASCADE,
  jugador_id             UUID        REFERENCES jugadores(id),
  carton_id              UUID        REFERENCES cartones(id),
  nombre_jugador         TEXT        NOT NULL,
  patron                 TEXT        NOT NULL,
  numero_cierre          INTEGER     NOT NULL,
  numeros_cantados_count INTEGER     NOT NULL,
  premio_bs              DECIMAL(10,2) NOT NULL,
  bote_total_bs          DECIMAL(10,2) NOT NULL,
  created_at             TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ────────────────────────────────────────
-- TABLA 8: CONFIGURACIÓN DEL BOT DE TELEGRAM
-- ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS telegram_config (
  id             SERIAL      PRIMARY KEY,
  chat_id        TEXT,                          -- ID del grupo/canal de Telegram donde vive el bot
  activo         BOOLEAN     NOT NULL DEFAULT true,
  minutos_aviso  INTEGER[]   NOT NULL DEFAULT '{30,10,5}', -- avisos "comienza en X minutos"
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO telegram_config (id) VALUES (1)
  ON CONFLICT (id) DO NOTHING;

-- Migración segura para quien YA había corrido este script antes
-- (agrega la columna solo si no existe; no borra nada)
ALTER TABLE configuracion ADD COLUMN IF NOT EXISTS partida_activa_id UUID;

-- ────────────────────────────────────────
-- TRIGGERS updated_at
-- ────────────────────────────────────────
CREATE OR REPLACE FUNCTION _set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$;

DO $$
DECLARE t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY['partidas','rondas','depositos','configuracion','telegram_config']
  LOOP
    EXECUTE format('
      DROP TRIGGER IF EXISTS trg_%s_upd ON %s;
      CREATE TRIGGER trg_%s_upd
        BEFORE UPDATE ON %s
        FOR EACH ROW EXECUTE FUNCTION _set_updated_at();
    ',t,t,t,t);
  END LOOP;
END; $$;

-- ────────────────────────────────────────
-- EXPIRAR DEPÓSITOS AUTOMÁTICAMENTE
-- ────────────────────────────────────────
CREATE OR REPLACE FUNCTION expirar_depositos()
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  UPDATE depositos
  SET estado = 'expirado', updated_at = NOW()
  WHERE estado = 'pendiente' AND expira_at < NOW();
END;
$$;

-- ────────────────────────────────────────
-- ROW LEVEL SECURITY
-- ────────────────────────────────────────
ALTER TABLE configuracion ENABLE ROW LEVEL SECURITY;
ALTER TABLE partidas      ENABLE ROW LEVEL SECURITY;
ALTER TABLE rondas        ENABLE ROW LEVEL SECURITY;
ALTER TABLE jugadores     ENABLE ROW LEVEL SECURITY;
ALTER TABLE cartones      ENABLE ROW LEVEL SECURITY;
ALTER TABLE depositos     ENABLE ROW LEVEL SECURITY;
ALTER TABLE ganadores     ENABLE ROW LEVEL SECURITY;
ALTER TABLE telegram_config ENABLE ROW LEVEL SECURITY;

-- Lectura pública
CREATE POLICY "lee_config"     ON configuracion FOR SELECT USING (true);
CREATE POLICY "lee_partidas"   ON partidas      FOR SELECT USING (true);
CREATE POLICY "lee_rondas"     ON rondas        FOR SELECT USING (true);
CREATE POLICY "lee_jugadores"  ON jugadores     FOR SELECT USING (true);
CREATE POLICY "lee_cartones"   ON cartones      FOR SELECT USING (true);
CREATE POLICY "lee_depositos"  ON depositos     FOR SELECT USING (true);
CREATE POLICY "lee_ganadores"  ON ganadores     FOR SELECT USING (true);
CREATE POLICY "lee_telegram"   ON telegram_config FOR SELECT USING (true);

-- Escritura jugadores (anon)
CREATE POLICY "ins_jugadores"  ON jugadores  FOR INSERT WITH CHECK (true);
CREATE POLICY "ins_cartones"   ON cartones   FOR INSERT WITH CHECK (true);
CREATE POLICY "ins_depositos"  ON depositos  FOR INSERT WITH CHECK (true);
CREATE POLICY "upd_cartones"   ON cartones   FOR UPDATE USING (true);
CREATE POLICY "del_cartones"   ON cartones   FOR DELETE USING (true);

-- Admin (service_role tiene acceso total por defecto).
-- NOTA DE SEGURIDAD: estas políticas usan USING(true), igual que el proyecto original,
-- lo que significa que la llave "anon" también puede escribir en estas tablas si alguien
-- conoce tu SUPABASE_URL/KEY. El panel admin está protegido solo por la URL secreta
-- (#adminmm) y una contraseña en la app, no por RLS. Es aceptable para un bingo privado
-- entre conocidos, pero si compartes el proyecto públicamente considera restringir esto
-- con Supabase Auth o políticas basadas en un rol "admin" real.
CREATE POLICY "admin_partidas"  ON partidas  FOR ALL USING (true);
CREATE POLICY "admin_rondas"    ON rondas    FOR ALL USING (true);
CREATE POLICY "admin_depositos" ON depositos FOR ALL USING (true);
CREATE POLICY "admin_ganadores" ON ganadores FOR ALL USING (true);
CREATE POLICY "admin_config"    ON configuracion FOR ALL USING (true);
CREATE POLICY "admin_telegram"  ON telegram_config FOR ALL USING (true);

-- ────────────────────────────────────────
-- REALTIME
-- ────────────────────────────────────────
ALTER PUBLICATION supabase_realtime ADD TABLE partidas;
ALTER PUBLICATION supabase_realtime ADD TABLE rondas;
ALTER PUBLICATION supabase_realtime ADD TABLE depositos;
ALTER PUBLICATION supabase_realtime ADD TABLE ganadores;
ALTER PUBLICATION supabase_realtime ADD TABLE configuracion;
ALTER PUBLICATION supabase_realtime ADD TABLE jugadores;
ALTER PUBLICATION supabase_realtime ADD TABLE cartones;
ALTER PUBLICATION supabase_realtime ADD TABLE telegram_config;

-- ────────────────────────────────────────
-- ÍNDICES
-- ────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_rondas_partida    ON rondas(partida_id);
CREATE INDEX IF NOT EXISTS idx_cartones_partida  ON cartones(partida_id);
CREATE INDEX IF NOT EXISTS idx_cartones_jugador  ON cartones(jugador_id);
CREATE INDEX IF NOT EXISTS idx_depositos_partida ON depositos(partida_id);
CREATE INDEX IF NOT EXISTS idx_depositos_estado  ON depositos(estado);
CREATE INDEX IF NOT EXISTS idx_depositos_celular ON depositos(celular);
CREATE INDEX IF NOT EXISTS idx_ganadores_partida ON ganadores(partida_id);
CREATE INDEX IF NOT EXISTS idx_ganadores_ronda   ON ganadores(ronda_id);

-- ────────────────────────────────────────
-- VISTAS
-- ────────────────────────────────────────
CREATE OR REPLACE VIEW vista_depositos_pendientes AS
SELECT
  d.id, d.nombre, d.celular, d.referencia,
  d.cantidad_cartones, d.monto_bs, d.estado,
  d.expira_at, d.created_at, p.nombre AS partida
FROM depositos d
JOIN partidas p ON p.id = d.partida_id
WHERE d.estado = 'pendiente'
ORDER BY d.created_at ASC;

CREATE OR REPLACE VIEW vista_ganadores AS
SELECT
  g.id, p.nombre AS partida, ro.nombre AS ronda, ro.modo,
  g.nombre_jugador, g.patron, g.numero_cierre,
  g.numeros_cantados_count AS bolas_usadas,
  g.premio_bs, g.bote_total_bs, g.created_at
FROM ganadores g
JOIN partidas p  ON p.id  = g.partida_id
JOIN rondas   ro ON ro.id = g.ronda_id
ORDER BY g.created_at DESC;

CREATE OR REPLACE VIEW vista_resumen_partida AS
SELECT
  p.id, p.nombre, p.estado,
  p.total_cartones, p.precio_carton, p.limite_cartones,
  ROUND(p.total_cartones * p.precio_carton, 2)       AS ingresos_bs,
  ROUND(p.total_cartones * p.precio_carton * 0.9, 2) AS bote_bs,
  ROUND(p.total_cartones * p.precio_carton * 0.1, 2) AS casa_bs,
  (SELECT COUNT(*) FROM rondas  r WHERE r.partida_id=p.id)                              AS total_rondas,
  (SELECT COUNT(*) FROM rondas  r WHERE r.partida_id=p.id AND r.estado='finalizado')    AS rondas_completadas,
  (SELECT COUNT(*) FROM depositos d WHERE d.partida_id=p.id AND d.estado='pendiente')   AS pagos_pendientes,
  (SELECT COUNT(*) FROM depositos d WHERE d.partida_id=p.id AND d.estado='aprobado')    AS pagos_aprobados,
  p.created_at
FROM partidas p;

-- NOTA: no se inserta ninguna partida de ejemplo. La app (index.html) crea
-- automáticamente una partida nueva con sus 3 rondas por defecto la primera
-- vez que alguien la abre y no encuentra ninguna partida activa.

-- ================================================================
-- ✅ LISTO. Ahora conecta en tu index.html:
--
-- 1. Ve a Supabase → Settings → API
-- 2. Copia "Project URL"        → SUPABASE_URL
-- 3. Copia "anon public" key    → SUPABASE_KEY
-- 4. Pégalos al inicio del <script> en index.html (busca SUPABASE_URL / SUPABASE_KEY)
--
-- Para el BOT DE TELEGRAM necesitas además:
-- 5. Copia "service_role" key (Settings → API → service_role, es SECRETA,
--    nunca la pongas en index.html ni la subas a un repo público)
--    → se usa solo en el bot (Railway/Render), como SUPABASE_SERVICE_KEY
-- ================================================================
