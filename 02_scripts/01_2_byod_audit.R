# ==============================================================================
# DSM-Harness | Paso 1.2: Validación Espacial, CRS y Diagnóstico Geográfico
# ==============================================================================
# OBJETIVO:
# Auditar las coordenadas geográficas del dataset intermedio (Paso 1.1), verificar
# rangos de latitud/longitud, detectar sistemas proyectados (UTM, Gauss-Krüger)
# y transformar a WGS84 (EPSG:4326), generar visualización interactiva y
# producir un reporte de texto con las métricas espaciales para que la IA
# formule preguntas pedagógicas de reflexión territorial.
#
# SALIDAS GENERADAS:
# 1. Dataset intermedio: '01_data/profiles/step1_2_spatial.csv'
# 2. Reporte espacial:   '01_data/profiles/step1_2_spatial_report.txt'
# 3. Gráfico en RStudio:  Visualizador interactivo mapview o ggplot2
#
# INSTRUCCIONES PARA EL ALUMNO:
# 1. Ejecuta este script en RStudio (Source o Ctrl+Shift+S).
# 2. Observa el mapa interactivo que se abrirá en la pestaña 'Viewer' o 'Plots'.
# 3. Avísale a la IA en el chat cuando haya terminado de ejecutarse.
# ==============================================================================

rm(list = ls())

suppressPackageStartupMessages({
  library(tidyverse)
  library(sf)
})

# 1. Configuración de rutas y parámetros ---------------------------------------
input_csv     <- "01_data/profiles/step1_1_variables.csv"
output_csv    <- "01_data/profiles/step1_2_spatial.csv"
output_report <- "01_data/profiles/step1_2_spatial_report.txt"

# CRS de origen si las coordenadas son proyectadas (ej. UTM).
# Si tus coordenadas ya son WGS84 (grados decimales), déjalo en NA o 4326.
# La IA o el alumno pueden ajustar este valor si sus datos vienen en una proyección nacional específica:
source_crs <- NA  # Ejemplo: 32634 (UTM 34N), 32719 (UTM 19S), 5343 (POSGAR), etc.

if (!file.exists(input_csv)) {
  stop(sprintf("[ERROR] No se encontro '%s'. Debes ejecutar primero '02_scripts/01_1_byod_audit.R'.", input_csv))
}

cat(sprintf("\n[*] Cargando dataset del Paso 1.1: %s ...\n", input_csv))
dat <- readr::read_csv(input_csv, show_col_types = FALSE)

# 2. Verificación de presencia de coordenadas ----------------------------------
has_coords <- all(c("longitude", "latitude") %in% names(dat))

if (!has_coords) {
  stop("[ERROR FATAL]: Las columnas 'longitude' y/latitude' no estan presentes en el dataset. Revisa el mapeo en Paso 1.1.")
}

dat <- dat %>%
  mutate(
    longitude = as.numeric(longitude),
    latitude  = as.numeric(latitude)
  )

n_total <- nrow(dat)
n_profiles <- if ("profile_code" %in% names(dat)) length(unique(na.omit(dat$profile_code))) else n_total

# 3. Detección y Auditoría de Coordenadas ---------------------------------------
missing_coords <- sum(is.na(dat$longitude) | is.na(dat$latitude))
zero_coords    <- sum(dat$longitude == 0 & dat$latitude == 0, na.rm = TRUE)

valid_mask <- !is.na(dat$longitude) & !is.na(dat$latitude) & !(dat$longitude == 0 & dat$latitude == 0)
dat_valid  <- dat[valid_mask, ]

min_x <- min(dat_valid$longitude, na.rm = TRUE)
max_x <- max(dat_valid$longitude, na.rm = TRUE)
min_y <- min(dat_valid$latitude, na.rm = TRUE)
max_y <- max(dat_valid$latitude, na.rm = TRUE)

is_projected <- (max_x > 180 || min_x < -180 || max_y > 90 || min_y < -90)
coord_diagnosis <- ""
crs_used <- "EPSG:4326 (WGS84 nativo)"

