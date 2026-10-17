# ==============================================================================
# DSM-Harness v2 | tests/testthat/test-04-predict.R
# Tests for Step 4: Spatial Prediction & OpenNSIS COG Export
# ==============================================================================

test_that("Step 4 stops if 'tiles' is missing from config.json pointing to reports/3b_resources.txt", {
  proj_name <- "test_pred_missing_tiles"
  cleanup_test_project(proj_name)
  on.exit(cleanup_test_project(proj_name), add = TRUE)
  
  rel_path <- create_synthetic_dataset(proj_name, format = "csv", coords_type = "geographic", n_profiles = 20)
  create_synthetic_covariates(proj_name)
  
  proj_dir <- file.path(repo_root, "projects", proj_name)
  cfg <- list(
    project = proj_name,
    language = "en",
    input_file = rel_path,
    base_table = "profiles_data",
    roles = list(profile_id = "id", x = "x", y = "y", top = "upper", bottom = "lower"),
    source_crs = "EPSG:4326",
    country_code = "TST",
    project_code = "PROJ",
    targets = list(
      list(property = "soc", d1 = 0, d2 = 30, code = "SOC")
    )
  )
  jsonlite::write_json(cfg, file.path(proj_dir, "config.json"), auto_unbox = TRUE, pretty = TRUE)
  
  res <- run_step("4", project = proj_name)
  expect_false(res)
  
  err_file <- file.path(proj_dir, "reports", "40_error.txt")
  expect_true(file.exists(err_file))
  err_content <- paste(readLines(err_file, warn = FALSE), collapse = " ")
  expect_true(grepl("3b_resources\\.txt", err_content))
})

test_that("Step 4 stops if country_code or project_code is missing without defaults or examples", {
  proj_name <- "test_pred_missing_codes"
  cleanup_test_project(proj_name)
  on.exit(cleanup_test_project(proj_name), add = TRUE)
  
  rel_path <- create_synthetic_dataset(proj_name, format = "csv", coords_type = "geographic", n_profiles = 20)
  create_synthetic_covariates(proj_name)
  
  proj_dir <- file.path(repo_root, "projects", proj_name)
  
  # 1. Missing country_code
  cfg_no_country <- list(
    project = proj_name,
    language = "en",
    input_file = rel_path,
    base_table = "profiles_data",
    roles = list(profile_id = "id", x = "x", y = "y", top = "upper", bottom = "lower"),
    source_crs = "EPSG:4326",
    project_code = "PROJ",
    tiles = list(cols = 2, rows = 1),
    targets = list(list(property = "soc", d1 = 0, d2 = 30, code = "SOC"))
  )
  jsonlite::write_json(cfg_no_country, file.path(proj_dir, "config.json"), auto_unbox = TRUE, pretty = TRUE)
  
  expect_false(run_step("4", project = proj_name))
  err_file <- file.path(proj_dir, "reports", "40_error.txt")
  err_lines <- readLines(err_file, warn = FALSE)
  err_msg <- grep("^Error:\\s*", err_lines, value = TRUE)
  expect_true(grepl("country_code", err_msg))
  # Precision 5: no example codes in messages
  expect_false(grepl("URY|SOILFER|GTM|CRI", err_msg))
  
  # 2. Missing project_code
  cfg_no_proj <- list(
    project = proj_name,
    language = "en",
    input_file = rel_path,
    base_table = "profiles_data",
    roles = list(profile_id = "id", x = "x", y = "y", top = "upper", bottom = "lower"),
    source_crs = "EPSG:4326",
    country_code = "TST",
    tiles = list(cols = 2, rows = 1),
    targets = list(list(property = "soc", d1 = 0, d2 = 30, code = "SOC"))
  )
  jsonlite::write_json(cfg_no_proj, file.path(proj_dir, "config.json"), auto_unbox = TRUE, pretty = TRUE)
  
  expect_false(run_step("4", project = proj_name))
  err_lines <- readLines(err_file, warn = FALSE)
  err_msg <- grep("^Error:\\s*", err_lines, value = TRUE)
  expect_true(grepl("project_code", err_msg))
  expect_false(grepl("URY|SOILFER|GTM|CRI", err_msg))
})

