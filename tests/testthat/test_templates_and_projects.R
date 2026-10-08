library(testthat)

if (basename(getwd()) == "testthat") setwd("../..")
if (basename(getwd()) == "tests") setwd("..")

r_cmd <- file.path(R.home("bin"), if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript")
if (!file.exists(r_cmd)) r_cmd <- Sys.which("Rscript")

test_that("Master templates exist, parse cleanly and declare TEMPLATE_VERSION 2.0.0", {
  scripts <- c(
    "00_inspect_data.R",
    "01_1_byod_audit.R",
    "01_2_byod_audit.R",
    "01_3_byod_audit.R",
    "02_extract_covariates.R",
    "03_spatial_modelling.R",
    "04_predict_and_cog.R",
    "05_render_report.R"
  )
  for (s in scripts) {
    p <- file.path("02_scripts", s)
    expect_true(file.exists(p), info = paste("Script exists:", s))
    
    parsed <- tryCatch(parse(p), error = function(e) e)
    expect_false(inherits(parsed, "error"), info = paste("Valid syntax:", s))
    
    if (s %in% c("01_1_byod_audit.R", "01_2_byod_audit.R", "01_3_byod_audit.R", "02_extract_covariates.R", "03_spatial_modelling.R", "04_predict_and_cog.R", "05_render_report.R")) {
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

test_that("Step 1.3 evaluates reference PTFs, local calibration (n >= 30), and enforces user confirmation", {
  test_csv <- "01_data/profiles/step1_2_spatial.csv"
  cfg_json <- "01_data/profiles/user_config.json"
  
  on.exit({
    unlink(test_csv)
    if (file.exists(cfg_json)) unlink(cfg_json)
    if (file.exists("01_data/profiles/cleaned_profiles.csv")) unlink("01_data/profiles/cleaned_profiles.csv")
    if (file.exists("01_data/profiles/step1_3_pedological_report.txt")) unlink("01_data/profiles/step1_3_pedological_report.txt")
  }, add = TRUE)
  
  # Caso 1: 5 <= n < 30 (n = 10 medidos). Contraste de catálogo de referencia
  df_val <- data.frame(
    profile_code = paste0("P", 1:15),
    longitude = -60, latitude = -34,
    upper = 0, lower = 20,
    SOC = c(1.5, 2.0, 0.8, 1.2, 3.0, 2.5, 1.1, 1.8, 0.9, 2.2, NA, 1.4, 2.1, 1.0, 1.6),
    BD = c(1.35, 1.28, 1.45, 1.25, 1.15, 1.22, 1.38, 1.30, 1.42, 1.20, NA, NA, NA, NA, NA) # 10 medidos
  )
  write.csv(df_val, test_csv, row.names = FALSE)
  
  # Sin confirmación (selected_ptf = null): no debe imputar BD_est pero sí generar tabla
  cfg_diag <- list(estimate_bd = FALSE)
  jsonlite::write_json(cfg_diag, cfg_json, auto_unbox = TRUE)
  
  source("02_scripts/01_3_byod_audit.R", local = new.env())
  
  res_diag <- read.csv("01_data/profiles/cleaned_profiles.csv")
  expect_true(all(is.na(res_diag$BD_est)))
  
  rep_lines <- readLines("01_data/profiles/step1_3_pedological_report.txt", encoding = "UTF-8")
  expect_true(any(grepl("TABLA COMPARATIVA DE PTFS EVALUADAS", rep_lines, fixed = TRUE)))
  expect_true(any(grepl("Saini (1996)", rep_lines, fixed = TRUE)))
  expect_true(any(grepl("Adams (1973)", rep_lines, fixed = TRUE)))
  
  # Confirmando modelo publicado ('best_published' o 'adams_1973') con estimate_bd = true
  cfg_conf <- list(estimate_bd = TRUE, selected_ptf = "best_published")
  jsonlite::write_json(cfg_conf, cfg_json, auto_unbox = TRUE)
  
  source("02_scripts/01_3_byod_audit.R", local = new.env())
  
  res_conf <- read.csv("01_data/profiles/cleaned_profiles.csv")
  # Filas con BD faltante y SOC presente (P12 a P15) deben tener BD_est imputado
  expect_true(all(!is.na(res_conf$BD_est[res_conf$profile_code %in% c("P12", "P13", "P14", "P15")])))
  expect_true(all(is.na(res_conf$BD_est[!is.na(res_conf$BD)])))
  
  # Caso 2: n >= 30 (n = 35 medidos). Calibración de función paramétrica local simple
  set.seed(123)
  soc_sim <- runif(40, 0.5, 4.0)
  om_sim <- soc_sim * 1.724
  # BD sintética con relación inversa a OM
  bd_sim <- round(1.60 - 0.08 * om_sim + rnorm(40, 0, 0.04), 2)
  bd_sim[36:40] <- NA # 5 faltantes a estimar
  
  df_large <- data.frame(
    profile_code = paste0("P", 1:40),
    longitude = -60, latitude = -34,
    upper = 0, lower = 20,
    SOC = soc_sim,
    BD = bd_sim
  )
  write.csv(df_large, test_csv, row.names = FALSE)
  
  # Con n >= 30 y selected_ptf = "local_fit", debe calibrar función local simple e imputar
  cfg_local <- list(estimate_bd = TRUE, selected_ptf = "local_fit", bd_fit_min_n = 30)
  jsonlite::write_json(cfg_local, cfg_json, auto_unbox = TRUE)
  
  source("02_scripts/01_3_byod_audit.R", local = new.env())
  
  res_local <- read.csv("01_data/profiles/cleaned_profiles.csv")
  expect_true(all(!is.na(res_local$BD_est[res_local$profile_code %in% paste0("P", 36:40)])))
  expect_true(all(is.na(res_local$BD_est[!is.na(res_local$BD)])))
  
  rep_large <- readLines("01_data/profiles/step1_3_pedological_report.txt", encoding = "UTF-8")
  expect_true(any(grepl("Ajuste local simple", rep_large, fixed = TRUE)))
  
  # Caso 3: n < 5 datos medidos
  df_noval <- df_val
  df_noval$BD <- c(1.35, 1.28, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA) # solo 2 medidos
  write.csv(df_noval, test_csv, row.names = FALSE)
  
  cfg_noval <- list(estimate_bd = TRUE)
  jsonlite::write_json(cfg_noval, cfg_json, auto_unbox = TRUE)
  
  source("02_scripts/01_3_byod_audit.R", local = new.env())
  
  res_noval <- read.csv("01_data/profiles/cleaned_profiles.csv")
  # Sin validación suficiente ni selected_ptf no debe imputar
  expect_true(all(is.na(res_noval$BD_est)))
  
  # Pero si el usuario elige forzar 'saini_1996' aún con n < 5:
  cfg_force <- list(estimate_bd = TRUE, selected_ptf = "saini_1996")
  jsonlite::write_json(cfg_force, cfg_json, auto_unbox = TRUE)
  
  source("02_scripts/01_3_byod_audit.R", local = new.env())
  
  res_force <- read.csv("01_data/profiles/cleaned_profiles.csv")
  expect_true(all(!is.na(res_force$BD_est[res_force$profile_code %in% c("P12", "P13", "P14", "P15")])))
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

test_that("Issue #25: 00_new_project.R stamps PROJECT_DIR and paths route reports to reports/", {
  test_proj <- "test_issue25_proj"
  proj_path <- file.path("projects", test_proj)
  on.exit(unlink(proj_path, recursive = TRUE), add = TRUE)
  
  project_name <<- test_proj
  source("02_scripts/00_new_project.R", local = new.env())
  
  s_path <- file.path(proj_path, "scripts", "01_1_byod_audit.R")
  lines <- readLines(s_path, encoding = "UTF-8")
  expect_true(any(grepl("PROJECT_DIR <- ['\"]projects/test_issue25_proj['\"]", lines)))
  expect_true(any(grepl('file.path(proj_active, "reports")', lines, fixed = TRUE)))
})

test_that("Issue #26: Step 1.1 resolves duplicate site keys before left_join and prevents row explosion", {
  test_xlsx <- "01_data/profiles/test_site_dups.xlsx"
  cfg_json  <- "01_data/profiles/user_config.json"
  
  df_sites <- data.frame(
    id_sitio = c("S1", "S1", "S2"),
    x = c(-60.1, -60.1, -60.2),
    y = c(-34.1, -34.1, -34.2)
  )
  df_hors <- data.frame(
    id_sitio = c("S1", "S1", "S2"),
    id_hz = c("H1", "H2", "H3"),
    top = c(0, 20, 0),
    bottom = c(20, 40, 30),
    soc = c(2.1, 1.2, 1.8)
  )
  writexl::write_xlsx(list(sitios = df_sites, horizontes = df_hors), test_xlsx)
  
  on.exit({
    unlink(test_xlsx)
    if (file.exists(cfg_json)) unlink(cfg_json)
    if (file.exists("01_data/profiles/step1_1_variables.csv")) unlink("01_data/profiles/step1_1_variables.csv")
    if (file.exists("01_data/profiles/step1_1_variables_report.txt")) unlink("01_data/profiles/step1_1_variables_report.txt")
  }, add = TRUE)
  
  cfg <- list(
    input_file = test_xlsx,
    site_sheet = "sitios",
    site_key = "id_sitio",
    horizon_sheets = list(
      list(sheet = "horizontes", join_key = "id_sitio", horiz_key = "id_hz")
    ),
    duplicate_key_strategy = "keep_first",
    column_mapping = list(
      profile_code = "id_sitio",
      longitude = "x", latitude = "y",
      upper = "top", lower = "bottom",
      SOC = "soc"
    )
  )
  jsonlite::write_json(cfg, cfg_json, auto_unbox = TRUE)
  
  source("02_scripts/01_1_byod_audit.R", local = new.env())
  
  out_df <- read.csv("01_data/profiles/step1_1_variables.csv")
  expect_equal(nrow(out_df), 3)
  
  rep_lines <- readLines("01_data/profiles/step1_1_variables_report.txt", encoding = "UTF-8")
  expect_true(any(grepl("Claves duplicadas en hoja de sitios", rep_lines, fixed = TRUE)))
})

test_that("Issue #27: Step 1.3 assigns BD_source per-row ('measured', 'estimated', 'missing')", {
  test_csv <- "01_data/profiles/step1_2_spatial.csv"
  cfg_json <- "01_data/profiles/user_config.json"
  
  on.exit({
    unlink(test_csv)
    if (file.exists(cfg_json)) unlink(cfg_json)
    if (file.exists("01_data/profiles/cleaned_profiles.csv")) unlink("01_data/profiles/cleaned_profiles.csv")
    if (file.exists("01_data/profiles/step1_3_pedological_report.txt")) unlink("01_data/profiles/step1_3_pedological_report.txt")
  }, add = TRUE)
  
  df_bd <- data.frame(
    profile_code = paste0("P", 1:15),
    longitude = -60, latitude = -34,
    upper = 0, lower = 20,
    SOC = c(1.5, 2.0, 0.8, 1.2, 3.0, 2.5, 1.1, 1.8, 0.9, 2.2, 1.4, 2.1, 1.0, NA, NA),
    BD  = c(1.35, 1.28, 1.45, 1.25, 1.15, 1.22, 1.38, 1.30, 1.42, 1.20, NA, NA, NA, NA, NA)
  )
  write.csv(df_bd, test_csv, row.names = FALSE)
  
  cfg <- list(estimate_bd = TRUE, selected_ptf = "best_published")
  jsonlite::write_json(cfg, cfg_json, auto_unbox = TRUE)
  
  source("02_scripts/01_3_byod_audit.R", local = new.env())
  
  res <- read.csv("01_data/profiles/cleaned_profiles.csv")
  expect_equal(sum(res$BD_source == "measured"), 10)
  expect_equal(sum(res$BD_source == "estimated"), 3)
  expect_equal(sum(res$BD_source == "missing"), 2)
  
  rep_lines <- readLines("01_data/profiles/step1_3_pedological_report.txt", encoding = "UTF-8")
  expect_true(any(grepl("BALANCE Y COBERTURA DE DENSIDAD APARENTE", rep_lines, fixed = TRUE)))
})

test_that("Issue #28: Step 1.2 generates 2D plot fallback when coordinates are projected and source_crs is null", {
  test_csv <- "01_data/profiles/step1_1_variables.csv"
  
  df_metric <- data.frame(
    profile_code = paste0("P", 1:10),
    longitude = 500000 + runif(10, -100, 100),
    latitude  = 6200000 + runif(10, -100, 100),
    upper = 0, lower = 20
  )
  write.csv(df_metric, test_csv, row.names = FALSE)
  
  on.exit({
    unlink(test_csv)
    if (file.exists("01_data/profiles/step1_2_spatial.csv")) unlink("01_data/profiles/step1_2_spatial.csv")
    if (file.exists("01_data/profiles/step1_2_spatial_report.txt")) unlink("01_data/profiles/step1_2_spatial_report.txt")
  }, add = TRUE)
  
  source("02_scripts/01_2_byod_audit.R", local = new.env())
  
  rep_lines <- readLines("01_data/profiles/step1_2_spatial_report.txt", encoding = "UTF-8")
  expect_true(any(grepl("Coordenadas en rango métrico proyectado sin CRS asignado", rep_lines, fixed = TRUE)))
})

test_that("Issue #31: Step 1.1 preserves keep_columns and carries them through to output", {
  test_csv <- "01_data/profiles/test_keep_cols.csv"
  cfg_json <- "01_data/profiles/user_config.json"
  
  df_in <- data.frame(
    id_prof = paste0("P", 1:5),
    top = 0, bottom = 20,
    x = -60, y = -34,
    carb = c(1.1, 1.2, 1.3, 1.4, 1.5),
    pH_nKCl = c(5.2, 5.4, 5.1, 5.8, 6.0),
    CaCO3 = c(0.1, 0.2, 0.0, 0.5, 0.3),
    survey_meta = c("A", "B", "C", "D", "E")
  )
  write.csv(df_in, test_csv, row.names = FALSE)
  
  cfg <- list(
    input_file = test_csv,
    column_mapping = list(
      profile_code = "id_prof",
      upper = "top",
      lower = "bottom",
      longitude = "x",
      latitude = "y",
      SOC = "carb"
    ),
    keep_columns = c("pH_nKCl", "CaCO3")
  )
  jsonlite::write_json(cfg, cfg_json, auto_unbox = TRUE)
  
  on.exit({
    unlink(test_csv)
    if (file.exists(cfg_json)) unlink(cfg_json)
    if (file.exists("01_data/profiles/step1_1_variables.csv")) unlink("01_data/profiles/step1_1_variables.csv")
    if (file.exists("01_data/profiles/step1_1_variables_report.txt")) unlink("01_data/profiles/step1_1_variables_report.txt")
    if (file.exists("01_data/profiles/step1_2_spatial.csv")) unlink("01_data/profiles/step1_2_spatial.csv")
    if (file.exists("01_data/profiles/step1_2_spatial_report.txt")) unlink("01_data/profiles/step1_2_spatial_report.txt")
    if (file.exists("01_data/profiles/cleaned_profiles.csv")) unlink("01_data/profiles/cleaned_profiles.csv")
    if (file.exists("01_data/profiles/step1_3_pedological_report.txt")) unlink("01_data/profiles/step1_3_pedological_report.txt")
  }, add = TRUE)
  
  source("02_scripts/01_1_byod_audit.R", local = new.env())
  
  res1 <- read.csv("01_data/profiles/step1_1_variables.csv")
  expect_true(all(c("pH_nKCl", "CaCO3") %in% names(res1)))
  expect_false("survey_meta" %in% names(res1))
  expect_equal(res1$pH_nKCl, df_in$pH_nKCl)
  expect_equal(res1$CaCO3, df_in$CaCO3)
  
  rep_lines <- readLines("01_data/profiles/step1_1_variables_report.txt", encoding = "UTF-8")
  expect_true(any(grepl("Columnas adicionales preservadas (keep_columns): pH_nKCl, CaCO3", rep_lines, fixed = TRUE)))
  expect_true(any(grepl("survey_meta", rep_lines, fixed = TRUE)))
  
  # Check persistence into Step 1.2 and Step 1.3
  source("02_scripts/01_2_byod_audit.R", local = new.env())
  res2 <- read.csv("01_data/profiles/step1_2_spatial.csv")
  expect_true(all(c("pH_nKCl", "CaCO3") %in% names(res2)))
  
  source("02_scripts/01_3_byod_audit.R", local = new.env())
  res3 <- read.csv("01_data/profiles/cleaned_profiles.csv")
  expect_true(all(c("pH_nKCl", "CaCO3") %in% names(res3)))
})

test_that("Issue #32: ADAPT blocks are clean insertion-only slots in master templates", {
  scripts <- c(
    "02_scripts/01_1_byod_audit.R",
    "02_scripts/01_2_byod_audit.R",
    "02_scripts/01_3_byod_audit.R",
    "02_scripts/02_extract_covariates.R",
    "02_scripts/03_spatial_modelling.R",
    "02_scripts/04_predict_and_cog.R",
    "02_scripts/05_render_report.R"
  )
  
  for (sc in scripts) {
    lines <- readLines(sc, encoding = "UTF-8")
    start_idxs <- grep("^# >>> ADAPT:", lines)
    end_idxs   <- grep("^# <<< ADAPT:", lines)
    
    expect_equal(length(start_idxs), length(end_idxs), info = paste("Mismatched ADAPT tags in", sc))
    
    for (k in seq_along(start_idxs)) {
      inner <- lines[(start_idxs[k] + 1):(end_idxs[k] - 1)]
      # Inner lines must only be comments or empty lines in pristine master templates
      non_comments <- grep("^\\s*[^#\\s]", inner, value = TRUE)
      expect_equal(length(non_comments), 0, info = paste("Found executable code inside master ADAPT slot in", sc, lines[start_idxs[k]]))
    }
  }
})

test_that("Issue #33: 01_2_byod_audit.R does not contain concrete hardcoded EPSG 32616", {
  lines <- readLines("02_scripts/01_2_byod_audit.R", encoding = "UTF-8")
  expect_false(any(grepl("32616", lines, fixed = TRUE)))
})

test_that("Issue #34: Scripts preserve run_step and PROJECT_NAME in caller environment", {
  scripts <- c(
    "02_scripts/01_1_byod_audit.R",
    "02_scripts/01_2_byod_audit.R",
    "02_scripts/01_3_byod_audit.R",
    "02_scripts/02_extract_covariates.R",
    "02_scripts/03_spatial_modelling.R",
    "02_scripts/04_predict_and_cog.R",
    "02_scripts/05_render_report.R"
  )
  for (sc in scripts) {
    lines <- readLines(sc, encoding = "UTF-8")
    rm_line <- grep("rm\\(list = setdiff", lines, value = TRUE)
    expect_true(length(rm_line) == 1, info = paste("Found rm line in", sc))
    expect_true(grepl('"run_step"', rm_line, fixed = TRUE), info = paste("run_step preserved in", sc))
    expect_true(grepl('"PROJECT_NAME"', rm_line, fixed = TRUE), info = paste("PROJECT_NAME preserved in", sc))
  }
})

test_that("Issue #35: 100% of documented keys in CONFIG_SCHEMA.md are present in known_config_keys", {
  schema_lines <- readLines("docs/CONFIG_SCHEMA.md", encoding = "UTF-8")
  sec2_start <- grep("^## 2\\. Top-Level Keys Reference", schema_lines)
  sec3_start <- grep("^## 3\\.", schema_lines)
  sec2_lines <- schema_lines[sec2_start:sec3_start]
  table_lines <- grep("^\\| `[a-zA-Z0-9_]+` \\|", sec2_lines, value = TRUE)
  schema_keys <- sub("^\\| `([a-zA-Z0-9_]+)` \\|.*", "\\1", table_lines)
  expect_true(length(schema_keys) >= 15, info = "Extracted schema keys from CONFIG_SCHEMA.md")
  
  script_lines <- readLines("02_scripts/01_1_byod_audit.R", encoding = "UTF-8")
  k_start <- grep("known_config_keys <- c\\(", script_lines)
  k_end <- grep("^\\)", script_lines[k_start:length(script_lines)])[1] + k_start - 1
  k_code <- paste(script_lines[k_start:k_end], collapse = " ")
  known_keys <- eval(parse(text = sub("known_config_keys <- ", "", k_code)))
  
  missing_keys <- setdiff(schema_keys, known_keys)
  expect_equal(length(missing_keys), 0,
               info = sprintf("Missing keys in known_config_keys: [%s]", paste(missing_keys, collapse = ", ")))
})

test_that("Issue #38: 01_2_byod_audit.R differentiates unique profiles and documents coordinate space", {
  lines <- readLines("02_scripts/01_2_byod_audit.R", encoding = "UTF-8")
  expect_true(any(grepl("outlier_profiles <-", lines, fixed = TRUE)))
  expect_true(any(grepl("coord_space_iqr <-", lines, fixed = TRUE)))
  expect_true(any(grepl("Espacio de coordenadas evaluado:", lines, fixed = TRUE)))
  expect_true(any(grepl("perfiles únicos", lines, fixed = TRUE)))
})

test_that("Issue #37 & #39: 00_new_project.R instantiates Stages 0 through 4 and run_step.R maps all steps", {
  test_proj <- "test_stages_workflow"
  proj_path <- file.path("projects", test_proj)
  on.exit(unlink(proj_path, recursive = TRUE), add = TRUE)
  
  project_name <<- test_proj
  source("02_scripts/00_new_project.R", local = new.env())
  
  # Verificar scripts en carpeta del proyecto
  expected_scripts <- c(
    "00_inspect_data.R",
    "01_1_byod_audit.R",
    "01_2_byod_audit.R",
    "01_3_byod_audit.R",
    "02_extract_covariates.R",
    "03_spatial_modelling.R",
    "04_predict_and_cog.R",
    "05_render_report.R"
  )
  for (sc in expected_scripts) {
    p <- file.path(proj_path, "scripts", sc)
    expect_true(file.exists(p), info = paste("Script instanciado existe:", sc))
    # Debe tener cabecera de procedencia
    first_lines <- readLines(p, n = 5, encoding = "UTF-8")
    expect_true(any(grepl("PROVENANCE METADATA", first_lines)), info = paste("Tiene metadatos de procedencia:", sc))
  }
  
  # Plantilla Rmd instanciada como artefacto
  rmd_file <- file.path(proj_path, "scripts", "05_variable_report.Rmd")
  expect_true(file.exists(rmd_file), info = "Plantilla Rmd existe en scripts de proyecto")
  
  # Verificar run_step.R
  run_step_file <- file.path(proj_path, "run_step.R")
  expect_true(file.exists(run_step_file))
  rs_lines <- readLines(run_step_file, encoding = "UTF-8")
  for (step_id in c("'0'", "'1.1'", "'1.2'", "'1.3'", "'2'", "'3'", "'4'", "'5'")) {
    expect_true(any(grepl(step_id, rs_lines, fixed = TRUE)), info = paste("run_step soporta:", step_id))
  }
})

test_that("Issue #41: .gitignore covers rasters, models and covariates directories", {
  gi_lines <- readLines(".gitignore", encoding = "UTF-8")
  expect_true(any(grepl("\\*\\.tif", gi_lines)), info = "Ignores *.tif")
  expect_true(any(grepl("\\*\\.tiff", gi_lines)), info = "Ignores *.tiff")
  expect_true(any(grepl("\\*\\.rds", gi_lines)), info = "Ignores *.rds")
  expect_true(any(grepl("covariates", gi_lines)), info = "Ignores covariates")
})

test_that("Issue #41: 04_predict_and_cog.R validates country_code and project_code without inventing them", {
  lines <- readLines("02_scripts/04_predict_and_cog.R", encoding = "UTF-8")
  expect_true(any(grepl("country_code", lines, fixed = TRUE)))
  expect_true(any(grepl("project_code", lines, fixed = TRUE)))
  expect_true(any(grepl("ISO-3", lines, fixed = TRUE)))
  expect_true(any(grepl("LAYOUT=COG", lines, fixed = TRUE)))
})

test_that("Issue #42: Spectroscopy is strictly banished from DSM documentation and workflows", {
  readme_lines <- readLines("README.md", encoding = "UTF-8")
  expect_true(any(grepl("OUT OF SCOPE", readme_lines, ignore.case = TRUE)))
  expect_true(any(grepl("The 5 Canonical DSM Stages", readme_lines)))
  
  readme_es_lines <- readLines("README.es.md", encoding = "UTF-8")
  expect_true(any(grepl("Las 5 Etapas Canónicas de DSM", readme_es_lines)))
  
  agents_lines <- readLines("AGENTS.md", encoding = "UTF-8")
  expect_true(any(grepl("ABSOLUTE BAN on Spectroscopy", agents_lines)))
})

test_that("Issue #43: Step 1.2 reports resulting WGS84 bounding box and requires territorial verification", {
  lines_12 <- readLines("02_scripts/01_2_byod_audit.R", encoding = "UTF-8")
  expect_true(any(grepl("RANGOS DE COORDENADAS WGS84 (CONFIRMACION HUMANA REQUERIDA)", lines_12, fixed = TRUE)))
  expect_true(any(grepl("Rango resultante en grados (WGS84):", lines_12, fixed = TRUE)))
  expect_true(any(grepl("Revisa el rango geografico resultante:", lines_12, fixed = TRUE)))
  
  agents_lines <- readLines("AGENTS.md", encoding = "UTF-8")
  expect_true(any(grepl("EPSG Candidate Protocol (#43)", agents_lines, fixed = TRUE)))
  expect_true(any(grepl("Post-Reprojection Bounding Box Verification (#43)", agents_lines, fixed = TRUE)))
})

test_that("Issue #44: Companion reports use clean ASCII without encoding conversion risks, and AGENTS mandates evidence rigor", {
  lines_03 <- readLines("02_scripts/03_spatial_modelling.R", encoding = "UTF-8")
  expect_true(any(grepl("R^2 (Coeficiente determinacion):", lines_03, fixed = TRUE)))
  expect_false(any(grepl("R²", lines_03, fixed = TRUE)))
  
  agents_lines <- readLines("AGENTS.md", encoding = "UTF-8")
  expect_true(any(grepl("ABSOLUTE BAN on Hallucinated File Names & Sources (#44)", agents_lines, fixed = TRUE)))
  expect_true(any(grepl("ABSOLUTE BAN on Unilateral Target Properties & Prescriptive Intervals (#44)", agents_lines, fixed = TRUE)))
})

test_that("Issue #45: Step 5 parameterized R Markdown report template and runner", {
  # 1. Master files existence and syntax
  expect_true(file.exists("02_scripts/05_variable_report.Rmd"))
  expect_true(file.exists("02_scripts/05_render_report.R"))
  
  parsed_runner <- tryCatch(parse("02_scripts/05_render_report.R"), error = function(e) e)
  expect_false(inherits(parsed_runner, "error"))
  
  # 2. Check required sections in Rmd template
  rmd_lines <- readLines("02_scripts/05_variable_report.Rmd", encoding = "UTF-8")
  expect_true(any(grepl("Sitios de observación", rmd_lines)))
  expect_true(any(grepl("Distribución de los valores", rmd_lines)))
  expect_true(any(grepl("Modelo y desempeño", rmd_lines)))
  expect_true(any(grepl("Validación", rmd_lines)))
  expect_true(any(grepl("Mapas finales", rmd_lines)))
  expect_true(any(grepl("Observaciones y límites", rmd_lines)))
  
  # 3. Explicit note: red line is 1:1, NOT a regression
  expect_true(any(grepl("La línea roja es la recta 1:1 \\(predicho = observado\\), no una regresión de los puntos", rmd_lines)))
  
  # 4. Check that 03_spatial_modelling saves metrics JSON
  lines_03 <- readLines("02_scripts/03_spatial_modelling.R", encoding = "UTF-8")
  expect_true(any(grepl("metrics_%s.json", lines_03, fixed = TRUE)))
  
  # 5. Check ADAPT block and report summary in 05_render_report.R
  runner_lines <- readLines("02_scripts/05_render_report.R", encoding = "UTF-8")
  expect_true(any(grepl(">>> ADAPT:render_report", runner_lines, fixed = TRUE)))
  expect_true(any(grepl("step5_report_summary.txt", runner_lines, fixed = TRUE)))
  
  # 6. Test rendering in an isolated project
  test_proj <- "test_step5_report"
  proj_path <- file.path("projects", test_proj)
  on.exit(unlink(proj_path, recursive = TRUE), add = TRUE)
  
  project_name <<- test_proj
  source("02_scripts/00_new_project.R", local = new.env())
  
  # Create synthetic dataset with target property
  synth_cov <- data.frame(
    profile_code = paste0("P", 1:30),
    longitude = runif(30, 21.0, 22.0),
    latitude = runif(30, 41.0, 42.0),
    pH_H2O = rnorm(30, mean = 6.5, sd = 0.8),
    cov1 = runif(30, 100, 200),
    cov2 = runif(30, 0, 50)
  )
  write.csv(synth_cov, file.path(proj_path, "data", "step2_covariates.csv"), row.names = FALSE)
  
  # Configure project config.json
  cfg <- list(
    target_property = "pH_H2O",
    target_depth_upper = 0,
    target_depth_lower = 30,
    country_code = "MKD",
    project_code = "NACIONAL",
    target_unit = "pH units"
  )
  jsonlite::write_json(cfg, file.path(proj_path, "config.json"), auto_unbox = TRUE, pretty = TRUE)
  
  # Execute step 5 runner in project
  PROJECT_DIR <<- proj_path
  CURRENT_PROJECT_DIR <<- proj_path
  PROJECT_NAME <<- test_proj
  
  source(file.path(proj_path, "scripts", "05_render_report.R"), local = new.env())
  
  expected_html <- file.path(proj_path, "reports", "report_MKD-NACIONAL-pH_H2O-0-30.html")
  expected_txt  <- file.path(proj_path, "reports", "step5_report_summary.txt")
  
  expect_true(file.exists(expected_html), info = "Generated standalone HTML report")
  expect_true(file.size(expected_html) > 1000, info = "HTML file is non-empty")
  expect_true(file.exists(expected_txt), info = "Generated companion summary TXT")
  
  html_lines <- readLines(expected_html, encoding = "UTF-8")
  expect_false(any(grepl("Perfiles usados</span><b>0</b>", html_lines, fixed = TRUE)))
  expect_true(any(grepl("Perfiles usados</span><b>30</b>", html_lines, fixed = TRUE)))
  
  # Check decision logged
  log_lines <- readLines(file.path(proj_path, "decisions_log.csv"), encoding = "UTF-8")
  expect_true(any(grepl("Reporte final de mapeo", log_lines)))
})

test_that("Issue #46: Step 5 enforces knit_root_dir and validates non-empty dataset profiles in rendered HTML", {
  lines_05 <- readLines("02_scripts/05_render_report.R", encoding = "UTF-8")
  expect_true(any(grepl("knit_root_dir", lines_05, fixed = TRUE)))
  expect_true(any(grepl("Perfiles usados</span><b>0</b>", lines_05, fixed = TRUE)))
  expect_true(any(grepl("El reporte HTML se generó sin perfiles", lines_05, fixed = TRUE)))
})

test_that("Issue #47: Step 1.1, 1.2 and 1.3 enforce strict enum validation and reject invalid preset strategies", {
  lines_11 <- readLines("02_scripts/01_1_byod_audit.R", encoding = "UTF-8")
  expect_true(any(grepl("Valor no válido para 'duplicate_key_strategy'", lines_11, fixed = TRUE)))
  expect_true(any(grepl("Valor no válido para 'duplicate_action'", lines_11, fixed = TRUE)))
  expect_true(any(grepl("Valor no válido para 'outlier_action'", lines_11, fixed = TRUE)))
  expect_true(any(grepl("Valor no válido para 'spatial_outlier_action'", lines_11, fixed = TRUE)))
  
  lines_12 <- readLines("02_scripts/01_2_byod_audit.R", encoding = "UTF-8")
  expect_true(any(grepl("Valor no válido para 'outlier_action'", lines_12, fixed = TRUE)))
  
  lines_13 <- readLines("02_scripts/01_3_byod_audit.R", encoding = "UTF-8")
  expect_true(any(grepl("Valor no válido para 'selected_ptf'", lines_13, fixed = TRUE)))
  
  agents_lines <- readLines("AGENTS.md", encoding = "UTF-8")
  expect_true(any(grepl("ABSOLUTE BAN on Proactive Duplicate Presets & Invalid Enums (#47)", agents_lines, fixed = TRUE)))
  expect_true(any(grepl("ABSOLUTE BAN on Fictitious Row Removals (#47)", agents_lines, fixed = TRUE)))
})

test_that("Issue #48: Agent neutrality, no CRS qualitative bias, no unbacked property scales, no persistent code examples", {
  lines_04 <- readLines("02_scripts/04_predict_and_cog.R", encoding = "UTF-8")
  expect_false(any(grepl("ej. GTM, MKD", lines_04, fixed = TRUE)))
  expect_false(any(grepl("ej. NACIONAL", lines_04, fixed = TRUE)))
  
  rmd_lines <- readLines("02_scripts/05_variable_report.Rmd", encoding = "UTF-8")
  expect_false(any(grepl('cc: "MKD"', rmd_lines, fixed = TRUE)))
  expect_false(any(grepl('proj: "NACIONAL"', rmd_lines, fixed = TRUE)))
  
  agents_lines <- readLines("AGENTS.md", encoding = "UTF-8")
  expect_true(any(grepl("ABSOLUTE BAN on Unbacked Analytical Scales & Presumptive Norms (#48)", agents_lines, fixed = TRUE)))
  expect_true(any(grepl("No Persistent Numeric Examples or Fixed Codes (#48)", agents_lines, fixed = TRUE)))
  expect_true(any(grepl("WITHOUT qualitative labels", agents_lines, fixed = TRUE)))
  
  panel_lines <- readLines("agents/dsm-panel.md", encoding = "UTF-8")
  expect_true(any(grepl("PROHIBICIÓN DE ESCALAS ANALÍTICAS SIN RESPALDO Y JUICIOS DE AJUSTE (#48)", panel_lines, fixed = TRUE)))
  expect_true(any(grepl("código del proyecto nacional", panel_lines, fixed = TRUE)))
})

test_that("Issue #49: [i18n] Bilingual English and Spanish workflow, reports, logs, and HTML rendering", {
  source("02_scripts/00_i18n.R", local = FALSE)
  
  # 1. Unit tests for 00_i18n.R
  expect_equal(get_project_language(list(language = "en")), "en")
  expect_equal(get_project_language(list(language = "es")), "es")
  expect_equal(get_project_language(list()), "es")
  expect_equal(get_project_language(NULL), "es")
  
  expect_equal(i18n_not_evaluated("es"), "NO EVALUADO")
  expect_equal(i18n_not_evaluated("en"), "NOT EVALUATED")
  expect_equal(i18n_present("en"), "PRESENT")
  expect_equal(i18n_missing("en"), "MISSING")
  
  expect_equal(translate_decision_text("Reporte final de mapeo", "en"), "Final mapping report")
  expect_equal(translate_decision_text("Auditoría de variables BYOD", "en"), "BYOD variable audit")
  expect_equal(translate_decision_text("Auditoría espacial de coordenadas", "en"), "Spatial coordinate audit")
  expect_equal(translate_decision_text("Auditoría pedológica y vertical", "en"), "Pedological and vertical audit")
  expect_equal(translate_decision_text("Extracción de covariables", "en"), "Covariate extraction")
  expect_equal(translate_decision_text("Modelado espacial QRF", "en"), "Spatial QRF modeling")
  expect_equal(translate_decision_text("Exportación COG OpenNSIS", "en"), "OpenNSIS COG export")
  
  enum_err_en <- format_config_enum_error("my_key", "bad_val", c("a", "b"), "en")
  expect_true(grepl("\\[CONFIG ERROR\\] Invalid value 'bad_val' for 'my_key'", enum_err_en))
  
  enum_err_es <- format_config_enum_error("my_key", "bad_val", c("a", "b"), "es")
  expect_true(grepl("\\[ERROR CONFIG\\] Valor no válido 'bad_val' para 'my_key'", enum_err_es))
  
  # 2. Test isolated project in English
  en_proj <- "test_i18n_en_proj"
  proj_path <- file.path("projects", en_proj)
  on.exit(unlink(proj_path, recursive = TRUE), add = TRUE)
  
  project_name <<- en_proj
  project_language <<- "en"
  source("02_scripts/00_new_project.R", local = new.env())
  
  # Verify project files
  expect_true(file.exists(file.path(proj_path, "scripts", "00_i18n.R")))
  expect_true(file.exists(file.path(proj_path, "scripts", "05_variable_report.Rmd")))
  
  cfg_read <- jsonlite::fromJSON(file.path(proj_path, "config.json"), simplifyVector = FALSE)
  expect_equal(cfg_read$language, "en")
  
  run_step_lines <- readLines(file.path(proj_path, "run_step.R"), encoding = "UTF-8")
  expect_true(any(grepl("Step runner for:", run_step_lines)))
  expect_true(any(grepl("Available commands:", run_step_lines)))
  
  # 3. Test Step 0 in English
  df_synth <- data.frame(
    id_perfil = paste0("P", 1:30),
    x_coord = runif(30, -60, -58),
    y_coord = runif(30, -35, -33),
    prof_desde = 0,
    prof_hasta = 30,
    carbono_org = runif(30, 0.5, 3.5),
    ph_suelo = runif(30, 5.5, 7.5),
    arcilla_pct = runif(30, 15, 35)
  )
  write.csv(df_synth, file.path(proj_path, "data", "perfiles.csv"), row.names = FALSE)
  
  cfg_read$input_file <- file.path(proj_path, "data", "perfiles.csv")
  jsonlite::write_json(cfg_read, file.path(proj_path, "config.json"), auto_unbox = TRUE, pretty = TRUE)
  
  PROJECT_DIR <<- proj_path
  CURRENT_PROJECT_DIR <<- proj_path
  PROJECT_NAME <<- en_proj
  input_file <<- file.path(proj_path, "data", "perfiles.csv")
  output_report <<- file.path(proj_path, "reports", "data_inspection_report.txt")
  
  source(file.path(proj_path, "scripts", "00_inspect_data.R"), local = new.env())
  
  step0_rep <- file.path(proj_path, "reports", "data_inspection_report.txt")
  expect_true(file.exists(step0_rep))
  step0_lines <- readLines(step0_rep, encoding = "UTF-8")
  expect_true(any(grepl("DSM-HARNESS: COMPACT STRUCTURAL INSPECTION REPORT (BYOD)", step0_lines, fixed = TRUE)))
  expect_true(any(grepl("Date and time:", step0_lines, fixed = TRUE)))
  expect_true(any(grepl("END OF COMPACT INSPECTION REPORT", step0_lines, fixed = TRUE)))
  expect_false(any(grepl("REPORTE COMPACTO DE INSPECCION ESTRUCTURAL", step0_lines, fixed = TRUE)))
  
  # 4. Test Step 1.1 in English
  cfg_read$column_mapping <- list(
    profile_code = "id_perfil",
    longitude = "x_coord",
    latitude = "y_coord",
    upper = "prof_desde",
    lower = "prof_hasta",
    SOC = "carbono_org",
    pH_H2O = "ph_suelo"
  )
  cfg_read$keep_columns <- c("arcilla_pct")
  jsonlite::write_json(cfg_read, file.path(proj_path, "config.json"), auto_unbox = TRUE, pretty = TRUE)
  
  source(file.path(proj_path, "scripts", "01_1_byod_audit.R"), local = new.env())
  
  step11_rep <- file.path(proj_path, "reports", "step1_1_variables_report.txt")
  expect_true(file.exists(step11_rep))
  step11_lines <- readLines(step11_rep, encoding = "UTF-8")
  expect_true(any(grepl("DSM-HARNESS | STEP 1.1 REPORT: VARIABLE MAPPING AND SELECTION", step11_lines, fixed = TRUE)))
  expect_true(any(grepl("Unique profile count:", step11_lines, fixed = TRUE)))
  expect_true(any(grepl("Additional columns preserved (keep_columns):", step11_lines, fixed = TRUE)))
  expect_false(any(grepl("REPORTE PASO 1.1: MAPEO Y SELECCION DE VARIABLES", step11_lines, fixed = TRUE)))
  
  # 5. Test Step 5 in English
  synth_cov <- data.frame(
    profile_code = paste0("P", 1:30),
    longitude = runif(30, 21.0, 22.0),
    latitude = runif(30, 41.0, 42.0),
    pH_H2O = rnorm(30, mean = 6.5, sd = 0.8),
    cov1 = runif(30, 100, 200),
    cov2 = runif(30, 0, 50)
  )
  write.csv(synth_cov, file.path(proj_path, "data", "step2_covariates.csv"), row.names = FALSE)
  
  cfg_read$target_property <- "pH_H2O"
  cfg_read$target_depth_upper <- 0
  cfg_read$target_depth_lower <- 30
  cfg_read$country_code <- "MKD"
  cfg_read$project_code <- "NACIONAL"
  cfg_read$target_unit <- "pH units"
  jsonlite::write_json(cfg_read, file.path(proj_path, "config.json"), auto_unbox = TRUE, pretty = TRUE)
  
  source(file.path(proj_path, "scripts", "05_render_report.R"), local = new.env())
  
  step5_rep <- file.path(proj_path, "reports", "step5_report_summary.txt")
  expect_true(file.exists(step5_rep))
  step5_lines <- readLines(step5_rep, encoding = "UTF-8")
  expect_true(any(grepl("DSM-HARNESS | FINAL SOIL MAPPING REPORT SUMMARY (STEP 5)", step5_lines, fixed = TRUE)))
  expect_true(any(grepl("Mapped variable:", step5_lines, fixed = TRUE)))
  expect_true(any(grepl("Generated HTML file:", step5_lines, fixed = TRUE)))
  expect_false(any(grepl("REPORTE RESUMEN DEL INFORME FINAL DE MAPEO", step5_lines, fixed = TRUE)))
  
  html_file <- file.path(proj_path, "reports", "report_MKD-NACIONAL-pH_H2O-0-30.html")
  expect_true(file.exists(html_file))
  html_lines <- readLines(html_file, encoding = "UTF-8")
  expect_true(any(grepl("1\\. Observation Sites", html_lines)))
  expect_true(any(grepl("2\\. Value Distribution", html_lines)))
  expect_true(any(grepl("3\\. Model &amp; Performance", html_lines)))
  expect_true(any(grepl("4\\. Validation", html_lines)))
  expect_true(any(grepl("5\\. Final Maps", html_lines)))
  expect_true(any(grepl("Observations &amp; Caveats", html_lines)))
  expect_true(any(grepl("The red line is the 1:1 line", html_lines)))
  expect_false(any(grepl("Sitios de observación", html_lines)))
  expect_false(any(grepl("Distribución de los valores", html_lines)))
  
  # 6. Verify decisions_log.csv in English
  log_file <- file.path(proj_path, "decisions_log.csv")
  expect_true(file.exists(log_file))
  log_df <- read.csv(log_file, stringsAsFactors = FALSE)
  expect_true(any(log_df$criterion == "Final mapping report"))
  expect_true(any(log_df$criterion == "Preserve additional columns"))
  expect_false(any(log_df$criterion == "Reporte final de mapeo"))
  expect_false(any(log_df$criterion == "Conservación de columnas adicionales"))
})

test_that("Issue #50: run_step.R executes cleanly in a fresh session without project_name defined", {
  test_proj <- "test_issue_50_runner"
  proj_path <- file.path("projects", test_proj)
  on.exit(unlink(proj_path, recursive = TRUE), add = TRUE)
  
  project_name <<- test_proj
  project_language <<- "es"
  source("02_scripts/00_new_project.R", local = new.env())
  
  runner_path <- file.path(proj_path, "run_step.R")
  expect_true(file.exists(runner_path))
  
  # Clean environment with no project_name defined
  clean_env <- new.env(parent = baseenv())
  expect_false(exists("project_name", envir = clean_env))
  
  # Sourcing run_step.R should not raise an error about object 'project_name' not found
  runner_output <- capture.output({
    expect_error(source(runner_path, local = clean_env), NA)
  })
  
  expect_true(exists("run_step", envir = clean_env))
  expect_true(exists("PROJECT_NAME", envir = clean_env))
  expect_equal(clean_env$PROJECT_NAME, test_proj)
  expect_true(any(grepl(test_proj, runner_output)))
})

test_that("Issue #51: Console output, reports, and HTML document title emit zero Spanish text when language is English", {
  test_proj <- "test_issue_51_en"
  proj_path <- file.path("projects", test_proj)
  on.exit(unlink(proj_path, recursive = TRUE), add = TRUE)
  
  project_name <<- test_proj
  project_language <<- "en"
  
  # 1. Project creation console capture
  p_out <- capture.output({
    source("02_scripts/00_new_project.R", local = new.env())
  })
  expect_true(any(grepl("PROJECT CREATED SUCCESSFULLY", p_out)))
  expect_false(any(grepl("PROYECTO CREADO EXITOSAMENTE", p_out)))
  expect_false(any(grepl("Script instanciado", p_out)))
  
  # Setup synthetic data
  df_synth <- data.frame(
    id_perfil = paste0("P", 1:20),
    x_coord = runif(20, -60, -58),
    y_coord = runif(20, -35, -33),
    prof_desde = 0,
    prof_hasta = 30,
    carbono_org = runif(20, 0.5, 3.5),
    ph_suelo = runif(20, 5.5, 7.5),
    cov1 = runif(20, 10, 50)
  )
  write.csv(df_synth, file.path(proj_path, "data", "perfiles.csv"), row.names = FALSE)
  
  # Config
  cfg_read <- jsonlite::fromJSON(file.path(proj_path, "config.json"), simplifyVector = FALSE)
  cfg_read$input_file <- file.path(proj_path, "data", "perfiles.csv")
  cfg_read$column_mapping <- list(
    profile_code = "id_perfil",
    longitude = "x_coord",
    latitude = "y_coord",
    upper = "prof_desde",
    lower = "prof_hasta",
    SOC = "carbono_org",
    pH_H2O = "ph_suelo"
  )
  cfg_read$target_property <- "SOC"
  cfg_read$country_code <- "MKD"
  cfg_read$project_code <- "DEMO"
  jsonlite::write_json(cfg_read, file.path(proj_path, "config.json"), auto_unbox = TRUE, pretty = TRUE)
  
  PROJECT_DIR <<- proj_path
  CURRENT_PROJECT_DIR <<- proj_path
  PROJECT_NAME <<- test_proj
  input_file <<- file.path(proj_path, "data", "perfiles.csv")
  
  # 2. Step 0 Console capture
  s0_out <- capture.output({
    source(file.path(proj_path, "scripts", "00_inspect_data.R"), local = new.env())
  })
  expect_true(any(grepl("COMPACT STRUCTURAL INSPECTION REPORT", s0_out)))
  expect_false(any(grepl("REPORTE COMPACTO", s0_out)))
  expect_false(any(grepl("INSPECCIÓN ESTRUCTURAL", s0_out)))
  
  # 3. Step 1.1 Console capture
  s1_out <- capture.output({
    source(file.path(proj_path, "scripts", "01_1_byod_audit.R"), local = new.env())
  })
  expect_true(any(grepl("VARIABLE MAPPING TABLE", s1_out)))
  expect_true(any(grepl("Configuration loaded from", s1_out)))
  expect_false(any(grepl("TABLA DE MAPEO DE VARIABLES", s1_out)))
  expect_false(any(grepl("Configuración cargada desde", s1_out)))
  expect_false(any(grepl("Perfiles únicos identificados", s1_out)))
  
  # 4. Step 5 Console capture & HTML title check
  write.csv(df_synth, file.path(proj_path, "data", "step2_covariates.csv"), row.names = FALSE)
  s5_out <- capture.output({
    source(file.path(proj_path, "scripts", "05_render_report.R"), local = new.env())
  })
  expect_true(any(grepl("FINAL REPORT GENERATION SUMMARY", s5_out)))
  expect_false(any(grepl("RESUMEN DE GENERACIÓN DE REPORTE FINAL", s5_out)))
  expect_false(any(grepl("Variable mapeada:", s5_out)))
  
  html_f <- file.path(proj_path, "reports", "report_MKD-DEMO-SOC-0-30.html")
  expect_true(file.exists(html_f))
  html_lines <- readLines(html_f, encoding = "UTF-8")
  
  # Document title in HTML <head><title>
  expect_true(any(grepl("<title>Soil Mapping Report · MKD-DEMO-SOC-0-30</title>", html_lines, fixed = TRUE)))
  expect_false(any(grepl("<title>Reporte de mapeo", html_lines)))
})



