# ==============================================================================
# DSM-Harness | Paso 2: Intersección y Extracción de Covariables Ambientales
# ==============================================================================
# OBJETIVO:
# Cargar el dataset auditado ('data/cleaned_profiles.csv'), armonizar el CRS con
# la pila de covariables ambientales (SCORPAN), filtrar anomalías espaciales
# según configuración, estandarizar a la profundidad objetivo y extraer los
# valores de las covariables en cada perfil de suelo.
#
# SALIDAS GENERADAS:
# 1. Dataset con covariables: 'data/step2_covariates.csv'
# 2. Reporte descriptivo:     'reports/step2_covariates_report.txt'
# 3. Log de decisiones:       'decisions_log.csv'
#
# INSTRUCCIONES PARA EL ALUMNO:
# 1. Asegúrate de colocar tus rásters de covariables en 'projects/<nombre>/covariates/'
#    o en '01_data/covariates/'.
# 2. Ejecuta este script en RStudio (Source o Ctrl+Shift+S) o mediante run_step("2").
# 3. Dialoga con la IA en el chat sobre las covariables extraídas y perfiles válidos.
# ==============================================================================

TEMPLATE_VERSION <- "2.0.0"

rm(list = setdiff(ls(), c("input_file", "input_csv", "TEMPLATE_VERSION", "PROJECT_DIR", "CURRENT_PROJECT_DIR", "PROJECT_NAME", "run_step")))

suppressWarnings(suppressPackageStartupMessages({
  library(tidyverse)
  library(terra)
  library(sf)
}))

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
  base_cov_dir  <- file.path(proj_active, "covariates")
  config_file   <- file.path(proj_active, "config.json")
  decisions_log <- file.path(proj_active, "decisions_log.csv")
} else {
  base_data_dir <- "01_data/profiles"
  base_rep_dir  <- "01_data/profiles"
  base_out_dir  <- "03_outputs/module3"
  base_cov_dir  <- "01_data/covariates"
  config_file   <- "01_data/profiles/user_config.json"
  decisions_log <- "01_data/profiles/decisions_log.csv"
}

if (!dir.exists(base_data_dir)) dir.create(base_data_dir, recursive = TRUE)
if (!dir.exists(base_rep_dir))  dir.create(base_rep_dir, recursive = TRUE)
if (!dir.exists(base_out_dir))  dir.create(base_out_dir, recursive = TRUE)
if (!dir.exists(base_cov_dir))  dir.create(base_cov_dir, recursive = TRUE)

input_csv     <- file.path(base_data_dir, "cleaned_profiles.csv")
output_csv    <- file.path(base_data_dir, "step2_covariates.csv")
output_report <- file.path(base_rep_dir,  "step2_covariates_report.txt")

# Carga de motor i18n
i18n_candidates <- c(
  if (!is.null(proj_active)) file.path(proj_active, "scripts", "00_i18n.R"),
  if (!is.null(proj_active)) file.path(proj_active, "00_i18n.R"),
  if (!is.null(proj_active)) file.path(proj_active, "02_scripts", "00_i18n.R"),
  "02_scripts/00_i18n.R",
  "scripts/00_i18n.R",
  "00_i18n.R"
)
for (cand in i18n_candidates) {
  if (!is.null(cand) && file.exists(cand)) {
    tryCatch(source(cand, local = FALSE), error = function(e) NULL)
    break
  }
}

# 2. Inicialización de Trazabilidad y Log de Decisiones ------------------------
run_id <- format(Sys.time(), "%Y%m%d_%H%M%S")
decision_logged <- FALSE

lang <- if (exists("get_project_language")) get_project_language() else "es"
is_en <- identical(lang, "en")

record_decision <- function(step, criterion, decision, source = "user_config",
                            affected_rows = 0, affected_profiles = 0, details = "") {
  if (is_en && exists("translate_decision_text")) {
    criterion <- translate_decision_text(criterion, "en")
    decision  <- translate_decision_text(decision, "en")
    details   <- translate_decision_text(details, "en")
  }
  entry <- data.frame(
    timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    run_id = run_id,
    step = as.character(step),
    criterion = as.character(criterion),
    user_decision = as.character(decision),
    source = as.character(source),
    affected_rows = as.integer(affected_rows),
    affected_profiles = as.integer(affected_profiles),
    details = as.character(details),
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
      if (exists("get_project_language")) {
        lang <- get_project_language(user_cfg)
        is_en <- identical(lang, "en")
      }
      if (is_en) {
        cat(sprintf("[*] Configuration loaded from: '%s'\n", config_file))
      } else {
        cat(sprintf("[*] Configuración cargada desde: '%s'\n", config_file))
      }
    }
  }, error = function(e) {
    if (is_en) cat(sprintf("[NOTICE] Could not parse '%s': %s\n", config_file, e$message)) else cat(sprintf("[AVISO] No se pudo parsear '%s': %s\n", config_file, e$message))
  })
}

