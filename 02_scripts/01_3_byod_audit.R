# ==============================================================================
# DSM-Harness | Paso 1.3: Profundidades, Continuidad Vertical y Coherencia Edafológica
# ==============================================================================
# OBJETIVO:
# Auditar la coherencia vertical (solapes de profundidad, discontinuidades y
# espesores), evaluar coherencia analítica (balance de texturas 100%, rangos
# plausibles de pH y SOC), estimar opcionalmente Densidad Aparente (BD) en columna
# separada 'BD_est' evitando circularidad con SOC mediante competencia de PTFs
# evaluadas contra mediciones reales, registrar decisiones en decisions_log.csv
# y generar el dataset limpio 'cleaned_profiles.csv'.
#
# SALIDAS GENERADAS:
# 1. Dataset limpio final: 'data/cleaned_profiles.csv'
# 2. Reporte edafológico:  'reports/step1_3_pedological_report.txt'
# 3. Log de decisiones:    'decisions_log.csv'
#
# INSTRUCCIONES PARA EL ALUMNO:
# 1. Ejecuta este script en RStudio (Source o Ctrl+Shift+S).
# 2. Revisa el reporte edafológico en consola y archivo de texto.
# 3. Dialoga con la IA en el chat sobre los hallazgos y decisiones de consistencia.
# ==============================================================================

TEMPLATE_VERSION <- "2.0.0"

rm(list = setdiff(ls(), c("input_csv", "TEMPLATE_VERSION")))

suppressPackageStartupMessages({
  library(tidyverse)
})

# 1. Configuración de rutas y parámetros ---------------------------------------
is_project_env <- dir.exists("data") && dir.exists("reports")
base_data_dir  <- if (is_project_env) "data" else "01_data/profiles"
base_rep_dir   <- if (is_project_env) "reports" else "01_data/profiles"

config_file   <- if (file.exists("config.json")) "config.json" else file.path(base_data_dir, "user_config.json")
input_csv     <- file.path(base_data_dir, "step1_2_spatial.csv")
output_csv    <- file.path(base_data_dir, "cleaned_profiles.csv")
output_report <- file.path(base_rep_dir, "step1_3_pedological_report.txt")
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
  stop(sprintf("[ERROR FATAL]: No se encontró el dataset intermedio '%s'. Ejecuta primero el Paso 1.2.", input_csv))
}

cat(sprintf("\n[*] Cargando datos desde: %s ...\n", input_csv))
dat <- readr::read_csv(input_csv, show_col_types = FALSE)

# Identificar duplicados exactos previos para separar artefactos de unión
exact_dup_mask <- duplicated(dat) | duplicated(dat, fromLast = TRUE)
exact_dup_count <- sum(duplicated(dat))

# 2. Auditoría de Profundidades y Continuidad Vertical -------------------------
# >>> ADAPT:pedological_checks
cat("[*] Evaluando límites de profundidad y continuidad de horizontes...\n")

if (!("upper" %in% names(dat)) || !("lower" %in% names(dat))) {
  stop("[ERROR FATAL]: El dataset no contiene columnas 'upper' y 'lower' requeridas para auditar profundidades.")
}

dat$upper <- suppressWarnings(as.numeric(dat$upper))
dat$lower <- suppressWarnings(as.numeric(dat$lower))

# A. Inversión de límites (upper > lower)
inv_depths_mask <- (!is.na(dat$upper)) & (!is.na(dat$lower)) & (dat$upper > dat$lower)
inv_depths_count <- sum(inv_depths_mask)

if (inv_depths_count > 0) {
  cat(sprintf("[AVISO] Se detectaron %d registros con límites invertidos (upper > lower). Invirtiendo límites...\n", inv_depths_count))
  tmp_up <- dat$upper[inv_depths_mask]
  dat$upper[inv_depths_mask] <- dat$lower[inv_depths_mask]
  dat$lower[inv_depths_mask] <- tmp_up
  record_decision(1.3, "Profundidades invertidas", "Inversión automática de límites (swap)",
                  source = "script_default", affected_rows = inv_depths_count)
}

