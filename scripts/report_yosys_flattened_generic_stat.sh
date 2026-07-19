#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

TOP_MODULE="rv32i_core"
SV2V_NETLIST="build/sv2v/${TOP_MODULE}.sv2v.v"

mkdir -p build/yosys logs/yosys reports/yosys

if [[ ! -f "$SV2V_NETLIST" ]]; then
    echo "ERROR: Missing ${SV2V_NETLIST}"
    echo "Run scripts/check_yosys_synthesis_readiness_sv2v.sh first."
    exit 1
fi

YOSYS_SCRIPT="build/yosys/report_flattened_generic_stat.ys"

cat > "$YOSYS_SCRIPT" <<YOSYS
read_verilog ${SV2V_NETLIST}

hierarchy -check -top ${TOP_MODULE}

proc
opt

flatten
opt_clean

check
stat

write_verilog -noattr build/yosys/${TOP_MODULE}.flattened.generic.v
YOSYS

yosys -l logs/yosys/report_flattened_generic_stat.log "$YOSYS_SCRIPT"

cp logs/yosys/report_flattened_generic_stat.log \
   reports/yosys/report_flattened_generic_stat.log

echo "Generated:"
echo "  reports/yosys/report_flattened_generic_stat.log"
echo "  build/yosys/${TOP_MODULE}.flattened.generic.v"
