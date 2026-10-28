// Tạo, xem và merge pull request trên GitHub mà không cần `gh`.
//
//   node tool/deploy/github.mjs pr-create <body.json>   # {title, head, base, body}
//   node tool/deploy/github.mjs pr-view <number>
//   node tool/deploy/github.mjs checks <sha>
//   node tool/deploy/github.mjs pr-merge <number> [merge|squash|rebase]
//
// Token lấy từ credential git đã lưu (`git credential fill`), đúng cái git
// dùng để push. Script không bao giờ in token.

import { spawnSync } from 'node:child_process';
import { readFileSync } from 'node:fs';

const repo = 'anhnpvse02755-png/PoolCoachAI';
const api = `https://api.github.com/repos/${repo}`;

function token() {
  const r = spawnSync('git', ['credential', 'fill'], {
    input: 'protocol=https\nhost=github.com\n\n',
    encoding: 'utf8',
    env: { ...process.env, GIT_TERMINAL_PROMPT: '0' },
  });
  const line = (r.stdout || '').split('\n').find((l) => l.startsWith('password='));
  if (!line) throw new Error('Không có credential GitHub đã lưu cho git');
  return line.slice('password='.length).trim();
}

async function call(method, path, body) {
  const res = await fetch(api + path, {
    method,
    headers: {
      Authorization: `Bearer ${token()}`,
      Accept: 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28',
      ...(body ? { 'Content-Type': 'application/json' } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  const data = text ? JSON.parse(text) : null;
  if (!res.ok) throw new Error(`${method} ${path} → ${res.status} ${data?.message ?? text}`);
  return data;
}

const [cmd, arg, extra] = process.argv.slice(2);

switch (cmd) {
  case 'pr-create': {
    const pr = await call('POST', '/pulls', JSON.parse(readFileSync(arg, 'utf8')));
    console.log(`#${pr.number} ${pr.html_url}`);
    break;
  }
  case 'pr-view': {
    const pr = await call('GET', `/pulls/${arg}`);
    console.log(`#${pr.number} ${pr.state} merged=${pr.merged} mergeable=${pr.mergeable} (${pr.mergeable_state})`);
    console.log(`head ${pr.head.ref} ${pr.head.sha.slice(0, 7)} → base ${pr.base.ref}`);
    break;
  }
  case 'checks': {
    const runs = await call('GET', `/commits/${arg}/check-runs?per_page=50`);
    for (const c of runs.check_runs) console.log(`${c.name}: ${c.conclusion ?? c.status}`);
    break;
  }
  case 'pr-merge': {
    const pr = await call('GET', `/pulls/${arg}`);
    const r = await call('PUT', `/pulls/${arg}/merge`, {
      merge_method: extra ?? 'merge',
      commit_title: `Merge ${pr.head.ref}: ${pr.title} (#${pr.number})`,
      sha: pr.head.sha,
    });
    console.log(`merged=${r.merged} sha=${r.sha?.slice(0, 7)} ${r.message}`);
    break;
  }
  default:
    console.error('Lệnh: pr-create <file> | pr-view <n> | checks <sha> | pr-merge <n> [method]');
    process.exit(2);
}
