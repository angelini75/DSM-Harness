# ==============================================================================
# DSM-Harness v2 | tests/testthat/test-03b-resources.R
# Test Step 3b: Hardware & raster resource diagnosis and tiling advisory
# ==============================================================================

test_that("Step 3b fails cleanly when no covariate rasters exist", {
  proj_name <- "test_res_no_rasters"
  cleanup_test_project(proj_name)
  on.exit(cleanup_test_project(proj_name), add = TRUE)
  new_project(proj_name, repo_root = repo_root)
  
  cfg_path <- file.path(repo_root, "projects", proj_name, "config.json")
  cfg <- jsonlite::fromJSON(cfg_path, simplifyVector = FALSE)
  cfg$input_file <- "data/dummy.csv"
  jsonlite::write_json(cfg, cfg_path, auto_unbox = TRUE, pretty = TRUE)
  
  success <- run_step("3b", proj_name)
  expect_false(success)
  
  err_file <- file.path(repo_root, "projects", proj_name, "reports", "3b_error.txt")
  expect_true(file.exists(err_file))
  err_content <- readLines(err_file)
  expect_true(any(grepl("covariates", err_content)))
})

test_that("Step 3b reports missing hardware config and marks tiling NO EVALUADO when ram_gb or cores is missing", {
  proj_name <- "test_res_missing_hw"
  cleanup_test_project(proj_name)
  on.exit(cleanup_test_project(proj_name), add = TRUE)

  create_synthetic_dataset(proj_name, format = "csv", n_profiles = 20, coords_type = "geographic")
  create_synthetic_covariates(proj_name, crs = "EPSG:4326", n_layers = 4, mismatch = FALSE)
  
  cfg_path <- file.path(repo_root, "projects", proj_name, "config.json")
  cfg <- jsonlite::fromJSON(cfg_path, simplifyVector = FALSE)
  cfg$input_file <- "data/profiles_data.csv"
  cfg$roles <- list(profile_id = "id", x = "x", y = "y", top = "upper", bottom = "lower")
  cfg$source_crs <- "EPSG:4326"
  cfg$targets <- list(list(property = "soc", d1 = 0, d2 = 30, code = "SOC"))
  # Note: cfg$cores and cfg$ram_gb are omitted!
  jsonlite::write_json(cfg, cfg_path, auto_unbox = TRUE, pretty = TRUE)
  
  expect_true(run_step("1.1", proj_name))
  expect_true(run_step("1.2", proj_name))
  expect_true(run_step("1.3", proj_name))
  expect_true(run_step("2", proj_name))
  
  # Step 3b runs without error, but reports missing config
  success <- run_step("3b", proj_name)
  expect_true(success)
  
  proj_dir <- file.path(repo_root, "projects", proj_name)
  rep_file <- file.path(proj_dir, "reports", "3b_resources.txt")
  expect_true(file.exists(rep_file))
  
  lines <- readLines(rep_file, warn = FALSE)
  expect_true(any(grepl("hardware specifications missing|Faltan especificaciones de hardware", lines, ignore.case = TRUE)))
  expect_true(any(grepl("NOT EVALUATED|NO EVALUADO", lines, ignore.case = TRUE)))
})

test_that("Step 3b monotonic vertical tiling: more ram_gb gives equal or fewer cols and rows is always 1", {
  proj_name <- "test_res_monotonic"
  cleanup_test_project(proj_name)
  on.exit(cleanup_test_project(proj_name), add = TRUE)

  create_synthetic_dataset(proj_name, format = "csv", n_profiles = 25, coords_type = "geographic")
  create_synthetic_covariates(proj_name, crs = "EPSG:4326", n_layers = 10, mismatch = FALSE)
  
  cfg_path <- file.path(repo_root, "projects", proj_name, "config.json")
  cfg <- jsonlite::fromJSON(cfg_path, simplifyVector = FALSE)
  cfg$input_file <- "data/profiles_data.csv"
  cfg$roles <- list(profile_id = "id", x = "x", y = "y", top = "upper", bottom = "lower")
  cfg$source_crs <- "EPSG:4326"
  cfg$targets <- list(list(property = "soc", d1 = 0, d2 = 30, code = "SOC"))
  cfg$cores <- 4
  cfg$ram_share <- 0.1
  cfg$ram_gb <- 0.001 # Small RAM to force multiple tiles
  jsonlite::write_json(cfg, cfg_path, auto_unbox = TRUE, pretty = TRUE)
  
  expect_true(run_step("1.1", proj_name))
  expect_true(run_step("1.2", proj_name))
  expect_true(run_step("1.3", proj_name))
  expect_true(run_step("2", proj_name))
  
  # 1. Run with small ram_gb
  expect_true(run_step("3b", proj_name))
  rep_file <- file.path(repo_root, "projects", proj_name, "reports", "3b_resources.txt")
  lines_small <- readLines(rep_file, warn = FALSE)
  tiling_line_small <- grep("Proposed Tiling|Esquema de teselado", lines_small, value = TRUE)
  # Extract cols count from e.g. "4 vertical tiles (4 cols x 1 rows)"
  cols_small <- as.integer(sub(".*\\((\\d+)\\s*(cols|columnas).*", "\\1", tiling_line_small))
  expect_true(cols_small >= 1)
  expect_true(grepl("1\\s*(rows|filas)", tiling_line_small, ignore.case = TRUE))
  
  # 2. Run with much larger ram_gb
  cfg$ram_gb <- 16
  jsonlite::write_json(cfg, cfg_path, auto_unbox = TRUE, pretty = TRUE)
  expect_true(run_step("3b", proj_name))
  lines_large <- readLines(rep_file, warn = FALSE)
  tiling_line_large <- grep("Proposed Tiling|Esquema de teselado", lines_large, value = TRUE)
  cols_large <- as.integer(sub(".*\\((\\d+)\\s*(cols|columnas).*", "\\1", tiling_line_large))
  
  # More RAM must give equal or fewer cols
  expect_true(cols_large <= cols_small)
  # rows must always be 1
  expect_true(grepl("1\\s*(rows|filas)", tiling_line_large, ignore.case = TRUE))
})

