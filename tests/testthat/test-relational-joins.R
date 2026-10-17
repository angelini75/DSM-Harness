test_that("Relational joins: three horizon tables, shared column names, duplicate key in horizon, no .x/.y suffixes, and end-to-end 0 -> 1.3", {
  proj_rel <- "test_relational_full"
  cleanup_test_project(proj_rel)
  on.exit(cleanup_test_project(proj_rel), add = TRUE)
  
  new_project(proj_rel, language = "es", repo_root = repo_root)
  pdir <- file.path(repo_root, "projects", proj_rel)
  data_dir <- file.path(pdir, "data")
  
  # 1. Generate multi-sheet relational dataset
  n_profiles <- 20
  prof_ids <- sprintf("PRF_%03d", seq_len(n_profiles))
  
  # Profiles table (site level)
  df_profiles <- data.frame(
    site_code = prof_ids, # Differently named key!
    x = seq(450000, 460000, length.out = n_profiles),
    y = seq(4600000, 4610000, length.out = n_profiles),
    elevation = seq(1200, 1800, length.out = n_profiles),
    stringsAsFactors = FALSE
  )
  
  # Horizon table 1: Chemistry (base table)
  horiz_chem_list <- list()
  for (i in seq_len(n_profiles)) {
    pid <- prof_ids[i]
    horiz_chem_list[[length(horiz_chem_list) + 1]] <- data.frame(
      profile_id = pid, layer_id = 1, upper = 0, lower = 30,
      soc = round(runif(1, 1.5, 3.5), 2), ph = 7.1, method = "Walkley-Black",
      stringsAsFactors = FALSE
    )
    horiz_chem_list[[length(horiz_chem_list) + 1]] <- data.frame(
      profile_id = pid, layer_id = 2, upper = 30, lower = 60,
      soc = round(runif(1, 0.5, 1.8), 2), ph = 7.4, method = "Walkley-Black",
      stringsAsFactors = FALSE
    )
  }
  df_horiz_chem <- do.call(rbind, horiz_chem_list)
  
  # Horizon table 2: Physics (has shared columns: upper, lower, method)
  # WITH DUPLICATE KEY in incoming horizon table to test duplicate resolution!
  horiz_phys_list <- list()
  for (i in seq_len(n_profiles)) {
    pid <- prof_ids[i]
    horiz_phys_list[[length(horiz_phys_list) + 1]] <- data.frame(
      profile_id = pid, layer_id = 1, upper = 0, lower = 30,
      clay = 28, sand = 42, silt = 30, method = "Hydrometer",
      stringsAsFactors = FALSE
    )
    horiz_phys_list[[length(horiz_phys_list) + 1]] <- data.frame(
      profile_id = pid, layer_id = 2, upper = 30, lower = 60,
      clay = 35, sand = 35, silt = 30, method = "Hydrometer",
      stringsAsFactors = FALSE
    )
  }
  df_horiz_phys <- do.call(rbind, horiz_phys_list)
  # Inject duplicate row into horizons_phys
  dup_row_phys <- df_horiz_phys[1, , drop = FALSE]
  dup_row_phys$clay <- 30 # slightly different value to verify averaging
  df_horiz_phys <- rbind(df_horiz_phys, dup_row_phys)
  
  # Inject non-numeric character strings in clay to test NA coercion reporting
  df_horiz_phys$clay <- as.character(df_horiz_phys$clay)
  df_horiz_phys$clay[2] <- "<0.01"
  df_horiz_phys$clay[3] <- "trace"
  
  # Horizon table 3: Density (has shared column: method)
  horiz_dens_list <- list()
  for (i in seq_len(n_profiles)) {
    pid <- prof_ids[i]
    horiz_dens_list[[length(horiz_dens_list) + 1]] <- data.frame(
      profile_id = pid, layer_id = 1, bd = round(runif(1, 1.1, 1.4), 2), method = "Core",
      stringsAsFactors = FALSE
    )
    horiz_dens_list[[length(horiz_dens_list) + 1]] <- data.frame(
      profile_id = pid, layer_id = 2, bd = round(runif(1, 1.3, 1.6), 2), method = "Core",
      stringsAsFactors = FALSE
    )
  }
  df_horiz_dens <- do.call(rbind, horiz_dens_list)
  
  excel_file <- file.path(data_dir, "soil_survey.xlsx")
  writexl::write_xlsx(
    list(
      horizons_chem = df_horiz_chem,
      horizons_phys = df_horiz_phys,
      horizons_density = df_horiz_dens,
      profiles = df_profiles
    ),
    path = excel_file
  )
  
  # 2. Run Step 0 on this multi-sheet Excel file
  res_step0 <- run_step("0", project = proj_rel)
  expect_true(res_step0)
  rep0 <- file.path(pdir, "reports", "00_inspection.txt")
  expect_true(file.exists(rep0))
  rep0_txt <- readLines(rep0)
  expect_true(any(grepl("horizons_chem", rep0_txt)))
  expect_true(any(grepl("horizons_phys", rep0_txt)))
  expect_true(any(grepl("horizons_density", rep0_txt)))
  expect_true(any(grepl("profiles", rep0_txt)))
  
  # 3. Test Step 1.1 with missing duplicate key strategy -> must stop
  cfg_no_strat <- list(
    project = proj_rel,
    language = "es",
    input_file = "data/soil_survey.xlsx",
    base_table = "horizons_chem",
    joins = list(
      list(
        table = "profiles",
        by = list(profile_id = "site_code")
      ),
      list(
        table = "horizons_phys",
        by = list(profile_id = "profile_id", layer_id = "layer_id")
      ),
      list(
        table = "horizons_density",
        by = list(profile_id = "profile_id", layer_id = "layer_id")
      )
    ),
    roles = list(
      profile_id = "profile_id",
      x = "x",
      y = "y",
      top = "horizons_chem.upper",
      bottom = "horizons_chem.lower",
      bulk_density = "bd",
      organic_carbon = "soc"
    ),
    categories = list(
      profile_id = "identification",
      x = "location",
      y = "location",
      "horizons_chem.upper" = "depth",
      "horizons_chem.lower" = "depth",
      soc = "organic matter and density",
      bd = "organic matter and density",
      clay = "texture",
      sand = "texture",
      silt = "texture",
      ph = "chemistry",
      elevation = "other"
    )
  )
  jsonlite::write_json(cfg_no_strat, file.path(pdir, "config.json"), auto_unbox = TRUE, pretty = TRUE)
  
  res_no_strat <- run_step("1.1", project = proj_rel)
  expect_false(res_no_strat)
  
  # Verify error report was written with traceback (11_error.txt)
  err_file_11 <- file.path(pdir, "reports", "11_error.txt")
  expect_true(file.exists(err_file_11))
  err_lines <- readLines(err_file_11)
  expect_true(any(grepl("TRACEBACK", err_lines)))
  
  # 3b. Test ambiguous bare role column after collision (top = "upper" matches both chem.upper and phys.upper)
  cfg_ambig <- cfg_no_strat
  cfg_ambig$duplicate_key_strategy <- "average"
  cfg_ambig$roles$top <- "upper"
  jsonlite::write_json(cfg_ambig, file.path(pdir, "config.json"), auto_unbox = TRUE, pretty = TRUE)
  res_ambig <- run_step("1.1", project = proj_rel)
  expect_false(res_ambig)
  err_lines <- readLines(err_file_11)
  expect_true(any(grepl("horizons_chem\\.upper", err_lines)))
  
  # 4. Now configure strategy 'average' with qualified role and run 1.1
  cfg_valid <- cfg_no_strat
  cfg_valid$duplicate_key_strategy <- "average"
  cfg_valid$roles$top <- "horizons_chem.upper"
  cfg_valid$roles$bottom <- "horizons_chem.lower"
  cfg_valid$source_crs <- "EPSG:32642"
  cfg_valid$impute_bulk_density <- TRUE
  jsonlite::write_json(cfg_valid, file.path(pdir, "config.json"), auto_unbox = TRUE, pretty = TRUE)
  
  res_step11 <- run_step("1.1", project = proj_rel)
  expect_true(res_step11)
  
  # Verify 11_mapping.txt recorded the resolved roles
  map_txt <- readLines(file.path(pdir, "reports", "11_mapping.txt"))
  expect_true(any(grepl("horizons_chem\\.upper", map_txt)))
  
  mapped_csv <- file.path(data_dir, "01_mapped.csv")
  expect_true(file.exists(mapped_csv))
  df_mapped <- readr::read_csv(mapped_csv, show_col_types = FALSE)
  
  # Exact row count: 20 profiles * 2 = 40 rows. No row multiplication!
  expect_equal(nrow(df_mapped), 40)
  
  # Crucial check: NO .x or .y suffixes in column names
  col_names <- names(df_mapped)
  expect_false(any(grepl("\\.x$|\\.y$", col_names)))
  
  # Check collision resolution for 'method'
  expect_true(any(grepl("horizons_chem\\.method", col_names)))
  expect_true(any(grepl("horizons_phys\\.method", col_names)))
  expect_true(any(grepl("horizons_density\\.method", col_names)))
  
  # 4b. Test Step 1.2 without CRS: returns TRUE, reports pending, does NOT write 02_spatial.csv
  cfg_no_crs <- cfg_valid
  cfg_no_crs$source_crs <- NULL
  jsonlite::write_json(cfg_no_crs, file.path(pdir, "config.json"), auto_unbox = TRUE, pretty = TRUE)
  spatial_csv <- file.path(data_dir, "02_spatial.csv")
  if (file.exists(spatial_csv)) file.remove(spatial_csv)
  
  res_no_crs <- run_step("1.2", project = proj_rel)
  expect_true(res_no_crs)
  expect_false(file.exists(spatial_csv))
  
  # 5. Restore source_crs and run Step 1.2 (spatial reprojection to EPSG:4326)
  jsonlite::write_json(cfg_valid, file.path(pdir, "config.json"), auto_unbox = TRUE, pretty = TRUE)
  res_step12 <- run_step("1.2", project = proj_rel)
  expect_true(res_step12)
  expect_true(file.exists(spatial_csv))
  df_spatial <- readr::read_csv(spatial_csv, show_col_types = FALSE)
  expect_true(all(df_spatial$x >= -180 & df_spatial$x <= 180))
  expect_true(all(df_spatial$y >= -90 & df_spatial$y <= 90))
  
  rep12_txt <- readLines(file.path(pdir, "reports", "12_spatial.txt"))
  expect_false(any(grepl("EPSG:EPSG:", rep12_txt)))
  
  # 6. Run Step 1.3 (pedological audit & bulk density modeling)
  res_step13 <- run_step("1.3", project = proj_rel)
  expect_true(res_step13)
  clean_csv <- file.path(data_dir, "03_clean.csv")
  expect_true(file.exists(clean_csv))
  df_clean <- readr::read_csv(clean_csv, show_col_types = FALSE)
  expect_equal(nrow(df_clean), 40)
  expect_true("bd_imputed" %in% names(df_clean))
  expect_true(is.numeric(df_clean$clay))
  
  # Verify NA coercion was reported in 13_pedological.txt
  rep13_txt <- readLines(file.path(pdir, "reports", "13_pedological.txt"))
  expect_true(any(grepl("Valores no numéricos convertidos a NA", rep13_txt)))
  expect_false(any(grepl("\\(Exponential\\)", rep13_txt)))
  
  # Check reports exist
  expect_true(file.exists(file.path(pdir, "reports", "11_mapping.txt")))
  expect_true(file.exists(file.path(pdir, "reports", "12_spatial.txt")))
  expect_true(file.exists(file.path(pdir, "reports", "13_pedological.txt")))
})
