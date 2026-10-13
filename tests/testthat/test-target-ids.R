test_that("get_target_id produces consistent canonical identifiers for special characters and depths", {
  # 1. Basic properties
  expect_equal(get_target_id("clay", 0, 30), "clay_0_30")
  expect_equal(get_target_id("clay", "0", "30"), "clay_0_30")
  
  # 2. Spaces, %, ., and -
  expect_equal(get_target_id("clay total", 0, 30), "clay_total_0_30")
  expect_equal(get_target_id("clay %", 0, 30), "clay___0_30")
  expect_equal(get_target_id("clay.pct", 0, 30), "clay_pct_0_30")
  expect_equal(get_target_id("clay-pct", 0, 30), "clay-pct_0_30")
  expect_equal(get_target_id("SOC (g/kg)", 0, 30), "SOC__g_kg__0_30")
  
  # 3. Fractional depths
  expect_equal(get_target_id("clay", 0.5, 2.5), "clay_0_5_2_5")
  expect_equal(get_target_id("clay", "0.5", "2.5"), "clay_0_5_2_5")
  expect_equal(get_target_id("sand-tot", 0.0, 15.5), "sand-tot_0_15_5")
})

test_that("Cross-step consistency: Steps 2-5 use identical target_id for names with spaces, %, ., - and decimals", {
  proj_name <- "test_cross_step_ids"
  cleanup_test_project(proj_name)
  on.exit(cleanup_test_project(proj_name), add = TRUE)
  
  create_synthetic_dataset(proj_name, format = "csv", coords_type = "geographic", n_profiles = 12)
  create_synthetic_covariates(proj_name, crs = "EPSG:4326")
  proj_dir <- file.path(repo_root, "projects", proj_name)
  
  # Inject target columns with special characters into raw csv
  raw_csv <- file.path(proj_dir, "data", "profiles_data.csv")
  df_raw <- read.csv(raw_csv)
  df_raw[["clay %"]] <- runif(nrow(df_raw), 10, 40)
  df_raw[["sand-tot"]] <- runif(nrow(df_raw), 20, 60)
  write.csv(df_raw, raw_csv, row.names = FALSE)
  
  # Setup config with target with spaces/symbols and fractional depth
  cfg_file <- file.path(proj_dir, "config.json")
  cfg <- jsonlite::fromJSON(cfg_file, simplifyVector = FALSE)
  cfg$input_file <- "data/profiles_data.csv"
  cfg$roles <- list(profile_id = "id", x = "x", y = "y", top = "upper", bottom = "lower")
  cfg$source_crs <- "EPSG:4326"
  cfg$country_code <- "SLV"
  cfg$project_code <- "TEST"
  cfg$tiles <- list(cols = 1, rows = 1)
  cfg$boruta_max_runs <- 11
  cfg$cv_folds <- 2
  cfg$cv_repeats <- 1
  cfg$targets <- list(
    list(
      property = "clay %",
      d1 = 0.5,
      d2 = 15.5,
      code = "CLAY_PCT",
      enabled = TRUE
    )
  )
  jsonlite::write_json(cfg, cfg_file, auto_unbox = TRUE, pretty = TRUE)
  
  # Run steps 1.1, 1.2, 1.3
  expect_true(run_step("1.1", project = proj_name))
  expect_true(run_step("1.2", project = proj_name))
  expect_true(run_step("1.3", project = proj_name))
  
  expected_id <- get_target_id("clay %", 0.5, 15.5)
  expect_equal(expected_id, "clay___0_5_15_5")
  
  # Run Step 2
  expect_true(run_step("2", project = proj_name))
  step2_csv <- file.path(proj_dir, "data", sprintf("04_cov_%s.csv", expected_id))
  step2_rep <- file.path(proj_dir, "reports", sprintf("20_covariates_%s.txt", expected_id))
  expect_true(file.exists(step2_csv))
  expect_true(file.exists(step2_rep))
  
  # Run Step 3
  expect_true(run_step("3", project = proj_name))
  step3_rds <- file.path(proj_dir, "outputs", "models", sprintf("%s.rds", expected_id))
  step3_json <- file.path(proj_dir, "outputs", "models", sprintf("metrics_%s.json", expected_id))
  step3_rep <- file.path(proj_dir, "reports", sprintf("30_modelling_%s.txt", expected_id))
  expect_true(file.exists(step3_rds))
  expect_true(file.exists(step3_json))
  expect_true(file.exists(step3_rep))
  
  # Check enriched metrics JSON (Precision 3)
  metrics_data <- jsonlite::fromJSON(step3_json)
  expect_true(!is.null(metrics_data$training_rows))
  expect_true(!is.null(metrics_data$boruta_confirmed))
  expect_true(!is.null(metrics_data$hyperparameters))
  expect_true(!is.null(metrics_data$cores_used))
  expect_true(!is.null(metrics_data$elapsed_seconds))
  
  # Run Step 4
  expect_true(run_step("4", project = proj_name))
  step4_rep <- file.path(proj_dir, "reports", sprintf("40_prediction_%s.txt", expected_id))
  expect_true(file.exists(step4_rep))
  
  mean_tif <- file.path(proj_dir, "outputs", "maps", "SLV-TEST-CLAY_PCT-0_5-15_5-mean.tif")
  sd_tif   <- file.path(proj_dir, "outputs", "maps", "SLV-TEST-CLAY_PCT-0_5-15_5-sd.tif")
  expect_true(file.exists(mean_tif))
  expect_true(file.exists(sd_tif))
  
  # Run Step 5
  expect_true(run_step("5", project = proj_name))
  step5_html <- file.path(proj_dir, "reports", sprintf("report_%s.html", expected_id))
  step5_rep  <- file.path(proj_dir, "reports", sprintf("50_report_%s.txt", expected_id))
  expect_true(file.exists(step5_html))
  expect_true(file.exists(step5_rep))
})
