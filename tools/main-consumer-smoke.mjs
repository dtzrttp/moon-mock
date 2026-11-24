import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { copyFileSync, mkdirSync, mkdtempSync, readdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
const target = process.argv[2] ?? 'js';
assert(['js', 'native'].includes(target), 'target 必须是 js 或 native');
const sandbox = mkdtempSync(join(root, '_build', 'main-consumer-'));
const dependency = join(sandbox, 'dependency');
const consumer = join(sandbox, 'consumer');
mkdirSync(dependency);
mkdirSync(consumer);
copyFileSync(join(root, 'moon.mod'), join(dependency, 'moon.mod'));
for (const name of ['runtime', 'matchers']) {
  const source = join(root, name);
  const destination = join(dependency, name);
  mkdirSync(destination, { recursive: true });
  for (const file of readdirSync(source)) {
    if (file === 'moon.pkg' || file.endsWith('.mbt')) {
      copyFileSync(join(source, file), join(destination, file));
    }
  }
}
writeFileSync(join(sandbox, 'moon.work'), 'members = ["consumer", "dependency"]\n');
writeFileSync(join(consumer, 'moon.mod'), [
  'name = "dtzrttp/mock_main_consumer"',
  'version = "0.1.0"',
  'import { "dtzrttp/moon-mock@0.2.0" }',
  '',
].join('\n'));
writeFileSync(join(consumer, 'moon.pkg'), [
  'import {',
  '  "dtzrttp/moon-mock/runtime" @mock_runtime,',
  '  "dtzrttp/moon-mock/matchers" @matchers,',
  '} for "wbtest"',
  '',
].join('\n'));
writeFileSync(join(consumer, 'catalog.mbt'), [
  'pub(open) trait Catalog {',
  '  fn lookup(Self, String, Int32) -> String',
  '}',
  '',
].join('\n'));
writeFileSync(join(consumer, 'main_wbtest.mbt'), [
  'test "main分支匹配器及有界调用历史可供外部模块使用" {',
  '  @mock_runtime.with_mock_history(4, c => {',
  '    let mock = MockCatalog::new(c)',
  '    let identifier : @mock_runtime.Capture[String] = @mock_runtime.Capture::new()',
  '    let count : @mock_runtime.Capture[Int32] = @mock_runtime.Capture::new()',
  '    let matcher = @matchers.pair(',
  '      identifier.matcher(@matchers.starts_with("sku-")),',
  '      count.matcher(@matchers.at_least(1)),',
  '    )',
  '    mock.expect_lookup(matcher, "found")',
  '    assert_eq(Catalog::lookup(mock, "sku-42", 3), "found")',
  '    assert_eq(identifier.values(), ["sku-42"])',
  '    assert_eq(count.values(), [3])',
  '    assert_eq(c.history().length(), 1)',
  '    assert_eq(c.history()[0].outcome, "selected")',
  '    let duplicates = @matchers.unordered_elements([',
  '      @mock_runtime.equal_to(7),',
  '      @mock_runtime.equal_to(7),',
  '    ]).unwrap()',
  '    assert_true(duplicates.matches([7, 7]))',
  '    assert_false(duplicates.matches([7, 8]))',
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
run(cli, [...prefix, 'generate', 'catalog.mbt', 'Catalog', '--output', 'mock_catalog_wbtest.mbt'], consumer);
run(cli, [...prefix, 'generate', 'catalog.mbt', 'Catalog', '--check', 'mock_catalog_wbtest.mbt'], consumer);
const result = run('moon', ['test', '.', '--target', target, '--deny-warn'], consumer);
assert.match(result, /Total tests: 1, passed: 1, failed: 0/);
console.log(target + ' 主分支独立消费方测试1/1通过，覆盖生成、通用匹配器和调用历史');
