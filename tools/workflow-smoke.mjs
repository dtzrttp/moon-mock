import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, readFileSync, writeFileSync, existsSync, linkSync, chmodSync } from 'node:fs';
import { join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
const target = process.argv[2] ?? 'js';
assert(['js', 'native'].includes(target));
const base = join(root, '_build', target, 'debug', 'build', 'cmd', 'moon-mock', 'moon-mock');
const program = target === 'js' ? process.execPath : base + '.exe';
const prefix = target === 'js' ? [base + '.js'] : [];
const dir = mkdtempSync(join(root, '_build', 'workflow-smoke-'));
let commands = 0;
function run(code, args, cwd = root) {
  commands++;
  const result = spawnSync(program, [...prefix, ...args], { cwd, encoding: 'utf8', timeout: 30000 });
  assert.ifError(result.error);
  assert.equal(result.status, code, result.stderr + result.stdout);
  return result;
}
const source = join(dir, 'traits.mbt');
const manifest = join(dir, 'jobs.json');
writeFileSync(source, 'trait Reader { fn read(Self, Int32) -> String }\ntrait Writer { fn write(Self, String) -> Unit }\n');
const jobs = [
  { source: 'traits.mbt', trait: 'Reader', output: 'mock_reader_wbtest.mbt' },
  { source: 'traits.mbt', trait: 'Writer', output: 'mock_writer_wbtest.mbt' },
];
const reader = join(dir, jobs[0].output);
const writer = join(dir, jobs[1].output);
const save = items => writeFileSync(manifest, JSON.stringify({ schema_version: 1, jobs: items }));
const batch = (...extra) => ['batch', manifest, ...extra];
const inspect = JSON.parse(run(0, ['inspect', source, '--json']).stdout);
assert.equal(inspect.type_checked, false);
assert.deepEqual(inspect.traits.map(t => t.name), ['Reader', 'Writer']);
assert.equal(inspect.traits[0].methods[0].parameter_count, 2);
assert.match(run(0, ['inspect', source]).stdout, /Reader/);
run(2, ['inspect', source, '--unknown']);
run(2, ['inspect', 'README.md']);
const missingInspect = JSON.parse(run(1, ['inspect', join(dir, 'missing.mbt'), '--json']).stdout);
assert.equal(missingInspect.diagnostics[0].code, 'source_read_error');
const invalidUtf8 = join(dir, 'invalid_utf8.mbt');
writeFileSync(invalidUtf8, Buffer.from([0xff, 0xfe]));
assert.match(run(1, ['inspect', invalidUtf8]).stderr, /source_invalid_utf8/);
const oversizedSource = join(dir, 'oversized.mbt');
writeFileSync(oversizedSource, Buffer.alloc(4 * 1024 * 1024 + 1, 32));
const oversizedReport = JSON.parse(run(1, ['inspect', oversizedSource, '--json']).stdout);
assert.equal(oversizedReport.diagnostics[0].code, 'source_read_error');
assert.match(oversizedReport.diagnostics[0].message, /source_too_large/);

save(jobs);
const initialCheck = JSON.parse(run(2, batch('--check')).stdout);
assert.deepEqual(initialCheck.jobs.map(j => j.status), ['out_of_date', 'out_of_date']);
assert(!existsSync(reader));
assert(!existsSync(writer));
const generated = JSON.parse(run(0, batch()).stdout);
assert.deepEqual(generated.jobs.map(j => j.status), ['written', 'written']);
const originalReader = readFileSync(reader, 'utf8');
const originalWriter = readFileSync(writer, 'utf8');
const checked = JSON.parse(run(0, batch('--check')).stdout);
assert.deepEqual(checked.jobs.map(j => j.status), ['current', 'current']);
// 从不同工作目录调用，任务路径始终相对于清单目录。
run(0, ['batch', 'jobs.json', '--check'], dir);
save(jobs.map(job => ({ ...job, source })));
run(0, batch('--check'));
save(jobs);

writeFileSync(reader, originalReader + '// changed\n');
const stale = JSON.parse(run(2, batch('--check')).stdout);
assert.deepEqual(stale.jobs.map(j => j.status), ['out_of_date', 'current']);
assert.equal(readFileSync(writer, 'utf8'), originalWriter);
run(0, batch());
assert.equal(readFileSync(reader, 'utf8'), originalReader);

// 后面的生成任务失败时，前面成功任务的输出也不能被更新。
save([jobs[0], { ...jobs[1], trait: 'Missing' }]);
writeFileSync(reader, originalReader + '// keep\n');
const failed = JSON.parse(run(1, batch()).stdout);
assert.deepEqual(failed.jobs.map(j => j.status), ['ready', 'failed']);
assert.match(failed.jobs[1].error, /trait_not_found/);
assert.equal(readFileSync(reader, 'utf8'), originalReader + '// keep\n');
writeFileSync(reader, originalReader);

// 预检必须拒绝重复输出、越界、与任意其他任务输入冲突、已有手写文件。
save([jobs[0], { ...jobs[1], output: './mock_reader_wbtest.mbt' }]);
assert.match(run(2, batch()).stderr, /duplicate_output/);
save([{ ...jobs[0], output: '../escape_wbtest.mbt' }]);
assert.match(run(2, batch()).stderr, /manifest_invalid/);
save([{ ...jobs[0], output: join(dir, 'absolute_wbtest.mbt') }]);
assert.match(run(2, batch()).stderr, /manifest_invalid/);
writeFileSync(writer, 'let handwritten = 1\n');
save(jobs);
assert.match(run(2, batch()).stderr, /refuse_overwrite/);
assert.equal(readFileSync(reader, 'utf8'), originalReader);
assert.equal(readFileSync(writer, 'utf8'), 'let handwritten = 1\n');
writeFileSync(writer, originalWriter);

const inputAlias = join(dir, 'input_wbtest.mbt');
writeFileSync(inputAlias, '// 由 moon-mock 生成\ntrait Other { fn get(Self) -> Unit }\n');
save([
  { ...jobs[0], output: 'input_wbtest.mbt' },
  { source: 'input_wbtest.mbt', trait: 'Other', output: 'other_wbtest.mbt' },
]);
assert.match(run(2, batch()).stderr, /source_output_conflict/);
assert.match(readFileSync(inputAlias, 'utf8'), /trait Other/);

save([{ ...jobs[0], output: 'missing/nested_wbtest.mbt' }]);
assert.match(run(2, batch()).stderr, /output_parent_missing/);
save([jobs[0], { ...jobs[1], output: 'invoice?_wbtest.mbt' }]);
assert.match(run(2, batch()).stderr, /manifest_invalid/);
assert.equal(readFileSync(reader, 'utf8'), originalReader);
save([{ ...jobs[0], sources: ['./traits.mbt'] }]);
assert.match(run(2, batch()).stderr, /duplicate_source/);
save([{ ...jobs[0], source: 'missing.mbt' }]);
assert.match(run(1, batch()).stderr, /source_read_error/);

// 预检也拒绝与输入内容相同的输出，保守覆盖不同路径的硬链接别名。
const hardlinkInput = join(dir, 'generated_like.mbt');
const hardlinkOutput = join(dir, 'linked_wbtest.mbt');
const generatedLike = '// 由 moon-mock 生成\nlet generated_marker = true\n';
writeFileSync(hardlinkInput, generatedLike);
linkSync(hardlinkInput, hardlinkOutput);
save([{ ...jobs[0], sources: ['generated_like.mbt'], output: 'linked_wbtest.mbt' }]);
assert.match(run(2, batch()).stderr, /source_output_alias/);
assert.equal(readFileSync(hardlinkInput, 'utf8'), generatedLike);

// 让第二个输出写入失败，核对批次报告中的已写入及失败状态。
writeFileSync(reader, originalReader + '// stale\n');
chmodSync(writer, 0o444);
const thirdOutput = join(dir, 'mock_third_wbtest.mbt');
writeFileSync(thirdOutput, originalReader);
const threeJobs = [jobs[0], jobs[1], { ...jobs[0], mock_name: 'MockThirdReader', output: 'mock_third_wbtest.mbt' }];
save(threeJobs);
const partialWrite = run(1, batch());
const partialReport = JSON.parse(partialWrite.stdout);
assert.match(partialWrite.stderr, /batch_write_partial/);
assert.deepEqual(partialReport.jobs.map(job => job.status), ['written', 'failed', 'not_attempted']);
assert.equal(readFileSync(reader, 'utf8'), originalReader);
assert.equal(readFileSync(thirdOutput, 'utf8'), originalReader);
chmodSync(writer, 0o666);
assert.equal(readFileSync(writer, 'utf8'), originalWriter);

save([]);
assert.deepEqual(JSON.parse(run(0, batch()).stdout).jobs, []);
writeFileSync(manifest, '{"schema_version":1,"jobs":[],"jobs":[]}');
assert.match(run(2, batch()).stderr, /manifest_invalid/);
writeFileSync(source, 'trait Broken {');
const broken = JSON.parse(run(1, ['inspect', source, '--json']).stdout);
assert.equal(broken.traits.length, 0);
assert(broken.diagnostics.length > 0);
assert.equal(broken.diagnostics[0].code, 'parse_error');
assert.equal(readFileSync(reader, 'utf8'), originalReader);
console.log(target + ' 检查/批量工作流实际执行 ' + commands + ' 条命令，来源 ' + relative(root, dir));
