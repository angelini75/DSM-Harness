# ==============================================================================
# DSM-Harness v2 | 02_scripts/03_model.R
# Step 3: Feature Selection (Boruta) & Quantile Regression Forest (QRF)
# ==============================================================================

# Ensure repo_root and proj_root are set
if (!exists("repo_root", inherits = FALSE)) {
  find_root <- function(d = getwd()) {
    curr <- normalizePath(d, winslash = "/", mustWork = FALSE)
    while (nchar(curr) > 0 && dirname(curr) != curr) {
      if (file.exists(file.path(curr, "DSM-Harness.Rproj"))) return(curr)
      curr <- dirname(curr)
    }
    normalizePath(d, winslash = "/", mustWork = FALSE)
  }
  repo_root <- find_root()
}

if (!exists("msg", mode = "function")) {
  source(file.path(repo_root, "02_scripts", "i18n", "load_i18n.R"), local = FALSE)
}
if (!exists("record_decision", mode = "function")) {
  source(file.path(repo_root, "R", "decisions.R"), local = FALSE)
}
if (!exists("validate_config", mode = "function")) {
  source(file.path(repo_root, "R", "validate_config.R"), local = FALSE)
}
if (!exists("get_target_id", mode = "function")) {
  source(file.path(repo_root, "R", "targets.R"), local = FALSE)
}

if (!exists("project", inherits = FALSE) || is.null(project)) {
  stop(msg("step_context_missing", "en", "3", "3", repo_root = repo_root), call. = FALSE)
}

proj_root <- file.path(repo_root, "projects", project)
data_dir <- file.path(proj_root, "data")
reports_dir <- file.path(proj_root, "reports")
models_dir <- file.path(proj_root, "outputs", "models")
cov_dir <- file.path(proj_root, "covariates")

if (!dir.exists(reports_dir)) dir.create(reports_dir, recursive = TRUE)
if (!dir.exists(models_dir)) dir.create(models_dir, recursive = TRUE)

config_path <- file.path(proj_root, "config.json")
if (!file.exists(config_path)) {
  stop(msg("config_missing", "en", config_path, repo_root = repo_root), call. = FALSE)
}

if (!exists("cfg", inherits = FALSE) || is.null(cfg)) {
  cfg <- jsonlite::fromJSON(config_path, simplifyVector = FALSE)
}
lang <- cfg$language %||% "en"

# Validate configuration
clean_csv <- file.path(data_dir, "03_clean.csv")
if (file.exists(clean_csv)) {
  clean_cols <- names(readr::read_csv(clean_csv, n_max = 1, show_col_types = FALSE))
  validate_config(cfg, data_cols = clean_cols, stop_on_error = TRUE, repo_root = repo_root, target_cols_only = TRUE)
} else {
  validate_config(cfg, stop_on_error = TRUE, repo_root = repo_root)
}

# Targets selection
all_targets <- cfg$targets
if (is.null(all_targets) || length(all_targets) == 0) {
  stop(msg("model_no_targets", lang, repo_root = repo_root), call. = FALSE)
}

valid_target_ids <- character(0)
for (tgt in all_targets) {
  tid <- get_target_id(tgt$property, tgt$d1, tgt$d2)
  valid_target_ids <- c(valid_target_ids, tid)
}

filter_targets <- NULL
if (exists("targets", inherits = FALSE) && !is.null(targets)) {
  filter_targets <- as.character(targets)
}

if (!is.null(filter_targets)) {
  matching_indices <- which(sapply(all_targets, function(tgt) {
    p <- as.character(tgt$property)
    sp <- gsub("[^A-Za-z0-9_-]", "_", p)
    tid <- get_target_id(tgt$property, tgt$d1, tgt$d2)
    (p %in% filter_targets) || (sp %in% filter_targets) || (tid %in% filter_targets)
  }))
  if (length(matching_indices) == 0) {
    err_msg <- msg(
      "model_no_matching_targets", lang,
      paste(filter_targets, collapse = ", "),
      paste(valid_target_ids, collapse = ", "),
      repo_root = repo_root
    )
    stop(err_msg, call. = FALSE)
  }
} else {
  matching_indices <- which(sapply(all_targets, function(tgt) isTRUE(tgt$enabled %||% TRUE)))
  if (length(matching_indices) == 0) {
    stop(msg("model_no_targets", lang, repo_root = repo_root), call. = FALSE)
  }
}

refit_flag <- isTRUE(if (exists("refit", inherits = FALSE)) refit else cfg$refit %||% FALSE)

# 1. Discover covariate raster layer names for strict predictor validation
cov_files <- list.files(cov_dir, pattern = "\\.tif$", full.names = TRUE, ignore.case = TRUE)
raster_layer_names <- character(0)
if (length(cov_files) > 0) {
  cov_stack <- terra::rast(cov_files)
  raster_layer_names <- make.unique(names(cov_stack))
}

