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

rm(list = setdiff(ls(), c("input_csv", "TEMPLATE_VERSION")))

suppressPackageStartupMessages({
  library(tidyverse)
  library(sf)
})

# 1. Configuración de rutas y parámetros ---------------------------------------
is_project_env <- dir.exists("data") && dir.exists("reports")
base_data_dir  <- if (is_project_env) "data" else "01_data/profiles"
base_rep_dir   <- if (is_project_env) "reports" else "01_data/profiles"

config_file   <- if (file.exists("config.json")) "config.json" else file.path(base_data_dir, "user_config.json")
input_csv     <- file.path(base_data_dir, "step1_1_variables.csv")
output_csv    <- file.path(base_data_dir, "step1_2_spatial.csv")
output_report <- file.path(base_rep_dir, "step1_2_spatial_report.txt")
decisions_log <- if (file.exists("decisions_log.csv")) "decisions_log.csv" else file.path(base_data_dir, "decisions_log.csv")

SCRIPT_RUN_ID <- format(Sys.time(), "%Y%m%d_%H%M%S")
decision_logged <- FALSE

record_decision <- function(step, criterion, decision, source = "user_config", affected_rows = 0, affected_profiles = 0, details = "") {
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
    }
  }, error = function(e) NULL)
}

if (!file.exists(input_csv)) {
  stop(sprintf("[ERROR FATAL]: No se encontró el dataset intermedio '%s'. Ejecuta primero el Paso 1.1.", input_csv))
}

cat(sprintf("\n[*] Cargando datos espaciales desde: %s ...\n", input_csv))
dat <- readr::read_csv(input_csv, show_col_types = FALSE)
n_total <- nrow(dat)

# 2. Detección y Validación Numérica de Coordenadas -----------------------------
lon_col <- intersect(c("longitude", "x", "lon", "long", "longitud"), names(dat))
lat_col <- intersect(c("latitude", "y", "lat", "latitud"), names(dat))

