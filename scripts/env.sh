#!/usr/bin/env bash
# Source file này từ thư mục gốc của dự án:
#   source scripts/env.sh

export PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PDK_ROOT="${PDK_ROOT:-$HOME/.volare}"
export PDK="${PDK:-sky130A}"
export OPENLANE_IMAGE="${OPENLANE_IMAGE:-ghcr.io/efabless/openlane2:2.3.10}"

echo "PROJECT_ROOT=$PROJECT_ROOT"
echo "PDK_ROOT=$PDK_ROOT"
echo "PDK=$PDK"
echo "OPENLANE_IMAGE=$OPENLANE_IMAGE"
