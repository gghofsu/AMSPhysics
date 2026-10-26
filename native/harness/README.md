# Development harness

Runs the Ruby part of MSPhysics and AMS Library outside of SketchUp, on the
Ruby versions that the supported SketchUp releases embed (3.4 for SketchUp 2027,
3.2 for SketchUp 2024-2026), using
[ruby.wasm](https://github.com/ruby/ruby.wasm) and a stubbed SketchUp Ruby API.

This makes it possible to check, without a SketchUp installation, that

* every Ruby file of the repository compiles on the Ruby version of the run
  (`tests/test_compile.rb`),
* the whole require chain works on a 64 bit Windows SketchUp
  (`tests/test_load.rb`): `MSPhysics.rb` → `MSPhysics/main_entry.rb` →
  `ams_lib.rb`/`ams_lib/main.rb` → `MSPhysics/main.rb` → dialogs, control
  panel, replay and settings,
* the differences between the SketchUp versions of the supported range are
  handled: the deprecation of `UI.refresh_toolbars`, the shadow info keys that
  cannot be written, and the versions the loader accepts
  (`tests/test_sketchup_2027.rb`),
* no string literal of the extension is mutated, which Ruby 3.4 reports as a
  deprecation warning and a future Ruby version is to reject with a
  `FrozenError` (`tests/test_chilled_strings.rb`),
* the pure Ruby fallback of AMS Library implements the API that MSPhysics uses
  (`tests/test_ams_fallback.rb`),
* the staged native engines cover the supported Ruby versions
  (`tests/test_abi_gate.rb`),
* the AMS::ExtensionManager staging logic copies the right files for the Ruby
  version of the running SketchUp (`tests/test_extension_manager.rb`),
* MSPhysics still loads next to an AMS Library that is too old for the running
  Ruby version, by using the copy it bundles
  (`tests/test_ams_library_compat.rb`),
* the dependency diagnostics read the import table of the engine and report
  which of the libraries it needs are available (`tests/test_dll_diagnostics.rb`),
* every library that is shipped has all of the libraries it depends on
  (`tests/test_dll_files.rb`),
* loading AMS Library does not delete its own files, and an installation that
  is missing the fallback implementation is repaired
  (`tests/test_ams_clean_up.rb`).

What it does **not** cover: the native libraries (`msp_lib.so`, `newton.dll`,
`ams_lib.so`) are not loaded, so no simulation, no real window handling and no
Newton Dynamics calls are exercised. Use SketchUp for those.

## Requirements

* Node.js 18 or newer
* the Ruby WASM packages:

  ```sh
  npm install --prefix /tmp/rbwasm @ruby/wasm-wasi @ruby/3.4-wasm-wasi @ruby/3.2-wasm-wasi @bjorn3/browser_wasi_shim
  ```

## Usage

```sh
export RUBY_WASM_MODULES=/tmp/rbwasm/node_modules   # optional, this is the default
node native/harness/run_wasm.js native/harness/tests/test_compile.rb
node native/harness/run_wasm.js native/harness/tests/test_load.rb
node native/harness/run_wasm.js native/harness/tests/test_ams_fallback.rb
```

All of the tests at once, on Ruby 3.4 with the stubbed SketchUp 2027:

```sh
native/harness/run_tests.sh
```

The Ruby version of the run also selects the SketchUp version that the stub API
reports, because every SketchUp release embeds a fixed Ruby version:

```sh
native/harness/run_tests.sh --ruby 3.2    # Ruby 3.2 / SketchUp 2026
native/harness/run_tests.sh --all         # both, one after the other
SU_VERSION=26.2.243 native/harness/run_tests.sh --ruby 3.4   # override only the
                                                             # SketchUp version
```

`HARNESS_WARNINGS=deprecated` turns the deprecation warnings of Ruby on, which
is how the chilled strings of Ruby 3.4 become visible:

```sh
HARNESS_WARNINGS=deprecated native/harness/run_tests.sh
```

On a Ruby version for which no native engine is staged, `test_load.rb` copies
the newest staged engine into place as a stand-in (`--simulate-abi`) in order to
exercise the Ruby code. Both Ruby versions that are supported at the moment have
a staged engine, so that only applies to a Ruby version a future SketchUp ships.

Individual scripts can be run on either Ruby version with
`RUBY_WASM_VERSION=3.4 node native/harness/run_wasm.js <script.rb>`.

Any other Ruby script can be run the same way; the repository is available as
the virtual file system root, so `require 'MSPhysics.rb'` and
`require 'ams_lib/main'` work as they do in SketchUp.

## Layout

| Path | Purpose |
| --- | --- |
| `run_wasm.js` | Boots the Ruby 3.4 (or 3.2, via `RUBY_WASM_VERSION`) WASM VM with the repository mounted at `/` and `stubs/` merged into it. |
| `run_tests.sh` | Runs all of the tests. |
| `stubs/sketchup.rb`, `stubs/extensions.rb` | Stand-ins for SketchUp's own Ruby files. |
| `stubs/stub_sketchup_api.rb` | Stub of the SketchUp Ruby API (`Sketchup`, `UI`, `Geom`, entities, observers, model, pages, rendering options, shadow info, ...), reporting itself as 64 bit SketchUp 2027 on Windows unless `SU_VERSION` says otherwise. |
| `stubs/stub_msphysics_native.rb` | Fakes for the classes that come from `msp_lib.so` (`MSPhysics::Newton`, `MSPhysics::SDL`, `MSPhysics::Mixer`, `MSPhysics::Sound`, `MSPhysics::Music`) and their constants. |
| `tests/test_*.rb` | The checks described above. |
| `tests/fixtures/` | Inputs that the checks compile but do not run. |

The stubs are development-only and are not shipped with the extension.
