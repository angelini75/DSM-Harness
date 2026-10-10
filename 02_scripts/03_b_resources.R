# ==============================================================================
# DSM-Harness v2 | 02_scripts/03_b_resources.R
# Step 3b: Hardware & Raster Resource Diagnosis and Tiling Advisory
# ==============================================================================

# Ensure repo_root and proj_root are set
if (!exists("repo_root", inherits = FALSE)) {
  find_root <- function(d = getwd()) {
    curr <- normalizePath(d, winslash = "/", mustWork = FALSE)
    while (nchar(curr) > 0 && dirname(curr) != curr) {
      if (file.exists(file.path(curr, "DSM-Harness.Rproj"))) return(curr)
      curr <- dirname(curr)
    }
    normalizePath(d, winslash = "/", mustWork = FALSE)
  }
  repo_root <- find_root()
}

if (!exists("msg", mode = "function")) {
  source(file.path(repo_root, "02_scripts", "i18n", "load_i18n.R"), local = FALSE)
}
if (!exists("record_decision", mode = "function")) {
  source(file.path(repo_root, "R", "decisions.R"), local = FALSE)
}

if (!exists("project", inherits = FALSE) || is.null(project)) {
  stop(msg("step_context_missing", "en", "3b", "3b", repo_root = repo_root), call. = FALSE)
}

proj_root <- file.path(repo_root, "projects", project)
reports_dir <- file.path(proj_root, "reports")
models_dir <- file.path(proj_root, "outputs", "models")
cov_dir <- file.path(proj_root, "covariates")

if (!dir.exists(reports_dir)) dir.create(reports_dir, recursive = TRUE)

config_path <- file.path(proj_root, "config.json")
if (!file.exists(config_path)) {
  stop(msg("config_missing", "en", config_path, repo_root = repo_root), call. = FALSE)
}

if (!exists("cfg", inherits = FALSE) || is.null(cfg)) {
  cfg <- jsonlite::fromJSON(config_path, simplifyVector = FALSE)
}
lang <- cfg$language %||% "en"

# 1. Hardware Inspection
cores_total <- parallel::detectCores()
worker_threads <- max(1, cores_total - 1)

detect_ram_gb <- function() {
  ram_gb <- NA_real_
  if (.Platform$OS.type == "windows") {
    out <- tryCatch(
      system2("powershell", c("-NoProfile", "-Command", "[Math]::Round((Get-CimInstance Win32_OperatingSystem).TotalVisibleMemorySize / 1MB, 2)"), stdout = TRUE),
      error = function(e) NULL
    )
    if (!is.null(out) && length(out) > 0) {
      val <- suppressWarnings(as.numeric(trimws(out[1])))
      if (!is.na(val) && val > 0) ram_gb <- val
    }
  } else {
    mem_info <- tryCatch(readLines("/proc/meminfo"), error = function(e) NULL)
    if (!is.null(mem_info)) {
      line <- grep("^MemTotal:", mem_info, value = TRUE)
      if (length(line) > 0) {
        kb <- as.numeric(gsub("[^0-9]", "", line))
        ram_gb <- round(kb / (1024^2), 2)
      }
    }
  }
  if (is.na(ram_gb)) ram_gb <- 8.0
  ram_gb
}
ram_total_gb <- detect_ram_gb()

# 2. Covariate Raster Inspection
cov_files <- list.files(cov_dir, pattern = "\\.tif$", full.names = TRUE, ignore.case = TRUE)
if (length(cov_files) == 0) {
  stop(msg("cov_no_rasters", lang, cov_dir, repo_root = repo_root), call. = FALSE)
}

cov_stack <- terra::rast(cov_files)
r_cols <- terra::ncol(cov_stack)
r_rows <- terra::nrow(cov_stack)
r_cells <- terra::ncell(cov_stack)
r_layers <- terra::nlyr(cov_stack)
r_ext <- as.vector(terra::ext(cov_stack))
r_res <- terra::res(cov_stack)

