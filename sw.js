// Service worker mínimo — solo existe para que el navegador permita "Instalar app".
// No cachea nada para que el bingo siempre cargue la versión más reciente en vivo.
self.addEventListener('install', function(e){ self.skipWaiting(); });
self.addEventListener('activate', function(e){ self.clients.claim(); });
self.addEventListener('fetch', function(e){ /* siempre va a la red, sin caché */ });
