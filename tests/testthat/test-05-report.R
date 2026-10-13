# ==============================================================================
# DSM-Harness v2 | tests/testthat/test-05-report.R
# Tests for Step 5: Final Evaluation & Mapping Report
# ==============================================================================

test_that("Step 5 stops with clear message if pandoc is missing (Precision 7)", {
  # Mock rmarkdown::pandoc_available to return FALSE
  local_mock <- function() {
    orig <- rmarkdown::pandoc_available
    unlockBinding("pandoc_available", asNamespace("rmarkdown"))
    assign("pandoc_available", function(...) FALSE, envir = asNamespace("rmarkdown"))
    lockBinding("pandoc_available", asNamespace("rmarkdown"))
    
    function() {
      unlockBinding("pandoc_available", asNamespace("rmarkdown"))
      assign("pandoc_available", orig, envir = asNamespace("rmarkdown"))
      lockBinding("pandoc_available", asNamespace("rmarkdown"))
    }
  }
  
  restore <- local_mock()
  on.exit(restore(), add = TRUE)
  
  proj_name <- "test_pandoc_missing"
  cleanup_test_project(proj_name)
  on.exit(cleanup_test_project(proj_name), add = TRUE)
  
  new_project(proj_name, repo_root = repo_root)
  proj_dir <- file.path(repo_root, "projects", proj_name)
  cfg <- list(
    project = proj_name,
    language = "en",
    input_file = "data/dummy.csv",
    base_table = "dummy",
    roles = list(profile_id = "id", x = "x", y = "y", top = "top", bottom = "bottom"),
    source_crs = "EPSG:4326"
  )
  jsonlite::write_json(cfg, file.path(proj_dir, "config.json"), auto_unbox = TRUE, pretty = TRUE)
  
  expect_false(run_step("5", project = proj_name))
  err_file <- file.path(proj_dir, "reports", "50_error.txt")
  expect_true(file.exists(err_file))
  err_content <- paste(readLines(err_file, warn = FALSE), collapse = " ")
  expect_true(grepl("Pandoc is required", err_content, ignore.case = TRUE))
})

test_that("Step 5 stops if prediction maps are missing", {
  proj_name <- "test_report_missing_maps"
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
    project_code = "DEMO",
    tiles = list(cols = 2, rows = 2),
    targets = list(list(property = "soc", d1 = 0, d2 = 30, code = "SOC"))
  )
  jsonlite::write_json(cfg, file.path(proj_dir, "config.json"), auto_unbox = TRUE, pretty = TRUE)
  
  expect_false(run_step("5", project = proj_name))
  err_file <- file.path(proj_dir, "reports", "50_error.txt")
  expect_true(file.exists(err_file))
  err_content <- paste(readLines(err_file, warn = FALSE), collapse = " ")
  expect_true(grepl("Prediction maps missing", err_content, ignore.case = TRUE))
})

test_that("Step 5 stops if target code is missing from config.json (Precision 2)", {
  proj_name <- "test_report_missing_target_code"
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
    project_code = "DEMO",
    tiles = list(cols = 2, rows = 2),
    targets = list(list(property = "soc", d1 = 0, d2 = 30)) # missing code
  )
  jsonlite::write_json(cfg, file.path(proj_dir, "config.json"), auto_unbox = TRUE, pretty = TRUE)
  
  expect_false(run_step("5", project = proj_name))
  err_file <- file.path(proj_dir, "reports", "50_error.txt")
  expect_true(file.exists(err_file))
  err_content <- paste(readLines(err_file, warn = FALSE), collapse = " ")
  expect_true(grepl("code", err_content))
})