if (length(lon_col) == 0 || length(lat_col) == 0) {
  stop("[ERROR FATAL]: El dataset no contiene columnas estándar de coordenadas ('longitude'/'latitude' o 'x'/'y').")
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
  stop("[ERROR FATAL]: Ningún registro posee coordenadas válidas no nulas. Imposible realizar auditoría espacial.")
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
# >>> ADAPT:crs_and_outliers
crs_used <- "EPSG:4326 (WGS84 no proyectado)"
coord_diagnosis <- "Coordenadas geográficas estándar WGS84."
source_crs <- if (!is.null(user_cfg$source_crs)) as.integer(user_cfg$source_crs) else NULL

if (is_projected_coords) {
  coord_diagnosis <- sprintf("Coordenadas proyectadas/métricas detectadas: X[%.1f, %.1f], Y[%.1f, %.1f].",
                             min_x_raw, max_x_raw, min_y_raw, max_y_raw)
  if (is.null(source_crs)) {
    cat("\n==============================================================================\n")
    cat("[ALERTA DE PROYECCIÓN]: Las coordenadas están en metros/proyectadas pero 'source_crs'\n")
    cat("NO está definido en 'config.json'.\n")
    cat(sprintf("Rango detectado: X: [%.1f, %.1f] | Y: [%.1f, %.1f]\n", min_x_raw, max_x_raw, min_y_raw, max_y_raw))
    cat("Por favor, consulta el EPSG de tu país/zona en 'docs/OPENNSIS_STANDARDS.md' o con la IA,\n")
    cat("y decláralo en 'config.json' (ej: \"source_crs\": 32616).\n")
    cat("==============================================================================\n\n")
    crs_used <- "MÉTRICAS SIN EPSG (Transformación pendiente; mapa omitido para evitar deformación)"
  } else {
    cat(sprintf("[*] Reproyectando coordenadas desde EPSG:%d a EPSG:4326 (WGS84) ...\n", source_crs))
    sf_pts <- sf::st_as_sf(dat_valid, coords = c("longitude", "latitude"), crs = source_crs)
    sf_wgs84 <- sf::st_transform(sf_pts, crs = 4326)
    coords_wgs84 <- sf::st_coordinates(sf_wgs84)
    
    dat_valid$longitude <- coords_wgs84[, 1]
    dat_valid$latitude  <- coords_wgs84[, 2]
    crs_used <- sprintf("Transformado de EPSG:%d a EPSG:4326 (WGS84)", source_crs)
    coord_diagnosis <- sprintf("Coordenadas transformadas a WGS84 desde EPSG:%d.", source_crs)
    
    record_decision(1.2, "Transformación CRS", sprintf("Reproyección EPSG:%d -> EPSG:4326", source_crs),
                    source = "user_config", affected_rows = nrow(dat_valid), affected_profiles = n_profiles,
                    details = sprintf("Coordenadas originales: X[%.1f, %.1f], Y[%.1f, %.1f]", min_x_raw, max_x_raw, min_y_raw, max_y_raw))
  }
} else {
  if (min_x_raw > -90 && max_x_raw < 90 && (min_y_raw < -90 || max_y_raw > 90 || min_x_raw > 0)) {
    coord_diagnosis <- "Posible inversión entre latitud y longitud; verificar visualmente en mapa."
  } else {
    coord_diagnosis <- "Coordenadas geográficas estándar WGS84 (grados decimales)."
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
dat_valid$flag_spatial_outlier <- outlier_mask

# Aplicar decisión del usuario sobre outliers si está configurada
target_outlier_act <- if (!is.null(user_cfg$outlier_action)) user_cfg$outlier_action else user_cfg$spatial_outlier_action
outlier_act_source <- if (!is.null(target_outlier_act)) "user_config" else "script_default"

if (!is.null(target_outlier_act) && outlier_count > 0) {
  if (target_outlier_act == "exclude") {
    dat_valid <- dat_valid %>% filter(!flag_spatial_outlier)
    outlier_action_applied <- sprintf("Excluidos %d registros outliers", outlier_count)
    record_decision(1.2, "Outliers espaciales", "Excluir puntos anómalos", source = outlier_act_source,
                    affected_rows = outlier_count, details = "Filtro IQR 3x aplicado tras confirmación")
  } else if (target_outlier_act == "flag") {
    outlier_action_applied <- sprintf("Conservados con flag_spatial_outlier = TRUE (%d registros)", outlier_count)
    record_decision(1.2, "Outliers espaciales", "Conservar y marcar bandera", source = outlier_act_source,
                    affected_rows = outlier_count, details = "Columna flag_spatial_outlier agregada")
  } else {
    outlier_action_applied <- "Conservados como válidos por decisión del usuario"
    record_decision(1.2, "Outliers espaciales", "Conservar como válidos", source = outlier_act_source,
                    affected_rows = outlier_count)
  }
} else {
  outlier_action_applied <- if (outlier_count > 0) {
    sprintf("Identificados %d posibles candidatos; marcados con flag_spatial_outlier para inspección visual", outlier_count)
  } else {
    "0 outliers detectados por filtro univariado IQR 3x"
  }
  record_decision(1.2, "Outliers espaciales", "Evaluación completada", source = outlier_act_source,
                  affected_rows = outlier_count, details = outlier_action_applied)
}
# <<< ADAPT:crs_and_outliers

# Perfiles colocalizados (mismas coordenadas)
unique_locs <- dat_valid %>% distinct(longitude, latitude) %>% nrow()

# 5. Generación del Reporte Espacial en Texto UTF-8 -----------------------------
report_con <- file(output_report, open = "wt", encoding = "UTF-8")
writeLines("================================================================================", report_con)
writeLines("  DSM-HARNESS | REPORTE PASO 1.2: AUDITORÍA ESPACIAL Y GEOGRÁFICA", report_con)
writeLines("================================================================================", report_con)
writeLines(paste("Fecha:", format(Sys.time(), "%Y-%m-%d %H:%M:%S")), report_con)
writeLines(paste("Archivo analizado:", input_csv), report_con)
writeLines(paste("Diagnóstico general:", coord_diagnosis), report_con)
writeLines(paste("Sistema de referencia (CRS):", crs_used), report_con)
writeLines("--------------------------------------------------------------------------------", report_con)
writeLines("MÉTRICAS DE REGISTROS Y LOCALIZACIONES (100% CALCULADAS):", report_con)
writeLines(sprintf("  Total registros iniciales:          %d", n_total), report_con)
writeLines(sprintf("  Registros con coordenadas válidas:  %d (%.1f%%)", nrow(dat_valid), (nrow(dat_valid) / n_total) * 100), report_con)
writeLines(sprintf("  Registros con coordenadas nulas/NA: %d", missing_coords_count), report_con)
writeLines(sprintf("  Registros en (0, 0):                %d", zero_coords_count), report_con)
writeLines(sprintf("  Sitios / ubicaciones únicas:        %d", unique_locs), report_con)
if ("profile_code" %in% names(dat)) {
  writeLines(sprintf("  Perfiles únicos identificados:      %d", n_profiles), report_con)
  if (length(orphan_profiles_coords) > 0) {
    writeLines(sprintf("  Perfiles sin coordenadas válidas:   %d (ejemplos: %s)", 
                       length(orphan_profiles_coords), paste(head(orphan_profiles_coords, 5), collapse = ", ")), report_con)
  }
}
writeLines("--------------------------------------------------------------------------------", report_con)
writeLines("RANGOS DE COORDENADAS WGS84:", report_con)
writeLines(sprintf("  Longitud: [%.4f, %.4f] (Amplitud: %.4f grados)", 
                   min(dat_valid$longitude), max(dat_valid$longitude), diff(range(dat_valid$longitude))), report_con)
writeLines(sprintf("  Latitud:  [%.4f, %.4f] (Amplitud: %.4f grados)", 
                   min(dat_valid$latitude), max(dat_valid$latitude), diff(range(dat_valid$latitude))), report_con)
writeLines("--------------------------------------------------------------------------------", report_con)
writeLines("AUDITORÍA DE OUTLIERS ESPACIALES Y DISPERSIÓN:", report_con)
writeLines(sprintf("  Método aplicado:                  1D IQR por eje (umbral: Q1 - 3·IQR o Q3 + 3·IQR)"), report_con)
writeLines(sprintf("  Candidatos detectados por IQR 3x: %d", outlier_count), report_con)
writeLines(sprintf("  Tratamiento de outliers:          %s", outlier_action_applied), report_con)
writeLines("  NOTA Y LIMITACIÓN METODOLÓGICA:", report_con)
writeLines("  El filtro IQR univariado por eje detecta exclusivamente valores extremos en los", report_con)
writeLines("  márgenes exteriores del área muestreada. NO detecta errores de coordenadas o puntos", report_con)
writeLines("  aislados que se encuentren dentro de la caja envolvente (bounding box). Es indispensable", report_con)
writeLines("  inspeccionar el mapa interactivo generado en RStudio antes de tomar una decisión.", report_con)

if (outlier_count > 0 && "profile_code" %in% names(dat_valid)) {
  out_sample <- dat_valid %>% filter(flag_spatial_outlier) %>% distinct(profile_code, .keep_all = TRUE) %>% head(10)
  writeLines("\nEJEMPLO DE PUNTOS CANDIDATOS A OUTLIER:", report_con)
  for (i in seq_len(nrow(out_sample))) {
    writeLines(sprintf("  - Perfil: %-15s | Lon: %8.4f | Lat: %8.4f", 
                       out_sample$profile_code[i], out_sample$longitude[i], out_sample$latitude[i]), report_con)
  }
}

writeLines("================================================================================", report_con)
close(report_con)

# 6. Guardar dataset intermedio -------------------------------------------------
readr::write_csv(dat_valid, output_csv)

# 7. Diagnóstico Visual Interactivo (Mapview o ggplot2) -------------------------
if (!is_projected_coords || !is.null(source_crs)) {
  cat("[*] Generando visualización espacial diagnóstica ...\n")
  sf_map <- sf::st_as_sf(dat_valid, coords = c("longitude", "latitude"), crs = 4326)
  
  if (requireNamespace("mapview", quietly = TRUE)) {
    tryCatch({
      m <- mapview::mapview(sf_map, zcol = if ("flag_spatial_outlier" %in% names(sf_map)) "flag_spatial_outlier" else NULL,
                            layer.name = "Perfiles de Suelo",
                            col.regions = c("#2A788EFF", "#D84315"),
                            legend = TRUE)
      print(m)
      cat("[OK] Mapa interactivo desplegado en el panel 'Viewer' de RStudio.\n")
    }, error = function(e) {
      cat("[AVISO] mapview no pudo desplegarse; generando gráfico con ggplot2.\n")
    })
  } else {
    p <- ggplot(dat_valid, aes(x = longitude, y = latitude, color = flag_spatial_outlier)) +
      geom_point(alpha = 0.7, size = 2) +
      scale_color_manual(values = c("FALSE" = "#2A788EFF", "TRUE" = "#D84315"),
                         labels = c("Normal", "Candidato Outlier"), name = "Estado") +
      theme_minimal() +
      labs(title = "Distribución Espacial de Perfiles",
           subtitle = sprintf("Total perfiles válidos: %d | Candidatos a outlier (IQR 3x): %d", nrow(dat_valid), outlier_count),
           x = "Longitud (WGS84)", y = "Latitud (WGS84)")
    print(p)
    cat("[OK] Gráfico espacial generado en el panel 'Plots' de RStudio.\n")
  }
}

# 8. Resumen en consola --------------------------------------------------------
cat("\n==============================================================================\n")
cat("  RESUMEN DE AUDITORÍA ESPACIAL (Paso 1.2)\n")
cat("==============================================================================\n")
cat(sprintf("Registros válidos analizados:          %d / %d (%.1f%%)\n", nrow(dat_valid), n_total, (nrow(dat_valid) / n_total) * 100))
cat(sprintf("Sistema de referencia:                 %s\n", crs_used))
cat(sprintf("Posibles outliers espaciales (IQR 3x): %d puntos detectados\n", outlier_count))
cat(sprintf("Acción aplicada:                       %s\n", outlier_action_applied))
cat(sprintf("[OK] Dataset espacial guardado en:     %s\n", output_csv))
cat(sprintf("[OK] Reporte espacial guardado en:     %s\n", output_report))
if (decision_logged) {
  cat(sprintf("[OK] Registro de decisiones en:        %s\n", decisions_log))
}
cat("==============================================================================\n\n")

cat("------------------------------------------------------------------------------\n")
cat("INSTRUCCIÓN PARA EL ALUMNO:\n")
cat("1. Revisa el mapa en RStudio (pestaña 'Viewer' o 'Plots').\n")
cat("2. En el chat con la IA, describe si los puntos corresponden a tu área de estudio\n")
cat("   o si identificas puntos aislados antes de avanzar al Paso 1.3.\n")
cat("------------------------------------------------------------------------------\n\n")
