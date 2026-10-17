# ==============================================================================
# DSM-Harness v2 | tests/testthat/test-03-model.R
# Test Step 3: Feature selection, QRF modeling, predictor isolation & CV metrics
# ==============================================================================

test_that("Step 3 fails cleanly when Step 2 outputs are missing", {
  proj_name <- "test_mod_missing_input"
  cleanup_test_project(proj_name)
  new_project(proj_name, repo_root = repo_root)
  
  cfg_path <- file.path(repo_root, "projects", proj_name, "config.json")
  cfg <- jsonlite::fromJSON(cfg_path, simplifyVector = FALSE)
  cfg$input_file <- "data/dummy.csv"
  cfg$targets <- list(list(property = "soc", d1 = 0, d2 = 30))
  jsonlite::write_json(cfg, cfg_path, auto_unbox = TRUE, pretty = TRUE)
  
  success <- run_step("3", proj_name)
  expect_false(success)
  
  err_file <- file.path(repo_root, "projects", proj_name, "reports", "30_error.txt")
  expect_true(file.exists(err_file))
  err_content <- readLines(err_file)
  expect_true(any(grepl("Step 2|Paso 2", err_content)))
  
  cleanup_test_project(proj_name)
})

test_that("Step 3 strictly asserts that predictors equal covariate raster layers only", {
  proj_name <- "test_mod_predictor_isolation"
  cleanup_test_project(proj_name)
  create_synthetic_dataset(proj_name, format = "csv", n_profiles = 25, coords_type = "geographic")
  create_synthetic_covariates(proj_name, crs = "EPSG:4326", n_layers = 2, mismatch = FALSE)
  
  cfg_path <- file.path(repo_root, "projects", proj_name, "config.json")
  cfg <- jsonlite::fromJSON(cfg_path, simplifyVector = FALSE)
  cfg$input_file <- "data/profiles_data.csv"
  cfg$roles <- list(profile_id = "id", x = "x", y = "y", top = "upper", bottom = "lower")
  cfg$source_crs <- "EPSG:4326"
  cfg$targets <- list(list(property = "soc", d1 = 0, d2 = 30))
  cfg$boruta_max_runs <- 15
  cfg$cv_folds <- 2
  cfg$cv_repeats <- 1
  jsonlite::write_json(cfg, cfg_path, auto_unbox = TRUE, pretty = TRUE)
  
  run_step("1.1", proj_name)
  run_step("1.2", proj_name)
  run_step("1.3", proj_name)
  run_step("2", proj_name)
  
  # Deliberately inject a rogue soil predictor into 04_cov_soc_0_30.csv
  cov_csv_path <- file.path(repo_root, "projects", proj_name, "data", "04_cov_soc_0_30.csv")
  df_tainted <- readr::read_csv(cov_csv_path, show_col_types = FALSE)
  df_tainted$rogue_soil_prop <- runif(nrow(df_tainted), 10, 50)
  readr::write_csv(df_tainted, cov_csv_path)
  
  # Step 3 must halt and refuse to train when non-raster predictor is detected
  success <- run_step("3", proj_name)
  expect_false(success)
  
  err_file <- file.path(repo_root, "projects", proj_name, "reports", "30_error.txt")
  expect_true(file.exists(err_file))
  err_content <- readLines(err_file)
  expect_true(any(grepl("rogue_soil_prop", err_content)))
  
  cleanup_test_project(proj_name)
})

