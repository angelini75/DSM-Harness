# ==============================================================================
# DSM-Harness | Paso 1.2: Auditoría Espacial, Coordenadas y Outliers Geográficos
# ==============================================================================
# OBJETIVO:
# Auditar rigurosamente las coordenadas espaciales del dataset generado en el
# Paso 1.1, detectar métricas numéricas y formatos (geográficas WGS84 vs métricas
# UTM/proyectadas), identificar proyecciones, detectar outliers espaciales por
# dispersión univariada (3*IQR), advertir sobre limitaciones estadísticas,
# generar mapa diagnóstico interactivo y registrar decisiones en decisions_log.csv.
#
# SALIDAS GENERADAS:
# 1. Dataset espacial intermedio: 'data/step1_2_spatial.csv'
# 2. Reporte descriptivo espacial:'reports/step1_2_spatial_report.txt'
# 3. Log de decisiones:           'decisions_log.csv'
#
# INSTRUCCIONES PARA EL ALUMNO:
# 1. Ejecuta este script en RStudio (Source o Ctrl+Shift+S).
# 2. Observa el mapa interactivo en la pestaña 'Viewer' o 'Plots'.
# 3. Dialoga con la IA en el chat para confirmar el CRS y decidir sobre outliers.
# ==============================================================================

TEMPLATE_VERSION <- "2.0.0"

rm(list = setdiff(ls(), c("input_file", "input_csv", "TEMPLATE_VERSION", "PROJECT_DIR", "CURRENT_PROJECT_DIR", "PROJECT_NAME", "run_step")))

suppressWarnings(suppressPackageStartupMessages({
  library(tidyverse)
  library(sf)
}))

# 1. Configuración de rutas y parámetros ---------------------------------------
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
  config_file   <- file.path(proj_active, "config.json")
  decisions_log <- file.path(proj_active, "decisions_log.csv")
} else {
  base_data_dir <- "01_data/profiles"
  base_rep_dir  <- "01_data/profiles"
  config_file   <- file.path(base_data_dir, "user_config.json")
  decisions_log <- file.path(base_data_dir, "decisions_log.csv")
}

if (!exists("input_csv") || is.null(input_csv) || !nzchar(input_csv)) {
  input_csv <- file.path(base_data_dir, "step1_1_variables.csv")
}
output_csv    <- file.path(base_data_dir, "step1_2_spatial.csv")
output_report <- file.path(base_rep_dir, "step1_2_spatial_report.txt")

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

SCRIPT_RUN_ID <- format(Sys.time(), "%Y%m%d_%H%M%S")
decision_logged <- FALSE

lang <- if (exists("get_project_language")) get_project_language() else "es"
is_en <- identical(lang, "en")

record_decision <- function(step, criterion, decision, source = "user_config", affected_rows = 0, affected_profiles = 0, details = "") {
  if (is_en && exists("translate_decision_text")) {
    criterion <- translate_decision_text(criterion, "en")
    decision  <- translate_decision_text(decision, "en")
    details   <- translate_decision_text(details, "en")
  }
  log_entry <- data.frame(
    timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    run_id = SCRIPT_RUN_ID,
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
    write.csv(log_entry, decisions_log, row.names = FALSE)
  } else {
    first_line <- readLines(decisions_log, n = 1, warn = FALSE)
    if (!grepl("run_id", first_line)) {
      write.csv(log_entry, decisions_log, row.names = FALSE)
    } else {
      write.table(log_entry, decisions_log, sep = ",", col.names = FALSE, row.names = FALSE, append = TRUE)
    }
  }
  decision_logged <<- TRUE
}

# Cargar configuración de usuario si existe
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
} else {
  if (is_en) cat(sprintf("[NOTICE] No config file found at '%s'. Using default auto-detection.\n", config_file)) else cat(sprintf("[AVISO] No se encontró archivo de configuración en '%s'. Usando autodetección predeterminada.\n", config_file))
}

if (!file.exists(input_csv)) {
  if (is_en) {
    stop(sprintf("[FATAL ERROR]: Intermediate dataset '%s' not found. Please run Step 1.1 first.", input_csv))
  } else {
    stop(sprintf("[ERROR FATAL]: No se encontró el dataset intermedio '%s'. Ejecuta primero el Paso 1.1.", input_csv))
  }
}

if (is_en) {
  cat(sprintf("\n[*] Loading spatial data from: %s ...\n", input_csv))
} else {
  cat(sprintf("\n[*] Cargando datos espaciales desde: %s ...\n", input_csv))
}
dat <- readr::read_csv(input_csv, show_col_types = FALSE)
n_total <- nrow(dat)

# 2. Detección y Validación Numérica de Coordenadas -----------------------------
lon_col <- intersect(c("longitude", "x", "lon", "long", "longitud"), names(dat))
lat_col <- intersect(c("latitude", "y", "lat", "latitud"), names(dat))

if (length(lon_col) == 0 || length(lat_col) == 0) {
  if (is_en) {
    stop("[FATAL ERROR]: The dataset does not contain standard coordinate columns ('longitude'/'latitude' or 'x'/'y').")
  } else {
    stop("[ERROR FATAL]: El dataset no contiene columnas estándar de coordenadas ('longitude'/'latitude' o 'x'/'y').")
  }
}

