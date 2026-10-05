library(testthat)

if (basename(getwd()) == "testthat") setwd("../..")
if (basename(getwd()) == "tests") setwd("..")

test_that("Master templates exist, parse cleanly and declare TEMPLATE_VERSION 2.0.0", {
  scripts <- c("00_inspect_data.R", "01_1_byod_audit.R", "01_2_byod_audit.R", "01_3_byod_audit.R")
  for (s in scripts) {
    p <- file.path("02_scripts", s)
    expect_true(file.exists(p), info = paste("Script exists:", s))
    
    # Parse syntax check
    parsed <- tryCatch(parse(p), error = function(e) e)
    expect_false(inherits(parsed, "error"), info = paste("Valid syntax:", s))
    
    # Template version check for step scripts
    if (s %in% c("01_1_byod_audit.R", "01_2_byod_audit.R", "01_3_byod_audit.R")) {
      lines <- readLines(p, encoding = "UTF-8")
      expect_true(any(grepl('TEMPLATE_VERSION <- "2.0.0"', lines, fixed = TRUE)),
                  info = paste("Declares TEMPLATE_VERSION 2.0.0:", s))
      expect_true(any(grepl(">>> ADAPT:", lines)), info = paste("Contains ADAPT tags:", s))
    }
  }
})

test_that("Step 1.1 fails fast when dataset has 0 mapped variables", {
  test_csv <- "01_data/profiles/test_unmapped_guard.csv"
  write.csv(data.frame(foo_a = 1:5, foo_b = 6:10), test_csv, row.names = FALSE)
  on.exit(unlink(test_csv), add = TRUE)
  
  # Ejecutar en proceso R separado para capturar stop()
  r_cmd <- file.path(R.home("bin"), "Rscript.exe")
  if (!file.exists(r_cmd)) r_cmd <- "Rscript"
  
  res <- system2(r_cmd, args = c("02_scripts/01_1_byod_audit.R"), stdout = TRUE, stderr = TRUE)
  expect_true(any(grepl("ERROR FATAL EN MAPEO", res)), info = "Fails fast with fatal mapping error")
  expect_false(file.exists("01_data/profiles/step1_1_variables.csv"), info = "Does not create empty CSV on failure")
})

test_that("00_new_project.R instantiates an isolated project with correct provenance and run_step.R", {
  test_proj <- "test_unit_project"
  proj_path <- file.path("projects", test_proj)
  on.exit(unlink(proj_path, recursive = TRUE), add = TRUE)
  
  # Instanciar proyecto
  project_name <<- test_proj
  source("02_scripts/00_new_project.R", local = new.env())
  
  expect_true(dir.exists(proj_path))
  expect_true(dir.exists(file.path(proj_path, "data")))
  expect_true(dir.exists(file.path(proj_path, "scripts")))
  expect_true(dir.exists(file.path(proj_path, "outputs")))
  expect_true(dir.exists(file.path(proj_path, "reports")))
  expect_true(file.exists(file.path(proj_path, "config.json")))
  expect_true(file.exists(file.path(proj_path, "decisions_log.csv")))
  expect_true(file.exists(file.path(proj_path, "run_step.R")))
  
  # Verificar cabecera de procedencia
  step1_p <- file.path(proj_path, "scripts", "01_1_byod_audit.R")
  expect_true(file.exists(step1_p))
  p_lines <- readLines(step1_p, encoding = "UTF-8")
  expect_true(any(grepl("PROVENANCE METADATA", p_lines)))
  expect_true(any(grepl("TEMPLATE_VERSION: 2.0.0", p_lines)))
})

test_that("00_audit_diff.R identifies intact vs adapted project scripts", {
  test_proj <- "test_diff_project"
  proj_path <- file.path("projects", test_proj)
  on.exit(unlink(proj_path, recursive = TRUE), add = TRUE)
  
  # Crear proyecto
  project_name <<- test_proj
  source("02_scripts/00_new_project.R", local = new.env())
  
  # Auditar proyecto intacto
  res_intact <- capture.output({
    project_name <<- test_proj
    source("02_scripts/00_audit_diff.R", local = new.env())
  })
  expect_true(any(grepl("\\[INTACTO\\].*01_1_byod_audit.R", res_intact)))
  
  # Modificar un bloque ADAPT en el proyecto
  step1_path <- file.path(proj_path, "scripts", "01_1_byod_audit.R")
  lines <- readLines(step1_path, encoding = "UTF-8")
  tag_idx <- grep(">>> ADAPT:column_mapping", lines)
  lines[tag_idx + 1] <- paste0("# Parche de prueba adaptado por IA\n", lines[tag_idx + 1])
  writeLines(lines, step1_path)
  
  # Re-auditar
  res_adapted <- capture.output({
    project_name <<- test_proj
    source("02_scripts/00_audit_diff.R", local = new.env())
  })
  expect_true(any(grepl("\\[ADAPTADO\\].*01_1_byod_audit.R", res_adapted)))
  expect_true(any(grepl("Bloque modificado: \\[ADAPT:column_mapping\\]", res_adapted)))
})