# 2. Evaluation metrics helper
calc_accuracy <- function(pred, obs) {
  n <- length(obs)
  sdx <- sd(pred, na.rm = TRUE)
  sdy <- sd(obs, na.rm = TRUE)
  r <- stats::cor(pred, obs, method = "pearson", use = "pairwise.complete.obs")
  v <- sdx / sdy
  sx2 <- var(pred, na.rm = TRUE) * (n - 1) / n
  sy2 <- var(obs, na.rm = TRUE) * (n - 1) / n
  u <- (mean(pred, na.rm = TRUE) - mean(obs, na.rm = TRUE)) / ((sx2 * sy2)^0.25)
  Cb <- ((v + 1 / v + u^2) / 2)^-1
  rhoC <- r * Cb
  
  sse <- sum((obs - pred)^2, na.rm = TRUE)
  sst <- sum((obs - mean(obs, na.rm = TRUE))^2, na.rm = TRUE)
  mec <- if (sst > 0) 1 - (sse / sst) else NA_real_
  
  list(
    ME = round(mean(pred - obs, na.rm = TRUE), 4),
    MAE = round(mean(abs(pred - obs), na.rm = TRUE), 4),
    RMSE = round(sqrt(mean((pred - obs)^2, na.rm = TRUE)), 4),
    r = round(r, 4),
    r2 = round(r^2, 4),
    MEC = round(mec, 4),
    rhoC = round(rhoC, 4),
    Cb = round(Cb, 4)
  )
}

processed_count <- 0

