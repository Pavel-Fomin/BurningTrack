#!/bin/sh

# Dev-only structural diff двух legacy DeviceSQL export.pdb.
# Скрипт не использует симуляторы и не запускает UI.

set -eu

if [ "$#" -ne 2 ]; then
    echo "Usage: Scripts/PioneerDeckExport/diff_export_pdb.sh <reference-export.pdb> <generated-export.pdb>" >&2
    exit 64
fi

REFERENCE_PDB="$1"
GENERATED_PDB="$2"

if [ ! -f "$REFERENCE_PDB" ]; then
    echo "Reference export.pdb not found: $REFERENCE_PDB" >&2
    exit 66
fi

if [ ! -f "$GENERATED_PDB" ]; then
    echo "Generated export.pdb not found: $GENERATED_PDB" >&2
    exit 66
fi

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
OUTPUT_DIR="${PIONEER_PDB_DIFF_OUTPUT_DIR:-$REPO_ROOT/.build/pioneer-pdb-diff}"
SCRIPT_HOME="$OUTPUT_DIR/home"
CLANG_CACHE_DIR="$OUTPUT_DIR/clang-module-cache"

mkdir -p "$OUTPUT_DIR"
mkdir -p "$SCRIPT_HOME"
mkdir -p "$CLANG_CACHE_DIR"

echo "Reference: $REFERENCE_PDB"
echo "Generated: $GENERATED_PDB"
echo "Output: $OUTPUT_DIR"

cd "$REPO_ROOT"

HOME="$SCRIPT_HOME" \
CLANG_MODULE_CACHE_PATH="$CLANG_CACHE_DIR" \
PIONEER_REFERENCE_PDB="$REFERENCE_PDB" \
PIONEER_GENERATED_PDB="$GENERATED_PDB" \
PIONEER_PDB_DIFF_OUTPUT_DIR="$OUTPUT_DIR" \
swift test --filter PioneerPDBStructuralDiffTests/testReferenceAndGeneratedExportPDBStructuralDiff

echo "Reference dump: $OUTPUT_DIR/reference-dump.json"
echo "Generated dump: $OUTPUT_DIR/generated-dump.json"
echo "Diff JSON: $OUTPUT_DIR/diff-report.json"
echo "Diff text: $OUTPUT_DIR/diff-report.txt"
