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

test_that("Step 1.2 detects spatial outliers via 3x IQR and documents bounding box limitations", {
  test_csv <- "01_data/profiles/step1_1_variables.csv"
  
  # 20 puntos en un cluster compacto (-60, -34) y 1 punto extremo en el eje X (-50, -34)
  set.seed(42)
  pts_cluster <- data.frame(
    profile_code = paste0("P", 1:20),
    longitude = rnorm(20, mean = -60.0, sd = 0.05),
    latitude  = rnorm(20, mean = -34.0, sd = 0.05),
    upper = 0, lower = 20
  )
  pt_outlier <- data.frame(
    profile_code = "P_OUTLIER",
    longitude = -50.0,
    latitude  = -34.0,
    upper = 0, lower = 20
  )
  write.csv(rbind(pts_cluster, pt_outlier), test_csv, row.names = FALSE)
  on.exit({
    unlink(test_csv)
    if (file.exists("01_data/profiles/step1_2_spatial.csv")) unlink("01_data/profiles/step1_2_spatial.csv")
    if (file.exists("01_data/profiles/step1_2_spatial_report.txt")) unlink("01_data/profiles/step1_2_spatial_report.txt")
  }, add = TRUE)
  
  source("02_scripts/01_2_byod_audit.R", local = new.env())
  
  out_csv <- read.csv("01_data/profiles/step1_2_spatial.csv")
  expect_true("flag_spatial_outlier" %in% names(out_csv))
  
  # El punto extremo por 3x IQR debe estar marcado
  out_row <- out_csv[out_csv$profile_code == "P_OUTLIER", ]
  expect_true(out_row$flag_spatial_outlier)
  
  # El reporte debe advertir de la limitación metodológica del filtro IQR univariado
  rep_lines <- readLines("01_data/profiles/step1_2_spatial_report.txt", encoding = "UTF-8")
  expect_true(any(grepl("IQR 3x", rep_lines, fixed = TRUE)))
  expect_true(any(grepl("caja envolvente", rep_lines, fixed = TRUE)))
})

test_that("Step 1.3 performs multi-PTF competition selection when n >= 5 and omits when n < 5", {
  test_csv <- "01_data/profiles/step1_2_spatial.csv"
  cfg_json <- "01_data/profiles/user_config.json"
  
  on.exit({
    unlink(test_csv)
    if (file.exists(cfg_json)) unlink(cfg_json)
    if (file.exists("01_data/profiles/cleaned_profiles.csv")) unlink("01_data/profiles/cleaned_profiles.csv")
    if (file.exists("01_data/profiles/step1_3_pedological_report.txt")) unlink("01_data/profiles/step1_3_pedological_report.txt")
  }, add = TRUE)
  
  # Caso 1: n >= 5 datos medidos -> competencia y selección automática
  df_val <- data.frame(
    profile_code = paste0("P", 1:12),
    longitude = -60, latitude = -34,
    upper = 0, lower = 20,
    SOC = c(1.5, 2.0, 0.8, 1.2, 3.0, 2.5, 1.1, 1.8, 0.9, 2.2, 1.4, 2.1),
    Sand = c(40, 50, 60, 30, 20, 35, 45, 55, 65, 25, 40, 50),
    Clay = c(20, 15, 10, 30, 40, 25, 18, 12, 8, 35, 22, 16),
    BD = c(1.35, 1.28, 1.45, 1.25, 1.15, 1.22, 1.38, 1.30, NA, NA, NA, NA) # 8 medidos (n >= 5)
  )
  write.csv(df_val, test_csv, row.names = FALSE)
  
  cfg_auto <- list(estimate_bd = TRUE)
  jsonlite::write_json(cfg_auto, cfg_json, auto_unbox = TRUE)
  
  source("02_scripts/01_3_byod_audit.R", local = new.env())
  
  res_csv <- read.csv("01_data/profiles/cleaned_profiles.csv")
  expect_true("BD_est" %in% names(res_csv))
  # Los faltantes (filas 9 a 12) deben tener BD_est imputado
  expect_true(all(!is.na(res_csv$BD_est[9:12])))
  
  rep_lines <- readLines("01_data/profiles/step1_3_pedological_report.txt", encoding = "UTF-8")
  expect_true(any(grepl("TABLA COMPARATIVA DE PTFS EVALUADAS", rep_lines, fixed = TRUE)))
  
  # Caso 2: n < 5 datos medidos sin selected_ptf -> omisión por defecto
  df_noval <- df_val
  df_noval$BD <- c(1.35, 1.28, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA) # solo 2 medidos (n < 5)
  write.csv(df_noval, test_csv, row.names = FALSE)
  
  source("02_scripts/01_3_byod_audit.R", local = new.env())
  
  res_noval <- read.csv("01_data/profiles/cleaned_profiles.csv")
  # Al no haber validación suficiente, no debe correr PTF por defecto
  expect_true(all(is.na(res_noval$BD_est)))
  
  # Caso 3: n < 5 pero con selected_ptf explícito -> aplica la PTF solicitada
  cfg_explicit <- list(estimate_bd = TRUE, selected_ptf = "rawls_1982")
  jsonlite::write_json(cfg_explicit, cfg_json, auto_unbox = TRUE)
  
  source("02_scripts/01_3_byod_audit.R", local = new.env())
  
  res_explicit <- read.csv("01_data/profiles/cleaned_profiles.csv")
  expect_true(all(!is.na(res_explicit$BD_est[3:12])))
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
