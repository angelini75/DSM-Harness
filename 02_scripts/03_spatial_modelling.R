# ==============================================================================
# DSM-Harness | Paso 3: Modelado Espacial y Validación Cruzada (QRF)
# ==============================================================================
# OBJETIVO:
# Realizar la selección de variables con Boruta, entrenar un modelo de bosque
# aleatorio de regresión cuantílica (QRF) con ranger/caret y validación cruzada
# repetida con afinación de grilla de hiperparámetros (mtry), evaluar métricas
# de desempeño (R^2, RMSE, CCC, sesgo) y guardar el modelo entrenado.
#
# SALIDAS GENERADAS:
# 1. Modelo entrenado:        'outputs/ranger_model_<target>.rds'
# 2. Reporte de modelado:     'reports/step3_modelling_report.txt'
# 3. Gráficos diagnósticos:   'reports/boruta_<target>.png', 'reports/scatterplot_<target>.png'
# 4. Log de decisiones:       'decisions_log.csv'
#
# INSTRUCCIONES PARA EL ALUMNO:
# 1. Asegúrate de haber ejecutado con éxito el Paso 2 (run_step("2")).
# 2. Ejecuta este script en RStudio (Source o Ctrl+Shift+S) o mediante run_step("3").
# 3. Dialoga con la IA sobre las covariables seleccionadas, la afinación y las métricas.
# ==============================================================================

TEMPLATE_VERSION <- "2.0.0"

rm(list = setdiff(ls(), c("input_file", "input_csv", "TEMPLATE_VERSION", "PROJECT_DIR", "CURRENT_PROJECT_DIR", "PROJECT_NAME", "run_step")))

suppressWarnings(suppressPackageStartupMessages({
  library(tidyverse)
  library(caret)
  library(ranger)
  library(Boruta)
}))

# 1. Configuración de rutas y proyecto -----------------------------------------
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
  base_out_dir  <- file.path(proj_active, "outputs")
  config_file   <- file.path(proj_active, "config.json")
  decisions_log <- file.path(proj_active, "decisions_log.csv")
} else {
  base_data_dir <- "01_data/profiles"
  base_rep_dir  <- "01_data/profiles"
  base_out_dir  <- "03_outputs/module3/models"
  config_file   <- "01_data/profiles/user_config.json"
  decisions_log <- "01_data/profiles/decisions_log.csv"
}

if (!dir.exists(base_data_dir)) dir.create(base_data_dir, recursive = TRUE)
if (!dir.exists(base_rep_dir))  dir.create(base_rep_dir, recursive = TRUE)
if (!dir.exists(base_out_dir))  dir.create(base_out_dir, recursive = TRUE)

input_csv     <- file.path(base_data_dir, "step2_covariates.csv")
output_report <- file.path(base_rep_dir,  "step3_modelling_report.txt")

# Carga de motor i18n
i18n_candidates <- c(
  if (!is.null(proj_active)) file.path(proj_active, "scripts", "00_i18n.R"),
  if (!is.null(proj_active)) file.path(proj_active, "00_i18n.R"),
  if (!is.null(proj_active)) file.path(proj_active, "02_scripts", "00_i18n.R"),
  "02_scripts/00_i18n.R",
  "scripts/00_i18n.R",
  "00_i18n.R"
)
for (cand in i18n_candidates) {
  if (!is.null(cand) && file.exists(cand)) {
    tryCatch(source(cand, local = FALSE), error = function(e) NULL)
    break
  }
}

# 2. Inicialización de Trazabilidad y Log de Decisiones ------------------------
run_id <- format(Sys.time(), "%Y%m%d_%H%M%S")
decision_logged <- FALSE

lang <- if (exists("get_project_language")) get_project_language() else "es"
is_en <- identical(lang, "en")

