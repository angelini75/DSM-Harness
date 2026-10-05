# ==============================================================================
# DSM-Harness | Paso 1.1: Identificación, Relaciones y Selección de Variables
# ==============================================================================
# OBJETIVO:
# Cargar el dataset de perfiles (Excel multi-hoja o CSV), realizar la unión
# relacional si corresponde (Sitios + Horizontes), auditar réplicas y claves repetidas,
# mapear a variables estándar DSM (ISO 28258) según configuración confirmada o diccionario,
# registrar decisiones en decisions_log.csv y generar reporte de trazabilidad.
#
# SALIDAS GENERADAS:
# 1. Dataset intermedio:  '01_data/profiles/step1_1_variables.csv'
# 2. Reporte descriptivo: '01_data/profiles/step1_1_variables_report.txt'
# 3. Log de decisiones:   '01_data/profiles/decisions_log.csv'
#
# INSTRUCCIONES PARA EL ALUMNO:
# 1. Ejecuta este script en RStudio (Source o Ctrl+Shift+S).
# 2. Revisa la tabla de mapeo y auditoría de claves impresa en consola.
# 3. Dialoga con la IA en el chat para confirmar el mapeo y decidir sobre réplicas.
# ==============================================================================

rm(list = ls())

suppressPackageStartupMessages({
  library(tidyverse)
  library(readxl)
})

# 1. Configuración de rutas ----------------------------------------------------
config_file   <- "01_data/profiles/user_config.json"
mapping_csv   <- "01_data/profiles/mapping_confirmed.csv"
output_csv    <- "01_data/profiles/step1_1_variables.csv"
output_report <- "01_data/profiles/step1_1_variables_report.txt"
decisions_log <- "01_data/profiles/decisions_log.csv"

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
}

# Cargar configuración de usuario si existe (JSON o CSV)
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

# Determinar archivo de entrada
if (!is.null(user_cfg$input_file) && file.exists(user_cfg$input_file)) {
  input_file <- user_cfg$input_file
} else if (exists("input_file") && !is.null(input_file) && file.exists(input_file)) {
  # Respeta variable de entorno R
} else {
  avail <- list.files("01_data/profiles", pattern = "\\.(xlsx|xls|csv|txt|tsv)$", full.names = TRUE, ignore.case = TRUE)
  avail <- avail[!grepl("(_report\\.txt|step1_.*\\.csv|cleaned_profiles\\.csv|decisions_log|mapping_confirmed)", avail)]
  if (length(avail) >= 1) {
    input_file <- avail[1]
  } else {
    stop("[ERROR FATAL]: No se encontró ningún archivo de datos en '01_data/profiles/'.")
  }
}

ext <- tolower(tools::file_ext(input_file))
cat(sprintf("\n[*] Cargando archivo de perfiles: %s (formato .%s) ...\n", input_file, ext))

# 2. Carga y Estructuración (Multi-hoja o tabla plana) -------------------------
join_info <- ""
n_sites_raw <- 0
n_horiz_raw <- 0
orphan_horizons <- 0
orphan_sites <- 0
dup_key_count <- 0
duplicate_handling_applied <- "Sin duplicados detectados"

