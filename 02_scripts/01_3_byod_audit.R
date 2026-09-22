# ==============================================================================
# DSM-Harness | Paso 1.3: Profundidades, Límites de Horizontes y Coherencia Edafológica
# ==============================================================================
# OBJETIVO:
# Auditar los límites verticales de horizontes (upper, lower), verificar coherencia
# física (upper >= 0, lower > upper), comprobar coherencia analítica (suma de texturas,
# rangos de pH y SOC), estimar densidad aparente faltante (PTF Saxton 2006),
# generar gráficos diagnósticos de profundidad y producir un reporte de texto
# para que la IA plantee preguntas de reflexión pedológica.
#
# SALIDAS GENERADAS:
# 1. Dataset final Etapa 1: '01_data/profiles/cleaned_profiles.csv'
# 2. Reporte edafológico:   '01_data/profiles/step1_3_pedological_report.txt'
# 3. Gráficos en RStudio:   Curvas de profundidad y diagramas de distribución
#
# INSTRUCCIONES PARA EL ALUMNO:
# 1. Ejecuta este script en RStudio (Source o Ctrl+Shift+S).
# 2. Observa los gráficos de perfiles de suelo en la pestaña 'Plots'.
# 3. Avísale a la IA en el chat cuando termine de ejecutarse.
# ==============================================================================

rm(list = ls())

suppressPackageStartupMessages({
  library(tidyverse)
})

# 1. Configuración de rutas ----------------------------------------------------
input_csv     <- "01_data/profiles/step1_2_spatial.csv"
output_csv    <- "01_data/profiles/cleaned_profiles.csv"
output_report <- "01_data/profiles/step1_3_pedological_report.txt"

if (!file.exists(input_csv)) {
  stop(sprintf("[ERROR] No se encontro '%s'. Debes ejecutar primero '02_scripts/01_2_byod_audit.R'.", input_csv))
}

cat(sprintf("\n[*] Cargando dataset del Paso 1.2: %s ...\n", input_csv))
dat <- readr::read_csv(input_csv, show_col_types = FALSE)

# 2. Auditoría de Límites Verticales de Horizontes ------------------------------
cat("[*] Auditando profundidades de horizontes (upper, lower)...\n")

# Asegurar tipo numérico en profundidades
dat <- dat %>%
  mutate(
    upper = as.numeric(upper),
    lower = as.numeric(lower)
  )

n_initial <- nrow(dat)

# Detección de anomalías de profundidad
inv_depths   <- sum(dat$lower < dat$upper, na.rm = TRUE)
zero_thick   <- sum(dat$lower == dat$upper, na.rm = TRUE)
neg_depths   <- sum(dat$upper < 0 | dat$lower < 0, na.rm = TRUE)
na_depths    <- sum(is.na(dat$upper) | is.na(dat$lower))

# Corrección de profundidades invertidas
if (inv_depths > 0) {
  cat(sprintf("[AVISO]: Se detectaron %d registros con lower < upper. Invirtiendo límites...\n", inv_depths))
  dat <- dat %>%
    mutate(
      temp_up = pmin(upper, lower),
      temp_lo = pmax(upper, lower),
      upper = temp_up,
      lower = temp_lo
    ) %>%
    select(-temp_up, -temp_lo)
}

# Filtrar horizontes con espesor cero o profundidades nulas
dat_clean <- dat %>%
  filter(!is.na(upper), !is.na(lower), lower > upper, upper >= 0)

n_depth_filtered <- n_initial - nrow(dat_clean)
max_depth <- max(dat_clean$lower, na.rm = TRUE)

# 3. Auditoría de Propiedades Edafológicas --------------------------------------
cat("[*] Evaluando coherencia de propiedades analíticas de suelo...\n")

# A. Suma de textura (Arena + Limo + Arcilla ~ 100%)
has_texture <- all(c("Clay", "Sand", "Silt") %in% names(dat_clean))
texture_sum_ok <- NA
texture_anomalies <- 0

if (has_texture) {
  dat_clean <- dat_clean %>%
    mutate(
      Clay = as.numeric(Clay),
      Sand = as.numeric(Sand),
      Silt = as.numeric(Silt),
      texture_sum = Clay + Sand + Silt
    )
  
  # Considerar válido entre 95% y 105%
  valid_tex <- !is.na(dat_clean$texture_sum)
  if (sum(valid_tex) > 0) {
    tex_diff <- abs(dat_clean$texture_sum[valid_tex] - 100)
    texture_anomalies <- sum(tex_diff > 5)
    texture_sum_ok <- round(mean(tex_diff <= 5) * 100, 1)
  }
}

# B. Coherencia de pH
has_ph <- "pH_H2O" %in% names(dat_clean)
ph_outliers <- 0
if (has_ph) {
  dat_clean$pH_H2O <- as.numeric(dat_clean$pH_H2O)
  ph_outliers <- sum(dat_clean$pH_H2O < 2.5 | dat_clean$pH_H2O > 11.5, na.rm = TRUE)
}