test_that("Step 5 renders HTML report with observation sites, histogram, variable importance source, and 100% catalogue language purity (Precision 6 & 7)", {
  skip_if(!rmarkdown::pandoc_available(), "Pandoc is required for Step 5 HTML rendering")
  
  # --------------------------------------------------------------------------
  # 1. English Project Test
  # --------------------------------------------------------------------------
  proj_en <- "test_report_en"
  cleanup_test_project(proj_en)
  on.exit(cleanup_test_project(proj_en), add = TRUE)
  
  rel_path_en <- create_synthetic_dataset(proj_en, format = "csv", coords_type = "geographic", n_profiles = 25)
  create_synthetic_covariates(proj_en, n_layers = 3)
  
  proj_dir_en <- file.path(repo_root, "projects", proj_en)
  cfg_en <- list(
    project = proj_en,
    language = "en",
    input_file = rel_path_en,
    base_table = "profiles_data",
    roles = list(profile_id = "id", x = "x", y = "y", top = "upper", bottom = "lower"),
    source_crs = "EPSG:4326",
    country_code = "TST",
    project_code = "DEMO",
    tiles = list(cols = 2, rows = 2),
    targets = list(list(property = "soc", d1 = 0, d2 = 30, code = "SOC", enabled = TRUE))
  )
  jsonlite::write_json(cfg_en, file.path(proj_dir_en, "config.json"), auto_unbox = TRUE, pretty = TRUE)
  
  expect_true(run_step("1.1", project = proj_en))
  expect_true(run_step("1.2", project = proj_en))
  expect_true(run_step("1.3", project = proj_en))
  expect_true(run_step("2", project = proj_en))
  expect_true(run_step("3", project = proj_en))
  expect_true(run_step("4", project = proj_en))
  expect_true(run_step("5", project = proj_en))
  
  html_en <- file.path(proj_dir_en, "reports", "report_soc_0_30.html")
  expect_true(file.exists(html_en))
  html_lines_en <- readLines(html_en, warn = FALSE, encoding = "UTF-8")
  html_text_en <- paste(html_lines_en, collapse = " ")
  
  # Precision 6 checks in English HTML
  expect_true(grepl("Total Observation Sites: 25", html_text_en))
  expect_true(grepl("Spatial Distribution of Observation Sites", html_text_en))
  expect_true(grepl("Histogram of Observed Values", html_text_en))
  expect_true(grepl("Not evaluated \\(only cross-validation was conducted\\)", html_text_en))
  expect_true(grepl("Variable importance source: Final Quantile Regression Forest model \\(permutation importance\\)", html_text_en))
  expect_true(grepl("Observed vs[.\\s\u00a0]+Cross-Validation Predicted", html_text_en))
  expect_true(grepl("Conditional Mean Prediction", html_text_en))
  expect_true(grepl("Prediction Uncertainty \\(Standard Deviation\\)", html_text_en))
  expect_true(grepl("Model Specification &amp; Computational Resources", html_text_en))
  expect_true(grepl("Training Observations.*n = 25", html_text_en))
  expect_true(grepl("Feature Selection \\(Boruta\\)", html_text_en))
  
  # Precision 7 language purity: an "en" project has no Spanish catalogue strings
  expect_false(grepl("Reporte de Mapeo Digital", html_text_en))
  expect_false(grepl("Sitios de Observación", html_text_en))
  expect_false(grepl("No evaluado \\(únicamente", html_text_en))
  expect_false(grepl("Fuente de importancia de variables", html_text_en))
  expect_false(grepl("Predicción de la Media Condicional", html_text_en))
  expect_false(grepl("Resumen y Metadatos", html_text_en))
  
  # Check report text file & decisions log
  txt_rep_en <- file.path(proj_dir_en, "reports", "50_report_soc_0_30.txt")
  expect_true(file.exists(txt_rep_en))
  
  dec_file_en <- file.path(proj_dir_en, "decisions_log.csv")
  expect_true(file.exists(dec_file_en))
  dec_df_en <- read.csv(dec_file_en, stringsAsFactors = FALSE)
  expect_true(any(dec_df_en$step == "5"))
  
  # --------------------------------------------------------------------------
  # 2. Spanish Project Test
  # --------------------------------------------------------------------------
  proj_es <- "test_report_es"
  cleanup_test_project(proj_es)
  on.exit(cleanup_test_project(proj_es), add = TRUE)
  
  rel_path_es <- create_synthetic_dataset(proj_es, format = "csv", coords_type = "geographic", n_profiles = 25)
  create_synthetic_covariates(proj_es, n_layers = 3)
  
  proj_dir_es <- file.path(repo_root, "projects", proj_es)
  cfg_es <- list(
    project = proj_es,
    language = "es",
    input_file = rel_path_es,
    base_table = "profiles_data",
    roles = list(profile_id = "id", x = "x", y = "y", top = "upper", bottom = "lower"),
    source_crs = "EPSG:4326",
    country_code = "TST",
    project_code = "DEMO",
    tiles = list(cols = 2, rows = 2),
    targets = list(list(property = "soc", d1 = 0, d2 = 30, code = "SOC", enabled = TRUE))
  )
  jsonlite::write_json(cfg_es, file.path(proj_dir_es, "config.json"), auto_unbox = TRUE, pretty = TRUE)
  
  expect_true(run_step("1.1", project = proj_es))
  expect_true(run_step("1.2", project = proj_es))
  expect_true(run_step("1.3", project = proj_es))
  expect_true(run_step("2", project = proj_es))
  expect_true(run_step("3", project = proj_es))
  expect_true(run_step("4", project = proj_es))
  expect_true(run_step("5", project = proj_es))
  
  html_es <- file.path(proj_dir_es, "reports", "report_soc_0_30.html")
  expect_true(file.exists(html_es))
  html_lines_es <- readLines(html_es, warn = FALSE, encoding = "UTF-8")
  html_text_es <- paste(html_lines_es, collapse = " ")
  
  # Precision 6 checks in Spanish HTML
  expect_true(grepl("Total de Sitios de Observación: 25", html_text_es))
  expect_true(grepl("Distribución Espacial de Sitios de Observación", html_text_es))
  expect_true(grepl("Histograma de Valores Observados", html_text_es))
  expect_true(grepl("No evaluado \\(únicamente se realizó validación cruzada\\)", html_text_es))
  expect_true(grepl("Fuente de importancia de variables: Modelo final de Quantile Regression Forest \\(importancia por permutación\\)", html_text_es))
  expect_true(grepl("Observado vs[.\\s\u00a0]+Predicho en", html_text_es))
  expect_true(grepl("Predicción de la Media Condicional", html_text_es))
  expect_true(grepl("Incertidumbre de la Predicción \\(Desviación Estándar\\)", html_text_es))
  expect_true(grepl("Especificación del Modelo y Recursos de Cómputo", html_text_es))
  expect_true(grepl("Observaciones de Entrenamiento.*n = 25", html_text_es))
  expect_true(grepl("Selección de Variables \\(Boruta\\)", html_text_es))
  
  # Precision 7 language purity: an "es" project has no English catalogue strings
  expect_false(grepl("Digital Soil Mapping Report", html_text_es))
  expect_false(grepl("Observation Sites & Data Distribution", html_text_es))
  expect_false(grepl("Not evaluated \\(only cross-validation", html_text_es))
  expect_false(grepl("Variable importance source:", html_text_es))
  expect_false(grepl("Conditional Mean Prediction", html_text_es))
  expect_false(grepl("Project Summary & Metadata", html_text_es))
})