lon_name <- lon_col[1]
lat_name <- lat_col[1]

if (lon_name != "longitude") dat$longitude <- as.numeric(dat[[lon_name]])
if (lat_name != "latitude")  dat$latitude  <- as.numeric(dat[[lat_name]])

dat$longitude <- suppressWarnings(as.numeric(dat$longitude))
dat$latitude  <- suppressWarnings(as.numeric(dat$latitude))

is_na_coord   <- is.na(dat$longitude) | is.na(dat$latitude)
is_zero_coord <- dat$longitude == 0 & dat$latitude == 0
missing_coords_count <- sum(is_na_coord)
zero_coords_count    <- sum(is_zero_coord, na.rm = TRUE)

dat_valid <- dat %>% filter(!is_na_coord & !is_zero_coord)

if (nrow(dat_valid) == 0) {
  if (is_en) {
    stop("[FATAL ERROR]: No records have valid non-zero coordinates. Spatial audit impossible.")
  } else {
    stop("[ERROR FATAL]: Ningún registro posee coordenadas válidas no nulas. Imposible realizar auditoría espacial.")
  }
}

n_profiles <- if ("profile_code" %in% names(dat)) length(unique(na.omit(dat$profile_code))) else nrow(dat)
orphan_profiles_coords <- if ("profile_code" %in% names(dat)) {
  setdiff(unique(na.omit(dat$profile_code)), unique(na.omit(dat_valid$profile_code)))
} else character(0)

min_x_raw <- min(dat_valid$longitude, na.rm = TRUE)
max_x_raw <- max(dat_valid$longitude, na.rm = TRUE)
min_y_raw <- min(dat_valid$latitude, na.rm = TRUE)
max_y_raw <- max(dat_valid$latitude, na.rm = TRUE)

is_projected_coords <- (abs(min_x_raw) > 180 || abs(max_x_raw) > 180 || abs(min_y_raw) > 90 || abs(max_y_raw) > 90)

# 3. Transformación de Coordenadas y CRS ---------------------------------------
crs_used <- if (is_en) "EPSG:4326 (WGS84 unprojected)" else "EPSG:4326 (WGS84 no proyectado)"
coord_diagnosis <- if (is_en) "Standard WGS84 geographic coordinates." else "Coordenadas geográficas estándar WGS84."
source_crs <- if (!is.null(user_cfg$source_crs)) as.integer(user_cfg$source_crs) else NULL

if (is_projected_coords) {
  coord_diagnosis <- sprintf(if (is_en) "Projected/metric coordinates detected: X[%.1f, %.1f], Y[%.1f, %.1f]." else "Coordenadas proyectadas/métricas detectadas: X[%.1f, %.1f], Y[%.1f, %.1f].",
                             min_x_raw, max_x_raw, min_y_raw, max_y_raw)
  if (is.null(source_crs)) {
    cat("\n==============================================================================\n")
    if (is_en) {
      cat("[PROJECTION ALERT]: Coordinates are in meters/projected but 'source_crs'\n")
      cat("is NOT defined in 'config.json'.\n")
      cat(sprintf("Detected range: X: [%.1f, %.1f] | Y: [%.1f, %.1f]\n", min_x_raw, max_x_raw, min_y_raw, max_y_raw))
      cat("Please consult the EPSG for your country/area in 'docs/OPENNSIS_STANDARDS.md' or with the AI,\n")
      cat("and declare it in 'config.json' (e.g. \"source_crs\": <EPSG code for your area>).\n")
      cat("==============================================================================\n\n")
      crs_used <- "METRICS WITHOUT EPSG (2D plot generated in Plots pane; basemap omitted until source_crs declared)"
    } else {
      cat("[ALERTA DE PROYECCIÓN]: Las coordenadas están en metros/proyectadas pero 'source_crs'\n")
      cat("NO está definido en 'config.json'.\n")
      cat(sprintf("Rango detectado: X: [%.1f, %.1f] | Y: [%.1f, %.1f]\n", min_x_raw, max_x_raw, min_y_raw, max_y_raw))
      cat("Por favor, consulta el EPSG de tu país/zona en 'docs/OPENNSIS_STANDARDS.md' o con la IA,\n")
      cat("y decláralo en 'config.json' (ej: \"source_crs\": <código EPSG de tu zona>).\n")
      cat("==============================================================================\n\n")
      crs_used <- "MÉTRICAS SIN EPSG (Gráfico 2D generado en panel Plots; mapa base omitido hasta declarar source_crs)"
    }
  } else {
    if (is_en) {
      cat(sprintf("[*] Reprojecting coordinates from EPSG:%d to EPSG:4326 (WGS84) ...\n", source_crs))
    } else {
      cat(sprintf("[*] Reproyectando coordenadas desde EPSG:%d a EPSG:4326 (WGS84) ...\n", source_crs))
    }
    sf_pts <- sf::st_as_sf(dat_valid, coords = c("longitude", "latitude"), crs = source_crs)
    sf_wgs84 <- sf::st_transform(sf_pts, crs = 4326)
    coords_wgs84 <- sf::st_coordinates(sf_wgs84)
    
    dat_valid$longitude <- coords_wgs84[, 1]
    dat_valid$latitude  <- coords_wgs84[, 2]
    crs_used <- sprintf(if (is_en) "Transformed from EPSG:%d to EPSG:4326 (WGS84)" else "Transformado de EPSG:%d a EPSG:4326 (WGS84)", source_crs)
    coord_diagnosis <- sprintf(if (is_en) "Coordinates transformed to WGS84 from EPSG:%d." else "Coordenadas transformadas a WGS84 desde EPSG:%d.", source_crs)
    
    record_decision(1.2, "Transformación CRS", sprintf("Reproyección EPSG:%d -> EPSG:4326", source_crs),
                    source = "user_config", affected_rows = nrow(dat_valid), affected_profiles = n_profiles,
                    details = sprintf("Coordenadas originales: X[%.1f, %.1f], Y[%.1f, %.1f]", min_x_raw, max_x_raw, min_y_raw, max_y_raw))
  }
} else {
  if (min_x_raw > -90 && max_x_raw < 90 && (min_y_raw < -90 || max_y_raw > 90 || min_x_raw > 0)) {
    coord_diagnosis <- if (is_en) "Possible latitude and longitude swap; visually inspect on map." else "Posible inversión entre latitud y longitud; verificar visualmente en mapa."
  } else {
    coord_diagnosis <- if (is_en) "Standard WGS84 geographic coordinates (decimal degrees)." else "Coordenadas geográficas estándar WGS84 (grados decimales)."
  }
  record_decision(1.2, "Sistema de referencia (CRS)", "WGS84 geográfico (EPSG:4326)",
                  source = if (!is.null(user_cfg$source_crs)) "user_config" else "script_default",
                  affected_rows = nrow(dat_valid), affected_profiles = n_profiles,
                  details = "Sin transformación requerida")
}

