#!/usr/bin/env bash
# Codex Cloud: bounded execution for potentially hanging build/test commands.
# Usage: bash tool/run_bounded_audit.sh NAME SECONDS command [args...]
# Examples:
#   bash tool/run_bounded_audit.sh analyze 180 flutter analyze --no-pub
#   bash tool/run_bounded_audit.sh test-pdf 180 flutter test --no-pub test/pdf_service_test.dart
#   bash tool/run_bounded_audit.sh tests 480 flutter test --no-pub
#   bash tool/run_bounded_audit.sh web 900 flutter build web --release --no-pub

set -u
if [[ "$#" -lt 3 ]]; then
  echo "Usage: bash tool/run_bounded_audit.sh NAME SECONDS COMMAND [ARGS...]" >&2
  exit 2
fi
name="$1"; shift
duration="$1"; shift

if [[ ! "$name" =~ ^[a-zA-Z0-9_-]{1,48}$ ]]; then
  echo "Invalid NAME: use letters, digits, hyphen or underscore" >&2
  exit 2
fi
if [[ ! "$duration" =~ ^[0-9]+$ ]] || ((duration < 1 || duration > 1200)); then
  echo "Invalid SECONDS: must be 1..1200" >&2
  exit 2
fi
if ! command -v timeout >/dev/null 2>&1; then
  echo "TIMEOUT_TOOL_UNAVAILABLE. Do NOT run unbounded command; switch to existing CI." >&2
  exit 127
fi
umask 077
logdir="${TMPDIR:-/tmp}/petita-audit-results"
mkdir -p "$logdir"
logfile="$(mktemp "$logdir/${name}.XXXXXX.log")"
start="$(date +%s)"
set +e
timeout --signal=TERM --kill-after=15s "${duration}s" "$@" >"$logfile" 2>&1
status=$?
set -e
elapsed="$(( $(date +%s) - start ))"
echo "AUDIT_RESULT label=$name status=$status seconds=$elapsed log=$logfile"
case "$status" in
  0) echo "AUDIT_PASS label=$name" ;;
  124|137) echo "AUDIT_TIMEOUT label=$name. Record as blocked; do not retry without a concrete change." >&2 ;;
  *) echo "AUDIT_FAILURE label=$name. Investigate or move to next priority." >&2 ;;
esac
echo "--- Last 35 lines of command output ---"
tail -n 35 "$logfile"
echo "--- End of output ---"
exit "$status"
