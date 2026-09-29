# Development harness

Runs the Ruby part of MSPhysics and AMS Library outside of SketchUp, on the
same Ruby version that SketchUp 2024-2026 embeds (Ruby 3.2), using
[ruby.wasm](https://github.com/ruby/ruby.wasm) and a stubbed SketchUp Ruby API.

This makes it possible to check, without a SketchUp installation, that

* every Ruby file of the repository compiles on Ruby 3.2
  (`tests/test_compile.rb`),
* the whole require chain works on a 64 bit Windows SketchUp 2026
  (`tests/test_load.rb`): `MSPhysics.rb` → `MSPhysics/main_entry.rb` →
  `ams_lib.rb`/`ams_lib/main.rb` → `MSPhysics/main.rb` → dialogs, control
  panel, replay and settings,
* the pure Ruby fallback of AMS Library implements the API that MSPhysics uses
  (`tests/test_ams_fallback.rb`),
* the staged native engines cover the supported SketchUp versions
  (`tests/test_abi_gate.rb`),
* the AMS::ExtensionManager staging logic copies the right files for the Ruby
  version of the running SketchUp (`tests/test_extension_manager.rb`).

What it does **not** cover: the native libraries (`msp_lib.so`, `newton.dll`,
`ams_lib.so`) are not loaded, so no simulation, no real window handling and no
Newton Dynamics calls are exercised. Use SketchUp for those.

## Requirements

* Node.js 18 or newer
* the Ruby WASM packages:

  ```sh
  npm install --prefix /tmp/rbwasm @ruby/wasm-wasi @ruby/3.2-wasm-wasi @bjorn3/browser_wasi_shim
  ```

## Usage

```sh
export RUBY_WASM_MODULES=/tmp/rbwasm/node_modules   # optional, this is the default
node native/harness/run_wasm.js native/harness/tests/test_compile.rb
node native/harness/run_wasm.js native/harness/tests/test_load.rb
node native/harness/run_wasm.js native/harness/tests/test_ams_fallback.rb
```

All of the tests at once, on the Ruby version SketchUp 2024-2026 embed:

```sh
native/harness/run_tests.sh
```

SketchUp announced that it will move to Ruby 3.4. The same tests can be run on
that version, if `@ruby/3.4-wasm-wasi` is installed next to the packages above.
On Ruby 3.4 no native engine is staged yet, so `test_load.rb` copies the 3.2
engine into place as a stand-in (`--simulate-abi`) in order to exercise the Ruby
code, and `test_extension_manager.rb` verifies that the missing engine is
reported instead of failing.

```sh
native/harness/run_tests.sh --ruby 3.4
```

Individual scripts can be run on Ruby 3.4 with
`RUBY_WASM_VERSION=3.4 node native/harness/run_wasm.js <script.rb>`.

Any other Ruby script can be run the same way; the repository is available as
the virtual file system root, so `require 'MSPhysics.rb'` and
`require 'ams_lib/main'` work as they do in SketchUp.

## Layout

| Path | Purpose |
| --- | --- |
| `run_wasm.js` | Boots the Ruby 3.2 (or 3.4, via `RUBY_WASM_VERSION`) WASM VM with the repository mounted at `/` and `stubs/` merged into it. |
| `run_tests.sh` | Runs all of the tests. |
| `stubs/sketchup.rb`, `stubs/extensions.rb` | Stand-ins for SketchUp's own Ruby files. |
| `stubs/stub_sketchup_api.rb` | Stub of the SketchUp Ruby API (`Sketchup`, `UI`, `Geom`, entities, observers, model, pages, rendering options, shadow info, ...), reporting itself as 64 bit SketchUp 2026 on Windows. |
| `stubs/stub_msphysics_native.rb` | Fakes for the classes that come from `msp_lib.so` (`MSPhysics::Newton`, `MSPhysics::SDL`, `MSPhysics::Mixer`, `MSPhysics::Sound`, `MSPhysics::Music`) and their constants. |
| `tests/*.rb` | The checks described above. |

The stubs are development-only and are not shipped with the extension.
