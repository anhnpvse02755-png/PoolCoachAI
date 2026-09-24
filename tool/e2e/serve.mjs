// Server tĩnh giống nginx trên Easypanel: fallback về index.html và MIME đúng cho wasm.
//   node tool/e2e/serve.mjs build/web 8765
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';

const [, , dir = 'build/web', port = '8765'] = process.argv;
const root = path.resolve(dir);
const types = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'application/javascript',
  '.mjs': 'application/javascript',
  '.json': 'application/json',
  '.wasm': 'application/wasm',
  '.png': 'image/png',
  '.otf': 'font/otf',
  '.ttf': 'font/ttf',
  '.frag': 'application/octet-stream',
};

http.createServer((req, res) => {
  const url = new URL(req.url, 'http://x');
  let file = path.join(root, decodeURIComponent(url.pathname));
  if (!file.startsWith(root) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) {
    file = path.join(root, 'index.html');
  }
  res.writeHead(200, {
    'Content-Type': types[path.extname(file)] ?? 'application/octet-stream',
    'Cache-Control': 'no-cache',
  });
  fs.createReadStream(file).pipe(res);
}).listen(Number(port), '127.0.0.1', () => console.log(`http://127.0.0.1:${port}/`));
