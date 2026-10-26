#!/bin/bash
# Run every harness test (see native/harness/README.md).
#
# Every SketchUp release embeds a fixed Ruby version, so the Ruby version of
# the run also selects the SketchUp version that the stub API reports:
#
#   Ruby 3.4 -> SketchUp 2027 (27.0.264)   the default
#   Ruby 3.2 -> SketchUp 2026 (26.2.243)
#
# Usage:
#   native/harness/run_tests.sh                # Ruby 3.4 / SketchUp 2027
#   native/harness/run_tests.sh --ruby 3.2     # Ruby 3.2 / SketchUp 2026
#   native/harness/run_tests.sh --all          # both, one after the other
#
# SU_VERSION=... overrides the simulated SketchUp version, e.g. to run the
# Ruby 3.4 checks against SketchUp 2026.
set -u
cd "$(dirname "$0")/../.."

# The SketchUp version that belongs to a Ruby version.
su_version_for() {
  case "$1" in
    3.2) echo '26.2.243' ;;
    *)   echo '27.0.264' ;;
  esac
}

run_suite() { # $1 = Ruby version
  local version="$1"
  local status=0
  export RUBY_WASM_VERSION="$version"
  export SU_VERSION="${SU_VERSION_OVERRIDE:-$(su_version_for "$version")}"

  echo ""
  echo "################ Ruby $version / SketchUp $SU_VERSION ################"
  # Only the test_*.rb files are tests; tests/fixtures holds the inputs that
  # some of them compile without running them.
  for t in native/harness/tests/test_*.rb; do
    echo "---------- $t"
    local args=""
    # On a Ruby version for which no native engine is staged yet, the load test
    # uses the newest staged engine as a stand-in.
    if [ "$(basename "$t")" = "test_load.rb" ] && \
       [ ! -f "MSPhysics/libraries/stage/win64/$version/msp_lib.so" ]; then
      args="--simulate-abi"
    fi
    if ! node native/harness/run_wasm.js "$t" $args; then
      status=1
    fi
  done
  echo "=================================="
  if [ $status -eq 0 ]; then
    echo "ALL TESTS PASSED (Ruby $version / SketchUp $SU_VERSION)"
  else
    echo "SOME TESTS FAILED (Ruby $version / SketchUp $SU_VERSION)"
  fi
  return $status
}

VERSION=${RUBY_WASM_VERSION:-3.4}
RUN_ALL=0
while [ $# -gt 0 ]; do
  case "$1" in
    --ruby) VERSION=${2:?"--ruby needs a version"}; shift 2 ;;
    --ruby=*) VERSION=${1#*=}; shift ;;
    --all) RUN_ALL=1; shift ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

SU_VERSION_OVERRIDE=${SU_VERSION:-}
export SU_VERSION_OVERRIDE

status=0
if [ "$RUN_ALL" = "1" ]; then
  # The Ruby versions of the SketchUp releases that this build supports: 3.4
  # (SketchUp 2027) and 3.2 (SketchUp 2024-2026).
  for version in 3.4 3.2; do
    run_suite "$version" || status=1
  done
else
  run_suite "$VERSION" || status=1
fi
exit $status