if (is_projected) {
  cat("\n[ALERTA ESPACIAL]: Las coordenadas exceden los rangos de WGS84 (-180..180, -90..90).\n")
  cat(sprintf("  Rango X detectado: [%.1f, %.1f]\n", min_x, max_x))
  cat(sprintf("  Rango Y detectado: [%.1f, %.1f]\n", min_y, max_y))
  cat("  -> Se detectaron coordenadas métricas proyectadas (ej. UTM o cuadrícula nacional).\n")
  
  if (is.na(source_crs)) {
    # Heurística para sugerir zona UTM basada en valores X / Y
    cat("\n[ACCION REQUERIDA]: Define la variable 'source_crs' arriba con el código EPSG correspondiente a tu proyección.\n")
    cat("Ejemplo: source_crs <- 32634 para UTM Zona 34N, 32719 para UTM Zona 19S.\n")
    # Intentar continuar si el usuario ya tenía EPSG configurado
    coord_diagnosis <- "Coordenadas proyectadas detectadas. Pendiente confirmación de EPSG de origen."
  } else {
    cat(sprintf("[*] Transformando coordenadas desde EPSG:%s a EPSG:4326 (WGS84)...\n", as.character(source_crs)))
    sf_pts <- sf::st_as_sf(dat_valid, coords = c("longitude", "latitude"), crs = source_crs)
    sf_wgs84 <- sf::st_transform(sf_pts, crs = 4326)
    coords_wgs84 <- sf::st_coordinates(sf_wgs84)
    
    dat_valid$longitude <- coords_wgs84[, 1]
    dat_valid$latitude  <- coords_wgs84[, 2]
    
    crs_used <- sprintf("Transformado de EPSG:%s a EPSG:4326 (WGS84)", as.character(source_crs))
    min_x <- min(dat_valid$longitude)
    max_x <- max(dat_valid$longitude)
    min_y <- min(dat_valid$latitude)
    max_y <- max(dat_valid$latitude)
    coord_diagnosis <- "Coordenadas proyectadas transformadas exitosamente a WGS84."
  }
} else {
  # Verificar posible inversión latitud/longitud
  if (min_x > 0 && max_x < 90 && (min_y > 90 || min_y < -90)) {
    cat("[ALERTA]: Posible inversión de ejes X (longitud) e Y (latitud). Verificando...\n")
    coord_diagnosis <- "Posible inversión detectada entre latitud y longitud."
  } else {
    coord_diagnosis <- "Coordenadas geográficas estándar WGS84 (grados decimales)."
  }
}

# 4. Cálculo de Métricas Territoriales para el Reporte -------------------------
span_x <- max_x - min_x
span_y <- max_y - min_y

# Perfiles colocalizados (mismas coordenadas)
unique_locs <- dat_valid %>%
  distinct(longitude, latitude) %>%
  nrow()

# 5. Generación del Reporte Espacial en Texto (para lectura de la IA) ----------
report_con <- file(output_report, open = "wt", encoding = "UTF-8")
writeLines("================================================================================", report_con)
writeLines("  DSM-HARNESS | REPORTE PASO 1.2: AUDITORÍA ESPACIAL Y GEOGRÁFICA", report_con)
writeLines("================================================================================", report_con)
writeLines(paste("Fecha:", format(Sys.time(), "%Y-%m-%d %H:%M:%S")), report_con)
writeLines(paste("Archivo analizado:", input_csv), report_con)
writeLines(paste("Diagnóstico general:", coord_diagnosis), report_con)
writeLines(paste("Sistema de referencia (CRS):", crs_used), report_con)
writeLines("--------------------------------------------------------------------------------", report_con)
writeLines("MÉTRICAS DE REGISTROS Y LOCALIZACIONES:", report_con)
writeLines(sprintf("  Total registros (horizontes):       %d", n_total), report_con)
writeLines(sprintf("  Registros con coordenadas válidas:  %d (%.1f%%)", nrow(dat_valid), (nrow(dat_valid) / n_total) * 100), report_con)
writeLines(sprintf("  Registros con coordenadas nulas/NA: %d", missing_coords), report_con)
writeLines(sprintf("  Registros en (0, 0):                %d", zero_coords), report_con)
writeLines(sprintf("  Sitios / ubicaciones únicas:        %d", unique_locs), report_con)
if ("profile_code" %in% names(dat)) {
  writeLines(sprintf("  Perfiles únicos identificados:      %d", n_profiles), report_con)
}
writeLines("--------------------------------------------------------------------------------", report_con)
writeLines("EXTENSIÓN ESPACIAL (BOUNDING BOX EN WGS84):", report_con)
writeLines(sprintf("  Longitud mínima (Oeste):  %10.5f°", min_x), report_con)
writeLines(sprintf("  Longitud máxima (Este):   %10.5f°", max_x), report_con)
writeLines(sprintf("  Amplitud Este-Oeste:      %10.5f°", span_x), report_con)
writeLines(sprintf("  Latitud mínima (Sur):     %10.5f°", min_y), report_con)
writeLines(sprintf("  Latitud máxima (Norte):   %10.5f°", max_y), report_con)
writeLines(sprintf("  Amplitud Norte-Sur:       %10.5f°", span_y), report_con)
writeLines("--------------------------------------------------------------------------------", report_con)
writeLines("ELEMENTOS OBSERVABLES EN EL GRÁFICO (PARA ANÁLISIS DE LA IA):", report_con)
writeLines(sprintf("  - Bounding Box: [%.3f, %.3f] Longitud x [%.3f, %.3f] Latitud", min_x, max_x, min_y, max_y), report_con)
writeLines(sprintf("  - Cobertura espacial: %.2f x %.2f grados (~ %.0f x %.0f km aprox.)", 
                   span_x, span_y, span_x * 111 * cos(mean(c(min_y, max_y)) * pi / 180), span_y * 111), report_con)