# 4. Auditoría de Outliers Espaciales por Dispersión (IQR 3x) -------------------
# Cálculo de dispersión basada en IQR respecto a la mediana (umbral estándar 3*IQR)
med_x <- median(dat_valid$longitude, na.rm = TRUE)
med_y <- median(dat_valid$latitude, na.rm = TRUE)
iqr_x <- IQR(dat_valid$longitude, na.rm = TRUE)
iqr_y <- IQR(dat_valid$latitude, na.rm = TRUE)

outlier_mask <- rep(FALSE, nrow(dat_valid))
if (iqr_x > 0 && iqr_y > 0) {
  q1_x <- quantile(dat_valid$longitude, 0.25, na.rm = TRUE)
  q3_x <- quantile(dat_valid$longitude, 0.75, na.rm = TRUE)
  q1_y <- quantile(dat_valid$latitude, 0.25, na.rm = TRUE)
  q3_y <- quantile(dat_valid$latitude, 0.75, na.rm = TRUE)
  
  outlier_mask <- (dat_valid$longitude < (q1_x - 3 * iqr_x)) | (dat_valid$longitude > (q3_x + 3 * iqr_x)) |
                  (dat_valid$latitude  < (q1_y - 3 * iqr_y)) | (dat_valid$latitude  > (q3_y + 3 * iqr_y))
}

# Chequeo adicional por IDs explícitos configurados
if (!is.null(user_cfg$outlier_ids) && length(user_cfg$outlier_ids) > 0 && "profile_code" %in% names(dat_valid)) {
  outlier_mask <- outlier_mask | (as.character(dat_valid$profile_code) %in% as.character(user_cfg$outlier_ids))
}

outlier_count <- sum(outlier_mask)
outlier_profiles <- if ("profile_code" %in% names(dat_valid)) {
  length(unique(dat_valid$profile_code[outlier_mask]))
} else {
  outlier_count
}

coord_space_iqr <- if (is_projected_coords && is.null(source_crs)) {
  if (is_en) "Original metric coordinates (unprojected)" else "Coordenadas métricas originales (sin reproyectar)"
} else if (is_projected_coords && !is.null(source_crs)) {
  sprintf(if (is_en) "WGS84 decimal degrees (reprojected from EPSG:%d)" else "Grados decimales WGS84 (reproyectados desde EPSG:%d)", source_crs)
} else {
  if (is_en) "WGS84 decimal degrees (source geographic coordinates)" else "Grados decimales WGS84 (coordenadas geográficas de origen)"
}

dat_valid$flag_spatial_outlier <- outlier_mask

# Aplicar decisión del usuario sobre outliers si está configurada
target_outlier_act <- if (!is.null(user_cfg$outlier_action)) user_cfg$outlier_action else user_cfg$spatial_outlier_action
if (!is.null(target_outlier_act)) {
  valid_outlier_acts <- c("flag", "exclude", "keep")
  if (!(target_outlier_act %in% valid_outlier_acts)) {
    stop(sprintf(if (is_en) "[CONFIG ERROR]: Invalid value for 'outlier_action': '%s'.\n  Valid values per 'docs/CONFIG_SCHEMA.md': [%s]." else "[ERROR CONFIG]: Valor no válido para 'outlier_action': '%s'.\n  Valores válidos según 'docs/CONFIG_SCHEMA.md': [%s].",
                 target_outlier_act, paste(valid_outlier_acts, collapse = ", ")))
  }
}
outlier_act_source <- if (!is.null(target_outlier_act)) "user_config" else "script_default"

