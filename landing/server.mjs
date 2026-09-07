import http from 'node:http';
import { readFile } from 'node:fs/promises';
import { extname, join, normalize } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('./public/', import.meta.url));
const port = Number(process.env.PORT || 10000);

const mime = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.webp': 'image/webp',
  '.ico': 'image/x-icon'
};

const server = http.createServer(async (req, res) => {
  try {
    if (req.url === '/health' || req.url === '/ready') {
      res.writeHead(200, { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store' });
      res.end(JSON.stringify({ status: 'UP', product: 'gru-landing' }));
      return;
    }

    const raw = decodeURIComponent((req.url || '/').split('?')[0]);
    const requested = raw === '/' ? 'index.html' : raw.replace(/^\/+/, '');
    const safe = normalize(requested).replace(/^(\.\.(\/|\\|$))+/, '');
    let path = join(root, safe);

    let body;
    try {
      body = await readFile(path);
    } catch {
      path = join(root, 'index.html');
      body = await readFile(path);
    }

    const type = mime[extname(path).toLowerCase()] || 'application/octet-stream';
    res.writeHead(200, {
      'content-type': type,
      'cache-control': type.startsWith('text/html') ? 'no-cache' : 'public, max-age=3600',
      'x-content-type-options': 'nosniff',
      'referrer-policy': 'strict-origin-when-cross-origin'
    });
    res.end(body);
  } catch (error) {
    res.writeHead(500, { 'content-type': 'text/plain; charset=utf-8' });
    res.end('gru. landing is temporarily unavailable');
  }
});

server.listen(port, '0.0.0.0', () => {
  console.log(`gru. landing live on ${port}`);
});
