#!/bin/sh

# Dev-only проверка generated export.pdb внешним parser'ом rekordcrate.
# Скрипт не использует симуляторы и не подключает экспорт к UI.

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
OUTPUT_DIR="${PIONEER_EXTERNAL_PDB_OUTPUT_DIR:-$REPO_ROOT/.build/pioneer-external-pdb-validation}"
SCRIPT_HOME="$OUTPUT_DIR/home"
CLANG_CACHE_DIR="$OUTPUT_DIR/clang-module-cache"

mkdir -p "$OUTPUT_DIR"
mkdir -p "$SCRIPT_HOME"
mkdir -p "$CLANG_CACHE_DIR"

echo "Parser: rekordcrate dump-pdb"
echo "Output: $OUTPUT_DIR"
if [ -n "${PIONEER_VALIDATION_MANIFEST:-}" ]; then
  echo "Manifest: $PIONEER_VALIDATION_MANIFEST"
elif [ -n "${PIONEER_VALIDATION_AUDIO_DIR:-}" ]; then
  echo "Source audio: $PIONEER_VALIDATION_AUDIO_DIR"
else
  echo "Source audio: $OUTPUT_DIR/source-audio (dummy)"
fi

cd "$REPO_ROOT"

HOME="$SCRIPT_HOME" \
CLANG_MODULE_CACHE_PATH="$CLANG_CACHE_DIR" \
RUN_PIONEER_EXTERNAL_PDB_VALIDATION=1 \
PIONEER_EXTERNAL_PDB_OUTPUT_DIR="$OUTPUT_DIR" \
swift test --filter PioneerExternalPDBValidationTests/testGeneratedExportPDBPassesRekordcrateDump

echo "PDB: $OUTPUT_DIR/PIONEER/rekordbox/export.pdb"
echo "Dump: $OUTPUT_DIR/rekordcrate-dump.txt"
echo "Report: $OUTPUT_DIR/rekordcrate-validation.json"
