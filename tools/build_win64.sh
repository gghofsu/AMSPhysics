#!/bin/bash
# Cross-build the MSPhysics native extension (msp_lib) together with the Newton
# Dynamics engine (newton.dll) for Windows x64, for one Ruby ABI version.
#
# SketchUp embeds a different Ruby version per release, and a Ruby C extension
# can only be loaded by the Ruby it was linked against:
#
#   SketchUp 2024-2026   Ruby 3.2   (x64-ucrt-ruby320.dll)
#   SketchUp 2027        Ruby 3.4   (x64-ucrt-ruby340.dll)
#
# The build uses Zig's C/C++ front end, which can target x86_64-windows-gnu
# (UCRT based API set) and link against the MSVC style import libraries that
# the SketchUp Ruby headers ship with. No Visual Studio installation is
# required. The import library decides which Ruby library the extension imports
# at run time, and the headers and import libraries come from SketchUp itself
# (see tools/prepare_sources.sh), so a successful link means that every Ruby
# symbol the extension uses is exported by the Ruby of that SketchUp release.
#
# Requirements:
#   * zig 0.16+ on $PATH, or set ZIG=/path/to/zig  (pip install ziglang)
#   * sources prepared by tools/prepare_sources.sh
#
# Usage:
#   tools/prepare_sources.sh
#   tools/build_win64.sh                     # Ruby 3.4 (SketchUp 2027)
#   tools/build_win64.sh --ruby 3.2          # Ruby 3.2 (SketchUp 2024-2026)
#   tools/build_win64.sh --all               # every ABI version that has a dev
#                                            # package in the prepared sources
#   tools/build_win64.sh --no-install        # build only, do not stage
#
# The output is written to tools/out/<ABI> and, unless --no-install is given,
# copied to MSPhysics/libraries/stage/win64/<ABI>/ (msp_lib.so and newton.dll
# have to be shipped as a pair, as they are built from the same sources).
#
# The Newton Dynamics part does not depend on Ruby, so its object files are
# built once, into tools/obj/engine, and reused for every ABI version.
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)

# Locate zig. It is either on the PATH, installed with the ziglang Python
# package (pip install ziglang), or unpacked into a temporary folder.
if [ -z "${ZIG:-}" ]; then
  if command -v zig >/dev/null 2>&1; then
    ZIG=$(command -v zig)
  else
    ZIG=$(python3 -c 'import os, sys, ziglang; sys.stdout.write(os.path.join(os.path.dirname(ziglang.__file__), "zig"))' 2>/dev/null || true)
    [ -n "$ZIG" ] && [ -x "$ZIG" ] || ZIG=""
    for candidate in /tmp/zig-pip/ziglang/zig /tmp/zig-linux-x86_64-*/zig; do
      [ -z "$ZIG" ] && [ -x "$candidate" ] && ZIG=$candidate
    done
    [ -n "$ZIG" ] || ZIG=zig
  fi
fi
SRC=${SRC:-$HERE/src/MSPhysics-master/C++Extension}
B=${B:-$HERE}
OBJ="$B/obj"
JOBS=${JOBS:-$(nproc)}
INSTALL=1
RUBY_ABI=3.4
BUILD_ALL=0

while [ $# -gt 0 ]; do
  case "$1" in
    --ruby) RUBY_ABI=${2:?"--ruby needs a version"}; shift 2 ;;
    --ruby=*) RUBY_ABI=${1#*=}; shift ;;
    --all) BUILD_ALL=1; shift ;;
    --no-install) INSTALL=0; shift ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

command -v "$ZIG" >/dev/null || { echo "zig not found; set ZIG=/path/to/zig" >&2; exit 1; }
[ -d "$SRC/Source/main" ] || { echo "sources not found in $SRC; run tools/prepare_sources.sh" >&2; exit 1; }

R="$SRC/ThirdParty/Ruby"
ND="$SRC/ThirdParty/NewtonDynamics"

mkdir -p "$OBJ/engine" "$B/compat"

# MSVC-isms shim for the non-MSVC toolchain.
cat > "$B/compat/msvcshim.h" <<'EOF'
/* Compatibility shim: MSVC specific intrinsics used by the SketchUp Ruby
   headers (generated for MSVC) and by the MSPhysics sources. */
#ifndef MSP_COMPAT_SHIM_H
#define MSP_COMPAT_SHIM_H
#if defined(__clang__) || defined(__GNUC__)
#  ifndef __assume
#    define __assume(expr) ((void)((expr) ? (void)0 : __builtin_unreachable()))
#  endif
#endif
#endif
EOF

# The Ruby headers for Windows include the Windows SDK version headers.
cat > "$B/compat/WinSDKVer.h" <<'EOF'
#ifndef MSP_WINSDKVER_H
#define MSP_WINSDKVER_H
#define _WIN32_WINNT 0x0601
#define WINVER 0x0601
#endif
EOF
cat > "$B/compat/SDKDDKVer.h" <<'EOF'
#ifndef MSP_SDKDDKVER_H
#define MSP_SDKDDKVER_H
#include "WinSDKVer.h"
#define NTDDI_VERSION 0x06010000
#endif
EOF