record_decision <- function(step, criterion, decision, source = "user_config",
                            affected_rows = 0, affected_profiles = 0, details = "") {
  if (is_en && exists("translate_decision_text")) {
    criterion <- translate_decision_text(criterion, "en")
    decision  <- translate_decision_text(decision, "en")
    details   <- translate_decision_text(details, "en")
  }
  entry <- data.frame(
    timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    run_id = run_id,
    template_version = TEMPLATE_VERSION,
    step = as.character(step),
    criterion = as.character(criterion),
    decision = as.character(decision),
    source = as.character(source),
    affected_rows = as.integer(affected_rows),
    affected_profiles = as.integer(affected_profiles),
    details = as.character(details),
    stringsAsFactors = FALSE
  )
  if (!file.exists(decisions_log)) {
    write.table(entry, decisions_log, sep = ",", row.names = FALSE, col.names = TRUE, qmethod = "double")
  } else {
    write.table(entry, decisions_log, sep = ",", row.names = FALSE, col.names = FALSE, append = TRUE, qmethod = "double")
  }
  decision_logged <<- TRUE
}

# 3. Cargar configuración de usuario ------------------------------------------
user_cfg <- list()
if (file.exists(config_file)) {
  tryCatch({
    if (requireNamespace("jsonlite", quietly = TRUE)) {
      user_cfg <- jsonlite::fromJSON(config_file, simplifyVector = FALSE)
      if (exists("get_project_language")) {
        lang <- get_project_language(user_cfg)
        is_en <- identical(lang, "en")
      }
      if (is_en) {
        cat(sprintf("[*] Configuration loaded from: '%s'\n", config_file))
      } else {
        cat(sprintf("[*] Configuración cargada desde: '%s'\n", config_file))
      }
    }
  }, error = function(e) {
    if (is_en) cat(sprintf("[NOTICE] Could not parse '%s': %s\n", config_file, e$message)) else cat(sprintf("[AVISO] No se pudo parsear '%s': %s\n", config_file, e$message))
  })
}

# 4. Cargar dataset con covariables --------------------------------------------
if (!file.exists(input_csv)) {
  stop(sprintf("[ERROR CRÍTICO] No se encontró el dataset de covariables en '%s'.\nEjecuta primero el Paso 2 (run_step('2')).", input_csv))
}

dat_cov <- readr::read_csv(input_csv, show_col_types = FALSE)
cat(sprintf("[*] Dataset con covariables cargado: %d registros.\n", nrow(dat_cov)))

# Identificar variable objetivo y columnas de covariables
meta_cols <- c("profile_code", "longitude", "latitude", "support_cm")
avail_targets <- setdiff(names(dat_cov), meta_cols)

target_prop <- if (!is.null(user_cfg$target_property)) as.character(user_cfg$target_property) else "SOC"
if (!(target_prop %in% names(dat_cov))) {
  candidates <- intersect(c("SOC", "OM", "pH_H2O", "Clay", "Sand", "Silt", "BD"), names(dat_cov))
  if (length(candidates) > 0) target_prop <- candidates[1] else target_prop <- avail_targets[1]
}

cov_cols <- setdiff(names(dat_cov), c(meta_cols, target_prop))
if (length(cov_cols) == 0) {
  stop("[ERROR CRÍTICO] No se encontraron columnas de covariables en el dataset.")
}

cat(sprintf("[*] Variable objetivo: '%s' | Total covariables candidatas: %d\n", target_prop, length(cov_cols)))

# Preparar datos completos (sin NA)
d_train <- dat_cov %>%
  dplyr::select(all_of(target_prop), all_of(cov_cols)) %>%
  na.omit() %>%
  as.data.frame()

n_train <- nrow(d_train)
cat(sprintf("[*] Datos para entrenamiento tras omitir NA: %d observaciones.\n", n_train))

# 5. Selección de variables con Boruta ------------------------------------------
set.seed(42)
boruta_runs <- if (!is.null(user_cfg$boruta_max_runs)) as.integer(user_cfg$boruta_max_runs) else 100
cat(sprintf("[*] Ejecutando selección de características Boruta (maxRuns = %d) ...\n", boruta_runs))

boruta_result <- Boruta::Boruta(
  y = d_train[, target_prop],
  x = d_train[, cov_cols],
  maxRuns = boruta_runs,
  doTrace = 0
)

selected_features <- Boruta::getSelectedAttributes(boruta_result, withTentative = TRUE)