# B. Espesor nulo o negativo
dat$thickness <- dat$lower - dat$upper
zero_thick_mask <- (!is.na(dat$thickness)) & (dat$thickness == 0)
neg_depths_mask <- (!is.na(dat$upper) & dat$upper < 0) | (!is.na(dat$lower) & dat$lower < 0)
na_depths_mask  <- is.na(dat$upper) | is.na(dat$lower)

zero_thick_count <- sum(zero_thick_mask)
neg_depths_count <- sum(neg_depths_mask)
na_depths_count  <- sum(na_depths_mask)

# C. Solapes (overlaps) y Discontinuidades (gaps) dentro de cada perfil
overlaps_raw_count <- 0
overlaps_clean_count <- 0
gaps_count <- 0

if ("profile_code" %in% names(dat)) {
  dat <- dat %>%
    group_by(profile_code) %>%
    arrange(upper, .by_group = TRUE) %>%
    mutate(
      prev_lower = lag(lower),
      flag_depth_overlap = !is.na(prev_lower) & !is.na(upper) & (upper < prev_lower),
      flag_depth_gap     = !is.na(prev_lower) & !is.na(upper) & (upper > prev_lower)
    ) %>%
    select(-prev_lower) %>%
    ungroup()
  
  overlaps_raw_count <- sum(dat$flag_depth_overlap, na.rm = TRUE)
  gaps_count         <- sum(dat$flag_depth_gap, na.rm = TRUE)
  
  dat_dedup <- dat %>% distinct(profile_code, upper, lower, .keep_all = TRUE)
  dat_dedup <- dat_dedup %>%
    group_by(profile_code) %>%
    arrange(upper, .by_group = TRUE) %>%
    mutate(
      prev_lower = lag(lower),
      flag_overlap_dedup = !is.na(prev_lower) & !is.na(upper) & (upper < prev_lower)
    ) %>%
    ungroup()
  overlaps_clean_count <- sum(dat_dedup$flag_overlap_dedup, na.rm = TRUE)
}

dat$flag_invalid_depth <- na_depths_mask | zero_thick_mask | neg_depths_mask

# 3. Auditoría de Propiedades Físicas y Edafológicas ----------------------------
cat("[*] Evaluando coherencia de propiedades analíticas de suelo...\n")

# A. Suma de textura (Arena + Limo + Arcilla ~ 100%)
has_texture <- all(c("Clay", "Sand", "Silt") %in% names(dat))
tex_normal_count <- 0
tex_mod_count    <- 0
tex_severe_count <- 0
tex_extreme_count <- 0
tex_min <- NA_real_; tex_max <- NA_real_; tex_med <- NA_real_

if (has_texture) {
  dat <- dat %>%
    mutate(
      Clay = as.numeric(Clay),
      Sand = as.numeric(Sand),
      Silt = as.numeric(Silt),
      texture_sum = Clay + Sand + Silt
    )
  
  valid_tex_mask <- !is.na(dat$texture_sum)
  if (sum(valid_tex_mask) > 0) {
    tex_vals <- dat$texture_sum[valid_tex_mask]
    tex_min <- min(tex_vals); tex_max <- max(tex_vals); tex_med <- median(tex_vals)
    
    tex_normal_count  <- sum(tex_vals >= 95 & tex_vals <= 105)
    tex_mod_count     <- sum((tex_vals >= 90 & tex_vals < 95) | (tex_vals > 105 & tex_vals <= 110))
    tex_severe_count  <- sum(tex_vals < 90 | tex_vals > 110)
    tex_extreme_count <- sum(tex_vals <= 0 | tex_vals > 150)
  }
  
  dat$flag_texture_imbalance <- !is.na(dat$texture_sum) & (dat$texture_sum < 90 | dat$texture_sum > 110)
} else {
  dat$texture_sum <- NA_real_
  dat$flag_texture_imbalance <- FALSE
}

