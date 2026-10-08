# ==============================================================================
# DSM-Harness | 00_new_project.R: Creador de Proyectos de Alumno Aislados
# ==============================================================================
# OBJETIVO:
# Crear un entorno de proyecto aislado ('projects/<nombre>/') donde el alumno
# tiene copias independientes de los scripts de trabajo, su propia carpeta de datos,
# outputs, configuración y log de decisiones.
#
# Las plantillas maestras en '02_scripts/' permanecen 100% intactas.
# Los scripts del proyecto pueden ser adaptados mediante parches mínimos en sus
# bloques delimitados (# >>> ADAPT:...), ahorrando tokens y preservando procedencia.
#
# INSTRUCCIONES:
# Ejecuta este script en RStudio (Source o Ctrl+Shift+S) y define el nombre.
# ==============================================================================

TEMPLATE_VERSION <- "2.0.0"

cat("\n==============================================================================\n")
cat("  DSM-HARNESS | GENERADOR DE PROYECTO DE TRABAJO (v2.0)\n")
cat("==============================================================================\n\n")

if (!exists("project_name") || is.null(project_name) || !nzchar(project_name)) {
  if (interactive()) {
    p_input <- readline(prompt = "Ingresa el nombre para tu proyecto / Project name (ej: suelo_nacional_gtm): ")
    project_name <- trimws(p_input)
  } else {
    project_name <- "mi_proyecto_suelos"
  }
}

if (!exists("project_language") || is.null(project_language) || !(project_language %in% c("es", "en"))) {
  if (interactive()) {
    p_lang <- readline(prompt = "Idioma del proyecto / Project language ([es]/en): ")
    project_language <- if (tolower(trimws(p_lang)) == "en") "en" else "es"
  } else {
    project_language <- "es"
  }
}

# Sanitizar nombre
project_name <- gsub("[^[:alnum:]_]", "_", tolower(project_name))
if (!nzchar(project_name)) project_name <- "mi_proyecto_suelos"

proj_dir     <- file.path("projects", project_name)
data_dir     <- file.path(proj_dir, "data")
scripts_dir  <- file.path(proj_dir, "scripts")
outputs_dir  <- file.path(proj_dir, "outputs")
reports_dir    <- file.path(proj_dir, "reports")
covariates_dir <- file.path(proj_dir, "covariates")

is_en <- identical(project_language, "en")