if (length(selected_features) == 0) {
  cat("[AVISO] Boruta no confirmó variables; usando todas las covariables disponibles.\n")
  selected_features <- cov_cols
  boruta_decision_txt <- "Todas las covariables (ninguna confirmada por Boruta)"
} else {
  cat(sprintf("[OK] Boruta seleccionó %d variables (confirmadas + tentativas).\n", length(selected_features)))
  boruta_decision_txt <- sprintf("%d de %d covariables seleccionadas", length(selected_features), length(cov_cols))
}

record_decision(3.0, "Selección de características", boruta_decision_txt,
                source = if (!is.null(user_cfg$boruta_max_runs)) "user_config" else "script_default",
                affected_rows = n_train, affected_profiles = n_train,
                details = paste(selected_features, collapse = ", "))

# Guardar gráfico Boruta
boruta_png <- file.path(base_rep_dir, sprintf("boruta_%s.png", target_prop))
tryCatch({
  png(boruta_png, width = 18, height = 22, units = "cm", res = 150)
  par(las = 1, mar = c(4, 12, 4, 2) + 0.1)
  plot(boruta_result, horizontal = TRUE, las = 1, xlab = "Importancia Z-Score", ylab = "", cex.axis = 0.6)
  dev.off()
  cat(sprintf("[OK] Gráfico de importancia Boruta guardado: '%s'\n", boruta_png))
}, error = function(e) {
  cat("[AVISO] No se pudo generar gráfico Boruta PNG:", e$message, "\n")
})

# 6. Entrenamiento QRF con Validación Cruzada Repetida y Grilla de Afinación ---
cat("[*] Configurando validación cruzada repetida y afinación de hiperparámetros ...\n")
cv_folds   <- if (!is.null(user_cfg$cv_folds)) as.integer(user_cfg$cv_folds) else 5
cv_repeats <- if (!is.null(user_cfg$cv_repeats)) as.integer(user_cfg$cv_repeats) else 5

cv_control <- caret::trainControl(
  method = "repeatedcv",
  number = cv_folds,
  repeats = cv_repeats,
  savePredictions = "final"
)

mtry_base <- max(1, round(length(selected_features) / 3))
mtry_candidates <- unique(pmax(1, c(
  max(1, mtry_base - round(mtry_base / 2)),
  mtry_base,
  min(length(selected_features), mtry_base + round(mtry_base / 2))
)))

tune_grid <- expand.grid(
  mtry = mtry_candidates,
  min.node.size = 5,
  splitrule = c("variance", "extratrees")
)

n_threads <- max(1, parallel::detectCores() - 1)
cat(sprintf("[*] Entrenando Quantile Regression Forest (%d pliegues, %d repeticiones, %d hilos CPU) ...\n",
            cv_folds, cv_repeats, n_threads))

set.seed(42)
qrf_model <- caret::train(
  y = d_train[, target_prop],
  x = d_train[, selected_features, drop = FALSE],
  method = "ranger",
  quantreg = TRUE,
  importance = "permutation",
  trControl = cv_control,
  tuneGrid = tune_grid,
  num.threads = n_threads
)

best_tune <- qrf_model$bestTune
cat(sprintf("[OK] Mejor combinación de hiperparámetros: mtry = %d, splitrule = %s, min.node.size = %d\n",
            best_tune$mtry, best_tune$splitrule, best_tune$min.node.size))

# 7. Evaluación de exactitud y cálculo de métricas ------------------------------
cv_preds <- qrf_model$pred %>%
  filter(
    mtry == best_tune$mtry,
    splitrule == best_tune$splitrule,
    min.node.size == best_tune$min.node.size
  )

obs_vals  <- cv_preds$obs
pred_vals <- cv_preds$pred

# Funciones canónicas de evaluación
calc_rmse <- function(y_t, y_p) sqrt(mean((y_t - y_p)^2, na.rm = TRUE))
calc_mae  <- function(y_t, y_p) mean(abs(y_t - y_p), na.rm = TRUE)
calc_bias <- function(y_t, y_p) mean(y_p - y_t, na.rm = TRUE)
calc_r2   <- function(y_t, y_p) {
  1 - sum((y_t - y_p)^2, na.rm = TRUE) / sum((y_t - mean(y_t, na.rm = TRUE))^2, na.rm = TRUE)
}
calc_ccc  <- function(y_t, y_p) {
  mu_x <- mean(y_t, na.rm = TRUE)
  mu_y <- mean(y_p, na.rm = TRUE)
  var_x <- var(y_t, na.rm = TRUE)
  var_y <- var(y_p, na.rm = TRUE)
  cov_xy <- cov(y_t, y_p, use = "complete.obs")
  2 * cov_xy / (var_x + var_y + (mu_x - mu_y)^2)
}

