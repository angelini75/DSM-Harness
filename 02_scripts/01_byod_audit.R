# ==============================================================================
# DSM-Harness | Stage 1: BYOD Soil Profile Audit & Harmonization
# ==============================================================================
# Este script realiza la auditoría de calidad, validación espacial (WGS84),
# chequeo de profundidades y horizontes (upper, lower), detección de atípicos
# y estandarización a normas ISO 28258 / OpenNSIS para perfiles nacionales.
#
# INSTRUCCIONES:
# 1. Abre este script dentro de tu proyecto RStudio (DSM-Harness.Rproj).
# 2. Configura abajo la ruta a tu archivo (Excel o CSV) y tu propiedad objetivo.
# 3. Ejecuta el script línea por línea o presionando Source.
# ==============================================================================

# 0. Limpieza y paquetes -------------------------------------------------------
rm(list = ls())
gc()

suppressPackageStartupMessages({
  library(tidyverse)
  library(readxl)
  library(sf)
  library(mapview)
})

cat("\n========================================================\n")
cat("  DSM-Harness: Etapa 1 - Auditoria de Perfiles de Suelo\n")
cat("========================================================\n\n")

# 1. Configuración de entrada (Ajusta estos parámetros) -------------------------

# Ruta a tu archivo de datos (puede ser .xlsx, .xls o .csv)
input_file <- "01_data/profiles/soil_profiles.xlsx" 

# Si es un archivo Excel (.xlsx), especifica la hoja (o deja NULL para leer la primera)
sheet_name <- NULL 

# Propiedad de suelo principal a modelar/evaluar (ej: "SOC", "pH_H2O", "Clay")
target_property <- "SOC"

# Código ISO del país o proyecto (para trazabilidad OpenNSIS)
project_code <- "SOILFER"


# 2. Carga inteligente de datos ------------------------------------------------

if (!file.exists(input_file)) {
  # Buscar si hay archivos alternativos en 01_data/profiles/
  profiles_dir <- "01_data/profiles"
  avail_files <- list.files(profiles_dir, pattern = "\\.(xlsx|xls|csv)$", full.names = TRUE)
  
  if (length(avail_files) > 0) {
    cat(sprintf("[AVISO] No se encontro '%s'.\n", input_file))
    cat(sprintf("[AUTO] Utilizando archivo detectado: '%s'\n", avail_files[1]))
    input_file <- avail_files[1]
  } else {
    stop(sprintf("\n[ERROR] No se encontro el archivo '%s' ni ningun archivo en '%s'.\nPor favor coloca tu archivo .xlsx o .csv en '01_data/profiles/'.", 
                 input_file, profiles_dir))
  }
}

file_ext <- tolower(tools::file_ext(input_file))
cat(sprintf("[*] Cargando dataset: %s (formato: %s)...\n", input_file, file_ext))

if (file_ext %in% c("xlsx", "xls")) {
  if (is.null(sheet_name)) {
    dat_raw <- readxl::read_excel(input_file)
  } else {
    dat_raw <- readxl::read_excel(input_file, sheet = sheet_name)
  }
} else if (file_ext == "csv") {
  dat_raw <- readr::read_csv(input_file, show_col_types = FALSE)
} else {
  stop("[ERROR] Formato no soportado. Debe ser .xlsx, .xls o .csv.")
}

cat(sprintf("[OK] Dataset cargado: %d filas y %d columnas.\n\n", nrow(dat_raw), ncol(dat_raw)))


# 3. Diccionario y estandarización a normas ISO 28258 / OpenNSIS ----------------