if (is_en) {
  cat(sprintf("[*] Creating project structure in: '%s' ...\n", proj_dir))
} else {
  cat(sprintf("[*] Creando estructura de proyecto en: '%s' ...\n", proj_dir))
}
dir.create(data_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(scripts_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(outputs_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(reports_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(covariates_dir, recursive = TRUE, showWarnings = FALSE)

# Crear .gitkeep
file.create(file.path(data_dir, ".gitkeep"))
file.create(file.path(outputs_dir, ".gitkeep"))
file.create(file.path(reports_dir, ".gitkeep"))
file.create(file.path(covariates_dir, ".gitkeep"))

# 1. Copiar y estampar procedencia en scripts ----------------------------------
source_scripts <- c(
  "00_i18n.R",
  "00_inspect_data.R",
  "01_1_byod_audit.R",
  "01_2_byod_audit.R",
  "01_3_byod_audit.R",
  "02_extract_covariates.R",
  "03_spatial_modelling.R",
  "04_predict_and_cog.R",
  "05_render_report.R"
)

for (s_file in source_scripts) {
  src_path <- file.path("02_scripts", s_file)
  dst_path <- file.path(scripts_dir, s_file)
  
  if (file.exists(src_path)) {
    orig_lines <- readLines(src_path, encoding = "UTF-8", warn = FALSE)
    
    # Crear cabecera de procedencia estampando PROJECT_DIR de forma nativa
    prov_header <- c(
      paste0("# --- PROVENANCE METADATA: PROJECT '", project_name, "' ---"),
      paste0("# TEMPLATE_VERSION: ", TEMPLATE_VERSION),
      paste0("# COPIED_FROM:      ", src_path),
      paste0("# CREATED_AT:       ", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
      "# ADAPTED_BLOCKS:   None (Original template copy)",
      paste0("PROJECT_DIR <- '", proj_dir, "'"),
      "# ------------------------------------------------------------------------------"
    )
    
    script_content <- c(prov_header, orig_lines)
    writeLines(script_content, dst_path, useBytes = FALSE)
    if (is_en) {
      cat(sprintf("  -> Script instantiated: %s\n", dst_path))
    } else {
      cat(sprintf("  -> Script instanciado: %s\n", dst_path))
    }
  }
}

# Copiar plantilla R Markdown de reporte final como artefacto no ejecutable R
rmd_master <- file.path("02_scripts", "05_variable_report.Rmd")
if (file.exists(rmd_master)) {
  file.copy(rmd_master, file.path(scripts_dir, "05_variable_report.Rmd"), overwrite = TRUE)
  if (is_en) {
    cat(sprintf("  -> Rmd template instantiated: %s\n", file.path(scripts_dir, "05_variable_report.Rmd")))
  } else {
    cat(sprintf("  -> Plantilla Rmd instanciada: %s\n", file.path(scripts_dir, "05_variable_report.Rmd")))
  }
}

# 2. Inicializar config.json del proyecto --------------------------------------
template_cfg <- "01_data/profiles/user_config.template.json"
proj_cfg     <- file.path(proj_dir, "config.json")

if (file.exists(template_cfg) && requireNamespace("jsonlite", quietly = TRUE)) {
  cfg_obj <- jsonlite::fromJSON(template_cfg, simplifyVector = FALSE)
  cfg_obj$language <- project_language
  cfg_obj$`_comment` <- if (project_language == "en") {
    sprintf("Project configuration: %s (TEMPLATE v%s)", project_name, TEMPLATE_VERSION)
  } else {
    sprintf("Configuración de proyecto: %s (TEMPLATE v%s)", project_name, TEMPLATE_VERSION)
  }
  cfg_obj$input_file <- sprintf("projects/%s/data/perfiles.xlsx", project_name)
  jsonlite::write_json(cfg_obj, proj_cfg, auto_unbox = TRUE, pretty = TRUE)
  if (is_en) {
    cat(sprintf("[*] Initial configuration created: '%s'\n", proj_cfg))
  } else {
    cat(sprintf("[*] Configuración inicial creada: '%s'\n", proj_cfg))
  }
}

# 3. Inicializar decisions_log.csv del proyecto --------------------------------
proj_log <- file.path(proj_dir, "decisions_log.csv")
log_header <- "timestamp,run_id,step,criterion,user_decision,source,affected_rows,affected_profiles,details,template_version\n"
cat(log_header, file = proj_log)
if (is_en) {
  cat(sprintf("[*] Audit log initialized: '%s'\n", proj_log))
} else {
  cat(sprintf("[*] Log de auditoría inicializado: '%s'\n", proj_log))
}

# 4. Crear ejecutor de conveniencia run_step.R ---------------------------------
is_en <- identical(project_language, "en")
step_exec_msg <- if (is_en) "\\n[>>> EXECUTING STEP %s] %s ...\\n" else "\\n[>>> EJECUTANDO PASO %s] %s ...\\n"
env_loaded_msg <- if (is_en) "\\n[*] Environment loaded for project: \"%s\"\\n" else "\\n[*] Entorno cargado para proyecto: \"%s\"\\n"
avail_cmd_hdr <- if (is_en) "Available commands:\\n" else "Comandos disponibles:\\n"
cmds_list <- if (is_en) c(
  "  run_step(\"0\")   -> Structural data inspection\\n",
  "  run_step(\"1.1\") -> Variable mapping and selection\\n",
  "  run_step(\"1.2\") -> Spatial audit and CRS\\n",
  "  run_step(\"1.3\") -> Depths and pedological consistency\\n",
  "  run_step(\"2\")   -> Environmental covariate extraction\\n",
  "  run_step(\"3\")   -> QRF modeling and cross-validation\\n",
  "  run_step(\"4\")   -> Spatial prediction and COG export\\n",
  "  run_step(\"5\")   -> Final parameterized HTML report\\n\\n"
) else c(
  "  run_step(\"0\")   -> Inspección estructural\\n",
  "  run_step(\"1.1\") -> Mapeo y selección de variables\\n",
  "  run_step(\"1.2\") -> Auditoría espacial y CRS\\n",
  "  run_step(\"1.3\") -> Profundidades y coherencia edafológica\\n",
  "  run_step(\"2\")   -> Extracción de covariables ambientales\\n",
  "  run_step(\"3\")   -> Modelado QRF y validación cruzada\\n",
  "  run_step(\"4\")   -> Predicción espacial y exportación COG\\n",
  "  run_step(\"5\")   -> Reporte final en HTML parametrizado\\n\\n"
)

run_step_code <- c(
  paste0("# DSM-Harness | ", if (is_en) "Step runner for: " else "Ejecutor de pasos para: ", project_name),
  paste0("PROJECT_NAME <- '", project_name, "'"),
  paste0("PROJECT_LANGUAGE <- '", project_language, "'"),
  paste0("CURRENT_PROJECT_DIR <- '", proj_dir, "'"),
  paste0("PROJECT_DIR <- '", proj_dir, "'"),
  "",
  "run_step <- function(step = '0') {",
  "  s_map <- list(",
  "    '0'   = '00_inspect_data.R',",
  "    '1.1' = '01_1_byod_audit.R',",
  "    '1.2' = '01_2_byod_audit.R',",
  "    '1.3' = '01_3_byod_audit.R',",
  "    '2'   = '02_extract_covariates.R',",
  "    '3'   = '03_spatial_modelling.R',",
  "    '4'   = '04_predict_and_cog.R',",
  "    '5'   = '05_render_report.R'",
  "  )",
  "  step_char <- as.character(step)",
  "  if (!(step_char %in% names(s_map))) {",
  sprintf("    stop(sprintf('%s \"%%s\". %s: %%s', step_char, paste(names(s_map), collapse = ', ')))",
          if (is_en) "Unknown step" else "Paso desconocido",
          if (is_en) "Options" else "Opciones"),
  "  }",
  "  s_file <- file.path('projects', PROJECT_NAME, 'scripts', s_map[[step_char]])",
  sprintf("  cat(sprintf('%s', step_char, s_file))", step_exec_msg),
  "  CURRENT_PROJECT_DIR <<- file.path('projects', PROJECT_NAME)",
  "  PROJECT_DIR <<- file.path('projects', PROJECT_NAME)",
  "  source(s_file, local = FALSE)",
  "}",
  "",
  sprintf("cat(sprintf('%s', PROJECT_NAME))", env_loaded_msg),
  sprintf("cat('%s')", avail_cmd_hdr),
  paste0("cat('", paste(cmds_list, collapse = "')\ncat('"), "')")
)
writeLines(run_step_code, file.path(proj_dir, "run_step.R"))

if (is_en) {
  cat(sprintf("[*] Step runner created: '%s'\n", file.path(proj_dir, "run_step.R")))
  cat("\n==============================================================================\n")
  cat("  [OK] PROJECT CREATED SUCCESSFULLY\n")
  cat("==============================================================================\n")
  cat(sprintf("Project directory:  %s/\n", proj_dir))
  cat(sprintf("1. Place your data file in:  projects/%s/data/\n", project_name))
  cat(sprintf("2. To run a step, open in RStudio and execute:\n"))
  cat(sprintf("   source('projects/%s/run_step.R')\n", project_name))
  cat(sprintf("   run_step('0')\n"))
  cat("==============================================================================\n\n")
} else {
  cat(sprintf("[*] Ejecutor de conveniencia creado: '%s'\n", file.path(proj_dir, "run_step.R")))
  cat("\n==============================================================================\n")
  cat("  [OK] PROYECTO CREADO EXITOSAMENTE\n")
  cat("==============================================================================\n")
  cat(sprintf("Directorio del proyecto:  %s/\n", proj_dir))
  cat(sprintf("1. Coloca tu archivo de datos en:  projects/%s/data/\n", project_name))
  cat(sprintf("2. Para ejecutar un paso, abre en RStudio y corre:\n"))
  cat(sprintf("   source('projects/%s/run_step.R')\n", project_name))
  cat(sprintf("   run_step('0')\n"))
  cat("==============================================================================\n\n")
}
