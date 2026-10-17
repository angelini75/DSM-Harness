# ==============================================================================
# DSM-Harness v2 | 02_scripts/02_covariates.R
# Step 2: Depth Standardisation & Covariate Extraction
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
  stop(msg("step_context_missing", "en", "2", "2", repo_root = repo_root), call. = FALSE)
}

proj_root <- file.path(repo_root, "projects", project)
data_dir <- file.path(proj_root, "data")
reports_dir <- file.path(proj_root, "reports")
cov_dir <- file.path(proj_root, "covariates")
if (!dir.exists(data_dir)) dir.create(data_dir, recursive = TRUE)
if (!dir.exists(reports_dir)) dir.create(reports_dir, recursive = TRUE)
if (!dir.exists(cov_dir)) dir.create(cov_dir, recursive = TRUE)

config_path <- file.path(proj_root, "config.json")
if (!file.exists(config_path)) {
  stop(msg("config_missing", "en", config_path, repo_root = repo_root), call. = FALSE)
}

if (!exists("cfg", inherits = FALSE) || is.null(cfg)) {
  cfg <- jsonlite::fromJSON(config_path, simplifyVector = FALSE)
}
lang <- cfg$language %||% "en"

is_str <- function(x) {
  if (is.null(x) || length(x) == 0) return(FALSE)
  ch <- as.character(x)[1]
  !is.na(ch) && nzchar(ch)
}

# 1. Verify Step 1.3 output exists
in_csv <- file.path(data_dir, "03_clean.csv")
if (!file.exists(in_csv)) {
  err_msg <- msg("step_missing_input", lang, "2", "data/03_clean.csv", "1.3", repo_root = repo_root)
  stop(err_msg, call. = FALSE)
}

df <- as.data.frame(readr::read_csv(in_csv, show_col_types = FALSE))

# Validate configuration against 03_clean.csv columns
validate_config(cfg, data_cols = names(df), stop_on_error = TRUE, repo_root = repo_root, target_cols_only = TRUE)

resolve_col <- function(col_name) {
  if (is.null(col_name) || !nzchar(col_name)) return(NULL)
  if (col_name %in% names(df)) return(col_name)
  matches <- grep(paste0("\\.", col_name, "$"), names(df), value = TRUE)
  if (length(matches) == 1) return(matches[1])
  bare <- sub("^[^.]+\\.", "", col_name)
  if (bare %in% names(df)) return(bare)
  NULL
}

pid_col <- resolve_col(if (is_str(cfg$roles$profile_id)) as.character(cfg$roles$profile_id) else NULL)
x_col   <- resolve_col(if (is_str(cfg$roles$x)) as.character(cfg$roles$x) else NULL)
y_col   <- resolve_col(if (is_str(cfg$roles$y)) as.character(cfg$roles$y) else NULL)
top_col <- resolve_col(if (is_str(cfg$roles$top)) as.character(cfg$roles$top) else NULL)
bot_col <- resolve_col(if (is_str(cfg$roles$bottom)) as.character(cfg$roles$bottom) else NULL)

if (is.null(pid_col) || is.null(x_col) || is.null(y_col) || is.null(top_col) || is.null(bot_col)) {
  missing_roles <- character(0)
  if (is.null(pid_col)) missing_roles <- c(missing_roles, "profile_id")
  if (is.null(x_col)) missing_roles <- c(missing_roles, "x")
  if (is.null(y_col)) missing_roles <- c(missing_roles, "y")
  if (is.null(top_col)) missing_roles <- c(missing_roles, "top")
  if (is.null(bot_col)) missing_roles <- c(missing_roles, "bottom")
  stop(msg("map_missing_roles", lang, paste(missing_roles, collapse = ", "), repo_root = repo_root), call. = FALSE)
}

# 2. Check targets configuration
targets <- cfg$targets
if (is.null(targets) || length(targets) == 0) {
  stop(msg("cov_no_targets", lang, repo_root = repo_root), call. = FALSE)
}

# 3. Check and load covariate GeoTIFF rasters
cov_files <- list.files(cov_dir, pattern = "\\.tif$", full.names = TRUE, ignore.case = TRUE)
if (length(cov_files) == 0) {
  stop(msg("cov_no_rasters", lang, cov_dir, repo_root = repo_root), call. = FALSE)
}