# Memory footprint calculation (8 bytes per double precision cell per layer)
uncompressed_mb <- round((r_cells * r_layers * 8) / (1024^2), 2)

# 3. Model Inspection
model_files <- list.files(models_dir, pattern = "\\.rds$", full.names = FALSE)
model_names <- if (length(model_files) > 0) paste(gsub("\\.rds$", "", model_files), collapse = ", ") else "none"

# 4. Tiling Calculation
# Target footprint per tile between 20 MB and 100 MB
target_tile_mb <- 50.0
calc_tiles <- max(1, ceiling(uncompressed_mb / target_tile_mb))

# Choose clean cols x rows split
if (calc_tiles <= 1) {
  tile_cols <- 1
  tile_rows <- 1
} else if (calc_tiles <= 4) {
  tile_cols <- 2
  tile_rows <- 2
} else if (calc_tiles <= 12) {
  tile_cols <- 4
  tile_rows <- 3
} else if (calc_tiles <= 25) {
  tile_cols <- 5
  tile_rows <- 5
} else {
  tile_cols <- 10
  tile_rows <- ceiling(calc_tiles / 10)
}
total_tiles <- tile_cols * tile_rows
tile_mb <- round(uncompressed_mb / total_tiles, 2)

report_file <- file.path(reports_dir, "3b_resources.txt")
rep_con <- file(report_file, open = "wt", encoding = "UTF-8")
log_out <- function(...) {
  line <- paste0(...)
  cat(line, "\n")
  cat(line, "\n", file = rep_con)
}

log_out("================================================================================")
log_out(msg("res_header", lang, repo_root = repo_root))
log_out("================================================================================")
log_out(msg("res_date", lang, format(Sys.time(), "%Y-%m-%d %H:%M:%S"), repo_root = repo_root))
log_out(msg("res_project", lang, project, repo_root = repo_root))
log_out("--------------------------------------------------------------------------------")
log_out("HARDWARE ENVIRONMENT:")
log_out(msg("res_hw_cores", lang, cores_total, worker_threads, repo_root = repo_root))
log_out(msg("res_hw_ram", lang, ram_total_gb, repo_root = repo_root))
log_out("--------------------------------------------------------------------------------")
log_out("COVARIATE RASTER VOLUME:")
log_out(msg("res_raster_dims", lang, r_cols, r_rows, r_cells, repo_root = repo_root))
log_out(msg("res_raster_layers", lang, r_layers, repo_root = repo_root))
log_out(msg("res_raster_extent", lang, r_ext[1], r_ext[2], r_ext[3], r_ext[4], repo_root = repo_root))
log_out(msg("res_raster_res", lang, r_res[1], r_res[2], repo_root = repo_root))
log_out(msg("res_raster_memory", lang, uncompressed_mb, repo_root = repo_root))
log_out("--------------------------------------------------------------------------------")
log_out("MODEL ARTIFACTS:")
if (length(model_files) > 0) {
  log_out(msg("res_models_found", lang, length(model_files), model_names, repo_root = repo_root))
} else {
  log_out(msg("res_no_models", lang, repo_root = repo_root))
}
log_out("--------------------------------------------------------------------------------")
log_out("STEP 4 TILING ADVISORY:")
log_out(msg("res_tiling_proposal", lang, total_tiles, tile_cols, tile_rows, tile_mb, repo_root = repo_root))
log_out("================================================================================")
log_out(msg("res_report_written", lang, report_file, repo_root = repo_root))
close(rep_con)

record_decision(
  project = project,
  step = "3b",
  decision = "Hardware and raster resource diagnosis and tiling advisory",
  details = sprintf("Cores: %d, RAM: %.2f GB, Raster: %dx%d (%d cells, %d layers, %.2f MB). Proposed tiling: %d tiles (%dx%d, %.2f MB/tile). Written %s",
                    cores_total, ram_total_gb, r_cols, r_rows, r_cells, r_layers, uncompressed_mb, total_tiles, tile_cols, tile_rows, tile_mb, report_file),
  repo_root = repo_root
)

cat(msg("res_completed", lang, repo_root = repo_root), "\n")
