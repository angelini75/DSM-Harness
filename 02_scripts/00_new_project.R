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
    p_input <- readline(prompt = "Ingresa el nombre para tu proyecto (ej: suelo_nacional_gtm): ")
    project_name <- trimws(p_input)
  } else {
    project_name <- "mi_proyecto_suelos"
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

cat(sprintf("[*] Creando estructura de proyecto en: '%s' ...\n", proj_dir))
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
    cat(sprintf("  -> Script instanciado: %s\n", dst_path))
  }
}

# Copiar plantilla R Markdown de reporte final como artefacto no ejecutable R
rmd_master <- file.path("02_scripts", "05_variable_report.Rmd")
if (file.exists(rmd_master)) {
  file.copy(rmd_master, file.path(scripts_dir, "05_variable_report.Rmd"), overwrite = TRUE)
  cat(sprintf("  -> Plantilla Rmd instanciada: %s\n", file.path(scripts_dir, "05_variable_report.Rmd")))
}

# 2. Inicializar config.json del proyecto --------------------------------------
template_cfg <- "01_data/profiles/user_config.template.json"
proj_cfg     <- file.path(proj_dir, "config.json")

if (file.exists(template_cfg) && requireNamespace("jsonlite", quietly = TRUE)) {
  cfg_obj <- jsonlite::fromJSON(template_cfg, simplifyVector = FALSE)
  cfg_obj$`_comment` <- sprintf("Configuración de proyecto: %s (TEMPLATE v%s)", project_name, TEMPLATE_VERSION)
  cfg_obj$input_file <- sprintf("projects/%s/data/perfiles.xlsx", project_name)
  jsonlite::write_json(cfg_obj, proj_cfg, auto_unbox = TRUE, pretty = TRUE)
  cat(sprintf("[*] Configuración inicial creada: '%s'\n", proj_cfg))
}

# 3. Inicializar decisions_log.csv del proyecto --------------------------------
proj_log <- file.path(proj_dir, "decisions_log.csv")
log_header <- "timestamp,run_id,step,criterion,user_decision,source,affected_rows,affected_profiles,details,template_version\n"
cat(log_header, file = proj_log)
cat(sprintf("[*] Log de auditoría inicializado: '%s'\n", proj_log))

# 4. Crear ejecutor de conveniencia run_step.R ---------------------------------
run_step_code <- c(
  paste0("# DSM-Harness | Ejecutor de pasos para: ", project_name),
  paste0("PROJECT_NAME <- '", project_name, "'"),
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
  "    stop(sprintf('Paso desconocido \"%s\". Opciones: %s', step_char, paste(names(s_map), collapse = ', ')))",
  "  }",
  "  s_file <- file.path('projects', PROJECT_NAME, 'scripts', s_map[[step_char]])",
  "  cat(sprintf('\\n[>>> EJECUTANDO PASO %s] %s ...\\n', step_char, s_file))",
  "  CURRENT_PROJECT_DIR <<- file.path('projects', PROJECT_NAME)",
  "  PROJECT_DIR <<- file.path('projects', PROJECT_NAME)",
  "  source(s_file, local = FALSE)",
  "}",
  "",
  sprintf("cat('\\n[*] Entorno cargado para proyecto: \"%s\"\\n')", project_name),
  "cat('Comandos disponibles:\\n')",
  "cat('  run_step(\"0\")   -> Inspección estructural\\n')",
  "cat('  run_step(\"1.1\") -> Mapeo y selección de variables\\n')",
  "cat('  run_step(\"1.2\") -> Auditoría espacial y CRS\\n')",
  "cat('  run_step(\"1.3\") -> Profundidades y coherencia edafológica\\n')",
  "cat('  run_step(\"2\")   -> Extracción de covariables ambientales\\n')",
  "cat('  run_step(\"3\")   -> Modelado QRF y validación cruzada\\n')",
  "cat('  run_step(\"4\")   -> Predicción espacial y exportación COG\\n')",
  "cat('  run_step(\"5\")   -> Reporte final en HTML parametrizado\\n\\n')"
)
writeLines(run_step_code, file.path(proj_dir, "run_step.R"))
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
