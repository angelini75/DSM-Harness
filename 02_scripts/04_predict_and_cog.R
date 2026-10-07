# ==============================================================================
# DSM-Harness | Paso 4: Predicción Espacial, Incertidumbre y Exportación COG
# ==============================================================================
# OBJETIVO:
# Aplicar el modelo QRF calibrado sobre la grilla espacial de covariables
# utilizando predicción por bloques/mosaicos (optimizada para memoria RAM),
# estimar la media condicional e incertidumbre (desviación estándar condicional),
# exportar a Cloud-Optimized GeoTIFF (COG) estricto con overviews y compresión
# DEFLATE bajo la nomenclatura estandarizada de UN-FAO / OpenNSIS.
#
# SALIDAS GENERADAS:
# 1. Mapa de media COG:       'outputs/<CC>-<PROJ>-<PROP>-<d1>-<d2>-mean.tif'
# 2. Mapa de incertidumbre:   'outputs/<CC>-<PROJ>-<PROP>-<d1>-<d2>-sd.tif'
# 3. Reporte de verificación: 'reports/step4_prediction_report.txt'
# 4. Log de decisiones:       'decisions_log.csv'
#
# INSTRUCCIONES PARA EL ALUMNO:
# 1. Asegúrate de configurar 'country_code' (ej. GTM, MKD) y 'project_code' (ej. NACIONAL)
#    en 'config.json'.
# 2. Ejecuta este script en RStudio (Source o Ctrl+Shift+S) o mediante run_step("4").
# 3. Observa los mapas diagnósticos generados en la pestaña 'Plots' de RStudio.
# ==============================================================================

TEMPLATE_VERSION <- "2.0.0"

rm(list = setdiff(ls(), c("input_file", "input_csv", "TEMPLATE_VERSION", "PROJECT_DIR", "CURRENT_PROJECT_DIR", "PROJECT_NAME", "run_step")))

