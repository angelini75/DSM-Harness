# ==============================================================================
# DSM-Harness | Paso 1.1: Identificación y Confirmación de Variables Relevantes
# ==============================================================================
# Objetivo: Leer el archivo nacional (.xlsx o .csv), seleccionar ÚNICAMENTE las
# variables necesarias para DSM y mostrar una tabla clara para confirmar el mapeo.
# ==============================================================================

rm(list = ls())

suppressPackageStartupMessages({
  library(tidyverse)
  library(readxl)
})

# 1. Configuración del archivo de entrada ---------------------------------------
# Ajusta el nombre de tu archivo si está en 01_data/profiles/
data_path <- "01_data/profiles/Profiles_data.xlsx"  # Puede ser .xlsx o .csv

# Si el archivo no existe en esa ruta exacta, busca el primer archivo disponible
if (!file.exists(data_path)) {
  avail <- list.files("01_data/profiles", pattern = "\\.(xlsx|xls|csv)$", full.names = TRUE)
  if (length(avail) > 0) {
    data_path <- avail[1]
  } else {
    stop("No se encontro ningun archivo .xlsx o .csv en '01_data/profiles/'.")
  }
}

# 2. Carga del archivo ---------------------------------------------------------
ext <- tolower(tools::file_ext(data_path))
cat(sprintf("\n[*] Cargando: %s ...\n", data_path))

dat_raw <- if (ext %in% c("xlsx", "xls")) {
  readxl::read_excel(data_path)
} else {
  readr::read_csv(data_path, show_col_types = FALSE)
}

# 3. Diccionario de variables RELEVANTES para DSM (ISO 28258) -------------------
# Solo nos interesan: ID, horizontes, profundidades, coordenadas y propiedades analíticas.
# Las demás columnas (taxonomía, morfología, fechas, etc.) no son relevantes y se descartan.
dsm_dict <- list(
  profile_code = c("profile_code", "profile_id", "id_perfil", "perfil", "codigo", "sitio", "calicata", "pedon_id", "site_id", "id", "sample_id"),
  Horizon      = c("horizon", "horizonte", "hor", "hz", "capa", "estrato"),
  upper        = c("upper", "prof_sup", "desde", "limite_sup", "prof_inicial", "top_depth", "top", "from", "upper_depth"),
  lower        = c("lower", "prof_inf", "hasta", "limite_inf", "prof_final", "bottom_depth", "bottom", "to", "lower_depth"),
  longitude    = c("longitude", "lon", "long", "longitud", "x", "coord_x", "dec_long", "wgs84_x", "long_wgs84"),
  latitude     = c("latitude", "lat", "latitud", "y", "coord_y", "dec_lat", "wgs84_y", "lat_wgs84"),
  SOC          = c("soc", "cos", "cot", "co", "c_org", "carbono_organico", "carbono", "oc", "org_c"),
  OM           = c("om", "mo", "materia_organica", "mat_org", "som"),
  pH_H2O       = c("ph", "ph_h2o", "ph_agua", "ph_suelo", "ph_water"),
  Clay         = c("clay", "arcilla", "arcillas", "clay_pct", "arcilla_%"),
  Sand         = c("sand", "arena", "arenas", "sand_pct", "arena_%"),
  Silt         = c("silt", "limo", "limos", "silt_pct", "limo_%"),
  BD           = c("bd", "da", "densidad_aparente", "dens_apar", "bulk_density"),
  CEC          = c("cec", "cic", "capacidad_intercambio_cationico", "ecec")
)

cols_raw <- names(dat_raw)
cols_clean <- tolower(trimws(cols_raw))

mapping <- data.frame(Original = character(), Estandar_DSM = character(), stringsAsFactors = FALSE)
rename_vector <- c()

for (target_var in names(dsm_dict)) {
  match_idx <- which(cols_clean %in% tolower(dsm_dict[[target_var]]))
  if (length(match_idx) > 0) {
    orig_name <- cols_raw[match_idx[1]]
    mapping <- rbind(mapping, data.frame(Original = orig_name, Estandar_DSM = target_var))
    rename_vector[target_var] <- orig_name
  }
}

# 4. Resumen y selección estricta ----------------------------------------------
cat("\n==============================================================\n")
cat("  TABLA DE MAPEO DE VARIABLES DETECTADAS (Paso 1.1)\n")
cat("==============================================================\n")
for (i in seq_len(nrow(mapping))) {
  cat(sprintf("  %-25s ---> %s\n", mapping$Original[i], mapping$Estandar_DSM[i]))
}
cat("==============================================================\n")

# Descartar columnas no relevantes
cols_descartadas <- setdiff(cols_raw, mapping$Original)
cat(sprintf("[*] Se conservaron %d variables clave para DSM.\n", nrow(mapping)))
cat(sprintf("[*] Se descartaron %d columnas accesorias no relevantes (morfologia, fechas, clasificacion, etc.).\n\n", length(cols_descartadas)))

# Subconjunto estandarizado
dat_step1 <- dat_raw %>%
  select(all_of(mapping$Original)) %>%
  rename(!!!rename_vector)

cat("INSTRUCCION PARA EL ALUMNO:\n")
cat("Revisa la tabla de arriba. ¿Las variables encontradas corresponden a lo correcto?\n")
cat("--> Responde en el chat: 'Si, es correcto' o indica qué columna debe modificarse.\n\n")
