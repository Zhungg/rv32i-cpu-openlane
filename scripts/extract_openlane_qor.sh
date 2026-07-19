#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

DESIGN_NAME="rv32i_core"
RUN_ROOT="openlane/${DESIGN_NAME}/runs"

RUN_DIR="${1:-$(ls -dt ${RUN_ROOT}/RUN_* | head -1)}"

if [[ ! -d "$RUN_DIR" ]]; then
    echo "ERROR: Invalid RUN_DIR: $RUN_DIR"
    exit 1
fi

OUT_DIR="reports/step8"
OUT_TXT="${OUT_DIR}/step8e_openlane_qor_metrics.txt"
OUT_MD="${OUT_DIR}/step8e_openlane_qor_summary.md"

mkdir -p "$OUT_DIR"

python3 - "$RUN_DIR" "$OUT_TXT" <<'PY'
import json
import re
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
out_txt = Path(sys.argv[2])

json_files = []
json_files += list(run_dir.rglob("state_out.json"))
json_files += list(run_dir.rglob("metrics.json"))
json_files += list(run_dir.rglob("*.metrics.json"))

def step_num(path: Path):
    m = re.match(r"(\d+)-", path.parent.name)
    return int(m.group(1)) if m else -1

json_files = sorted(set(json_files), key=lambda p: (step_num(p), str(p)))

all_metrics = {}
sources = {}

def flatten(obj, prefix=""):
    flat = {}
    if isinstance(obj, dict):
        for k, v in obj.items():
            key = f"{prefix}.{k}" if prefix else str(k)
            if isinstance(v, dict):
                flat.update(flatten(v, key))
            else:
                flat[key] = v
    return flat

for jf in json_files:
    try:
        data = json.loads(jf.read_text())
    except Exception:
        continue

    candidates = []

    if isinstance(data, dict):
        candidates.append(data)
        if isinstance(data.get("metrics"), dict):
            candidates.append(data["metrics"])

    for cand in candidates:
        flat = flatten(cand)

        for k, v in flat.items():
            lk = k.lower()

            # Keep likely QoR/status metrics.
            wanted = any(token in lk for token in [
                "flow",
                "error",
                "warning",
                "latch",
                "instance",
                "cell",
                "area",
                "util",
                "wns",
                "tns",
                "slack",
                "violation",
                "drc",
                "lvs",
                "antenna",
                "slew",
                "fanout",
                "cap",
                "power",
                "wire",
                "route",
                "die",
                "core"
            ])

            if wanted:
                all_metrics[k] = v
                sources[k] = str(jf)

preferred_keys = [
    "flow_errors_count",
    "design_lint_error_count",
    "design__lint_error__count",
    "design_lint_warning_count",
    "design__lint_warning__count",
    "design__inferred_latch__count",
    "synthesis_check_error_count",

    "design__instance__count",
    "design__instance__area",
    "design__core__area",
    "design__die__area",
    "design__utilization",

    "design_setup_wns",
    "design_setup_tns",
    "design_setup_violation_count",
    "design_hold_wns",
    "design_hold_tns",
    "design_hold_violation_count",

    "design__setup__ws",
    "design__setup__tns",
    "design__setup__violation__count",
    "design__hold__ws",
    "design__hold__tns",
    "design__hold__violation__count",

    "design_max_slew_violation_count",
    "design_max_fanout_violation_count",
    "design_max_cap_violation_count",

    "route_drc_errors",
    "route__drc_errors",
    "route_antenna_violation_count",
    "route__antenna_violation__count",

    "design_violations",
    "design__violations",

    "design_power_grid_violation_count",
    "design_power_grid_violation_count__net:VPWR",
    "design_power_grid_violation_count__net:VGND",
]

lines = []
lines.append(f"RUN_DIR: {run_dir}")
lines.append(f"JSON_FILES_SCANNED: {len(json_files)}")
lines.append("")

lines.append("---- Key metrics ----")
for k in preferred_keys:
    if k in all_metrics:
        lines.append(f"{k}: {all_metrics[k]}")

lines.append("")
lines.append("---- All matched metrics ----")
for k in sorted(all_metrics):
    lines.append(f"{k}: {all_metrics[k]}")

lines.append("")
lines.append("---- Metric sources ----")
for k in sorted(sources):
    lines.append(f"{k}: {sources[k]}")

out_txt.write_text("\n".join(lines) + "\n")
print("\n".join(lines))
PY

cat > "$OUT_MD" <<EOF2
# STEP 08E — OpenLane QoR Summary

## Run

\`\`\`text
$RUN_DIR
\`\`\`

## Extracted Metrics

\`\`\`text
$(cat "$OUT_TXT")
\`\`\`

## Final Artifacts

\`\`\`text
$(find "$RUN_DIR/final" -maxdepth 3 -type f 2>/dev/null | sort || true)
\`\`\`

## Notes

This is the first OpenLane QoR baseline for the RV32I core.

The goal of this step is to record baseline metrics after the first OpenLane smoke run, not to close final timing or electrical QoR yet.
EOF2

echo
echo "Generated:"
echo "  $OUT_TXT"
echo "  $OUT_MD"
