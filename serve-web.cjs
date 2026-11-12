// Serves the exported web build (web/) for testing:  node serve-web.cjs  → http://localhost:4180
const http = require('http');
const fs = require('fs');
const path = require('path');

const root = path.join(__dirname, 'web');
const port = Number(process.env.PORT) || 4180;
const types = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };

http.createServer((req, res) => {
  const rel = decodeURIComponent(req.url.split('?')[0]);
  const file = path.join(root, rel === '/' ? 'index.html' : rel);
  if (!file.startsWith(root) || !fs.existsSync(file)) { res.writeHead(404); res.end('Not found'); return; }
  res.writeHead(200, { 'Content-Type': types[path.extname(file)] || 'application/octet-stream' });
  fs.createReadStream(file).pipe(res);
}).listen(port, () => console.log(`Valluvar's Pond (web build): http://localhost:${port}`));
