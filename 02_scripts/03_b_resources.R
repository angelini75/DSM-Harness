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
if (!exists("validate_config", mode = "function")) {
  source(file.path(repo_root, "R", "validate_config.R"), local = FALSE)
}
if (!exists("get_target_id", mode = "function")) {
  source(file.path(repo_root, "R", "targets.R"), local = FALSE)
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

# Validate configuration
validate_config(cfg, stop_on_error = TRUE, repo_root = repo_root)

# 1. User-Stated Hardware Configuration (Comment 6233883917)
# The user states cores and ram_gb in config.json (no OS RAM detection, no silent 8 GB fallback).
cores_cfg <- cfg$cores
ram_gb_cfg <- cfg$ram_gb

hw_configured <- !is.null(cores_cfg) && is.numeric(cores_cfg) && cores_cfg >= 1 &&
                 !is.null(ram_gb_cfg) && is.numeric(ram_gb_cfg) && ram_gb_cfg > 0

cores_val <- if (hw_configured) as.integer(cores_cfg) else NA_integer_
ram_gb_val <- if (hw_configured) as.numeric(ram_gb_cfg) else NA_real_
ram_share <- if (!is.null(cfg$ram_share) && is.numeric(cfg$ram_share) && cfg$ram_share > 0 && cfg$ram_share <= 1) {
  as.numeric(cfg$ram_share)
} else {
  0.25
}

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

# Uncompressed raster stack footprint (8 bytes per double precision cell per layer)
uncompressed_mb <- round((r_cells * r_layers * 8) / (1024^2), 2)

# 3. Model Inspection & Training Rows for Prediction Memory
model_files <- list.files(models_dir, pattern = "\\.rds$", full.names = FALSE)
model_names <- if (length(model_files) > 0) paste(gsub("\\.rds$", "", model_files), collapse = ", ") else "none"

metrics_files <- list.files(models_dir, pattern = "^metrics_.*\\.json$", full.names = TRUE)
training_rows_vec <- integer(0)
for (mf in metrics_files) {
  met <- tryCatch(jsonlite::fromJSON(mf, simplifyVector = FALSE), error = function(e) NULL)
  if (!is.null(met) && !is.null(met$training_rows) && is.numeric(met$training_rows) && met$training_rows > 0) {
    training_rows_vec <- c(training_rows_vec, as.integer(met$training_rows))
  }
}

has_training_rows <- length(training_rows_vec) > 0
if (has_training_rows) {
  max_training_rows <- max(training_rows_vec)
  bytes_per_pixel <- 8 * (r_layers + max_training_rows)
} else {
  max_training_rows <- NA_integer_
  bytes_per_pixel <- 8 * r_layers
}

# 4. Vertical Strip Tiling Calculation (Comment 6233883917)
# Formula: max_pixels_per_tile = floor(ram_share * ram_gb * 1024^3 / bytes_per_pixel)
#          cols = ceil(total_pixels / max_pixels_per_tile), rows = 1
if (hw_configured) {
  max_pixels_per_tile <- max(1, floor((ram_share * ram_gb_val * (1024^3)) / bytes_per_pixel))
  tile_cols <- max(1, ceiling(r_cells / max_pixels_per_tile))
  tile_rows <- 1
  total_tiles <- tile_cols * tile_rows
  cells_per_tile <- ceiling(r_cells / total_tiles)
  tile_mb <- round((cells_per_tile * bytes_per_pixel) / (1024^2), 2)
} else {
  max_pixels_per_tile <- NA_real_
  tile_cols <- NA_integer_
  tile_rows <- NA_integer_
  total_tiles <- NA_integer_
  tile_mb <- NA_real_
}

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
log_out(msg("res_sec_hardware", lang, repo_root = repo_root))
if (hw_configured) {
  log_out(msg("res_hw_cores", lang, cores_val, repo_root = repo_root))
  log_out(msg("res_hw_ram", lang, ram_gb_val, ram_share, repo_root = repo_root))
} else {
  log_out(msg("res_hw_missing_config", lang, repo_root = repo_root))
}
log_out("--------------------------------------------------------------------------------")
log_out(msg("res_sec_raster", lang, repo_root = repo_root))
log_out(msg("res_raster_dims", lang, r_cols, r_rows, r_cells, repo_root = repo_root))
log_out(msg("res_raster_layers", lang, r_layers, repo_root = repo_root))
log_out(msg("res_raster_extent", lang, r_ext[1], r_ext[2], r_ext[3], r_ext[4], repo_root = repo_root))
log_out(msg("res_raster_res", lang, r_res[1], r_res[2], repo_root = repo_root))
log_out(msg("res_raster_memory", lang, uncompressed_mb, repo_root = repo_root))
log_out("--------------------------------------------------------------------------------")
log_out(msg("res_sec_models", lang, repo_root = repo_root))
if (length(model_files) > 0) {
  log_out(msg("res_models_found", lang, length(model_files), model_names, repo_root = repo_root))
} else {
  log_out(msg("res_no_models", lang, repo_root = repo_root))
}
if (has_training_rows) {
  log_out(msg("res_pred_memory_training_rows", lang, max_training_rows, length(metrics_files), repo_root = repo_root))
} else {
  log_out(msg("res_pred_memory_not_evaluated", lang, repo_root = repo_root))
}
log_out(msg("res_formula_explanation", lang, repo_root = repo_root))
log_out("--------------------------------------------------------------------------------")
log_out(msg("res_sec_tiling", lang, repo_root = repo_root))
if (hw_configured) {
  max_pix_str <- format(max_pixels_per_tile, scientific = FALSE, big.mark = ",")
  log_out(msg("res_tiling_proposal", lang, total_tiles, tile_cols, max_pix_str, tile_mb, repo_root = repo_root))
} else {
  log_out(msg("res_tiling_not_evaluated", lang, repo_root = repo_root))
}
log_out("================================================================================")
log_out(msg("res_report_written", lang, report_file, repo_root = repo_root))
close(rep_con)

decision_details <- if (hw_configured) {
  sprintf("Cores: %d, RAM: %.2f GB (share: %.2f), Raster: %dx%d (%d cells, %d layers). Proposed vertical tiling: %d cols (1 row, %.2f MB/tile). Written %s",
          cores_val, ram_gb_val, ram_share, r_cols, r_rows, r_cells, r_layers, tile_cols, tile_mb, report_file)
} else {
  sprintf("Hardware unconfigured in config.json ('cores' and/or 'ram_gb' missing). Proposed tiling: NO EVALUADO. Written %s", report_file)
}

record_decision(
  project = project,
  step = "3b",
  decision = "Hardware and raster resource diagnosis and vertical strip tiling advisory",
  details = decision_details,
  repo_root = repo_root
)

cat(msg("res_completed", lang, repo_root = repo_root), "\n")
