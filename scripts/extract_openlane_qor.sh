#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

DESIGN_NAME="rv32i_core"
RUN_ROOT="openlane/${DESIGN_NAME}/runs"

if [[ ! -d "$RUN_ROOT" ]]; then
    echo "ERROR: Missing run root: $RUN_ROOT"
    exit 1
fi

RUN_DIR="${1:-$(ls -dt ${RUN_ROOT}/RUN_* | head -1)}"

if [[ ! -d "$RUN_DIR" ]]; then
    echo "ERROR: Invalid RUN_DIR: $RUN_DIR"
    exit 1
fi

OUT_DIR="reports/step8"
OUT_MD="${OUT_DIR}/step8e_openlane_qor_summary.md"
OUT_TXT="${OUT_DIR}/step8e_openlane_qor_metrics.txt"

mkdir -p "$OUT_DIR"

echo "Using RUN_DIR: $RUN_DIR"

python3 - "$RUN_DIR" "$OUT_TXT" <<'PY'
import json
import re
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
out_txt = Path(sys.argv[2])

state_files = list(run_dir.rglob("state_out.json"))

if not state_files:
    raise SystemExit(f"No state_out.json found in {run_dir}")

def step_key(path: Path):
    # Example: 67-checker-lvs/state_out.json
    parent = path.parent.name
    m = re.match(r"(\d+)-", parent)
    if m:
        return int(m.group(1))
    return -1

# Prefer the latest step state_out.
state_files = sorted(state_files, key=step_key)
latest = state_files[-1]

data = json.loads(latest.read_text())

keys = [
    # Flow status
    "flow_errors_count",
    "design__lint_error__count",
    "design__lint_warning__count",
    "design__inferred_latch__count",
    "synthesis_check_error_count",

    # Generic design
    "design__instance__count",
    "design__instance__area",
    "design__core__area",
    "design__die__area",
    "design__utilization",

    # Timing
    "design__setup__ws",
    "design__setup__tns",
    "design__setup__violation__count",
    "design__hold__ws",
    "design__hold__tns",
    "design__hold__violation__count",

    # Alternative timing key names
    "design_setup_wns",
    "design_setup_tns",
    "design_setup_violation_count",
    "design_hold_wns",
    "design_hold_tns",
    "design_hold_violation_count",

    # Electrical
    "design_max_slew_violation_count",
    "design_max_fanout_violation_count",
    "design_max_cap_violation_count",
    "design__max_slew_violation__count",
    "design__max_fanout_violation__count",
    "design__max_cap_violation__count",

    # Routing / DRC / LVS / antenna
    "route__drc_errors",
    "route_drc_errors",
    "route__antenna_violation__count",
    "route_antenna_violation_count",
    "design__violations",
    "design_violations",

    # Power grid
    "design_power_grid_violation_count",
    "design_power_grid_violation_count__net:VPWR",
    "design_power_grid_violation_count__net:VGND",
]

lines = []
lines.append(f"RUN_DIR: {run_dir}")
lines.append(f"METRICS_SOURCE: {latest}")
lines.append("")

for k in keys:
    if k in data:
        lines.append(f"{k}: {data[k]}")

# Also print all likely QoR keys if exact names differ.
lines.append("")
lines.append("---- Additional matched metrics ----")
patterns = [
    "wns", "tns", "violation", "drc", "antenna", "area",
    "util", "instance", "cell", "power", "slew", "fanout", "cap"
]

for k in sorted(data.keys()):
    lk = k.lower()
    if any(p in lk for p in patterns):
        if k not in keys:
            lines.append(f"{k}: {data[k]}")

out_txt.write_text("\n".join(lines) + "\n")
print("\n".join(lines))
PY

cat > "$OUT_MD" <<EOF2
# STEP 08E — OpenLane QoR Summary

## Run

\`\`\`text
$(basename "$RUN_DIR")
\`\`\`

## Metrics

Raw extracted metrics:

\`\`\`text
$(cat "$OUT_TXT")
\`\`\`

## Final Artifacts

\`\`\`text
$(find "$RUN_DIR/final" -maxdepth 3 -type f 2>/dev/null | sort || true)
\`\`\`

## Notes

This is the first OpenLane smoke-run QoR extraction for the RV32I core.

The current goal is not final signoff closure yet. The goal is to establish a baseline for:

- area
- utilization
- timing
- routing DRC
- antenna
- power grid
- final generated artifacts

EOF2

echo
echo "Generated:"
echo "  $OUT_TXT"
echo "  $OUT_MD"
