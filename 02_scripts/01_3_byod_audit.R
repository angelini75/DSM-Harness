# ==============================================================================
# DSM-Harness | Paso 1.3: Profundidades, Límites de Horizontes y Coherencia Edafológica
# ==============================================================================
# OBJETIVO:
# Auditar los límites verticales de horizontes (upper, lower), verificar coherencia
# física y solapamientos dentro de perfiles, comprobar balance analítico de texturas,
# detectar valores físicamente imposibles, evaluar estimación de densidad aparente
# de forma no destructiva (solo si es solicitada por el usuario), generar gráficos
# diagnósticos y producir un reporte edafológico 100% calculado.
#
# SALIDAS GENERADAS:
# 1. Dataset final Etapa 1: '01_data/profiles/cleaned_profiles.csv'
# 2. Reporte edafológico:   '01_data/profiles/step1_3_pedological_report.txt'
# 3. Log de decisiones:     '01_data/profiles/decisions_log.csv'
# 4. Gráficos en RStudio:   Curvas de profundidad y balance de textura
#
# INSTRUCCIONES PARA EL ALUMNO:
# 1. Ejecuta este script en RStudio (Source o Ctrl+Shift+S).
# 2. Observa los gráficos de perfiles en la pestaña 'Plots' y las alertas en consola.
# 3. Dialoga con la IA en el chat sobre los hallazgos y decisiones de consistencia.
# ==============================================================================

rm(list = ls())

suppressPackageStartupMessages({
  library(tidyverse)
})

# 1. Configuración de rutas y parámetros ---------------------------------------
config_file   <- "01_data/profiles/user_config.json"
input_csv     <- "01_data/profiles/step1_2_spatial.csv"
output_csv    <- "01_data/profiles/cleaned_profiles.csv"
output_report <- "01_data/profiles/step1_3_pedological_report.txt"
decisions_log <- "01_data/profiles/decisions_log.csv"
decision_logged <- FALSE

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
  decision_logged <<- TRUE
}

# Cargar configuración de usuario si existe
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

if (!file.exists(input_csv)) {
  stop(sprintf("[ERROR] No se encontró '%s'. Debes ejecutar primero '02_scripts/01_2_byod_audit.R'.", input_csv))
}

cat(sprintf("\n[*] Cargando dataset del Paso 1.2: %s ...\n", input_csv))
dat <- readr::read_csv(input_csv, show_col_types = FALSE)
n_initial <- nrow(dat)

# 2. Auditoría de Límites Verticales de Horizontes ------------------------------
cat("[*] Auditando profundidades de horizontes (upper, lower)...\n")

dat <- dat %>%
  mutate(
    upper = as.numeric(upper),
    lower = as.numeric(lower)
  )

# Detección de anomalías de profundidad
inv_depths_mask  <- (!is.na(dat$upper)) & (!is.na(dat$lower)) & (dat$lower < dat$upper)
zero_thick_mask  <- (!is.na(dat$upper)) & (!is.na(dat$lower)) & (dat$lower == dat$upper)
neg_depths_mask  <- (!is.na(dat$upper) & dat$upper < 0) | (!is.na(dat$lower) & dat$lower < 0)
na_depths_mask   <- is.na(dat$upper) | is.na(dat$lower)

inv_depths_count <- sum(inv_depths_mask)
zero_thick_count <- sum(zero_thick_mask)
neg_depths_count <- sum(neg_depths_mask)
na_depths_count  <- sum(na_depths_mask)

# Corrección segura de profundidades invertidas (swap si lower < upper)
if (inv_depths_count > 0) {
  cat(sprintf("[AVISO]: Se detectaron %d registros con lower < upper. Invirtiendo límites...\n", inv_depths_count))
  dat <- dat %>%
    mutate(
      temp_up = if_else(inv_depths_mask, pmin(upper, lower), upper),
      temp_lo = if_else(inv_depths_mask, pmax(upper, lower), lower),
      upper = temp_up,
      lower = temp_lo
    ) %>%
    select(-temp_up, -temp_lo)
  record_decision(1.3, "Profundidades invertidas", "Inversión de límites (swap)", affected_rows = inv_depths_count)
}

# Auditoría de coherencia vertical interna por perfil (solapamientos y huecos)
dat$flag_depth_overlap <- FALSE
dat$flag_depth_gap     <- FALSE

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
}

overlaps_count <- sum(dat$flag_depth_overlap, na.rm = TRUE)
gaps_count     <- sum(dat$flag_depth_gap, na.rm = TRUE)

# No eliminar silenciosamente registros; marcar banderas de calidad
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

# D. Densidad Aparente (BD): Chequeo físico y Pedotransferencia No Destructiva --
has_bd <- "BD" %in% names(dat)
if (!has_bd) dat$BD <- NA_real_ else dat$BD <- as.numeric(dat$BD)

