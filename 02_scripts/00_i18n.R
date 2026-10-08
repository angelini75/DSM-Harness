# ==============================================================================
# DSM-Harness | 00_i18n.R: Central Internationalization (i18n) Engine
# ==============================================================================
# PURPOSE:
# Provides bilingual support (Spanish 'es' / English 'en') for DSM-Harness:
# - Console messages (cat)
# - Companion text reports (reports/*.txt)
# - Traceability logging (decisions_log.csv)
# - Configuration error and warning messages
# - UI labels and metadata for Step 5 HTML reports
#
# DEFAULT: 'es' (Spanish, preserving full backward compatibility)
# ==============================================================================

TEMPLATE_VERSION <- "2.0.0"

# 1. Detection of active language ---------------------------------------------
get_project_language <- function(cfg = NULL) {
  lang <- NULL
  if (!is.null(cfg) && is.list(cfg) && !is.null(cfg$language)) {
    lang <- tolower(trimws(as.character(cfg$language)))
  } else if (exists("user_cfg", envir = parent.frame()) && !is.null(get("user_cfg", envir = parent.frame())$language)) {
    lang <- tolower(trimws(as.character(get("user_cfg", envir = parent.frame())$language)))
  } else if (exists("config_file", envir = parent.frame()) && file.exists(get("config_file", envir = parent.frame()))) {
    tryCatch({
      c_path <- get("config_file", envir = parent.frame())
      if (requireNamespace("jsonlite", quietly = TRUE)) {
        c_data <- jsonlite::fromJSON(c_path, simplifyVector = FALSE)
        if (!is.null(c_data$language)) lang <- tolower(trimws(as.character(c_data$language)))
      }
    }, error = function(e) NULL)
  } else if (file.exists("config.json")) {
    tryCatch({
      if (requireNamespace("jsonlite", quietly = TRUE)) {
        c_data <- jsonlite::fromJSON("config.json", simplifyVector = FALSE)
        if (!is.null(c_data$language)) lang <- tolower(trimws(as.character(c_data$language)))
      }
    }, error = function(e) NULL)
  } else if (file.exists("01_data/profiles/user_config.json")) {
    tryCatch({
      if (requireNamespace("jsonlite", quietly = TRUE)) {
        c_data <- jsonlite::fromJSON("01_data/profiles/user_config.json", simplifyVector = FALSE)
        if (!is.null(c_data$language)) lang <- tolower(trimws(as.character(c_data$language)))
      }
    }, error = function(e) NULL)
  } else if (exists("PROJECT_LANGUAGE", envir = .GlobalEnv)) {
    lang <- tolower(trimws(as.character(get("PROJECT_LANGUAGE", envir = .GlobalEnv))))
  } else if (exists("HARNESS_LANG", envir = .GlobalEnv)) {
    lang <- tolower(trimws(as.character(get("HARNESS_LANG", envir = .GlobalEnv))))
  }
  
  if (!is.null(lang) && lang %in% c("en", "es")) {
    return(lang)
  }
  return("es")
}

# 2. Status terms --------------------------------------------------------------
i18n_not_evaluated <- function(lang = "es") {
  if (identical(lang, "en")) "NOT EVALUATED" else "NO EVALUADO"
}

i18n_present <- function(lang = "es") {
  if (identical(lang, "en")) "PRESENT" else "PRESENTE"
}

i18n_missing <- function(lang = "es") {
  if (identical(lang, "en")) "MISSING" else "FALTANTE"
}

i18n_not_applicable <- function(lang = "es") {
  if (identical(lang, "en")) "NOT APPLICABLE" else "NO APLICA"
}