# The Universal CRT headers of MinGW make memchr an import of the private API
# set (api-ms-win-crt-private-l1-1-0.dll), which is not part of the documented
# API surface of Windows. Provide it from this translation unit instead, so
# that the libraries only depend on documented libraries.
cat > "$B/compat/memchr_shim.c" <<'EOF'
/* Compatibility shim: keep the private Universal CRT API set out of the import
   table by providing memchr from the library itself. */
#if defined(__cplusplus)
extern "C" {
#endif

#if defined(__clang__)
__attribute__((optnone))
#elif defined(__GNUC__)
__attribute__((optimize("O0")))
#endif
void *memchr(const void *buffer, int character, unsigned long long size)
{
    const unsigned char *p = (const unsigned char *)buffer;
    unsigned char c = (unsigned char)character;
    while (size-- > 0) {
        if (*p == c) return (void *)p;
        p++;
    }
    return 0;
}

#if defined(__cplusplus)
}
#endif
EOF

export ENG_FLAGS="-target x86_64-windows-gnu -O2 -msse2 -msse3 -msse4.1 -DNDEBUG -DWIN32 -D_LIB -D_WIN_64_VER -D_CRT_SECURE_NO_WARNINGS -w \
-I$ND/dMath -I$ND/dgCore -I$ND/dgPhysics -I$ND/dgMeshUtil"

compile_one() { # $1 src, $2 obj, $3 mode
  local s="$1" o="$2" mode="$3" flags
  if [ "$mode" = engine ]; then flags="$ENG_FLAGS"; else flags="$MSP_FLAGS"; fi
  # Incremental: an object that is newer than its source is left alone, so
  # that a rerun only rebuilds what changed (the engine part is large).
  [ -f "$o" ] && [ "$o" -nt "$s" ] && return 0
  mkdir -p "$(dirname "$o")"
  if ! $ZIG c++ $flags -c "$s" -o "$o" 2>"$o.log"; then
    echo "FAIL $s"; grep -E "error|fatal error" "$o.log" | head -6; rm -f "$o"; return 1
  fi
}
export -f compile_one
export ZIG ENG_FLAGS OBJ

build_set() { # $1=label $2=mode $3..=sources
  local label="$1" mode="$2"; shift 2
  echo "=== compiling $label ($# files) ==="
  printf '%s\n' "$@" | xargs -P "$JOBS" -I{} bash -c 'compile_one "$1" "$OBJ/$2/$(basename "$1" .cpp).o" "$2"' _ {} "$mode"
}

# ---------------------------------------------------------------------------
# The Newton Dynamics engine: identical for every Ruby ABI version.
# ---------------------------------------------------------------------------
echo "=== Ruby dev packages available in the prepared sources ==="
ls "$R/include"