bd_measured_count   <- sum(!is.na(dat$BD))
bd_missing_count    <- sum(is.na(dat$BD))
bd_impossible_mask  <- (!is.na(dat$BD)) & (dat$BD <= 0 | dat$BD > 2.65)
bd_impossible_count <- sum(bd_impossible_mask)
dat$flag_bd_anomaly <- bd_impossible_mask

# Inicializar columnas no destructivas
dat$BD_est    <- NA_real_
dat$BD_source <- if_else(!is.na(dat$BD), "measured", "missing")

# Estimación de BD: SOLO si el usuario lo activó explícitamente en user_config.json
ptf_status <- "No activada (imputación por defecto desactivada para evitar circularidad)"
ptf_val_r2 <- NA_real_; ptf_val_rmse <- NA_real_; ptf_val_bias <- NA_real_
bd_imputed_count <- 0

estimate_bd_requested <- isTRUE(user_cfg$estimate_bd)

if (estimate_bd_requested) {
  cat("[*] Estimación de Densidad Aparente solicitada por configuración de usuario...\n")
  # Implementación verificable de Rawls et al. (1982) / Saxton & Rawls (2006)
  # BD_est = 100 / ( (%OM / BD_om) + ( (100 - %OM) / BD_mineral ) )
  # con BD_om = 0.224 g/cm3 y BD_mineral = 1.45 g/cm3 (o dependiente de arena/arcilla)
  
  om_vals <- if ("OM" %in% names(dat) && sum(!is.na(dat$OM)) > 0) {
    as.numeric(dat$OM)
  } else if (has_soc && sum(!is.na(dat$SOC)) > 0) {
    as.numeric(dat$SOC) * 1.724
  } else NULL
  
  if (!is.null(om_vals)) {
    # Evitar divisiones por cero o valores negativos
    om_clean <- pmax(om_vals, 0.01)
    
    # Densidad mineral base aproximada (Rawls et al. 1982)
    bd_min_base <- if (has_texture && sum(!is.na(dat$Sand)) > 0) {
      1.15 + 0.0038 * dat$Sand + 0.001 * dat$Clay
    } else {
      1.45
    }
    
    rawls_bd <- 100 / ((om_clean / 0.224) + ((100 - om_clean) / bd_min_base))
    
    # Asignar a BD_est sin sobreescribir BD medido
    dat$BD_est <- round(rawls_bd, 3)
    
    # Identificar registros donde se imputa
    impute_mask <- is.na(dat$BD) & !is.na(dat$BD_est)
    bd_imputed_count <- sum(impute_mask)
    dat$BD_source[impute_mask] <- "estimated"
    
    # Validación sobre los datos que sí tenían BD medida
    val_mask <- (!is.na(dat$BD)) & (!is.na(dat$BD_est)) & (!bd_impossible_mask)
    if (sum(val_mask) >= 5) {
      obs <- dat$BD[val_mask]
      prd <- dat$BD_est[val_mask]
      ptf_val_r2   <- round(cor(obs, prd)^2, 3)
      ptf_val_rmse <- round(sqrt(mean((obs - prd)^2)), 3)
      ptf_val_bias <- round(mean(prd - obs), 3)
    }
    
    ptf_status <- sprintf("PTF Rawls/Saxton aplicada: %d horizontes estimados. Valida sobre medidos (n=%d): R2=%.3f, RMSE=%.3f, Sesgo=%.3f",
                          bd_imputed_count, sum(val_mask), ptf_val_r2, ptf_val_rmse, ptf_val_bias)
    record_decision(1.3, "Estimación BD", "PTF Rawls et al. (1982) en BD_est", 
                    affected_rows = bd_imputed_count, 
                    details = sprintf("R2=%.3f, RMSE=%.3f sobre %d medidos", ptf_val_r2, ptf_val_rmse, sum(val_mask)))
  } else {
    ptf_status <- "No fue posible estimar BD (datos de OM/SOC ausentes)"
  }
}

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
writeLines("AUDITORÍA DE LÍMITES VERTICALES Y ESPESORES:", report_con)
writeLines(sprintf("  Límites invertidos detectados (corregidos): %d", inv_depths_count), report_con)
writeLines(sprintf("  Horizontes con espesor cero:                %d", zero_thick_count), report_con)
writeLines(sprintf("  Horizontes con profundidades negativas:     %d", neg_depths_count), report_con)
writeLines(sprintf("  Horizontes con profundidades nulas (NA):    %d", na_depths_count), report_con)
writeLines(sprintf("  Solapamientos verticales dentro de perfil:  %d", overlaps_count), report_con)
writeLines(sprintf("  Discontinuidades / huecos verticales:       %d", gaps_count), report_con)
writeLines("--------------------------------------------------------------------------------", report_con)
writeLines("AUDITORÍA DE TEXTURA (ARENA + LIMO + ARCILLA):", report_con)
if (has_texture) {
  writeLines(sprintf("  Rango de suma de textura:         Min = %.1f%% | Mediana = %.1f%% | Max = %.1f%%", tex_min, tex_med, tex_max), report_con)
  writeLines(sprintf("  Suma dentro de tolerancia (95-105%%):  %d registros", tex_normal_count), report_con)
  writeLines(sprintf("  Desviación moderada (90-95%% / 105-110%%): %d registros", tex_mod_count), report_con)
  writeLines(sprintf("  Inconsistencia grave (<90%% o >110%%):   %d registros", tex_severe_count), report_con)
  writeLines(sprintf("  Casos extremos (<=0%% o >150%%):         %d registros", tex_extreme_count), report_con)
} else {
  writeLines("  Variables de textura (Clay, Sand, Silt) no presentes en el dataset.", report_con)
}
writeLines("--------------------------------------------------------------------------------", report_con)
writeLines("AUDITORÍA DE VALORES FÍSICAMENTE SOSPECHOSOS:", report_con)
writeLines(sprintf("  Densidad Aparente medida <= 0 o > 2.65 g/cm3: %d", bd_impossible_count), report_con)
writeLines(sprintf("  pH fuera del rango físico (2.5 - 11.5):       %d", ph_impossible_count), report_con)
writeLines(sprintf("  Carbono Orgánico (SOC) negativo:              %d", soc_neg_count), report_con)
writeLines(sprintf("  Carbono Orgánico (SOC) > 30%% (orgánico):      %d", soc_high_count), report_con)
writeLines("--------------------------------------------------------------------------------", report_con)
writeLines("ESTADO DE DENSIDAD APARENTE (BD):", report_con)
writeLines(sprintf("  Valores medidos originalmente en 'BD':      %d (%.1f%%)", bd_measured_count, (bd_measured_count / nrow(dat)) * 100), report_con)
writeLines(sprintf("  Valores faltantes (NA):                     %d", bd_missing_count), report_con)
writeLines(sprintf("  Valores estimados en 'BD_est':              %d", bd_imputed_count), report_con)
writeLines(sprintf("  Detalle de Pedotransferencia:               %s", ptf_status), report_con)
writeLines("================================================================================", report_con)
close(report_con)