# C. Coherencia de SOC
has_soc <- "SOC" %in% names(dat_clean)
soc_neg <- 0
soc_high <- 0
if (has_soc) {
  dat_clean$SOC <- as.numeric(dat_clean$SOC)
  soc_neg  <- sum(dat_clean$SOC < 0, na.rm = TRUE)
  soc_high <- sum(dat_clean$SOC > 30, na.rm = TRUE) # Suelos orgánicos / histosoles
  # Corregir negativos a 0
  dat_clean$SOC <- pmax(dat_clean$SOC, 0)
}

# D. Estimación de Densidad Aparente (BD) por Pedotransferencia (Saxton et al. 2006)
has_bd <- "BD" %in% names(dat_clean)
bd_imputed <- 0

if (!has_bd) {
  dat_clean$BD <- NA_real_
} else {
  dat_clean$BD <- as.numeric(dat_clean$BD)
}

bd_missing <- sum(is.na(dat_clean$BD))
if (bd_missing > 0 && has_texture && has_soc) {
  cat(sprintf("[*] Estimando Densidad Aparente (BD) para %d registros faltantes usando PTF...\n", bd_missing))
  
  # PTF simplificada de Saxton & Rawls (2006) para densidad aparente normal
  # BD_normal = (1 - porosidad) * 2.65
  # Aproximación robusta basada en materia orgánica y textura:
  # BD = 1.66 - 0.318 * sqrt(SOC)
  idx_ptf <- which(is.na(dat_clean$BD) & !is.na(dat_clean$SOC))
  if (length(idx_ptf) > 0) {
    soc_vals <- pmin(dat_clean$SOC[idx_ptf], 20)
    dat_clean$BD[idx_ptf] <- round(pmax(1.66 - 0.318 * sqrt(soc_vals), 0.70), 2)
    bd_imputed <- length(idx_ptf)
  }
}

# 4. Cálculo de Métricas por Capas Estándar (0-30 cm vs 30-100 cm) --------------
dat_clean <- dat_clean %>%
  mutate(
    depth_mid = (upper + lower) / 2,
    layer_group = case_when(
      depth_mid <= 30 ~ "Superficial (0-30 cm)",
      depth_mid <= 100 ~ "Subsuperficial (30-100 cm)",
      TRUE ~ "Profundo (>100 cm)"
    )
  )

# Resumen de SOC por capa
soc_summary <- if (has_soc) {
  dat_clean %>%
    group_by(layer_group) %>%
    summarise(
      n = n(),
      soc_media = round(mean(SOC, na.rm = TRUE), 2),
      soc_mediana = round(median(SOC, na.rm = TRUE), 2),
      .groups = "drop"
    )
} else NULL

# 5. Generar Reporte de Texto Edafológico (para lectura de la IA) ---------------
report_con <- file(output_report, open = "wt", encoding = "UTF-8")
writeLines("================================================================================", report_con)
writeLines("  DSM-HARNESS | REPORTE PASO 1.3: PROFUNDIDADES Y COHERENCIA EDAFOLÓGICA", report_con)
writeLines("================================================================================", report_con)
writeLines(paste("Fecha:", format(Sys.time(), "%Y-%m-%d %H:%M:%S")), report_con)
writeLines(paste("Archivo analizado:", input_csv), report_con)
writeLines("--------------------------------------------------------------------------------", report_con)
writeLines("AUDITORÍA DE PROFUNDIDADES Y LÍMITES DE HORIZONTES:", report_con)
writeLines(sprintf("  Registros iniciales:              %d", n_initial), report_con)
writeLines(sprintf("  Registros depurados válidos:      %d", nrow(dat_clean)), report_con)
writeLines(sprintf("  Profundidades invertidas (fix):   %d", inv_depths), report_con)
writeLines(sprintf("  Horizontes espesor 0 (omitidos):  %d", zero_thick), report_con)
writeLines(sprintf("  Profundidades negativas:          %d", neg_depths), report_con)
writeLines(sprintf("  Profundidad máxima del dataset:   %.1f cm", max_depth), report_con)
writeLines("--------------------------------------------------------------------------------", report_con)
writeLines("COHERENCIA ANALÍTICA DE PROPIEDADES DE SUELO:", report_con)
if (has_texture) {
  writeLines(sprintf("  Textura: Horizontes con suma Sand+Silt+Clay ~ 100%% (±5%%): %.1f%% (%d anomalías)",
                     ifelse(is.na(texture_sum_ok), 0, texture_sum_ok), texture_anomalies), report_con)
}
if (has_ph) {
  writeLines(sprintf("  pH: Rango [%.2f, %.2f] | Valores anómalos (<2.5 o >11.5): %d",
                     min(dat_clean$pH_H2O, na.rm = TRUE), max(dat_clean$pH_H2O, na.rm = TRUE), ph_outliers), report_con)
}
if (has_soc) {
  writeLines(sprintf("  SOC: Rango [%.2f, %.2f] g/kg o %% | Valores negativos corregidos: %d | Horizontes orgánicos (>30%%): %d",
                     min(dat_clean$SOC, na.rm = TRUE), max(dat_clean$SOC, na.rm = TRUE), soc_neg, soc_high), report_con)
}
writeLines(sprintf("  Densidad Aparente (BD): Registros imputados vía PTF (Saxton): %d", bd_imputed), report_con)
if (!is.null(soc_summary)) {
  writeLines("--------------------------------------------------------------------------------", report_con)
  writeLines("DISTRIBUCIÓN DE CARBONO ORGÁNICO (SOC) POR PROFUNDIDAD:", report_con)
  for (r in seq_len(nrow(soc_summary))) {
    writeLines(sprintf("  - %-25s: n = %4d | Media = %5.2f | Mediana = %5.2f",
                       soc_summary$layer_group[r], soc_summary$n[r], 
                       soc_summary$soc_media[r], soc_summary$soc_mediana[r]), report_con)
  }
}
writeLines("================================================================================", report_con)
close(report_con)