if (ext %in% c("xlsx", "xls")) {
  sheets <- readxl::excel_sheets(input_file)
  cat(sprintf("[*] Hojas detectadas en Excel: [%s]\n", paste(sheets, collapse = ", ")))
  
  if (length(sheets) == 1) {
    dat_raw <- readxl::read_excel(input_file, sheet = 1, guess_max = 100000)
    join_info <- paste0("Hoja única: '", sheets[1], "'")
  } else {
    # Hojas configuradas por el usuario o detectadas heurísticamente
    s_sites <- if (!is.null(user_cfg$site_sheet)) user_cfg$site_sheet else sheets[grepl("site|sitio|perfil|loc|header|ubic", tolower(sheets))][1]
    s_horiz <- if (!is.null(user_cfg$horiz_sheet)) user_cfg$horiz_sheet else sheets[grepl("hor|capa|layer|anal|prop|quim|text", tolower(sheets))][1]
    
    if (!is.na(s_sites) && !is.na(s_horiz) && s_sites != s_horiz) {
      df_sites <- readxl::read_excel(input_file, sheet = s_sites, guess_max = 100000)
      df_horiz <- readxl::read_excel(input_file, sheet = s_horiz, guess_max = 100000)
      n_sites_raw <- nrow(df_sites)
      n_horiz_raw <- nrow(df_horiz)
      
      # Clave de unión configurada o detectada
      key_matches <- if (!is.null(user_cfg$join_key)) {
        user_cfg$join_key
      } else {
        common_keys <- intersect(tolower(names(df_sites)), tolower(names(df_horiz)))
        common_keys[grepl("id|code|perfil|sitio|profile", common_keys)]
      }
      
      if (length(key_matches) > 0) {
        target_key <- key_matches[1]
        join_key_site  <- names(df_sites)[which(tolower(names(df_sites)) == target_key)[1]]
        join_key_horiz <- names(df_horiz)[which(tolower(names(df_horiz)) == target_key)[1]]
        
        # Auditoría de claves repetidas en horizontes (potenciales réplicas analíticas)
        horiz_keys <- df_horiz[[join_key_horiz]]
        dup_mask <- duplicated(horiz_keys) | duplicated(horiz_keys, fromLast = TRUE)
        dup_key_count <- sum(duplicated(horiz_keys))
        
        dup_action <- if (!is.null(user_cfg$duplicate_action)) user_cfg$duplicate_action else "preserve_and_flag"
        
        if (dup_key_count > 0) {
          cat(sprintf("\n[ALERTA CLAVES DUPLICADAS]: Se detectaron %d registros con claves repetidas en la hoja '%s'.\n", dup_key_count, s_horiz))
          cat(sprintf("  -> Acción aplicada: %s\n", dup_action))
          
          if (dup_action == "average") {
            # Promediar numéricas para réplicas de laboratorio
            num_cols <- names(df_horiz)[sapply(df_horiz, is.numeric)]
            char_cols <- setdiff(names(df_horiz), c(num_cols, join_key_horiz))
            
            df_horiz <- df_horiz %>%
              group_by(across(all_of(join_key_horiz))) %>%
              summarise(
                across(all_of(num_cols), ~ mean(.x, na.rm = TRUE)),
                across(all_of(char_cols), ~ first(na.omit(.x))),
                .groups = "drop"
              )
            duplicate_handling_applied <- sprintf("Promedio numérico de réplicas (%d filas originales agrupadas)", n_horiz_raw)
            record_decision(1.1, "Claves duplicadas", "Promediar réplicas analíticas", affected_rows = dup_key_count, details = "Promedio numérico por clave de horizonte")
          } else if (dup_action == "keep_first") {
            df_horiz <- df_horiz %>% distinct(across(all_of(join_key_horiz)), .keep_all = TRUE)
            duplicate_handling_applied <- sprintf("Conservar primera ocurrencia (%d filas descartadas)", dup_key_count)
            record_decision(1.1, "Claves duplicadas", "Conservar primera ocurrencia", affected_rows = dup_key_count, details = "Filas duplicadas descartadas por distinct")
          } else {
            # Conservar todo y marcar bandera para no perder información
            df_horiz$audit_replica_flag <- dup_mask
            duplicate_handling_applied <- sprintf("Conservar todas las filas marcando columna 'audit_replica_flag' (%d filas afectadas)", sum(dup_mask))
            record_decision(1.1, "Claves duplicadas", "Conservar y marcar bandera", affected_rows = sum(dup_mask), details = "Columna audit_replica_flag agregada")
          }
        }
        
        # Unión relacional auditada (left_join para no descartar horizontes)
        dat_raw <- dplyr::left_join(
          df_horiz,
          df_sites,
          by = setNames(join_key_site, join_key_horiz)
        )
        
        site_keys_all <- unique(df_sites[[join_key_site]])
        horiz_keys_all <- unique(df_horiz[[join_key_horiz]])
        orphan_horizons <- length(setdiff(horiz_keys_all, site_keys_all))
        orphan_sites    <- length(setdiff(site_keys_all, horiz_keys_all))
        
        join_info <- sprintf("Unión relacional entre '%s' (%d filas) y '%s' (%d filas) usando clave '%s'", 
                             s_sites, n_sites_raw, s_horiz, n_horiz_raw, target_key)
        record_decision(1.1, "Unión de tablas", "left_join relacional", affected_rows = nrow(dat_raw), 
                        affected_profiles = length(unique(na.omit(df_sites[[join_key_site]]))),
                        details = sprintf("Perfiles sin horizontes: %d | Horizontes sin perfil: %d", orphan_sites, orphan_horizons))
      } else {
        dat_raw <- readxl::read_excel(input_file, sheet = 1, guess_max = 100000)
        join_info <- "Hoja 1 (sin clave relacional automática confirmada)"
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
  OM           = c("om", "mo", "materia_organica", "mat_org", "som", "soil_organic_matter", "humus"),
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

# Si hay mapeo explícito confirmado por el usuario en user_cfg$column_mapping o mapping_confirmed.csv
if (!is.null(user_cfg$column_mapping) && length(user_cfg$column_mapping) > 0) {
  for (target_var in names(user_cfg$column_mapping)) {
    orig_col <- user_cfg$column_mapping[[target_var]]
    if (orig_col %in% cols_raw) {
      mapping <- rbind(mapping, data.frame(Original = orig_col, Estandar_DSM = target_var))
      rename_vector[target_var] <- orig_col
    }
  }
} else if (file.exists(mapping_csv)) {
  m_csv <- read.csv(mapping_csv, stringsAsFactors = FALSE)
  if (all(c("Original", "Estandar_DSM") %in% names(m_csv))) {
    mapping <- m_csv %>% filter(Original %in% cols_raw)
    for (i in seq_len(nrow(mapping))) {
      rename_vector[mapping$Estandar_DSM[i]] <- mapping$Original[i]
    }
  }
} else {
  # Mapeo automático por diccionario
  for (target_var in names(dsm_dict)) {
    matches <- which(cols_clean %in% tolower(dsm_dict[[target_var]]))
    if (length(matches) > 0) {
      orig_col <- cols_raw[matches[1]]
      if (!(orig_col %in% mapping$Original)) {
        mapping <- rbind(mapping, data.frame(Original = orig_col, Estandar_DSM = target_var))
        rename_vector[target_var] <- orig_col
      }
    }
  }
}

# 4. Creación del dataset limpio de variables -----------------------------------
dat_step1 <- dat_raw %>%
  dplyr::select(all_of(mapping$Original)) %>%
  dplyr::rename(!!!rename_vector)

# Preservar columna de bandera de réplicas si existe
if ("audit_replica_flag" %in% names(dat_raw) && !("audit_replica_flag" %in% names(dat_step1))) {
  dat_step1$audit_replica_flag <- dat_raw$audit_replica_flag
}

# Tratamiento de SOC / Materia Orgánica (SOLO si el usuario lo confirmó explícitamente)
soc_conversion_note <- "No requerida (SOC medido directamente)"
if (!("SOC" %in% names(dat_step1)) && ("OM" %in% names(dat_step1))) {
  om_factor <- if (!is.null(user_cfg$om_to_soc_factor)) as.numeric(user_cfg$om_to_soc_factor) else NULL
  if (!is.null(om_factor) && om_factor > 0) {
    dat_step1 <- dat_step1 %>% mutate(SOC = round(as.numeric(OM) / om_factor, 2))
    soc_conversion_note <- sprintf("Calculado por usuario: SOC = OM / %.3f", om_factor)
    record_decision(1.1, "Derivación SOC", sprintf("SOC = OM / %.3f", om_factor), 
                    affected_rows = nrow(dat_step1), details = "Conversión de Materia Orgánica a Carbono Orgánico aprobada por usuario")
  } else {
    soc_conversion_note <- "OM presente pero SOC no derivado automáticamente (pendiente confirmación de factor por usuario)"
  }
}

# Descartar columnas no esenciales
cols_descartadas <- setdiff(cols_raw, mapping$Original)

# 5. Generar Reporte de Texto UTF-8 --------------------------------------------
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
writeLines("AUDITORÍA DE CLAVES Y RELACIONES:", report_con)
writeLines(sprintf("  Claves duplicadas detectadas en horizontes: %d", dup_key_count), report_con)
writeLines(sprintf("  Tratamiento de duplicados aplicado:         %s", duplicate_handling_applied), report_con)
if (n_sites_raw > 0) {
  writeLines(sprintf("  Perfiles en hoja sitios sin horizontes:     %d", orphan_sites), report_con)
  writeLines(sprintf("  Horizontes sin perfil correspondiente:      %d", orphan_horizons), report_con)
}
writeLines(sprintf("  Estado de Carbono Orgánico (SOC):           %s", soc_conversion_note), report_con)
writeLines("--------------------------------------------------------------------------------", report_con)
writeLines("TABLA DE CORRESPONDENCIA DE VARIABLES:", report_con)
for (i in seq_len(nrow(mapping))) {
  writeLines(sprintf("  %-35s ---> %s", mapping$Original[i], mapping$Estandar_DSM[i]), report_con)
}
writeLines("--------------------------------------------------------------------------------", report_con)
writeLines(sprintf("VARIABLES DESCARTADAS (%d en total):", length(cols_descartadas)), report_con)
if (length(cols_descartadas) > 0) {
  for (cd in cols_descartadas) {
    writeLines(sprintf("  - %s", cd), report_con)
  }
} else {
  writeLines("  (Ninguna variable fue descartada)", report_con)
}
writeLines("================================================================================", report_con)
close(report_con)

# 6. Guardar dataset intermedio -------------------------------------------------
readr::write_csv(dat_step1, output_csv)

# 7. Resumen en consola e instrucción ------------------------------------------
cat("\n==============================================================================\n")
cat("  TABLA DE MAPEO DE VARIABLES (Paso 1.1)\n")
cat("==============================================================================\n")
for (i in seq_len(nrow(mapping))) {
  cat(sprintf("  %-35s ---> %s\n", mapping$Original[i], mapping$Estandar_DSM[i]))
}
cat("------------------------------------------------------------------------------\n")
cat(sprintf("Claves duplicadas/réplicas: %d | Acción: %s\n", dup_key_count, duplicate_handling_applied))
cat(sprintf("Variables descartadas: %d (detalladas en el reporte)\n", length(cols_descartadas)))
cat(sprintf("[OK] Dataset intermedio guardado en: %s (%d filas)\n", output_csv, nrow(dat_step1)))
cat(sprintf("[OK] Reporte descriptivo guardado en: %s\n", output_report))
cat(sprintf("[OK] Registro de decisiones actualizado en: %s\n", decisions_log))
cat("==============================================================================\n\n")

cat("------------------------------------------------------------------------------\n")
cat("INSTRUCCIÓN PARA EL ALUMNO:\n")
cat("1. Revisa la tabla mostrada arriba y las alertas de duplicados o variables.\n")
cat("2. En el chat con la IA, confirma si el mapeo es correcto y cómo prefieres\n")
cat("   tratar las réplicas o conversiones antes de pasar al Paso 1.2.\n")
cat("------------------------------------------------------------------------------\n\n")
