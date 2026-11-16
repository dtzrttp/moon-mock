import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, readFileSync, unlinkSync, rmdirSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
const target = process.argv[2] ?? 'js';
assert(['js', 'native'].includes(target), 'target 必须是 js 或 native');
const base = join(root, '_build', target, 'debug', 'build', 'cmd', 'moon-mock', 'moon-mock');
const executable = target === 'js' ? process.execPath : base + (process.platform === 'win32' ? '.exe' : '');
const prefix = target === 'js' ? [base + '.js'] : [];

function run(expectedCode, ...args) {
  const result = spawnSync(executable, [...prefix, ...args], {
    cwd: root, encoding: 'utf8', timeout: 15000,
  });
  assert.ifError(result.error);
  assert.equal(result.status, expectedCode, result.stderr || result.stdout);
  return result;
}

const known = 'examples/transaction/transaction.mbt';
const command = ['generate', known, 'Transaction'];
assert.match(run(0, '--help').stdout, /generate/);
assert.match(run(0, ...command).stdout, /struct MockTransaction/);
assert.match(run(1, 'generate', known, 'Missing').stderr, /trait_not_found/);
for (const [stem, name] of [['transaction', 'Transaction'], ['transport', 'Transport']]) {
  run(0, 'generate', 'examples/' + stem + '/' + stem + '.mbt', name,
    '--check', 'examples/' + stem + '/mock_' + stem + '_wbtest.mbt');
}

const scratch = mkdtempSync(join(tmpdir(), 'moon-mock-smoke-'));
const fixture = join(scratch, 'mock_transaction_wbtest.mbt');
try {
  run(0, ...command, '--output', fixture);
  const original = readFileSync(fixture, 'utf8');
  assert.match(original, /^\/\/ 由 moon-mock 生成/);
  run(0, ...command, '--output', fixture);
  run(0, ...command, '--check', fixture);
  writeFileSync(fixture, original.replaceAll(/\r?\n/g, '\r\n'));
  run(0, ...command, '--check', fixture);
  writeFileSync(fixture, original + '// changed\n');
  assert.match(run(2, ...command, '--check', fixture).stderr, /generated_out_of_date/);
  writeFileSync(fixture, 'test "manual" {}\n');
  assert.match(run(2, ...command, '--output', fixture).stderr, /拒绝覆盖非生成文件/);
  assert.equal(readFileSync(fixture, 'utf8'), 'test "manual" {}\n');
  assert.match(run(2, ...command, '--check', join(scratch, 'missing_wbtest.mbt')).stderr,
    /generated_out_of_date/);
} finally {
  try { unlinkSync(fixture); } catch (error) { if (error.code !== 'ENOENT') throw error; }
  rmdirSync(scratch);
}
console.log(target + ' CLI 实际执行 12 个命令，覆盖生成、错误、过期文件与覆盖保护。');
