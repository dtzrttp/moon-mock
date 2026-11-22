import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { linkSync, mkdtempSync, readFileSync, unlinkSync, rmdirSync, writeFileSync } from 'node:fs';
import { join, relative, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
const target = process.argv[2] ?? 'js';
assert(['js', 'native'].includes(target), 'target 必须是 js 或 native');
const base = join(root, '_build', target, 'debug', 'build', 'cmd', 'moon-mock', 'moon-mock');
const executable = target === 'js' ? process.execPath : base + '.exe';
const prefix = target === 'js' ? [base + '.js'] : [];
let invocations = 0;

function run(expectedCode, ...args) {
  invocations++;
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
assert.match(run(0, ...command, '--mock-name', 'GeneratedTransaction').stdout,
  /struct GeneratedTransaction/);
assert.match(run(1, 'generate', known, 'Missing').stderr, /trait_not_found/);
for (const [stem, name] of [['transaction', 'Transaction'], ['transport', 'Transport']]) {
  run(0, 'generate', 'examples/' + stem + '/' + stem + '.mbt', name,
    '--check', 'examples/' + stem + '/mock_' + stem + '_wbtest.mbt');
}

const service = 'tools/fixtures/consumer/service.mbt';
const branch = 'tools/fixtures/consumer/branch_traits.mbt';
const parent = 'tools/fixtures/consumer/base_traits.mbt';
const generateService = ['generate', service, 'Service'];
assert.match(run(1, ...generateService).stderr, /supertrait_not_found: Endpoint|supertrait_not_found: Reader/);
assert.match(run(2, ...generateService, '--source', service).stderr, /重复或冲突/);
assert.match(run(2, ...generateService, '--source', 'README.md').stderr, /辅助源码必须是/);
assert.match(run(1, ...generateService, '--source', 'missing.mbt').stderr, /source_read_error: missing\.mbt/);
assert.match(run(0, ...generateService, '--source', branch, '--source', parent).stdout,
  /impl Reader for MockService with fn lookup/);

const scratch = mkdtempSync(join(root, '_build', 'cli-smoke-'));
const fixture = join(scratch, 'mock_transaction_wbtest.mbt');
const sourceFixture = join(scratch, 'source_wbtest.mbt');
const hardlink = join(scratch, 'source_alias_wbtest.mbt');
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
  const source = '// 由 moon-mock 生成\ntrait Source { fn read(Self) -> Unit }\n';
  writeFileSync(sourceFixture, source);
  const aliases = [
    scratch + sep + '.' + sep + 'source_wbtest.mbt',
    scratch + sep + '..' + sep + scratch.split(sep).at(-1) + sep + 'source_wbtest.mbt',
    relative(root, sourceFixture),
  ];
  if (process.platform === 'win32') aliases.push(sourceFixture.toUpperCase().replace('SOURCE_WBTEST.MBT', 'source_wbtest.mbt'));
  for (const alias of aliases) {
    assert.match(run(2, 'generate', sourceFixture, 'Source', '--output', alias).stderr,
      /source_output_conflict/);
    assert.equal(readFileSync(sourceFixture, 'utf8'), source);
  }
  linkSync(sourceFixture, hardlink);
  assert.match(run(2, 'generate', sourceFixture, 'Source', '--output', hardlink).stderr,
    /source_output_conflict/);
  assert.equal(readFileSync(sourceFixture, 'utf8'), source);
} finally {
  for (const path of [fixture, sourceFixture, hardlink]) {
    try { unlinkSync(path); } catch (error) { if (error.code !== 'ENOENT') throw error; }
  }
  rmdirSync(scratch);
}
console.log(target + ' CLI 实际执行 ' + invocations + ' 个命令，覆盖生成、名称配置、错误、过期文件与路径别名保护。');
