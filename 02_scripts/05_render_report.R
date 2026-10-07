# ==============================================================================
# DSM-Harness | 05_render_report.R: Renderizado de Reporte Final por Variable
# ==============================================================================
# OBJETIVO:
# Generar un reporte HTML autocontenido (standalone) y de alta calidad visual
# para la variable mapeada, documentando sitios de observación, distribución
# de valores, hiperparámetros y métricas QRF, validación cruzada con recta 1:1,
# mapas finales OpenNSIS (media e incertidumbre SD) y log de auditoría.
#
# ARCHIVOS DE ENTRADA:
# 1. Datos con covariables:   'step2_covariates.csv'
# 2. Modelo entrenado:        'ranger_model_<propiedad>.rds'
# 3. Métricas (opcional):     'metrics_<propiedad>.json'
# 4. Mapas COG OpenNSIS:      '<CC>-<PROJ>-<PROP>-<d1>-<d2>-mean.tif' y '-sd.tif'
# 5. Gráfico Boruta:          'boruta_<propiedad>.png'
# 6. Log de decisiones:       'decisions_log.csv'
#
# ARCHIVOS DE SALIDA:
# 1. Reporte HTML:            'reports/report_<CC>-<PROJ>-<PROP>-<d1>-<d2>.html'
# 2. Resumen complementario:  'reports/step5_report_summary.txt'
#
# INSTRUCCIONES PARA EL ALUMNO:
# 1. Asegúrate de haber ejecutado los Pasos 1, 2, 3 y 4.
# 2. Ejecuta este script mediante run_step("5") o en RStudio (Source / Ctrl+Shift+S).
# 3. Abre el archivo HTML generado en tu navegador web para inspeccionar el informe.
# ==============================================================================

TEMPLATE_VERSION <- "2.0.0"

rm(list = setdiff(ls(), c("input_file", "input_csv", "TEMPLATE_VERSION", "PROJECT_DIR", "CURRENT_PROJECT_DIR", "PROJECT_NAME", "run_step")))

suppressPackageStartupMessages({
  library(rmarkdown)
  library(knitr)
  library(ggplot2)
  library(terra)
  library(dplyr)
})

# 1. Configuración de rutas y proyecto -----------------------------------------
proj_active <- if (exists("PROJECT_DIR") && !is.null(PROJECT_DIR) && nzchar(as.character(PROJECT_DIR))) {
  as.character(PROJECT_DIR)
} else if (exists("CURRENT_PROJECT_DIR") && !is.null(CURRENT_PROJECT_DIR) && nzchar(as.character(CURRENT_PROJECT_DIR))) {
  as.character(CURRENT_PROJECT_DIR)
} else if (dir.exists("data") && dir.exists("reports")) {
  "."
} else {
  NULL
}

if (!is.null(proj_active)) {
  base_data_dir <- file.path(proj_active, "data")
  base_rep_dir  <- file.path(proj_active, "reports")
  base_out_dir  <- file.path(proj_active, "outputs")
  config_file   <- file.path(proj_active, "config.json")
  decisions_log <- file.path(proj_active, "decisions_log.csv")
  proj_name     <- if (exists("PROJECT_NAME") && !is.null(PROJECT_NAME) && nzchar(as.character(PROJECT_NAME))) {
    as.character(PROJECT_NAME)
  } else {
    basename(normalizePath(proj_active))
  }
} else {
  base_data_dir <- "01_data/profiles"
  base_rep_dir  <- "01_data/profiles"
  base_out_dir  <- "03_outputs/module3/maps"
  config_file   <- "01_data/profiles/user_config.json"
  decisions_log <- "01_data/profiles/decisions_log.csv"
  proj_name     <- "default"
}

run_id <- sprintf("R-%s-%04d", format(Sys.time(), "%Y%m%d"), sample(1:9999, 1))
decision_logged <- FALSE

# 2. Función de registro de auditoría ------------------------------------------
record_decision <- function(step, criterion, decision, source = "script_default", affected_rows = 0, affected_profiles = 0, details = "") {
  entry <- data.frame(
    timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    run_id = run_id,
    step = as.character(step),
    criterion = criterion,
    user_decision = decision,
    source = source,
    affected_rows = as.integer(affected_rows),
    affected_profiles = as.integer(affected_profiles),
    details = details,
    template_version = TEMPLATE_VERSION,
    stringsAsFactors = FALSE
  )
  if (!file.exists(decisions_log)) {
    write.table(entry, decisions_log, sep = ",", row.names = FALSE, col.names = TRUE, qmethod = "double")
  } else {
    write.table(entry, decisions_log, sep = ",", row.names = FALSE, col.names = FALSE, append = TRUE, qmethod = "double")
  }
  decision_logged <<- TRUE
}