# 6. Exportar dataset final limpio de la Etapa 1 --------------------------------
# Limpiar columnas auxiliares temporales
dat_final <- dat_clean %>%
  select(-any_of(c("depth_mid", "layer_group", "texture_sum")))

readr::write_csv(dat_final, output_csv)

# 7. Diagnóstico Visual en RStudio ---------------------------------------------
cat("\n[*] Generando visualizaciones diagnósticas de profundidad en RStudio...\n")

if (has_soc) {
  p1 <- ggplot(dat_clean %>% filter(!is.na(SOC)), aes(x = SOC, y = (upper + lower)/2)) +
    geom_point(alpha = 0.4, color = "darkgreen", size = 1.8) +
    geom_smooth(method = "loess", se = TRUE, color = "black", linewidth = 0.8) +
    scale_y_reverse() +
    theme_minimal() +
    labs(
      title = "Curva de Decaimiento de Carbono Orgánico con la Profundidad",
      subtitle = sprintf("Total: %d horizontes evaluados | Profundidad máx: %.0f cm", nrow(dat_clean), max_depth),
      x = "Carbono Orgánico del Suelo (SOC)",
      y = "Profundidad media del horizonte (cm)"
    )
  print(p1)
  cat("[OK] Gráfico de perfil de SOC mostrado en RStudio (Plots).\n")
} else if (has_ph) {
  p2 <- ggplot(dat_clean %>% filter(!is.na(pH_H2O)), aes(x = pH_H2O, y = (upper + lower)/2)) +
    geom_point(alpha = 0.4, color = "darkblue", size = 1.8) +
    geom_smooth(method = "loess", se = TRUE, color = "black", linewidth = 0.8) +
    scale_y_reverse() +
    theme_minimal() +
    labs(
      title = "Perfil de pH en Función de la Profundidad",
      subtitle = sprintf("Total: %d horizontes evaluados", nrow(dat_clean)),
      x = "pH (H2O)",
      y = "Profundidad media del horizonte (cm)"
    )
  print(p2)
  cat("[OK] Gráfico de perfil de pH mostrado en RStudio (Plots).\n")
}

cat("\n==============================================================================\n")
cat("  RESUMEN DE AUDITORÍA EDAFOLÓGICA (Paso 1.3)\n")
cat("==============================================================================\n")
cat(sprintf("  Horizontes finales validados: %d de %d\n", nrow(dat_clean), n_initial))
cat(sprintf("  Profundidad máxima alcanzada: %.1f cm\n", max_depth))
if (bd_imputed > 0) cat(sprintf("  Valores BD estimados vía PTF: %d\n", bd_imputed))
cat(sprintf("  Dataset final guardado en:   %s\n", output_csv))
cat(sprintf("  Reporte guardado en:         %s\n", output_report))
cat("==============================================================================\n\n")

cat("------------------------------------------------------------------------------\n")
cat("INSTRUCCIÓN PARA EL ALUMNO:\n")
cat("1. Examina el gráfico de profundidad en la pestaña 'Plots' de RStudio.\n")
cat("2. Observa si el carbono orgánico decae exponencialmente con la profundidad,\n")
cat("   o si identificas anomalías o horizontes enterrados.\n")
cat("3. Avísale a la IA en el chat que ya ejecutaste '01_3_byod_audit.R'.\n")
cat("   -> La IA leerá el reporte edafológico y formulará las preguntas de reflexión.\n")
cat("------------------------------------------------------------------------------\n\n")
