'use strict';

const http = require('http');
const net = require('net');
const { URL } = require('url');
const httpProxy = require('http-proxy');

const port = Number(process.env.PORT || 10000);
const upstreamRaw = process.env.GRU_UPSTREAM_URL || 'https://gru-jiqi.onrender.com';
const edgeSecret = (process.env.GRU_EDGE_SHARED_SECRET || '').trim();
const upstream = new URL(upstreamRaw);

if (upstream.protocol !== 'https:') {
  throw new Error('GRU_UPSTREAM_URL must use https');
}
if (edgeSecret.length < 32) {
  throw new Error('GRU_EDGE_SHARED_SECRET must contain at least 32 characters');
}

const proxy = httpProxy.createProxyServer({
  target: upstream.origin,
  changeOrigin: true,
  ws: true,
  xfwd: false,
  secure: true,
  proxyTimeout: 30_000,
  timeout: 30_000
});

const allowedMethods = new Set(['GET', 'HEAD', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS']);
const blockedHopHeaders = [
  'proxy-authorization',
  'proxy-authenticate',
  'forwarded',
  'x-gru-edge-secret',
  'x-gru-client-ip'
];

function setSecurityHeaders(res) {
  res.setHeader('Strict-Transport-Security', 'max-age=31536000; includeSubDomains');
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'DENY');
  res.setHeader('Referrer-Policy', 'no-referrer');
  res.setHeader('Permissions-Policy', 'camera=(), microphone=(), geolocation=()');
  res.setHeader('Cache-Control', 'no-store');
}

function reject(res, status, message) {
  setSecurityHeaders(res);
  res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8' });
  res.end(JSON.stringify({ error: message }));
}

function validPath(rawUrl) {
  try {
    const parsed = new URL(rawUrl || '/', 'https://gru.invalid');
    if (parsed.pathname.includes('..')) return false;
    return parsed.pathname.startsWith('/');
  } catch {
    return false;
  }
}

function normalizedIP(value) {
  if (!value) return null;
  const candidate = String(value).trim().replace(/^::ffff:/, '');
  return net.isIP(candidate) ? candidate : null;
}

function clientIP(req) {
  // Render's public router appends the network peer to X-Forwarded-For.
  // Prefer the rightmost valid address; a caller-supplied leftmost value must
  // never become the trusted backend rate-limit bucket.
  const forwarded = req.headers['x-forwarded-for'];
  if (forwarded) {
    const values = String(forwarded).split(',').map((part) => part.trim()).filter(Boolean);
    for (let index = values.length - 1; index >= 0; index -= 1) {
      const valid = normalizedIP(values[index]);
      if (valid) return valid;
    }
  }
  return normalizedIP(req.socket && req.socket.remoteAddress) || 'unknown';
}

function sanitizeRequest(req) {
  const ip = clientIP(req);
  for (const header of blockedHopHeaders) {
    delete req.headers[header];
  }
  delete req.headers['x-forwarded-host'];
  delete req.headers['x-forwarded-proto'];

  req.headers['x-gru-edge'] = 'render-proxy-v1';
  req.headers['x-gru-edge-secret'] = edgeSecret;
  req.headers['x-gru-client-ip'] = ip;
}

const server = http.createServer((req, res) => {
  setSecurityHeaders(res);

  if (!allowedMethods.has(req.method || '')) {
    return reject(res, 405, 'method_not_allowed');
  }
  if (!validPath(req.url)) {
    return reject(res, 400, 'invalid_path');
  }

  // Never print Authorization, cookies, request bodies, E2EE envelopes,
  // recovery backups, edge secrets, client IPs or media metadata.
  console.log(JSON.stringify({
    event: 'edge_request',
    method: req.method,
    path: (req.url || '/').split('?')[0]
  }));

  sanitizeRequest(req);
  proxy.web(req, res);
});

server.on('upgrade', (req, socket, head) => {
  if (!validPath(req.url) || !(req.url || '').startsWith('/ws')) {
    socket.destroy();
    return;
  }
  sanitizeRequest(req);
  proxy.ws(req, socket, head);
});

proxy.on('proxyRes', (proxyRes) => {
  proxyRes.headers['cache-control'] = 'no-store';
  delete proxyRes.headers['server'];
  delete proxyRes.headers['x-powered-by'];
});

proxy.on('error', (error, req, resOrSocket) => {
  console.error(JSON.stringify({
    event: 'edge_proxy_error',
    code: error && error.code ? error.code : 'proxy_error',
    path: req && req.url ? req.url.split('?')[0] : '/'
  }));

  if (resOrSocket && typeof resOrSocket.writeHead === 'function') {
    reject(resOrSocket, 502, 'upstream_unavailable');
  } else if (resOrSocket && typeof resOrSocket.destroy === 'function') {
    resOrSocket.destroy();
  }
});

server.requestTimeout = 35_000;
server.headersTimeout = 40_000;
server.keepAliveTimeout = 65_000;

server.listen(port, '0.0.0.0', () => {
  console.log(JSON.stringify({ event: 'edge_started', port, upstream: upstream.host }));
});