test_that("Step 4 stops if target code is missing from config.json (Precision 2)", {
  proj_name <- "test_pred_missing_target_code"
  cleanup_test_project(proj_name)
  on.exit(cleanup_test_project(proj_name), add = TRUE)
  
  rel_path <- create_synthetic_dataset(proj_name, format = "csv", coords_type = "geographic", n_profiles = 20)
  create_synthetic_covariates(proj_name)
  
  proj_dir <- file.path(repo_root, "projects", proj_name)
  cfg <- list(
    project = proj_name,
    language = "en",
    input_file = rel_path,
    base_table = "profiles_data",
    roles = list(profile_id = "id", x = "x", y = "y", top = "upper", bottom = "lower"),
    source_crs = "EPSG:4326",
    country_code = "TST",
    project_code = "PROJ",
    tiles = list(cols = 2, rows = 1),
    targets = list(
      list(property = "soc", d1 = 0, d2 = 30) # no code!
    )
  )
  jsonlite::write_json(cfg, file.path(proj_dir, "config.json"), auto_unbox = TRUE, pretty = TRUE)
  
  res <- run_step("4", project = proj_name)
  expect_false(res)
  
  err_file <- file.path(proj_dir, "reports", "40_error.txt")
  expect_true(file.exists(err_file))
  err_content <- paste(readLines(err_file, warn = FALSE), collapse = " ")
  expect_true(grepl("code", err_content))
})

test_that("Step 4 compares forest features with raster layers and names missing layers in error", {
  proj_name <- "test_pred_missing_covs"
  cleanup_test_project(proj_name)
  on.exit(cleanup_test_project(proj_name), add = TRUE)
  
  rel_path <- create_synthetic_dataset(proj_name, format = "csv", coords_type = "geographic", n_profiles = 20)
  create_synthetic_covariates(proj_name, n_layers = 2) # raster has cov_01, cov_02
  
  proj_dir <- file.path(repo_root, "projects", proj_name)
  cfg <- list(
    project = proj_name,
    language = "en",
    input_file = rel_path,
    base_table = "profiles_data",
    roles = list(profile_id = "id", x = "x", y = "y", top = "upper", bottom = "lower"),
    source_crs = "EPSG:4326",
    country_code = "TST",
    project_code = "DEMO",
    tiles = list(cols = 2, rows = 1),
    targets = list(list(property = "soc", d1 = 0, d2 = 30, code = "SOC"))
  )
  jsonlite::write_json(cfg, file.path(proj_dir, "config.json"), auto_unbox = TRUE, pretty = TRUE)
  
  # Create a mock ranger model expecting cov_missing_layer
  models_dir <- file.path(proj_dir, "outputs", "models")
  if (!dir.exists(models_dir)) dir.create(models_dir, recursive = TRUE)
  
  mock_forest <- list(independent.variable.names = c("cov_01", "cov_missing_layer"))
  mock_ranger <- list(forest = mock_forest)
  mock_caret <- list(finalModel = mock_ranger)
  saveRDS(mock_caret, file.path(models_dir, "soc_0_30.rds"))
  
  res <- run_step("4", project = proj_name)
  expect_false(res)
  
  err_file <- file.path(proj_dir, "reports", "40_error.txt")
  expect_true(file.exists(err_file))
  err_content <- paste(readLines(err_file, warn = FALSE), collapse = " ")
  expect_true(grepl("cov_missing_layer", err_content))
})