# Check resolution, CRS and extent across multiple rasters before stacking
if (length(cov_files) > 1) {
  mismatches <- character(0)
  r1 <- terra::rast(cov_files[1])
  crs1 <- terra::crs(r1, proj = TRUE)
  res1 <- round(terra::res(r1), 8)
  ext1 <- round(as.vector(terra::ext(r1)), 6)
  
  for (i in 2:length(cov_files)) {
    ri <- terra::rast(cov_files[i])
    crsi <- terra::crs(ri, proj = TRUE)
    resi <- round(terra::res(ri), 8)
    exti <- round(as.vector(terra::ext(ri)), 6)
    
    file_diffs <- character(0)
    if (!identical(crs1, crsi)) {
      file_diffs <- c(file_diffs, msg("cov_diff_crs", lang, crs1, crsi, repo_root = repo_root))
    }
    if (!all(abs(res1 - resi) < 1e-6)) {
      file_diffs <- c(file_diffs, msg("cov_diff_res", lang, paste(res1, collapse = ", "), paste(resi, collapse = ", "), repo_root = repo_root))
    }
    if (!all(abs(ext1 - exti) < 1e-4)) {
      file_diffs <- c(file_diffs, msg("cov_diff_ext", lang, paste(ext1, collapse = ", "), paste(exti, collapse = ", "), repo_root = repo_root))
    }
    if (length(file_diffs) > 0) {
      mismatches <- c(mismatches, sprintf("  * %s vs %s: %s", basename(cov_files[1]), basename(cov_files[i]), paste(file_diffs, collapse = "; ")))
    }
  }
  
  if (length(mismatches) > 0) {
    err_text <- paste(mismatches, collapse = "\n")
    stop(msg("cov_raster_mismatch", lang, err_text, repo_root = repo_root), call. = FALSE)
  }
}

cov_stack <- terra::rast(cov_files)
names(cov_stack) <- make.unique(names(cov_stack))
cov_crs <- terra::crs(cov_stack)
n_layers <- terra::nlyr(cov_stack)

min_support_cfg <- as.numeric(cfg$min_support %||% 5)
active_count <- 0

