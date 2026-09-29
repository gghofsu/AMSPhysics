# MSPhysics for SketchUp 2024-2026 (Ruby 3.2)

[MSPhysics](https://github.com/AntonSynytsia/MSPhysics) is a real-time physics
simulation extension for SketchUp, built on the Newton Dynamics engine. This
tree contains MSPhysics together with its dependency
[AMS Library](https://sketchucation.com/plugin/980-ams_lib-rbz), updated to run
on the current SketchUp releases:

* **SketchUp 2026.2** (26.2.243 Win64 / 26.2.242 Mac64), Ruby 3.2.2
* **SketchUp 2025** and **SketchUp 2024**, which also ship Ruby 3.2
  (the previous Ruby 2.x builds are kept for older SketchUp versions)

## What was updated

* **Ruby 3.2 compatibility.** `File.exists?` → `File.exist?`, the removal of
  `Fixnum`/`Bignum`, `taint`/`untaint`, and the double splat / keyword argument
  separation of Ruby 3.
* **SketchUp 2026 API compatibility.** Modifying the properties of a
  `Sketchup::Page` (axes, camera, rendering options, shadow info) has become an
  undoable operation in SketchUp 2026.0, and `Sketchup::ShadowInfo#[]=` is
  stricter since 2026.1 (raises `KeyError`/`TypeError`). Scene changes performed
  by the scene animation, the scene transition and the replay are now wrapped
  into transparent operations, and invalid or read-only shadow info keys are
  skipped. Since 2026.0 inverting a non-invertible transformation raises an
  `ArgumentError`; the extension falls back to an identity transformation.
* **Native engine for Ruby 3.2 on Windows.** `MSPhysics/libraries/stage/win64/3.2/`
  contains `msp_lib.so` and `newton.dll` built for the UCRT based Ruby 3.2
  (`x64-ucrt-ruby320`) that SketchUp 2024-2026 use.
* **AMS Library 3.8.0** ships with a pure Ruby fallback (`ams_lib/ruby_fallback.rb`)
  that provides the native part of the library when there is no build for the
  Ruby version of the running SketchUp, as is the case for Ruby 3.2. Whether the
  native library or the fallback is used is decided at load time.
* **Loader hardening.** `MSPhysics/main_entry.rb` verifies that AMS Library
  3.5+ is installed and that a native engine exists for the running Ruby ABI,
  and otherwise reports the problem instead of raising a `LoadError` on start-up.

## Layout

| Path | Contents |
| --- | --- |
| `MSPhysics.rb`, `MSPhysics/` | The extension itself, including the staged native libraries in `MSPhysics/libraries/stage/`. |
| `ams_lib.rb`, `ams_lib/` | AMS Library, the dependency that provides the window, keyboard, MIDI and geometry helpers. |
| `tools/` | Scripts that download the C++ sources and cross-build the Windows x64 Ruby 3.2 native libraries with Zig. See `tools/build_win64_ruby32.sh`. |
| `native/harness/` | Development harness that loads the extension on Ruby 3.2 with a stubbed SketchUp API. See `native/harness/README.md`. |

## Building the native extension

```sh
pip install ziglang                    # or set ZIG=/path/to/zig
tools/prepare_sources.sh               # downloads the C++ sources and patches them
tools/build_win64_ruby32.sh            # builds msp_lib.so + newton.dll and installs them
```

The sources are downloaded to `tools/src`, the output is written to `tools/out`
and installed into `MSPhysics/libraries/stage/win64/3.2/`. `msp_lib.so` and
`newton.dll` must be shipped as a pair, as both are built from the same
sources.

## Troubleshooting

When MSPhysics fails to load, it reports the actual error instead of leaving it
to SketchUp's extension error report, which may replace the error with a less
helpful one:

* the error, its cause and the backtrace are printed to the Ruby console,
* they are saved next to the extension as `MSPhysics/load_error.txt`,
* and the most important part is shown in a message box.

The report also records the versions, the folders the extension looks in, and
whether the AMS Library fallback and the Windows API (Fiddle) are available.
Attach that report when asking for help.

The two most common causes are:

* **AMS Library is outdated.** MSPhysics needs AMS Library 3.8.0 or later on Ruby
  3, which SketchUp 2024 and later use. Older versions (3.7.1b and before) rely
  on methods that were removed in Ruby 3. Reinstalling MSPhysics installs the
  bundled AMS Library 3.8.0 alongside it.
* **A library of the engine could not be loaded.** The message names the library
  and lists whether each of the `newton.dll`, `SDL2.dll` and `SDL2_mixer.dll`
  libraries could be loaded.

## Testing

The whole suite runs on CRuby 3.2 (the Ruby version of SketchUp 2024-2026) in
WebAssembly, with a stubbed SketchUp 2026 API. `node` and the packages listed in
`native/harness/README.md` are required.

```sh
native/harness/run_tests.sh
```

It checks that every Ruby file compiles, that the extension loads through its
normal entry points, that the AMS Library fallback implements the API MSPhysics
uses, that an engine is staged for the supported SketchUp versions and that the
staging copies the right files for the running Ruby version.

SketchUp announced that it will move to Ruby 3.4; the same suite also runs on
that version, where the missing engine is expected to be reported:

```sh
native/harness/run_tests.sh --ruby 3.4
```

## Credits and licence

MSPhysics and AMS Library are written by Anton Synytsia; the physics engine is
[Julio Jerez's Newton Dynamics](http://newtondynamics.com). Both extensions are
released under the MIT licence, see the `LICENCE-*.txt` files.
