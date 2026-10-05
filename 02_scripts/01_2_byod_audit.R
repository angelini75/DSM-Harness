# ==============================================================================
# DSM-Harness | Paso 1.2: Validación Espacial, CRS y Diagnóstico Geográfico
# ==============================================================================
# OBJETIVO:
# Auditar las coordenadas geográficas del dataset intermedio (Paso 1.1), verificar
# rangos reales de latitud/longitud, detectar sistemas métricos proyectados
# (UTM, Gauss-Krüger), sugerir o aplicar transformación a WGS84 (EPSG:4326),
# detectar potenciales outliers espaciales, generar visualización interactiva y
# producir un reporte de texto con métricas 100% calculadas.
#
# SALIDAS GENERADAS:
# 1. Dataset intermedio: '01_data/profiles/step1_2_spatial.csv'
# 2. Reporte espacial:   '01_data/profiles/step1_2_spatial_report.txt'
# 3. Log de decisiones:  '01_data/profiles/decisions_log.csv'
# 4. Gráfico en RStudio: Visualizador interactivo mapview o ggplot2
#
# INSTRUCCIONES PARA EL ALUMNO:
# 1. Ejecuta este script en RStudio (Source o Ctrl+Shift+S).
# 2. Observa el mapa en 'Viewer' o 'Plots' y las alertas en consola.
# 3. Dialoga con la IA en el chat para confirmar el CRS y decidir sobre outliers.
# ==============================================================================

TEMPLATE_VERSION <- "2.0.0"

rm(list = setdiff(ls(), c("input_csv", "TEMPLATE_VERSION")))

suppressPackageStartupMessages({
  library(tidyverse)
  library(sf)
})

# 1. Configuración de rutas y parámetros ---------------------------------------
config_file   <- "01_data/profiles/user_config.json"
input_csv     <- "01_data/profiles/step1_1_variables.csv"
output_csv    <- "01_data/profiles/step1_2_spatial.csv"
output_report <- "01_data/profiles/step1_2_spatial_report.txt"
decisions_log <- "01_data/profiles/decisions_log.csv"
decision_logged <- FALSE

# Función auxiliar para registrar decisiones en decisions_log.csv
record_decision <- function(step, criterion, decision, affected_rows = 0, affected_profiles = 0, details = "") {
  log_entry <- data.frame(
    timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    step = as.character(step),
    criterion = as.character(criterion),
    user_decision = as.character(decision),
    affected_rows = as.integer(affected_rows),
    affected_profiles = as.integer(affected_profiles),
    details = as.character(details),
    stringsAsFactors = FALSE
  )
  if (!file.exists(decisions_log)) {
    write.csv(log_entry, decisions_log, row.names = FALSE)
  } else {
    write.table(log_entry, decisions_log, sep = ",", col.names = FALSE, row.names = FALSE, append = TRUE)
  }
  decision_logged <<- TRUE
}

# Cargar configuración de usuario si existe
user_cfg <- list()
if (file.exists(config_file)) {
  tryCatch({
    if (requireNamespace("jsonlite", quietly = TRUE)) {
      user_cfg <- jsonlite::fromJSON(config_file)
      cat(sprintf("[*] Configuración de usuario cargada desde: '%s'\n", config_file))
    }
  }, error = function(e) {
    cat(sprintf("[AVISO] No se pudo parsear '%s': %s\n", config_file, e$message))
  })
}

# Parámetro CRS: configurable en user_config.json o en entorno R
source_crs <- if (!is.null(user_cfg$source_crs)) as.integer(user_cfg$source_crs) else (if (exists("source_crs")) source_crs else NA)

if (!file.exists(input_csv)) {
  stop(sprintf("[ERROR] No se encontró '%s'. Debes ejecutar primero '02_scripts/01_1_byod_audit.R'.", input_csv))
}

cat(sprintf("\n[*] Cargando dataset del Paso 1.1: %s ...\n", input_csv))
dat <- readr::read_csv(input_csv, show_col_types = FALSE)

# 2. Verificación de presencia de coordenadas ----------------------------------
has_coords <- all(c("longitude", "latitude") %in% names(dat))
if (!has_coords) {
  stop("[ERROR FATAL]: Las columnas 'longitude' y 'latitude' no están presentes en el dataset. Revisa el mapeo en Paso 1.1.")
}

dat <- dat %>%
  mutate(
    longitude = as.numeric(longitude),
    latitude  = as.numeric(latitude)
  )