# 4. Cargar dataset auditado (cleaned_profiles.csv) -----------------------------
if (!file.exists(input_csv)) {
  if (is_en) {
    stop(sprintf("[CRITICAL ERROR] Audited dataset not found at '%s'.\nPlease run Step 1.3 first (run_step('1.3')).", input_csv))
  } else {
    stop(sprintf("[ERROR CRÍTICO] No se encontró el dataset auditado en '%s'.\nEjecuta primero el Paso 1.3 (run_step('1.3')).", input_csv))
  }
}

dat_raw <- readr::read_csv(input_csv, show_col_types = FALSE)
n_initial_rows <- nrow(dat_raw)
n_initial_profiles <- if ("profile_code" %in% names(dat_raw)) length(unique(dat_raw$profile_code)) else n_initial_rows
if (is_en) {
  cat(sprintf("[*] Audited dataset loaded: %d rows, %d unique profiles.\n", n_initial_rows, n_initial_profiles))
} else {
  cat(sprintf("[*] Dataset auditado cargado: %d filas, %d perfiles únicos.\n", n_initial_rows, n_initial_profiles))
}

# 5. Filtrar banderas de calidad (outliers espaciales) --------------------------
include_outliers <- isTRUE(user_cfg$include_spatial_outliers)
if ("flag_spatial_outlier" %in% names(dat_raw) && !include_outliers) {
  outliers_to_drop <- sum(dat_raw$flag_spatial_outlier, na.rm = TRUE)
  outlier_profiles_dropped <- if ("profile_code" %in% names(dat_raw)) {
    length(unique(dat_raw$profile_code[dat_raw$flag_spatial_outlier %in% TRUE]))
  } else {
    outliers_to_drop
  }
  if (outliers_to_drop > 0) {
    dat_clean <- dat_raw %>% filter(!flag_spatial_outlier)
    if (is_en) {
      cat(sprintf("[*] Quality filter applied: excluded %d records (%d profiles) with flag_spatial_outlier = TRUE.\n",
                  outliers_to_drop, outlier_profiles_dropped))
    } else {
      cat(sprintf("[*] Filtro de calidad aplicado: excluidos %d registros (%d perfiles) con flag_spatial_outlier = TRUE.\n",
                  outliers_to_drop, outlier_profiles_dropped))
    }
    record_decision(2.0, "Filtro de calidad", "Exclusión de outliers espaciales marcados",
                    source = if (!is.null(user_cfg$include_spatial_outliers)) "user_config" else "script_default",
                    affected_rows = outliers_to_drop, affected_profiles = outlier_profiles_dropped,
                    details = "Perfiles marcados en Paso 1.2 no ingresan a la extracción")
  } else {
    dat_clean <- dat_raw
  }
} else {
  dat_clean <- dat_raw
}

# 6. Estandarización de profundidad y agregación de perfiles --------------------
target_prop <- if (!is.null(user_cfg$target_property)) as.character(user_cfg$target_property) else "SOC"
if (!(target_prop %in% names(dat_clean))) {
  # Buscar alternativas comunes
  candidates <- intersect(c("SOC", "OM", "pH_H2O", "Clay", "Sand", "Silt", "BD"), names(dat_clean))
  if (length(candidates) > 0) {
    target_prop <- candidates[1]
    if (is_en) {
      cat(sprintf("[NOTICE] Target property not defined in config.json; using available: '%s'\n", target_prop))
    } else {
      cat(sprintf("[AVISO] Propiedad objetivo no definida en config.json; usando disponible: '%s'\n", target_prop))
    }
  } else {
    stop(sprintf(if (is_en) "[CRITICAL ERROR] Target variable '%s' does not exist in dataset. Available columns: [%s]" else "[ERROR CRÍTICO] La variable objetivo '%s' no existe en el dataset. Columnas disponibles: [%s]",
                 target_prop, paste(names(dat_clean), collapse = ", ")))
  }
}