val_rmse <- calc_rmse(obs_vals, pred_vals)
val_mae  <- calc_mae(obs_vals, pred_vals)
val_bias <- calc_bias(obs_vals, pred_vals)
val_r2   <- calc_r2(obs_vals, pred_vals)
val_ccc  <- calc_ccc(obs_vals, pred_vals)

cat("\n------------------------------------------------------------------------------\n")
if (is_en) {
  cat(sprintf("CROSS-VALIDATION METRICS (Property: %s):\n", target_prop))
  cat(sprintf("  R^2:   %.3f\n", val_r2))
  cat(sprintf("  RMSE:  %.3f\n", val_rmse))
  cat(sprintf("  CCC:   %.3f (Lin Concordance)\n", val_ccc))
  cat(sprintf("  MAE:   %.3f\n", val_mae))
  cat(sprintf("  Bias:  %.3f\n", val_bias))
} else {
  cat(sprintf("MÉTRICAS DE VALIDACIÓN CRUZADA (Variable: %s):\n", target_prop))
  cat(sprintf("  R^2:   %.3f\n", val_r2))
  cat(sprintf("  RMSE:  %.3f\n", val_rmse))
  cat(sprintf("  CCC:   %.3f (Concordancia de Lin)\n", val_ccc))
  cat(sprintf("  MAE:   %.3f\n", val_mae))
  cat(sprintf("  Sesgo: %.3f\n", val_bias))
}
cat("------------------------------------------------------------------------------\n\n")

record_decision(3.0, "Evaluación de modelo", sprintf("R^2=%.3f, RMSE=%.3f, CCC=%.3f", val_r2, val_rmse, val_ccc),
                source = "script_default", affected_rows = length(obs_vals), affected_profiles = n_train,
                details = sprintf("CV %dx%d. Mejor mtry=%d, splitrule=%s", cv_folds, cv_repeats, best_tune$mtry, best_tune$splitrule))

# Gráfico 1:1 Observado vs Predicho
scatter_png <- file.path(base_rep_dir, sprintf("scatterplot_%s.png", target_prop))
residuals_df <- tibble(Observed = obs_vals, Predicted = pred_vals)
val_range <- range(c(obs_vals, pred_vals), na.rm = TRUE)

g_scatter <- ggplot(residuals_df, aes(x = Observed, y = Predicted)) +
  geom_point(alpha = 0.35, color = "#2A788EFF") +
  geom_abline(slope = 1, intercept = 0, color = "red", linetype = "dashed", linewidth = 1) +
  coord_fixed(xlim = val_range, ylim = val_range) +
  theme_minimal() +
  labs(
    title = if (is_en) sprintf("Observed vs Predicted in CV - %s", target_prop) else sprintf("Observado vs Predicho en CV - %s", target_prop),
    subtitle = sprintf("R^2 = %.3f | RMSE = %.3f | CCC = %.3f | n = %d", val_r2, val_rmse, val_ccc, n_train),
    x = if (is_en) sprintf("%s Observed", target_prop) else sprintf("%s Observado", target_prop),
    y = if (is_en) sprintf("%s Predicted", target_prop) else sprintf("%s Predicho", target_prop)
  )

ggsave(scatter_png, plot = g_scatter, width = 14, height = 14, units = "cm", dpi = 150)
if (is_en) cat(sprintf("[OK] 1:1 scatter plot saved to: '%s'\n", scatter_png)) else cat(sprintf("[OK] Gráfico 1:1 guardado en: '%s'\n", scatter_png))

# >>> ADAPT:spatial_modelling
# Punto de extensión: inserción de algoritmos adicionales, hiperparámetros o análisis de residuos.
# Objetos disponibles: qrf_model (train), d_train (data.frame), selected_features (character), target_prop (character), record_decision (function)
# <<< ADAPT:spatial_modelling

