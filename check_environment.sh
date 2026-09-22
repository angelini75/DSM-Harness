#!/usr/bin/env bash
# Environment verification script for DSM-Harness (macOS / Linux)
set -e

echo "========================================================"
echo "  DSM-Harness: macOS / Linux Environment Verification   "
echo "========================================================"
echo ""

# 1. Check for Rscript
if ! command -v Rscript >/dev/null 2>&1; then
    echo "[ERROR] 'Rscript' was not found in your PATH."
    echo "Please install R (>= 4.2.0) from https://cran.r-project.org/"
    exit 1
else
    RSCRIPT_PATH=$(command -v Rscript)
    echo "[OK] R detected at: $RSCRIPT_PATH"
    "$RSCRIPT_PATH" --version
fi

echo ""

# 2. Check for RStudio (macOS / Linux hints)
if [ "$(uname)" = "Darwin" ]; then
    if [ -d "/Applications/RStudio.app" ]; then
        echo "[OK] RStudio.app detected in /Applications."
    else
        echo "[WARNING] RStudio.app not found in /Applications. Ensure RStudio is installed."
    fi
else
    if command -v rstudio >/dev/null 2>&1; then
        echo "[OK] RStudio binary detected in PATH."
    else
        echo "[INFO] Running on Linux. Verify RStudio Desktop is installed."
    fi
fi

echo ""
echo "========================================================"
echo "  Running R package dependencies check...               "
echo "========================================================"
echo ""

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_SCRIPT="$DIR/02_scripts/00_check_packages.R"

if [ ! -f "$PACKAGE_SCRIPT" ]; then
    echo "[ERROR] Could not find '$PACKAGE_SCRIPT'."
    exit 1
fi

"$RSCRIPT_PATH" "$PACKAGE_SCRIPT"

echo ""
echo "[SUCCESS] Environment checks completed! You can now launch RStudio with 'DSM-Harness.Rproj'."