# 3. Decisions Log Translation -------------------------------------------------
# Maps canonical Spanish terms in decisions_log to English when language is 'en'
translate_decision_text <- function(text, lang = "es") {
  if (!identical(lang, "en") || is.null(text) || !nzchar(as.character(text))) {
    return(as.character(text))
  }
  
  txt <- as.character(text)
  
  trans_map <- list(
    # Step 1.1 Criteria & Decisions
    "Auditoría de variables BYOD"                = "BYOD variable audit",
    "Claves duplicadas en tabla de sitios"       = "Duplicate keys in site table",
    "Promediar réplicas antes de unir"           = "Average replicates before join",
    "Conservar primera ocurrencia"               = "Keep first occurrence",
    "Claves duplicadas en unión"                 = "Duplicate keys in join table",
    "Claves duplicadas en horizontes"            = "Duplicate keys in horizons table",
    "Promediar réplicas analíticas"              = "Average analytical replicates",
    "Conservar y marcar bandera"                 = "Keep and flag",
    "Filas duplicadas post-unión"                = "Duplicate rows post-join",
    "Conservar primera ocurrencia (eliminar filas idénticas)" = "Keep first occurrence (drop identical rows)",
    "Unión multi-hoja"                           = "Multi-sheet join",
    "Unión de tablas"                            = "Table join",
    "left_join relacional"                       = "Relational left_join",
    "Suma de fracciones de arena"                = "Sum of sand fractions",
    "Conservación de columnas adicionales"       = "Preserve additional columns",
    "Derivación SOC"                             = "SOC derivation",
    
    # Step 1.2 Criteria & Decisions
    "Auditoría espacial de coordenadas"          = "Spatial coordinate audit",
    "Transformación CRS"                         = "CRS transformation",
    "Sistema de referencia (CRS)"                = "Coordinate Reference System (CRS)",
    "WGS84 geográfico (EPSG:4326)"               = "Geographic WGS84 (EPSG:4326)",
    "Outliers espaciales"                        = "Spatial outliers",
    "Excluir puntos anómalos"                    = "Exclude anomalous points",
    "Conservar como válidos"                     = "Keep as valid",
    "Evaluación completada"                      = "Evaluation completed",
    "Coordenadas métricas proyectadas"           = "Projected metric coordinates",
    
    # Step 1.3 Criteria & Decisions
    "Auditoría pedológica y vertical"            = "Pedological and vertical audit",
    "Profundidades invertidas"                   = "Inverted depths",
    "Inversión automática de límites (swap)"     = "Automatic limit swap",
    "Balance textural"                           = "Texture balance",
    "Normalizado a 100%"                         = "Normalized to 100%",
    "Estimación BD"                              = "Bulk density estimation",
    "Estimación de densidad aparente"            = "Bulk density estimation",
    "Calibración paramétrica local"              = "Local parametric calibration",
    "Función de pedotransferencia de referencia" = "Reference pedotransfer function",
    "Sin estimación (solo valores medidos)"      = "No estimation (measured values only)",
    "Omitida por opción no disponible"           = "Skipped (option unavailable)",
    "Diagnóstico completado sin imputar (espera confirmación de usuario)" = "Diagnostic completed without imputation (awaiting user confirmation)",
    "Contraste completado sin imputar (espera confirmación de usuario)"   = "Contrast completed without imputation (awaiting user confirmation)",
    "Omitida por datos insuficientes (n < 5)"    = "Skipped due to insufficient data (n < 5)",
    "Omitida por falta de variables predictoras" = "Skipped due to missing predictors",
    "Continuidad vertical de horizontes"         = "Vertical horizon continuity",
    
    # Step 2 Criteria & Decisions
    "Filtro de calidad"                          = "Quality filter",
    "Exclusión de outliers espaciales marcados"  = "Exclusion of flagged spatial outliers",
    "Estandarización de profundidad"             = "Depth standardization",
    "Máscara de covariables"                     = "Covariate mask",
    "Filtrado de puntos fuera de máscara"        = "Filter points outside mask",
    "Extracción de covariables"                  = "Covariate extraction",
    "Extracción de covariables ambientales"      = "Environmental covariate extraction",
    
    # Step 3 Criteria & Decisions
    "Modelado espacial QRF"                      = "Spatial QRF modeling",
    "Selección de características"               = "Feature selection",
    "Evaluación de modelo"                       = "Model evaluation",
    "Modelado QRF y selección de variables"      = "QRF modeling and feature selection",
    "Afinación y métricas QRF"                   = "QRF tuning and metrics",
    
    # Step 4 Criteria & Decisions
    "Exportación COG OpenNSIS"                   = "OpenNSIS COG export",
    "Predicción espacial y exportación COG"      = "Spatial prediction and COG export",
    
    # Step 5 Criteria & Decisions
    "Reporte final de mapeo"                     = "Final mapping report",
    "Reporte HTML independiente generado"        = "Rendered standalone HTML report",
    "Reporte HTML generado"                      = "Generated HTML report",
    
    # Common details & decisions
    "Sin réplicas ni duplicados en claves evaluadas" = "No replicates or duplicates in evaluated keys",
    "Sin transformación requerida"               = "No transformation required",
    "Fracciones de arena consolidadas en Sand para análisis textural" = "Sand fractions consolidated into Sand for textural analysis",
    "Perfiles marcados en Paso 1.2 no ingresan a la extracción"       = "Profiles flagged in Step 1.2 excluded from extraction",
    "Todas las covariables (ninguna confirmada por Boruta)"           = "All covariates (none confirmed by Boruta)",
    "Modelo QRF ranger entrenado"                = "Trained ranger QRF model",
    "Predicciones continuas y desviaciones estándar" = "Continuous predictions and standard deviations"
  )
  
  if (txt %in% names(trans_map)) {
    return(trans_map[[txt]])
  }
  
  # Dynamic translations for details and composite decisions
  txt_res <- txt
  txt_res <- gsub("Hoja: ", "Sheet: ", txt_res, fixed = TRUE)
  txt_res <- gsub("Columna flag_spatial_outlier agregada sobre", "flag_spatial_outlier column added over", txt_res, fixed = TRUE)
  txt_res <- gsub("Conservados como válidos por decisión del usuario", "Kept as valid by user decision", txt_res, fixed = TRUE)
  txt_res <- gsub("Conversión de Materia Orgánica a Carbono Orgánico aprobada por usuario", "Organic Matter to Soil Organic Carbon conversion confirmed by user", txt_res, fixed = TRUE)
  txt_res <- gsub("Reporte HTML generado: ", "Generated HTML report: ", txt_res, fixed = TRUE)
  txt_res <- gsub("Formato: HTML autocontenido", "Format: Standalone HTML", txt_res, fixed = TRUE)
  txt_res <- gsub("Reproyección EPSG:", "Reprojection EPSG:", txt_res, fixed = TRUE)
  txt_res <- gsub("Preservadas: ", "Preserved: ", txt_res, fixed = TRUE)
  txt_res <- gsub("Columnas preservadas declarativamente vía 'keep_columns'", "Columns preserved declaratively via 'keep_columns'", txt_res, fixed = TRUE)
  txt_res <- gsub("Intervalo ", "Interval ", txt_res, fixed = TRUE)
  txt_res <- gsub(" cm ponderado por espesor", " cm thickness-weighted", txt_res, fixed = TRUE)
  txt_res <- gsub("PTF confirmada por usuario: ", "PTF confirmed by user: ", txt_res, fixed = TRUE)
  txt_res <- gsub("COG estándar verificado: ", "Standard COG verified: ", txt_res, fixed = TRUE)
  txt_res <- gsub("Puntos fuera de máscara raster excluidos", "Points outside raster mask excluded", txt_res, fixed = TRUE)
  txt_res <- gsub("Fracciones de arena consolidadas en Sand para análisis textural", "Sand fractions consolidated into Sand for textural analysis", txt_res, fixed = TRUE)
  txt_res <- gsub("Coordenadas originales: ", "Original coordinates: ", txt_res, fixed = TRUE)
  txt_res <- gsub("Sin transformación requerida", "No transformation required", txt_res, fixed = TRUE)
  txt_res <- gsub("Perfiles marcados en Paso 1.2 no ingresan a la extracción", "Profiles flagged in Step 1.2 excluded from extraction", txt_res, fixed = TRUE)
  txt_res <- gsub("Variable: ", "Variable: ", txt_res, fixed = TRUE)
  txt_res <- gsub(", soporte mínimo: ", ", minimum support: ", txt_res, fixed = TRUE)
  txt_res <- gsub(" de ", " of ", txt_res, fixed = TRUE)
  txt_res <- gsub(" covariables seleccionadas", " covariates selected", txt_res, fixed = TRUE)
  txt_res <- gsub("Ajuste local simple", "Simple local fit", txt_res, fixed = TRUE)
  txt_res <- gsub("fórmula: ", "formula: ", txt_res, fixed = TRUE)
  txt_res <- gsub("Horizontes estimados: ", "Estimated horizons: ", txt_res, fixed = TRUE)
  txt_res <- gsub("PTF imputada tras confirmación del usuario: ", "PTF imputed following user confirmation: ", txt_res, fixed = TRUE)
  txt_res <- gsub("Exponencial", "Exponential", txt_res, fixed = TRUE)
  txt_res <- gsub("Lineal", "Linear", txt_res, fixed = TRUE)
  txt_res <- gsub("Logarítmico", "Logarithmic", txt_res, fixed = TRUE)
  txt_res <- gsub("Recíproco", "Reciprocal", txt_res, fixed = TRUE)
  txt_res <- gsub("Archivos: ", "Files: ", txt_res, fixed = TRUE)
  txt_res <- gsub("Compresión: ", "Compression: ", txt_res, fixed = TRUE)
  txt_res <- gsub("Ajuste local y contraste de 6 PTFs disponibles sobre n=", "Local fit and contrast of 6 available PTFs on n=", txt_res, fixed = TRUE)
  txt_res <- gsub("Contraste de 6 PTFs publicadas sobre n=", "Contrast of 6 published PTFs on n=", txt_res, fixed = TRUE)
  
  return(txt_res)
}

# 4. Config validation error formatter -----------------------------------------
format_config_enum_error <- function(param_name, val, allowed_vals, lang = "es") {
  if (identical(lang, "en")) {
    sprintf("[CONFIG ERROR] Invalid value '%s' for '%s'.\n  Valid values according to 'docs/CONFIG_SCHEMA.md': [%s].",
            val, param_name, paste(allowed_vals, collapse = ", "))
  } else {
    sprintf("[ERROR CONFIG] Valor no válido '%s' para '%s'.\n  Valores válidos según 'docs/CONFIG_SCHEMA.md': [%s].",
            val, param_name, paste(allowed_vals, collapse = ", "))
  }
}