test_that("Step 3 trains QRF, writes metrics & report with cores/elapsed time, and supports target filtering/skipping", {
  proj_name <- "test_mod_end_to_end"
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
  cfg$boruta_max_runs <- 15
  cfg$cv_folds <- 2
  cfg$cv_repeats <- 1
  jsonlite::write_json(cfg, cfg_path, auto_unbox = TRUE, pretty = TRUE)
  
  run_step("1.1", proj_name)
  run_step("1.2", proj_name)
  run_step("1.3", proj_name)
  run_step("2", proj_name)
  
  # 1. Run only target soc_0_30
  expect_true(run_step("3", proj_name, targets = "soc_0_30"))
  
  proj_dir <- file.path(repo_root, "projects", proj_name)
  m1_file <- file.path(proj_dir, "outputs", "models", "soc_0_30.rds")
  m2_file <- file.path(proj_dir, "outputs", "models", "soc_30_60.rds")
  metrics_file <- file.path(proj_dir, "outputs", "models", "metrics_soc_0_30.json")
  rep_file <- file.path(proj_dir, "reports", "30_modelling_soc_0_30.txt")
  
  expect_true(file.exists(m1_file))
  expect_false(file.exists(m2_file))
  expect_true(file.exists(metrics_file))
  expect_true(file.exists(rep_file))
  
  # Verify metrics content
  metrics <- jsonlite::fromJSON(metrics_file)
  expect_true(!is.null(metrics$RMSE))
  expect_true(!is.null(metrics$R2 %||% metrics$r2))
  expect_true(!is.null(metrics$MAE))
  
  # Verify report contains CPU cores, elapsed time, training n, and Boruta decisions
  rep_content <- readLines(rep_file)
  expect_true(any(grepl("CPU core|núcleo", rep_content, ignore.case = TRUE)))
  expect_true(any(grepl("seconds|segundos", rep_content, ignore.case = TRUE)))
  expect_true(any(grepl("Training observations|Observaciones de entrenamiento", rep_content, ignore.case = TRUE)))
  expect_true(any(grepl("Confirmed.*Tentative.*Rejected|confirmadas.*tentativas.*rechazadas", rep_content, ignore.case = TRUE)))
  
  # 2. Re-run without refit: should skip existing m1_file
  mod_time_before <- file.info(m1_file)$mtime
  expect_true(run_step("3", proj_name, targets = "soc_0_30", refit = FALSE))
  mod_time_after <- file.info(m1_file)$mtime
  expect_equal(mod_time_before, mod_time_after)
  
  # 3. Check decision log
  log_df <- readr::read_csv(file.path(proj_dir, "decisions_log.csv"), show_col_types = FALSE)
  expect_true(any(log_df$step == "3"))
  
  cleanup_test_project(proj_name)
})

test_that("Step 3 stops with error listing valid targets when targets filter matches nothing", {
  proj_name <- "test_mod_no_match"
  cleanup_test_project(proj_name)
  create_synthetic_dataset(proj_name, format = "csv", n_profiles = 25, coords_type = "geographic")
  create_synthetic_covariates(proj_name, crs = "EPSG:4326", n_layers = 2, mismatch = FALSE)
  
  cfg_path <- file.path(repo_root, "projects", proj_name, "config.json")
  cfg <- jsonlite::fromJSON(cfg_path, simplifyVector = FALSE)
  cfg$input_file <- "data/profiles_data.csv"
  cfg$roles <- list(profile_id = "id", x = "x", y = "y", top = "upper", bottom = "lower")
  cfg$source_crs <- "EPSG:4326"
  cfg$targets <- list(
    list(property = "soc", d1 = 0, d2 = 30),
    list(property = "soc", d1 = 30, d2 = 60)
  )
  cfg$boruta_max_runs <- 15
  cfg$cv_folds <- 2
  cfg$cv_repeats <- 1
  jsonlite::write_json(cfg, cfg_path, auto_unbox = TRUE, pretty = TRUE)
  
  run_step("1.1", proj_name)
  run_step("1.2", proj_name)
  run_step("1.3", proj_name)
  run_step("2", proj_name)
  
  # Run Step 3 with target filter that does NOT match any target
  success <- run_step("3", proj_name, targets = c("nonexistent_prop", "clay_0_10"))
  expect_false(success)
  
  err_file <- file.path(repo_root, "projects", proj_name, "reports", "30_error.txt")
  expect_true(file.exists(err_file))
  err_content <- readLines(err_file)
  
  # Must list valid targets in the error
  expect_true(any(grepl("soc_0_30", err_content)))
  expect_true(any(grepl("soc_30_60", err_content)))
  expect_true(any(grepl("nonexistent_prop", err_content)))
  
  cleanup_test_project(proj_name)
})

