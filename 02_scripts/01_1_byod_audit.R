# ==============================================================================
# DSM-Harness | Paso 1.1: Identificación, Relaciones y Selección de Variables
# ==============================================================================
# OBJETIVO:
# Cargar el dataset de perfiles (Excel multi-hoja o CSV), validar la configuración
# del usuario contra 'docs/CONFIG_SCHEMA.md', realizar la unión relacional si
# corresponde (sitios + 1 o N hojas de horizontes), auditar réplicas y claves
# repetidas, mapear a variables estándar DSM (ISO 28258), registrar decisiones
# en decisions_log.csv y generar reporte de trazabilidad verídico.
#
# SALIDAS GENERADAS:
# 1. Dataset intermedio:  'data/step1_1_variables.csv' (o 01_data/profiles/)
# 2. Reporte descriptivo: 'reports/step1_1_variables_report.txt'
# 3. Log de decisiones:   'decisions_log.csv'
#
# INSTRUCCIONES PARA EL ALUMNO:
# 1. Ejecuta este script en RStudio (Source o Ctrl+Shift+S).
# 2. Revisa la tabla de mapeo y auditoría de claves impresa en consola.
# 3. Dialoga con la IA en el chat para confirmar el mapeo y réplicas.
# ==============================================================================

TEMPLATE_VERSION <- "2.0.0"

rm(list = setdiff(ls(), c("input_file", "TEMPLATE_VERSION", "PROJECT_DIR", "CURRENT_PROJECT_DIR")))

suppressPackageStartupMessages({
  library(tidyverse)
  library(readxl)
})

# 1. Configuración de rutas y validación de esquema ----------------------------
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

mapping_csv   <- file.path(base_data_dir, "mapping_confirmed.csv")
output_csv    <- file.path(base_data_dir, "step1_1_variables.csv")
output_report <- file.path(base_rep_dir, "step1_1_variables_report.txt")

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

# Validación formal de user_config.json contra docs/CONFIG_SCHEMA.md
known_config_keys <- c(
  "_comment", "input_file", "skip_rows", "has_units_row", "site_sheet", "site_key",
  "horiz_sheet", "join_key", "horizon_sheets", "duplicate_action", "duplicate_key_strategy",
  "allow_missing_essentials", "sand_sum", "column_mapping",
  "om_to_soc_factor", "source_crs", "outlier_action", "spatial_outlier_action", "outlier_ids", "estimate_bd"
)

user_cfg <- list()
if (file.exists(config_file)) {
  tryCatch({
    if (requireNamespace("jsonlite", quietly = TRUE)) {
      user_cfg <- jsonlite::fromJSON(config_file, simplifyVector = FALSE)
      cat(sprintf("[*] Configuración cargada desde: '%s'\n", config_file))
      
      cfg_keys <- setdiff(names(user_cfg), known_config_keys)
      if (length(cfg_keys) > 0) {
        cat(sprintf("\n[AVISO CONFIG]: Se detectaron claves no reconocidas en '%s':\n  [%s]\n",
                    config_file, paste(cfg_keys, collapse = ", ")))
        cat("  -> Consulta 'docs/CONFIG_SCHEMA.md' para ver el esquema canónico admitido.\n\n")
      }
      
      applied_keys <- intersect(names(user_cfg), known_config_keys)
      cat(sprintf("[*] Parámetros aplicados: [%s]\n", paste(applied_keys, collapse = ", ")))
    }
  }, error = function(e) {
    cat(sprintf("[AVISO] No se pudo parsear '%s': %s\n", config_file, e$message))
  })
} else {
  cat(sprintf("[AVISO] No se encontró archivo de configuración en '%s'. Usando autodetección predeterminada.\n", config_file))
}

# Determinar archivo de entrada
if (!is.null(user_cfg$input_file) && file.exists(as.character(user_cfg$input_file))) {
  input_file <- as.character(user_cfg$input_file)
} else if (!is.null(user_cfg$input_file) && !is.null(proj_active) && file.exists(file.path(base_data_dir, basename(as.character(user_cfg$input_file))))) {
  input_file <- file.path(base_data_dir, basename(as.character(user_cfg$input_file)))
} else if (exists("input_file") && !is.null(input_file) && file.exists(input_file)) {
  # Respeta variable de entorno R
} else {
  avail <- list.files(base_data_dir, pattern = "\\.(xlsx|xls|csv|txt|tsv)$", full.names = TRUE, ignore.case = TRUE)
  avail <- avail[!grepl("(_report\\.txt|step1_.*\\.csv|cleaned_profiles\\.csv|decisions_log|mapping_confirmed|template)", avail)]
  if (length(avail) >= 1) {
    input_file <- avail[1]
  } else {
    stop(sprintf("[ERROR FATAL]: No se encontró ningún archivo de datos en '%s/'.", base_data_dir))
  }
}

ext <- tolower(tools::file_ext(input_file))
cat(sprintf("\n[*] Cargando archivo de perfiles: %s (formato .%s) ...\n", input_file, ext))

skip_n <- if (!is.null(user_cfg$skip_rows)) as.integer(user_cfg$skip_rows) else 0
has_units <- if (!is.null(user_cfg$has_units_row)) isTRUE(user_cfg$has_units_row) else FALSE

clean_units_row <- function(df) {
  if (has_units && nrow(df) > 1) {
    df <- df[-1, , drop = FALSE]
  }
  df
}

# 2. Carga y Estructuración Relacional (1 o N Hojas) ---------------------------
join_info <- "Lectura directa"
n_sites_raw <- 0
n_horiz_raw <- 0
orphan_horizons <- NA_integer_
orphan_sites <- NA_integer_
dup_key_count <- 0
dup_site_count <- 0
exact_dup_rows <- 0
duplicate_handling_applied <- "Sin réplicas ni duplicados en claves evaluadas"
evaluated_duplicates <- FALSE