# 3. Cargar configuración de usuario ------------------------------------------
user_cfg <- list()
if (file.exists(config_file)) {
  tryCatch({
    if (requireNamespace("jsonlite", quietly = TRUE)) {
      user_cfg <- jsonlite::fromJSON(config_file, simplifyVector = FALSE)
      cat(sprintf("[*] Configuración cargada desde: '%s'\n", config_file))
    }
  }, error = function(e) {
    cat(sprintf("[AVISO] No se pudo parsear '%s': %s\n", config_file, e$message))
  })
}

target_prop  <- if (!is.null(user_cfg$target_property)) as.character(user_cfg$target_property) else "SOC"
depth_d1     <- if (!is.null(user_cfg$target_depth_upper)) as.integer(user_cfg$target_depth_upper) else 0
depth_d2     <- if (!is.null(user_cfg$target_depth_lower)) as.integer(user_cfg$target_depth_lower) else 30
target_unit  <- if (!is.null(user_cfg$target_unit)) as.character(user_cfg$target_unit) else ""
country_code <- if (!is.null(user_cfg$country_code) && nzchar(as.character(user_cfg$country_code))) toupper(as.character(user_cfg$country_code)) else "PAIS"
project_code <- if (!is.null(user_cfg$project_code) && nzchar(as.character(user_cfg$project_code))) toupper(as.character(user_cfg$project_code)) else "PROJ"

tag <- sprintf("%s-%s-%s-%d-%d", country_code, project_code, target_prop, depth_d1, depth_d2)
output_html <- file.path(base_rep_dir, sprintf("report_%s.html", tag))
output_txt  <- file.path(base_rep_dir, "step5_report_summary.txt")

# 4. Localizar plantilla R Markdown -------------------------------------------
rmd_candidates <- c(
  if (!is.null(proj_active)) file.path(proj_active, "scripts", "05_variable_report.Rmd") else NULL,
  file.path("02_scripts", "05_variable_report.Rmd"),
  "05_variable_report.Rmd"
)
rmd_template <- NULL
for (rc in rmd_candidates) {
  if (!is.null(rc) && file.exists(rc)) {
    rmd_template <- rc
    break
  }
}

if (is.null(rmd_template)) {
  stop("No se encontro la plantilla '05_variable_report.Rmd' en 'scripts/' ni en '02_scripts/'.")
}

cat(sprintf("[*] Generando reporte final con plantilla: '%s'\n", rmd_template))
cat(sprintf("  - Variable:     %s (%d-%d cm)\n", target_prop, depth_d1, depth_d2))
cat(sprintf("  - Pais/Proj:    %s / %s\n", country_code, project_code))
cat(sprintf("  - Destino HTML: %s\n", output_html))

# 5. Pre-evaluación de datos y renderizado con rmarkdown -----------------------
dir.create(base_rep_dir, recursive = TRUE, showWarnings = FALSE)

n_rows_dat <- 0
f_cov_check <- file.path(base_data_dir, "step2_covariates.csv")
if (file.exists(f_cov_check)) {
  tryCatch({
    n_rows_dat <- nrow(read.csv(f_cov_check, stringsAsFactors = FALSE))
  }, error = function(e) NULL)
}

root_dir <- normalizePath(".", winslash = "/", mustWork = FALSE)
proj_dir_normalized <- if (!is.null(proj_active)) {
  normalizePath(proj_active, winslash = "/", mustWork = FALSE)
} else {
  root_dir
}

render_params <- list(
  project = proj_name,
  project_dir = proj_dir_normalized,
  cc = country_code,
  proj = project_code,
  property = target_prop,
  d1 = depth_d1,
  d2 = depth_d2,
  unit = target_unit
)

res_render <- tryCatch({
  rmarkdown::render(
    input = rmd_template,
    output_file = basename(output_html),
    output_dir = dirname(output_html),
    knit_root_dir = root_dir,
    params = render_params,
    quiet = TRUE,
    envir = new.env()
  )
}, error = function(e) {
  stop(sprintf("Error al renderizar el reporte R Markdown: %s", e$message))
})

# Validación post-render: asegurar que el HTML no se haya generado vacío
if (!file.exists(output_html) || file.size(output_html) == 0) {
  stop(sprintf("El archivo de reporte HTML '%s' no se generó o está vacío.", output_html))
}

html_lines <- readLines(output_html, encoding = "UTF-8", warn = FALSE)
if (n_rows_dat > 0 && any(grepl("Perfiles usados</span><b>0</b>", html_lines, fixed = TRUE))) {
  stop(sprintf("El reporte HTML se generó sin perfiles ('Perfiles usados: 0') a pesar de existir %d filas en '%s'. Verifica las rutas y knit_root_dir.",
               n_rows_dat, f_cov_check))
}

cat(sprintf("[OK] Reporte HTML generado: '%s' (%.1f KB)\n", output_html, file.size(output_html) / 1024))

