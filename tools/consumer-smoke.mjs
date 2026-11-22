import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { copyFileSync, mkdirSync, mkdtempSync, readdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
const target = process.argv[2] ?? 'js';
assert(['js', 'native'].includes(target), 'target 必须是 js 或 native');
const sandbox = mkdtempSync(join(root, '_build', 'external-consumer-'));
const dependency = join(sandbox, 'dependency');
const consumer = join(sandbox, 'consumer');
mkdirSync(join(dependency, 'runtime'), { recursive: true });
mkdirSync(consumer);
copyFileSync(join(root, 'moon.mod'), join(dependency, 'moon.mod'));
for (const name of readdirSync(join(root, 'runtime'))) {
  if (name === 'moon.pkg' || name.endsWith('.mbt')) {
    copyFileSync(join(root, 'runtime', name), join(dependency, 'runtime', name));
  }
}
writeFileSync(join(sandbox, 'moon.work'), 'members = ["consumer", "dependency"]\n');
writeFileSync(join(consumer, 'moon.mod'), [
  'name = "dtzrttp/mock_consumer"',
  'version = "0.1.0"',
  'import { "dtzrttp/moon-mock@0.1.0", "moonbitlang/async@0.22.4" }',
  '',
].join('\n'));
writeFileSync(join(consumer, 'moon.pkg'), [
  'import { "dtzrttp/moon-mock/runtime" @mock_runtime, "moonbitlang/async" } for "wbtest"',
  '',
].join('\n'));

const fixtures = join(root, 'tools', 'fixtures', 'consumer');
for (const name of readdirSync(fixtures)) {
  copyFileSync(join(fixtures, name), join(consumer, name));
}

function run(program, args, cwd) {
  const result = spawnSync(program, args, { cwd, encoding: 'utf8', timeout: 120000 });
  assert.ifError(result.error);
  assert.equal(result.status, 0, result.stderr || result.stdout);
  return result.stdout + result.stderr;
}

const base = join(root, '_build', target, 'debug', 'build', 'cmd', 'moon-mock', 'moon-mock');
const cli = target === 'js' ? process.execPath : base + '.exe';
const prefix = target === 'js' ? [base + '.js'] : [];
run(cli, [...prefix, 'generate', 'traits.mbt', 'Catalog', '--output', 'mock_catalog_wbtest.mbt'], consumer);
const hierarchy = [
  'generate', 'service.mbt', 'Service',
  '--source', 'branch_traits.mbt',
  '--source', 'base_traits.mbt',
];
run(cli, [...prefix, ...hierarchy, '--output', 'mock_service_wbtest.mbt'], consumer);
run(cli, [...prefix, ...hierarchy, '--check', 'mock_service_wbtest.mbt'], consumer);
const result = run('moon', ['test', '.', '--target', target, '--deny-warn'], consumer);
assert.match(result, /Total tests: 9, passed: 9, failed: 0/);
console.log(target + ' 独立消费方测试 9/9 通过，保留工作区 ' + sandbox);