if (ext %in% c("xlsx", "xls")) {
  sheets <- readxl::excel_sheets(input_file)
  cat(sprintf("[*] Hojas detectadas en Excel (%d): [%s]\n", length(sheets), paste(sheets, collapse = ", ")))
  
  # Caso 1: Hoja única
  if (length(sheets) == 1) {
    dat_raw <- readxl::read_excel(input_file, sheet = 1, skip = skip_n, guess_max = 100000)
    dat_raw <- clean_units_row(dat_raw)
    exact_dup_rows <- sum(duplicated(dat_raw))
    join_info <- paste0("Hoja única: '", sheets[1], "'")
    
  # Caso 2: Múltiples hojas con horizon_sheets (N hojas de horizontes)
  } else if (!is.null(user_cfg$horizon_sheets) && length(user_cfg$horizon_sheets) > 0) {
    s_sites <- if (!is.null(user_cfg$site_sheet)) user_cfg$site_sheet else sheets[1]
    site_k  <- if (!is.null(user_cfg$site_key)) user_cfg$site_key else NULL
    
    cat(sprintf("[*] Modo Multi-Hoja: Hoja de sitios: '%s' | Hojas de horizontes a unir: %d\n", 
                s_sites, length(user_cfg$horizon_sheets)))
    
    df_sites <- readxl::read_excel(input_file, sheet = s_sites, skip = skip_n, guess_max = 100000)
    df_sites <- clean_units_row(df_sites)
    n_sites_raw <- nrow(df_sites)
    
    if (is.null(site_k)) {
      cand_s <- names(df_sites)[grepl("^(id|code|codigo|perfil|sitio|profile|site)|(_id|_code|_key)$", tolower(names(df_sites)))]
      site_k <- if (length(cand_s) > 0) cand_s[1] else names(df_sites)[1]
    }
    
    # Pre-chequeo de claves repetidas en la hoja de sitios (Issue #26: prevención de many-to-many)
    dup_site_count <- sum(duplicated(na.omit(df_sites[[site_k]])))
    dup_strat <- if (!is.null(user_cfg$duplicate_key_strategy)) user_cfg$duplicate_key_strategy else "fail"
    
    if (dup_site_count > 0) {
      cat(sprintf("\n[ALERTA CLAVE REPETIDA EN HOJA DE SITIOS]: La clave '%s' tiene %d registros duplicados en '%s'.\n",
                  site_k, dup_site_count, s_sites))
      if (dup_strat == "fail") {
        cat("  [ERROR FATAL]: En una relación 1-a-N, la tabla de sitios debe tener claves únicas para evitar duplicación cartesiana (many-to-many).\n")
        cat("  ACCIONES DISPONIBLES:\n")
        cat("  1. En 'config.json', configura 'duplicate_key_strategy': 'average' (promediar numéricos) o 'keep_first'.\n")
        cat("  2. Revisa la hoja de sitios en Excel para consolidar las réplicas antes de unir.\n\n")
        stop(sprintf("Ejecución detenida: Clave de perfil no única '%s' en hoja de sitios '%s' (%d filas repetidas).", site_k, s_sites, dup_site_count))
      } else if (dup_strat %in% c("average", "aggregate")) {
        num_c <- names(df_sites)[sapply(df_sites, is.numeric)]
        char_c <- setdiff(names(df_sites), c(num_c, site_k))
        df_sites <- df_sites %>%
          group_by(across(all_of(site_k))) %>%
          summarise(across(all_of(num_c), ~ mean(.x, na.rm = TRUE)),
                    across(all_of(char_c), ~ first(na.omit(.x))), .groups = "drop")
        record_decision(1.1, "Claves duplicadas en tabla de sitios", "Promediar réplicas antes de unir",
                        source = "user_config", affected_rows = dup_site_count, details = sprintf("Hoja: %s", s_sites))
      } else if (dup_strat == "keep_first") {
        df_sites <- df_sites %>% distinct(across(all_of(site_k)), .keep_all = TRUE)
        record_decision(1.1, "Claves duplicadas en tabla de sitios", "Conservar primera ocurrencia",
                        source = "user_config", affected_rows = dup_site_count, details = sprintf("Hoja: %s", s_sites))
      }
    }
    
    # Cargar y unir secuencialmente las hojas de horizontes
    df_horiz_acc <- NULL
    
    for (idx in seq_along(user_cfg$horizon_sheets)) {
      h_info <- user_cfg$horizon_sheets[[idx]]
      h_name <- h_info$sheet
      h_jkey <- h_info$join_key
      
      cat(sprintf("  -> Leyendo hoja de horizontes [%d/%d]: '%s' (join_key: '%s') ...\n",
                  idx, length(user_cfg$horizon_sheets), h_name, h_jkey))
      
      df_h_cur <- readxl::read_excel(input_file, sheet = h_name, skip = skip_n, guess_max = 100000)
      df_h_cur <- clean_units_row(df_h_cur)
      
      if (is.null(df_horiz_acc)) {
        df_horiz_acc <- df_h_cur
      } else {
        common_jkey <- intersect(names(df_horiz_acc), names(df_h_cur))
        target_j <- if (h_jkey %in% common_jkey) h_jkey else common_jkey[1]
        
        if (is.na(target_j) || length(target_j) == 0) {
          stop(sprintf("[ERROR MULTI-HOJA]: No se encontró clave común para unir la hoja '%s' con las anteriores.", h_name))
        }
        
        # Pre-chequeo de claves repetidas en la hoja derecha (Issue #17: prevención de many-to-many)
        dup_right_count <- sum(duplicated(na.omit(df_h_cur[[target_j]])))
        dup_strat_sec <- if (!is.null(user_cfg$duplicate_key_strategy)) user_cfg$duplicate_key_strategy else "fail"
        
        if (dup_right_count > 0) {
          cat(sprintf("\n[ALERTA CLAVE REPETIDA EN HOJA SECUNDARIA]: La clave '%s' tiene %d registros duplicados en '%s'.\n",
                      target_j, dup_right_count, h_name))
          if (dup_strat_sec == "fail") {
            cat("  [ERROR FATAL]: La unión produciría un producto cartesiano (many-to-many) multiplicando filas artificialmente.\n")
            cat("  ACCIONES DISPONIBLES:\n")
            cat("  1. En 'config.json', configura 'duplicate_key_strategy': 'average' (promediar numéricos) o 'keep_first'.\n")
            cat("  2. Revisa la hoja en Excel para consolidar las réplicas antes de unir.\n\n")
            stop(sprintf("Ejecución detenida: Clave no única '%s' en hoja '%s' (%d filas repetidas).", target_j, h_name, dup_right_count))
          } else if (dup_strat_sec %in% c("average", "aggregate")) {
            num_c <- names(df_h_cur)[sapply(df_h_cur, is.numeric)]
            char_c <- setdiff(names(df_h_cur), c(num_c, target_j))
            df_h_cur <- df_h_cur %>%
              group_by(across(all_of(target_j))) %>%
              summarise(across(all_of(num_c), ~ mean(.x, na.rm = TRUE)),
                        across(all_of(char_c), ~ first(na.omit(.x))), .groups = "drop")
            record_decision(1.1, "Claves duplicadas en unión", "Promediar réplicas antes de unir",
                            source = "user_config", affected_rows = dup_right_count, details = sprintf("Hoja: %s", h_name))
          } else if (dup_strat_sec == "keep_first") {
            df_h_cur <- df_h_cur %>% distinct(across(all_of(target_j)), .keep_all = TRUE)
            record_decision(1.1, "Claves duplicadas en unión", "Conservar primera ocurrencia",
                            source = "user_config", affected_rows = dup_right_count, details = sprintf("Hoja: %s", h_name))
          }
        }
        
        nrow_before <- nrow(df_horiz_acc)
        df_horiz_acc <- dplyr::left_join(df_horiz_acc, df_h_cur, by = target_j)
        nrow_after  <- nrow(df_horiz_acc)
        
        if (nrow_after > nrow_before) {
          cat(sprintf("\n[ALERTA INFLACIÓN DE FILAS]: La unión con '%s' incrementó las filas de %d a %d (+%d filas).\n",
                      h_name, nrow_before, nrow_after, nrow_after - nrow_before))
        }
      }
    }
    
    n_horiz_raw <- nrow(df_horiz_acc)
    
    # Auditoría de réplicas en horizontes: evaluar sobre clave de horizonte si existe
    evaluated_duplicates <- TRUE
    h_site_matches <- intersect(names(df_horiz_acc), c(site_k, tolower(site_k), toupper(site_k)))
    join_k_site_in_horiz <- if (length(h_site_matches) > 0) h_site_matches[1] else names(df_horiz_acc)[1]
    
    cand_hkey <- names(df_horiz_acc)[grepl("^(id_horiz|horiz_id|horizon_id|id_capa|id_sample|sample_id|horid|hor_id|layer_id|layerid|id_horizonte|horizonte_id)$", tolower(names(df_horiz_acc)))]
    if (length(cand_hkey) > 0) {
      target_h_key <- cand_hkey[1]
      dup_keys_vec <- df_horiz_acc[[target_h_key]]
      dup_mask <- duplicated(dup_keys_vec) | duplicated(dup_keys_vec, fromLast = TRUE)
      dup_key_count <- sum(duplicated(dup_keys_vec))
    } else {
      dup_key_count <- 0
      dup_mask <- rep(FALSE, nrow(df_horiz_acc))
    }
    
    dup_action <- if (!is.null(user_cfg$duplicate_action)) user_cfg$duplicate_action else "preserve_and_flag"
    dup_source <- if (!is.null(user_cfg$duplicate_action)) "user_config" else "script_default"
    
    if (dup_key_count > 0) {
      cat(sprintf("\n[ALERTA CLAVES DUPLICADAS EN HORIZONTES]: Se detectaron %d registros repetidos en la clave '%s'.\n", dup_key_count, target_h_key))
      if (dup_action == "average") {
        num_c <- names(df_horiz_acc)[sapply(df_horiz_acc, is.numeric)]
        char_c <- setdiff(names(df_horiz_acc), c(num_c, target_h_key))
        df_horiz_acc <- df_horiz_acc %>%
          group_by(across(all_of(target_h_key))) %>%
          summarise(across(all_of(num_c), ~ mean(.x, na.rm = TRUE)),
                    across(all_of(char_c), ~ first(na.omit(.x))), .groups = "drop")
        duplicate_handling_applied <- sprintf("Promedio numérico de réplicas (%d agrupadas)", n_horiz_raw)
        record_decision(1.1, "Claves duplicadas en horizontes", "Promediar réplicas analíticas", source = dup_source, affected_rows = dup_key_count)
      } else if (dup_action == "keep_first") {
        df_horiz_acc <- df_horiz_acc %>% distinct(across(all_of(target_h_key)), .keep_all = TRUE)
        duplicate_handling_applied <- sprintf("Conservar primera ocurrencia (%d descartadas)", dup_key_count)
        record_decision(1.1, "Claves duplicadas en horizontes", "Conservar primera ocurrencia", source = dup_source, affected_rows = dup_key_count)
      } else {
        df_horiz_acc$audit_replica_flag <- dup_mask
        duplicate_handling_applied <- sprintf("Conservar marcando columna 'audit_replica_flag' (%d filas)", sum(dup_mask))
        record_decision(1.1, "Claves duplicadas en horizontes", "Conservar y marcar bandera", source = dup_source, affected_rows = sum(dup_mask))
      }
    }
    
    # Unión final sitios + horizontes acumulados
    dat_raw <- dplyr::left_join(df_horiz_acc, df_sites, by = setNames(site_k, join_k_site_in_horiz))
    orphan_horizons <- length(setdiff(unique(df_horiz_acc[[join_k_site_in_horiz]]), unique(df_sites[[site_k]])))
    orphan_sites    <- length(setdiff(unique(df_sites[[site_k]]), unique(df_horiz_acc[[join_k_site_in_horiz]])))
    
    exact_dup_rows <- sum(duplicated(dat_raw))
    if (exact_dup_rows > 0) {
      cat(sprintf("\n[ALERTA FILAS DUPLICADAS TRAS UNIÓN]: Se detectaron %d filas exactamente duplicadas en el dataset combinado.\n", exact_dup_rows))
      dup_act_choice <- if (!is.null(user_cfg$duplicate_action)) user_cfg$duplicate_action else user_cfg$duplicate_key_strategy
      if (!is.null(dup_act_choice) && dup_act_choice == "keep_first") {
        dat_raw <- dat_raw %>% distinct()
        record_decision(1.1, "Filas duplicadas post-unión", "Conservar primera ocurrencia (eliminar filas idénticas)",
                        source = "user_config", affected_rows = exact_dup_rows)
        cat(sprintf("  -> Deduplicación aplicada: %d filas idénticas descartadas.\n", exact_dup_rows))
      }
    }
    
    join_info <- sprintf("Unión Multi-Hoja: '%s' (%d perfiles) + %d hojas horizontes (%d filas)",
                         s_sites, n_sites_raw, length(user_cfg$horizon_sheets), nrow(dat_raw))
    record_decision(1.1, "Unión multi-hoja", "left_join relacional", source = "user_config",
                    affected_rows = nrow(dat_raw),
                    affected_profiles = length(unique(na.omit(df_sites[[site_k]]))),
                    details = sprintf("Orphan sites: %d | Orphan horizons: %d | Dups post-join: %d", orphan_sites, orphan_horizons, exact_dup_rows))

  # Caso 3: Dos hojas (Sitios + 1 de Horizontes heurístico o configurado)
  } else if (length(sheets) >= 2) {
    s_sites <- if (!is.null(user_cfg$site_sheet)) user_cfg$site_sheet else sheets[1]
    s_horiz <- if (!is.null(user_cfg$horiz_sheet)) user_cfg$horiz_sheet else sheets[2]
    
    cat(sprintf("[*] Modo 2 Hojas: Sitios = '%s' | Horizontes = '%s'\n", s_sites, s_horiz))
    df_sites <- readxl::read_excel(input_file, sheet = s_sites, skip = skip_n, guess_max = 100000)
    df_horiz <- readxl::read_excel(input_file, sheet = s_horiz, skip = skip_n, guess_max = 100000)
    df_sites <- clean_units_row(df_sites)
    df_horiz <- clean_units_row(df_horiz)
    
    n_sites_raw <- nrow(df_sites)
    n_horiz_raw <- nrow(df_horiz)
    
    key_matches <- if (!is.null(user_cfg$join_key)) {
      user_cfg$join_key
    } else {
      common_keys <- intersect(tolower(names(df_sites)), tolower(names(df_horiz)))
      common_keys[grepl("^(id|code|perfil|sitio|profile)|(_id|_code|_key)$", common_keys)]
    }
    
    if (length(key_matches) > 0) {
      target_key <- key_matches[1]
      join_key_site  <- names(df_sites)[which(tolower(names(df_sites)) == target_key)[1]]
      join_key_horiz <- names(df_horiz)[which(tolower(names(df_horiz)) == target_key)[1]]
      
      dup_site_count <- sum(duplicated(na.omit(df_sites[[join_key_site]])))
      dup_strat <- if (!is.null(user_cfg$duplicate_key_strategy)) user_cfg$duplicate_key_strategy else "fail"
      if (dup_site_count > 0) {
        cat(sprintf("\n[ALERTA CLAVE REPETIDA EN HOJA DE SITIOS]: La clave '%s' tiene %d registros duplicados en '%s'.\n",
                    join_key_site, dup_site_count, s_sites))
        if (dup_strat == "fail") {
          cat("  [ERROR FATAL]: En una relación 1-a-N, la tabla de sitios debe tener claves únicas para evitar duplicación cartesiana (many-to-many).\n")
          cat("  ACCIONES DISPONIBLES:\n")
          cat("  1. En 'config.json', configura 'duplicate_key_strategy': 'average' (promediar numéricos) o 'keep_first'.\n")
          cat("  2. Revisa la hoja de sitios en Excel para consolidar las réplicas antes de unir.\n\n")
          stop(sprintf("Ejecución detenida: Clave de perfil no única '%s' en hoja de sitios '%s' (%d filas repetidas).", join_key_site, s_sites, dup_site_count))
        } else if (dup_strat %in% c("average", "aggregate")) {
          num_c <- names(df_sites)[sapply(df_sites, is.numeric)]
          char_c <- setdiff(names(df_sites), c(num_c, join_key_site))
          df_sites <- df_sites %>%
            group_by(across(all_of(join_key_site))) %>%
            summarise(across(all_of(num_c), ~ mean(.x, na.rm = TRUE)),
                      across(all_of(char_c), ~ first(na.omit(.x))), .groups = "drop")
          record_decision(1.1, "Claves duplicadas en tabla de sitios", "Promediar réplicas antes de unir",
                          source = "user_config", affected_rows = dup_site_count, details = sprintf("Hoja: %s", s_sites))
        } else if (dup_strat == "keep_first") {
          df_sites <- df_sites %>% distinct(across(all_of(join_key_site)), .keep_all = TRUE)
          record_decision(1.1, "Claves duplicadas en tabla de sitios", "Conservar primera ocurrencia",
                          source = "user_config", affected_rows = dup_site_count, details = sprintf("Hoja: %s", s_sites))
        }
      }
      
      cand_hkey_c3 <- names(df_horiz)[grepl("^(id_horiz|horiz_id|horizon_id|id_capa|id_sample|sample_id|horid|hor_id|layer_id|layerid|id_horizonte|horizonte_id)$", tolower(names(df_horiz)))]
      if (length(cand_hkey_c3) > 0) {
        evaluated_duplicates <- TRUE
        target_h_key <- cand_hkey_c3[1]
        dup_keys_vec <- df_horiz[[target_h_key]]
        dup_key_count <- sum(duplicated(dup_keys_vec))
        dup_action <- if (!is.null(user_cfg$duplicate_action)) user_cfg$duplicate_action else "preserve_and_flag"
        dup_source <- if (!is.null(user_cfg$duplicate_action)) "user_config" else "script_default"
        if (dup_key_count > 0) {
          if (dup_action == "average") {
            num_c <- names(df_horiz)[sapply(df_horiz, is.numeric)]
            char_c <- setdiff(names(df_horiz), c(num_c, target_h_key))
            df_horiz <- df_horiz %>%
              group_by(across(all_of(target_h_key))) %>%
              summarise(across(all_of(num_c), ~ mean(.x, na.rm = TRUE)),
                        across(all_of(char_c), ~ first(na.omit(.x))), .groups = "drop")
            duplicate_handling_applied <- sprintf("Promedio numérico de réplicas (%d agrupadas)", n_horiz_raw)
            record_decision(1.1, "Claves duplicadas en horizontes", "Promediar réplicas analíticas", source = dup_source, affected_rows = dup_key_count)
          } else if (dup_action == "keep_first") {
            df_horiz <- df_horiz %>% distinct(across(all_of(target_h_key)), .keep_all = TRUE)
            duplicate_handling_applied <- sprintf("Conservar primera ocurrencia (%d descartadas)", dup_key_count)
            record_decision(1.1, "Claves duplicadas en horizontes", "Conservar primera ocurrencia", source = dup_source, affected_rows = dup_key_count)
          }
        }
      }
      
      dat_raw <- dplyr::left_join(df_horiz, df_sites, by = setNames(join_key_site, join_key_horiz))
      orphan_horizons <- length(setdiff(unique(df_horiz[[join_key_horiz]]), unique(df_sites[[join_key_site]])))
      orphan_sites    <- length(setdiff(unique(df_sites[[join_key_site]]), unique(df_horiz[[join_key_horiz]])))
      
      exact_dup_rows <- sum(duplicated(dat_raw))
      if (exact_dup_rows > 0) {
        cat(sprintf("\n[ALERTA FILAS DUPLICADAS TRAS UNIÓN]: Se detectaron %d filas exactamente duplicadas en el dataset combinado.\n", exact_dup_rows))
        dup_act_choice <- if (!is.null(user_cfg$duplicate_action)) user_cfg$duplicate_action else user_cfg$duplicate_key_strategy
        if (!is.null(dup_act_choice) && dup_act_choice == "keep_first") {
          dat_raw <- dat_raw %>% distinct()
          record_decision(1.1, "Filas duplicadas post-unión", "Conservar primera ocurrencia (eliminar filas idénticas)",
                          source = "user_config", affected_rows = exact_dup_rows)
          cat(sprintf("  -> Deduplicación aplicada: %d filas idénticas descartadas.\n", exact_dup_rows))
        }
      }
      
      join_info <- sprintf("Unión relacional: '%s' (%d filas) y '%s' (%d filas) usando clave '%s'", 
                           s_sites, n_sites_raw, s_horiz, n_horiz_raw, target_key)
      record_decision(1.1, "Unión de tablas", "left_join relacional", source = "user_config",
                      affected_rows = nrow(dat_raw),
                      affected_profiles = length(unique(na.omit(df_sites[[join_key_site]]))),
                      details = sprintf("Orphan sites: %d | Orphan horizons: %d | Dups post-join: %d", orphan_sites, orphan_horizons, exact_dup_rows))
    } else {
      dat_raw <- readxl::read_excel(input_file, sheet = 1, skip = skip_n, guess_max = 100000)
      dat_raw <- clean_units_row(dat_raw)
      exact_dup_rows <- sum(duplicated(dat_raw))
      join_info <- paste("Lectura de hoja principal:", sheets[1], "(sin clave común detectada)")
    }
  }
} else {
  dat_raw <- readr::read_csv(input_file, skip = skip_n, show_col_types = FALSE)
  dat_raw <- clean_units_row(dat_raw)
  exact_dup_rows <- sum(duplicated(dat_raw))
  join_info <- "Archivo delimitado plano (CSV)"
}