test_that("Step 5 displays NO EVALUADO when metrics JSON lacks training metadata (Precision 3)", {
  skip_if(!rmarkdown::pandoc_available(), "Pandoc is required for Step 5 HTML rendering")
  
  proj_es <- "test_report_no_eval"
  cleanup_test_project(proj_es)
  on.exit(cleanup_test_project(proj_es), add = TRUE)
  
  rel_path_es <- create_synthetic_dataset(proj_es, format = "csv", coords_type = "geographic", n_profiles = 25)
  create_synthetic_covariates(proj_es, n_layers = 3)
  
  proj_dir_es <- file.path(repo_root, "projects", proj_es)
  cfg_es <- list(
    project = proj_es,
    language = "es",
    input_file = rel_path_es,
    base_table = "profiles_data",
    roles = list(profile_id = "id", x = "x", y = "y", top = "upper", bottom = "lower"),
    source_crs = "EPSG:4326",
    country_code = "TST",
    project_code = "DEMO",
    tiles = list(cols = 2, rows = 2),
    targets = list(list(property = "soc", d1 = 0, d2 = 30, code = "SOC", enabled = TRUE))
  )
  jsonlite::write_json(cfg_es, file.path(proj_dir_es, "config.json"), auto_unbox = TRUE, pretty = TRUE)
  
  expect_true(run_step("1.1", project = proj_es))
  expect_true(run_step("1.2", project = proj_es))
  expect_true(run_step("1.3", project = proj_es))
  expect_true(run_step("2", project = proj_es))
  expect_true(run_step("3", project = proj_es))
  expect_true(run_step("4", project = proj_es))
  
  # Overwrite metrics file with bare metrics (simulating legacy run without training rows, Boruta counts, etc.)
  metrics_file <- file.path(proj_dir_es, "outputs", "models", "metrics_soc_0_30.json")
  bare_metrics <- list(rmse = 0.5, r2 = 0.2, me = 0.01, mae = 0.4)
  jsonlite::write_json(bare_metrics, metrics_file, auto_unbox = TRUE, pretty = TRUE)
  
  expect_true(run_step("5", project = proj_es, refit = TRUE))
  
  html_es <- file.path(proj_dir_es, "reports", "report_soc_0_30.html")
  expect_true(file.exists(html_es))
  html_text_es <- paste(readLines(html_es, warn = FALSE, encoding = "UTF-8"), collapse = " ")
  
  # Precision 3: verify NO EVALUADO is displayed
  expect_true(grepl("NO EVALUADO", html_text_es))
})