alias_dict <- list(
  longitude    = c("longitude", "lon", "long", "longitud", "x", "coord_x", "dec_long", "wgs84_x", "long_wgs84", "x_coord"),
  latitude     = c("latitude", "lat", "latitud", "y", "coord_y", "dec_lat", "wgs84_y", "lat_wgs84", "y_coord"),
  profile_code = c("profile_code", "profile_id", "id_perfil", "perfil", "codigo", "sitio", "calicata", "pedon_id", "site_id", "id", "sample_id", "sondeo"),
  Horizon      = c("horizon", "horizonte", "hor", "hz", "capa", "estrato", "layer"),
  upper        = c("upper", "prof_sup", "desde", "limite_sup", "prof_inicial", "top_depth", "top", "from", "upper_depth", "depth_top"),
  lower        = c("lower", "prof_inf", "hasta", "limite_inf", "prof_final", "bottom_depth", "bottom", "to", "lower_depth", "depth_bottom"),
  SOC          = c("soc", "cos", "cot", "co", "c_org", "carbono_organico", "carbono", "oc", "org_c", "organic_carbon"),
  OM           = c("om", "mo", "materia_organica", "mat_org", "som", "materia_org"),
  pH_H2O       = c("ph_h2o", "ph", "ph_agua", "ph_suelo", "ph_water"),
  Clay         = c("clay", "arcilla", "arcillas", "clay_pct", "clay_perc", "arcilla_porc", "arcilla_%"),
  Sand         = c("sand", "arena", "arenas", "sand_pct", "sand_perc", "arena_porc", "arena_%"),
  Silt         = c("silt", "limo", "limos", "silt_pct", "silt_perc", "limo_porc", "limo_%"),
  BD           = c("bd", "da", "densidad_aparente", "dens_apar", "bulk_density", "dry_bulk_density"),
  CEC          = c("cec", "cic", "capacidad_intercambio_cationico", "ecec", "cat_exch_cap")
)

# Funcion de mapeo automatico por sinonimos
col_names_orig <- names(dat_raw)
col_names_clean <- tolower(trimws(col_names_orig))

detected_mapping <- list()
for (std_name in names(alias_dict)) {
  matched_idx <- which(col_names_clean %in% tolower(alias_dict[[std_name]]))
  if (length(matched_idx) > 0) {
    detected_mapping[[col_names_orig[matched_idx[1]]]] <- std_name
  }
}

cat("--- Mapeo de Columnas Detectado (ISO 28258 / OpenNSIS) ---\n")
dat_renamed <- dat_raw
for (orig_col in names(detected_mapping)) {
  target_col <- detected_mapping[[orig_col]]
  cat(sprintf("  [*] '%s' -> '%s'\n", orig_col, target_col))
  names(dat_renamed)[names(dat_renamed) == orig_col] <- target_col
}
cat("----------------------------------------------------------\n\n")

# Verificar columnas obligatorias minimas
required_cols <- c("longitude", "latitude", "upper", "lower")
missing_req <- setdiff(required_cols, names(dat_renamed))
if (length(missing_req) > 0) {
  stop(sprintf("[ERROR CRITICO] Faltan columnas obligatorias que no pudieron inferirse: %s\nPor favor renombra manualmente las columnas en el archivo o script.", 
               paste(missing_req, collapse = ", ")))
}

# Si falta profile_code, generamos uno correlativo por coordenadas identicas
if (!"profile_code" %in% names(dat_renamed)) {
  cat("[AVISO] No se detecto columna de ID de perfil ('profile_code'). Generando IDs automaticos por coordenada.\n")
  dat_renamed <- dat_renamed %>%
    group_by(longitude, latitude) %>%
    mutate(profile_code = paste0("PROF_", cur_group_id())) %>%
    ungroup()
}

# Conversion de Materia Organica a Carbono Organico (Van Bemmelen) si SOC no existe
if (!"SOC" %in% names(dat_renamed) && "OM" %in% names(dat_renamed)) {
  cat("[PEDOLOGIA] 'SOC' no estaba presente pero se detecto 'OM' (Materia Organica).\n")
  cat("           Calculando SOC = OM / 1.724 (Factor de Van Bemmelen)...\n")
  dat_renamed <- dat_renamed %>%
    mutate(SOC = as.numeric(OM) / 1.724)
}


# 4. Validacion Espacial (WGS84) -----------------------------------------------

cat("[*] Ejecutando validacion espacial (WGS84)...\n")

dat_spatial_check <- dat_renamed %>%
  mutate(
    longitude = as.numeric(longitude),
    latitude  = as.numeric(latitude)
  )

n_total <- nrow(dat_spatial_check)
n_na_coords <- sum(is.na(dat_spatial_check$longitude) | is.na(dat_spatial_check$latitude))

if (n_na_coords > 0) {
  cat(sprintf("  [!] Descartando %d registros con coordenadas NA.\n", n_na_coords))
}

# Chequeo de rangos WGS84
dat_clean_geo <- dat_spatial_check %>%
  filter(!is.na(longitude) & !is.na(latitude))