for (idx in seq_along(all_targets)) {
  if (!(idx %in% matching_indices)) {
    next
  }
  
  tgt <- all_targets[[idx]]
  prop <- as.character(tgt$property)
  d1 <- as.numeric(tgt$d1)
  d2 <- as.numeric(tgt$d2)
  
  safe_prop <- gsub("[^A-Za-z0-9_-]", "_", prop)
  target_id <- get_target_id(prop, d1, d2)
  
  model_file <- file.path(models_dir, sprintf("%s.rds", target_id))
  metrics_file <- file.path(models_dir, sprintf("metrics_%s.json", target_id))
  report_file <- file.path(reports_dir, sprintf("30_modelling_%s.txt", target_id))
  
  # Skip existing model unless refit requested
  if (file.exists(model_file) && !refit_flag) {
    cat(msg("model_skipping_existing", lang, model_file, prop, repo_root = repo_root), "\n")
    next
  }
  
  in_csv <- file.path(data_dir, sprintf("04_cov_%s.csv", target_id))
  if (!file.exists(in_csv)) {
    err_msg <- msg("model_input_not_found", lang, prop, in_csv, repo_root = repo_root)
    stop(err_msg, call. = FALSE)
  }
  
  dat_cov <- as.data.frame(readr::read_csv(in_csv, show_col_types = FALSE))
  
  # Strict separation: predictors are exclusively covariate raster layers
  metadata_cols <- c("profile_id", "x", "y")
  candidate_preds <- setdiff(names(dat_cov), c(metadata_cols, prop))
  
  if (length(raster_layer_names) > 0) {
    invalid_preds <- setdiff(candidate_preds, raster_layer_names)
    if (length(invalid_preds) > 0) {
      err_msg <- msg("model_non_raster_predictor_detected", lang, paste(invalid_preds, collapse = ", "), repo_root = repo_root)
      stop(err_msg, call. = FALSE)
    }
  }
  
  rep_con <- file(report_file, open = "wt", encoding = "UTF-8")
  log_out <- function(...) {
    line <- paste0(...)
    cat(line, "\n")
    cat(line, "\n", file = rep_con)
  }
  
  log_out("================================================================================")
  log_out(msg("model_header", lang, repo_root = repo_root))
  log_out("================================================================================")
  log_out(msg("model_date", lang, format(Sys.time(), "%Y-%m-%d %H:%M:%S"), repo_root = repo_root))
  log_out(msg("model_project", lang, project, repo_root = repo_root))
  log_out(msg("model_target_header", lang, prop, d1, d2, repo_root = repo_root))
  log_out(msg("model_predictors_count", lang, length(candidate_preds), repo_root = repo_root))
  
  # Training dataset preparation
  d <- dat_cov[, c(prop, candidate_preds), drop = FALSE]
  d <- na.omit(d)
  log_out(msg("model_training_rows", lang, nrow(d), repo_root = repo_root))
  
  # Feature selection with Boruta
  max_runs <- as.integer(cfg$boruta_max_runs %||% 100)
  log_out(msg("model_boruta_start", lang, max_runs, repo_root = repo_root))
  
  set.seed(1)
  boruta_res <- Boruta::Boruta(
    y = d[[prop]],
    x = d[, candidate_preds, drop = FALSE],
    maxRuns = max_runs,
    doTrace = 0
  )
  
  decisions <- boruta_res$finalDecision
  n_confirmed <- sum(decisions == "Confirmed")
  n_tentative <- sum(decisions == "Tentative")
  n_rejected <- sum(decisions == "Rejected")
  log_out(msg("model_boruta_decisions", lang, n_confirmed, n_tentative, n_rejected, repo_root = repo_root))
  
  selected_features <- Boruta::getSelectedAttributes(boruta_res, withTentative = TRUE)
  if (length(selected_features) == 0) {
    log_out(msg("model_boruta_none_fallback", lang, length(candidate_preds), repo_root = repo_root))
    selected_features <- candidate_preds
  } else {
    log_out(msg("model_boruta_features", lang, length(selected_features), paste(selected_features, collapse = ", "), repo_root = repo_root))
  }
  
  # Quantile Regression Forest training
  log_out(msg("model_qrf_start", lang, repo_root = repo_root))
  
  cv_folds <- as.integer(cfg$cv_folds %||% 5)
  cv_repeats <- as.integer(cfg$cv_repeats %||% 5)
  cv_control <- caret::trainControl(
    method = "repeatedcv",
    number = cv_folds,
    repeats = cv_repeats,
    savePredictions = TRUE
  )
  
  mtry_base <- max(1, round(length(selected_features) / 3))
  mtry_candidates <- unique(pmax(1, pmin(length(selected_features), c(
    mtry_base - round(mtry_base / 2),
    mtry_base,
    mtry_base + round(mtry_base / 2)
  ))))
  
  tune_grid <- expand.grid(
    mtry = mtry_candidates,
    min.node.size = 5,
    splitrule = c("variance", "extratrees")
  )
  
  num_threads <- if (!is.null(cfg$cores) && is.numeric(cfg$cores) && cfg$cores >= 1) {
    as.integer(cfg$cores)
  } else {
    max(1, parallel::detectCores() - 1)
  }
  
  t_start <- proc.time()
  model <- suppressWarnings(caret::train(
    y = d[[prop]],
    x = d[, selected_features, drop = FALSE],
    method = "ranger",
    quantreg = TRUE,
    importance = "permutation",
    trControl = cv_control,
    tuneGrid = tune_grid,
    num.threads = num_threads
  ))
  elapsed_sec <- as.numeric((proc.time() - t_start)["elapsed"])
  
  log_out(msg("model_cores_time", lang, num_threads, elapsed_sec, repo_root = repo_root))
  
  best_tune <- model$bestTune
  log_out(msg("model_best_tune", lang, best_tune$mtry, best_tune$splitrule, best_tune$min.node.size, repo_root = repo_root))
  
  # Validation predictions and accuracy metrics
  cv_preds <- model$pred[
    model$pred$mtry == best_tune$mtry &
    model$pred$splitrule == best_tune$splitrule &
    model$pred$min.node.size == best_tune$min.node.size, , drop = FALSE
  ]
  
  metrics <- calc_accuracy(cv_preds$pred, cv_preds$obs)
  
  log_out(msg("model_metrics_header", lang, repo_root = repo_root))
  log_out(msg("model_metrics_table", lang, metrics$ME, metrics$MAE, metrics$RMSE, metrics$r2, metrics$MEC, metrics$rhoC, metrics$Cb, repo_root = repo_root))
  
  # Enrich metrics with model facts (Precision 3)
  metrics$training_rows <- nrow(d)
  metrics$boruta_confirmed <- as.integer(n_confirmed)
  metrics$boruta_tentative <- as.integer(n_tentative)
  metrics$boruta_rejected <- as.integer(n_rejected)
  metrics$hyperparameters <- list(
    mtry = as.integer(best_tune$mtry),
    splitrule = as.character(best_tune$splitrule),
    min_node_size = as.integer(best_tune$min.node.size)
  )
  metrics$cores_used <- as.integer(num_threads)
  metrics$elapsed_seconds <- round(elapsed_sec, 2)
  metrics$algorithm <- "Quantile Regression Forest (ranger)"

  # Save fitted model & metrics JSON
  saveRDS(model, model_file)
  jsonlite::write_json(metrics, metrics_file, auto_unbox = TRUE, pretty = TRUE)
  
  log_out("================================================================================")
  log_out(msg("model_saved", lang, model_file, metrics_file, report_file, repo_root = repo_root))
  close(rep_con)
  
  record_decision(
    project = project,
    step = "3",
    decision = sprintf("QRF model fitted for target '%s' [%.0f, %.0f] cm", prop, d1, d2),
    details = sprintf("Selected %d features (%s). 5x5 CV: RMSE=%.4f, R2=%.4f, MEC=%.4f. Threads=%d, Time=%.2fs. Written %s",
                      length(selected_features), paste(selected_features, collapse = ", "),
                      metrics$RMSE, metrics$r2, metrics$MEC, num_threads, elapsed_sec, model_file),
    repo_root = repo_root
  )
  
  processed_count <- processed_count + 1
}

cat(msg("model_all_completed", lang, repo_root = repo_root), "\n")
