test_that("Session isolation: running 1.3 then 1.2 in same session works and reads 01_mapped.csv", {
  proj_iso <- "test_isolation"
  cleanup_test_project(proj_iso)
  on.exit(cleanup_test_project(proj_iso), add = TRUE)
  
  create_synthetic_dataset(proj_iso, format = "csv", coords_type = "geographic", n_profiles = 20)
  
  cfg <- list(
    language = "en",
    project = proj_iso,
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
    source_crs = "EPSG:4326",
    impute_bulk_density = FALSE
  )
  jsonlite::write_json(cfg, file.path(repo_root, "projects", proj_iso, "config.json"), auto_unbox = TRUE, pretty = TRUE)
  
  # Step 1.1 creates 01_mapped.csv
  expect_true(run_step("1.1", project = proj_iso))
  # Step 1.2 creates 02_spatial.csv
  expect_true(run_step("1.2", project = proj_iso))
  # Step 1.3 creates 03_clean.csv
  expect_true(run_step("1.3", project = proj_iso))
  
  # Now immediately run 1.2 again in the exact same session!
  res_re_12 <- run_step("1.2", project = proj_iso)
  expect_true(res_re_12)
  
  # Verify 12_spatial.txt confirms reading data/01_mapped.csv
  spatial_rep <- file.path(repo_root, "projects", proj_iso, "reports", "12_spatial.txt")
  rep_lines <- readLines(spatial_rep)
  expect_true(any(grepl("Input File: data/01_mapped\\.csv", rep_lines)))
})