# Deteccion de coordenadas invertidas (Lat en X o Lon en Y)
is_swapped <- any(abs(dat_clean_geo$latitude) > 90 & abs(dat_clean_geo$longitude) <= 90)
if (is_swapped) {
  cat("  [ALERTA] Se detectaron latitudes > 90. Es muy probable que Longitud y Latitud esten invertidas.\n")
  cat("           Invirtiendo coordenadas automaticamente...\n")
  dat_clean_geo <- dat_clean_geo %>%
    rename(temp_lon = longitude) %>%
    mutate(longitude = latitude, latitude = temp_lon) %>%
    select(-temp_lon)
}

# Filtrar puntos validos en WGS84 y excluir origen nulo (0,0)
dat_clean_geo <- dat_clean_geo %>%
  filter(longitude >= -180 & longitude <= 180) %>%
  filter(latitude >= -90 & latitude <= 90) %>%
  filter(!(longitude == 0 & latitude == 0))

n_valid_geo <- nrow(dat_clean_geo)
cat(sprintf("  [OK] Registros con coordenadas validas: %d / %d (%.1f%%)\n", 
            n_valid_geo, n_total, (n_valid_geo / n_total) * 100))


# 5. Validacion de Profundidades y Horizontes -----------------------------------

cat("\n[*] Ejecutando validacion de profundidades de horizontes...\n")

dat_depth_check <- dat_clean_geo %>%
  mutate(
    upper = as.numeric(upper),
    lower = as.numeric(lower)
  ) %>%
  filter(!is.na(upper) & !is.na(lower)) %>%
  filter(upper >= 0 & lower > upper) %>%
  mutate(thickness = lower - upper)

# Deteccion de solapamientos dentro del mismo perfil
depth_issues <- dat_depth_check %>%
  group_by(profile_code) %>%
  arrange(upper, .by_group = TRUE) %>%
  mutate(prev_lower = lag(lower)) %>%
  filter(!is.na(prev_lower) & upper < prev_lower) %>%
  ungroup()

if (nrow(depth_issues) > 0) {
  cat(sprintf("  [AVISO] Se detectaron %d horizontes con solapamiento de profundidad en sus perfiles.\n", nrow(depth_issues)))
} else {
  cat("  [OK] No se detectaron solapamientos criticos de horizontes.\n")
}


# 6. Chequeos de Rangos Edafológicos y Función de Pedotransferencia (PTF) --------

cat("\n[*] Validando limites edafologicos y consistencia física...\n")

dat_pedoclean <- dat_depth_check

# Chequeo de pH
if ("pH_H2O" %in% names(dat_pedoclean)) {
  dat_pedoclean <- dat_pedoclean %>%
    mutate(pH_H2O = as.numeric(pH_H2O)) %>%
    mutate(pH_flag = ifelse(!is.na(pH_H2O) & (pH_H2O < 3.0 | pH_H2O > 10.5), "pH_atipico", "OK"))
  n_ph_out <- sum(dat_pedoclean$pH_flag == "pH_atipico", na.rm = TRUE)
  if (n_ph_out > 0) cat(sprintf("  [!] %d horizontes con pH fuera del rango habitual (3.0 - 10.5).\n", n_ph_out))
}

# Chequeo de SOC
if ("SOC" %in% names(dat_pedoclean)) {
  dat_pedoclean <- dat_pedoclean %>%
    mutate(SOC = as.numeric(SOC)) %>%
    mutate(SOC_flag = ifelse(!is.na(SOC) & (SOC < 0 | SOC > 50), "SOC_atipico", "OK"))
  n_soc_out <- sum(dat_pedoclean$SOC_flag == "SOC_atipico", na.rm = TRUE)
  if (n_soc_out > 0) cat(sprintf("  [!] %d horizontes con SOC fuera de rango mineral/organico (0 - 50%%).\n", n_soc_out))
}

