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
  (`tests/test_ams_fallback.rb`).

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

Any other Ruby script can be run the same way; the repository is available as
the virtual file system root, so `require 'MSPhysics.rb'` and
`require 'ams_lib/main'` work as they do in SketchUp.

All of the tests can also be run at once:

```sh
native/harness/run_tests.sh
```

## Layout

| Path | Purpose |
| --- | --- |
| `run_wasm.js` | Boots the Ruby 3.2 WASM VM with the repository mounted at `/` and `stubs/` merged into it. |
| `stubs/sketchup.rb`, `stubs/extensions.rb` | Stand-ins for SketchUp's own Ruby files. |
| `stubs/stub_sketchup_api.rb` | Stub of the SketchUp Ruby API (`Sketchup`, `UI`, `Geom`, entities, observers, model, pages, rendering options, shadow info, ...), reporting itself as 64 bit SketchUp 2026 on Windows. |
| `stubs/stub_msphysics_native.rb` | Fakes for the classes that come from `msp_lib.so` (`MSPhysics::Newton`, `MSPhysics::SDL`, `MSPhysics::Mixer`, `MSPhysics::Sound`, `MSPhysics::Music`) and their constants. |
| `tests/*.rb` | The checks described above. |

The stubs are development-only and are not shipped with the extension.