# B. Coherencia de pH
has_ph <- "pH_H2O" %in% names(dat)
ph_impossible_count <- 0
if (has_ph) {
  dat$pH_H2O <- as.numeric(dat$pH_H2O)
  ph_impossible_mask <- (!is.na(dat$pH_H2O)) & (dat$pH_H2O < 2.5 | dat$pH_H2O > 11.5)
  ph_impossible_count <- sum(ph_impossible_mask)
  dat$flag_ph_anomaly <- ph_impossible_mask
} else {
  dat$flag_ph_anomaly <- FALSE
}

# C. Coherencia de SOC
has_soc <- "SOC" %in% names(dat)
soc_neg_count <- 0
soc_high_count <- 0
if (has_soc) {
  dat$SOC <- as.numeric(dat$SOC)
  soc_neg_mask  <- (!is.na(dat$SOC)) & (dat$SOC < 0)
  soc_high_mask <- (!is.na(dat$SOC)) & (dat$SOC > 30)
  soc_neg_count  <- sum(soc_neg_mask)
  soc_high_count <- sum(soc_high_mask)
  dat$flag_soc_anomaly <- soc_neg_mask
} else {
  dat$flag_soc_anomaly <- FALSE
}

# D. Coherencia y Estimación de Densidad Aparente (BD) por Competencia de PTFs -
has_bd <- "BD" %in% names(dat)
bd_impossible_count <- 0
if (has_bd) {
  dat$BD <- as.numeric(dat$BD)
  # Umbral físico estándar de densidad mineral de partículas de suelo (cuarzo ~ 2.65 g/cm3)
  bd_impossible_mask <- (!is.na(dat$BD)) & (dat$BD <= 0 | dat$BD > 2.65)
  bd_impossible_count <- sum(bd_impossible_mask)
  dat$flag_bd_anomaly <- bd_impossible_mask
} else {
  dat$BD <- NA_real_
  dat$flag_bd_anomaly <- FALSE
  bd_impossible_mask <- rep(FALSE, nrow(dat))
}

estimate_bd_req <- if (!is.null(user_cfg$estimate_bd)) isTRUE(user_cfg$estimate_bd) else FALSE
dat$BD_est <- NA_real_
dat$BD_source <- if (has_bd && sum(!is.na(dat$BD)) > 0) "measured" else "missing"

ptf_eval_table <- data.frame(
  PTF = character(),
  Formula = character(),
  n_val = integer(),
  R2 = numeric(),
  RMSE = numeric(),
  Bias = numeric(),
  stringsAsFactors = FALSE
)
ptf_status <- "No solicitada (conservando BD medida original sin imputar)"

# Catálogo de PTFs documentadas candidatas
om_series <- if ("OM" %in% names(dat)) as.numeric(dat$OM) else if ("SOC" %in% names(dat)) as.numeric(dat$SOC) * 1.724 else NULL
soc_series <- if ("SOC" %in% names(dat)) as.numeric(dat$SOC) else if ("OM" %in% names(dat)) as.numeric(dat$OM) / 1.724 else NULL
sand_series <- if ("Sand" %in% names(dat)) as.numeric(dat$Sand) else NULL
clay_series <- if ("Clay" %in% names(dat)) as.numeric(dat$Clay) else NULL

