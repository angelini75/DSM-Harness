test_that("Step 1.3 pedological audit, out-of-order check, and bulk density modeling", {
  proj_ped <- "test_pedological"
  cleanup_test_project(proj_ped)
  on.exit(cleanup_test_project(proj_ped), add = TRUE)
  
  create_synthetic_dataset(proj_ped, format = "csv", coords_type = "geographic", n_profiles = 20)
  
  cfg <- list(
    language = "en",
    project = proj_ped,
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
  jsonlite::write_json(cfg, file.path(repo_root, "projects", proj_ped, "config.json"), auto_unbox = TRUE, pretty = TRUE)
  
  # 1. Out-of-order test: Running 1.3 before 1.2
  output_capture <- capture.output({
    res_ooo <- run_step("1.3", project = proj_ped)
  })
  expect_false(res_ooo)
  expect_true(any(grepl("1\\.2", output_capture)))
  
  # 2. Run steps 1.1 and 1.2
  expect_true(run_step("1.1", project = proj_ped))
  expect_true(run_step("1.2", project = proj_ped))
  
  # 3. Run Step 1.3 without imputation
  res_13_no_imp <- run_step("1.3", project = proj_ped)
  expect_true(res_13_no_imp)
  
  clean_csv <- file.path(repo_root, "projects", proj_ped, "data", "03_clean.csv")
  ped_rep <- file.path(repo_root, "projects", proj_ped, "reports", "13_pedological.txt")
  
  expect_true(file.exists(clean_csv))
  expect_true(file.exists(ped_rep))
  
  rep_text <- readLines(ped_rep)
  # Must contain catalogue contrast
  expect_true(any(grepl("Saini \\(1996\\)", rep_text)))
  # Must contain local fit model (n = 40 >= 30)
  expect_true(any(grepl("Simple local fit", rep_text)))
  
  df_clean_no_imp <- readr::read_csv(clean_csv, show_col_types = FALSE)
  expect_false("bd_imputed" %in% names(df_clean_no_imp))
  
  # 4. Run Step 1.3 with imputation enabled
  cfg$impute_bulk_density <- TRUE
  jsonlite::write_json(cfg, file.path(repo_root, "projects", proj_ped, "config.json"), auto_unbox = TRUE, pretty = TRUE)
  
  res_13_imp <- run_step("1.3", project = proj_ped)
  expect_true(res_13_imp)
  
  df_clean_imp <- readr::read_csv(clean_csv, show_col_types = FALSE)
  expect_true("bd_imputed" %in% names(df_clean_imp))
  expect_true(all(!is.na(df_clean_imp$bd_imputed)))
  # Original measured bulk density column must remain intact!
  expect_true("bd" %in% names(df_clean_imp))
})
