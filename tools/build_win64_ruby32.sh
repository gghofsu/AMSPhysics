#!/bin/bash
# Cross-build the MSPhysics native extension (msp_lib) together with the Newton
# Dynamics engine (newton.dll) for SketchUp 2024-2026 on Windows x64, which use
# Ruby 3.2 (x64-ucrt-ruby320).
#
# The build uses Zig's C/C++ front end, which can target x86_64-windows-gnu
# (UCRT based API set) and link against the MSVC style import libraries that the
# Ruby 3.2 headers ship with. No Visual Studio installation is required.
#
# Requirements:
#   * zig 0.16+ on $PATH, or set ZIG=/path/to/zig  (pip install ziglang)
#   * sources prepared by tools/prepare_sources.sh
#
# Usage:
#   tools/prepare_sources.sh
#   tools/build_win64_ruby32.sh [--no-install]
#
# The output is written to tools/out and, unless --no-install is given, copied
# to MSPhysics/libraries/stage/win64/3.2/ (msp_lib.so and newton.dll have to be
# shipped as a pair, as they are built from the same sources).
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
ZIG=${ZIG:-zig}
SRC=${SRC:-$HERE/src/MSPhysics-master/C++Extension}
B=${B:-$HERE}
OUT="$B/out"
OBJ="$B/obj"
JOBS=${JOBS:-$(nproc)}
INSTALL=1
[ "${1:-}" = "--no-install" ] && INSTALL=0

command -v "$ZIG" >/dev/null || { echo "zig not found; set ZIG=/path/to/zig" >&2; exit 1; }
[ -d "$SRC/Source/main" ] || { echo "sources not found in $SRC; run tools/prepare_sources.sh" >&2; exit 1; }

mkdir -p "$OUT" "$OBJ/engine" "$OBJ/msp" "$B/compat"
R="$SRC/ThirdParty/Ruby"
ND="$SRC/ThirdParty/NewtonDynamics"

# MSVC-isms shim for the non-MSVC toolchain.
cat > "$B/compat/msvcshim.h" <<'EOF'
/* Compatibility shim: MSVC specific intrinsics used by the SketchUp Ruby 3.2
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

export MSP_FLAGS="-target x86_64-windows-gnu -O2 -msse2 -msse3 -msse4.1 -DNDEBUG -DWIN32 -D_WINDOWS -D_USRDLL -D_CRT_SECURE_NO_WARNINGS \
-DRUBY_VERSION25 -D_WIN_64_VER -D_MT=0 -DHAVE_STRUCT_TIMEZONE=1 -DHAVE_STRUCT_TIMESPEC=1 -w \
-include $B/compat/msvcshim.h \
-I$B/compat -I$R/include/3.2/win32_x64 -I$ND/dgNewton -I$ND/dMath \
-I$SRC/ThirdParty/SDL2/include -I$SRC/ThirdParty/SDL2_mixer/include"

compile_one() { # $1 src, $2 obj, $3 mode
  local s="$1" o="$2" mode="$3" flags
  if [ "$mode" = engine ]; then flags="$ENG_FLAGS"; else flags="$MSP_FLAGS"; fi
  mkdir -p "$(dirname "$o")"
  if ! $ZIG c++ $flags -c "$s" -o "$o" 2>"$o.log"; then
    echo "FAIL $s"; grep -E "error|fatal error" "$o.log" | head -6; rm -f "$o"; return 1
  fi
}
export -f compile_one
export ZIG ENG_FLAGS MSP_FLAGS OUT OBJ

build_set() { # $1=label $2=mode $3..=sources
  local label="$1" mode="$2"; shift 2
  echo "=== compiling $label ($# files) ==="
  printf '%s\n' "$@" | xargs -P "$JOBS" -I{} bash -c 'compile_one "$1" "$OBJ/$2/$(basename "$1" .cpp).o" "$2"' _ {} "$mode"
}

build_set "newton engine" engine \
  "$ND"/dMath/*.cpp "$ND"/dgCore/*.cpp "$ND"/dgPhysics/*.cpp "$ND"/dgMeshUtil/*.cpp
build_set "msp_lib" msp "$SRC"/Source/main/*.cpp "$SRC"/Source/win/*.cpp

echo "=== compiling the compatibility shims ==="
# -fno-builtin keeps the compiler from turning the loop of memchr into a call
# to memchr itself; the function is also marked as not optimizable for that
# reason.
$ZIG cc -target x86_64-windows-gnu -O2 -fno-builtin -c "$B/compat/memchr_shim.c" -o "$OBJ/engine/memchr_shim.o"
cp -f "$OBJ/engine/memchr_shim.o" "$OBJ/msp/memchr_shim.o"

echo "=== archiving engine ==="
rm -f "$OUT/libnewton_engine.a"
$ZIG ar rcs "$OUT/libnewton_engine.a" "$OBJ"/engine/*.o

echo "=== linking newton.dll ==="
$ZIG c++ -target x86_64-windows-gnu -shared -O2 -msse2 -msse3 -msse4.1 -w \
  -DNDEBUG -DWIN32 -D_USRDLL -D_NEWTON_BUILD_DLL -D_WIN_64_VER -D_CRT_SECURE_NO_WARNINGS \
  -I"$ND/dMath" -I"$ND/dgCore" -I"$ND/dgPhysics" -I"$ND/dgMeshUtil" \
  "$ND/dgNewton/Newton.cpp" "$ND/dgNewton/NewtonClass.cpp" \
  -Wl,--out-implib,"$OUT/newton.lib.a" \
  "$OUT/libnewton_engine.a" -o "$OUT/newton.dll"

echo "=== linking msp_lib.so ==="
# The dMath objects have to be linked into msp_lib explicitly; their symbols are
# not exported through newton.dll.
DMATH_OBJS=""
for name in dMatrix dVector dQuaternion dLinearAlgebra dMathDefines dStdAfxMath; do
  DMATH_OBJS="$DMATH_OBJS $OBJ/engine/$name.o"
done

# Only Init_msp_lib is exported; the rest of the symbols are internal to the
# extension.
cat > "$B/RubyExtension.def" <<'EOF'
LIBRARY

EXPORTS
	Init_msp_lib
EOF

$ZIG c++ -target x86_64-windows-gnu -shared -O2 -msse2 -msse3 -msse4.1 $MSP_FLAGS \
  -Wl,--out-implib,"$OUT/msp_lib.lib.a" \
  "$B/RubyExtension.def" \
  "$OBJ"/msp/*.o $DMATH_OBJS \
  "$OUT/newton.lib.a" \
  "$SRC/ThirdParty/SDL2/lib/x64/SDL2.lib" \
  "$SRC/ThirdParty/SDL2_mixer/lib/x64/SDL2_mixer.lib" \
  "$R/lib/win32/x64-ucrt-ruby320.lib" \
  -o "$OUT/msp_lib.so"

echo "=== stripping ==="
$ZIG strip -s "$OUT/msp_lib.so" "$OUT/newton.dll" 2>/dev/null || true

if [ "$INSTALL" = "1" ]; then
  STAGE="$HERE/../MSPhysics/libraries/stage/win64/3.2"
  mkdir -p "$STAGE"
  cp -f "$OUT/msp_lib.so" "$OUT/newton.dll" "$STAGE/"
  echo "=== installed to $STAGE ==="
fi
ls -la "$OUT"