# Chequeo de Textura (Suma de Arena + Limo + Arcilla)
if (all(c("Sand", "Silt", "Clay") %in% names(dat_pedoclean))) {
  dat_pedoclean <- dat_pedoclean %>%
    mutate(
      Sand = as.numeric(Sand),
      Silt = as.numeric(Silt),
      Clay = as.numeric(Clay),
      tex_sum = Sand + Silt + Clay,
      tex_flag = ifelse(!is.na(tex_sum) & (tex_sum < 90 | tex_sum > 110), "Suma_inconsistente", "OK")
    )
  n_tex_out <- sum(dat_pedoclean$tex_flag == "Suma_inconsistente", na.rm = TRUE)
  if (n_tex_out > 0) cat(sprintf("  [!] %d horizontes con suma de fracciones texturales fuera del rango 90-110%%.\n", n_tex_out))
}

# Estimacion de Densidad Aparente (Bulk Density) via Pedotransferencia (Saxton et al.)
if (!"BD" %in% names(dat_pedoclean) || all(is.na(dat_pedoclean$BD))) {
  if (all(c("Sand", "Clay", "SOC") %in% names(dat_pedoclean))) {
    cat("  [PTF] Estimando Densidad Aparente (BD) faltante mediante funcion de Saxton et al.:\n")
    cat("        BD = 1.35 + 0.0045*Sand + 0.0035*Clay - 0.06*1.72*SOC\n")
    dat_pedoclean <- dat_pedoclean %>%
      mutate(BD = 1.35 + 0.0045 * Sand + 0.0035 * Clay - 0.06 * 1.72 * SOC)
  }
}


# 7. Exportación del Dataset Limpio y Armonizado --------------------------------

out_dir <- "01_data/profiles"
if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)

clean_csv_path <- file.path(out_dir, "cleaned_profiles.csv")
clean_rds_path <- file.path(out_dir, "cleaned_profiles.rds")

readr::write_csv(dat_pedoclean, clean_csv_path)
saveRDS(dat_pedoclean, clean_rds_path)

cat(sprintf("\n[OK] Datos depurados y armonizados exportados a:\n  -> %s\n  -> %s\n\n", 
            clean_csv_path, clean_rds_path))


# 8. DIAGNÓSTICO VISUAL 1: Mapa Interactivo de Distribución Espacial -----------

cat("[*] Generando mapa interactivo de validacion espacial...\n")

dat_sf <- sf::st_as_sf(dat_pedoclean, coords = c("longitude", "latitude"), crs = 4326)

if (target_property %in% names(dat_sf) && is.numeric(dat_sf[[target_property]])) {
  map_view <- mapview(dat_sf, zcol = target_property, 
                      layer.name = paste("Perfiles:", target_property),
                      cex = 3.5, alpha.regions = 0.8)
} else {
  map_view <- mapview(dat_sf, layer.name = "Perfiles de Suelo", cex = 3)
}

print(map_view)


# 9. DIAGNÓSTICO VISUAL 2: Gráfico Bivariado de Plausibilidad Edafológica -------

if ("BD" %in% names(dat_pedoclean) && "SOC" %in% names(dat_pedoclean)) {
  cat("[*] Generando grafico de dispersion: SOC vs Densidad Aparente...\n")
  
  p_bivar <- ggplot(dat_pedoclean %>% filter(!is.na(SOC) & !is.na(BD)), 
                    aes(x = SOC, y = BD)) +
    geom_point(alpha = 0.5, color = "forestgreen", size = 2) +
    geom_smooth(method = "lm", se = TRUE, color = "darkblue", fill = "lightblue") +
    labs(
      title = "Chequeo Edafologico Bivariado: SOC vs Densidad Aparente",
      subtitle = "Esperado: correlacion negativa (mayor materia organica reduce la densidad)",
      x = "Carbono Organico del Suelo (SOC, %)",
      y = "Densidad Aparente (BD, g/cm³)"
    ) +
    theme_minimal(base_size = 12) +
    theme(plot.title = element_text(face = "bold"))
  
  print(p_bivar)
}

cat("\n========================================================\n")
cat("  Auditoria completada con exito.\n")
cat("========================================================\n")
cat("PREGUNTAS DE REFLEXION PARA EL ALUMNO:\n")
cat("1. En el mapa interactivo (mapview), ¿todos los puntos caen en tierra firme\n")
cat("   dentro de los limites de tu pais, o hay puntos en el oceano/paises vecinos?\n")
cat("2. En el grafico bivariado (SOC vs BD), ¿se observa la relacion inversa esperada\n")
cat("   o existen horizontes con alto carbono y alta densidad que sugieran un error analitico?\n")
cat("========================================================\n\n")
