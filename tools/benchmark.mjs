import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { cpus, platform, release, arch } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
const options = process.argv.slice(2);
const real = options.includes('--real');
const refresh = options.includes('--refresh');
const samples = Number(options.find(value => value.startsWith('--samples='))?.split('=')[1] ?? 11);
assert(Number.isInteger(samples) && samples >= 3 && samples <= 101, 'samples 必须在3至101之间');
for (const option of options) {
  assert(option === '--real' || option === '--refresh' || /^--samples=\d+$/.test(option),
    '未知选项 ' + option);
}
const scratch = join(root, '_build', 'benchmark-inputs');
mkdirSync(scratch, { recursive: true });
const sha256 = value => createHash('sha256').update(value).digest('hex');
const inputs = [];
for (const size of [1, 16, 64]) {
  const methods = Array.from({ length: size }, (_, i) =>
    'fn query_' + i + '(Self, String, Array[Int32]) -> Array[String] raise DbError');
  const source = 'trait Repository {\n' + methods.join('\n') + '\n}\n';
  const path = join(scratch, 'synthetic-' + size + '.mbt');
  writeFileSync(path, source);
  inputs.push({ name: 'synthetic-' + size, path, trait: 'Repository', kind: 'synthetic' });
}
if (real) {
  const manifest = JSON.parse(readFileSync(join(root, 'tools', 'fixtures', 'benchmark-upstream.json'), 'utf8'));
  const fetched = new Map();
  for (const entry of manifest.inputs) {
    assert(/^[0-9a-f]{40}$/.test(entry.commit));
    const url = 'https://raw.githubusercontent.com/' + entry.repository + '/' +
      entry.commit + '/' + entry.file;
    const path = join(scratch, sha256(url) + '.mbt');
    if ((refresh || !existsSync(path)) && !fetched.has(url)) {
      const response = await fetch(url, { signal: AbortSignal.timeout(30000) });
      assert(response.ok, '上游读取失败 ' + response.status + ' ' + url);
      writeFileSync(path, await response.text());
    }
    fetched.set(url, path);
    inputs.push({ ...entry, path, url, kind: 'upstream' });
  }
}

function run(program, args) {
  const result = spawnSync(program, args, {
    cwd: root, encoding: 'utf8', timeout: 60000, maxBuffer: 32 * 1024 * 1024,
  });
  assert.ifError(result.error);
  assert.equal(result.status, 0, result.stderr || result.stdout);
  return result.stdout;
}

const rows = [];
for (const target of ['js', 'native']) {
  const base = join(root, '_build', target, 'release', 'build', 'cmd', 'moon-mock', 'moon-mock');
  const executable = target === 'js' ? process.execPath : base + '.exe';
  const prefix = target === 'js' ? [base + '.js'] : [];
  for (const input of inputs) {
    const args = [...prefix, 'generate', input.path, input.trait];
    const expected = run(executable, args);
    run(executable, args);
    const times = [];
    for (let i = 0; i < samples; i++) {
      const start = process.hrtime.bigint();
      const output = run(executable, args);
      times.push(Number(process.hrtime.bigint() - start) / 1e6);
      assert.equal(output, expected, '同一输入必须得到确定性结果');
    }
    const sorted = [...times].sort((a, b) => a - b);
    const quantile = fraction => sorted[Math.ceil(fraction * sorted.length) - 1];
    const source = readFileSync(input.path);
    const { path, ...metadata } = input;
    rows.push({
      ...metadata, target, input_bytes: source.length, input_sha256: sha256(source),
      output_bytes: Buffer.byteLength(expected), raw_output_sha256: sha256(expected),
      output_sha256: sha256(expected.replaceAll('\r\n', '\n')),
      output_lines: expected.trimEnd().split(/\r?\n/).length,
      samples_ms: times, median_ms: quantile(0.5), p95_ms: quantile(0.95),
      min_ms: sorted[0], max_ms: sorted.at(-1),
    });
    console.log(target + ' ' + input.name + ' 中位数 ' + quantile(0.5).toFixed(3) + ' ms');
  }
}
for (const input of inputs) {
  const pair = rows.filter(row => row.name === input.name);
  assert.equal(pair[0].output_sha256, pair[1].output_sha256, '双后端输出应一致');
}
const result = {
  schema_version: 1,
  measured_at: new Date().toISOString(),
  source_commit: run('git', ['rev-parse', 'HEAD']).trim(),
  benchmark_script_sha256: sha256(readFileSync(fileURLToPath(import.meta.url))),
  tracked_changes: run('git', ['diff', '--stat']).trim(),
  environment: {
    platform: platform(), release: release(), arch: arch(), cpu: cpus()[0]?.model,
    logical_cpus: cpus().length, node: process.version,
    moon: run('moon', ['version', '--all']).trim(),
  },
  method: {
    warmup_processes: 2, measured_processes: samples, build: 'release',
    scope: '独立 CLI 进程的启动、源文件读取、官方解析器、生成、格式化和标准输出的总墙钟时间',
    percentiles: '排序后使用 ceil(p*n)-1 索引，11个样本的p95是最大值',
    output_comparison: '仅规范化 Windows CRLF 为 LF 后比较双后端源码哈希，原始字节哈希单独保留',
  },
  rows,
};
const output = join(root, '_build', 'benchmark-results.json');
writeFileSync(output, JSON.stringify(result, null, 2) + '\n');
console.log('基准原始样本已保存 ' + output);
