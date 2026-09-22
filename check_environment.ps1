<#
.SYNOPSIS
    Environment verification script for DSM-Harness (Windows / PowerShell).
.DESCRIPTION
    Checks for R, RStudio, and executes headless R package checks.
#>

$ErrorActionPreference = "Continue"

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  DSM-Harness: Windows Environment Verification Tool   " -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Check for Rscript / R installation
$rscriptCmd = Get-Command "Rscript" -ErrorAction SilentlyContinue

if (-not $rscriptCmd) {
    Write-Host "[*] Rscript not found in system PATH. Searching standard directories..." -ForegroundColor Yellow
    $candidatePaths = Get-ChildItem "C:\Program Files\R" -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending
    foreach ($dir in $candidatePaths) {
        $candidateExe = Join-Path $dir.FullName "bin\Rscript.exe"
        if (Test-Path $candidateExe) {
            $rscriptPath = $candidateExe
            break
        }
    }
} else {
    $rscriptPath = $rscriptCmd.Source
}

if (-not $rscriptPath) {
    Write-Host "[ERROR] R is not installed or not found in 'C:\Program Files\R'." -ForegroundColor Red
    Write-Host "Please install R (>= 4.2.0) from: https://cran.r-project.org/bin/windows/base/" -ForegroundColor Yellow
    exit 1
} else {
    Write-Host "[OK] R detected at: $rscriptPath" -ForegroundColor Green
    & "$rscriptPath" --version
}

Write-Host ""

# 2. Check for RStudio
$rstudioCandidate = "C:\Program Files\RStudio\rstudio.exe"
$rstudioCmd = Get-Command "rstudio" -ErrorAction SilentlyContinue

if ($rstudioCmd -or (Test-Path $rstudioCandidate)) {
    Write-Host "[OK] RStudio detected." -ForegroundColor Green
} else {
    Write-Host "[WARNING] RStudio executable not found in default location." -ForegroundColor Yellow
    Write-Host "Make sure RStudio Desktop is installed: https://posit.co/download/rstudio-desktop/" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  Running R package dependencies check...               " -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""

$scriptPath = Join-Path $PSScriptRoot "02_scripts\00_check_packages.R"

if (-not (Test-Path $scriptPath)) {
    Write-Host "[ERROR] Could not find '$scriptPath'." -ForegroundColor Red
    exit 1
}

& "$rscriptPath" "$scriptPath"

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "[SUCCESS] All environment checks passed! You are ready to open 'DSM-Harness.Rproj' in RStudio." -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "[FAILED] Package verification encountered issues. Please review error messages above." -ForegroundColor Red
    exit $LASTEXITCODE
}
