# ==============================================================================
# DSM-Harness v2 | 02_scripts/01_2_byod_audit.R
# Step 1.2: Spatial Range Audit, CRS Diagnosis & Reprojection
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
  stop("Step 1.2 must be run within a project context (e.g., run_step('1.2', project = 'myproj'))")
}

proj_root <- file.path(repo_root, "projects", project)
data_dir <- file.path(proj_root, "data")
reports_dir <- file.path(proj_root, "reports")
if (!dir.exists(data_dir)) dir.create(data_dir, recursive = TRUE)
if (!dir.exists(reports_dir)) dir.create(reports_dir, recursive = TRUE)

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

# Verify that Step 1.1 output exists
in_csv <- file.path(data_dir, "01_mapped.csv")
if (!file.exists(in_csv)) {
  err_msg <- msg("step_missing_input", lang, "1.2", "data/01_mapped.csv", "1.1", repo_root = repo_root)
  stop(err_msg, call. = FALSE)
}

df <- as.data.frame(readr::read_csv(in_csv, show_col_types = FALSE))

x_col <- if (is_str(cfg$roles$x)) as.character(cfg$roles$x) else NULL
y_col <- if (is_str(cfg$roles$y)) as.character(cfg$roles$y) else NULL

if (is.null(x_col) || is.null(y_col) || !x_col %in% names(df) || !y_col %in% names(df)) {
  err_msg <- msg("spatial_coords_missing", lang, repo_root = repo_root)
  stop(err_msg, call. = FALSE)
}

# Coordinate ranges
x_vals <- as.numeric(df[[x_col]])
y_vals <- as.numeric(df[[y_col]])
x_valid <- x_vals[!is.na(x_vals)]
y_valid <- y_vals[!is.na(y_vals)]

if (length(x_valid) == 0 || length(y_valid) == 0) {
  stop("No non-NA coordinates found in dataset.", call. = FALSE)
}

x_min <- min(x_valid); x_max <- max(x_valid)
y_min <- min(y_valid); y_max <- max(y_valid)

# Diagnostic: geographic vs projected
is_geo <- (x_min >= -180 && x_max <= 180 && y_min >= -90 && y_max <= 90)

report_path <- file.path(reports_dir, "12_spatial.txt")
rep_con <- file(report_path, open = "wt", encoding = "UTF-8")

log_out <- function(...) {
  line <- paste0(...)
  cat(line, "\n")
  cat(line, "\n", file = rep_con)
}

log_out("================================================================================")
log_out("  DSM-HARNESS: STEP 1.2 SPATIAL AUDIT & CRS DIAGNOSIS")
log_out("================================================================================")
log_out("Date: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"))
log_out("Project: ", project)
log_out("Input File: data/01_mapped.csv (", nrow(df), " rows)")
log_out("Coordinate columns: X = '", x_col, "', Y = '", y_col, "'")
log_out(sprintf("Raw X range: [%.4f, %.4f]", x_min, x_max))
log_out(sprintf("Raw Y range: [%.4f, %.4f]\n", y_min, y_max))

if (is_geo) {
  log_out("Diagnostic: ", msg("spatial_looks_geographic", lang, x_min, x_max, y_min, y_max, repo_root = repo_root))
} else {
  log_out("Diagnostic: ", msg("spatial_looks_projected", lang, x_min, x_max, y_min, y_max, repo_root = repo_root))
}

source_crs <- cfg$source_crs

# If source_crs is missing or empty
if (!is_str(source_crs)) {
  crs_msg <- msg("spatial_crs_needed", lang, repo_root = repo_root)
  log_out("\n[NOTICE] ", crs_msg)
  close(rep_con)
  
  record_decision(
    project = project,
    step = "1.2",
    decision = "Spatial audit performed (CRS needed)",
    details = sprintf("Raw X: [%.2f, %.2f], Y: [%.2f, %.2f]. Awaiting source_crs.", x_min, x_max, y_min, y_max),
    repo_root = repo_root
  )
  
  cat(crs_msg, "\n")
  # Do NOT write 02_spatial.csv
} else {
  crs_str <- as.character(source_crs)
  log_out("\nConfigured source_crs: ", crs_str)
  
  # Check if CRS is already geographic (EPSG:4326 / WGS84)
  is_crs_geo <- grepl("4326|wgs84|crs84", tolower(crs_str))
  
  if (is_crs_geo || is_geo) {
    # Geographic coordinates pass through
    log_out("Coordinates are geographic (EPSG:4326). Passing through without reprojection.")
    res_lon_min <- x_min; res_lon_max <- x_max
    res_lat_min <- y_min; res_lat_max <- y_max
  } else {
    # Projected coordinates -> reproject to EPSG:4326
    crs_arg <- crs_str
    if (grepl("^[0-9]+$", crs_str)) {
      crs_arg <- as.integer(crs_str)
    }
    
    has_coords <- !is.na(df[[x_col]]) & !is.na(df[[y_col]])
    coords_df <- df[has_coords, c(x_col, y_col)]
    
    sf_pts <- sf::st_as_sf(coords_df, coords = c(x_col, y_col), crs = crs_arg)
    sf_geo <- sf::st_transform(sf_pts, 4326)
    geo_coords <- sf::st_coordinates(sf_geo)
    
    df[has_coords, x_col] <- geo_coords[, 1]
    df[has_coords, y_col] <- geo_coords[, 2]
    
    res_lon_min <- min(geo_coords[, 1]); res_lon_max <- max(geo_coords[, 1])
    res_lat_min <- min(geo_coords[, 2]); res_lat_max <- max(geo_coords[, 2])
    
    log_out(msg("spatial_reprojected", lang, crs_str, res_lon_min, res_lon_max, res_lat_min, res_lat_max, repo_root = repo_root))
  }
  
  log_out(sprintf("\nResulting Lon range: [%.4f, %.4f]", res_lon_min, res_lon_max))
  log_out(sprintf("Resulting Lat range: [%.4f, %.4f]\n", res_lat_min, res_lat_max))
  
  out_csv <- file.path(data_dir, "02_spatial.csv")
  readr::write_csv(df, out_csv)
  
  close(rep_con)
  
  record_decision(
    project = project,
    step = "1.2",
    decision = "Spatial audit and coordinate standardization",
    details = sprintf("source_crs: %s. Resulting Lon: [%.4f, %.4f], Lat: [%.4f, %.4f]. Written data/02_spatial.csv", crs_str, res_lon_min, res_lon_max, res_lat_min, res_lat_max),
    repo_root = repo_root
  )
  
  cat(msg("spatial_complete", lang, out_csv, report_path, repo_root = repo_root), "\n")
}