depth_d1 <- if (!is.null(user_cfg$target_depth_upper)) as.numeric(user_cfg$target_depth_upper) else 0
depth_d2 <- if (!is.null(user_cfg$target_depth_lower)) as.numeric(user_cfg$target_depth_lower) else 30

if (is_en) {
  cat(sprintf("[*] Standardizing profiles for property '%s' at depth %d–%d cm ...\n", target_prop, depth_d1, depth_d2))
} else {
  cat(sprintf("[*] Estandarizando perfiles para propiedad '%s' en profundidad %d–%d cm ...\n", target_prop, depth_d1, depth_d2))
}

# Promedio ponderado por espesor de horizontes dentro del intervalo [d1, d2]
dat_std <- dat_clean %>%
  filter(!is.na(.data[[target_prop]])) %>%
  filter(!is.na(upper) & !is.na(lower) & lower > upper) %>%
  mutate(
    h_top = pmax(upper, depth_d1),
    h_bot = pmin(lower, depth_d2),
    h_thick = pmax(0, h_bot - h_top)
  ) %>%
  filter(h_thick > 0) %>%
  group_by(profile_code) %>%
  summarise(
    longitude = first(longitude),
    latitude  = first(latitude),
    support_cm = sum(h_thick),
    !!target_prop := sum(.data[[target_prop]] * h_thick) / sum(h_thick),
    .groups = "drop"
  )

min_support <- if (!is.null(user_cfg$min_depth_support_cm)) as.numeric(user_cfg$min_depth_support_cm) else 5
dat_std <- dat_std %>% filter(support_cm >= min_support)

n_std_profiles <- nrow(dat_std)
if (is_en) {
  cat(sprintf("[OK] Standardized profiles (minimum support >= %.0f cm): %d profiles.\n", min_support, n_std_profiles))
} else {
  cat(sprintf("[OK] Perfiles estandarizados (soporte mínimo >= %.0f cm): %d perfiles.\n", min_support, n_std_profiles))
}
record_decision(2.0, "Estandarización de profundidad", sprintf("Intervalo %d-%d cm ponderado por espesor", depth_d1, depth_d2),
                source = if (!is.null(user_cfg$target_depth_upper)) "user_config" else "script_default",
                affected_rows = nrow(dat_clean), affected_profiles = n_std_profiles,
                details = sprintf("Variable: %s, soporte mínimo: %.0f cm", target_prop, min_support))

# 7. Cargar pila de covariables ambientales ------------------------------------
cov_path_cfg <- if (!is.null(user_cfg$covariates_path)) as.character(user_cfg$covariates_path) else NULL

avail_covs <- if (!is.null(cov_path_cfg) && file.exists(cov_path_cfg)) {
  cov_path_cfg
} else {
  c_files <- list.files(base_cov_dir, pattern = "\\.(tif|tiff)$", full.names = TRUE, ignore.case = TRUE)
  if (length(c_files) == 0 && dir.exists("01_data/covariates")) {
    c_files <- list.files("01_data/covariates", pattern = "\\.(tif|tiff)$", full.names = TRUE, ignore.case = TRUE)
  }
  c_files
}

if (length(avail_covs) == 0) {
  stop(sprintf(if (is_en) "[CRITICAL ERROR] No covariate raster files (.tif) found in '%s' nor in '01_data/covariates/'.\nPlace your GeoTIFF covariates in that folder or specify 'covariates_path' in config.json." else "[ERROR CRÍTICO] No se encontraron archivos ráster de covariables (.tif) en '%s' ni en '01_data/covariates/'.\nColoca tus covariables GeoTIFF en dicha carpeta o especifica 'covariates_path' en config.json.", base_cov_dir))
}

if (is_en) {
  cat(sprintf("[*] Loading covariates from: [%s] ...\n", paste(basename(avail_covs), collapse = ", ")))
} else {
  cat(sprintf("[*] Cargando covariables desde: [%s] ...\n", paste(basename(avail_covs), collapse = ", ")))
}
cov_stack <- terra::rast(avail_covs)
cov_names <- names(cov_stack)
if (is_en) {
  cat(sprintf("[OK] Covariate stack: %d layers/bands. CRS: %s\n", length(cov_names), crs(cov_stack, describe = TRUE)$name))
} else {
  cat(sprintf("[OK] Pila de covariables: %d capas/bandas. CRS: %s\n", length(cov_names), crs(cov_stack, describe = TRUE)$name))
}

