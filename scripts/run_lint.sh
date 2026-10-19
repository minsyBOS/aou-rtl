#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2026 Tenstorrent USA Inc
#
# Verilator semantic lint check for AOU_TOP
# Complements scripts/run_verible_lint.sh (style/structural checks).
#
# Verilator catches elaboration-aware issues that Verible cannot:
#   - Signal width mismatches (WIDTHEXPAND / WIDTHTRUNC)
#   - Blocking assignments in sequential blocks (BLKSEQ)
#   - Latch inference (LATCH)
#   - Implicit net declarations (IMPLICIT)
#   - Incomplete case statements (CASEINCOMPLETE)
#
# Scope: AOU_TOP (the turnkey FDI bringup wrapper around AOU_CORE_TOP).
# The single-PHY parameter configuration is exercised; TWO_PHY ports are
# gated by `ifdef TWO_PHY` and excluded from this build.
#
# Usage:  bash scripts/run_lint.sh
#         (run from the repository root)
#
# Override the Verilator binary location via VERILATOR:
#   VERILATOR=/path/to/verilator bash scripts/run_lint.sh

set -euo pipefail
export AOU_CORE_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

VERILATOR="${VERILATOR:-verilator}"
LOG_DIR="${AOU_CORE_HOME}/logs"
mkdir -p "${LOG_DIR}"
LOG_FILE="${LOG_DIR}/verilator_lint.log"

echo "Verilator lint: AOU_TOP"
echo "Log file: ${LOG_FILE}"

# Under pipefail the pipeline's status is Verilator's; `|| RC=$?` keeps
# `set -e` from ending the script before the summary below.
RC=0
$VERILATOR \
    --lint-only \
    --timing \
    -Wall \
    -Wno-DECLFILENAME \
    -Wno-UNUSEDSIGNAL \
    -Wno-UNUSEDPARAM \
    -Wno-PINCONNECTEMPTY \
    --top-module AOU_TOP \
    -f "${AOU_CORE_HOME}/RTL/filelist.f" 2>&1 | tee "${LOG_FILE}" || RC=$?

WARNINGS=$(grep -ci 'warning' "${LOG_FILE}" 2>/dev/null || true)
ERRORS=$(grep -ci 'error' "${LOG_FILE}" 2>/dev/null || true)
# Connectivity defects are bugs, not style: list them again after the
# (many) width warnings so they are not lost in the log, and fail on them
# even where the width warnings are tolerated.
CONNECTIVITY=$(grep -E '^%Warning-(UNDRIVEN|IMPLICIT|MULTIDRIVEN|PINMISSING|PINNOCONNECT):' \
    "${LOG_FILE}" 2>/dev/null || true)
echo ""
echo "Verilator lint complete: ${ERRORS} error(s), ${WARNINGS} warning(s)"
if [[ -n "${CONNECTIVITY}" ]]; then
    echo "Connectivity warnings (undriven, implicit or multiply driven nets, missing pins):"
    echo "${CONNECTIVITY}"
    RC=1
fi
echo "Full log: ${LOG_FILE}"
exit $RC
