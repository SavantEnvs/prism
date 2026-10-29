#!/usr/bin/env bash
# Runs upstream's C++ binding test suite (test/cpp, built by mayhem/build.sh with normal flags).
# Each test prints "ok    <name>" or "FAILED <name>" and the runner prints "<N> tests, <M> failed checks".
set -uo pipefail
cd "$SRC"
# emit_ctrf <tool> <passed> <failed> [skipped] [pending] [other]
# Writes a CTRF report (file + stdout `CTRF {...}` marker) and returns non-zero iff failed>0.
emit_ctrf() {
  local tool="$1" passed="$2" failed="$3" skipped="${4:-0}" pending="${5:-0}" other="${6:-0}"
  local tests=$(( passed + failed + skipped + pending + other ))
  cat > "${CTRF_REPORT:-$SRC/ctrf-report.json}" <<JSON
{
  "results": {
    "tool": { "name": "$tool" },
    "summary": {
      "tests": $tests,
      "passed": $passed,
      "failed": $failed,
      "pending": $pending,
      "skipped": $skipped,
      "other": $other
    }
  }
}
JSON
  printf 'CTRF {"results":{"tool":{"name":"%s"},"summary":{"tests":%d,"passed":%d,"failed":%d,"pending":%d,"skipped":%d,"other":%d}}}\n' \
    "$tool" "$tests" "$passed" "$failed" "$pending" "$skipped" "$other"
  [ "$failed" -eq 0 ]
}

RUNNER=build/tests/cpp_test
[ -x "$RUNNER" ] || { echo "missing $RUNNER (mayhem/build.sh should have built it)" >&2; emit_ctrf "prism-cpp" 0 1 0; exit 1; }

out=$("$RUNNER" 2>&1); rc=$?
printf '%s\n' "$out"
passed=$(printf '%s\n' "$out" | grep -c '^ok  ')
failed=$(printf '%s\n' "$out" | grep -c '^FAILED ')
summary=$(printf '%s\n' "$out" | grep -E '^[0-9]+ tests, [0-9]+ failed checks$' | tail -1)
# Neutered/crashed runner: no summary line, or zero tests, or a non-zero exit with no FAILED line.
if [ -z "$summary" ] || [ "$passed" -eq 0 ] || { [ "$rc" -ne 0 ] && [ "$failed" -eq 0 ]; }; then
  failed=$((failed + 1))
fi
emit_ctrf "prism-cpp" "$passed" "$failed" 0
