# ==============================================================================
# DSM-Harness | Paso 1.1: Identificación, Relaciones y Selección de Variables
# ==============================================================================
# OBJETIVO:
# Cargar el dataset de perfiles (Excel multi-hoja o CSV), realizar la unión
# relacional si corresponde (Sitios + Horizontes), seleccionar ÚNICAMENTE las
# variables esenciales para DSM (estándar ISO 28258) y descartar metadatos accesorios.
#
# SALIDAS GENERADAS:
# 1. Dataset intermedio: '01_data/profiles/step1_1_variables.csv'
# 2. Reporte descriptivo: '01_data/profiles/step1_1_variables_report.txt'
#
# INSTRUCCIONES PARA EL ALUMNO:
# 1. Ejecuta este script en RStudio (Source o Ctrl+Shift+S).
# 2. Revisa la tabla de mapeo de variables impresa en la consola.
# 3. Confirma en el chat con la IA si la correspondencia es correcta.
# ==============================================================================

rm(list = ls())

suppressPackageStartupMessages({
  library(tidyverse)
  library(readxl)
})

# 1. Configuración de rutas ----------------------------------------------------
input_file    <- "01_data/profiles/Profiles_data.xlsx"
output_csv    <- "01_data/profiles/step1_1_variables.csv"
output_report <- "01_data/profiles/step1_1_variables_report.txt"

# Si no existe la ruta exacta, buscar primer archivo en 01_data/profiles/
if (!file.exists(input_file)) {
  avail <- list.files("01_data/profiles", pattern = "\\.(xlsx|xls|csv|txt)$", full.names = TRUE)
  avail <- avail[!grepl("data_inspection_report\\.txt$", avail)]
  avail <- avail[!grepl("step1_.*", avail)]
  avail <- avail[!grepl("cleaned_profiles\\.csv$", avail)]
  if (length(avail) > 0) {
    input_file <- avail[1]
  } else {
    stop("No se encontro ningun archivo de perfiles en '01_data/profiles/'.")
  }
}

ext <- tolower(tools::file_ext(input_file))
cat(sprintf("\n[*] Cargando archivo: %s (formato .%s) ...\n", input_file, ext))

# 2. Carga y Estructuración (Soporte multi-hoja o tabla plana) ------------------
if (ext %in% c("xlsx", "xls")) {
  sheets <- readxl::excel_sheets(input_file)
  cat(sprintf("[*] Hojas detectadas en Excel: [%s]\n", paste(sheets, collapse = ", ")))
  
  # Si tiene múltiples hojas relacionales (ej. Sitios y Horizontes)
  # la IA adaptará la lógica de lectura y unión aquí según el reporte estructural:
  if (length(sheets) == 1) {
    dat_raw <- readxl::read_excel(input_file, sheet = 1, guess_max = 100000)
    join_info <- "Hoja única (tabla plana)"
  } else {
    # Detección heurística de hojas principales
    s_sites <- sheets[grepl("site|sitio|perfil|loc|header", tolower(sheets))][1]
    s_horiz <- sheets[grepl("hor|capa|layer|anal|prop", tolower(sheets))][1]
    
    if (!is.na(s_sites) && !is.na(s_horiz)) {
      df_sites <- readxl::read_excel(input_file, sheet = s_sites, guess_max = 100000)
      df_horiz <- readxl::read_excel(input_file, sheet = s_horiz, guess_max = 100000)
      
      # Buscar clave común (ID)
      common_keys <- intersect(tolower(names(df_sites)), tolower(names(df_horiz)))
      key_matches <- common_keys[grepl("id|code|perfil|sitio|profile", common_keys)]
      
      if (length(key_matches) > 0) {
        join_key_site <- names(df_sites)[which(tolower(names(df_sites)) == key_matches[1])]
        join_key_horiz <- names(df_horiz)[which(tolower(names(df_horiz)) == key_matches[1])]
        
        dat_raw <- dplyr::left_join(
          df_horiz,
          df_sites,
          by = setNames(join_key_site, join_key_horiz)
        )
        join_info <- sprintf("Unión relacional entre '%s' y '%s' mediante clave '%s'", s_sites, s_horiz, key_matches[1])
      } else {
        # Si no hay clave obvia, cargar la primera hoja con más columnas
        dat_raw <- readxl::read_excel(input_file, sheet = 1, guess_max = 100000)
        join_info <- "Hoja 1 (sin clave relacional automática detectada)"
      }
    } else {
      dat_raw <- readxl::read_excel(input_file, sheet = 1, guess_max = 100000)
      join_info <- paste("Lectura de hoja principal:", sheets[1])
    }
  }
} else {
  # Archivo de texto delimitado
  dat_raw <- readr::read_csv(input_file, show_col_types = FALSE)
  join_info <- "Archivo delimitado plano (CSV)"
}

