#!/usr/bin/env bash
set -euo pipefail

cat <<'MSG'
Memory-interface shell regression: SKIPPED

Reason:
  This test belonged to Step 5H, where LOAD/STORE instructions were
  intentionally stalled and the core was not allowed to issue DMEM requests.

Current design state:
  Step 6C has integrated the real LSU into the MEM stage.
  LOAD/STORE instructions are now expected to issue DMEM requests and retire
  after receiving DMEM responses.

Use these regressions instead:
  make test-lsu-leaf
  make test-lsu-controller
  make test-lsu-core
MSG
