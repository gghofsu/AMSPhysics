#!/bin/bash
# Run every harness test (see native/harness/README.md).
#
# Usage:
#   native/harness/run_tests.sh              # Ruby 3.2 (SketchUp 2024-2026)
#   native/harness/run_tests.sh --ruby 3.4   # the announced Ruby 3.4
set -u
cd "$(dirname "$0")/../.."

VERSION=${RUBY_WASM_VERSION:-3.2}
if [ "${1:-}" = "--ruby" ]; then
  VERSION=${2:-3.2}
fi
export RUBY_WASM_VERSION=$VERSION

echo "== Ruby $VERSION =="
status=0
for t in native/harness/tests/*.rb; do
  echo "---------- $t"
  args=""
  # On a Ruby version for which no native engine is staged yet, the load test
  # uses the 3.2 engine as a stand-in.
  if [ "$(basename "$t")" = "test_load.rb" ] && [ "$VERSION" != "3.2" ]; then
    args="--simulate-abi"
  fi
  if ! node native/harness/run_wasm.js "$t" $args; then
    status=1
  fi
done
echo "=================================="
if [ $status -eq 0 ]; then
  echo "ALL TESTS PASSED (Ruby $VERSION)"
else
  echo "SOME TESTS FAILED (Ruby $VERSION)"
fi
exit $status