test_that("Step 3b handles older model with missing training_rows as no model: covariates only, prediction memory NO EVALUADO", {
  proj_name <- "test_res_no_training_rows"
  cleanup_test_project(proj_name)
  on.exit(cleanup_test_project(proj_name), add = TRUE)

  create_synthetic_dataset(proj_name, format = "csv", n_profiles = 25, coords_type = "geographic")
  create_synthetic_covariates(proj_name, crs = "EPSG:4326", n_layers = 4, mismatch = FALSE)
  
  cfg_path <- file.path(repo_root, "projects", proj_name, "config.json")
  cfg <- jsonlite::fromJSON(cfg_path, simplifyVector = FALSE)
  cfg$input_file <- "data/profiles_data.csv"
  cfg$roles <- list(profile_id = "id", x = "x", y = "y", top = "upper", bottom = "lower")
  cfg$source_crs <- "EPSG:4326"
  cfg$targets <- list(list(property = "soc", d1 = 0, d2 = 30, code = "SOC"))
  cfg$cores <- 4
  cfg$ram_gb <- 8
  jsonlite::write_json(cfg, cfg_path, auto_unbox = TRUE, pretty = TRUE)
  
  expect_true(run_step("1.1", proj_name))
  expect_true(run_step("1.2", proj_name))
  expect_true(run_step("1.3", proj_name))
  expect_true(run_step("2", proj_name))
  
  # Create a legacy metrics file lacking training_rows
  models_dir <- file.path(repo_root, "projects", proj_name, "outputs", "models")
  dir.create(models_dir, recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(list(rmse = 0.5, r2 = 0.2), file.path(models_dir, "metrics_legacy.json"), auto_unbox = TRUE)
  
  expect_true(run_step("3b", proj_name))
  
  rep_file <- file.path(repo_root, "projects", proj_name, "reports", "3b_resources.txt")
  lines <- readLines(rep_file, warn = FALSE)
  
  # Assert prediction memory is marked NOT EVALUATED (covariates only)
  expect_true(any(grepl("Prediction Memory: NOT EVALUATED|Memoria de Predicción: NO EVALUADO", lines)))
  # Assert proposal is still generated using covariates footprint
  expect_true(any(grepl("Proposed Tiling Scheme|Esquema de teselado propuesto", lines)))
})

test_that("Step 3b with multiple models uses maximum training_rows and states so in the report", {
  proj_name <- "test_res_multi_models"
  cleanup_test_project(proj_name)
  on.exit(cleanup_test_project(proj_name), add = TRUE)

  create_synthetic_dataset(proj_name, format = "csv", n_profiles = 25, coords_type = "geographic")
  create_synthetic_covariates(proj_name, crs = "EPSG:4326", n_layers = 4, mismatch = FALSE)
  
  cfg_path <- file.path(repo_root, "projects", proj_name, "config.json")
  cfg <- jsonlite::fromJSON(cfg_path, simplifyVector = FALSE)
  cfg$input_file <- "data/profiles_data.csv"
  cfg$roles <- list(profile_id = "id", x = "x", y = "y", top = "upper", bottom = "lower")
  cfg$source_crs <- "EPSG:4326"
  cfg$targets <- list(list(property = "soc", d1 = 0, d2 = 30, code = "SOC"))
  cfg$cores <- 4
  cfg$ram_gb <- 8
  jsonlite::write_json(cfg, cfg_path, auto_unbox = TRUE, pretty = TRUE)
  
  expect_true(run_step("1.1", proj_name))
  expect_true(run_step("1.2", proj_name))
  expect_true(run_step("1.3", proj_name))
  expect_true(run_step("2", proj_name))
  
  # Create two metrics files with different training_rows
  models_dir <- file.path(repo_root, "projects", proj_name, "outputs", "models")
  dir.create(models_dir, recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(list(training_rows = 150), file.path(models_dir, "metrics_tgt1.json"), auto_unbox = TRUE)
  jsonlite::write_json(list(training_rows = 450), file.path(models_dir, "metrics_tgt2.json"), auto_unbox = TRUE)
  
  expect_true(run_step("3b", proj_name))
  
  rep_file <- file.path(repo_root, "projects", proj_name, "reports", "3b_resources.txt")
  lines <- readLines(rep_file, warn = FALSE)
  
  # Assert max training rows (450) across 2 models is reported
  expect_true(any(grepl("n = 450", lines)))
  expect_true(any(grepl("across 2 model|sobre 2 modelo", lines)))
})
