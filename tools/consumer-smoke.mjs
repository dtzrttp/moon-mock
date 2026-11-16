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
  '  fn search(Self, String, action~ : Int32, arg_0~ : Int32, self~ : Int32, args~ : Int32) -> Int32',
  '  fn page_size(Self, limit? : Int32) -> Int32',
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
  'test "标签调用按声明顺序匹配并传给回调" {',
  '  @mock_runtime.with_mock(c => {',
  '    let mock = MockCatalog::new(c)',
  '    mock.respond_search(@mock_runtime.equal_to(("book", 2, 3, 5, 7)), values => {',
  '      let (_, action, arg, receiver, args) = values',
  '      action + arg + receiver + args',
  '    })',
  '    let catalog : &Catalog = mock',
  '    assert_eq(catalog.search("book", args=7, self=5, arg_0=3, action=2), 17)',
  '    mock.expect_page_size(@mock_runtime.equal_to(None), 20)',
  '    mock.expect_page_size(@mock_runtime.equal_to(Some(9)), 9)',
  '    assert_eq(catalog.page_size(), 20)',
  '    assert_eq(catalog.page_size(limit=9), 9)',
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

const base = join(root, '_build', target, 'debug', 'build', 'cmd', 'moon-mock', 'moon-mock');
const cli = target === 'js' ? process.execPath : base + '.exe';
const prefix = target === 'js' ? [base + '.js'] : [];
run(cli, [...prefix, 'generate', 'traits.mbt', 'Catalog', '--output', 'mock_catalog_wbtest.mbt'], consumer);
const result = run('moon', ['test', '.', '--target', target, '--deny-warn'], consumer);
assert.match(result, /Total tests: 3, passed: 3, failed: 0/);
console.log(target + ' 独立消费方测试 3/3 通过，保留工作区 ' + sandbox);
