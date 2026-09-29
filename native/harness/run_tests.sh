#!/bin/bash
# Run every harness test (see native/harness/README.md).
set -u
cd "$(dirname "$0")/../.."
status=0
for t in native/harness/tests/*.rb; do
  echo "---------- $t"
  if ! node native/harness/run_wasm.js "$t"; then
    status=1
  fi
done
echo "=================================="
if [ $status -eq 0 ]; then
  echo "ALL TESTS PASSED"
else
  echo "SOME TESTS FAILED"
fi
exit $status
