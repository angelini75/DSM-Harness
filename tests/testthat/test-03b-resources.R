# ==============================================================================
# DSM-Harness v2 | tests/testthat/test-03b-resources.R
# Test Step 3b: Hardware & raster resource diagnosis and tiling advisory
# ==============================================================================

test_that("Step 3b fails cleanly when no covariate rasters exist", {
  proj_name <- "test_res_no_rasters"
  cleanup_test_project(proj_name)
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
  
  cleanup_test_project(proj_name)
})

test_that("Step 3b diagnoses hardware/raster volume and writes tiling advisory report without creating maps", {
  proj_name <- "test_res_complete"
  cleanup_test_project(proj_name)
  create_synthetic_dataset(proj_name, format = "csv", n_profiles = 20, coords_type = "geographic")
  create_synthetic_covariates(proj_name, crs = "EPSG:4326", n_layers = 4, mismatch = FALSE)
  
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
  
  expect_true(run_step("1.1", proj_name))
  expect_true(run_step("1.2", proj_name))
  expect_true(run_step("1.3", proj_name))
  expect_true(run_step("2", proj_name))
  expect_true(run_step("3", proj_name))
  
  success <- run_step("3b", proj_name)
  expect_true(success)
  
  proj_dir <- file.path(repo_root, "projects", proj_name)
  rep_file <- file.path(proj_dir, "reports", "3b_resources.txt")
  expect_true(file.exists(rep_file))
  
  lines <- readLines(rep_file)
  expect_true(any(grepl("CPU Cores|Núcleos de CPU", lines, ignore.case = TRUE)))
  expect_true(any(grepl("RAM", lines, ignore.case = TRUE)))
  expect_true(any(grepl("Raster Dimensions|Dimensiones del ráster", lines, ignore.case = TRUE)))
  expect_true(any(grepl("Tiling|teselas|tiles", lines, ignore.case = TRUE)))
  
  # Assert Step 3b does NOT produce map outputs (strictly advisory)
  maps_dir <- file.path(proj_dir, "outputs", "maps")
  if (dir.exists(maps_dir)) {
    expect_equal(length(list.files(maps_dir)), 0)
  }
  
  # Check decision log
  log_df <- readr::read_csv(file.path(proj_dir, "decisions_log.csv"), show_col_types = FALSE)
  expect_true(any(log_df$step == "3b"))
  
  cleanup_test_project(proj_name)
})