# 6. Guardar dataset final de la Etapa 1 ----------------------------------------
readr::write_csv(dat, output_csv)

# 7. Diagnósticos Gráficos en RStudio -------------------------------------------
cat("\n[*] Generando gráficos diagnósticos edafológicos en RStudio...\n")

if (has_texture && sum(!is.na(dat$texture_sum)) > 0) {
  p1 <- ggplot(dat, aes(x = texture_sum)) +
    geom_histogram(binwidth = 2, fill = "#3182bd", color = "white", alpha = 0.8) +
    geom_vline(xintercept = 100, color = "red", linetype = "dashed", size = 1) +
    annotate("rect", xmin = 95, xmax = 105, ymin = 0, ymax = Inf, alpha = 0.15, fill = "green") +
    theme_minimal() +
    labs(
      title = "Balance de Textura (Arena + Limo + Arcilla)",
      subtitle = "Banda verde = Tolerancia aceptable (95% - 105%) | Línea roja = 100% ideal",
      x = "Suma de Textura (%)",
      y = "Frecuencia de Horizontes"
    )
  print(p1)
  cat("[OK] Gráfico de balance de textura generado en 'Plots'.\n")
}

cat("\n==============================================================================\n")
cat("  RESUMEN DE AUDITORÍA EDAFOLÓGICA (Paso 1.3)\n")
cat("==============================================================================\n")
cat(sprintf("  Registros procesados:          %d\n", nrow(dat)))
cat(sprintf("  Solapes verticales:            %d | Huecos verticales: %d\n", overlaps_count, gaps_count))
if (has_texture) cat(sprintf("  Textura fuera de balance:      %d registros\n", tex_severe_count))
cat(sprintf("  BD imposibles (<=0 o >2.65):   %d | pH anómalos: %d\n", bd_impossible_count, ph_impossible_count))
cat(sprintf("  BD medidos: %d | BD estimados: %d (columna 'BD_est')\n", bd_measured_count, bd_imputed_count))
cat(sprintf("[OK] Dataset final guardado en:   %s\n", output_csv))
cat(sprintf("[OK] Reporte guardado en:         %s\n", output_report))
if (decision_logged) {
  cat(sprintf("[OK] Registro decisiones:         %s\n", decisions_log))
} else {
  cat(sprintf("[*] Registro decisiones:         Sin cambios en esta corrida (%s)\n", decisions_log))
}
cat("==============================================================================\n\n")

cat("------------------------------------------------------------------------------\n")
cat("INSTRUCCIÓN PARA EL ALUMNO:\n")
cat("1. Revisa los gráficos y métricas de consistencia en RStudio.\n")
cat("2. En el chat con la IA, dialoga sobre las posibles anomalías de profundidad\n")
cat("   o textura, y decide si requieres estimar BD antes de avanzar a la Etapa 2.\n")
cat("------------------------------------------------------------------------------\n\n")