writeLines(sprintf("  - Dispersión: %d sitios distribuidos en el área de estudio.", unique_locs), report_con)
writeLines("================================================================================", report_con)
close(report_con)

# 6. Exportar dataset intermedio con coordenadas validadas ---------------------
readr::write_csv(dat_valid, output_csv)

# 7. Diagnóstico Visual en RStudio ---------------------------------------------
cat("\n[*] Generando visualización geográfica en RStudio...\n")

# Intentar mapa interactivo con mapview si está disponible
has_mapview <- requireNamespace("mapview", quietly = TRUE)

sf_pts_view <- sf::st_as_sf(
  dat_valid %>% distinct(longitude, latitude, .keep_all = TRUE),
  coords = c("longitude", "latitude"),
  crs = 4326
)

if (has_mapview) {
  # Visualización interactiva Leaflet/mapview
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
  # Fallback a ggplot2
  p <- ggplot() +
    geom_point(data = dat_valid, aes(x = longitude, y = latitude), color = "darkred", alpha = 0.6, size = 1.5) +
    coord_quickmap() +
    theme_minimal() +
    labs(
      title = "Distribución Espacial de Perfiles de Suelo",
      subtitle = sprintf("Total: %d puntos válidos | BBox: [%.2f, %.2f] Lon, [%.2f, %.2f] Lat", 
                         nrow(dat_valid), min_x, max_x, min_y, max_y),
      x = "Longitud (°)",
      y = "Latitud (°)"
    )
  print(p)
  cat("[OK] Gráfico espacial generado en la pestaña 'Plots' de RStudio.\n")
}

cat("\n==============================================================================\n")
cat("  RESUMEN DE AUDITORÍA ESPACIAL (Paso 1.2)\n")
cat("==============================================================================\n")
cat(sprintf("  Puntos válidos:       %d de %d (%.1f%%)\n", nrow(dat_valid), n_total, (nrow(dat_valid)/n_total)*100))
cat(sprintf("  Ubicaciones únicas:   %d sitios\n", unique_locs))
cat(sprintf("  Extensión Longitud:   [%.4f°, %.4f°]\n", min_x, max_x))
cat(sprintf("  Extensión Latitud:    [%.4f°, %.4f°]\n", min_y, max_y))
cat(sprintf("  Dataset guardado en:  %s\n", output_csv))
cat(sprintf("  Reporte guardado en:  %s\n", output_report))
cat("==============================================================================\n\n")

cat("------------------------------------------------------------------------------\n")
cat("INSTRUCCIÓN PARA EL ALUMNO:\n")
cat("1. Examina el mapa en el visor de RStudio.\n")
cat("2. Verifica si los puntos caen exactamente en la zona o país de estudio.\n")
cat("3. Avísale a la IA en el chat que ya ejecutaste '01_2_byod_audit.R'.\n")
cat("   -> La IA leerá el reporte espacial y te hará preguntas sobre la distribución.\n")
cat("------------------------------------------------------------------------------\n\n")
