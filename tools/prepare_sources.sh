#!/bin/bash
# Download the sources that the native build needs and apply the patches that
# are required to build them with a non-MSVC toolchain (see patches/).
#
# Two upstream projects are involved:
#
#   1. https://github.com/AntonSynytsia/MSPhysics (branch master), which
#      contains the C++ extension, the Newton Dynamics engine and the Ruby
#      headers and import libraries up to Ruby 3.2 (introduced with pull
#      request #32).
#   2. https://github.com/SketchUp/testup-2, SketchUp's own test extension,
#      which contains the Ruby headers and import libraries of the Ruby
#      versions that SketchUp ships, including the Ruby 3.4 dev package of
#      SketchUp 2027 (ruby340/win32_x64 + x64-ucrt-ruby340.lib).
#
# The Ruby dev package of a SketchUp release is the authoritative source: the
# engine has to be linked against the very Ruby library that the running
# SketchUp loads, and the import library names it.
#
# Usage:
#   tools/prepare_sources.sh [destination]
#
# The destination defaults to tools/src.
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
DEST=${1:-$HERE/src}
URL="https://codeload.github.com/AntonSynytsia/MSPhysics/tar.gz/refs/heads/master"
SU_REPO="SketchUp/testup-2"

# The Ruby ABI versions for which the SketchUp Ruby dev package is fetched from
# SketchUp's repository, mapped to the folder and the import library they use.
SU_RUBY_ABIS="3.4"

mkdir -p "$DEST"
if [ ! -d "$DEST/MSPhysics-master" ]; then
  echo "==> downloading $URL"
  curl -fsSL "$URL" -o "$DEST/msphysics-master.tar.gz"
  tar -xzf "$DEST/msphysics-master.tar.gz" -C "$DEST"
fi

cd "$DEST/MSPhysics-master"

echo "==> applying patches"
apply_patch() { # $1 = patch file, $2 = description
  if patch -p1 -N --dry-run --silent < "$1" >/dev/null 2>&1; then
    patch -p1 -N --silent < "$1"
    echo "    patched $2"
  elif patch -p1 -R --dry-run --silent < "$1" >/dev/null 2>&1; then
    echo "    already patched: $2"
  else
    echo "    FAILED to apply (conflicts): $2" >&2
    return 1
  fi
}

apply_patch "$HERE/patches/ruby_prep.h.patch" "C++Extension/Source/main/ruby_prep.h"
apply_patch "$HERE/patches/dgTypes.cpp.patch" "C++Extension/ThirdParty/NewtonDynamics/dgCore/dgTypes.cpp"
apply_patch "$HERE/patches/msp_crash_fixes.patch" "C++Extension/Source/main (user data, GC protection and dangling pointers)"

# Fetch the Ruby dev package (headers + import library) of a SketchUp release
# from SketchUp's own repository and place it where the build expects it:
#   ThirdParty/Ruby/include/<ABI>/win32_x64
#   ThirdParty/Ruby/lib/win32/x64-ucrt-ruby<ABI without the dot>0.lib
fetch_sketchup_ruby() { # $1 = Ruby ABI version, e.g. 3.4
  local abi="$1"
  local pkg="ruby${abi/./}0"   # e.g. "3.4" -> "ruby340"
  local ruby="C++Extension/ThirdParty/Ruby"
  local inc="$ruby/include/$abi/win32_x64"
  local lib="$ruby/lib/win32/x64-ucrt-$pkg.lib"

  if [ -f "$inc/ruby/config.h" ] && [ -f "$lib" ]; then
    echo "    Ruby $abi dev package already present"
    return 0
  fi

  echo "==> downloading the SketchUp Ruby $abi dev package from $SU_REPO"
  local branch
  branch=$(curl -fsSL "https://api.github.com/repos/$SU_REPO" |
    sed -n 's/.*"default_branch": *"\([^"]*\)".*/\1/p' | head -1)
  [ -n "$branch" ] || { echo "could not determine the default branch of $SU_REPO" >&2; return 1; }
  local tarball="$DEST/sketchup-testup-2-$branch.tar.gz"
  if [ ! -f "$tarball" ]; then
    curl -fsSL "https://codeload.github.com/$SU_REPO/tar.gz/refs/heads/$branch" -o "$tarball"
  fi

  # The dev package lives below the taskbar list C extension of the repository.
  local prefix
  prefix=$(tar -tzf "$tarball" | grep -m1 "/ThirdParty/include/$pkg/win32_x64/ruby/config.h$") || {
    echo "the Ruby $abi dev package was not found in $SU_REPO" >&2; return 1; }
  prefix=${prefix%%/ThirdParty/include/$pkg/win32_x64/ruby/config.h}

  mkdir -p "$(dirname "$inc")" "$ruby/lib/win32"
  tar -xzf "$tarball" -C "$DEST" \
    "$prefix/ThirdParty/include/$pkg/win32_x64" \
    "$prefix/ThirdParty/lib/win/x64/x64-ucrt-$pkg.lib"
  cp -r "$DEST/$prefix/ThirdParty/include/$pkg/win32_x64" "$inc"
  cp "$DEST/$prefix/ThirdParty/lib/win/x64/x64-ucrt-$pkg.lib" "$lib"
  rm -rf "$DEST/$prefix"

  # The headers are generated for MSVC and refuse to be used by another
  # compiler. The cross-build uses the C/C++ front end of Zig instead, exactly
  # as the Ruby 3.2 headers of the MSPhysics sources are used (there the check
  # is commented out as well).
  if grep -q '^#if (_MSC_VER' "$inc/ruby/config.h"; then
    sed -i 's|^#if (_MSC_VER|// #if (_MSC_VER|; s|^#error MSC version unmatch|// #error MSC version unmatch|' \
      "$inc/ruby/config.h"
    # The #endif of the check follows the two commented lines.
    sed -i '0,/^#endif$/s|^#endif$|// #endif|' "$inc/ruby/config.h"
    echo "    allowed the Ruby $abi headers to be used by a non-MSVC compiler"
  fi
  echo "    Ruby $abi dev package: $(find "$inc" -type f | wc -l) headers + $(basename "$lib")"
}

for abi in $SU_RUBY_ABIS; do
  fetch_sketchup_ruby "$abi"
done

echo "==> sources ready at $DEST/MSPhysics-master"