calc_ptf_candidates <- function(df) {
  res <- list()
  # 1. Rawls et al. (1982)
  if (!is.null(om_series) && sum(!is.na(om_series)) > 0) {
    om_c <- pmin(pmax(om_series, 0.01), 60)
    bd_base <- if (!is.null(sand_series) && !is.null(clay_series)) {
      1.15 + 0.0038 * sand_series + 0.001 * clay_series
    } else 1.45
    res[["rawls_1982"]] <- list(
      name = "Rawls et al. (1982)",
      formula = "100 / (OM/0.224 + (100-OM)/BD_min)",
      pred = round(100 / ((om_c / 0.224) + ((100 - om_c) / bd_base)), 3)
    )
  }
  # 2. Adams (1973) / Curtis & Post (1964)
  if (!is.null(om_series) && sum(!is.na(om_series)) > 0) {
    om_c <- pmin(pmax(om_series, 0.01), 60)
    res[["adams_1973"]] <- list(
      name = "Adams (1973)",
      formula = "100 / (OM/0.244 + (100-OM)/1.64)",
      pred = round(100 / ((om_c / 0.244) + ((100 - om_c) / 1.64)), 3)
    )
  }
  # 3. Alexander (1980) / Manrique & Jones (1991)
  if (!is.null(soc_series) && sum(!is.na(soc_series)) > 0) {
    soc_c <- pmax(soc_series, 0.001)
    res[["alexander_1980"]] <- list(
      name = "Alexander (1980)",
      formula = "1.66 - 0.318 * sqrt(SOC)",
      pred = round(pmax(pmin(1.66 - 0.318 * sqrt(soc_c), 2.2), 0.3), 3)
    )
  }
  # 4. Saxton et al. (1986)
  if (!is.null(sand_series) && !is.null(clay_series) && sum(!is.na(sand_series)) > 0) {
    res[["saxton_1986"]] <- list(
      name = "Saxton et al. (1986)",
      formula = "1.30 + 0.003 * Sand - 0.002 * Clay",
      pred = round(pmax(pmin(1.30 + 0.003 * sand_series - 0.002 * clay_series, 2.2), 0.5), 3)
    )
  }
  res
}