if (!is.null(target_outlier_act) && outlier_count > 0) {
  if (target_outlier_act == "exclude") {
    dat_valid <- dat_valid %>% filter(!flag_spatial_outlier)
    outlier_action_applied <- sprintf(if (is_en) "Excluded %d records (%d unique profiles)" else "Excluidos %d registros (%d perfiles únicos)", outlier_count, outlier_profiles)
    record_decision(1.2, "Outliers espaciales", "Excluir puntos anómalos", source = outlier_act_source,
                    affected_rows = outlier_count, affected_profiles = outlier_profiles,
                    details = sprintf(if (is_en) "3x IQR filter applied after confirmation on %s" else "Filtro IQR 3x aplicado tras confirmación sobre %s", coord_space_iqr))
  } else if (target_outlier_act == "flag") {
    outlier_action_applied <- sprintf(if (is_en) "Preserved with flag_spatial_outlier = TRUE (%d records, %d unique profiles)" else "Conservados con flag_spatial_outlier = TRUE (%d registros, %d perfiles únicos)", outlier_count, outlier_profiles)
    record_decision(1.2, "Outliers espaciales", "Conservar y marcar bandera", source = outlier_act_source,
                    affected_rows = outlier_count, affected_profiles = outlier_profiles,
                    details = sprintf(if (is_en) "flag_spatial_outlier column added on %s" else "Columna flag_spatial_outlier agregada sobre %s", coord_space_iqr))
  } else if (target_outlier_act == "keep") {
    outlier_action_applied <- sprintf(if (is_en) "Preserved as valid by user decision (%d records, %d unique profiles)" else "Conservados como válidos por decisión del usuario (%d registros, %d perfiles únicos)", outlier_count, outlier_profiles)
    record_decision(1.2, "Outliers espaciales", "Conservar como válidos", source = outlier_act_source,
                    affected_rows = outlier_count, affected_profiles = outlier_profiles)
  }
} else {
  outlier_action_applied <- if (outlier_count > 0) {
    sprintf(if (is_en) "Identified %d candidates (%d unique profiles); marked with flag_spatial_outlier for visual inspection" else "Identificados %d candidatos (%d perfiles únicos); marcados con flag_spatial_outlier para inspección visual", outlier_count, outlier_profiles)
  } else {
    if (is_en) "0 outliers detected by univariate 3x IQR filter" else "0 outliers detectados por filtro univariado IQR 3x"
  }
  record_decision(1.2, "Outliers espaciales", "Evaluación completada", source = outlier_act_source,
                  affected_rows = outlier_count, affected_profiles = outlier_profiles,
                  details = sprintf(if (is_en) "%s (space: %s)" else "%s (espacio: %s)", outlier_action_applied, coord_space_iqr))
}

# >>> ADAPT:crs_and_outliers
# Punto de extensión: inserción de filtros o transformaciones espaciales personalizadas.
# Objetos disponibles: dat_valid (data.frame), outlier_mask (logical), source_crs (int), user_cfg (list), record_decision (función)
# Invariante: dat_valid debe conservar columnas longitude y latitude válidas.
# <<< ADAPT:crs_and_outliers

# Perfiles colocalizados (mismas coordenadas)
unique_locs <- dat_valid %>% distinct(longitude, latitude) %>% nrow()

