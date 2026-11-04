'use strict';
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');

const port = Number(process.env.PIM4_PREVIEW_PORT || 4300);
const api = new URL(process.env.PIM4_PREVIEW_API || 'http://localhost:5278/');
if (!Number.isInteger(port) || port < 1 || port > 65535 ||
    api.protocol !== 'http:' ||
    !['localhost', '127.0.0.1', '[::1]'].includes(api.hostname) ||
    api.pathname !== '/' || api.username || api.password || api.search || api.hash) {
  throw new Error('A previa usa somente uma API HTTP local e uma porta valida.');
}
const root = path.resolve(__dirname, '../build/web');
const shell = path.join(__dirname, 'preview-shell.html');
if (!fs.existsSync(path.join(root, 'main.dart.js'))) {
  throw new Error('Gere o build web primeiro usando Preview-Mobile.ps1.');
}
const types = { '.html':'text/html; charset=utf-8', '.js':'application/javascript',
  '.json':'application/json; charset=utf-8', '.css':'text/css', '.wasm':'application/wasm',
  '.png':'image/png', '.svg':'image/svg+xml', '.ttf':'font/ttf', '.woff2':'font/woff2' };

function proxy(req, res, health = false) {
  const headers = { ...req.headers, host: api.host };
  delete headers.connection;
  if (health) { delete headers.authorization; delete headers['content-length']; }
  const incoming = new URL(req.url, 'http://localhost');
  const targetPath = health ? '/health' : incoming.pathname + incoming.search;
  const upstream = http.request(new URL(targetPath, api), {
    method: health ? 'GET' : req.method, headers, timeout: 20000,
  }, response => {
    const responseHeaders = { ...response.headers, 'cache-control': 'no-store' };
    delete responseHeaders['transfer-encoding'];
    res.writeHead(response.statusCode || 502, responseHeaders);
    response.pipe(res);
  });
  upstream.on('timeout', () => upstream.destroy(new Error('timeout')));
  upstream.on('error', () => {
    if (res.headersSent) { res.destroy(); return; }
    res.writeHead(502, { 'content-type':'application/json; charset=utf-8',
      'cache-control':'no-store' });
    res.end(JSON.stringify({ message:'API local indisponível. Inicie o PIM4API e tente novamente.' }));
  });
  req.on('aborted', () => upstream.destroy());
  if (health) upstream.end(); else req.pipe(upstream);
}

const server = http.createServer((req, res) => {
  const url = new URL(req.url, 'http://localhost');
  if (url.pathname.startsWith('/api/')) return proxy(req, res);
  if (url.pathname === '/preview-health') return proxy(req, res, true);
  if (!['GET', 'HEAD'].includes(req.method)) { res.writeHead(405); res.end(); return; }
  let file;
  if (url.pathname === '/') file = shell;
  else if (url.pathname === '/app') {
    res.writeHead(302, { location:'/app/' }); res.end(); return;
  } else if (url.pathname.startsWith('/app/')) {
    let relative;
    try { relative = decodeURIComponent(url.pathname.slice(5)) || 'index.html'; }
    catch { res.writeHead(400); res.end(); return; }
    file = path.resolve(root, relative);
    if (!file.startsWith(root + path.sep)) { res.writeHead(403); res.end(); return; }
  } else { res.writeHead(404); res.end(); return; }
  fs.stat(file, (error, stat) => {
    if (error || !stat.isFile()) { res.writeHead(404); res.end(); return; }
    res.writeHead(200, { 'content-type':types[path.extname(file)] || 'application/octet-stream',
      'content-length':stat.size, 'cache-control':'no-store',
      'x-content-type-options':'nosniff', 'referrer-policy':'same-origin' });
    if (req.method === 'HEAD') res.end();
    else fs.createReadStream(file).on('error', () => res.destroy()).pipe(res);
  });
});
server.on('error', error => { console.error('Não foi possível iniciar a prévia: ' + error.message); process.exitCode = 1; });
server.listen(port, '127.0.0.1', () => {
  console.log('App Flutter no navegador: http://localhost:' + port);
  console.log('API real encaminhada para ' + api.origin);
  console.log('Ctrl+C encerra a prévia.');
});