if (estimate_bd_req) {
  cat("[*] Solicitud de estimación de Densidad Aparente detectada (estimate_bd = true) ...\n")
  ptf_list <- calc_ptf_candidates(dat)
  val_obs_mask <- (!is.na(dat$BD)) & (!bd_impossible_mask)
  n_val_total <- sum(val_obs_mask)
  
  # Decisión del responsable (Issue #23):
  # 1. Si hay suficientes datos medidos (n >= 5): competir y elegir la que mejor se adapte (menor RMSE)
  # 2. Si no hay suficientes datos medidos: no correr la PTF o aplicar la elegida expresamente por el usuario
  if (n_val_total >= 5 && length(ptf_list) > 0) {
    cat(sprintf("[*] Datos de validación disponibles (n = %d). Evaluando competencia de PTFs candidatas ...\n", n_val_total))
    
    for (pkey in names(ptf_list)) {
      p_obj <- ptf_list[[pkey]]
      pred_vals <- p_obj$pred
      eval_mask <- val_obs_mask & (!is.na(pred_vals))
      
      if (sum(eval_mask) >= 5) {
        obs <- dat$BD[eval_mask]
        prd <- pred_vals[eval_mask]
        r2_val   <- round(cor(obs, prd)^2, 3)
        rmse_val <- round(sqrt(mean((obs - prd)^2)), 3)
        bias_val <- round(mean(prd - obs), 3)
        
        ptf_eval_table <- rbind(ptf_eval_table, data.frame(
          PTF = p_obj$name,
          Formula = p_obj$formula,
          n_val = as.integer(sum(eval_mask)),
          R2 = r2_val,
          RMSE = rmse_val,
          Bias = bias_val,
          stringsAsFactors = FALSE
        ))
      }
    }
    
    if (nrow(ptf_eval_table) > 0) {
      # Seleccionar automáticamente la PTF con menor RMSE
      best_idx <- which.min(ptf_eval_table$RMSE)
      best_ptf_name <- ptf_eval_table$PTF[best_idx]
      best_ptf_rmse <- ptf_eval_table$RMSE[best_idx]
      best_ptf_r2   <- ptf_eval_table$R2[best_idx]
      
      # Buscar vector de predicción de la ganadora
      winner_key <- names(ptf_list)[sapply(ptf_list, function(x) x$name == best_ptf_name)]
      winner_pred <- ptf_list[[winner_key]]$pred
      dat$BD_est <- winner_pred
      
      impute_mask <- is.na(dat$BD) & !is.na(dat$BD_est)
      bd_imputed_count <- sum(impute_mask)
      dat$BD_source[impute_mask] <- "estimated"
      
      ptf_status <- sprintf("Seleccionada por mejor ajuste: %s (RMSE = %.3f g/cm3, R2 = %.3f sobre n=%d). Horizontes estimados: %d.",
                            best_ptf_name, best_ptf_rmse, best_ptf_r2, ptf_eval_table$n_val[best_idx], bd_imputed_count)
      
      record_decision(1.3, "Estimación BD", sprintf("PTF seleccionada por validación: %s (RMSE=%.3f, R2=%.3f)", best_ptf_name, best_ptf_rmse, best_ptf_r2),
                      source = "script_default", affected_rows = bd_imputed_count,
                      details = sprintf("Mejor ajuste competitivo sobre %d muestras medidas de validación", ptf_eval_table$n_val[best_idx]))
    } else {
      ptf_status <- "No fue posible evaluar ninguna PTF candidata sobre los datos de validación"
    }
    
  } else if (!is.null(user_cfg$selected_ptf) && nzchar(as.character(user_cfg$selected_ptf))) {
    sel_key <- tolower(as.character(user_cfg$selected_ptf))
    if (sel_key %in% names(ptf_list)) {
      p_obj <- ptf_list[[sel_key]]
      dat$BD_est <- p_obj$pred
      impute_mask <- is.na(dat$BD) & !is.na(dat$BD_est)
      bd_imputed_count <- sum(impute_mask)
      dat$BD_source[impute_mask] <- "estimated"
      
      ptf_status <- sprintf("PTF aplicada por selección del usuario: %s (sin datos de validación suficientes, n=%d). Horizontes estimados: %d.",
                            p_obj$name, n_val_total, bd_imputed_count)
      record_decision(1.3, "Estimación BD", sprintf("PTF seleccionada por usuario: %s", p_obj$name),
                      source = "user_config", affected_rows = bd_imputed_count,
                      details = sprintf("Aplicada sin validación cruzada local (n_medidos=%d < 5)", n_val_total))
    } else {
      ptf_status <- sprintf("PTF solicitada '%s' no disponible o faltan variables requeridas. Estimación omitida.", sel_key)
      record_decision(1.3, "Estimación BD", "Omitida por PTF no aplicable", source = "user_config", affected_rows = 0)
    }
  } else {
    ptf_status <- sprintf("No ejecutada por falta de datos de validación suficientes (n=%d < 5). El usuario puede configurar 'selected_ptf' si desea forzar un modelo.", n_val_total)
    record_decision(1.3, "Estimación BD", "Omitida por falta de datos de validación (n < 5)",
                    source = "script_default", affected_rows = 0,
                    details = "Sin datos medidos suficientes para validar y comparar PTFs candidatas")
  }
} else {
  record_decision(1.3, "Estimación BD", "Omitida / Conservar medidos sin imputar",
                  source = if (!is.null(user_cfg$estimate_bd)) "user_config" else "script_default",
                  affected_rows = 0, details = "No se solicitó estimación PTF")
}
# <<< ADAPT:pedological_checks

# 4. Cálculo de Métricas por Capas Estándar (0-30 cm vs 30-100 cm) --------------
dat <- dat %>%
  mutate(
    depth_mid = (upper + lower) / 2,
    layer_group = case_when(
      depth_mid <= 30 ~ "Superficial (0-30 cm)",
      depth_mid <= 100 ~ "Subsuperficial (30-100 cm)",
      TRUE ~ "Profundo (>100 cm)"
    )
  )

