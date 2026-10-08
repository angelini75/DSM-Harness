test_that("Config validator enforces schema, roles, categories, enums, and relative paths", {
  base_valid_cfg <- list(
    language = "en",
    project = "my_project",
    input_file = "data/profiles_data.csv",
    roles = list(
      profile_id = "id",
      x = "x",
      y = "y",
      top = "upper",
      bottom = "lower"
    ),
    columns = list(
      id = "identification",
      x = "location",
      y = "location",
      upper = "depth",
      lower = "depth",
      clay = "texture"
    ),
    duplicate_key_strategy = "average"
  )
  
  # 1. Valid config passes
  v_res <- validate_config(base_valid_cfg, stop_on_error = FALSE, repo_root = repo_root)
  expect_true(v_res$valid)
  expect_equal(length(v_res$errors), 0)
  
  # 2. Unknown top-level key rejected
  cfg_bad_key <- base_valid_cfg
  cfg_bad_key$unknown_property <- "bogus"
  v_bad_key <- validate_config(cfg_bad_key, stop_on_error = FALSE, repo_root = repo_root)
  expect_false(v_bad_key$valid)
  expect_true(any(grepl("unknown_property", v_bad_key$errors)))
  
  # 3. Absolute path for input_file rejected
  cfg_abs_path <- base_valid_cfg
  cfg_abs_path$input_file <- "C:/data/profiles_data.csv"
  v_abs <- validate_config(cfg_abs_path, stop_on_error = FALSE, repo_root = repo_root)
  expect_false(v_abs$valid)
  expect_true(any(grepl("relative", v_abs$errors)))
  
  # 4. Invalid role rejected
  cfg_bad_role <- base_valid_cfg
  cfg_bad_role$roles$invented_role <- "id"
  v_bad_role <- validate_config(cfg_bad_role, stop_on_error = FALSE, repo_root = repo_root)
  expect_false(v_bad_role$valid)
  expect_true(any(grepl("invented_role", v_bad_role$errors)))
  
  # 5. Invalid property category rejected
  cfg_bad_cat <- base_valid_cfg
  cfg_bad_cat$columns$clay <- "magic_category"
  v_bad_cat <- validate_config(cfg_bad_cat, stop_on_error = FALSE, repo_root = repo_root)
  expect_false(v_bad_cat$valid)
  expect_true(any(grepl("magic_category", v_bad_cat$errors)))
  
  # 6. Invalid duplicate_key_strategy rejected
  cfg_bad_enum <- base_valid_cfg
  cfg_bad_enum$duplicate_key_strategy <- "random_drop"
  v_bad_enum <- validate_config(cfg_bad_enum, stop_on_error = FALSE, repo_root = repo_root)
  expect_false(v_bad_enum$valid)
  expect_true(any(grepl("random_drop", v_bad_enum$errors)))
  
  # 7. Missing required role rejected
  cfg_missing_role <- base_valid_cfg
  cfg_missing_role$roles$x <- NULL
  v_miss_role <- validate_config(cfg_missing_role, stop_on_error = FALSE, repo_root = repo_root)
  expect_false(v_miss_role$valid)
  expect_true(any(grepl("roles", v_miss_role$errors)))
  
  # 8. Column not found in dataset rejected
  data_cols <- c("id", "x", "y", "upper", "lower") # 'clay' is missing!
  v_miss_col <- validate_config(base_valid_cfg, data_cols = data_cols, stop_on_error = FALSE, repo_root = repo_root)
  expect_false(v_miss_col$valid)
  expect_true(any(grepl("clay", v_miss_col$errors)))
})