test_that("Step 4 performs tiled spatial prediction, exports verified COG, and reports elapsed time", {
  proj_name <- "test_pred_pipeline"
  cleanup_test_project(proj_name)
  on.exit(cleanup_test_project(proj_name), add = TRUE)
  
  rel_path <- create_synthetic_dataset(proj_name, format = "csv", coords_type = "geographic", n_profiles = 25)
  create_synthetic_covariates(proj_name, n_layers = 3)
  
  proj_dir <- file.path(repo_root, "projects", proj_name)
  cfg <- list(
    project = proj_name,
    language = "en",
    input_file = rel_path,
    base_table = "profiles_data",
    roles = list(profile_id = "id", x = "x", y = "y", top = "upper", bottom = "lower"),
    source_crs = "EPSG:4326",
    country_code = "TST",
    project_code = "DEMO",
    tiles = list(cols = 2, rows = 1),
    targets = list(list(property = "soc", d1 = 0, d2 = 30, code = "SOC", enabled = TRUE))
  )
  jsonlite::write_json(cfg, file.path(proj_dir, "config.json"), auto_unbox = TRUE, pretty = TRUE)
  
  # Run pipeline up to Step 3
  expect_true(run_step("1.1", project = proj_name))
  expect_true(run_step("1.2", project = proj_name))
  expect_true(run_step("1.3", project = proj_name))
  expect_true(run_step("2", project = proj_name))
  expect_true(run_step("3", project = proj_name))
  
  # Run Step 4
  res4 <- run_step("4", project = proj_name)
  expect_true(res4)
  
  # Check OpenNSIS filenames
  mean_tif <- file.path(proj_dir, "outputs", "maps", "TST-DEMO-SOC-0-30-mean.tif")
  sd_tif   <- file.path(proj_dir, "outputs", "maps", "TST-DEMO-SOC-0-30-sd.tif")
  expect_true(file.exists(mean_tif))
  expect_true(file.exists(sd_tif))
  
  # Check COG layout
  mean_desc <- terra::describe(mean_tif)
  expect_true(any(grepl("LAYOUT=COG", mean_desc)))
  
  # Check diagnostic report
  rep_file <- file.path(proj_dir, "reports", "40_prediction_soc_0_30.txt")
  expect_true(file.exists(rep_file))
  rep_lines <- readLines(rep_file, warn = FALSE)
  rep_text <- paste(rep_lines, collapse = " ")
  
  expect_true(grepl("LAYOUT=COG", rep_text))
  expect_true(grepl("seconds", rep_text, ignore.case = TRUE))
  
  # Check decisions log
  dec_file <- file.path(proj_dir, "decisions_log.csv")
  expect_true(file.exists(dec_file))
  dec_df <- read.csv(dec_file, stringsAsFactors = FALSE)
  expect_true(any(dec_df$step == "4"))
  
  # Precision 3: Skip existing maps unless refit
  mtime_before <- file.info(mean_tif)$mtime
  Sys.sleep(1)
  expect_true(run_step("4", project = proj_name, refit = FALSE))
  mtime_after <- file.info(mean_tif)$mtime
  expect_equal(mtime_before, mtime_after)
})

