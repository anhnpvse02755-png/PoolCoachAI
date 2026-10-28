// Client JSON-RPC 2.0 tối giản cho MCP server của Easypanel (streamable HTTP, stateless).
//
//   node tool/deploy/easypanel.mjs tools
//   node tool/deploy/easypanel.mjs call <toolName> '<jsonArgs>'
//
// URL (có token) lấy từ EASYPANEL_MCP_URL; không bao giờ in ra.
const URL_ = process.env.EASYPANEL_MCP_URL;
if (!URL_) { console.error('Thiếu EASYPANEL_MCP_URL'); process.exit(2); }

let sessionId = null;
let nextId = 1;

async function rpc(method, params, notify = false) {
  const body = { jsonrpc: '2.0', method, params };
  if (!notify) body.id = nextId++;
  const headers = {
    'Content-Type': 'application/json',
    Accept: 'application/json, text/event-stream',
  };
  if (sessionId) headers['Mcp-Session-Id'] = sessionId;
  const res = await fetch(URL_, { method: 'POST', headers, body: JSON.stringify(body) });
  const sid = res.headers.get('mcp-session-id');
  if (sid) sessionId = sid;
  const text = await res.text();
  if (!res.ok) throw new Error(`HTTP ${res.status}: ${text.slice(0, 500)}`);
  if (notify || !text.trim()) return null;
  let msg = null;
  if (text.trimStart().startsWith('{')) {
    msg = JSON.parse(text);
  } else {
    for (const line of text.split(/\r?\n/)) {
      if (!line.startsWith('data:')) continue;
      const d = line.slice(5).trim();
      if (!d) continue;
      try {
        const m = JSON.parse(d);
        if (m.id === body.id || m.result || m.error) msg = m;
      } catch { /* bỏ qua */ }
    }
  }
  if (!msg) throw new Error('Không có phản hồi JSON-RPC');
  if (msg.error) throw new Error(`RPC ${msg.error.code}: ${msg.error.message}`);
  return msg.result;
}

async function init() {
  await rpc('initialize', {
    protocolVersion: '2025-06-18',
    capabilities: {},
    clientInfo: { name: 'pcai-deploy', version: '1' },
  });
  try { await rpc('notifications/initialized', {}, true); } catch { /* stateless */ }
}

const [cmd, name, argsJson] = process.argv.slice(2);
try {
  await init();
  if (cmd === 'tools') {
    const r = await rpc('tools/list', {});
    for (const t of r.tools) {
      console.log(t.name);
      console.log(JSON.stringify(t.inputSchema));
    }
  } else if (cmd === 'call' && name) {
    const r = await rpc('tools/call', { name, arguments: argsJson ? JSON.parse(argsJson) : {} });
    const out = (r.content ?? []).map((c) => c.text ?? JSON.stringify(c)).join('\n');
    console.log(out);
    if (r.isError) process.exit(1);
  } else {
    console.error('Cách dùng: tools | call <tool> <jsonArgs>');
    process.exit(2);
  }
} catch (e) {
  console.error(String(e.message).replace(/https?:\/\/\S+/g, '<url>'));
  process.exit(1);
}