# 3. Diccionario Edafológico de Variables Clave para DSM (ISO 28258) ------------
# Se seleccionan ÚNICAMENTE variables necesarias para modelado espacial.
# Se descartan metadatos taxonómicos, morfológicos y notas accesorias de campo.
dsm_dict <- list(
  profile_code = c("profile_code", "profile_id", "id_perfil", "perfil", "codigo", "sitio", 
                   "calicata", "pedon_id", "site_id", "id", "sample_id", "profile_no", "prof_id"),
  Horizon      = c("horizon", "horizonte", "hor", "hz", "capa", "estrato", "layer", "subsample"),
  upper        = c("upper", "prof_sup", "desde", "limite_sup", "prof_inicial", "top_depth", 
                   "top", "from", "upper_depth", "depth_top", "prof_desde"),
  lower        = c("lower", "prof_inf", "hasta", "limite_inf", "prof_final", "bottom_depth", 
                   "bottom", "to", "lower_depth", "depth_bottom", "prof_hasta"),
  longitude    = c("longitude", "lon", "long", "longitud", "x", "coord_x", "dec_long", 
                   "wgs84_x", "long_wgs84", "point_x", "east", "easting"),
  latitude     = c("latitude", "lat", "latitud", "y", "coord_y", "dec_lat", 
                   "wgs84_y", "lat_wgs84", "point_y", "north", "northing"),
  SOC          = c("soc", "cos", "cot", "co", "c_org", "carbono_organico", "carbono", 
                   "oc", "org_c", "organic_carbon", "soil_organic_carbon"),
  OM           = c("om", "mo", "materia_organica", "mat_org", "som", "soil_organic_matter"),
  pH_H2O       = c("ph", "ph_h2o", "ph_agua", "ph_suelo", "ph_water"),
  Clay         = c("clay", "arcilla", "arcillas", "clay_pct", "arcilla_%", "arcilla_porc"),
  Sand         = c("sand", "arena", "arenas", "sand_pct", "arena_%", "arena_porc"),
  Silt         = c("silt", "limo", "limos", "silt_pct", "limo_%", "limo_porc"),
  BD           = c("bd", "da", "densidad_aparente", "dens_apar", "bulk_density", "bulk_dens"),
  CEC          = c("cec", "cic", "capacidad_intercambio_cationico", "ecec", "cice"),
  Total_N      = c("nitrogeno_total", "total_n", "n_total", "ntot", "nitrogeno", "n_pct"),
  P_ext        = c("fosforo", "fosforo_disponible", "p_olsen", "p_bray", "p_extractable", "p_ext")
)

cols_raw   <- names(dat_raw)
cols_clean <- tolower(trimws(gsub("[^[:alnum:]_]", "_", cols_raw)))

mapping <- data.frame(Original = character(), Estandar_DSM = character(), stringsAsFactors = FALSE)
rename_vector <- character()

for (target_var in names(dsm_dict)) {
  # Buscar coincidencias exactas o por prefijo
  matches <- which(cols_clean %in% tolower(dsm_dict[[target_var]]))
  if (length(matches) > 0) {
    orig_col <- cols_raw[matches[1]]
    if (!(orig_col %in% mapping$Original)) {
      mapping <- rbind(mapping, data.frame(Original = orig_col, Estandar_DSM = target_var))
      rename_vector[target_var] <- orig_col
    }
  }
}