# 8. Proyección de puntos y extracción espacial --------------------------------
dat_pts <- terra::vect(dat_std, geom = c("longitude", "latitude"), crs = "EPSG:4326")
if (crs(dat_pts) != crs(cov_stack)) {
  if (is_en) {
    cat("[*] Reprojecting points to covariate CRS ...\n")
  } else {
    cat("[*] Reproyectando puntos al CRS de las covariables ...\n")
  }
  dat_pts <- terra::project(dat_pts, crs(cov_stack))
}

if (is_en) {
  cat("[*] Extracting covariate values at profile locations ...\n")
} else {
  cat("[*] Extrayendo valores de covariables en ubicaciones de perfiles ...\n")
}
extracted <- terra::extract(cov_stack, dat_pts, ID = FALSE)

dat_cov <- bind_cols(dat_std, as_tibble(extracted))

# Identificar perfiles fuera de la máscara ráster (covariables NA)
valid_mask <- complete.cases(dat_cov[, cov_names, drop = FALSE])
n_dropped_mask <- sum(!valid_mask)
n_final_cov <- sum(valid_mask)

if (n_dropped_mask > 0) {
  if (is_en) {
    cat(sprintf("[NOTICE] %d profiles fell outside valid covariate mask (NA values).\n", n_dropped_mask))
  } else {
    cat(sprintf("[AVISO] %d perfiles cayeron fuera de la máscara válida de covariables (valores NA).\n", n_dropped_mask))
  }
  record_decision(2.0, "Máscara de covariables", "Filtrado de puntos fuera de máscara",
                  source = "script_default", affected_rows = n_dropped_mask, affected_profiles = n_dropped_mask,
                  details = "Puntos con NA en covariables excluidos del dataset de entrenamiento")
}

dat_final <- dat_cov %>% filter(valid_mask)
if (is_en) {
  cat(sprintf("[OK] Final covariate dataset ready: %d complete profiles with %d covariates.\n",
              nrow(dat_final), length(cov_names)))
} else {
  cat(sprintf("[OK] Dataset final de covariables listo: %d perfiles completos con %d covariables.\n",
              nrow(dat_final), length(cov_names)))
}

# >>> ADAPT:covariate_extraction
# Punto de extensión: inserción de filtros de covariables o transformaciones personalizadas.
# Objetos disponibles: dat_final (tbl_df), cov_stack (SpatRaster), target_prop (character), user_cfg (list), record_decision (function)
# <<< ADAPT:covariate_extraction

# 9. Guardar dataset intermedio ------------------------------------------------
readr::write_csv(dat_final, output_csv)
if (is_en) {
  cat(sprintf("[OK] Covariate dataset saved to: '%s'\n", output_csv))
} else {
  cat(sprintf("[OK] Dataset con covariables guardado en: '%s'\n", output_csv))
}

