import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { copyFileSync, mkdirSync, mkdtempSync, readdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
const version = process.argv[2] ?? '0.1.0';
assert(/^\d+\.\d+\.\d+$/.test(version), '版本应为三段数字');
const sandbox = mkdtempSync(join(root, '_build', 'registry-consumer-'));
const consumer = join(sandbox, 'consumer');
const bin = join(sandbox, 'bin');
mkdirSync(consumer);
mkdirSync(bin);
writeFileSync(join(sandbox, 'moon.work'), 'members = ["consumer"]\n');
writeFileSync(join(consumer, 'moon.mod'), [
  'name = "dtzrttp/registry_mock_consumer"',
  'import { "dtzrttp/moon-mock@' + version + '", "moonbitlang/async@0.22.4" }',
  '',
].join('\n'));
writeFileSync(join(consumer, 'moon.pkg'),
  'import { "dtzrttp/moon-mock/runtime" @mock_runtime, "moonbitlang/async" } for "wbtest"\n');
for (const name of readdirSync(join(root, 'tools', 'fixtures', 'consumer'))) {
  copyFileSync(join(root, 'tools', 'fixtures', 'consumer', name), join(consumer, name));
}
function run(program, args, cwd = sandbox) {
  const result = spawnSync(program, args, {
    cwd, encoding: 'utf8', timeout: 300000, maxBuffer: 8 * 1024 * 1024,
  });
  assert.ifError(result.error);
  assert.equal(result.status, 0, result.stderr || result.stdout);
  return result.stdout + result.stderr;
}
const metadata = run('moon', ['view', 'dtzrttp/moon-mock@' + version, '--json']);
run('moon', ['install', 'dtzrttp/moon-mock/cmd/moon-mock@' + version, '--bin', bin]);
const cli = join(bin, process.platform === 'win32' ? 'moon-mock.exe' : 'moon-mock');
assert(run(cli, ['--help']).includes('generate'));
for (const [file, name, output, sources] of [
  ['traits.mbt', 'Catalog', 'mock_catalog_wbtest.mbt', []],
  ['service.mbt', 'Service', 'mock_service_wbtest.mbt',
    ['--source', 'branch_traits.mbt', '--source', 'base_traits.mbt']],
  ['signature_matrix.mbt', 'SignatureMatrix', 'mock_signature_matrix_wbtest.mbt', []],
]) {
  run(cli, ['generate', file, name, ...sources, '--output', output], consumer);
  run(cli, ['generate', file, name, ...sources, '--check', output], consumer);
}
const tree = run('moon', ['tree'], consumer);
assert(tree.includes('dtzrttp/moon-mock'));
const results = [];
for (const target of ['js', 'native']) {
  const output = run('moon', ['test', '.', '--target', target, '--deny-warn'], consumer);
  assert.match(output, /Total tests: 10, passed: 10, failed: 0/);
  results.push({ target, output });
  console.log(target + ' 注册表消费方 10/10 通过');
}
writeFileSync(join(sandbox, 'evidence.json'), JSON.stringify({
  version, source: 'mooncakes.io', metadata, tree, results,
}, null, 2) + '\n');
console.log('公开发行版独立下载、CLI安装及双后端验证证据 ' + sandbox);