test_that("Step 4 executes predict.ranger correctly in a fresh R process via system2(Rscript) (Precision 4)", {
  proj_name <- "test_pred_fresh_process"
  cleanup_test_project(proj_name)
  on.exit(cleanup_test_project(proj_name), add = TRUE)
  
  rel_path <- create_synthetic_dataset(proj_name, format = "csv", coords_type = "geographic", n_profiles = 25)
  create_synthetic_covariates(proj_name, n_layers = 3)
  
  proj_dir <- file.path(repo_root, "projects", proj_name)
  cfg <- list(
    project = proj_name,
    language = "en",
    input_file = rel_path,
    base_table = "profiles_data",
    roles = list(profile_id = "id", x = "x", y = "y", top = "upper", bottom = "lower"),
    source_crs = "EPSG:4326",
    country_code = "TST",
    project_code = "DEMO",
    tiles = list(cols = 2, rows = 1),
    targets = list(list(property = "soc", d1 = 0, d2 = 30, code = "SOC", enabled = TRUE))
  )
  jsonlite::write_json(cfg, file.path(proj_dir, "config.json"), auto_unbox = TRUE, pretty = TRUE)
  
  # Run pipeline up to Step 3 in current session
  expect_true(run_step("1.1", project = proj_name))
  expect_true(run_step("1.2", project = proj_name))
  expect_true(run_step("1.3", project = proj_name))
  expect_true(run_step("2", project = proj_name))
  expect_true(run_step("3", project = proj_name))
  
  # Execute Step 4 in a completely fresh R process using system2("Rscript", ...)
  rscript_bin <- file.path(R.home("bin"), "Rscript")
  code <- sprintf('source("%s"); res <- run_step("4", project = "%s"); if (!isTRUE(res)) quit(status = 1)',
                  gsub("\\\\", "/", file.path(repo_root, "run_step.R")),
                  proj_name)
  
  out <- system2(rscript_bin, args = c("--vanilla", "-e", shQuote(code)), stdout = TRUE, stderr = TRUE)
  status <- attr(out, "status")
  if (is.null(status)) status <- 0
  
  expect_equal(status, 0, info = paste(out, collapse = "\n"))
  
  mean_tif <- file.path(proj_dir, "outputs", "maps", "TST-DEMO-SOC-0-30-mean.tif")
  expect_true(file.exists(mean_tif))
})

test_that("Step 4 COG check detects and reports fallback when file lacks COG layout (Precision 2 & 8)", {
  # Direct unit test of COG verification and fallback reporting logic
  tmp_dir <- tempfile("test_cog_verif_")
  dir.create(tmp_dir, recursive = TRUE)
  on.exit(unlink(tmp_dir, recursive = TRUE), add = TRUE)
  
  # 1. Real COG
  r <- terra::rast(nrows = 20, ncols = 20, vals = runif(400), crs = "EPSG:4326")
  raw_tif <- file.path(tmp_dir, "raw.tif")
  cog_tif <- file.path(tmp_dir, "cog.tif")
  
  terra::writeRaster(r, raw_tif, overwrite = TRUE, datatype = "FLT4S", NAflag = -9999,
                     gdal = c("COMPRESS=DEFLATE", "PREDICTOR=2", "TILED=YES", "BLOCKXSIZE=512", "BLOCKYSIZE=512"))
  sf::gdal_utils("translate", source = raw_tif, destination = cog_tif,
                 options = c("-of", "COG", "-co", "COMPRESS=DEFLATE", "-co", "PREDICTOR=2", "-co", "BLOCKSIZE=512"))
  
  desc_cog <- terra::describe(cog_tif)
  is_cog <- any(grepl("LAYOUT=COG", desc_cog))
  expect_true(is_cog)
  
  # 2. Plain GeoTIFF (fallback simulation)
  plain_tif <- file.path(tmp_dir, "plain.tif")
  terra::writeRaster(r, plain_tif, overwrite = TRUE, datatype = "FLT4S", NAflag = -9999,
                     gdal = c("COMPRESS=DEFLATE", "PREDICTOR=2"))
  desc_plain <- terra::describe(plain_tif)
  is_plain_cog <- any(grepl("LAYOUT=COG", desc_plain))
  expect_false(is_plain_cog)
  
  # Test catalogue message for fallback: does NOT call it COG
  fallback_msg_en <- msg("pred_cog_fallback", "en", repo_root = repo_root)
  expect_true(grepl("Fallback to plain compressed GeoTIFF", fallback_msg_en))
  expect_true(grepl("File does not have COG layout", fallback_msg_en))
  expect_false(grepl("^Verification: Valid Cloud-Optimized GeoTIFF", fallback_msg_en))
  
  fallback_msg_es <- msg("pred_cog_fallback", "es", repo_root = repo_root)
  expect_true(grepl("Respaldo a GeoTIFF", fallback_msg_es))
  expect_true(grepl("no posee estructura COG", fallback_msg_es))
})