suppressPackageStartupMessages({
  library(tidyverse)
  library(terra)
  library(sf)
  library(ranger)
  library(caret)
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
  base_cov_dir  <- file.path(proj_active, "covariates")
  config_file   <- file.path(proj_active, "config.json")
  decisions_log <- file.path(proj_active, "decisions_log.csv")
} else {
  base_data_dir <- "01_data/profiles"
  base_rep_dir  <- "01_data/profiles"
  base_out_dir  <- "03_outputs/module3/maps"
  base_cov_dir  <- "01_data/covariates"
  config_file   <- "01_data/profiles/user_config.json"
  decisions_log <- "01_data/profiles/decisions_log.csv"
}

tile_tmp_dir  <- file.path(base_out_dir, "tiles_tmp")
if (!dir.exists(base_out_dir))  dir.create(base_out_dir, recursive = TRUE)
if (!dir.exists(base_rep_dir))  dir.create(base_rep_dir, recursive = TRUE)
if (!dir.exists(tile_tmp_dir))  dir.create(tile_tmp_dir, recursive = TRUE)

output_report <- file.path(base_rep_dir, "step4_prediction_report.txt")

# 2. Inicialización de Trazabilidad y Log de Decisiones ------------------------
run_id <- format(Sys.time(), "%Y%m%d_%H%M%S")
decision_logged <- FALSE

record_decision <- function(step, criterion, decision, source = "user_config",
                            affected_rows = 0, affected_profiles = 0, details = "") {
  entry <- data.frame(
    timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    run_id = run_id,
    template_version = TEMPLATE_VERSION,
    step = as.character(step),
    criterion = as.character(criterion),
    decision = as.character(decision),
    source = as.character(source),
    affected_rows = as.integer(affected_rows),
    affected_profiles = as.integer(affected_profiles),
    details = as.character(details),
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

# 4. Parámetros de nomenclatura OpenNSIS ---------------------------------------
target_prop <- if (!is.null(user_cfg$target_property)) as.character(user_cfg$target_property) else "SOC"
depth_d1    <- if (!is.null(user_cfg$target_depth_upper)) as.integer(user_cfg$target_depth_upper) else 0
depth_d2    <- if (!is.null(user_cfg$target_depth_lower)) as.integer(user_cfg$target_depth_lower) else 30

country_code <- if (!is.null(user_cfg$country_code) && nzchar(as.character(user_cfg$country_code))) {
  toupper(as.character(user_cfg$country_code))
} else {
  cat("\n[AVISO OPENNSIS]: 'country_code' no está declarado en config.json.\n")
  cat("  -> Se utilizará 'PAIS' como código provisional. Consulta tu código ISO-3 (ej. GTM, MKD) con la IA.\n")
  "PAIS"
}

project_code <- if (!is.null(user_cfg$project_code) && nzchar(as.character(user_cfg$project_code))) {
  toupper(as.character(user_cfg$project_code))
} else {
  cat("\n[AVISO OPENNSIS]: 'project_code' no está declarado en config.json.\n")
  cat("  -> Se utilizará 'PROJ' como código provisional. NUNCA inventes nombres de proyecto.\n")
  "PROJ"
}

# Nomenclatura canónica OpenNSIS: <CC>-<PROJ>-<PROP>-<d1>-<d2>-<stat>.tif
name_mean_cog <- sprintf("%s-%s-%s-%d-%d-mean.tif", country_code, project_code, target_prop, depth_d1, depth_d2)
name_sd_cog   <- sprintf("%s-%s-%s-%d-%d-sd.tif",   country_code, project_code, target_prop, depth_d1, depth_d2)

path_mean_cog <- file.path(base_out_dir, name_mean_cog)
path_sd_cog   <- file.path(base_out_dir, name_sd_cog)

cat(sprintf("[*] Nombres de archivo OpenNSIS configurados:\n  - Media:         %s\n  - Incertidumbre: %s\n",
            name_mean_cog, name_sd_cog))

# 5. Cargar modelo calibrado (QRF) ---------------------------------------------
model_files <- list.files(base_out_dir, pattern = sprintf("ranger_model_.*%s.*\\.rds$", target_prop), full.names = TRUE)
if (length(model_files) == 0) {
  model_files <- list.files(base_out_dir, pattern = "ranger_model_.*\\.rds$", full.names = TRUE)
}
if (length(model_files) == 0 && dir.exists("03_outputs/module3/models")) {
  model_files <- list.files("03_outputs/module3/models", pattern = "ranger_model_.*\\.rds$", full.names = TRUE)
}

if (length(model_files) == 0) {
  stop("[ERROR CRÍTICO] No se encontró ningún modelo entrenado (.rds). Ejecuta primero el Paso 3 (run_step('3')).")
}

model_path <- model_files[1]
cat(sprintf("[*] Cargando modelo entrenado desde: '%s' ...\n", model_path))
trained_caret <- readRDS(model_path)
ranger_model  <- trained_caret$finalModel
selected_covs <- ranger_model$forest$independent.variable.names

cat(sprintf("[OK] Modelo cargado. Covariables requeridas: %d capas.\n", length(selected_covs)))

# 6. Cargar pila de covariables espaciales --------------------------------------
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
  stop("[ERROR CRÍTICO] No se encontraron archivos ráster de covariables (.tif).")
}

cat("[*] Cargando pila espacial de covariables ...\n")
cov_stack <- terra::rast(avail_covs)

missing_covs <- setdiff(selected_covs, names(cov_stack))
if (length(missing_covs) > 0) {
  stop(sprintf("[ERROR CRÍTICO] Faltan covariables en el ráster requeridas por el modelo: [%s]",
               paste(missing_covs, collapse = ", ")))
}

cov_subset <- cov_stack[[selected_covs]]
grid_cells <- ncell(cov_subset)
cat(sprintf("[OK] Grilla espacial lista: %d columnas x %d filas (%s celdas totales).\n",
            ncol(cov_subset), nrow(cov_subset), format(grid_cells, big.mark = ".")))

# 7. Predicción Espacial Tiled / Bloques (Protección de Memoria RAM) ------------
cat("[*] Configurando predicción espacial por mosaicos ...\n")
pfun <- function(...) {
  predict(...)$predictions |> t()
}

# Determinar número de mosaicos según el tamaño de la grilla
n_tiles_x <- if (grid_cells > 2e6) 4 else if (grid_cells > 5e5) 2 else 1
n_tiles_y <- if (grid_cells > 2e6) 4 else if (grid_cells > 5e5) 2 else 1

r_ref <- cov_subset[[1]]
t_grid <- terra::rast(nrows = n_tiles_y, ncols = n_tiles_x, extent = ext(r_ref), crs = crs(r_ref))
tile_files <- terra::makeTiles(r_ref, t_grid, overwrite = TRUE,
                              filename = file.path(tile_tmp_dir, "tile_.tif"))

n_tiles <- length(tile_files)
cat(sprintf("[*] Grilla dividida en %d bloque(s) para predicción eficiente ...\n", n_tiles))

mean_tile_paths <- character(n_tiles)
sd_tile_paths   <- character(n_tiles)

for (j in seq_along(tile_files)) {
  cat(sprintf("  -> Procesando bloque %d de %d ...\n", j, n_tiles))
  t_crop <- terra::rast(tile_files[j])
  cov_tile <- terra::crop(cov_subset, t_crop)
  
  mean_t_file <- file.path(tile_tmp_dir, sprintf("t_mean_%d.tif", j))
  sd_t_file   <- file.path(tile_tmp_dir, sprintf("t_sd_%d.tif", j))
  
  # Predicción de Media Condicional
  terra::interpolate(
    cov_tile,
    model = ranger_model,
    fun = pfun,
    na.rm = TRUE,
    type = "quantiles",
    what = mean,
    filename = mean_t_file,
    overwrite = TRUE,
    wopt = list(datatype = "FLT4S", NAflag = -9999)
  )
  
  # Predicción de Incertidumbre (Desviación Estándar Condicional)
  terra::interpolate(
    cov_tile,
    model = ranger_model,
    fun = pfun,
    na.rm = TRUE,
    type = "quantiles",
    what = sd,
    filename = sd_t_file,
    overwrite = TRUE,
    wopt = list(datatype = "FLT4S", NAflag = -9999)
  )
  
  mean_tile_paths[j] <- mean_t_file
  sd_tile_paths[j]   <- sd_t_file
}

# Unir mosaicos en rásters consolidados
cat("[*] Ensamblando bloques espaciales en rásters finales ...\n")
if (n_tiles > 1) {
  mean_list <- lapply(mean_tile_paths, terra::rast)
  sd_list   <- lapply(sd_tile_paths, terra::rast)
  pred_mean_raw <- terra::mosaic(terra::sprc(mean_list), fun = "first")
  pred_sd_raw   <- terra::mosaic(terra::sprc(sd_list), fun = "first")
} else {
  pred_mean_raw <- terra::rast(mean_tile_paths[1])
  pred_sd_raw   <- terra::rast(sd_tile_paths[1])
}

names(pred_mean_raw) <- sprintf("%s_mean", target_prop)
names(pred_sd_raw)   <- sprintf("%s_sd", target_prop)

# Guardar GeoTIFF temporales para traducción COG
tmp_mean_tif <- file.path(tile_tmp_dir, "mosaic_mean_temp.tif")
tmp_sd_tif   <- file.path(tile_tmp_dir, "mosaic_sd_temp.tif")

terra::writeRaster(pred_mean_raw, tmp_mean_tif, overwrite = TRUE, datatype = "FLT4S", NAflag = -9999)
terra::writeRaster(pred_sd_raw,   tmp_sd_tif,   overwrite = TRUE, datatype = "FLT4S", NAflag = -9999)

# 8. Exportación a Cloud-Optimized GeoTIFF (COG Estricto con Overviews) --------
cat("[*] Generando Cloud-Optimized GeoTIFF (COG estándar FAO/OpenNSIS) con pirámides internas ...\n")

cog_translate_opts <- c(
  "-of", "COG",
  "-co", "COMPRESS=DEFLATE",
  "-co", "PREDICTOR=2",
  "-co", "BLOCKSIZE=512",
  "-co", "OVERVIEW_RESAMPLING=AVERAGE",
  "-co", "WARP_RESAMPLING=BILINEAR"
)

# Convertir media a verdadero COG
sf::gdal_utils("translate", tmp_mean_tif, path_mean_cog, options = cog_translate_opts)
cat(sprintf("[OK] COG Media exportado:         '%s'\n", path_mean_cog))

# Convertir desvío a verdadero COG
sf::gdal_utils("translate", tmp_sd_tif, path_sd_cog, options = cog_translate_opts)
cat(sprintf("[OK] COG Incertidumbre exportado: '%s'\n", path_sd_cog))

# Limpieza de archivos temporales
unlink(tile_tmp_dir, recursive = TRUE)

# 9. Verificación de Conformidad COG -------------------------------------------
desc_mean <- terra::describe(path_mean_cog)
is_true_cog <- any(grepl("LAYOUT=COG", desc_mean)) || any(grepl("Overviews", desc_mean))

cog_audit_status <- if (is_true_cog) "CONFORME (True COG con Overviews y LAYOUT=COG)" else "GEOTIFF CON COMPRESIÓN DEFLATE"
cat(sprintf("[*] Verificación técnica de salida: %s\n", cog_audit_status))

record_decision(4.0, "Exportación COG OpenNSIS", cog_audit_status,
                source = if (!is.null(user_cfg$country_code)) "user_config" else "script_default",
                affected_rows = ncell(pred_mean_raw), affected_profiles = 0,
                details = sprintf("Archivos: %s, %s. NoData: -9999, Compresión: DEFLATE, Predictor: 2", name_mean_cog, name_sd_cog))

# >>> ADAPT:prediction_and_cog
# Punto de extensión: inserción de máscaras de área de aplicabilidad (AOA), corte por límites administrativos o exportación adicional.
# Objetos disponibles: path_mean_cog (character), path_sd_cog (character), user_cfg (list), record_decision (function)
# <<< ADAPT:prediction_and_cog

# 10. Despliegue de Diagnósticos Gráficos en RStudio ----------------------------
cat("[*] Desplegando mapas predictivos en pestaña Plots de RStudio ...\n")
par(mfrow = c(1, 2), mar = c(3, 3, 3, 5))
plot(terra::rast(path_mean_cog), main = sprintf("Media Predicha: %s (%d-%d cm)", target_prop, depth_d1, depth_d2),
     col = hcl.colors(100, "Viridis"))
plot(terra::rast(path_sd_cog), main = sprintf("Incertidumbre (SD): %s (%d-%d cm)", target_prop, depth_d1, depth_d2),
     col = hcl.colors(100, "Inferno"))
par(mfrow = c(1, 1))

# 11. Generar reporte complementario .txt --------------------------------------
rep_con <- file(output_report, open = "wt", encoding = "UTF-8")
writeLines("================================================================================", rep_con)
writeLines("DSM-HARNESS | REPORTE DE PREDICCION ESPACIAL Y OPENNSIS COG (PASO 4)", rep_con)
writeLines(sprintf("Fecha de ejecucion: %s | Run ID: %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), run_id), rep_con)
writeLines("================================================================================", rep_con)
writeLines(sprintf("Variable objetivo:               %s", target_prop), rep_con)
writeLines(sprintf("Profundidad estandarizada:       %d-%d cm", depth_d1, depth_d2), rep_con)
writeLines(sprintf("Codigo de pais OpenNSIS (<CC>):  %s", country_code), rep_con)
writeLines(sprintf("Codigo de proyecto (<PROJ>):     %s", project_code), rep_con)
writeLines("--------------------------------------------------------------------------------", rep_con)
writeLines("ARCHIVOS GENERADOS BAJO ESTANDAR OPENNSIS:", rep_con)
writeLines(sprintf("  Mapa de Media:         %s", name_mean_cog), rep_con)
writeLines(sprintf("  Mapa de Incertidumbre: %s", name_sd_cog), rep_con)
writeLines(sprintf("  Ruta fisica:           %s", base_out_dir), rep_con)
writeLines("--------------------------------------------------------------------------------", rep_con)
writeLines("VERIFICACION TECNICA DEL RASTER:", rep_con)
writeLines(sprintf("  Estado COG:            %s", cog_audit_status), rep_con)
writeLines(sprintf("  Compresion GDAL:       DEFLATE (Predictor 2)"), rep_con)
writeLines(sprintf("  Tamano de bloque:      512 x 512 pixeles"), rep_con)
writeLines(sprintf("  Valor NoData:          -9999"), rep_con)
writeLines(sprintf("  Dimensiones espaciales:%d cols x %d rows", ncol(pred_mean_raw), nrow(pred_mean_raw)), rep_con)
writeLines("================================================================================", rep_con)
close(rep_con)
cat(sprintf("[OK] Reporte escrito en: '%s'\n", output_report))

# 12. Resumen en consola -------------------------------------------------------
cat("\n==============================================================================\n")
cat("  RESUMEN DE PREDICCIÓN ESPACIAL Y COG OPENNSIS (Paso 4)\n")
cat("==============================================================================\n")
cat(sprintf("Variable mapeada:         %s (%d–%d cm)\n", target_prop, depth_d1, depth_d2))
cat(sprintf("Estándar de archivo:      OpenNSIS Cloud-Optimized GeoTIFF (COG)\n"))
cat(sprintf("Archivo Media:            %s\n", name_mean_cog))
cat(sprintf("Archivo Incertidumbre:    %s\n", name_sd_cog))
cat(sprintf("[OK] Reporte guardado:    %s\n", output_report))
if (decision_logged) cat(sprintf("[OK] Log de decisiones:   %s\n", decisions_log))
cat("==============================================================================\n\n")
cat("------------------------------------------------------------------------------\n")
cat("INSTRUCCIÓN PARA EL ALUMNO:\n")
cat("1. Revisa los mapas desplegados en la pestaña 'Plots' de RStudio.\n")
cat("2. En el chat con la IA, dialoga sobre los patrones espaciales observados y las zonas de mayor incertidumbre.\n")
cat("------------------------------------------------------------------------------\n\n")
