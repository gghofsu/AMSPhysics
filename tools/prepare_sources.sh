#!/bin/bash
# Download the MSPhysics C++ sources and apply the patches that are needed to
# build them with a non-MSVC toolchain (see patches/).
#
# The downloaded sources are the upstream master branch of
# https://github.com/AntonSynytsia/MSPhysics, which contains the Ruby 3.2 build
# support (headers for win32/x64 + mac, and the x64-ucrt-ruby320 import library)
# that was introduced with pull request #32.
#
# Usage:
#   tools/prepare_sources.sh [destination]
#
# The destination defaults to tools/src.
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
DEST=${1:-$HERE/src}
URL="https://codeload.github.com/AntonSynytsia/MSPhysics/tar.gz/refs/heads/master"

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

echo "==> sources ready at $DEST/MSPhysics-master"