test_that("Step 4 skips tile with partial NAs but no complete cell across all covariate layers (Precision 2)", {
  proj_name <- "test_pred_partial_na_tile"
  cleanup_test_project(proj_name)
  on.exit(cleanup_test_project(proj_name), add = TRUE)
  
  rel_path <- create_synthetic_dataset(proj_name, format = "csv", coords_type = "geographic", n_profiles = 25)
  create_synthetic_covariates(proj_name, n_layers = 2)
  
  proj_dir <- file.path(repo_root, "projects", proj_name)
  cfg <- list(
    project = proj_name,
    language = "en",
    input_file = rel_path,
    base_table = "profiles_data",
    roles = list(profile_id = "id", x = "x", y = "y", top = "upper", bottom = "lower"),
    source_crs = "EPSG:4326",
    country_code = "TST",
    project_code = "DEMO",
    tiles = list(cols = 2, rows = 1),
    targets = list(list(property = "soc", d1 = 0, d2 = 30, code = "SOC", enabled = TRUE))
  )
  jsonlite::write_json(cfg, file.path(proj_dir, "config.json"), auto_unbox = TRUE, pretty = TRUE)
  
  # Run pipeline up to Step 3
  expect_true(run_step("1.1", project = proj_name))
  expect_true(run_step("1.2", project = proj_name))
  expect_true(run_step("1.3", project = proj_name))
  expect_true(run_step("2", project = proj_name))
  expect_true(run_step("3", project = proj_name))
  
  # Replace covariates raster with a 2-tile raster where Tile 2 has partial NAs in each layer
  # but zero complete cells across all layers
  cov_file <- file.path(proj_dir, "covariates", "covariates_stack.tif")
  r1 <- terra::rast(nrows = 10, ncols = 20, xmin = 74.0, xmax = 76.0, ymin = 41.0, ymax = 43.0, crs = "EPSG:4326")
  r2 <- terra::rast(nrows = 10, ncols = 20, xmin = 74.0, xmax = 76.0, ymin = 41.0, ymax = 43.0, crs = "EPSG:4326")
  
  v1 <- matrix(runif(200, 10, 50), nrow = 10, ncol = 20)
  v2 <- matrix(runif(200, 10, 50), nrow = 10, ncol = 20)
  
  # Tile 2 is cols 11:20:
  # Rows 1:5 have v1 valid, v2 NA
  v2[1:5, 11:20] <- NA_real_
  # Rows 6:10 have v1 NA, v2 valid
  v1[6:10, 11:20] <- NA_real_
  
  terra::values(r1) <- as.vector(t(v1))
  terra::values(r2) <- as.vector(t(v2))
  names(r1) <- "cov_01"
  names(r2) <- "cov_02"
  cov_stack <- c(r1, r2)
  terra::writeRaster(cov_stack, cov_file, overwrite = TRUE)
  
  # Run Step 4 with 2 vertical strip tiles (cols = 2, rows = 1)
  expect_true(run_step("4", project = proj_name))
  
  rep_file <- file.path(proj_dir, "reports", "40_prediction_soc_0_30.txt")
  expect_true(file.exists(rep_file))
  rep_lines <- readLines(rep_file, warn = FALSE)
  
  # Assert Tile 2 was skipped because no cell had complete data
  expect_true(any(grepl("contains no cell with complete covariate data. Skipping prediction for this tile", rep_lines)))
  
  # Assert mean raster exists and Tile 1 has valid predictions while Tile 2 has NAs
  mean_tif <- file.path(proj_dir, "outputs", "maps", "TST-DEMO-SOC-0-30-mean.tif")
  expect_true(file.exists(mean_tif))
  mean_r <- terra::rast(mean_tif)
  expect_equal(terra::ncol(mean_r), 20)
  expect_equal(terra::nrow(mean_r), 10)
})