# >>> ADAPT:render_report
# Punto de extension: adicion de formatos de salida (PDF, DOCX), subida a repositorio o metadatos extras.
# Objetos disponibles: output_html (character), render_params (list), record_decision (function)
# <<< ADAPT:render_report

# 6. Registrar en auditoria ----------------------------------------------------
record_decision(
  step = 5.0,
  criterion = "Reporte final de mapeo",
  decision = sprintf("Reporte HTML generado: %s", basename(output_html)),
  source = "script_default",
  affected_rows = n_rows_dat,
  affected_profiles = n_rows_dat,
  details = sprintf("Tag: %s | Formato: HTML autocontenido", tag)
)

# 7. Generar reporte complementario .txt ---------------------------------------
rep_con <- file(output_txt, open = "wt", encoding = "UTF-8")
writeLines("================================================================================", rep_con)
writeLines("DSM-HARNESS | REPORTE RESUMEN DEL INFORME FINAL DE MAPEO (PASO 5)", rep_con)
writeLines(sprintf("Fecha de ejecucion: %s | Run ID: %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), run_id), rep_con)
writeLines("================================================================================", rep_con)
writeLines(sprintf("Variable mapeada:              %s", target_prop), rep_con)
writeLines(sprintf("Intervalo de profundidad:      %d a %d cm", depth_d1, depth_d2), rep_con)
writeLines(sprintf("Codigo de pais / proyecto:     %s / %s", country_code, project_code), rep_con)
writeLines(sprintf("Etiqueta OpenNSIS (Tag):       %s", tag), rep_con)
writeLines(sprintf("Archivo HTML generado:         %s", basename(output_html)), rep_con)
writeLines(sprintf("Tamano del archivo HTML:       %.1f KB", file.size(output_html) / 1024), rep_con)
writeLines("--------------------------------------------------------------------------------", rep_con)
writeLines("ESTADO DE ARTEFACTOS EVALUADOS:", rep_con)

f_mean_cog <- file.path(base_out_dir, paste0(tag, "-mean.tif"))
f_sd_cog   <- file.path(base_out_dir, paste0(tag, "-sd.tif"))
f_model    <- file.path(base_out_dir, sprintf("ranger_model_%s.rds", target_prop))
f_boruta   <- file.path(base_rep_dir, sprintf("boruta_%s.png", target_prop))
f_metrics  <- file.path(base_out_dir, sprintf("metrics_%s.json", target_prop))

writeLines(sprintf("  Dataset de entrenamiento:    %s", if (file.exists(f_cov_check)) sprintf("PRESENTE (%d filas)", n_rows_dat) else "NO EVALUADO"), rep_con)
writeLines(sprintf("  Modelo QRF (ranger):         %s", if (file.exists(f_model)) "PRESENTE" else "NO EVALUADO"), rep_con)
writeLines(sprintf("  Metricas JSON:               %s", if (file.exists(f_metrics)) "PRESENTE" else "NO EVALUADO"), rep_con)
writeLines(sprintf("  Grafico Boruta:              %s", if (file.exists(f_boruta)) "PRESENTE" else "NO EVALUADO"), rep_con)
writeLines(sprintf("  Mapa Media OpenNSIS COG:     %s", if (file.exists(f_mean_cog)) basename(f_mean_cog) else "NO EVALUADO"), rep_con)
writeLines(sprintf("  Mapa Incertidumbre OpenNSIS: %s", if (file.exists(f_sd_cog)) basename(f_sd_cog) else "NO EVALUADO"), rep_con)
writeLines("--------------------------------------------------------------------------------", rep_con)
writeLines("LINEA DE VALIDACION:", rep_con)
writeLines("  La linea roja en el scatterplot es estrictamente la recta 1:1 (predicho = observado),", rep_con)
writeLines("  NO una regresion empirica de los puntos.", rep_con)
writeLines("  Validacion con muestra independiente: NO EVALUADO.", rep_con)
writeLines("================================================================================", rep_con)
close(rep_con)

cat(sprintf("[OK] Resumen de reporte escrito en: '%s'\n", output_txt))

# 8. Resumen en consola --------------------------------------------------------
cat("\n==============================================================================\n")
cat("  RESUMEN DE GENERACIÓN DE REPORTE FINAL (Paso 5)\n")
cat("==============================================================================\n")
cat(sprintf("Variable mapeada:    %s (%d-%d cm)\n", target_prop, depth_d1, depth_d2))
cat(sprintf("País / Proyecto:     %s / %s\n", country_code, project_code))
cat(sprintf("Tag OpenNSIS:        %s\n", tag))
cat(sprintf("[OK] Reporte HTML:   %s\n", output_html))
cat(sprintf("[OK] Resumen TXT:    %s\n", output_txt))
if (decision_logged) cat(sprintf("[OK] Log decisiones: %s\n", decisions_log))
cat("==============================================================================\n\n")