# 8. Guardar modelo entrenado --------------------------------------------------
model_rds <- file.path(base_out_dir, sprintf("ranger_model_%s.rds", target_prop))
saveRDS(qrf_model, model_rds)
if (is_en) cat(sprintf("[OK] QRF model saved to: '%s'\n", model_rds)) else cat(sprintf("[OK] Modelo QRF guardado en: '%s'\n", model_rds))

# Guardar métricas en JSON para consumo por Paso 5 y reporte automatizado
metrics_json <- file.path(base_out_dir, sprintf("metrics_%s.json", target_prop))
metrics_data <- list(
  property = target_prop,
  n_train = n_train,
  cv_folds = cv_folds,
  cv_repeats = cv_repeats,
  best_tune = as.list(best_tune),
  selected_features = selected_features,
  R2 = val_r2,
  RMSE = val_rmse,
  CCC = val_ccc,
  MAE = val_mae,
  Bias = val_bias
)
if (requireNamespace("jsonlite", quietly = TRUE)) {
  jsonlite::write_json(metrics_data, metrics_json, auto_unbox = TRUE, pretty = TRUE)
  if (is_en) cat(sprintf("[OK] Metrics JSON saved to: '%s'\n", metrics_json)) else cat(sprintf("[OK] Métricas JSON guardadas en: '%s'\n", metrics_json))
}