n_total <- nrow(dat)
n_profiles <- if ("profile_code" %in% names(dat)) length(unique(na.omit(dat$profile_code))) else n_total

# 3. Detección y Auditoría 100% Calculada de Coordenadas -----------------------
missing_coords_mask <- is.na(dat$longitude) | is.na(dat$latitude)
zero_coords_mask    <- (!missing_coords_mask) & (dat$longitude == 0 & dat$latitude == 0)

missing_coords_count <- sum(missing_coords_mask)
zero_coords_count    <- sum(zero_coords_mask)

# Perfiles afectados por coordenadas nulas
orphan_profiles_coords <- if ("profile_code" %in% names(dat)) {
  unique(na.omit(dat$profile_code[missing_coords_mask | zero_coords_mask]))
} else character(0)

valid_mask <- (!missing_coords_mask) & (!zero_coords_mask)
dat_valid  <- dat[valid_mask, ]

if (nrow(dat_valid) == 0) {
  stop("[ERROR FATAL]: Ningún registro posee coordenadas válidas no nulas.")
}

min_x_raw <- min(dat_valid$longitude, na.rm = TRUE)
max_x_raw <- max(dat_valid$longitude, na.rm = TRUE)
min_y_raw <- min(dat_valid$latitude, na.rm = TRUE)
max_y_raw <- max(dat_valid$latitude, na.rm = TRUE)

# Detección de sistema métrico proyectado vs. grados geográficos
is_projected <- (max_x_raw > 180 || min_x_raw < -180 || max_y_raw > 90 || min_y_raw < -90)
coord_diagnosis <- ""
crs_used <- "EPSG:4326 (WGS84 nativo)"

# >>> ADAPT:crs_and_outliers
if (is_projected) {
  cat("\n[ALERTA ESPACIAL]: Las coordenadas exceden los rangos de WGS84 (-180..180, -90..90).\n")
  cat(sprintf("  Rango X: [%.1f, %.1f] | Rango Y: [%.1f, %.1f]\n", min_x_raw, max_x_raw, min_y_raw, max_y_raw))
  cat("  -> Se detectaron coordenadas métricas proyectadas (ej. UTM o cuadrícula nacional).\n")
  
  if (is.na(source_crs) || is.null(source_crs)) {
    coord_diagnosis <- "Coordenadas proyectadas detectadas. Requiere confirmación del código EPSG por el usuario."
    cat("\n[ACCION REQUERIDA]: Consulta al usuario el EPSG de origen en el chat antes de reproyectar.\n")
    # No transformar ciegamente; mantener coordenadas originales
  } else {
    cat(sprintf("[*] Reproyectando coordenadas desde EPSG:%s a EPSG:4326 (WGS84)...\n", as.character(source_crs)))
    sf_pts <- sf::st_as_sf(dat_valid, coords = c("longitude", "latitude"), crs = source_crs)
    sf_wgs84 <- sf::st_transform(sf_pts, crs = 4326)
    coords_wgs84 <- sf::st_coordinates(sf_wgs84)
    
    dat_valid$longitude <- coords_wgs84[, 1]
    dat_valid$latitude  <- coords_wgs84[, 2]
    crs_used <- sprintf("Transformado de EPSG:%s a EPSG:4326 (WGS84)", as.character(source_crs))
    coord_diagnosis <- sprintf("Coordenadas transformadas a WGS84 desde EPSG:%s.", as.character(source_crs))
    
    record_decision(1.2, "Transformación CRS", sprintf("Reproyección EPSG:%s -> EPSG:4326", source_crs),
                    affected_rows = nrow(dat_valid), affected_profiles = n_profiles,
                    details = sprintf("Coordenadas originales: X[%.1f, %.1f], Y[%.1f, %.1f]", min_x_raw, max_x_raw, min_y_raw, max_y_raw))
  }
} else {
  # Verificar posible inversión latitud/longitud
  if (min_x_raw > -90 && max_x_raw < 90 && (min_y_raw < -90 || max_y_raw > 90 || min_x_raw > 0)) {
    coord_diagnosis <- "Posible inversión entre latitud y longitud; verificar visualmente en mapa."
  } else {
    coord_diagnosis <- "Coordenadas geográficas estándar WGS84 (grados decimales)."
  }
}

min_x <- min(dat_valid$longitude, na.rm = TRUE)
max_x <- max(dat_valid$longitude, na.rm = TRUE)
min_y <- min(dat_valid$latitude, na.rm = TRUE)
max_y <- max(dat_valid$latitude, na.rm = TRUE)
span_x <- max_x - min_x
span_y <- max_y - min_y

