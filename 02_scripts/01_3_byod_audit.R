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

rm(list = setdiff(ls(), c("input_file", "input_csv", "TEMPLATE_VERSION", "PROJECT_DIR", "CURRENT_PROJECT_DIR", "PROJECT_NAME", "run_step")))

suppressPackageStartupMessages({
  library(tidyverse)
})

# 1. Configuración de rutas y parámetros ---------------------------------------
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

if (!exists("input_csv") || is.null(input_csv) || !nzchar(input_csv)) {
  input_csv <- file.path(base_data_dir, "step1_2_spatial.csv")
}
output_csv    <- file.path(base_data_dir, "cleaned_profiles.csv")
output_report <- file.path(base_rep_dir, "step1_3_pedological_report.txt")

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
      cat(sprintf("[*] Configuración cargada desde: '%s'\n", config_file))
    }
  }, error = function(e) {
    cat(sprintf("[AVISO] No se pudo parsear '%s': %s\n", config_file, e$message))
  })
} else {
  cat(sprintf("[AVISO] No se encontró archivo de configuración en '%s'. Usando autodetección predeterminada.\n", config_file))
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
dat$BD_source <- dplyr::case_when(
  !is.na(dat$BD) & (!dat$flag_bd_anomaly) ~ "measured",
  TRUE                                    ~ "missing"
)

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

# Catálogo base de PTFs del script de referencia y calibración local (Issue #24)
om_series <- if ("OM" %in% names(dat)) as.numeric(dat$OM) else if ("SOC" %in% names(dat)) as.numeric(dat$SOC) * 1.724 else NULL
has_om_or_soc <- !is.null(om_series) && sum(!is.na(om_series)) > 0

# Umbral mínimo de muestras para calibrar función local simple (default 30, configurable)
bd_fit_min_n <- if (!is.null(user_cfg$bd_fit_min_n)) as.integer(user_cfg$bd_fit_min_n) else 30L
if (is.na(bd_fit_min_n) || bd_fit_min_n < 5L) bd_fit_min_n <- 30L

# 1. Catálogo base de referencia (Saini 1996, Drew 1973, Jeffrey 1979, Grigal 1989, Adams 1973, Honeyset 1989)
calc_reference_ptfs <- function(om_vec) {
  res <- list()
  if (is.null(om_vec) || sum(!is.na(om_vec)) == 0) return(res)
  
  om_c <- pmin(pmax(om_vec, 0.01), 70)
  
  # Saini (1996)
  res[["saini_1996"]] <- list(
    name = "Saini (1996)",
    formula = "1.62 - 0.06 * OM",
    pred = round(pmax(pmin(1.62 - 0.06 * om_c, 2.65), 0.2), 3)
  )
  # Drew (1973)
  res[["drew_1973"]] <- list(
    name = "Drew (1973)",
    formula = "1 / (0.6268 + 0.0361 * OM)",
    pred = round(pmax(pmin(1 / (0.6268 + 0.0361 * om_c), 2.65), 0.2), 3)
  )
  # Jeffrey (1979)
  res[["jeffrey_1979"]] <- list(
    name = "Jeffrey (1979)",
    formula = "1.482 - 0.6786 * ln(OM)",
    pred = round(pmax(pmin(1.482 - 0.6786 * log(om_c), 2.65), 0.2), 3)
  )
  # Grigal (1989)
  res[["grigal_1989"]] <- list(
    name = "Grigal (1989)",
    formula = "0.669 + 0.941 * exp(-0.06 * OM)",
    pred = round(pmax(pmin(0.669 + 0.941 * exp(-0.06 * om_c), 2.65), 0.2), 3)
  )
  # Adams (1973)
  res[["adams_1973"]] <- list(
    name = "Adams (1973)",
    formula = "100 / (OM/0.244 + (100-OM)/2.65)",
    pred = round(pmax(pmin(100 / ((om_c / 0.244) + ((100 - om_c) / 2.65)), 2.65), 0.2), 3)
  )
  # Honeyset & Ratkowsky (1989)
  res[["honeyset_1989"]] <- list(
    name = "Honeyset & Ratkowsky (1989)",
    formula = "1 / (0.564 + 0.0556 * OM)",
    pred = round(pmax(pmin(1 / (0.564 + 0.0556 * om_c), 2.65), 0.2), 3)
  )
  res
}

# 2. Ajuste paramétrico simple local con datos locales (sin Machine Learning)
fit_local_models <- function(df_val, om_full) {
  om_full_c <- pmin(pmax(om_full, 0.01), 70)
  val_om_c  <- pmin(pmax(df_val$OM, 0.01), 70)
  val_bd    <- df_val$BD
  
  candidates <- list()
  
  # Lineal: BD ~ OM
  m1 <- tryCatch(lm(val_bd ~ val_om_c), error = function(e) NULL)
  if (!is.null(m1)) {
    cf <- coef(m1)
    sign_b <- ifelse(cf[2] >= 0, "+", "-")
    f_str <- sprintf("%.3f %s %.4f*OM", cf[1], sign_b, abs(cf[2]))
    p_val <- pmax(pmin(predict(m1, newdata = data.frame(val_om_c = val_om_c)), 2.65), 0.2)
    p_all <- round(pmax(pmin(predict(m1, newdata = data.frame(val_om_c = om_full_c)), 2.65), 0.2), 3)
    candidates[["Lineal"]] <- list(formula = f_str, pred_val = p_val, pred_all = p_all)
  }
  
  # Logarítmico: BD ~ ln(OM)
  m2 <- tryCatch(lm(val_bd ~ log(val_om_c)), error = function(e) NULL)
  if (!is.null(m2)) {
    cf <- coef(m2)
    sign_b <- ifelse(cf[2] >= 0, "+", "-")
    f_str <- sprintf("%.3f %s %.4f*ln(OM)", cf[1], sign_b, abs(cf[2]))
    p_val <- pmax(pmin(predict(m2, newdata = data.frame(val_om_c = val_om_c)), 2.65), 0.2)
    p_all <- round(pmax(pmin(predict(m2, newdata = data.frame(val_om_c = om_full_c)), 2.65), 0.2), 3)
    candidates[["Logarítmico"]] <- list(formula = f_str, pred_val = p_val, pred_all = p_all)
  }
  
  # Recíproco / Inverso: 1/BD ~ OM
  m3 <- tryCatch(lm(I(1 / val_bd) ~ val_om_c), error = function(e) NULL)
  if (!is.null(m3)) {
    cf <- coef(m3)
    sign_b <- ifelse(cf[2] >= 0, "+", "-")
    f_str <- sprintf("1 / (%.4f %s %.4f*OM)", cf[1], sign_b, abs(cf[2]))
    pred_inv_val <- predict(m3, newdata = data.frame(val_om_c = val_om_c))
    p_val <- pmax(pmin(ifelse(pred_inv_val > 0, 1 / pred_inv_val, 2.65), 2.65), 0.2)
    pred_inv_all <- predict(m3, newdata = data.frame(val_om_c = om_full_c))
    p_all <- round(pmax(pmin(ifelse(pred_inv_all > 0, 1 / pred_inv_all, 2.65), 2.65), 0.2), 3)
    candidates[["Recíproco"]] <- list(formula = f_str, pred_val = p_val, pred_all = p_all)
  }
  
  # Exponencial: ln(BD) ~ OM
  m4 <- tryCatch(lm(log(val_bd) ~ val_om_c), error = function(e) NULL)
  if (!is.null(m4)) {
    cf <- coef(m4)
    sign_b <- ifelse(cf[2] >= 0, "+", "-")
    f_str <- sprintf("%.4f * exp(%s%.4f*OM)", exp(cf[1]), ifelse(cf[2] >= 0, "", "-"), abs(cf[2]))
    pred_log_val <- predict(m4, newdata = data.frame(val_om_c = val_om_c))
    p_val <- pmax(pmin(exp(pred_log_val), 2.65), 0.2)
    pred_log_all <- predict(m4, newdata = data.frame(val_om_c = om_full_c))
    p_all <- round(pmax(pmin(exp(pred_log_all), 2.65), 0.2), 3)
    candidates[["Exponencial"]] <- list(formula = f_str, pred_val = p_val, pred_all = p_all)
  }
  
  if (length(candidates) == 0) return(NULL)
  
  rmse_list <- sapply(candidates, function(cand) sqrt(mean((val_bd - cand$pred_val)^2)))
  best_name <- names(which.min(rmse_list))
  best_cand <- candidates[[best_name]]
  
  list(
    type = best_name,
    formula = best_cand$formula,
    name = sprintf("Ajuste local simple (%s)", best_name),
    pred = best_cand$pred_all
  )
}

val_obs_mask <- (!is.na(dat$BD)) & (!bd_impossible_mask) & (!is.na(om_series)) & (om_series > 0)
n_val_total <- sum(val_obs_mask)
all_models_list <- list()

if (has_om_or_soc) {
  # Cargar catálogo publicado de referencia
  ptf_ref <- calc_reference_ptfs(om_series)
  for (pkey in names(ptf_ref)) {
    all_models_list[[pkey]] <- ptf_ref[[pkey]]
  }
  
  # Muestras suficientes para calibrar función local simple (n >= bd_fit_min_n)
  if (n_val_total >= bd_fit_min_n) {
    cat(sprintf("[*] Muestras medidas suficientes (n = %d >= %d). Calibrando función paramétrica simple local ...\n",
                n_val_total, bd_fit_min_n))
    df_val_subset <- data.frame(BD = dat$BD[val_obs_mask], OM = om_series[val_obs_mask])
    loc_fit <- fit_local_models(df_val_subset, om_series)
    if (!is.null(loc_fit)) {
      all_models_list[["local_fit"]] <- loc_fit
    }
  }
  
  # Contrastar modelos contra datos medidos (n >= 5)
  if (n_val_total >= 5) {
    obs_bd <- dat$BD[val_obs_mask]
    for (mkey in names(all_models_list)) {
      m_obj <- all_models_list[[mkey]]
      prd_val <- m_obj$pred[val_obs_mask]
      valid_pair <- (!is.na(prd_val)) & (!is.na(obs_bd))
      if (sum(valid_pair) >= 5) {
        obs_sub <- obs_bd[valid_pair]
        prd_sub <- prd_val[valid_pair]
        r2_val   <- round(cor(obs_sub, prd_sub)^2, 3)
        rmse_val <- round(sqrt(mean((obs_sub - prd_sub)^2)), 3)
        bias_val <- round(mean(prd_sub - obs_sub), 3)
        
        ptf_eval_table <- rbind(ptf_eval_table, data.frame(
          PTF = m_obj$name,
          Formula = m_obj$formula,
          n_val = as.integer(sum(valid_pair)),
          R2 = r2_val,
          RMSE = rmse_val,
          Bias = bias_val,
          stringsAsFactors = FALSE
        ))
      }
    }
  }
}

# Reglas de imputación y confirmación (Issue #24):
# Siempre pedir confirmación al alumno antes de estimar/imputar BD_est. No se imputa automáticamente.
has_user_ptf_choice <- !is.null(user_cfg$selected_ptf) && nzchar(as.character(user_cfg$selected_ptf))

if (estimate_bd_req && has_user_ptf_choice) {
  sel_key <- tolower(trimws(as.character(user_cfg$selected_ptf)))
  winner_key <- NULL
  
  if (sel_key %in% names(all_models_list)) {
    winner_key <- sel_key
  } else if (sel_key %in% c("best_published", "best", "mejor")) {
    pub_rows <- ptf_eval_table[!grepl("Ajuste local", ptf_eval_table$PTF), ]
    if (nrow(pub_rows) > 0) {
      best_pub_name <- pub_rows$PTF[which.min(pub_rows$RMSE)]
      winner_key <- names(all_models_list)[sapply(all_models_list, function(x) x$name == best_pub_name)]
    }
  }
  
  if (!is.null(winner_key) && winner_key %in% names(all_models_list)) {
    chosen_model <- all_models_list[[winner_key]]
    impute_mask <- is.na(dat$BD) & !is.na(chosen_model$pred)
    dat$BD_est <- NA_real_
    dat$BD_est[impute_mask] <- chosen_model$pred[impute_mask]
    bd_imputed_count <- sum(impute_mask)
    dat$BD_source[impute_mask] <- "estimated"
    
    ptf_status <- sprintf("PTF imputada tras confirmación del usuario: %s (fórmula: %s). Horizontes estimados: %d.",
                          chosen_model$name, chosen_model$formula, bd_imputed_count)
    record_decision(1.3, "Estimación BD", sprintf("PTF confirmada por usuario: %s", chosen_model$name),
                    source = "user_config", affected_rows = bd_imputed_count,
                    details = sprintf("Modelo: %s. Fórmula: %s", chosen_model$name, chosen_model$formula))
  } else {
    ptf_status <- sprintf("Opción 'selected_ptf: %s' no disponible o no calibrable con los datos actuales. Estimación omitida.", sel_key)
    record_decision(1.3, "Estimación BD", "Omitida por opción no disponible", source = "user_config", affected_rows = 0)
  }
} else {
  # Sin confirmación del usuario: solo reportar diagnóstico/contraste sin imputar BD_est
  if (n_val_total >= bd_fit_min_n && nrow(ptf_eval_table) > 0) {
    ptf_status <- sprintf("Diagnóstico completado sobre n=%d medidos (>= %d). Se calibró función local simple y contrastaron 6 PTFs publicadas. BD_est NO imputada (requiere confirmación del usuario en 'config.json').",
                          n_val_total, bd_fit_min_n)
    record_decision(1.3, "Estimación BD", "Diagnóstico completado sin imputar (espera confirmación de usuario)",
                    source = "script_default", affected_rows = 0,
                    details = sprintf("Ajuste local y contraste de 6 PTFs disponibles sobre n=%d", n_val_total))
  } else if (n_val_total >= 5 && nrow(ptf_eval_table) > 0) {
    ptf_status <- sprintf("Diagnóstico de contraste completado sobre n=%d medidos (< %d requeridos para ajuste local). 6 PTFs publicadas contrastadas. BD_est NO imputada (requiere confirmación del usuario en 'config.json').",
                          n_val_total, bd_fit_min_n)
    record_decision(1.3, "Estimación BD", "Contraste completado sin imputar (espera confirmación de usuario)",
                    source = "script_default", affected_rows = 0,
                    details = sprintf("Contraste de 6 PTFs publicadas sobre n=%d", n_val_total))
  } else if (n_val_total < 5) {
    ptf_status <- sprintf("Datos medidos insuficientes para contrastar o calibrar PTF (n=%d < 5). BD_est NO imputada (el usuario puede indicar 'selected_ptf' en config.json si decide forzar un modelo publicado sin validación local).", n_val_total)
    record_decision(1.3, "Estimación BD", "Omitida por datos insuficientes (n < 5)",
                    source = "script_default", affected_rows = 0,
                    details = "Menos de 5 observaciones con BD y OM/SOC medidos simultáneamente")
  } else {
    ptf_status <- "No evaluada (variables OM / SOC ausentes para contrastar PTFs)"
    record_decision(1.3, "Estimación BD", "Omitida por falta de variables predictoras",
                    source = "script_default", affected_rows = 0)
  }
}

# >>> ADAPT:pedological_checks
# Punto de extensión: inserción de reglas de consistencia edafológica o banderas personalizadas.
# Objetos disponibles: dat (data.frame), user_cfg (list), record_decision (función)
# Invariante: dat debe conservar columnas upper, lower y variables analíticas.
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

# Conteo y coherencia de BD (Issue #27)
n_bd_measured <- sum(dat$BD_source == "measured")
n_bd_estimated <- sum(dat$BD_source == "estimated")
n_bd_missing <- sum(dat$BD_source == "missing")

n_bd_raw_non_na <- if (has_bd) sum(!is.na(dat$BD)) else 0
n_excluded_anomaly <- bd_impossible_count
n_excluded_missing_om <- if (has_bd) sum(!is.na(dat$BD) & !dat$flag_bd_anomaly & (is.na(om_series) | om_series <= 0)) else 0

# 5. Generar Reporte de Texto Edafológico UTF-8 ---------------------------------
report_con <- file(output_report, open = "wt", encoding = "UTF-8")
writeLines("================================================================================", report_con)
writeLines("  DSM-HARNESS | REPORTE PASO 1.3: PROFUNDIDADES Y COHERENCIA EDAFOLOGICA", report_con)
writeLines("================================================================================", report_con)
writeLines(paste("Fecha:", format(Sys.time(), "%Y-%m-%d %H:%M:%S")), report_con)
writeLines(paste("Archivo analizado:", input_csv), report_con)
writeLines(paste("Total registros evaluados:", nrow(dat)), report_con)
writeLines("--------------------------------------------------------------------------------", report_con)
writeLines("AUDITORIA DE DUPLICADOS Y ARTEFACTOS DE UNION:", report_con)
writeLines(sprintf("  Filas exactamente duplicadas:               %d (artefactos de union)", exact_dup_count), report_con)
writeLines("--------------------------------------------------------------------------------", report_con)
writeLines("AUDITORIA DE LIMITES VERTICALES Y ESPESORES:", report_con)
writeLines(sprintf("  Limites invertidos detectados (corregidos): %d", inv_depths_count), report_con)
writeLines(sprintf("  Horizontes con espesor cero:                %d", zero_thick_count), report_con)
writeLines(sprintf("  Horizontes con profundidades negativas:     %d", neg_depths_count), report_con)
writeLines(sprintf("  Horizontes con profundidades NA:            %d", na_depths_count), report_con)
writeLines(sprintf("  Solapes verticales brutos detectados:       %d", overlaps_raw_count), report_con)
writeLines(sprintf("  Solapes reales tras deduplicacion:          %d", overlaps_clean_count), report_con)
if (overlaps_raw_count > overlaps_clean_count) {
  writeLines(sprintf("  -> NOTA: %d solapes fueron artefactos producidos por filas duplicadas.", 
                     overlaps_raw_count - overlaps_clean_count), report_con)
}
writeLines(sprintf("  Discontinuidades / huecos verticales (gaps): %d", gaps_count), report_con)
writeLines("--------------------------------------------------------------------------------", report_con)
writeLines("AUDITORIA DE COHERENCIA DE TEXTURA:", report_con)
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
writeLines("AUDITORIA DE PROPIEDADES QUIMICAS (pH y SOC):", report_con)
if (has_ph) {
  writeLines(sprintf("  pH en agua: Rango [%.2f, %.2f] | Valores anomalos (< 2.5 o > 11.5): %d", 
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
writeLines("DENSIDAD APARENTE (BD), CONTRASTE Y CALIBRACION DE PTFS:", report_con)
writeLines(sprintf("  Estado de estimacion BD: %s", ptf_status), report_con)
if (has_bd || estimate_bd_req) {
  writeLines("\nBALANCE Y COBERTURA DE DENSIDAD APARENTE (BD):", report_con)
  writeLines(sprintf("  Filas totales evaluadas:                       %d", nrow(dat)), report_con)
  writeLines(sprintf("  BD con medicion valida (BD_source = 'measured'):  %d (%.1f%%)",
                     n_bd_measured, (n_bd_measured / nrow(dat)) * 100), report_con)
  writeLines(sprintf("  BD estimada por PTF   (BD_source = 'estimated'): %d (%.1f%%)",
                     n_bd_estimated, (n_bd_estimated / nrow(dat)) * 100), report_con)
  writeLines(sprintf("  Sin dato de BD        (BD_source = 'missing'):   %d (%.1f%%)",
                     n_bd_missing, (n_bd_missing / nrow(dat)) * 100), report_con)
  
  writeLines("\nDETALLE DE CALIBRACION Y EXCLUSIONES:", report_con)
  writeLines(sprintf("  Mediciones analizadas brutas:                  %d", n_bd_raw_non_na), report_con)
  writeLines(sprintf("  Excluidas por valor anomalo (<= 0 o > 2.65):   %d", n_excluded_anomaly), report_con)
  writeLines(sprintf("  Excluidas por falta de OM/SOC predictor:       %d", n_excluded_missing_om), report_con)
  writeLines(sprintf("  Total observaciones utilizadas en contraste:   %d (Umbral ajuste local: %d)",
                     n_val_total, bd_fit_min_n), report_con)
}
if (nrow(ptf_eval_table) > 0) {
  writeLines("\nTABLA COMPARATIVA DE PTFS EVALUADAS CONTRA DATOS MEDIDOS:", report_con)
  writeLines(sprintf("  %-32s | %-6s | %-6s | %-12s | %-12s", "PTF / Modelo", "n val", "R2", "RMSE (g/cm3)", "Sesgo (g/cm3)"), report_con)
  writeLines("  ---------------------------------------------------------------------------------------", report_con)
  for (i in seq_len(nrow(ptf_eval_table))) {
    writeLines(sprintf("  %-32s | %-6d | %-6.3f | %-12.3f | %-+12.3f",
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
cat(sprintf("Densidad Aparente - Medida válida:    %d (%.1f%%)\n", n_bd_measured, (n_bd_measured / nrow(dat)) * 100))
cat(sprintf("Densidad Aparente - Estimada (PTF):   %d (%.1f%%)\n", n_bd_estimated, (n_bd_estimated / nrow(dat)) * 100))
cat(sprintf("Densidad Aparente - Faltante:         %d (%.1f%%)\n", n_bd_missing, (n_bd_missing / nrow(dat)) * 100))
cat(sprintf("Estado Densidad Aparente:             %s\n", ptf_status))
if (nrow(ptf_eval_table) > 0) {
  cat("Contraste y evaluación de PTFs:\n")
  for (i in seq_len(nrow(ptf_eval_table))) {
    cat(sprintf("  - %-30s: RMSE = %.3f g/cm3 | R2 = %.3f (n=%d)\n",
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
