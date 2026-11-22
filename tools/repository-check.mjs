import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { existsSync, readFileSync } from 'node:fs';
import { dirname, isAbsolute, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
const git = args => execFileSync('git', args, { cwd: root, encoding: 'utf8' });
const files = git(['ls-files', '-z']).split('\0').filter(Boolean);
const manifest = readFileSync(resolve(root, 'moon.mod'), 'utf8');
assert(/^name\s*=\s*"dtzrttp\/moon-mock"\s*$/m.test(manifest), '模块名称应为本项目命名空间');
assert(/^license\s*=\s*"Apache-2.0"\s*$/m.test(manifest), '发行清单应声明实际许可证');
for (const required of ['README.md', 'LICENSE', 'NOTICE.md', '.github/workflows/ci.yml']) {
  assert(files.includes(required), '缺少必要仓库文件 ' + required);
}
const license = readFileSync(resolve(root, 'LICENSE'), 'utf8');
assert(license.includes('Apache License') && license.includes('Version 2.0'));
assert(readFileSync(resolve(root, 'NOTICE.md'), 'utf8').includes('Copyright 2026 dtzrttp'));

let checkedLinks = 0;
for (const file of files) {
  const segments = file.split('/');
  assert(!segments.some(part => ['_build', '.mooncakes', '.probe', 'node_modules'].includes(part)),
    '构建产物或缓存被跟踪 ' + file);
  assert(!file.startsWith('docs/evidence/'), '本地验证缓存不应提交');
  assert(!/credentials|\.env(?:\.|$)|\.pem$|\.key$/i.test(file), '需要复核敏感文件 ' + file);
  const text = readFileSync(resolve(root, file), 'utf8');
  assert(!/ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{50,}|-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----/.test(text),
    '文件可能含凭证，需要人工复核 ' + file);
  if (!file.endsWith('.md')) continue;
  for (const match of text.matchAll(/\[[^\]]*\]\((?:<([^>]+)>|([^\s)]+))\)/g)) {
    const target = match[1] ?? match[2];
    if (/^https?:|^mailto:|^#/.test(target)) continue;
    const local = decodeURIComponent(target.split('#')[0]);
    if (!local) continue;
    assert(!isAbsolute(local), '仓库文档包含机器绝对路径 ' + file);
    assert(existsSync(resolve(root, dirname(file), local)), '本地文档链接失效 ' + file + ' -> ' + target);
    checkedLinks++;
  }
}
const identities = git(['log', '--format=%an <%ae>%n%cn <%ce>']).trim().split(/\r?\n/).filter(Boolean);
for (const identity of identities) {
  assert.equal(identity, 'dtzrttp <313799694+dtzrttp@users.noreply.github.com>',
    '本项目提交身份与使用者指定账号不一致');
}
assert(!/^Co-authored-by:/im.test(git(['log', '--format=%B'])), '本项目不应添加共同作者署名');
console.log('仓库静态自查通过，已检查 ' + files.length + ' 个跟踪文件及 ' + checkedLinks + ' 个本地文档链接。');
