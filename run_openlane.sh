#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 <rv32i_core|rv32i_soc> [additional OpenLane arguments...]"
}

if [[ $# -lt 1 ]]; then
  usage
  exit 2
fi

DESIGN="$1"
shift

case "$DESIGN" in
  rv32i_core|rv32i_soc) ;;
  *)
    echo "ERROR: unsupported design '$DESIGN'."
    usage
    exit 2
    ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
PDK_ROOT="${PDK_ROOT:-$HOME/.volare}"
PDK="${PDK:-sky130A}"
OPENLANE_IMAGE="${OPENLANE_IMAGE:-ghcr.io/efabless/openlane2:3.0.0.dev21}"
DESIGN_DIR="$PROJECT_ROOT/openlane/$DESIGN"
CONFIG_FILE="$DESIGN_DIR/config.json"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "ERROR: missing $CONFIG_FILE"
  echo "Create the OpenLane 2 configuration after the RTL top-level and constraints are frozen."
  exit 1
fi

if [[ ! -d "$PDK_ROOT" ]]; then
  echo "ERROR: PDK_ROOT does not exist: $PDK_ROOT"
  exit 1
fi

mkdir -p "$DESIGN_DIR/runs"

echo "Design         : $DESIGN"
echo "Design dir     : $DESIGN_DIR"
echo "Run output     : $DESIGN_DIR/runs/RUN_<timestamp>"
echo "PDK_ROOT       : $PDK_ROOT"
echo "PDK            : $PDK"
echo "OpenLane image : $OPENLANE_IMAGE"

# Use the host UID/GID so generated runs are not owned by root.
docker run --rm \
  --user "$(id -u):$(id -g)" \
  --env HOME=/tmp \
  --env PDK_ROOT="$PDK_ROOT" \
  --env PDK="$PDK" \
  --volume "$PROJECT_ROOT:$PROJECT_ROOT" \
  --volume "$PDK_ROOT:$PDK_ROOT" \
  --workdir "$DESIGN_DIR" \
  "$OPENLANE_IMAGE" \
  openlane --pdk "$PDK" config.json "$@"