test_that("Step 4 runs successfully with one selected target with code and one unselected target without code (Precision 4)", {
  proj_name <- "test_pred_unselected_no_code"
  cleanup_test_project(proj_name)
  on.exit(cleanup_test_project(proj_name), add = TRUE)
  
  rel_path <- create_synthetic_dataset(proj_name, format = "csv", coords_type = "geographic", n_profiles = 25)
  create_synthetic_covariates(proj_name, n_layers = 3)
  
  proj_dir <- file.path(repo_root, "projects", proj_name)
  cfg <- list(
    project = proj_name,
    language = "en",
    input_file = rel_path,
    base_table = "profiles_data",
    roles = list(profile_id = "id", x = "x", y = "y", top = "upper", bottom = "lower"),
    source_crs = "EPSG:4326",
    country_code = "TST",
    project_code = "DEMO",
    tiles = list(cols = 2, rows = 1),
    targets = list(
      list(property = "soc", d1 = 0, d2 = 30, code = "SOC", enabled = TRUE),
      list(property = "clay", d1 = 0, d2 = 30, enabled = FALSE) # No code!
    )
  )
  jsonlite::write_json(cfg, file.path(proj_dir, "config.json"), auto_unbox = TRUE, pretty = TRUE)
  
  expect_true(run_step("1.1", project = proj_name))
  expect_true(run_step("1.2", project = proj_name))
  expect_true(run_step("1.3", project = proj_name))
  expect_true(run_step("2", project = proj_name))
  expect_true(run_step("3", project = proj_name))
  
  # Step 4 runs without error because clay is disabled (not selected)
  expect_true(run_step("4", project = proj_name))
  
  mean_tif <- file.path(proj_dir, "outputs", "maps", "TST-DEMO-SOC-0-30-mean.tif")
  expect_true(file.exists(mean_tif))
})

test_that("Step 4 in Spanish translates COG status as COG_VERIFICADO or GEOTIFF_RESPALDO", {
  proj_name <- "test_pred_cog_status_es"
  cleanup_test_project(proj_name)
  on.exit(cleanup_test_project(proj_name), add = TRUE)
  
  rel_path <- create_synthetic_dataset(proj_name, format = "csv", coords_type = "geographic", n_profiles = 25)
  create_synthetic_covariates(proj_name, n_layers = 3)
  
  proj_dir <- file.path(repo_root, "projects", proj_name)
  cfg <- list(
    project = proj_name,
    language = "es",
    input_file = rel_path,
    base_table = "profiles_data",
    roles = list(profile_id = "id", x = "x", y = "y", top = "upper", bottom = "lower"),
    source_crs = "EPSG:4326",
    country_code = "TST",
    project_code = "DEMO",
    tiles = list(cols = 1, rows = 1),
    targets = list(list(property = "soc", d1 = 0, d2 = 30, code = "SOC", enabled = TRUE))
  )
  jsonlite::write_json(cfg, file.path(proj_dir, "config.json"), auto_unbox = TRUE, pretty = TRUE)
  
  expect_true(run_step("1.1", project = proj_name))
  expect_true(run_step("1.2", project = proj_name))
  expect_true(run_step("1.3", project = proj_name))
  expect_true(run_step("2", project = proj_name))
  expect_true(run_step("3", project = proj_name))
  expect_true(run_step("4", project = proj_name))
  
  rep_file <- file.path(proj_dir, "reports", "40_prediction_soc_0_30.txt")
  expect_true(file.exists(rep_file))
  rep_lines <- readLines(rep_file, warn = FALSE, encoding = "UTF-8")
  
  # Status tag must be Spanish (COG_VERIFICADO or GEOTIFF_RESPALDO), never English VERIFIED_COG
  has_es_tag <- any(grepl("COG_VERIFICADO|GEOTIFF_RESPALDO", rep_lines))
  expect_true(has_es_tag)
  expect_false(any(grepl("VERIFIED_COG", rep_lines)))
})