build_set "newton engine" engine \
  "$ND"/dMath/*.cpp "$ND"/dgCore/*.cpp "$ND"/dgPhysics/*.cpp "$ND"/dgMeshUtil/*.cpp

echo "=== compiling the compatibility shims ==="
# -fno-builtin keeps the compiler from turning the loop of memchr into a call
# to memchr itself; the function is also marked as not optimizable for that
# reason.
$ZIG cc -target x86_64-windows-gnu -O2 -fno-builtin -c "$B/compat/memchr_shim.c" -o "$OBJ/engine/memchr_shim.o"

echo "=== archiving engine ==="
# dgCore/dgMatrix.cpp and dgCore/dgGoogol.cpp define the static class members
# that other translation units copy in their own static constructors (e.g.
# dgWorkGroupFloat::m_one copies dgVector::m_one) and are therefore linked into
# newton.dll after all other object files; see the note at the link below.
rm -f "$OBJ/libnewton_engine.a"
ENGINE_ARCHIVE_OBJS=()
for obj in "$OBJ"/engine/*.o; do
  base=$(basename "$obj")
  if [ "$base" != "dgMatrix.o" ] && [ "$base" != "dgGoogol.o" ]; then
    ENGINE_ARCHIVE_OBJS+=("$obj")
  fi
done
$ZIG ar rcs "$OBJ/libnewton_engine.a" "${ENGINE_ARCHIVE_OBJS[@]}"

echo "=== linking newton.dll ==="
# MinGW walks __CTOR_LIST__ from the last linked object file to the first (see
# __do_global_ctors in the mingw-w64 CRT), so dgMatrix.o and dgGoogol.o are
# passed explicitly after the other object files: the static dgVector and
# dgGoogol members have to be initialized before the translation units that
# copy them, or the solver runs with zeroed constants.
$ZIG c++ -target x86_64-windows-gnu -shared -Wl,-s -O2 -msse2 -msse3 -msse4.1 -w \
  -DNDEBUG -DWIN32 -D_USRDLL -D_NEWTON_BUILD_DLL -D_WIN_64_VER -D_CRT_SECURE_NO_WARNINGS \
  -I"$ND/dMath" -I"$ND/dgCore" -I"$ND/dgPhysics" -I"$ND/dgMeshUtil" \
  "$ND/dgNewton/Newton.cpp" "$ND/dgNewton/NewtonClass.cpp" \
  -Wl,--out-implib,"$OBJ/newton.lib.a" \
  "${ENGINE_ARCHIVE_OBJS[@]}" "$OBJ/engine/dgGoogol.o" "$OBJ/engine/dgMatrix.o" \
  -o "$OBJ/newton.dll"

# ---------------------------------------------------------------------------
# The Ruby extension: one build per Ruby ABI version.
# ---------------------------------------------------------------------------
build_abi() { # $1 = Ruby ABI version, e.g. 3.4
  local abi="$1"
  local nodot="${abi/./}"
  local out="$B/out/$abi"
  local msp_obj="$OBJ/msp-$abi"
  local inc="$R/include/$abi/win32_x64"
  local lib="$R/lib/win32/x64-ucrt-ruby${nodot}0.lib"

  [ -f "$inc/ruby/config.h" ] || { echo "no Ruby $abi headers at $inc; run tools/prepare_sources.sh" >&2; return 1; }
  [ -f "$lib" ] || { echo "no Ruby $abi import library at $lib; run tools/prepare_sources.sh" >&2; return 1; }

  echo ""
  echo "############################################################"
  echo "# msp_lib for Ruby $abi ($(grep -m1 'RUBY_API_VERSION_MINOR' "$inc/ruby/version.h" | grep -o '[0-9]*' | head -1).x API, $(basename "$lib"))"
  echo "############################################################"

  mkdir -p "$out" "$msp_obj/msp"

  export MSP_FLAGS="-target x86_64-windows-gnu -O2 -msse2 -msse3 -msse4.1 -DNDEBUG -DWIN32 -D_WINDOWS -D_USRDLL -D_CRT_SECURE_NO_WARNINGS \
-DRUBY_VERSION25 -D_WIN_64_VER -D_MT=0 -DHAVE_STRUCT_TIMEZONE=1 -DHAVE_STRUCT_TIMESPEC=1 -w \
-include $B/compat/msvcshim.h \
-I$B/compat -I$inc -I$ND/dgNewton -I$ND/dMath \
-I$SRC/ThirdParty/SDL2/include -I$SRC/ThirdParty/SDL2_mixer/include"
  export OBJ="$msp_obj"

  # memchr has to come from the library itself, so that the private API set of
  # the Universal CRT stays out of the import table (see compat/memchr_shim.c).
  cp -f "$B/obj/engine/memchr_shim.o" "$msp_obj/msp/memchr_shim.o"
  build_set "msp_lib (Ruby $abi)" msp "$SRC"/Source/main/*.cpp "$SRC"/Source/win/*.cpp
  export OBJ="$B/obj"

  # The dMath objects have to be linked into msp_lib explicitly; their symbols
  # are not exported through newton.dll.
  local dmath_objs=""
  for name in dMatrix dVector dQuaternion dLinearAlgebra dMathDefines dStdAfxMath; do
    dmath_objs="$dmath_objs $OBJ/engine/$name.o"
  done

  # Only Init_msp_lib is exported; the rest of the symbols are internal to the
  # extension.
  cat > "$B/RubyExtension-$abi.def" <<'EOF'
LIBRARY

EXPORTS
	Init_msp_lib
EOF

  echo "=== linking msp_lib.so (Ruby $abi) ==="
  $ZIG c++ -target x86_64-windows-gnu -shared -Wl,-s -O2 -msse2 -msse3 -msse4.1 $MSP_FLAGS \
    -Wl,--out-implib,"$out/msp_lib.lib.a" \
    "$B/RubyExtension-$abi.def" \
    "$msp_obj"/msp/*.o $dmath_objs \
    "$OBJ/newton.lib.a" \
    "$SRC/ThirdParty/SDL2/lib/x64/SDL2.lib" \
    "$SRC/ThirdParty/SDL2_mixer/lib/x64/SDL2_mixer.lib" \
    "$lib" \
    -o "$out/msp_lib.so"
  cp -f "$OBJ/newton.dll" "$out/newton.dll"

  if [ "$INSTALL" = "1" ]; then
    local stage="$HERE/../MSPhysics/libraries/stage/win64/$abi"
    mkdir -p "$stage"
    cp -f "$out/msp_lib.so" "$out/newton.dll" "$stage/"
    echo "=== installed to $stage ==="
  fi
  ls -la "$out"
}

if [ "$BUILD_ALL" = "1" ]; then
  # The ABI versions the extension supports on Windows x64: Ruby 3.2, which
  # SketchUp 2024-2026 embed, and Ruby 3.4, which SketchUp 2027 embeds.
  for abi in 3.2 3.4; do
    if [ -f "$R/include/$abi/win32_x64/ruby/config.h" ] && [ -f "$R/lib/win32/x64-ucrt-ruby${abi/./}0.lib" ]; then
      build_abi "$abi"
    else
      echo "skipping Ruby $abi: no dev package in the prepared sources" >&2
    fi
  done
else
  build_abi "$RUBY_ABI"
fi
