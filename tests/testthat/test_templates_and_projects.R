library(testthat)

if (basename(getwd()) == "testthat") setwd("../..")
if (basename(getwd()) == "tests") setwd("..")

r_cmd <- file.path(R.home("bin"), if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript")
if (!file.exists(r_cmd)) r_cmd <- Sys.which("Rscript")

test_that("Master templates exist, parse cleanly and declare TEMPLATE_VERSION 2.0.0", {
  scripts <- c("00_inspect_data.R", "01_1_byod_audit.R", "01_2_byod_audit.R", "01_3_byod_audit.R")
  for (s in scripts) {
    p <- file.path("02_scripts", s)
    expect_true(file.exists(p), info = paste("Script exists:", s))
    
    parsed <- tryCatch(parse(p), error = function(e) e)
    expect_false(inherits(parsed, "error"), info = paste("Valid syntax:", s))
    
    if (s %in% c("01_1_byod_audit.R", "01_2_byod_audit.R", "01_3_byod_audit.R")) {
      lines <- readLines(p, encoding = "UTF-8")
      expect_true(any(grepl('TEMPLATE_VERSION <- "2.0.0"', lines, fixed = TRUE)),
                  info = paste("Declares TEMPLATE_VERSION 2.0.0:", s))
      expect_true(any(grepl(">>> ADAPT:", lines)), info = paste("Contains ADAPT tags:", s))
    }
  }
})

test_that("Step 0 inspection generates ultra-compact report (<= 8 KB)", {
  test_csv <- "01_data/profiles/test_inspect_size.csv"
  # Crear dataset sintético con múltiples columnas
  df_synth <- data.frame(
    id_perfil = paste0("P", 1:50),
    x_coord = runif(50, -60, -58),
    y_coord = runif(50, -35, -33),
    prof_desde = 0,
    prof_hasta = 30,
    carbono_org = runif(50, 0.5, 3.5),
    ph_suelo = runif(50, 5.5, 7.5),
    arcilla_pct = runif(50, 15, 35),
    arena_pct = runif(50, 40, 60),
    limo_pct = runif(50, 10, 30)
  )
  write.csv(df_synth, test_csv, row.names = FALSE)
  on.exit(unlink(test_csv), add = TRUE)
  
  rep_file <- "01_data/profiles/data_inspection_report.txt"
  if (file.exists(rep_file)) unlink(rep_file)
  
  input_file <<- test_csv
  output_report <<- rep_file
  source("02_scripts/00_inspect_data.R", local = new.env())
  
  expect_true(file.exists(rep_file))
  rep_size_kb <- file.size(rep_file) / 1024
  expect_true(rep_size_kb <= 8, info = sprintf("Report size (%.1f KB) is <= 8 KB", rep_size_kb))
})

test_that("Step 1.1 fails fast when essential variables are missing and allow_missing_essentials is false", {
  test_csv <- "01_data/profiles/test_missing_essentials.csv"
  write.csv(data.frame(soc = 1:5, ph = 6:10, clay = 11:15), test_csv, row.names = FALSE)
  test_out_csv <- "01_data/profiles/step1_1_variables.csv"
  if (file.exists(test_out_csv)) unlink(test_out_csv)
  
  on.exit({
    unlink(test_csv)
    if (file.exists(test_out_csv)) unlink(test_out_csv)
  }, add = TRUE)
  
  input_file <<- test_csv
  err <- tryCatch(
    source("02_scripts/01_1_byod_audit.R", local = new.env()),
    error = function(e) e$message
  )
  
  expect_true(grepl("Variables esenciales ausentes", err), info = "Fails fast when essentials missing")
  expect_false(file.exists(test_out_csv), info = "Does not write output CSV on essential failure")
})

test_that("Step 1.1 fails fast when dataset has 0 mapped variables", {
  test_csv <- "01_data/profiles/test_zero_mapped.csv"
  write.csv(data.frame(foo_a = 1:5, foo_b = 6:10), test_csv, row.names = FALSE)
  test_out_csv <- "01_data/profiles/step1_1_variables.csv"
  if (file.exists(test_out_csv)) unlink(test_out_csv)
  
  on.exit({
    unlink(test_csv)
    if (file.exists(test_out_csv)) unlink(test_out_csv)
  }, add = TRUE)
  
  input_file <<- test_csv
  err <- tryCatch(
    source("02_scripts/01_1_byod_audit.R", local = new.env()),
    error = function(e) e$message
  )
  
  expect_true(grepl("No hay variables DSM identificadas", err), info = "Fails fast on 0 mapped variables")
  expect_false(file.exists(test_out_csv), info = "Does not write output CSV on 0 variables failure")
})

test_that("Step 1.1 computes sand_sum correctly and carries into mapping", {
  test_csv <- "01_data/profiles/test_sand_sum.csv"
  cfg_json <- "01_data/profiles/user_config.json"
  
  df_sand <- data.frame(
    id_sitio = paste0("P", 1:5),
    x = -60, y = -34,
    prof_ini = 0, prof_fin = 20,
    arena_muy_fina = c(5, 10, 15, 20, 25),
    arena_media    = c(20, 20, 20, 20, 20),
    arena_gruesa   = c(10, 10, 10, 10, 10)
  )
  write.csv(df_sand, test_csv, row.names = FALSE)
  on.exit({
    unlink(test_csv)
    if (file.exists(cfg_json)) unlink(cfg_json)
    if (file.exists("01_data/profiles/step1_1_variables.csv")) unlink("01_data/profiles/step1_1_variables.csv")
    if (file.exists("01_data/profiles/step1_1_variables_report.txt")) unlink("01_data/profiles/step1_1_variables_report.txt")
  }, add = TRUE)
  
  cfg <- list(
    input_file = test_csv,
    sand_sum = list("arena_muy_fina", "arena_media", "arena_gruesa"),
    column_mapping = list(
      profile_code = "id_sitio",
      longitude = "x", latitude = "y",
      upper = "prof_ini", lower = "prof_fin"
    )
  )
  jsonlite::write_json(cfg, cfg_json, auto_unbox = TRUE)
  
  input_file <<- test_csv
  source("02_scripts/01_1_byod_audit.R", local = new.env())
  
  res_csv <- read.csv("01_data/profiles/step1_1_variables.csv")
  expect_true("Sand" %in% names(res_csv))
  expect_equal(res_csv$Sand, c(35, 40, 45, 50, 55))
})

test_that("Step 1.2 detects spatial isolation outliers via nearest-neighbor (k-NN)", {
  test_csv <- "01_data/profiles/step1_1_variables.csv"
  
  # 15 puntos en un cluster compacto (-60, -34) y 1 punto aislado a 500 km (-55, -30)
  set.seed(42)
  pts_cluster <- data.frame(
    profile_code = paste0("P", 1:15),
    longitude = rnorm(15, mean = -60.0, sd = 0.05),
    latitude  = rnorm(15, mean = -34.0, sd = 0.05),
    upper = 0, lower = 20
  )
  pt_isolated <- data.frame(
    profile_code = "P_ISOLATED",
    longitude = -55.0,
    latitude  = -30.0,
    upper = 0, lower = 20
  )
  write.csv(rbind(pts_cluster, pt_isolated), test_csv, row.names = FALSE)
  on.exit({
    unlink(test_csv)
    if (file.exists("01_data/profiles/step1_2_spatial.csv")) unlink("01_data/profiles/step1_2_spatial.csv")
    if (file.exists("01_data/profiles/step1_2_spatial_report.txt")) unlink("01_data/profiles/step1_2_spatial_report.txt")
  }, add = TRUE)
  
  source("02_scripts/01_2_byod_audit.R", local = new.env())
  
  out_csv <- read.csv("01_data/profiles/step1_2_spatial.csv")
  expect_true("flag_spatial_outlier" %in% names(out_csv))
  
  # El punto aislado debe estar marcado
  isol_row <- out_csv[out_csv$profile_code == "P_ISOLATED", ]
  expect_true(isol_row$flag_spatial_outlier)
})

test_that("00_new_project.R instantiates isolated project with updated decisions_log structure", {
  test_proj <- "test_unit_project_v2"
  proj_path <- file.path("projects", test_proj)
  on.exit(unlink(proj_path, recursive = TRUE), add = TRUE)
  
  project_name <<- test_proj
  source("02_scripts/00_new_project.R", local = new.env())
  
  expect_true(dir.exists(proj_path))
  expect_true(file.exists(file.path(proj_path, "decisions_log.csv")))
  expect_true(file.exists(file.path(proj_path, "run_step.R")))
  
  log_lines <- readLines(file.path(proj_path, "decisions_log.csv"))
  expect_true(grepl("run_id", log_lines[1]))
  expect_true(grepl("template_version", log_lines[1]))
})

test_that("00_audit_diff.R identifies intact vs adapted project scripts", {
  test_proj <- "test_diff_project_v2"
  proj_path <- file.path("projects", test_proj)
  on.exit(unlink(proj_path, recursive = TRUE), add = TRUE)
  
  project_name <<- test_proj
  source("02_scripts/00_new_project.R", local = new.env())
  
  res_intact <- capture.output({
    project_name <<- test_proj
    source("02_scripts/00_audit_diff.R", local = new.env())
  })
  expect_true(any(grepl("\\[INTACTO\\].*01_1_byod_audit.R", res_intact)))
  
  step1_path <- file.path(proj_path, "scripts", "01_1_byod_audit.R")
  lines <- readLines(step1_path, encoding = "UTF-8")
  tag_idx <- grep(">>> ADAPT:column_mapping", lines)
  lines[tag_idx + 1] <- paste0("# Parche adaptado\n", lines[tag_idx + 1])
  writeLines(lines, step1_path)
  
  res_adapted <- capture.output({
    project_name <<- test_proj
    source("02_scripts/00_audit_diff.R", local = new.env())
  })
  expect_true(any(grepl("\\[ADAPTADO\\].*01_1_byod_audit.R", res_adapted)))
})
