// ════════════════════════════════════════════════════════════════
// BINGO STAR ONLINE — Bot de Telegram (avisos de pago, en privado)
//
// Qué hace:
//  Cada vez que alguien reserva cartones y registra su pago, el bot
//  te manda a TI (en privado, no a ningún grupo) un mensaje con:
//  nombre del jugador, cuántos cartones pagó, cuánto pagó y la
//  referencia. Si además adjuntó una foto del comprobante, te la
//  reenvía justo debajo.
//
// El bot NO publica nada en grupos ni canales. El "chat_id" que
// configures en el panel admin debe ser TU chat privado con el bot
// (lo obtienes hablándole por privado y escribiendo /chatid).
//
// Corre por polling (revisa Supabase cada pocos segundos). Necesita
// correr 24/7 en un servicio como Railway o Render (Vercel NO sirve
// para esto).
// ════════════════════════════════════════════════════════════════
try{ require('dotenv').config(); }catch(e){ /* dotenv es opcional, Railway/Render inyectan las env vars directo */ }

const TelegramBot = require('node-telegram-bot-api');
const { createClient } = require('@supabase/supabase-js');

const BOT_TOKEN = process.env.TELEGRAM_BOT_TOKEN;
const SB_URL    = process.env.SUPABASE_URL;
const SB_KEY    = process.env.SUPABASE_SERVICE_KEY;
const POLL_MS   = (parseInt(process.env.CHECK_INTERVAL_SECONDS) || 15) * 1000;

if(!BOT_TOKEN || !SB_URL || !SB_KEY){
  console.error('❌ Faltan variables de entorno. Revisa TELEGRAM_BOT_TOKEN, SUPABASE_URL, SUPABASE_SERVICE_KEY.');
  process.exit(1);
}

const bot = new TelegramBot(BOT_TOKEN, { polling: true });
const sb  = createClient(SB_URL, SB_KEY);

function fBs(v){ return 'Bs. ' + parseFloat(v).toFixed(2).replace('.',','); }

// ── ESTADO EN MEMORIA (para no repetir avisos) ──────────────────
let lastPartidaId = null;
let lastDepositoTs = new Date().toISOString(); // arranca "ahora": no reenvía compras viejas al reiniciar el bot

async function getTelegramConfig(){
  const { data } = await sb.from('telegram_config').select('*').eq('id',1).maybeSingle();
  return data || { chat_id:null, activo:true };
}

async function getPartidaActiva(){
  const { data: cfg } = await sb.from('configuracion').select('partida_activa_id').eq('id',1).maybeSingle();
  if(!cfg || !cfg.partida_activa_id) return null;
  const { data } = await sb.from('partidas').select('*').eq('id', cfg.partida_activa_id).maybeSingle();
  return data;
}

async function getBancoReceptor(){
  const { data } = await sb.from('configuracion').select('pm_banco').eq('id',1).maybeSingle();
  return (data && data.pm_banco) || '—';
}

async function sendMsg(chatId, text){
  if(!chatId) return;
  try{ await bot.sendMessage(chatId, text, { parse_mode:'HTML' }); }
  catch(e){ console.error('Error enviando mensaje de Telegram:', e.message); }
}

// ── AVISOS DE PAGO (privado, solo a ti) ─────────────────────────
async function checkPagos(){
  try{
    const cfg = await getTelegramConfig();
    if(!cfg.chat_id || cfg.activo === false) return;
    const chatId = cfg.chat_id;

    const partida = await getPartidaActiva();
    if(!partida) return;

    // ── cambio de partida activa: no repetir avisos de la partida anterior ──
    if(partida.id !== lastPartidaId){
      lastPartidaId = partida.id;
      lastDepositoTs = new Date().toISOString();
    }

    const { data: compras } = await sb.from('depositos').select('*')
      .eq('partida_id', partida.id).gt('created_at', lastDepositoTs).order('created_at');

    if(compras && compras.length){
      const banco = await getBancoReceptor();
      for(const d of compras){
        const hora = new Date(d.created_at).toLocaleTimeString('es-VE', { hour:'2-digit', minute:'2-digit' });
        const esperado = parseFloat(d.monto_bs);
        const declarado = d.monto_declarado != null ? parseFloat(d.monto_declarado) : null;
        let coincide = '⚠️ No indicó el monto — revisar manualmente';
        if(declarado != null){
          const cuadra = Math.abs(declarado - esperado) <= 1; // tolerancia 1 Bs.
          coincide = cuadra
            ? `✅ Coincide con las ${d.cantidad_cartones} cartones`
            : `❌ NO coincide con las ${d.cantidad_cartones} cartones (esperado ${fBs(esperado)})`;
        }
        await sendMsg(chatId,
          `🧾 <b>Nuevo pago</b>\n👤 ${d.nombre}\n🔢 Referencia: <code>${d.referencia}</code>\n💵 Monto: <b>${declarado != null ? fBs(declarado) : '—'}</b>\n🏦 Banco: ${banco}\n${coincide}\n🕐 Hora: ${hora}`);

        // ── reenviar la foto del comprobante, si adjuntó una ──
        if(d.comprobante_url){
          try{
            await bot.sendPhoto(chatId, d.comprobante_url, { caption: `📎 Comprobante — Ref ${d.referencia} (${d.nombre})` });
          }catch(e){
            console.error('Error reenviando comprobante:', e.message);
            await sendMsg(chatId, `⚠️ No pude reenviar la foto del comprobante de la ref ${d.referencia}. Link directo:\n${d.comprobante_url}`);
          }
        }
      }
      lastDepositoTs = compras[compras.length-1].created_at;
    }
  }catch(e){ console.error('Error en checkPagos:', e.message); }
}

// ── COMANDOS BÁSICOS ─────────────────────────────────────────────
bot.onText(/\/start/, (msg) => {
  sendMsg(msg.chat.id, '👋 ¡Hola! Soy el bot de <b>Bingo Star Online</b>.\nTe voy a avisar aquí mismo, en privado, cada vez que alguien pague: nombre, cartones, monto, referencia y la foto del comprobante si la adjuntó.\n\nUsa /chatid para obtener el ID de este chat y pegarlo en el panel admin (sección 📢 Telegram). Asegúrate de escribirme por privado, no desde un grupo.');
});
bot.onText(/\/chatid/, (msg) => {
  sendMsg(msg.chat.id, `🆔 El Chat ID de este chat es:\n<code>${msg.chat.id}</code>\n\nCópialo y pégalo en el panel admin, sección 📢 Telegram. Debe ser el ID de tu chat privado con el bot.`);
});

console.log('🤖 Bot de Bingo Star Online iniciado (solo avisos de pago, en privado). Escuchando...');
setInterval(checkPagos, POLL_MS);
checkPagos();