# 5. Generación del Reporte Espacial en Texto UTF-8 -----------------------------
report_con <- file(output_report, open = "wt", encoding = "UTF-8")
writeLines("================================================================================", report_con)
if (is_en) {
  writeLines("  DSM-HARNESS | STEP 1.2 REPORT: SPATIAL AND GEOGRAPHIC AUDIT", report_con)
  writeLines("================================================================================", report_con)
  writeLines(paste("Date:                ", format(Sys.time(), "%Y-%m-%d %H:%M:%S")), report_con)
  writeLines(paste("Analyzed file:       ", input_csv), report_con)
  writeLines(paste("General diagnosis:   ", if (exists("translate_decision_text")) translate_decision_text(coord_diagnosis, "en") else coord_diagnosis), report_con)
  writeLines(paste("CRS:                 ", if (exists("translate_decision_text")) translate_decision_text(crs_used, "en") else crs_used), report_con)
  writeLines("--------------------------------------------------------------------------------", report_con)
  writeLines("RECORD AND LOCATION METRICS (100% CALCULATED):", report_con)
  writeLines(sprintf("  Total initial records:              %d", n_total), report_con)
  writeLines(sprintf("  Records with valid coordinates:     %d (%.1f%%)", nrow(dat_valid), (nrow(dat_valid) / n_total) * 100), report_con)
  writeLines(sprintf("  Records with null/NA coordinates:   %d", missing_coords_count), report_con)
  writeLines(sprintf("  Records at (0, 0):                  %d", zero_coords_count), report_con)
  writeLines(sprintf("  Unique sites / locations:           %d", unique_locs), report_con)
  if ("profile_code" %in% names(dat)) {
    writeLines(sprintf("  Unique profiles identified:         %d", n_profiles), report_con)
    if (length(orphan_profiles_coords) > 0) {
      writeLines(sprintf("  Profiles without valid coordinates: %d (samples: %s)", 
                         length(orphan_profiles_coords), paste(head(orphan_profiles_coords, 5), collapse = ", ")), report_con)
    }
  }
  writeLines("--------------------------------------------------------------------------------", report_con)
  if (is_projected_coords && is.null(source_crs)) {
    writeLines("METRIC COORDINATE RANGES (PROJECTED WITHOUT CRS):", report_con)
    writeLines(sprintf("  X (East):  [%.1f, %.1f] (Span: %.1f m)", 
                       min(dat_valid$longitude), max(dat_valid$longitude), diff(range(dat_valid$longitude))), report_con)
    writeLines(sprintf("  Y (North): [%.1f, %.1f] (Span: %.1f m)", 
                       min(dat_valid$latitude), max(dat_valid$latitude), diff(range(dat_valid$latitude))), report_con)
    writeLines("  NOTE: Metric projected coordinates without assigned CRS. 2D scatter plot available in Plots.", report_con)
  } else {
    min_lon <- min(dat_valid$longitude, na.rm = TRUE)
    max_lon <- max(dat_valid$longitude, na.rm = TRUE)
    min_lat <- min(dat_valid$latitude, na.rm = TRUE)
    max_lat <- max(dat_valid$latitude, na.rm = TRUE)
    writeLines("WGS84 COORDINATE RANGES (HUMAN VERIFICATION REQUIRED):", report_con)
    writeLines(sprintf("  Longitude: [%.4f, %.4f] (Span: %.4f degrees)", 
                       min_lon, max_lon, diff(c(min_lon, max_lon))), report_con)
    writeLines(sprintf("  Latitude:  [%.4f, %.4f] (Span: %.4f degrees)", 
                       min_lat, max_lat, diff(c(min_lat, max_lat))), report_con)
    writeLines("  SPATIAL CONTROL NOTE: Check that this range falls inside your territory or study area.", report_con)
    writeLines("  If points fall in the ocean or overseas, the source EPSG is incorrect.", report_con)
  }
  writeLines("--------------------------------------------------------------------------------", report_con)
  writeLines("SPATIAL OUTLIER AUDIT AND DISPERSION:", report_con)
  writeLines(sprintf("  Applied method:                   1D IQR per axis (threshold: Q1 - 3*IQR or Q3 + 3*IQR)"))
  writeLines(sprintf("  Evaluated coordinate space:       %s", coord_space_iqr), report_con)
  writeLines(sprintf("  Candidates detected by IQR 3x:    %d unique profiles (%d records/rows)", outlier_profiles, outlier_count), report_con)
  out_act_en <- if (exists("translate_decision_text")) translate_decision_text(outlier_action_applied, "en") else outlier_action_applied
  writeLines(sprintf("  Outlier treatment:                %s", out_act_en), report_con)
  writeLines("  METHODOLOGICAL LIMITATION NOTE:", report_con)
  writeLines("  Univariate IQR per axis only detects extreme values at outer boundaries of sampled extent.", report_con)
  writeLines("  It DOES NOT detect points inside bounding box. Interactive map / scatter plot visual inspection", report_con)
  writeLines("  in RStudio is required before making a decision.", report_con)
  
  if (outlier_count > 0 && "profile_code" %in% names(dat_valid)) {
    out_sample <- dat_valid %>% filter(flag_spatial_outlier) %>% distinct(profile_code, .keep_all = TRUE) %>% head(10)
    writeLines("\nCANDIDATE OUTLIER POINT SAMPLES:", report_con)
    for (i in seq_len(nrow(out_sample))) {
      writeLines(sprintf("  - Profile: %-15s | Lon: %8.4f | Lat: %8.4f", 
                         out_sample$profile_code[i], out_sample$longitude[i], out_sample$latitude[i]), report_con)
    }
  }
} else {
  writeLines("  DSM-HARNESS | REPORTE PASO 1.2: AUDITORIA ESPACIAL Y GEOGRAFICA", report_con)
  writeLines("================================================================================", report_con)
  writeLines(paste("Fecha:", format(Sys.time(), "%Y-%m-%d %H:%M:%S")), report_con)
  writeLines(paste("Archivo analizado:", input_csv), report_con)
  writeLines(paste("Diagnostico general:", coord_diagnosis), report_con)
  writeLines(paste("Sistema de referencia (CRS):", crs_used), report_con)
  writeLines("--------------------------------------------------------------------------------", report_con)
  writeLines("METRICAS DE REGISTROS Y LOCALIZACIONES (100% CALCULADAS):", report_con)
  writeLines(sprintf("  Total registros iniciales:          %d", n_total), report_con)
  writeLines(sprintf("  Registros con coordenadas validas:  %d (%.1f%%)", nrow(dat_valid), (nrow(dat_valid) / n_total) * 100), report_con)
  writeLines(sprintf("  Registros con coordenadas nulas/NA: %d", missing_coords_count), report_con)
  writeLines(sprintf("  Registros en (0, 0):                %d", zero_coords_count), report_con)
  writeLines(sprintf("  Sitios / ubicaciones unicas:        %d", unique_locs), report_con)
  if ("profile_code" %in% names(dat)) {
    writeLines(sprintf("  Perfiles unicos identificados:      %d", n_profiles), report_con)
    if (length(orphan_profiles_coords) > 0) {
      writeLines(sprintf("  Perfiles sin coordenadas validas:   %d (ejemplos: %s)", 
                         length(orphan_profiles_coords), paste(head(orphan_profiles_coords, 5), collapse = ", ")), report_con)
    }
  }
  writeLines("--------------------------------------------------------------------------------", report_con)
  if (is_projected_coords && is.null(source_crs)) {
    writeLines("RANGOS DE COORDENADAS METRICAS (PROYECTADAS SIN CRS):", report_con)
    writeLines(sprintf("  X (Este):  [%.1f, %.1f] (Amplitud: %.1f m)", 
                       min(dat_valid$longitude), max(dat_valid$longitude), diff(range(dat_valid$longitude))), report_con)
    writeLines(sprintf("  Y (Norte): [%.1f, %.1f] (Amplitud: %.1f m)", 
                       min(dat_valid$latitude), max(dat_valid$latitude), diff(range(dat_valid$latitude))), report_con)
    writeLines("  NOTA: Coordenadas en rango métrico proyectado sin CRS asignado. Gráfico 2D disponible en Plots.", report_con)
  } else {
    min_lon <- min(dat_valid$longitude, na.rm = TRUE)
    max_lon <- max(dat_valid$longitude, na.rm = TRUE)
    min_lat <- min(dat_valid$latitude, na.rm = TRUE)
    max_lat <- max(dat_valid$latitude, na.rm = TRUE)
    writeLines("RANGOS DE COORDENADAS WGS84 (CONFIRMACION HUMANA REQUERIDA):", report_con)
    writeLines(sprintf("  Longitud: [%.4f, %.4f] (Amplitud: %.4f grados)", 
                       min_lon, max_lon, diff(c(min_lon, max_lon))), report_con)
    writeLines(sprintf("  Latitud:  [%.4f, %.4f] (Amplitud: %.4f grados)", 
                       min_lat, max_lat, diff(c(min_lat, max_lat))), report_con)
    writeLines("  NOTA DE CONTROL ESPACIAL: Verificar que este rango concuerde con los limites", report_con)
    writeLines("  de tu pais o zona de estudio. Si los puntos caen en el oceano o fuera del pais,", report_con)
    writeLines("  el codigo EPSG de origen es incorrecto.", report_con)
  }
  writeLines("--------------------------------------------------------------------------------", report_con)
  writeLines("AUDITORIA DE OUTLIERS ESPACIALES Y DISPERSION:", report_con)
  writeLines(sprintf("  Metodo aplicado:                  1D IQR por eje (umbral: Q1 - 3*IQR o Q3 + 3*IQR)"))
  writeLines(sprintf("  Espacio de coordenadas evaluado:  %s", coord_space_iqr), report_con)
  writeLines(sprintf("  Candidatos detectados por IQR 3x: %d perfiles unicos (%d registros/filas)", outlier_profiles, outlier_count), report_con)
  writeLines(sprintf("  Tratamiento de outliers:          %s", outlier_action_applied), report_con)
  writeLines("  NOTA Y LIMITACION METODOLOGICA:", report_con)
  writeLines("  El filtro IQR univariado por eje detecta exclusivamente valores extremos en los", report_con)
  writeLines("  margenes exteriores del area muestreada en el espacio de coordenadas evaluado.", report_con)
  writeLines("  NO detecta errores de coordenadas o puntos aislados que se encuentren dentro de", report_con)
  writeLines("  la caja envolvente (bounding box). Es indispensable inspeccionar el mapa interactivo", report_con)
  writeLines("  o grafico de dispersion generado en RStudio antes de tomar una decision.", report_con)
  
  if (outlier_count > 0 && "profile_code" %in% names(dat_valid)) {
    out_sample <- dat_valid %>% filter(flag_spatial_outlier) %>% distinct(profile_code, .keep_all = TRUE) %>% head(10)
    writeLines("\nEJEMPLO DE PUNTOS CANDIDATOS A OUTLIER:", report_con)
    for (i in seq_len(nrow(out_sample))) {
      writeLines(sprintf("  - Perfil: %-15s | Lon: %8.4f | Lat: %8.4f", 
                         out_sample$profile_code[i], out_sample$longitude[i], out_sample$latitude[i]), report_con)
    }
  }
}
writeLines("================================================================================", report_con)
close(report_con)