# 4. Auditoría de Outliers Espaciales y Puntos Sospechosos ---------------------
# Cálculo de dispersión basada en IQR respecto a la mediana
med_x <- median(dat_valid$longitude, na.rm = TRUE)
med_y <- median(dat_valid$latitude, na.rm = TRUE)
iqr_x <- IQR(dat_valid$longitude, na.rm = TRUE)
iqr_y <- IQR(dat_valid$latitude, na.rm = TRUE)

# Si el IQR es mayor a cero, marcar puntos a más de 3*IQR de los cuartiles
outlier_mask <- rep(FALSE, nrow(dat_valid))
if (iqr_x > 0 && iqr_y > 0) {
  q1_x <- quantile(dat_valid$longitude, 0.25, na.rm = TRUE)
  q3_x <- quantile(dat_valid$longitude, 0.75, na.rm = TRUE)
  q1_y <- quantile(dat_valid$latitude, 0.25, na.rm = TRUE)
  q3_y <- quantile(dat_valid$latitude, 0.75, na.rm = TRUE)
  
  outlier_mask <- (dat_valid$longitude < (q1_x - 3 * iqr_x)) | (dat_valid$longitude > (q3_x + 3 * iqr_x)) |
                  (dat_valid$latitude  < (q1_y - 3 * iqr_y)) | (dat_valid$latitude  > (q3_y + 3 * iqr_y))
}

outlier_count <- sum(outlier_mask)
dat_valid$flag_spatial_outlier <- outlier_mask

# Aplicar decisión del usuario sobre outliers si está configurada
outlier_action_applied <- "Ninguna (puntos marcados con flag_spatial_outlier para revisión)"
target_outlier_act <- if (!is.null(user_cfg$outlier_action)) user_cfg$outlier_action else user_cfg$spatial_outlier_action
if (!is.null(target_outlier_act) && outlier_count > 0) {
  if (target_outlier_act == "exclude") {
    dat_valid <- dat_valid %>% filter(!flag_spatial_outlier)
    outlier_action_applied <- sprintf("Excluidos %d registros outliers", outlier_count)
    record_decision(1.2, "Outliers espaciales", "Excluir puntos anómalos", affected_rows = outlier_count, details = "Filtro IQR aplicado tras confirmación")
  } else if (target_outlier_act == "flag") {
    outlier_action_applied <- sprintf("Conservados con flag_spatial_outlier = TRUE (%d registros)", outlier_count)
    record_decision(1.2, "Outliers espaciales", "Conservar y marcar bandera", affected_rows = outlier_count, details = "Columna flag_spatial_outlier agregada")
  } else {
    outlier_action_applied <- "Conservados como válidos por decisión del usuario"
    record_decision(1.2, "Outliers espaciales", "Conservar como válidos", affected_rows = outlier_count)
  }
}
# <<< ADAPT:crs_and_outliers

# Perfiles colocalizados (mismas coordenadas)
unique_locs <- dat_valid %>%
  distinct(longitude, latitude) %>%
  nrow()

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
writeLines("EXTENSIÓN ESPACIAL CALCULADA (BOUNDING BOX):", report_con)
writeLines(sprintf("  Longitud mínima (Oeste):  %10.5f", min_x), report_con)
writeLines(sprintf("  Longitud máxima (Este):   %10.5f", max_x), report_con)
writeLines(sprintf("  Amplitud Este-Oeste:      %10.5f", span_x), report_con)
writeLines(sprintf("  Latitud mínima (Sur):     %10.5f", min_y), report_con)
writeLines(sprintf("  Latitud máxima (Norte):   %10.5f", max_y), report_con)
writeLines(sprintf("  Amplitud Norte-Sur:       %10.5f", span_y), report_con)
writeLines("--------------------------------------------------------------------------------", report_con)
writeLines("AUDITORÍA DE PUNTOS SOSPECHOSOS Y OUTLIERS ESPACIALES:", report_con)
writeLines(sprintf("  Puntos detectados como posibles outliers: %d", outlier_count), report_con)
writeLines(sprintf("  Acción aplicada sobre outliers:           %s", outlier_action_applied), report_con)
if (outlier_count > 0) {
  outliers_df <- dat_valid[outlier_mask, ]
  writeLines("  Listado de registros sospechosos:", report_con)
  p_col <- if ("profile_code" %in% names(outliers_df)) "profile_code" else names(outliers_df)[1]
  for (j in seq_len(min(nrow(outliers_df), 10))) {
    writeLines(sprintf("    - ID: %s | Longitud: %.5f | Latitud: %.5f", 
                       as.character(outliers_df[[p_col]][j]), outliers_df$longitude[j], outliers_df$latitude[j]), report_con)
  }
  if (nrow(outliers_df) > 10) {
    writeLines(sprintf("    ... y %d registros más (ver tabla en RStudio)", nrow(outliers_df) - 10), report_con)
  }
}
writeLines("================================================================================", report_con)
close(report_con)