# 4. Process each configured target
for (idx in seq_along(targets)) {
  tgt <- targets[[idx]]
  is_enabled <- isTRUE(tgt$enabled %||% TRUE)
  prop <- as.character(tgt$property)
  d1 <- as.numeric(tgt$d1)
  d2 <- as.numeric(tgt$d2)
  
  if (!is_enabled) {
    cat(msg("cov_target_disabled", lang, prop, d1, d2, repo_root = repo_root), "\n")
    next
  }
  
  prop_col <- resolve_col(prop)
  if (is.null(prop_col)) {
    stop(msg("cov_prop_not_found", lang, prop, paste(names(df), collapse = ", "), repo_root = repo_root), call. = FALSE)
  }
  
  active_count <- active_count + 1
  target_id <- get_target_id(prop, d1, d2)
  safe_prop <- gsub("[^A-Za-z0-9_-]", "_", prop)
  
  report_file <- file.path(reports_dir, sprintf("20_covariates_%s.txt", target_id))
  rep_con <- file(report_file, open = "wt", encoding = "UTF-8")
  
  log_out <- function(...) {
    line <- paste0(...)
    cat(line, "\n")
    cat(line, "\n", file = rep_con)
  }
  
  log_out("================================================================================")
  log_out(msg("cov_header", lang, repo_root = repo_root))
  log_out("================================================================================")
  log_out(msg("cov_date", lang, format(Sys.time(), "%Y-%m-%d %H:%M:%S"), repo_root = repo_root))
  log_out(msg("cov_project", lang, project, repo_root = repo_root))
  log_out(msg("cov_input_file", lang, "data/03_clean.csv", repo_root = repo_root))
  log_out(msg("cov_loaded_rasters", lang, length(cov_files), n_layers, paste(names(cov_stack), collapse = ", "), repo_root = repo_root))
  log_out(msg("cov_raster_crs", lang, terra::crs(cov_stack, proj = TRUE), repo_root = repo_root))
  log_out(msg("cov_target_header", lang, prop, d1, d2, repo_root = repo_root))
  if (safe_prop != prop) {
    log_out(msg("cov_safe_mapping", lang, prop, safe_prop, repo_root = repo_root))
  }
  
  # Depth standardisation: thickness-weighted mean per profile
  prof_ids <- unique(df[[pid_col]])
  n_init_profiles <- length(prof_ids)
  log_out(msg("cov_profiles_count", lang, n_init_profiles, repo_root = repo_root))
  
  df_sub <- df
  df_sub$.top <- suppressWarnings(as.numeric(df_sub[[top_col]]))
  df_sub$.bottom <- suppressWarnings(as.numeric(df_sub[[bot_col]]))
  df_sub$.val <- suppressWarnings(as.numeric(df_sub[[prop_col]]))
  df_sub$.pid <- as.character(df_sub[[pid_col]])
  df_sub$.x <- suppressWarnings(as.numeric(df_sub[[x_col]]))
  df_sub$.y <- suppressWarnings(as.numeric(df_sub[[y_col]]))
  
  valid_horiz <- !is.na(df_sub$.top) & !is.na(df_sub$.bottom) & !is.na(df_sub$.val) & !is.na(df_sub$.x) & !is.na(df_sub$.y)
  df_sub <- df_sub[valid_horiz, , drop = FALSE]
  
  df_sub$.h_thick <- pmax(0, pmin(df_sub$.bottom, d2) - pmax(df_sub$.top, d1))
  df_sub <- df_sub[df_sub$.h_thick > 0, , drop = FALSE]
  
  if (nrow(df_sub) == 0) {
    prof_valid <- data.frame(.pid = character(0), .x = numeric(0), .y = numeric(0), .support = numeric(0), .std_val = numeric(0))
  } else {
    prof_list <- split(df_sub, df_sub$.pid)
    agg_rows <- lapply(prof_list, function(p_df) {
      tot_thick <- sum(p_df$.h_thick)
      std_val <- sum(p_df$.val * p_df$.h_thick) / tot_thick
      data.frame(
        .pid = p_df$.pid[1],
        .x = p_df$.x[1],
        .y = p_df$.y[1],
        .support = tot_thick,
        .std_val = std_val,
        stringsAsFactors = FALSE
      )
    })
    prof_agg <- do.call(rbind, agg_rows)
    prof_valid <- prof_agg[prof_agg$.support >= min_support_cfg, , drop = FALSE]
  }
  
  n_valid_support <- nrow(prof_valid)
  n_low_support <- n_init_profiles - n_valid_support
  log_out(msg("cov_support_stats", lang, min_support_cfg, n_valid_support, n_low_support, repo_root = repo_root))
  
  if (n_valid_support == 0) {
    close(rep_con)
    err_msg <- msg("cov_no_profiles_support", lang, min_support_cfg, prop, d1, d2, repo_root = repo_root)
    stop(err_msg, call. = FALSE)
  }
  
  # Spatial extraction
  pts_vect <- terra::vect(prof_valid, geom = c(".x", ".y"), crs = "EPSG:4326")
  pts_proj <- terra::project(pts_vect, cov_crs)
  extracted <- terra::extract(cov_stack, pts_proj, ID = FALSE)
  
  # Identify points outside raster extent or with NA covariates
  ext_cov <- terra::ext(cov_stack)
  crds_proj <- terra::crds(pts_proj)
  inside_box <- (crds_proj[, 1] >= ext_cov$xmin & crds_proj[, 1] <= ext_cov$xmax &
                 crds_proj[, 2] >= ext_cov$ymin & crds_proj[, 2] <= ext_cov$ymax)
  
  n_outside_extent <- sum(!inside_box)
  has_na_cov <- apply(extracted, 1, function(row) any(is.na(row)))
  n_na_cov <- sum(inside_box & has_na_cov)
  
  complete_mask <- inside_box & !has_na_cov
  n_complete <- sum(complete_mask)
  
  log_out(msg("cov_outside_raster", lang, n_outside_extent, repo_root = repo_root))
  log_out(msg("cov_na_covariates", lang, n_na_cov, repo_root = repo_root))
  log_out(msg("cov_complete_profiles", lang, n_complete, repo_root = repo_root))
  
  # Build target dataset: profile_id, x, y, <property>, and covariate columns ONLY
  target_df <- data.frame(
    profile_id = prof_valid$.pid[complete_mask],
    x = prof_valid$.x[complete_mask],
    y = prof_valid$.y[complete_mask],
    stringsAsFactors = FALSE
  )
  target_df[[prop]] <- prof_valid$.std_val[complete_mask]
  
  extracted_clean <- extracted[complete_mask, , drop = FALSE]
  for (cn in names(extracted_clean)) {
    target_df[[cn]] <- extracted_clean[[cn]]
  }
  
  out_csv <- file.path(data_dir, sprintf("04_cov_%s.csv", target_id))
  readr::write_csv(target_df, out_csv)
  
  log_out("================================================================================")
  log_out(msg("cov_written", lang, out_csv, report_file, repo_root = repo_root))
  close(rep_con)
  
  record_decision(
    project = project,
    step = "2",
    decision = sprintf("Depth standardisation and covariate extraction for target '%s' [%.0f, %.0f] cm", prop, d1, d2),
    details = sprintf("Retained %d complete profiles (min_support=%.1f cm, excluded_low_support=%d, outside_raster=%d, na_cov=%d). Written %s",
                      n_complete, min_support_cfg, n_low_support, n_outside_extent, n_na_cov, out_csv),
    repo_root = repo_root
  )
}

cat(msg("cov_all_completed", lang, active_count, repo_root = repo_root), "\n")
