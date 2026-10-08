# ==============================================================================
# DSM-Harness v2 | tests/testthat/helper.R
# Test helpers and synthetic dataset generation
# ==============================================================================

# Find repo root and load runner
repo_root <- normalizePath(file.path(getwd(), "..", ".."), winslash = "/", mustWork = FALSE)
if (!file.exists(file.path(repo_root, "DSM-Harness.Rproj"))) {
  repo_root <- normalizePath(getwd(), winslash = "/", mustWork = FALSE)
  while (nchar(repo_root) > 0 && dirname(repo_root) != repo_root) {
    if (file.exists(file.path(repo_root, "DSM-Harness.Rproj"))) break
    repo_root <- dirname(repo_root)
  }
}

source(file.path(repo_root, "run_step.R"), local = FALSE)
source(file.path(repo_root, "R", "decisions.R"), local = FALSE)
source(file.path(repo_root, "R", "validate_config.R"), local = FALSE)
source(file.path(repo_root, "02_scripts", "i18n", "load_i18n.R"), local = FALSE)

cleanup_test_project <- function(proj_name) {
  pdir <- file.path(repo_root, "projects", proj_name)
  if (dir.exists(pdir)) {
    unlink(pdir, recursive = TRUE, force = TRUE)
  }
}

create_synthetic_dataset <- function(proj_name, format = "csv", dup_keys = FALSE, n_profiles = 20, coords_type = "projected") {
  new_project(proj_name, repo_root = repo_root)
  proj_dir <- file.path(repo_root, "projects", proj_name)
  data_dir <- file.path(proj_dir, "data")
  
  # Coordinates
  if (coords_type == "projected") {
    # UTM zone 42N
    x_coords <- seq(450000, 460000, length.out = n_profiles)
    y_coords <- seq(4600000, 4610000, length.out = n_profiles)
  } else {
    # Geographic WGS84
    x_coords <- seq(74.5, 75.5, length.out = n_profiles)
    y_coords <- seq(41.5, 42.5, length.out = n_profiles)
  }
  
  prof_ids <- sprintf("P%03d", seq_len(n_profiles))
  
  df_profiles <- data.frame(
    id = prof_ids,
    x = x_coords,
    y = y_coords,
    elevation = seq(1000, 1500, length.out = n_profiles),
    stringsAsFactors = FALSE
  )
  
  if (dup_keys) {
    # Duplicate first profile key
    dup_row <- df_profiles[1, , drop = FALSE]
    dup_row$elevation <- 1050
    df_profiles <- rbind(df_profiles, dup_row)
  }
  
  # Generate ~2 horizons per profile (>= 35 horizons if n_profiles >= 20)
  horiz_list <- list()
  for (i in seq_len(n_profiles)) {
    pid <- prof_ids[i]
    # Layer 1: 0-30
    # Layer 2: 30-60
    soc_1 <- round(runif(1, 1.5, 3.5), 2)
    soc_2 <- round(runif(1, 0.5, 1.8), 2)
    bd_1 <- round(runif(1, 1.1, 1.4), 2)
    bd_2 <- round(runif(1, 1.3, 1.6), 2)
    
    horiz_list[[length(horiz_list) + 1]] <- data.frame(
      id = pid,
      upper = 0,
      lower = 30,
      soc = soc_1,
      clay = 25,
      sand = 45,
      silt = 30,
      ph = 7.2,
      bd = bd_1,
      stringsAsFactors = FALSE
    )
    horiz_list[[length(horiz_list) + 1]] <- data.frame(
      id = pid,
      upper = 30,
      lower = 60,
      soc = soc_2,
      clay = 30,
      sand = 40,
      silt = 30,
      ph = 7.5,
      bd = bd_2,
      stringsAsFactors = FALSE
    )
  }
  df_horizons <- do.call(rbind, horiz_list)
  
  if (format == "excel") {
    file_path <- file.path(data_dir, "profiles_data.xlsx")
    writexl::write_xlsx(list(profiles = df_profiles, horizons = df_horizons), path = file_path)
    rel_path <- "data/profiles_data.xlsx"
  } else {
    df_flat <- merge(df_horizons, df_profiles, by = "id")
    file_path <- file.path(data_dir, "profiles_data.csv")
    readr::write_csv(df_flat, file_path)
    rel_path <- "data/profiles_data.csv"
  }
  
  rel_path
}