# 10. Generar reporte complementario .txt ---------------------------------------
rep_con <- file(output_report, open = "wt", encoding = "UTF-8")
writeLines("================================================================================", rep_con)
if (is_en) {
  writeLines("DSM-HARNESS | ENVIRONMENTAL COVARIATE EXTRACTION REPORT (STEP 2)", rep_con)
  writeLines(sprintf("Execution date: %s | Run ID: %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), run_id), rep_con)
  writeLines("================================================================================", rep_con)
  writeLines(sprintf("Target property:                 %s", target_prop), rep_con)
  writeLines(sprintf("Standardized depth:              %d-%d cm", depth_d1, depth_d2), rep_con)
  writeLines(sprintf("Minimum thickness support:       %.0f cm", min_support), rep_con)
  writeLines(sprintf("Audited initial profiles:        %d", n_initial_profiles), rep_con)
  if ("flag_spatial_outlier" %in% names(dat_raw) && !include_outliers) {
    writeLines(sprintf("Profiles dropped by outlier:     %d", outlier_profiles_dropped), rep_con)
  }
  writeLines(sprintf("Profiles with sufficient support:%d", n_std_profiles), rep_con)
  writeLines(sprintf("Profiles outside raster mask:    %d", n_dropped_mask), rep_con)
  writeLines(sprintf("Final profiles with covariates:  %d", nrow(dat_final)), rep_con)
  writeLines("--------------------------------------------------------------------------------", rep_con)
  writeLines(sprintf("Number of extracted covariates:  %d", length(cov_names)), rep_con)
  writeLines(sprintf("Covariates CRS:                  %s", crs(cov_stack, describe = TRUE)$name), rep_con)
  writeLines("Available environmental covariates:", rep_con)
  for (cn in cov_names) {
    writeLines(sprintf("  - %s", cn), rep_con)
  }
} else {
  writeLines("DSM-HARNESS | REPORTE DE EXTRACCION DE COVARIABLES AMBIENTALES (PASO 2)", rep_con)
  writeLines(sprintf("Fecha de ejecucion: %s | Run ID: %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), run_id), rep_con)
  writeLines("================================================================================", rep_con)
  writeLines(sprintf("Variable objetivo:               %s", target_prop), rep_con)
  writeLines(sprintf("Profundidad estandarizada:       %d-%d cm", depth_d1, depth_d2), rep_con)
  writeLines(sprintf("Soporte minimo de espesor:       %.0f cm", min_support), rep_con)
  writeLines(sprintf("Perfiles iniciales auditados:    %d", n_initial_profiles), rep_con)
  if ("flag_spatial_outlier" %in% names(dat_raw) && !include_outliers) {
    writeLines(sprintf("Perfiles descartados por outlier: %d", outlier_profiles_dropped), rep_con)
  }
  writeLines(sprintf("Perfiles con soporte suficiente: %d", n_std_profiles), rep_con)
  writeLines(sprintf("Perfiles fuera de mascara raster:%d", n_dropped_mask), rep_con)
  writeLines(sprintf("Perfiles finales con covariable: %d", nrow(dat_final)), rep_con)
  writeLines("--------------------------------------------------------------------------------", rep_con)
  writeLines(sprintf("Numero de covariables extraidas: %d", length(cov_names)), rep_con)
  writeLines(sprintf("CRS de las covariables:          %s", crs(cov_stack, describe = TRUE)$name), rep_con)
  writeLines("Covariables ambientales disponibles:", rep_con)
  for (cn in cov_names) {
    writeLines(sprintf("  - %s", cn), rep_con)
  }
}
writeLines("================================================================================", rep_con)
close(rep_con)
if (is_en) cat(sprintf("[OK] Report written to: '%s'\n", output_report)) else cat(sprintf("[OK] Reporte escrito en: '%s'\n", output_report))

# 11. Resumen en consola -------------------------------------------------------
cat("\n==============================================================================\n")
if (is_en) {
  cat("  COVARIATE EXTRACTION SUMMARY (Step 2)\n")
  cat("==============================================================================\n")
  cat(sprintf("Target property:            %s (%d–%d cm)\n", target_prop, depth_d1, depth_d2))
  cat(sprintf("Profiles ready for modeling:%d (of %d initial)\n", nrow(dat_final), n_initial_profiles))
  cat(sprintf("Included covariates:        %d layers\n", length(cov_names)))
  cat(sprintf("[OK] Dataset saved:         %s\n", output_csv))
  cat(sprintf("[OK] Report saved:          %s\n", output_report))
  if (decision_logged) {
    cat(sprintf("[OK] Decisions log:         %s\n", decisions_log))
  }
  cat("==============================================================================\n\n")
} else {
  cat("  RESUMEN DE EXTRACCIÓN DE COVARIABLES (Paso 2)\n")
  cat("==============================================================================\n")
  cat(sprintf("Variable objetivo:          %s (%d–%d cm)\n", target_prop, depth_d1, depth_d2))
  cat(sprintf("Perfiles útiles para modelar:%d (de %d iniciales)\n", nrow(dat_final), n_initial_profiles))
  cat(sprintf("Covariables incorporadas:   %d capas\n", length(cov_names)))
  cat(sprintf("[OK] Dataset guardado:      %s\n", output_csv))
  cat(sprintf("[OK] Reporte guardado:      %s\n", output_report))
  if (decision_logged) {
    cat(sprintf("[OK] Log de decisiones:     %s\n", decisions_log))
  }
  cat("==============================================================================\n\n")
}