# 5. Generar Reporte de Texto Edafológico UTF-8 ---------------------------------
report_con <- file(output_report, open = "wt", encoding = "UTF-8")
writeLines("================================================================================", report_con)
writeLines("  DSM-HARNESS | REPORTE PASO 1.3: PROFUNDIDADES Y COHERENCIA EDAFOLÓGICA", report_con)
writeLines("================================================================================", report_con)
writeLines(paste("Fecha:", format(Sys.time(), "%Y-%m-%d %H:%M:%S")), report_con)
writeLines(paste("Archivo analizado:", input_csv), report_con)
writeLines(paste("Total registros evaluados:", nrow(dat)), report_con)
writeLines("--------------------------------------------------------------------------------", report_con)
writeLines("AUDITORÍA DE DUPLICADOS Y ARTEFACTOS DE UNIÓN:", report_con)
writeLines(sprintf("  Filas exactamente duplicadas:               %d (artefactos de unión)", exact_dup_count), report_con)
writeLines("--------------------------------------------------------------------------------", report_con)
writeLines("AUDITORÍA DE LÍMITES VERTICALES Y ESPESORES:", report_con)
writeLines(sprintf("  Límites invertidos detectados (corregidos): %d", inv_depths_count), report_con)
writeLines(sprintf("  Horizontes con espesor cero:                %d", zero_thick_count), report_con)
writeLines(sprintf("  Horizontes con profundidades negativas:     %d", neg_depths_count), report_con)
writeLines(sprintf("  Horizontes con profundidades NA:            %d", na_depths_count), report_con)
writeLines(sprintf("  Solapes verticales brutos detectados:       %d", overlaps_raw_count), report_con)
writeLines(sprintf("  Solapes reales tras deduplicación:          %d", overlaps_clean_count), report_con)
if (overlaps_raw_count > overlaps_clean_count) {
  writeLines(sprintf("  -> NOTA: %d solapes fueron artefactos producidos por filas duplicadas.", 
                     overlaps_raw_count - overlaps_clean_count), report_con)
}
writeLines(sprintf("  Discontinuidades / huecos verticales (gaps): %d", gaps_count), report_con)
writeLines("--------------------------------------------------------------------------------", report_con)
writeLines("AUDITORÍA DE COHERENCIA DE TEXTURA:", report_con)
if (has_texture) {
  writeLines(sprintf("  Horizontes evaluados con textura:           %d", sum(!is.na(dat$texture_sum))), report_con)
  writeLines(sprintf("  Rango de suma (Clay+Sand+Silt):             [%.1f, %.1f] %% (Mediana: %.1f %%)", tex_min, tex_max, tex_med), report_con)
  writeLines(sprintf("  Textura balanceada (95 - 105 %%):             %d horizontes", tex_normal_count), report_con)
  writeLines(sprintf("  Desbalance moderado (90-95 %% o 105-110 %%):   %d horizontes", tex_mod_count), report_con)
  writeLines(sprintf("  Desbalance severo (< 90 %% o > 110 %%):        %d horizontes", tex_severe_count), report_con)
  writeLines(sprintf("  Valores imposibles (<= 0 %% o > 150 %%):       %d horizontes", tex_extreme_count), report_con)
} else {
  writeLines("  Variables de textura (Clay, Sand, Silt) no presentes en el dataset: NO EVALUADO", report_con)
}
writeLines("--------------------------------------------------------------------------------", report_con)
writeLines("AUDITORÍA DE PROPIEDADES QUÍMICAS (pH y SOC):", report_con)
if (has_ph) {
  writeLines(sprintf("  pH en agua: Rango [%.2f, %.2f] | Valores anómalos (< 2.5 o > 11.5): %d", 
                     min(dat$pH_H2O, na.rm = TRUE), max(dat$pH_H2O, na.rm = TRUE), ph_impossible_count), report_con)
} else {
  writeLines("  pH_H2O: NO EVALUADO (variable no presente)", report_con)
}
if (has_soc) {
  writeLines(sprintf("  SOC: Rango [%.2f, %.2f] | Valores negativos: %d | Valores > 30 %%: %d",
                     min(dat$SOC, na.rm = TRUE), max(dat$SOC, na.rm = TRUE), soc_neg_count, soc_high_count), report_con)
} else {
  writeLines("  SOC: NO EVALUADO (variable no presente)", report_con)
}
writeLines("--------------------------------------------------------------------------------", report_con)
writeLines("DENSIDAD APARENTE (BD) Y COMPETENCIA DE PTFS:", report_con)
writeLines(sprintf("  Estado de estimación BD: %s", ptf_status), report_con)
if (has_bd) {
  writeLines(sprintf("  BD medida original: Rango [%.2f, %.2f] g/cm3 | Anómalos (<= 0 o > 2.65): %d",
                     min(dat$BD, na.rm = TRUE), max(dat$BD, na.rm = TRUE), bd_impossible_count), report_con)
}
if (nrow(ptf_eval_table) > 0) {
  writeLines("\nTABLA COMPARATIVA DE PTFS EVALUADAS CONTRA DATOS MEDIDOS:", report_con)
  writeLines(sprintf("  %-25s | %-6s | %-6s | %-12s | %-12s", "PTF Candidata", "n val", "R2", "RMSE (g/cm3)", "Sesgo (g/cm3)"), report_con)
  writeLines("  ----------------------------------------------------------------------------", report_con)
  for (i in seq_len(nrow(ptf_eval_table))) {
    writeLines(sprintf("  %-25s | %-6d | %-6.3f | %-12.3f | %-+12.3f",
                       ptf_eval_table$PTF[i], ptf_eval_table$n_val[i],
                       ptf_eval_table$R2[i], ptf_eval_table$RMSE[i], ptf_eval_table$Bias[i]), report_con)
  }
}
writeLines("================================================================================", report_con)
close(report_con)

