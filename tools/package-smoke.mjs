import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
const target = process.argv[2] ?? 'js';
assert(['js', 'native'].includes(target), 'target 必须是 js 或 native');

function run(program, args, cwd) {
  const result = spawnSync(program, args, { cwd, encoding: 'utf8', timeout: 180000 });
  assert.ifError(result.error);
  assert.equal(result.status, 0, result.stderr || result.stdout);
  return result.stdout + result.stderr;
}

run('moon', ['package'], root);
const archives = readdirSync(join(root, '_build', 'publish'))
  .filter(name => name.startsWith('dtzrttp-moon-mock-') && name.endsWith('.zip'));
assert.equal(archives.length, 1, '发行包目录应只包含一个待验证版本');
const archive = join(root, '_build', 'publish', archives[0]);
const listing = process.platform === 'win32'
  ? run('tar', ['-tf', archive], root)
  : run('unzip', ['-Z1', archive], root);
const entries = listing.split(/\r?\n/).filter(Boolean);
assert(entries.includes('LICENSE'));
assert(entries.includes('moon.mod'));
for (const entry of entries) {
  assert(!entry.split(/[\\/]/).some(part => ['..', '.git', '.mooncakes', '_build'].includes(part)),
    '发行包不能包含缓存、版本库或越界路径 ' + entry);
  assert(!entry.replaceAll('\\', '/').startsWith('docs/evidence/'));
  assert(!entry.toLowerCase().includes('credentials'));
}
const sandbox = mkdtempSync(join(root, '_build', 'package-consumer-'));
if (process.platform === 'win32') {
  run('tar', ['-xf', archive, '-C', sandbox], root);
} else {
  run('unzip', ['-q', archive, '-d', sandbox], root);
}
assert.equal(readFileSync(join(sandbox, 'moon.mod'), 'utf8'),
  readFileSync(join(root, 'moon.mod'), 'utf8'));
assert(existsSync(join(sandbox, 'tools', 'consumer-smoke.mjs')));
run('moon', ['build', '--target', target, '--deny-warn'], sandbox);
const evidence = run(process.execPath, ['tools/consumer-smoke.mjs', target], sandbox);
assert(evidence.includes('10/10'));
if (target === 'native') {
  const installBin = join(sandbox, '_build', 'installed-bin');
  mkdirSync(installBin, { recursive: true });
  run('moon', ['install', './cmd/moon-mock', '--bin', installBin], sandbox);
  const installed = join(installBin, process.platform === 'win32' ? 'moon-mock.exe' : 'moon-mock');
  assert(existsSync(installed), '应得到独立安装的 CLI');
  assert(run(installed, ['--help'], sandbox).includes('generate'));
}
console.log(target + ' 发行包解压后构建与全新消费方 10/10 通过，目录 ' + sandbox);