# >>> ADAPT:read_and_join
# Punto de extensión: inserción de filtros o transformaciones personalizadas post-unión.
# Objetos disponibles: dat_raw (data.frame), user_cfg (list), record_decision (función)
# Invariante: dat_raw debe contener las filas y columnas requeridas para el mapeo.
# <<< ADAPT:read_and_join

# 3. Diccionario Edafológico de Variables Clave para DSM (ISO 28258) ------------
dsm_dict <- list(
  profile_code = c("profile_code", "profile_id", "id_perfil", "perfil", "codigo", "sitio", 
                   "calicata", "pedon_id", "site_id", "id", "sample_id", "profile_no", "prof_id",
                   "cod_sitio", "id_sitio", "site_code", "site", "prof_code"),
  Horizon      = c("horizon", "horizonte", "hor", "hz", "capa", "estrato", "layer", "subsample",
                   "id_horiz", "id_horizonte", "horiz_id"),
  upper        = c("upper", "prof_sup", "desde", "limite_sup", "prof_inicial", "top_depth", 
                   "top", "from", "upper_depth", "depth_top", "prof_desde", "prof_ini", "depth_from"),
  lower        = c("lower", "prof_inf", "hasta", "limite_inf", "prof_final", "bottom_depth", 
                   "bottom", "to", "lower_depth", "depth_bottom", "prof_hasta", "prof_fin", "depth_to"),
  longitude    = c("longitude", "lon", "long", "longitud", "x", "coord_x", "x_coord", "xcoord", 
                   "dec_long", "wgs84_x", "long_wgs84", "point_x", "east", "easting", "x_proj", 
                   "este", "lon_dec", "coord_este"),
  latitude     = c("latitude", "lat", "latitud", "y", "coord_y", "y_coord", "ycoord", 
                   "dec_lat", "wgs84_y", "lat_wgs84", "point_y", "north", "northing", "y_proj", 
                   "norte", "lat_dec", "coord_norte"),
  SOC          = c("soc", "cos", "cot", "co", "c_org", "carbono_organico", "carbono", 
                   "oc", "org_c", "organic_carbon", "soil_organic_carbon", "c_organico"),
  OM           = c("om", "mo", "materia_organica", "mat_org", "som", "soil_organic_matter", "humus", "mat_organica"),
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

# A. Mapeo explícito desde user_config.json
if (!is.null(user_cfg$column_mapping) && length(user_cfg$column_mapping) > 0) {
  for (target_var in names(user_cfg$column_mapping)) {
    orig_col <- as.character(user_cfg$column_mapping[[target_var]])
    if (orig_col %in% cols_raw) {
      mapping <- rbind(mapping, data.frame(Original = orig_col, Estandar_DSM = target_var, stringsAsFactors = FALSE))
      rename_vector[target_var] <- orig_col
    } else {
      cat(sprintf("\n[AVISO MAPEO]: La columna '%s' declarada para '%s' no existe en el dataset tras la unión.\n", orig_col, target_var))
      cat("  Columnas disponibles tras la unión (names(dat_raw)):\n")
      cat(sprintf("  [%s]\n\n", paste(cols_raw, collapse = ", ")))
    }
  }
# B. Mapeo desde mapping_confirmed.csv si existe
} else if (file.exists(mapping_csv)) {
  m_csv <- read.csv(mapping_csv, stringsAsFactors = FALSE)
  if (all(c("Original", "Estandar_DSM") %in% names(m_csv))) {
    mapping <- m_csv %>% filter(Original %in% cols_raw)
    for (i in seq_len(nrow(mapping))) {
      rename_vector[mapping$Estandar_DSM[i]] <- mapping$Original[i]
    }
  }
# C. Mapeo automático por diccionario heurístico
} else {
  for (target_var in names(dsm_dict)) {
    matches <- which(cols_clean %in% tolower(dsm_dict[[target_var]]))
    if (length(matches) > 0) {
      orig_col <- cols_raw[matches[1]]
      if (!(orig_col %in% mapping$Original)) {
        mapping <- rbind(mapping, data.frame(Original = orig_col, Estandar_DSM = target_var, stringsAsFactors = FALSE))
        rename_vector[target_var] <- orig_col
      }
    }
  }
}

# Tratamiento de suma de fracciones de arena (Issue #18)
sand_sum_applied <- FALSE
if (!is.null(user_cfg$sand_sum) && length(user_cfg$sand_sum) > 0) {
  sand_cols <- unlist(user_cfg$sand_sum)
  missing_sand <- setdiff(sand_cols, names(dat_raw))
  if (length(missing_sand) > 0) {
    cat(sprintf("\n[AVISO sand_sum]: Columnas de arena no encontradas en datos: [%s]\n", paste(missing_sand, collapse = ", ")))
  } else {
    cat(sprintf("\n[*] Calculando Sand sumando fracciones: [%s] ...\n", paste(sand_cols, collapse = " + ")))
    raw_sand_mat <- sapply(dat_raw[, sand_cols, drop = FALSE], function(x) {
      val <- suppressWarnings(as.numeric(as.character(x)))
      val[is.na(val)] <- 0
      val
    })
    dat_raw$Sand <- rowSums(raw_sand_mat, na.rm = TRUE)
    all_na_sand <- apply(is.na(dat_raw[, sand_cols, drop = FALSE]), 1, all)
    dat_raw$Sand[all_na_sand] <- NA_real_
    
    if (!("Sand" %in% mapping$Estandar_DSM)) {
      mapping <- rbind(mapping, data.frame(Original = "Sand", Estandar_DSM = "Sand", stringsAsFactors = FALSE))
      rename_vector["Sand"] <- "Sand"
    }
    record_decision(1.1, "Suma de fracciones de arena", sprintf("Sand = %s", paste(sand_cols, collapse = " + ")),
                    source = "user_config", affected_rows = nrow(dat_raw), details = "Fracciones de arena consolidadas en Sand para análisis textural")
    sand_sum_applied <- TRUE
  }
}

# >>> ADAPT:column_mapping
# Punto de extensión: inserción de correspondencias o variables derivadas personalizadas.
# Objetos disponibles: dat_raw, mapping (data.frame: Original, Estandar_DSM), rename_vector (named chr), user_cfg, record_decision
# Invariante: registrar nuevas correspondencias en mapping y rename_vector antes de dat_step1.
# <<< ADAPT:column_mapping

# 4. Fail-Fast Pedológico Estricto de Variables Esenciales (Issue #18) ----------
essential_vars <- c("profile_code", "upper", "lower")
has_coords <- any(c("longitude", "latitude") %in% mapping$Estandar_DSM) || any(c("x", "y") %in% mapping$Estandar_DSM)
missing_essentials <- setdiff(essential_vars, mapping$Estandar_DSM)
if (!has_coords) missing_essentials <- c(missing_essentials, "coordenadas (longitude/latitude o x/y)")

allow_missing <- if (!is.null(user_cfg$allow_missing_essentials)) isTRUE(user_cfg$allow_missing_essentials) else FALSE

if (nrow(mapping) == 0) {
  cat("\n==============================================================================\n")
  cat("[ERROR FATAL EN MAPEO (Paso 1.1)]:\n")
  cat("No se pudo identificar automáticamente ninguna variable DSM (0 variables mapeadas).\n")
  cat("Columnas disponibles tras la unión (names(dat_raw)):\n  [", paste(cols_raw, collapse = ", "), "]\n\n")
  cat("ACCIONES NECESARIAS:\n")
  cat("1. Revisa las columnas listadas arriba.\n")
  cat("2. Abre 'config.json' y declara 'column_mapping' según 'docs/CONFIG_SCHEMA.md'.\n")
  cat("==============================================================================\n\n")
  stop("Ejecución detenida: No hay variables DSM identificadas.")
}

if (length(missing_essentials) > 0 && !allow_missing) {
  cat("\n==============================================================================\n")
  cat("[ERROR FATAL: VARIABLES ESENCIALES AUSENTES (Paso 1.1)]:\n")
  cat(sprintf("Faltan variables fundamentales para DSM: [%s]\n\n", paste(missing_essentials, collapse = ", ")))
  cat("Columnas disponibles tras la unión (names(dat_raw)):\n  [", paste(cols_raw, collapse = ", "), "]\n\n")
  cat("El flujo no puede continuar sin identificador de perfil, límites de profundidad y coordenadas.\n")
  cat("ACCIONES NECESARIAS:\n")
  cat("1. Revisa los nombres reales de columnas disponibles tras la unión listados arriba.\n")
  cat("2. En 'config.json', bajo 'column_mapping', mapea los nombres originales a:\n")
  cat("   - 'profile_code': identificador del perfil\n")
  cat("   - 'upper' / 'lower': límites superior e inferior de profundidad (cm)\n")
  cat("   - 'longitude' / 'latitude': coordenadas espaciales\n")
  cat("3. Si tu dataset intencionalmente carece de estas variables, define:\n")
  cat("   'allow_missing_essentials': true en config.json para permitir la exportación.\n")
  cat("==============================================================================\n\n")
  stop(sprintf("Ejecución detenida: Variables esenciales ausentes [%s].", paste(missing_essentials, collapse = ", ")))
}

# 5. Creación del dataset limpio de variables -----------------------------------
dat_step1 <- dat_raw %>%
  dplyr::select(all_of(mapping$Original)) %>%
  dplyr::rename(!!!rename_vector)

if ("audit_replica_flag" %in% names(dat_raw) && !("audit_replica_flag" %in% names(dat_step1))) {
  dat_step1$audit_replica_flag <- dat_raw$audit_replica_flag
}

# Tratamiento de columnas adicionales declaradas para conservar (keep_columns, Issue #31)
keep_cols_cfg <- if (!is.null(user_cfg$keep_columns)) unlist(user_cfg$keep_columns) else character(0)
extra_cols_added <- character(0)

if (length(keep_cols_cfg) > 0) {
  keep_cols_exist <- intersect(keep_cols_cfg, names(dat_raw))
  keep_cols_missing <- setdiff(keep_cols_cfg, names(dat_raw))
  if (length(keep_cols_missing) > 0) {
    cat(sprintf("\n[AVISO keep_columns]: Columnas solicitadas no encontradas en datos tras la unión: [%s]\n",
                paste(keep_cols_missing, collapse = ", ")))
  }
  
  extra_to_add <- setdiff(keep_cols_exist, names(dat_step1))
  for (col_extra in extra_to_add) {
    dat_step1[[col_extra]] <- dat_raw[[col_extra]]
  }
  extra_cols_added <- extra_to_add
  
  if (length(extra_cols_added) > 0) {
    cat(sprintf("[*] Conservando %d columnas adicionales (keep_columns): [%s]\n",
                length(extra_cols_added), paste(extra_cols_added, collapse = ", ")))
    record_decision(1.1, "Conservación de columnas adicionales",
                    sprintf("Preservadas: [%s]", paste(extra_cols_added, collapse = ", ")),
                    source = "user_config", affected_rows = nrow(dat_step1),
                    details = "Columnas preservadas declarativamente vía 'keep_columns'")
  }
}

n_profiles <- if ("profile_code" %in% names(dat_step1)) length(unique(na.omit(dat_step1$profile_code))) else 0

# Tratamiento verídico de SOC / Materia Orgánica
soc_conversion_note <- "No aplica"
if ("OM" %in% names(dat_step1) && !("SOC" %in% names(dat_step1))) {
  om_factor <- if (!is.null(user_cfg$om_to_soc_factor)) as.numeric(user_cfg$om_to_soc_factor) else NULL
  if (!is.null(om_factor) && om_factor > 0) {
    dat_step1 <- dat_step1 %>% mutate(SOC = round(as.numeric(OM) / om_factor, 2))
    soc_conversion_note <- sprintf("Derivado por usuario: SOC = OM / %.3f", om_factor)
    record_decision(1.1, "Derivación SOC", sprintf("SOC = OM / %.3f", om_factor), source = "user_config",
                    affected_rows = nrow(dat_step1), affected_profiles = n_profiles,
                    details = "Conversión de Materia Orgánica a Carbono Orgánico aprobada por usuario")
  } else {
    soc_conversion_note <- "OM presente pero NO convertido a SOC (pendiente factor del usuario; reversible)"
  }
}

cols_descartadas <- setdiff(cols_raw, union(mapping$Original, extra_cols_added))

# 6. Generar Reporte de Texto UTF-8 100% Verídico ------------------------------
report_con <- file(output_report, open = "wt", encoding = "UTF-8")
writeLines("================================================================================", report_con)
writeLines("  DSM-HARNESS | REPORTE PASO 1.1: MAPEO Y SELECCIÓN DE VARIABLES", report_con)
writeLines("================================================================================", report_con)
writeLines(paste("Fecha y hora:        ", format(Sys.time(), "%Y-%m-%d %H:%M:%S")), report_con)
writeLines(paste("Archivo de entrada:  ", input_file), report_con)
writeLines(paste("Estructura de carga: ", join_info), report_con)
writeLines(paste("Dimensiones iniciales:", nrow(dat_raw), "filas x", ncol(dat_raw), "columnas"), report_con)
writeLines(paste("Dimensiones filtradas:", nrow(dat_step1), "filas x", ncol(dat_step1), "variables DSM"), report_con)
if ("profile_code" %in% names(dat_step1)) {
  writeLines(paste("Número de perfiles únicos:", n_profiles), report_con)
} else {
  writeLines("Número de perfiles únicos: NO EVALUADO (falta mapear 'profile_code')", report_con)
}
writeLines("--------------------------------------------------------------------------------", report_con)
writeLines("AUDITORÍA DE CLAVES Y RELACIONES:", report_con)
writeLines(sprintf("  Claves duplicadas en hoja de sitios:       %d", dup_site_count), report_con)
if (evaluated_duplicates) {
  writeLines(sprintf("  Claves duplicadas/réplicas en horizontes:  %d", dup_key_count), report_con)
  writeLines(sprintf("  Tratamiento de duplicados aplicado:        %s", duplicate_handling_applied), report_con)
} else {
  writeLines("  Claves duplicadas/réplicas en horizontes:  NO EVALUADO (sin clave de horizonte)", report_con)
  writeLines("  Tratamiento de duplicados aplicado:        NO APLICA", report_con)
}
writeLines(sprintf("  Filas exactamente duplicadas post-unión:   %d", exact_dup_rows), report_con)
if (!is.na(orphan_horizons)) {
  writeLines(sprintf("  Horizontes huérfanos (sin perfil en sitios): %d", orphan_horizons), report_con)
  writeLines(sprintf("  Sitios sin horizontes registrados:          %d", orphan_sites), report_con)
}
writeLines("--------------------------------------------------------------------------------", report_con)
writeLines("VARIABLES FUNDAMENTALES EVALUADAS:", report_con)
for (ev in essential_vars) {
  status_ev <- if (ev %in% names(dat_step1)) sprintf("PRESENTE (mapeada desde '%s')", rename_vector[ev]) else "FALTANTE"
  writeLines(sprintf("  %-15s : %s", ev, status_ev), report_con)
}
status_coord <- if (has_coords) "PRESENTE" else "FALTANTE"
writeLines(sprintf("  %-15s : %s", "coordenadas", status_coord), report_con)
writeLines("--------------------------------------------------------------------------------", report_con)
writeLines("ESTADO DE PROPIEDADES COMPLEMENTARIAS:", report_con)
writeLines(paste("  Derivación de SOC desde OM:", soc_conversion_note), report_con)
if (sand_sum_applied) {
  writeLines(sprintf("  Suma de fracciones de arena: APLICADA (%s -> Sand)", paste(user_cfg$sand_sum, collapse = " + ")), report_con)
}
if (length(extra_cols_added) > 0) {
  writeLines(sprintf("  Columnas adicionales preservadas (keep_columns): %s", paste(extra_cols_added, collapse = ", ")), report_con)
}
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

# 7. Guardar dataset intermedio -------------------------------------------------
readr::write_csv(dat_step1, output_csv)

# 8. Resumen en consola e instrucción ------------------------------------------
cat("\n==============================================================================\n")
cat("  TABLA DE MAPEO DE VARIABLES (Paso 1.1)\n")
cat("==============================================================================\n")
for (i in seq_len(nrow(mapping))) {
  cat(sprintf("  %-35s ---> %s\n", mapping$Original[i], mapping$Estandar_DSM[i]))
}
cat("------------------------------------------------------------------------------\n")
if ("profile_code" %in% names(dat_step1)) {
  cat(sprintf("Perfiles únicos identificados:         %d\n", n_profiles))
}
if (length(extra_cols_added) > 0) {
  cat(sprintf("Columnas adicionales preservadas:      %d [%s]\n", length(extra_cols_added), paste(extra_cols_added, collapse = ", ")))
}
if (dup_site_count > 0) {
  cat(sprintf("Claves duplicadas en hoja de sitios:   %d\n", dup_site_count))
}
if (evaluated_duplicates) {
  cat(sprintf("Claves duplicadas/réplicas horizontes: %d | Acción: %s\n", dup_key_count, duplicate_handling_applied))
}
if (exact_dup_rows > 0) {
  cat(sprintf("Filas duplicadas tras la unión:        %d\n", exact_dup_rows))
}
cat(sprintf("Variables descartadas: %d (detalladas en el reporte)\n", length(cols_descartadas)))
cat(sprintf("[OK] Dataset intermedio guardado en: %s (%d filas x %d columnas)\n", output_csv, nrow(dat_step1), ncol(dat_step1)))
cat(sprintf("[OK] Reporte descriptivo guardado en: %s\n", output_report))
if (decision_logged) {
  cat(sprintf("[OK] Registro de decisiones actualizado en: %s\n", decisions_log))
} else {
  cat(sprintf("[*] Registro de decisiones sin cambios en esta corrida (%s)\n", decisions_log))
}
cat("==============================================================================\n\n")

cat("------------------------------------------------------------------------------\n")
cat("INSTRUCCIÓN PARA EL ALUMNO:\n")
cat("1. Revisa la tabla mostrada arriba y las alertas de variables en consola.\n")
cat("2. En el chat con la IA, confirma si el mapeo es correcto y acuerda cómo\n")
cat("   tratar réplicas o conversiones antes de pasar al Paso 1.2.\n")
cat("------------------------------------------------------------------------------\n\n")