# 6. Guardar dataset intermedio -------------------------------------------------
readr::write_csv(dat_valid, output_csv)

# 7. Diagnóstico Visual Interactivo (Mapview o ggplot2) -------------------------
lbl_normal <- if (is_en) "Normal" else "Normal"
lbl_outlier <- if (is_en) "Outlier Candidate" else "Candidato Outlier"
lbl_status <- if (is_en) "Status" else "Estado"

if (!is_projected_coords || !is.null(source_crs)) {
  if (is_en) cat("[*] Generating spatial diagnostic visualization ...\n") else cat("[*] Generando visualización espacial diagnóstica ...\n")
  sf_map <- sf::st_as_sf(dat_valid, coords = c("longitude", "latitude"), crs = 4326)
  
  if (requireNamespace("mapview", quietly = TRUE)) {
    tryCatch({
      m <- mapview::mapview(sf_map, zcol = if ("flag_spatial_outlier" %in% names(sf_map)) "flag_spatial_outlier" else NULL,
                            layer.name = if (is_en) "Soil Profiles" else "Perfiles de Suelo",
                            col.regions = c("#2A788EFF", "#D84315"),
                            legend = TRUE)
      print(m)
      if (is_en) cat("[OK] Interactive map displayed in RStudio 'Viewer' panel.\n") else cat("[OK] Mapa interactivo desplegado en el panel 'Viewer' de RStudio.\n")
    }, error = function(e) {
      if (is_en) cat("[NOTICE] mapview could not display; falling back to ggplot2.\n") else cat("[AVISO] mapview no pudo desplegarse; generando gráfico con ggplot2.\n")
    })
  } else {
    p <- ggplot(dat_valid, aes(x = longitude, y = latitude, color = flag_spatial_outlier)) +
      geom_point(alpha = 0.7, size = 2) +
      scale_color_manual(values = c("FALSE" = "#2A788EFF", "TRUE" = "#D84315"),
                         labels = c(lbl_normal, lbl_outlier), name = lbl_status) +
      theme_minimal() +
      labs(title = if (is_en) "Spatial Distribution of Profiles" else "Distribución Espacial de Perfiles",
           subtitle = if (is_en) sprintf("Total valid profiles: %d | Outlier candidates (IQR 3x): %d", nrow(dat_valid), outlier_count) else sprintf("Total perfiles válidos: %d | Candidatos a outlier (IQR 3x): %d", nrow(dat_valid), outlier_count),
           x = if (is_en) "Longitude (WGS84)" else "Longitud (WGS84)", y = if (is_en) "Latitude (WGS84)" else "Latitud (WGS84)")
    print(p)
    if (is_en) cat("[OK] Spatial plot generated in RStudio 'Plots' panel.\n") else cat("[OK] Gráfico espacial generado en el panel 'Plots' de RStudio.\n")
  }
} else {
  # Coordenadas proyectadas sin EPSG especificado: generar dispersión plana en ggplot2 (Issue #28)
  if (is_en) cat("[*] Metric coordinates without specified EPSG. Generating planar 2D scatter plot ...\n") else cat("[*] Coordenadas métricas sin EPSG especificado. Generando gráfico de dispersión bidimensional ...\n")
  p <- ggplot(dat_valid, aes(x = longitude, y = latitude, color = flag_spatial_outlier)) +
    geom_point(alpha = 0.7, size = 2) +
    scale_color_manual(values = c("FALSE" = "#2A788EFF", "TRUE" = "#D84315"),
                       labels = c(lbl_normal, lbl_outlier), name = lbl_status) +
    theme_minimal() +
    labs(title = if (is_en) "Metric Coordinate Distribution (No CRS Specified)" else "Distribución de Coordenadas Métricas (Sin CRS Especificado)",
         subtitle = if (is_en) sprintf("Planar scatter in unspecified source system. Total: %d | Outliers IQR 3x: %d", nrow(dat_valid), outlier_count) else sprintf("Dispersión plana en sistema de origen no especificado (sin georreferenciar). Total: %d | Outliers IQR 3x: %d", nrow(dat_valid), outlier_count),
         x = if (is_en) "X Coordinate (East)" else "Coordenada X (Este)", y = if (is_en) "Y Coordinate (North)" else "Coordenada Y (Norte)")
  print(p)
  if (is_en) {
    cat("[OK] Diagnostic scatter plot generated in RStudio 'Plots' panel.\n")
    cat("     -> NOTE: This plot shows relative point dispersion in raw metric coordinates.\n")
    cat("     -> To display interactive basemap (mapview), set 'source_crs' in 'config.json'.\n")
  } else {
    cat("[OK] Gráfico diagnóstico de dispersión generado en el panel 'Plots' de RStudio.\n")
    cat("     -> NOTA: Este gráfico muestra la dispersión relativa de los puntos en sus coordenadas métricas originales.\n")
    cat("     -> Para desplegar mapa interactivo sobre capas base (mapview), declara 'source_crs' en 'config.json'.\n")
  }
}

