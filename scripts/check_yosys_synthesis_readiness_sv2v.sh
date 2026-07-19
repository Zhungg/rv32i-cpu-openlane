#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

TOP_MODULE="rv32i_core"
RTL_LIST="config/rtl.f"

mkdir -p \
    build/sv2v \
    build/yosys \
    logs/yosys \
    reports/yosys

if ! command -v sv2v >/dev/null 2>&1; then
    echo "ERROR: sv2v not found."
    echo "Install sv2v or use a Yosys build with read_slang/read_systemverilog."
    exit 1
fi

if ! command -v yosys >/dev/null 2>&1; then
    echo "ERROR: yosys not found."
    exit 1
fi

RTL_FILES=()

while IFS= read -r source_file; do
    [[ -z "$source_file" ]] && continue
    [[ "$source_file" =~ ^[[:space:]]*# ]] && continue

    if [[ ! -f "$source_file" ]]; then
        echo "ERROR: Missing RTL source: $source_file"
        exit 1
    fi

    RTL_FILES+=("$source_file")
done < "$RTL_LIST"

SV2V_OUT="build/sv2v/${TOP_MODULE}.sv2v.v"
YOSYS_SCRIPT="build/yosys/check_synthesis_readiness_sv2v.ys"

echo "=========================================="
echo "RV32I sv2v + Yosys Synthesis Readiness"
echo "=========================================="
echo "Top module : ${TOP_MODULE}"
echo "RTL list   : ${RTL_LIST}"
echo "sv2v       : $(sv2v --version 2>/dev/null || echo available)"
echo "Yosys      : $(yosys -V)"
echo

echo "[1/3] Converting SystemVerilog to Verilog using sv2v"

sv2v \
    --write="${SV2V_OUT}" \
    "${RTL_FILES[@]}"

echo "sv2v output: ${SV2V_OUT}"

echo
echo "[2/3] Creating Yosys script"

cat > "$YOSYS_SCRIPT" <<YOSYS
read_verilog ${SV2V_OUT}

hierarchy -check -top ${TOP_MODULE}

proc
opt
check

stat

write_verilog -noattr build/yosys/${TOP_MODULE}.generic.v
YOSYS

echo
echo "[3/3] Running Yosys"

yosys -l logs/yosys/check_synthesis_readiness_sv2v.log \
      "$YOSYS_SCRIPT"

cp logs/yosys/check_synthesis_readiness_sv2v.log \
   reports/yosys/check_synthesis_readiness_sv2v.log

echo
echo "=========================================="
echo "sv2v + Yosys synthesis-readiness check: PASS"
echo "Generated:"
echo "  ${SV2V_OUT}"
echo "  logs/yosys/check_synthesis_readiness_sv2v.log"
echo "  reports/yosys/check_synthesis_readiness_sv2v.log"
echo "  build/yosys/${TOP_MODULE}.generic.v"
echo "=========================================="
