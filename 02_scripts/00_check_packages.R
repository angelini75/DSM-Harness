# 00_check_packages.R
# Script for verifying and installing required R packages for DSM & Soil Spectroscopy training

required_packages <- c(
  # Spatial
  "terra",
  "sf",
  "mapview",
  # Machine Learning & DSM
  "ranger",
  "caret",
  "Boruta",
  # Spectroscopy
  "prospectr",
  "matrixStats",
  # Data Manipulation & Visualization
  "tidyverse",
  "readxl",
  "writexl",
  "ggpubr",
  # Pedology
  "aqp"
)

cat("========================================================\n")
cat("Checking R environment and required packages...\n")
cat("R version:", R.version.string, "\n")
cat("Platform:", R.version$platform, "\n")
cat("========================================================\n\n")

installed <- rownames(installed.packages())
missing_pkgs <- setdiff(required_packages, installed)

# Ensure user library directory exists and is writable
user_lib <- Sys.getenv("R_LIBS_USER")
if (!dir.exists(user_lib)) {
  dir.create(user_lib, recursive = TRUE, showWarnings = FALSE)
}
.libPaths(c(user_lib, .libPaths()))

if (length(missing_pkgs) == 0) {
  cat("[OK] All required packages are already installed!\n\n")
} else {
  cat("[WARNING] The following packages are missing:\n")
  cat(paste(" -", missing_pkgs, collapse = "\n"), "\n\n")
  cat("Target library directory:", user_lib, "\n")
  cat("Attempting to install missing packages from CRAN...\n")
  install.packages(missing_pkgs, lib = user_lib, repos = "https://cloud.r-project.org")

  
  # Re-check
  installed_after <- rownames(installed.packages())
  still_missing <- setdiff(required_packages, installed_after)
  if (length(still_missing) > 0) {
    cat("\n[ERROR] Could not automatically install:\n")
    cat(paste(" -", still_missing, collapse = "\n"), "\n")
    quit(status = 1)
  } else {
    cat("\n[SUCCESS] All missing packages successfully installed!\n")
  }
}

# Quick sanity check for spatial libraries (GDAL/PROJ linked to terra)
cat("\nTesting spatial driver initialization (terra & sf)...\n")
tryCatch({
  suppressPackageStartupMessages(library(terra))
  suppressPackageStartupMessages(library(sf))
  cat("[OK] terra version:", as.character(packageVersion("terra")), "\n")
  cat("[OK] sf version:", as.character(packageVersion("sf")), "\n")
  cat("[OK] GDAL linked to terra:", terra::gdal(), "\n")
  cat("[OK] PROJ linked to terra:", terra::proj(), "\n")
}, error = function(e) {
  cat("[ERROR] Spatial driver initialization failed:", conditionMessage(e), "\n")
  quit(status = 1)
})

cat("\n========================================================\n")
cat("[COMPLETE] Your R environment is fully ready for DSM-Harness!\n")
cat("========================================================\n")
