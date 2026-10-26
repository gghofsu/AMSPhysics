# MSPhysics for SketchUp 2024-2027 (Ruby 3.2 and Ruby 3.4)

[MSPhysics](https://github.com/AntonSynytsia/MSPhysics) is a real-time physics
simulation extension for SketchUp, built on the Newton Dynamics engine. This
tree contains MSPhysics together with its dependency
[AMS Library](https://sketchucation.com/plugin/980-ams_lib-rbz), updated to run
on the current SketchUp releases:

* **SketchUp 2027** (27.0.264 Win64), Ruby 3.4.9
* **SketchUp 2026.2** (26.2.243 Win64 / 26.2.242 Mac64), Ruby 3.2.2
* **SketchUp 2025** and **SketchUp 2024**, which also ship Ruby 3.2
  (the previous Ruby 2.x builds are kept for older SketchUp versions)

Every SketchUp release embeds a fixed Ruby version, so the native part of an
extension has to be built once per SketchUp generation. This tree stages an
engine for both generations:

| Ruby ABI | SketchUp | Staged in |
| --- | --- | --- |
| `x64-ucrt-ruby340` (3.4) | 2027 | `MSPhysics/libraries/stage/win64/3.4/` |
| `x64-ucrt-ruby320` (3.2) | 2024-2026 | `MSPhysics/libraries/stage/win64/3.2/` |

## What was updated

* **Ruby 3.4 compatibility.** Ruby 3.4 compiles the string literals of a file
  that has no `frozen_string_literal` comment into *chilled* strings: mutating
  one still works, but it is reported as a deprecation warning, and a future
  Ruby version is to freeze them. Every accumulator in the extension that
  starts with a literal (`cmd = ''`, then `cmd << ...`) now starts with
  `String.new` instead, in the panels and dialogs that assemble their
  JavaScript, in the replay writer, in the translation and in the library
  report. The harness walks the instructions of every Ruby file of the
  extension to verify that no literal is mutated any more
  (`native/harness/tests/test_chilled_strings.rb`). Prism is the parser of
  Ruby 3.4; every file of the extension compiles with it unchanged.
* **SketchUp 2027 API compatibility.**
  * `UI.refresh_toolbars` is deprecated, as SketchUp refreshes its toolbars
    itself now. `AMS.refresh_toolbars` only calls it on SketchUp 2026 and
    earlier (`AMS.ui_refresh_toolbars_available?`), so it no longer writes a
    deprecation warning into the Ruby console of SketchUp 2027.
  * `Sketchup::ShadowInfo#[]=` warns instead of raising when a read-only key
    is written. MSPhysics skips the keys that cannot be written anyway and,
    while it does, filters the warnings it suppresses out of the console.
  * `Sketchup::ModelObserver#onDeleteModel` and `#onEraseAll` are deprecated in
    favour of `Sketchup::AppObserver#onCloseModel`. MSPhysics does not
    implement either of them; its observers are `Sketchup::AppObserver`
    (`onNewModel`, `onOpenModel`, `onQuit`) and selection observers, which are
    unchanged in 2027.
  * The modifier flags that `Sketchup::Tool#onKeyDown` and `#onKeyUp` report
    were corrected in 2027. MSPhysics compares the key code and not the flags,
    so its tools need no change.
  * Scene changes performed by the scene animation, the scene transition and
    the replay are wrapped into transparent operations, and inverting a
    non-invertible transformation falls back to an identity transformation, as
    both were changed in SketchUp 2026 and stay that way in 2027.
* **Ruby 3.2 compatibility.** `File.exists?` → `File.exist?`, the removal of
  `Fixnum`/`Bignum`, `taint`/`untaint`, and the double splat / keyword
  argument separation of Ruby 3.
* **Native engines for both Ruby versions.** `tools/build_win64.sh` builds
  `msp_lib.so` and `newton.dll` for either ABI from the same engine objects,
  and installs them into the folder the loader looks in for the running Ruby
  version.
* **AMS Library 3.8.1** knows the Ruby versions up to 3.5
  (`AMS::IS_RUBY_VERSION_34`, `AMS::IS_RUBY_VERSION_35`), exposes the ABI it
  was built for (`AMS::RUBY_ABI_VERSION`), and ships a pure Ruby fallback
  (`ams_lib/ruby_fallback.rb`) that provides the native part of the library
  when there is no build for the Ruby version of the running SketchUp. Whether
  the native library or the fallback is used is decided at load time.
* **Loader hardening.** `MSPhysics/main_entry.rb` verifies that AMS Library
  3.5+ is installed and that a native engine exists for the running Ruby ABI,
  and otherwise reports the problem instead of raising a `LoadError` on
  start-up.

### Known limitation in SketchUp 2027

SketchUp 2027 introduces MDI: several models are open in tabs of one window at
the same time. MSPhysics was written for a single document window and keeps its
state for the model that is active when the simulation is started; simulating
several models at the same time is not supported. The extension itself loads
and runs in an MDI window.

## Layout

| Path | Contents |
| --- | --- |
| `MSPhysics.rb`, `MSPhysics/` | The extension itself, including the staged native libraries in `MSPhysics/libraries/stage/`. |
| `ams_lib.rb`, `ams_lib/` | AMS Library, the dependency that provides the window, keyboard, MIDI and geometry helpers. |
| `tools/` | Scripts that download the C++ sources and cross-build the Windows x64 native libraries with Zig. See `tools/build_win64.sh`. |
| `native/harness/` | Development harness that loads the extension on Ruby 3.4 and Ruby 3.2 with a stubbed SketchUp API. See `native/harness/README.md`. |

## Building the native extension

```sh
pip install ziglang                    # or set ZIG=/path/to/zig
tools/prepare_sources.sh               # downloads the C++ sources and patches them
tools/build_win64.sh                   # Ruby 3.4 (SketchUp 2027)
tools/build_win64.sh --ruby 3.2        # Ruby 3.2 (SketchUp 2024-2026)
tools/build_win64.sh --all             # both
```

One run of `prepare_sources.sh` fetches the headers and import libraries of
both ABIs: the Ruby 3.4 dev package of SketchUp 2027 (`ruby340/win32_x64` and
`x64-ucrt-ruby340.lib`) from `SketchUp/testup-2`, and the Ruby versions up to
3.2 from the MSPhysics repository itself. The sources are downloaded to
`tools/src`, the output is written to `tools/obj` and `tools/out` and installed
into `MSPhysics/libraries/stage/win64/<abi>/`. `msp_lib.so` and `newton.dll` must be
shipped as a pair, as both are built from the same sources. The engine objects
are shared between the ABIs, so only the extension is recompiled for the second
one.

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

When one of the libraries the engine needs cannot be loaded, the report names
the library and the Windows error, and lists the libraries that the failing
library itself depends on, together with whether each of them is loaded in
SketchUp, exists as a file, or cannot be found. The dependencies are read from
the import table of the library, so they are also reported when the Windows API
cannot be called through Fiddle.

The two most common causes are:

* **AMS Library is outdated.** MSPhysics needs AMS Library 3.8.0 or later on
  Ruby 3, which every SketchUp from 2024 on uses, because only that version
  loads a pure Ruby fallback when there is no native build for the running
  Ruby version. Older versions (3.7.1b and before) rely on methods that were
  removed in Ruby 3. Reinstalling MSPhysics installs the bundled AMS Library
  3.8.1 alongside it, which is the version that handles the SketchUp 2027
  changes.
* **AMS Library is incomplete.** AMS Library 3.8.0a and before delete the Ruby
  files of their folder that are not registered with their extension manager
  while cleaning up, which removed `ruby_fallback.rb` and left the library
  broken from the second start of SketchUp on. MSPhysics restores the file from
  the copy it ships in `MSPhysics/ams_lib_fallback/` when it finds the
  installation in that state, so no manual repair is needed.
* **A library of the engine could not be loaded.** The message names the library
  and lists whether each of the `newton.dll`, `SDL2.dll` and `SDL2_mixer.dll`
  libraries could be loaded.
* **The engine of the extension is older than the extension.** An engine built
  for another Ruby version cannot be loaded, which is what the report says when
  it finds a staged engine that is linked against a different Ruby library.

## Testing

The whole suite runs on CRuby 3.4 (the Ruby version of SketchUp 2027) in
WebAssembly, with a stubbed SketchUp 2027 API. `node` and the packages listed in
`native/harness/README.md` are required.

```sh
native/harness/run_tests.sh            # Ruby 3.4 / SketchUp 2027
native/harness/run_tests.sh --ruby 3.2 # Ruby 3.2 / SketchUp 2026
native/harness/run_tests.sh --all      # both, one after the other
```

It checks that every Ruby file compiles, that the extension loads through its
normal entry points, that the SketchUp 2027 API changes are handled, that no
string literal of the extension is mutated, that the AMS Library fallback
implements the API MSPhysics uses, that an engine is staged for the supported
Ruby versions and that the staging copies the right files for the running Ruby
version.

With `HARNESS_WARNINGS=deprecated` the harness also turns the deprecation
warnings of Ruby on, which is how the chilled strings of Ruby 3.4 are found:

```sh
HARNESS_WARNINGS=deprecated native/harness/run_tests.sh
```

## Credits and licence

MSPhysics and AMS Library are written by Anton Synytsia; the physics engine is
[Julio Jerez's Newton Dynamics](http://newtondynamics.com). Both extensions are
released under the MIT licence, see the `LICENCE-*.txt` files.
