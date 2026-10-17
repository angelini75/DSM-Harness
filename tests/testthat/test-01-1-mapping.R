test_that("Step 1.1 handles duplicate keys according to strategy", {
  # Case 1: Duplicate keys and missing strategy -> stops / returns FALSE
  proj_dup_none <- "test_dup_none"
  cleanup_test_project(proj_dup_none)
  on.exit(cleanup_test_project(proj_dup_none), add = TRUE)
  
  create_synthetic_dataset(proj_dup_none, format = "excel", dup_keys = TRUE)
  
  # Config with NO duplicate strategy
  cfg_no_strat <- list(
    language = "en",
    project = proj_dup_none,
    input_file = "data/profiles_data.xlsx",
    sheets = list("profiles", "horizons"),
    base_table = "horizons",
    joins = list(
      list(
        table = "profiles",
        by = list(id = "id")
      )
    ),
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
    )
  )
  jsonlite::write_json(cfg_no_strat, file.path(repo_root, "projects", proj_dup_none, "config.json"), auto_unbox = TRUE, pretty = TRUE)
  
  res_no_strat <- run_step("1.1", project = proj_dup_none)
  expect_false(res_no_strat)
  expect_false(file.exists(file.path(repo_root, "projects", proj_dup_none, "data", "01_mapped.csv")))
  
  # Case 2: Duplicate keys with strategy 'average' -> succeeds, no row growth
  proj_dup_avg <- "test_dup_avg"
  cleanup_test_project(proj_dup_avg)
  on.exit(cleanup_test_project(proj_dup_avg), add = TRUE)
  
  create_synthetic_dataset(proj_dup_avg, format = "excel", dup_keys = TRUE, n_profiles = 20)
  
  cfg_avg <- cfg_no_strat
  cfg_avg$project <- proj_dup_avg
  cfg_avg$duplicate_key_strategy <- "average"
  cfg_avg$excluded_categories <- list("other")
  
  jsonlite::write_json(cfg_avg, file.path(repo_root, "projects", proj_dup_avg, "config.json"), auto_unbox = TRUE, pretty = TRUE)
  
  res_avg <- run_step("1.1", project = proj_dup_avg)
  expect_true(res_avg)
  
  mapped_file <- file.path(repo_root, "projects", proj_dup_avg, "data", "01_mapped.csv")
  expect_true(file.exists(mapped_file))
  
  df_mapped <- readr::read_csv(mapped_file, show_col_types = FALSE)
  # Total horizons = 20 profiles * 2 = 40 rows. No row growth should occur!
  expect_equal(nrow(df_mapped), 40)
  # Excluded category "other" -> elevation should not be present
  expect_false("elevation" %in% names(df_mapped))
  # Role columns must be present
  expect_true(all(c("id", "x", "y", "upper", "lower", "soc", "bd") %in% names(df_mapped)))
})