# 6. Exportar dataset intermedio ------------------------------------------------
readr::write_csv(dat_valid, output_csv)

# 7. Diagnóstico Visual en RStudio ---------------------------------------------
cat("\n[*] Generando visualización geográfica en RStudio...\n")

sf_pts_view <- sf::st_as_sf(
  dat_valid %>% distinct(longitude, latitude, .keep_all = TRUE),
  coords = c("longitude", "latitude"),
  crs = if (!is_projected || !is.na(source_crs)) 4326 else NA
)

if (requireNamespace("mapview", quietly = TRUE) && (!is_projected || !is.na(source_crs))) {
  color_col <- if ("SOC" %in% names(sf_pts_view)) "SOC" else (if ("pH_H2O" %in% names(sf_pts_view)) "pH_H2O" else NULL)
  
  if (!is.null(color_col)) {
    m <- mapview::mapview(sf_pts_view, zcol = color_col, layer.name = paste("Perfiles:", color_col),
                          map.types = c("CartoDB.Positron", "OpenStreetMap", "Esri.WorldImagery"))
  } else {
    m <- mapview::mapview(sf_pts_view, layer.name = "Perfiles de Suelo",
                          map.types = c("CartoDB.Positron", "OpenStreetMap", "Esri.WorldImagery"))
  }
  print(m)
  cat("[OK] Mapa interactivo cargado en la pestaña 'Viewer' de RStudio.\n")
} else {
  p <- ggplot() +
    geom_point(data = dat_valid, aes(x = longitude, y = latitude, color = flag_spatial_outlier), alpha = 0.7, size = 2) +
    scale_color_manual(values = c("FALSE" = "#2b8cbe", "TRUE" = "#e41a1c"), name = "¿Outlier?") +
    coord_quickmap() +
    theme_minimal() +
    labs(
      title = "Distribución Espacial de Perfiles de Suelo",
      subtitle = sprintf("Válidos: %d | BBox: [%.2f, %.2f] X, [%.2f, %.2f] Y", 
                         nrow(dat_valid), min_x, max_x, min_y, max_y),
      x = "Coordenada X / Longitud",
      y = "Coordenada Y / Latitud"
    )
  print(p)
  cat("[OK] Gráfico espacial generado en la pestaña 'Plots' de RStudio.\n")
}

cat("\n==============================================================================\n")
cat("  RESUMEN DE AUDITORÍA ESPACIAL (Paso 1.2)\n")
cat("==============================================================================\n")
cat(sprintf("  Puntos válidos:       %d de %d (%.1f%%)\n", nrow(dat_valid), n_total, (nrow(dat_valid)/n_total)*100))
cat(sprintf("  Ubicaciones únicas:   %d sitios\n", unique_locs))
cat(sprintf("  Extensión X:          [%.4f, %.4f]\n", min_x, max_x))
cat(sprintf("  Extensión Y:          [%.4f, %.4f]\n", min_y, max_y))
cat(sprintf("  Posibles outliers:    %d puntos detectados\n", outlier_count))
cat(sprintf("[OK] Dataset guardado en:  %s\n", output_csv))
cat(sprintf("[OK] Reporte guardado en:  %s\n", output_report))
if (decision_logged) {
  cat(sprintf("[OK] Registro decisiones:  %s\n", decisions_log))
} else {
  cat(sprintf("[*] Registro decisiones:  Sin cambios en esta corrida (%s)\n", decisions_log))
}
cat("==============================================================================\n\n")

cat("------------------------------------------------------------------------------\n")
cat("INSTRUCCIÓN PARA EL ALUMNO:\n")
cat("1. Examina el mapa y las alertas en la consola de RStudio.\n")
cat("2. En el chat con la IA, comenta si la ubicación territorial es correcta y\n")
cat("   qué decisión tomar ante posibles puntos fuera de zona antes del Paso 1.3.\n")
cat("------------------------------------------------------------------------------\n\n")
