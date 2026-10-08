test_that("Step 1.2 spatial audit, out-of-order check, and CRS handling", {
  proj_spatial <- "test_spatial"
  cleanup_test_project(proj_spatial)
  on.exit(cleanup_test_project(proj_spatial), add = TRUE)
  
  create_synthetic_dataset(proj_spatial, format = "csv", coords_type = "projected")
  
  cfg <- list(
    language = "en",
    project = proj_spatial,
    input_file = "data/profiles_data.csv",
    roles = list(
      profile_id = "id",
      x = "x",
      y = "y",
      top = "upper",
      bottom = "lower",
      bulk_density = "bd",
      organic_carbon = "soc"
    ),
    columns = list(
      id = "identification",
      x = "location",
      y = "location",
      upper = "depth",
      lower = "depth",
      clay = "texture",
      sand = "texture",
      silt = "texture",
      soc = "organic matter and density",
      bd = "organic matter and density",
      ph = "chemistry",
      elevation = "other"
    ),
    duplicate_key_strategy = "keep_first",
    source_crs = NULL
  )
  jsonlite::write_json(cfg, file.path(repo_root, "projects", proj_spatial, "config.json"), auto_unbox = TRUE, pretty = TRUE)
  
  # 1. Out-of-order test: Running 1.2 before 1.1
  output_capture <- capture.output({
    res_ooo <- run_step("1.2", project = proj_spatial)
  })
  expect_false(res_ooo)
  # Message must explicitly mention step 1.1
  expect_true(any(grepl("1\\.1", output_capture)))
  
  # 2. Run step 1.1 first
  res_11 <- run_step("1.1", project = proj_spatial)
  expect_true(res_11)
  
  # 3. Run Step 1.2 with empty source_crs
  res_no_crs <- run_step("1.2", project = proj_spatial)
  # Step 1.2 with empty CRS writes report but does NOT write 02_spatial.csv
  spatial_csv <- file.path(repo_root, "projects", proj_spatial, "data", "02_spatial.csv")
  spatial_rep <- file.path(repo_root, "projects", proj_spatial, "reports", "12_spatial.txt")
  
  expect_false(file.exists(spatial_csv))
  expect_true(file.exists(spatial_rep))
  rep_lines <- readLines(spatial_rep)
  expect_true(any(grepl("source_crs", rep_lines)))
  
  # 4. Update config with valid projected CRS and run 1.2
  cfg$source_crs <- "EPSG:32642"
  jsonlite::write_json(cfg, file.path(repo_root, "projects", proj_spatial, "config.json"), auto_unbox = TRUE, pretty = TRUE)
  
  res_with_crs <- run_step("1.2", project = proj_spatial)
  expect_true(res_with_crs)
  expect_true(file.exists(spatial_csv))
  
  df_spatial <- readr::read_csv(spatial_csv, show_col_types = FALSE)
  # Coordinates must now be in geographic range [-180, 180] and [-90, 90]
  expect_true(all(df_spatial$x >= -180 & df_spatial$x <= 180))
  expect_true(all(df_spatial$y >= -90 & df_spatial$y <= 90))
})
