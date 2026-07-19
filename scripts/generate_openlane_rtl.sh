#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

TOP_MODULE="rv32i_core"
RTL_LIST="config/rtl.f"

OPENLANE_DESIGN_DIR="openlane/${TOP_MODULE}"
OPENLANE_SRC_DIR="${OPENLANE_DESIGN_DIR}/src"

BUILD_SV2V_DIR="build/sv2v"

mkdir -p \
    "$OPENLANE_SRC_DIR" \
    "$BUILD_SV2V_DIR"

if ! command -v sv2v >/dev/null 2>&1; then
    echo "ERROR: sv2v not found."
    echo "Make sure ~/.local/bin is in PATH."
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

SV2V_BUILD_OUT="${BUILD_SV2V_DIR}/${TOP_MODULE}.sv2v.v"
OPENLANE_RTL_OUT="${OPENLANE_SRC_DIR}/${TOP_MODULE}.v"

echo "=========================================="
echo "Generate OpenLane RTL"
echo "=========================================="
echo "Top module       : ${TOP_MODULE}"
echo "RTL list         : ${RTL_LIST}"
echo "sv2v build out   : ${SV2V_BUILD_OUT}"
echo "OpenLane RTL out : ${OPENLANE_RTL_OUT}"
echo

sv2v \
    --write="${SV2V_BUILD_OUT}" \
    "${RTL_FILES[@]}"

cp "${SV2V_BUILD_OUT}" "${OPENLANE_RTL_OUT}"

echo
echo "Generated:"
echo "  ${SV2V_BUILD_OUT}"
echo "  ${OPENLANE_RTL_OUT}"
echo "=========================================="