# 9. Generar reporte complementario .txt ---------------------------------------
rep_con <- file(output_report, open = "wt", encoding = "UTF-8")
writeLines("================================================================================", rep_con)
if (is_en) {
  writeLines("DSM-HARNESS | SPATIAL MODELLING AND CROSS-VALIDATION REPORT (STEP 3)", rep_con)
  writeLines(sprintf("Execution date: %s | Run ID: %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), run_id), rep_con)
  writeLines("================================================================================", rep_con)
  writeLines(sprintf("Target property:                 %s", target_prop), rep_con)
  writeLines(sprintf("Total training profiles:         %d", n_train), rep_con)
  writeLines(sprintf("Initial covariates:              %d", length(cov_cols)), rep_con)
  writeLines(sprintf("Selected covariates:             %d", length(selected_features)), rep_con)
  writeLines("Covariates selected by Boruta:", rep_con)
  for (sf in selected_features) writeLines(sprintf("  - %s", sf), rep_con)
  writeLines("--------------------------------------------------------------------------------", rep_con)
  writeLines("TRAINING AND TUNING CONFIGURATION:", rep_con)
  writeLines("  Algorithm:                     Quantile Regression Forest (ranger)", rep_con)
  writeLines(sprintf("  Validation scheme:             Repeated Cross-Validation (%d folds, %d repeats)", cv_folds, cv_repeats), rep_con)
  writeLines(sprintf("  Best mtry:                     %d", best_tune$mtry), rep_con)
  writeLines(sprintf("  Split rule:                    %s", best_tune$splitrule), rep_con)
  writeLines(sprintf("  min.node.size:                 %d", best_tune$min.node.size), rep_con)
  writeLines("--------------------------------------------------------------------------------", rep_con)
  writeLines("PEDOMETRIC PERFORMANCE METRICS (CROSS-VALIDATION):", rep_con)
  writeLines(sprintf("  R^2 (Determination coefficient): %.4f", val_r2), rep_con)
  writeLines(sprintf("  RMSE (Root mean square error):   %.4f", val_rmse), rep_con)
  writeLines(sprintf("  CCC (Lin concordance):           %.4f", val_ccc), rep_con)
  writeLines(sprintf("  MAE (Mean absolute error):       %.4f", val_mae), rep_con)
  writeLines(sprintf("  Mean bias:                       %.4f", val_bias), rep_con)
} else {
  writeLines("DSM-HARNESS | REPORTE DE MODELADO ESPACIAL Y VALIDACION CRUZADA (PASO 3)", rep_con)
  writeLines(sprintf("Fecha de ejecucion: %s | Run ID: %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), run_id), rep_con)
  writeLines("================================================================================", rep_con)
  writeLines(sprintf("Variable objetivo modelada:      %s", target_prop), rep_con)
  writeLines(sprintf("Total perfiles de entrenamiento: %d", n_train), rep_con)
  writeLines(sprintf("Covariables iniciales:           %d", length(cov_cols)), rep_con)
  writeLines(sprintf("Covariables seleccionadas:       %d", length(selected_features)), rep_con)
  writeLines("Covariables seleccionadas por Boruta:", rep_con)
  for (sf in selected_features) writeLines(sprintf("  - %s", sf), rep_con)
  writeLines("--------------------------------------------------------------------------------", rep_con)
  writeLines("CONFIGURACION DE ENTRENAMIENTO Y AFINACION:", rep_con)
  writeLines("  Algoritmo:                     Quantile Regression Forest (ranger)", rep_con)
  writeLines(sprintf("  Esquema de validacion:         Validacion Cruzada Repetida (%d folds, %d repeticiones)", cv_folds, cv_repeats), rep_con)
  writeLines(sprintf("  Mejor mtry:                    %d", best_tune$mtry), rep_con)
  writeLines(sprintf("  Regla de division (splitrule): %s", best_tune$splitrule), rep_con)
  writeLines(sprintf("  min.node.size:                 %d", best_tune$min.node.size), rep_con)
  writeLines("--------------------------------------------------------------------------------", rep_con)
  writeLines("METRICAS DE RENDIMIENTO PEDOMETRICO (EVALUACION CRUZADA):", rep_con)
  writeLines(sprintf("  R^2 (Coeficiente determinacion): %.4f", val_r2), rep_con)
  writeLines(sprintf("  RMSE (Error cuadratico medio):  %.4f", val_rmse), rep_con)
  writeLines(sprintf("  CCC (Concordancia de Lin):      %.4f", val_ccc), rep_con)
  writeLines(sprintf("  MAE (Error absoluto medio):     %.4f", val_mae), rep_con)
  writeLines(sprintf("  Sesgo medio (Bias):             %.4f", val_bias), rep_con)
}
writeLines("================================================================================", rep_con)
close(rep_con)
if (is_en) cat(sprintf("[OK] Report written to: '%s'\n", output_report)) else cat(sprintf("[OK] Reporte escrito en: '%s'\n", output_report))

# 10. Resumen en consola -------------------------------------------------------
cat("\n==============================================================================\n")
if (is_en) {
  cat("  SPATIAL MODELLING SUMMARY (Step 3)\n")
  cat("==============================================================================\n")
  cat(sprintf("Modelled property:   %s\n", target_prop))
  cat(sprintf("Evaluated profiles:  %d\n", n_train))
  cat(sprintf("Selected covariates: %d of %d\n", length(selected_features), length(cov_cols)))
  cat(sprintf("R^2: %.3f | RMSE: %.3f | CCC: %.3f\n", val_r2, val_rmse, val_ccc))
  cat(sprintf("[OK] Model saved:    %s\n", model_rds))
  cat(sprintf("[OK] Report saved:   %s\n", output_report))
  cat(sprintf("[OK] Plots:          %s and %s\n", basename(boruta_png), basename(scatter_png)))
  if (decision_logged) cat(sprintf("[OK] Decisions log:  %s\n", decisions_log))
  cat("==============================================================================\n\n")
} else {
  cat("  RESUMEN DE MODELADO ESPACIAL (Paso 3)\n")
  cat("==============================================================================\n")
  cat(sprintf("Variable modelada:      %s\n", target_prop))
  cat(sprintf("Perfiles evaluados:     %d\n", n_train))
  cat(sprintf("Covariables elegidas:   %d de %d\n", length(selected_features), length(cov_cols)))
  cat(sprintf("R^2: %.3f | RMSE: %.3f | CCC: %.3f\n", val_r2, val_rmse, val_ccc))
  cat(sprintf("[OK] Modelo guardado:   %s\n", model_rds))
  cat(sprintf("[OK] Reporte guardado:  %s\n", output_report))
  cat(sprintf("[OK] Gráficos:          %s y %s\n", basename(boruta_png), basename(scatter_png)))
  if (decision_logged) cat(sprintf("[OK] Log de decisiones: %s\n", decisions_log))
  cat("==============================================================================\n\n")
}
