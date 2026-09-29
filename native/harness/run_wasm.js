#!/usr/bin/env node
// Development harness: run a Ruby script with CRuby 3.2 (ruby.wasm) against the
// files of this repository.
//
// The script to run is read from the host file system and evaluated inside the
// VM. `require` calls resolve within the virtual file system, which contains
// the repository itself (at '/') plus the stub SketchUp API found in
// native/harness/stubs.
//
// Usage:
//   node native/harness/run_wasm.js native/harness/tests/test_load.rb
//
// Requirements:
//   npm install --prefix /tmp/rbwasm @ruby/wasm-wasi @ruby/3.2-wasm-wasi \
//       @bjorn3/browser_wasi_shim
//   (set RUBY_WASM_MODULES to a different prefix if installed elsewhere)
const fs = require('fs');
const path = require('path');

const MODULES = process.env.RUBY_WASM_MODULES || '/tmp/rbwasm/node_modules';
const { RubyVM } = require(path.join(MODULES, '@ruby/wasm-wasi/dist/cjs/vm.js'));
const {
  ConsoleStdout,
  Directory,
  File,
  OpenFile,
  PreopenDirectory,
  WASI,
} = require(path.join(MODULES, '@bjorn3/browser_wasi_shim'));

const ROOT = path.resolve(__dirname, '..', '..');
const STUBS = path.join(__dirname, 'stubs');

// Build a browser_wasi_shim Directory tree from a host directory.
function buildDirectory(hostDir, filter) {
  const dir = new Directory(new Map());
  for (const entry of fs.readdirSync(hostDir, { withFileTypes: true })) {
    const name = entry.name;
    const full = path.join(hostDir, name);
    if (filter && !filter(full, name, entry)) continue;
    if (entry.isDirectory()) {
      dir.contents.set(name, buildDirectory(full, filter));
    } else if (entry.isFile()) {
      dir.contents.set(name, new File(fs.readFileSync(full)));
    }
  }
  return dir;
}

const skip = (full, name) =>
  name !== '.git' && name !== 'node_modules' && name !== 'doc' && !name.endsWith('.zip');

const root = buildDirectory(ROOT, (full, name, entry) => {
  if (entry.isDirectory()) return skip(full, name);
  return true;
});
// Merge the stub SketchUp API into the root directory.
for (const entry of fs.readdirSync(STUBS)) {
  root.contents.set(entry, new File(fs.readFileSync(path.join(STUBS, entry))));
}

const scriptPath = process.argv[2];
if (!scriptPath) {
  console.error('usage: node run_wasm.js <script.rb> [args...]');
  process.exit(2);
}
const code = fs.readFileSync(scriptPath, 'utf8');

function lineBuffered(prefix) {
  // NOTE: The shim's lineBuffered helper delivers complete lines (without the
  // trailing newline), so nothing may be re-buffered here.
  return ConsoleStdout.lineBuffered((line) => process.stdout.write(prefix + line + '\n'));
}

(async () => {
  const fds = [
    new OpenFile(new File([])),
    lineBuffered(''),
    lineBuffered('[rb stderr] '),
    // PreopenDirectory expects the contents map, not the Directory itself.
    new PreopenDirectory('/', root.contents),
  ];
  const wasi = new WASI([], [], fds, { debug: false });
  const source = fs.readFileSync(
    path.join(MODULES, '@ruby/3.2-wasm-wasi/dist/ruby+stdlib.wasm')
  );
  const module_ = await WebAssembly.compile(source);
  const { vm } = await RubyVM.instantiateModule({ module: module_, wasip1: wasi });
  try {
    vm.eval("$LOAD_PATH.unshift('/') unless $LOAD_PATH.include?('/')");
    vm.eval("ARGV.replace(" + JSON.stringify(process.argv.slice(3)) + ")");
    vm.eval(code);
  } catch (err) {
    const message = err && err.message ? err.message : String(err);
    console.error('RUBY ERROR: ' + message);
    process.exitCode = 1;
  }
})();