# 6. Guardar dataset limpio final -----------------------------------------------
readr::write_csv(dat, output_csv)

# 7. Resumen en consola --------------------------------------------------------
cat("\n==============================================================================\n")
cat("  RESUMEN DE AUDITORÍA EDAFOLÓGICA (Paso 1.3)\n")
cat("==============================================================================\n")
cat(sprintf("Registros totales evaluados:          %d\n", nrow(dat)))
cat(sprintf("Filas duplicadas de unión:            %d\n", exact_dup_count))
cat(sprintf("Límites invertidos corregidos:        %d\n", inv_depths_count))
cat(sprintf("Solapes verticales brutos / netos:    %d / %d\n", overlaps_raw_count, overlaps_clean_count))
if (has_texture) {
  cat(sprintf("Balance textural (95-105%%):           %d horizontes (Desbalance severo: %d)\n", tex_normal_count, tex_severe_count))
}
cat(sprintf("Estado Densidad Aparente:             %s\n", ptf_status))
if (nrow(ptf_eval_table) > 0) {
  cat("Competencia de PTFs:\n")
  for (i in seq_len(nrow(ptf_eval_table))) {
    cat(sprintf("  - %-22s: RMSE = %.3f g/cm3 | R2 = %.3f (n=%d)\n",
                ptf_eval_table$PTF[i], ptf_eval_table$RMSE[i], ptf_eval_table$R2[i], ptf_eval_table$n_val[i]))
  }
}
cat(sprintf("[OK] Dataset limpio guardado en:      %s\n", output_csv))
cat(sprintf("[OK] Reporte edafológico guardado en: %s\n", output_report))
if (decision_logged) {
  cat(sprintf("[OK] Registro de decisiones en:       %s\n", decisions_log))
}
cat("==============================================================================\n\n")

cat("------------------------------------------------------------------------------\n")
cat("INSTRUCCIÓN PARA EL ALUMNO:\n")
cat("1. Revisa el reporte edafológico guardado en 'reports/step1_3_pedological_report.txt'.\n")
cat("2. En el chat con la IA, comenta los resultados de texturas, solapes y BD.\n")
cat("------------------------------------------------------------------------------\n\n")
