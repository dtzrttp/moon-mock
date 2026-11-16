import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { copyFileSync, mkdirSync, mkdtempSync, readdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
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
  'import { "dtzrttp/moon-mock@0.1.0" }',
  '',
].join('\n'));
writeFileSync(join(consumer, 'moon.pkg'), [
  'import { "dtzrttp/moon-mock/runtime" @mock_runtime } for "wbtest"',
  '',
].join('\n'));
writeFileSync(join(consumer, 'traits.mbt'), [
  'pub(open) trait Availability { fn available(Self) -> Bool }',
  'pub(open) trait Catalog {',
  '  fn lookup(Self, Int32) -> (String, Int32)?',
  '  fn status(Self, &Availability) -> &Availability = _',
  '}',
  'impl Catalog with fn status(_self, fallback) { fallback }',
  '',
].join('\n'));
writeFileSync(join(consumer, 'consumer_wbtest.mbt'), [
  'priv struct Stock(Bool)',
  'impl Availability for Stock with fn available(self) { self.0 }',
  'test "不同模块的使用方只导入运行库" {',
  '  @mock_runtime.with_mock(c => {',
  '    let mock = MockCatalog::new(c)',
  '    mock.expect_lookup(@mock_runtime.equal_to(42), Some(("book", 3)))',
  '    assert_eq(Catalog::lookup(mock, 42), Some(("book", 3)))',
  '  })',
  '}',
  'test "调用带默认实现的方法时使用设定的返回值" {',
  '  @mock_runtime.with_mock(c => {',
  '    let mock = MockCatalog::new(c)',
  '    mock.expect_status(@mock_runtime.matching("缺货", stock => !stock.available()), Stock(true))',
  '    let status = Catalog::status(mock, Stock(false))',
  '    assert_true(status.available())',
  '  })',
  '}',
  '',
].join('\n'));

function run(program, args, cwd) {
  const result = spawnSync(program, args, { cwd, encoding: 'utf8', timeout: 120000 });
  assert.ifError(result.error);
  assert.equal(result.status, 0, result.stderr || result.stdout);
  return result.stdout + result.stderr;
}

const cli = join(root, '_build', 'js', 'debug', 'build', 'cmd', 'moon-mock', 'moon-mock.js');
run(process.execPath, [cli, 'generate', 'traits.mbt', 'Catalog', '--output', 'mock_catalog_wbtest.mbt'], consumer);
const result = run('moon', ['test', '.', '--target', 'js', '--deny-warn'], consumer);
assert.match(result, /Total tests: 2, passed: 2, failed: 0/);
console.log('独立消费方测试 2/2 通过，保留工作区 ' + sandbox);