# 8. Resumen en consola --------------------------------------------------------
cat("\n==============================================================================\n")
if (is_en) {
  cat("  SPATIAL AUDIT SUMMARY (Step 1.2)\n")
  cat("==============================================================================\n")
  cat(sprintf("Valid records analyzed:               %d / %d (%.1f%%)\n", nrow(dat_valid), n_total, (nrow(dat_valid) / n_total) * 100))
  crs_en <- if (exists("translate_decision_text")) translate_decision_text(crs_used, "en") else crs_used
  cat(sprintf("Reference system:                     %s\n", crs_en))
  if (!is_projected_coords || !is.null(source_crs)) {
    min_lon <- min(dat_valid$longitude, na.rm = TRUE)
    max_lon <- max(dat_valid$longitude, na.rm = TRUE)
    min_lat <- min(dat_valid$latitude, na.rm = TRUE)
    max_lat <- max(dat_valid$latitude, na.rm = TRUE)
    cat(sprintf("Resulting degree range (WGS84):       Lon [%.4f, %.4f] | Lat [%.4f, %.4f]\n", min_lon, max_lon, min_lat, max_lat))
  }
  cat(sprintf("Potential spatial outliers (IQR 3x):  %d unique profiles (%d records/horizons)\n", outlier_profiles, outlier_count))
  cat(sprintf("Evaluated coordinate space for IQR:   %s\n", coord_space_iqr))
  out_act_en <- if (exists("translate_decision_text")) translate_decision_text(outlier_action_applied, "en") else outlier_action_applied
  cat(sprintf("Applied action:                       %s\n", out_act_en))
  cat(sprintf("[OK] Spatial dataset saved to:        %s\n", output_csv))
  cat(sprintf("[OK] Spatial report saved to:         %s\n", output_report))
  if (decision_logged) {
    cat(sprintf("[OK] Decisions log at:                %s\n", decisions_log))
  }
  cat("==============================================================================\n\n")

  cat("------------------------------------------------------------------------------\n")
  cat("STUDENT INSTRUCTIONS:\n")
  if (is_projected_coords && is.null(source_crs)) {
    cat("1. Review the coordinate scatter plot in RStudio 'Plots' panel.\n")
    cat("2. In the AI chat, indicate which projected system / EPSG corresponds to these coordinates,\n")
    cat("   and verify if dispersion matches your study area before moving to Step 1.3.\n")
  } else {
    min_lon <- min(dat_valid$longitude, na.rm = TRUE)
    max_lon <- max(dat_valid$longitude, na.rm = TRUE)
    min_lat <- min(dat_valid$latitude, na.rm = TRUE)
    max_lat <- max(dat_valid$latitude, na.rm = TRUE)
    cat(sprintf("1. Review resulting geographic range: Longitude [%.4f, %.4f] | Latitude [%.4f, %.4f].\n", min_lon, max_lon, min_lat, max_lat))
    cat("   Verify in the RStudio map if points fall inside your country / study area\n")
    cat("   (an incorrect EPSG may place points in the ocean or on another continent).\n")
    cat("2. In the AI chat, confirm whether the geographic location is plausible before moving to Step 1.3.\n")
  }
  cat("------------------------------------------------------------------------------\n\n")
} else {
  cat("  RESUMEN DE AUDITORÍA ESPACIAL (Paso 1.2)\n")
  cat("==============================================================================\n")
  cat(sprintf("Registros válidos analizados:          %d / %d (%.1f%%)\n", nrow(dat_valid), n_total, (nrow(dat_valid) / n_total) * 100))
  cat(sprintf("Sistema de referencia:                 %s\n", crs_used))
  if (!is_projected_coords || !is.null(source_crs)) {
    min_lon <- min(dat_valid$longitude, na.rm = TRUE)
    max_lon <- max(dat_valid$longitude, na.rm = TRUE)
    min_lat <- min(dat_valid$latitude, na.rm = TRUE)
    max_lat <- max(dat_valid$latitude, na.rm = TRUE)
    cat(sprintf("Rango resultante en grados (WGS84):    Lon [%.4f, %.4f] | Lat [%.4f, %.4f]\n", min_lon, max_lon, min_lat, max_lat))
  }
  cat(sprintf("Posibles outliers espaciales (IQR 3x): %d perfiles únicos (%d registros/horizontes)\n", outlier_profiles, outlier_count))
  cat(sprintf("Espacio evaluado para IQR:             %s\n", coord_space_iqr))
  cat(sprintf("Acción aplicada:                       %s\n", outlier_action_applied))
  cat(sprintf("[OK] Dataset espacial guardado en:     %s\n", output_csv))
  cat(sprintf("[OK] Reporte espacial guardado en:     %s\n", output_report))
  if (decision_logged) {
    cat(sprintf("[OK] Registro de decisiones en:        %s\n", decisions_log))
  }
  cat("==============================================================================\n\n")

  cat("------------------------------------------------------------------------------\n")
  cat("INSTRUCCIÓN PARA EL ALUMNO:\n")
  if (is_projected_coords && is.null(source_crs)) {
    cat("1. Revisa el gráfico de dispersión de coordenadas en el panel 'Plots' de RStudio.\n")
    cat("2. En el chat con la IA, indica qué sistema proyectado/EPSG corresponde a estas coordenadas,\n")
    cat("   y si la dispersión de puntos concuerda con tu área de estudio antes de pasar al Paso 1.3.\n")
  } else {
    min_lon <- min(dat_valid$longitude, na.rm = TRUE)
    max_lon <- max(dat_valid$longitude, na.rm = TRUE)
    min_lat <- min(dat_valid$latitude, na.rm = TRUE)
    max_lat <- max(dat_valid$latitude, na.rm = TRUE)
    cat(sprintf("1. Revisa el rango geografico resultante: Longitud [%.4f, %.4f] | Latitud [%.4f, %.4f].\n", min_lon, max_lon, min_lat, max_lat))
    cat("   Verifica en el mapa de RStudio si los puntos caen dentro de tu pais o zona de estudio\n")
    cat("   (un EPSG incorrecto puede situar los puntos en el oceano o en otro continente).\n")
    cat("2. En el chat con la IA, confirma si la ubicacion geografica es plausible antes de avanzar al Paso 1.3.\n")
  }
  cat("------------------------------------------------------------------------------\n\n")
}
