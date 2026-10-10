# ==============================================================================
# DSM-Harness v2 | tests/testthat/test-02-covariates.R
# Test Step 2: Depth standardisation and covariate extraction
# ==============================================================================

test_that("Step 2 fails cleanly when 03_clean.csv is missing", {
  proj_name <- "test_cov_missing_input"
  cleanup_test_project(proj_name)
  new_project(proj_name, repo_root = repo_root)
  
  success <- run_step("2", proj_name)
  expect_false(success)
  
  err_file <- file.path(repo_root, "projects", proj_name, "reports", "20_error.txt")
  expect_true(file.exists(err_file))
  err_content <- readLines(err_file)
  expect_true(any(grepl("1\\.3", err_content)))
  
  cleanup_test_project(proj_name)
})

test_that("Step 2 stops when no covariate rasters are present in covariates/", {
  proj_name <- "test_cov_no_rasters"
  cleanup_test_project(proj_name)
  create_synthetic_dataset(proj_name, format = "csv", coords_type = "geographic")
  
  cfg_path <- file.path(repo_root, "projects", proj_name, "config.json")
  cfg <- jsonlite::fromJSON(cfg_path, simplifyVector = FALSE)
  cfg$input_file <- "data/profiles_data.csv"
  cfg$roles <- list(profile_id = "id", x = "x", y = "y", top = "upper", bottom = "lower")
  cfg$source_crs <- "EPSG:4326"
  cfg$targets <- list(list(property = "soc", d1 = 0, d2 = 30))
  jsonlite::write_json(cfg, cfg_path, auto_unbox = TRUE, pretty = TRUE)
  
  expect_true(run_step("1.1", proj_name))
  expect_true(run_step("1.2", proj_name))
  expect_true(run_step("1.3", proj_name))
  
  # Run Step 2 without any raster in covariates/
  success <- run_step("2", proj_name)
  expect_false(success)
  
  err_file <- file.path(repo_root, "projects", proj_name, "reports", "20_error.txt")
  expect_true(file.exists(err_file))
  err_content <- readLines(err_file)
  expect_true(any(grepl("covariates", err_content)))
  
  cleanup_test_project(proj_name)
})

test_that("Step 2 detects and stops when covariate rasters mismatch in CRS/extent/res", {
  proj_name <- "test_cov_mismatch"
  cleanup_test_project(proj_name)
  create_synthetic_dataset(proj_name, format = "csv", coords_type = "geographic")
  create_synthetic_covariates(proj_name, crs = "EPSG:4326", n_layers = 2, mismatch = TRUE)
  
  cfg_path <- file.path(repo_root, "projects", proj_name, "config.json")
  cfg <- jsonlite::fromJSON(cfg_path, simplifyVector = FALSE)
  cfg$input_file <- "data/profiles_data.csv"
  cfg$roles <- list(profile_id = "id", x = "x", y = "y", top = "upper", bottom = "lower")
  cfg$source_crs <- "EPSG:4326"
  cfg$targets <- list(list(property = "soc", d1 = 0, d2 = 30))
  jsonlite::write_json(cfg, cfg_path, auto_unbox = TRUE, pretty = TRUE)
  
  expect_true(run_step("1.1", proj_name))
  expect_true(run_step("1.2", proj_name))
  expect_true(run_step("1.3", proj_name))
  
  success <- run_step("2", proj_name)
  expect_false(success)
  
  err_file <- file.path(repo_root, "projects", proj_name, "reports", "20_error.txt")
  expect_true(file.exists(err_file))
  err_content <- readLines(err_file)
  expect_true(any(grepl("mismatch|Discrepancia", err_content, ignore.case = TRUE)))
  
  cleanup_test_project(proj_name)
})

test_that("Step 2 standardises depth, extracts covariates, and strictly isolates predictors", {
  proj_name <- "test_cov_standard"
  cleanup_test_project(proj_name)
  create_synthetic_dataset(proj_name, format = "csv", n_profiles = 25, coords_type = "geographic")
  create_synthetic_covariates(proj_name, crs = "EPSG:4326", n_layers = 3, mismatch = FALSE)
  
  cfg_path <- file.path(repo_root, "projects", proj_name, "config.json")
  cfg <- jsonlite::fromJSON(cfg_path, simplifyVector = FALSE)
  cfg$input_file <- "data/profiles_data.csv"
  cfg$roles <- list(profile_id = "id", x = "x", y = "y", top = "upper", bottom = "lower")
  cfg$source_crs <- "EPSG:4326"
  cfg$targets <- list(
    list(property = "soc", d1 = 0, d2 = 30),
    list(property = "soc", d1 = 30, d2 = 60)
  )
  cfg$min_support <- 5
  jsonlite::write_json(cfg, cfg_path, auto_unbox = TRUE, pretty = TRUE)
  
  expect_true(run_step("1.1", proj_name))
  expect_true(run_step("1.2", proj_name))
  expect_true(run_step("1.3", proj_name))
  
  success <- run_step("2", proj_name)
  expect_true(success)
  
  proj_dir <- file.path(repo_root, "projects", proj_name)
  
  # Outputs check
  out_csv_1 <- file.path(proj_dir, "data", "04_cov_soc_0_30.csv")
  out_csv_2 <- file.path(proj_dir, "data", "04_cov_soc_30_60.csv")
  rep_1 <- file.path(proj_dir, "reports", "20_covariates_soc_0_30.txt")
  rep_2 <- file.path(proj_dir, "reports", "20_covariates_soc_30_60.txt")
  
  expect_true(file.exists(out_csv_1))
  expect_true(file.exists(out_csv_2))
  expect_true(file.exists(rep_1))
  expect_true(file.exists(rep_2))
  
  df_cov1 <- readr::read_csv(out_csv_1, show_col_types = FALSE)
  
  # Strict column isolation: only profile_id, x, y, soc, and cov_*
  expected_cols <- c("profile_id", "x", "y", "soc", "cov_01", "cov_02", "cov_03")
  expect_equal(names(df_cov1), expected_cols)
  
  # No auxiliary soil properties present
  forbidden_cols <- c("clay", "sand", "silt", "ph", "bd", "upper", "lower")
  expect_equal(intersect(names(df_cov1), forbidden_cols), character(0))
  
  # Check decision log
  log_file <- file.path(proj_dir, "decisions_log.csv")
  expect_true(file.exists(log_file))
  log_df <- readr::read_csv(log_file, show_col_types = FALSE)
  expect_true(any(log_df$step == "2"))
  
  cleanup_test_project(proj_name)
})
