# ==============================================================================
# DSM-Harness v2 | Step 4: Spatial Prediction & OpenNSIS COG Export
# ==============================================================================

# Ensure %||% is available
if (!exists("%||%", mode = "function")) {
  `%||%` <- function(a, b) {
    if (!is.null(a)) a else b
  }
}

# Resolve repository root
if (!exists("repo_root") || is.null(repo_root)) {
  if (exists("find_repo_root", mode = "function")) {
    repo_root <- find_repo_root()
  } else {
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
}

# Load i18n
if (!exists("msg", mode = "function")) {
  i18n_path <- file.path(repo_root, "02_scripts", "i18n", "load_i18n.R")
  if (file.exists(i18n_path)) source(i18n_path, local = FALSE)
}

# Resolve project context
if (!exists("project", inherits = FALSE) || is.null(project)) {
  stop(msg("step_context_missing", "en", "4", "4", repo_root = repo_root), call. = FALSE)
}

if (!exists("proj_root") || is.null(proj_root)) {
  proj_root <- file.path(repo_root, "projects", project)
}

# Load decisions helper
decisions_path <- file.path(repo_root, "R", "decisions.R")
if (file.exists(decisions_path)) source(decisions_path, local = FALSE)

# Load targets helper
targets_path <- file.path(repo_root, "R", "targets.R")
if (file.exists(targets_path)) source(targets_path, local = FALSE)

# Load config validator
val_path <- file.path(repo_root, "R", "validate_config.R")
if (file.exists(val_path)) source(val_path, local = FALSE)

# Load config.json
config_file <- file.path(proj_root, "config.json")
if (!file.exists(config_file)) {
  stop(msg("config_missing", "en", config_file, repo_root = repo_root), call. = FALSE)
}

cfg <- jsonlite::fromJSON(config_file, simplifyVector = FALSE)
lang <- cfg$language %||% "en"
project <- cfg$project %||% basename(proj_root)

# Ensure ranger namespace is loaded for predict.ranger S3 method
if (!requireNamespace("ranger", quietly = TRUE)) {
  stop(msg("pred_ranger_required", lang, repo_root = repo_root), call. = FALSE)
}
loadNamespace("ranger")

# Validate config against clean data columns
clean_file <- file.path(proj_root, "data", "03_clean.csv")
data_cols <- NULL
if (file.exists(clean_file)) {
  header_df <- read.csv(clean_file, nrows = 1, check.names = FALSE)
  data_cols <- names(header_df)
}
validate_config(cfg, data_cols = data_cols, stop_on_error = TRUE, repo_root = repo_root, target_cols_only = TRUE)

# Enforce Precision 1: Tile grid MUST come from user-confirmed config key
if (is.null(cfg$tiles) || !is.list(cfg$tiles) || is.null(cfg$tiles$cols) || is.null(cfg$tiles$rows)) {
  stop(msg("pred_missing_tiles", lang, repo_root = repo_root), call. = FALSE)
}
t_cols <- suppressWarnings(as.integer(cfg$tiles$cols))
t_rows <- suppressWarnings(as.integer(cfg$tiles$rows))
if (is.na(t_cols) || t_cols < 1 || is.na(t_rows) || t_rows < 1) {
  stop(msg("val_invalid_tiles_values", lang, repo_root = repo_root), call. = FALSE)
}

# Enforce Precision 5: country_code and project_code required, no defaults
if (is.null(cfg$country_code) || !is.character(cfg$country_code) || length(cfg$country_code) != 1 || !nzchar(trimws(cfg$country_code))) {
  stop(msg("pred_missing_country_code", lang, repo_root = repo_root), call. = FALSE)
}
country_code <- trimws(cfg$country_code)

if (is.null(cfg$project_code) || !is.character(cfg$project_code) || length(cfg$project_code) != 1 || !nzchar(trimws(cfg$project_code))) {
  stop(msg("pred_missing_project_code", lang, repo_root = repo_root), call. = FALSE)
}
project_code <- trimws(cfg$project_code)

# Check covariates directory
cov_dir <- file.path(proj_root, "covariates")
cov_files <- list.files(cov_dir, pattern = "\\.tif$", full.names = TRUE, ignore.case = TRUE)
if (length(cov_files) == 0) {
  stop(msg("pred_missing_cov_dir", lang, cov_dir, repo_root = repo_root), call. = FALSE)
}

# Load covariate stack
cov_stack <- terra::rast(cov_files)

# Configure output directories
maps_dir <- file.path(proj_root, "outputs", "maps")
if (!dir.exists(maps_dir)) dir.create(maps_dir, recursive = TRUE)

rep_dir <- file.path(proj_root, "reports")
if (!dir.exists(rep_dir)) dir.create(rep_dir, recursive = TRUE)

# Determine targets to predict
configured_targets <- cfg$targets %||% list()
if (length(configured_targets) == 0) {
  stop(msg("pred_no_targets", lang, repo_root = repo_root), call. = FALSE)
}

# Precision 2: Per-target code is required when Step 4 starts (no defaults, no example codes)
missing_code_targets <- character(0)
for (idx in seq_along(configured_targets)) {
  tgt <- configured_targets[[idx]]
  if (is.null(tgt$code) || !is.character(tgt$code) || length(tgt$code) != 1 || !nzchar(trimws(tgt$code))) {
    tgt_id <- get_target_id(tgt$property %||% paste0("target_", idx), tgt$d1 %||% 0, tgt$d2 %||% 0)
    missing_code_targets <- c(missing_code_targets, tgt_id)
  }
}
if (length(missing_code_targets) > 0) {
  stop(msg("pred_missing_target_code", lang, paste(missing_code_targets, collapse = ", "), repo_root = repo_root), call. = FALSE)
}

# Build valid target IDs using canonical get_target_id
all_target_specs <- list()
all_target_ids <- character(0)

for (idx in seq_along(configured_targets)) {
  tgt <- configured_targets[[idx]]
  prop <- tgt$property
  d1 <- tgt$d1
  d2 <- tgt$d2
  target_id <- get_target_id(prop, d1, d2)
  
  tgt$target_id <- target_id
  tgt$safe_id <- target_id
  tgt$idx <- idx
  
  all_target_specs[[idx]] <- tgt
  all_target_ids <- c(all_target_ids, target_id)
}

# Filter by runner argument 'targets' if provided
selected_targets <- list()
runner_targets <- if (exists("targets") && !is.null(targets)) targets else NULL

if (!is.null(runner_targets) && length(runner_targets) > 0) {
  for (tgt in all_target_specs) {
    if (tgt$target_id %in% runner_targets || tgt$property %in% runner_targets || (!is.null(tgt$code) && tgt$code %in% runner_targets)) {
      selected_targets[[length(selected_targets) + 1]] <- tgt
    }
  }
  if (length(selected_targets) == 0) {
    stop(msg("pred_no_matching_targets", lang, paste(runner_targets, collapse = ", "), paste(unique(all_target_ids), collapse = ", "), repo_root = repo_root), call. = FALSE)
  }
} else {
  for (tgt in all_target_specs) {
    is_enabled <- if (is.null(tgt$enabled)) TRUE else isTRUE(tgt$enabled)
    if (is_enabled) {
      selected_targets[[length(selected_targets) + 1]] <- tgt
    }
  }
  if (length(selected_targets) == 0) {
    stop(msg("pred_no_targets", lang, repo_root = repo_root), call. = FALSE)
  }
}

refit_flag <- if (exists("refit") && !is.null(refit)) isTRUE(refit) else isTRUE(cfg$refit)

# Helper function to write raster and verify COG layout (Precision 2 & 8)
write_and_verify_cog <- function(rast_obj, out_path, lang, repo_root) {
  tmp_tif <- tempfile(fileext = ".tif")
  
  # Step 1: Write base GeoTIFF with OpenNSIS options
  terra::writeRaster(
    rast_obj,
    tmp_tif,
    overwrite = TRUE,
    datatype = "FLT4S",
    NAflag = -9999,
    gdal = c(
      "COMPRESS=DEFLATE",
      "PREDICTOR=2",
      "TILED=YES",
      "BLOCKXSIZE=512",
      "BLOCKYSIZE=512"
    )
  )
  
  # Step 2: Attempt GDAL translate to COG profile
  gdal_ok <- FALSE
  tryCatch({
    sf::gdal_utils(
      "translate",
      source = tmp_tif,
      destination = out_path,
      options = c(
        "-of", "COG",
        "-co", "COMPRESS=DEFLATE",
        "-co", "PREDICTOR=2",
        "-co", "BLOCKSIZE=512",
        "-co", "OVERVIEW_RESAMPLING=AVERAGE",
        "-co", "WARP_RESAMPLING=BILINEAR"
      )
    )
    gdal_ok <- file.exists(out_path)
  }, error = function(e) {
    gdal_ok <<- FALSE
  })
  
  if (!gdal_ok || !file.exists(out_path)) {
    file.copy(tmp_tif, out_path, overwrite = TRUE)
  }
  unlink(tmp_tif)
  
  # Step 3: Verify COG layout and extract dynamic attributes (Item 5)
  attrs <- parse_cog_attributes(out_path)
  fname <- basename(out_path)
  status_tag <- if (isTRUE(attrs$is_cog)) "VERIFIED_COG" else "FALLBACK_GEOTIFF"
  
  log_line <- sprintf(
    "%s: %s (LAYOUT=%s, COMPRESSION=%s, BLOCK=%s, PREDICTOR=%s, NoData=%s)",
    fname, status_tag, attrs$layout, attrs$compression, attrs$block, attrs$predictor, attrs$nodata
  )
  
  list(
    status = status_tag,
    is_cog = isTRUE(attrs$is_cog),
    attributes = attrs,
    text = log_line
  )
}

# Prediction function for Quantile Regression Forest
pfun <- function(...) {
  predict(...)$predictions |> t()
}

# Main prediction loop across selected targets
for (tgt in selected_targets) {
  prop <- tgt$property
  d1 <- tgt$d1
  d2 <- tgt$d2
  target_id <- tgt$target_id
  safe_id <- target_id
  
  d1_num <- as.numeric(d1)
  d2_num <- as.numeric(d2)
  d1_str <- if (d1_num == floor(d1_num)) sprintf("%.0f", d1_num) else gsub("\\.", "_", as.character(d1_num))
  d2_str <- if (d2_num == floor(d2_num)) sprintf("%.0f", d2_num) else gsub("\\.", "_", as.character(d2_num))
  
  # Standard OpenNSIS filenames using user-confirmed 'code' AS TYPED (no toupper, Precision 2)
  prop_code <- as.character(tgt$code)
  mean_filename <- sprintf("%s-%s-%s-%s-%s-mean.tif", country_code, project_code, prop_code, d1_str, d2_str)
  sd_filename   <- sprintf("%s-%s-%s-%s-%s-sd.tif",   country_code, project_code, prop_code, d1_str, d2_str)
  mean_path     <- file.path(maps_dir, mean_filename)
  sd_path       <- file.path(maps_dir, sd_filename)
  
  report_file <- file.path(rep_dir, sprintf("40_prediction_%s.txt", safe_id))
  
  # Precision 3: Skip existing maps unless refit
  if (file.exists(mean_path) && file.exists(sd_path) && !refit_flag) {
    cat(sprintf(msg("pred_skipping_existing", lang, repo_root = repo_root), safe_id, safe_id), "\n")
    next
  }
  
  # Locate trained model
  model_file <- file.path(proj_root, "outputs", "models", paste0(safe_id, ".rds"))
  if (!file.exists(model_file)) {
    stop(msg("pred_missing_model", lang, safe_id, model_file, repo_root = repo_root), call. = FALSE)
  }
  
  model <- readRDS(model_file)
  ranger_model <- if (!is.null(model$finalModel)) model$finalModel else model
  
  # Precision 4: Compare forest features with raster layers; name any missing layer in error
  required_covs <- ranger_model$forest$independent.variable.names
  raster_covs   <- names(cov_stack)
  missing_covs  <- setdiff(required_covs, raster_covs)
  if (length(missing_covs) > 0) {
    stop(msg("pred_missing_covariates", lang, paste(missing_covs, collapse = ", "), repo_root = repo_root), call. = FALSE)
  }
  
  # Open diagnostic report
  rep_con <- file(report_file, open = "wt", encoding = "UTF-8")
  log_out <- function(txt) {
    cat(txt, "\n")
    cat(txt, "\n", file = rep_con)
  }
  
  log_out(msg("pred_header", lang, repo_root = repo_root))
  log_out(sprintf(msg("pred_date", lang, repo_root = repo_root), format(Sys.time(), "%Y-%m-%d %H:%M:%S")))
  log_out(sprintf(msg("pred_project", lang, repo_root = repo_root), project))
  log_out(sprintf(msg("pred_target_header", lang, repo_root = repo_root), prop, d1, d2))
  
  t_start <- proc.time()
  
  total_tiles <- t_cols * t_rows
  log_out(sprintf(msg("pred_tiling_info", lang, repo_root = repo_root), total_tiles, t_cols, t_rows))
  
  # Create tiles
  tile_grid <- terra::rast(nrows = t_rows, ncols = t_cols, extent = terra::ext(cov_stack), crs = terra::crs(cov_stack))
  tile_dir <- tempfile(pattern = "dsm_tiles_")
  dir.create(tile_dir, recursive = TRUE)
  
  tile_files <- terra::makeTiles(cov_stack[[1]], tile_grid, filename = file.path(tile_dir, "tile_.tif"), overwrite = TRUE)
  
  # Precision 3: Per-tile progress
  for (j in seq_along(tile_files)) {
    log_out(sprintf(msg("pred_tile_progress", lang, repo_root = repo_root), j, length(tile_files)))
    
    t_j <- terra::rast(tile_files[j])
    cov_tile <- terra::crop(cov_stack, t_j)
    
    mean_tile_f <- file.path(tile_dir, sprintf("mean_%d.tif", j))
    sd_tile_f   <- file.path(tile_dir, sprintf("sd_%d.tif", j))
    
    terra::interpolate(
      cov_tile,
      model = ranger_model,
      fun = pfun,
      na.rm = TRUE,
      type = "quantiles",
      what = mean,
      filename = mean_tile_f,
      overwrite = TRUE,
      wopt = list(datatype = "FLT4S")
    )
    
    terra::interpolate(
      cov_tile,
      model = ranger_model,
      fun = pfun,
      na.rm = TRUE,
      type = "quantiles",
      what = sd,
      filename = sd_tile_f,
      overwrite = TRUE,
      wopt = list(datatype = "FLT4S")
    )
  }
  
  # Mosaic tiles
  log_out(sprintf(msg("pred_mosaicing", lang, repo_root = repo_root), length(tile_files)))
  
  mean_rasters <- lapply(seq_along(tile_files), function(j) terra::rast(file.path(tile_dir, sprintf("mean_%d.tif", j))))
  mean_mosaic <- terra::mosaic(terra::sprc(mean_rasters), fun = "first")
  names(mean_mosaic) <- paste0(prop, "_mean")
  terra::NAflag(mean_mosaic) <- -9999
  
  sd_rasters <- lapply(seq_along(tile_files), function(j) terra::rast(file.path(tile_dir, sprintf("sd_%d.tif", j))))
  sd_mosaic <- terra::mosaic(terra::sprc(sd_rasters), fun = "first")
  names(sd_mosaic) <- paste0(prop, "_sd")
  terra::NAflag(sd_mosaic) <- -9999
  
  # Precision 2: COG creation and verification
  log_out(msg("pred_writing_cog", lang, repo_root = repo_root))
  
  mean_cog <- write_and_verify_cog(mean_mosaic, mean_path, lang, repo_root)
  log_out(mean_cog$text)
  
  sd_cog <- write_and_verify_cog(sd_mosaic, sd_path, lang, repo_root)
  log_out(sd_cog$text)
  
  # Precision 2: Print final filenames to console
  cat(sprintf(msg("pred_files_generated", lang, repo_root = repo_root), mean_filename, sd_filename), "\n")
  
  # Clean up tile temporary directory
  unlink(tile_dir, recursive = TRUE)
  
  # Precision 3: Elapsed time per target
  elapsed_sec <- as.numeric((proc.time() - t_start)["elapsed"])
  log_out(sprintf(msg("pred_target_completed", lang, repo_root = repo_root), safe_id, elapsed_sec))
  
  log_out("================================================================================")
  log_out(sprintf(msg("pred_files_saved", lang, repo_root = repo_root), mean_path, sd_path, report_file))
  close(rep_con)
  
  # Audit log
  record_decision(
    project = project,
    step = "4",
    decision = sprintf("Spatial prediction for target %s (mean & sd, tiles: %dx%d, status: %s)", safe_id, t_cols, t_rows, mean_cog$status),
    details = sprintf("Mean: %s; SD: %s; Status: %s", mean_filename, sd_filename, mean_cog$status),
    repo_root = repo_root
  )
}

cat(msg("pred_all_completed", lang, repo_root = repo_root), "\n")