# 4. Creación del dataset limpio de variables -----------------------------------
dat_step1 <- dat_raw %>%
  dplyr::select(all_of(mapping$Original)) %>%
  dplyr::rename(!!!rename_vector)

# Si hay OM pero no SOC, calcular SOC = OM / 1.724 (regla de van Bemmelen / FAO)
if (!("SOC" %in% names(dat_step1)) && ("OM" %in% names(dat_step1))) {
  dat_step1 <- dat_step1 %>%
    mutate(SOC = round(as.numeric(OM) / 1.724, 2))
  cat("[AVISO PEDOLÓGICO]: SOC no presente directamente; calculado a partir de Materia Orgánica (SOC = OM / 1.724).\n")
}

# Descartar columnas no esenciales
cols_descartadas <- setdiff(cols_raw, mapping$Original)

# 5. Generar Reporte de Texto (para que la IA lo lea de forma nativa) ----------
report_con <- file(output_report, open = "wt", encoding = "UTF-8")
writeLines("================================================================================", report_con)
writeLines("  DSM-HARNESS | REPORTE PASO 1.1: MAPEO Y SELECCIÓN DE VARIABLES", report_con)
writeLines("================================================================================", report_con)
writeLines(paste("Fecha:", format(Sys.time(), "%Y-%m-%d %H:%M:%S")), report_con)
writeLines(paste("Archivo de entrada:", input_file), report_con)
writeLines(paste("Estructura de carga:", join_info), report_con)
writeLines(paste("Dimensiones iniciales:", nrow(dat_raw), "filas x", ncol(dat_raw), "columnas"), report_con)
writeLines(paste("Dimensiones filtradas:", nrow(dat_step1), "filas x", ncol(dat_step1), "variables DSM"), report_con)
if ("profile_code" %in% names(dat_step1)) {
  writeLines(paste("Número de perfiles únicos:", length(unique(na.omit(dat_step1$profile_code)))), report_con)
}
writeLines("--------------------------------------------------------------------------------", report_con)
writeLines("TABLA DE CORRESPONDENCIA DE VARIABLES:", report_con)
for (i in seq_len(nrow(mapping))) {
  writeLines(sprintf("  %-35s ---> %s", mapping$Original[i], mapping$Estandar_DSM[i]), report_con)
}
writeLines("--------------------------------------------------------------------------------", report_con)
writeLines(paste("Variables descartadas (no esenciales para DSM):", length(cols_descartadas)), report_con)
writeLines("Muestra de variables descartadas:", report_con)
writeLines(paste(" ", head(cols_descartadas, 10), collapse = "\n"), report_con)
writeLines("================================================================================", report_con)
close(report_con)

# 6. Guardar dataset intermedio -------------------------------------------------
readr::write_csv(dat_step1, output_csv)

# 7. Resumen en consola e instrucción ------------------------------------------
cat("\n==============================================================================\n")
cat("  TABLA DE MAPEO DE VARIABLES CONFIRMADAS (Paso 1.1)\n")
cat("==============================================================================\n")
for (i in seq_len(nrow(mapping))) {
  cat(sprintf("  %-35s ---> %s\n", mapping$Original[i], mapping$Estandar_DSM[i]))
}
cat("==============================================================================\n")
cat(sprintf("[OK] Dataset intermedio guardado en: %s (%d filas)\n", output_csv, nrow(dat_step1)))
cat(sprintf("[OK] Reporte descriptivo guardado en: %s\n\n", output_report))

cat("------------------------------------------------------------------------------\n")
cat("INSTRUCCIÓN PARA EL ALUMNO:\n")
cat("1. Revisa la tabla de correspondencia mostrada arriba.\n")
cat("2. En el chat con la IA, confirma si las variables coinciden con tus datos:\n")
cat("   -> Ejemplo: 'Paso 1.1 listo, las variables coinciden' o indica si falta alguna.\n")
cat("3. La IA configurará '02_scripts/01_2_byod_audit.R' para la validación espacial.\n")
cat("------------------------------------------------------------------------------\n\n")
