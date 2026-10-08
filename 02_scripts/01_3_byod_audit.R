# ==============================================================================
# DSM-Harness v2 | 02_scripts/01_3_byod_audit.R
# Step 1.3: Depths Validation, Pedological Coherence & Bulk Density PTF Modeling
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

if (!exists("project", inherits = FALSE) || is.null(project)) {
  stop("Step 1.3 must be run within a project context (e.g., run_step('1.3', project = 'myproj'))")
}

proj_root <- file.path(repo_root, "projects", project)
data_dir <- file.path(proj_root, "data")
reports_dir <- file.path(proj_root, "reports")
if (!dir.exists(data_dir)) dir.create(data_dir, recursive = TRUE)
if (!dir.exists(reports_dir)) dir.create(reports_dir, recursive = TRUE)

config_path <- file.path(proj_root, "config.json")
if (!file.exists(config_path)) {
  stop(msg("config_missing", "en", config_path, repo_root = repo_root), call. = FALSE)
}

if (!exists("cfg", inherits = FALSE) || is.null(cfg)) {
  cfg <- jsonlite::fromJSON(config_path, simplifyVector = FALSE)
}
lang <- cfg$language %||% "en"

is_str <- function(x) {
  if (is.null(x) || length(x) == 0) return(FALSE)
  ch <- as.character(x)[1]
  !is.na(ch) && nzchar(ch)
}

# Verify that Step 1.2 output exists
in_csv <- file.path(data_dir, "02_spatial.csv")
if (!file.exists(in_csv)) {
  err_msg <- msg("step_missing_input", lang, "1.3", "data/02_spatial.csv", "1.2", repo_root = repo_root)
  stop(err_msg, call. = FALSE)
}

df <- as.data.frame(readr::read_csv(in_csv, show_col_types = FALSE))
n_initial <- nrow(df)

# Depths validation
top_col <- if (is_str(cfg$roles$top)) as.character(cfg$roles$top) else "top"
bottom_col <- if (is_str(cfg$roles$bottom)) as.character(cfg$roles$bottom) else "bottom"

if (!top_col %in% names(df) || !bottom_col %in% names(df)) {
  stop(sprintf("Depth columns '%s' and/or '%s' not found in dataset.", top_col, bottom_col), call. = FALSE)
}

df[[top_col]] <- as.numeric(df[[top_col]])
df[[bottom_col]] <- as.numeric(df[[bottom_col]])

# Fix inverted depths if top > bottom
inverted_mask <- !is.na(df[[top_col]]) & !is.na(df[[bottom_col]]) & (df[[top_col]] > df[[bottom_col]])
n_inverted <- sum(inverted_mask)
if (n_inverted > 0) {
  tmp_top <- df[[top_col]][inverted_mask]
  df[[top_col]][inverted_mask] <- df[[bottom_col]][inverted_mask]
  df[[bottom_col]][inverted_mask] <- tmp_top
}

# Check invalid intervals: top < 0 or bottom <= top
invalid_mask <- is.na(df[[top_col]]) | is.na(df[[bottom_col]]) | (df[[top_col]] < 0) | (df[[bottom_col]] <= df[[top_col]])
n_invalid <- sum(invalid_mask)

# Filter valid horizons
df_valid <- df[!invalid_mask, , drop = FALSE]

report_path <- file.path(reports_dir, "13_pedological.txt")
rep_con <- file(report_path, open = "wt", encoding = "UTF-8")

log_out <- function(...) {
  line <- paste0(...)
  cat(line, "\n")
  cat(line, "\n", file = rep_con)
}

log_out("================================================================================")
log_out("  DSM-HARNESS: STEP 1.3 PEDOLOGICAL AUDIT & BULK DENSITY MODELING")
log_out("================================================================================")
log_out("Date: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"))
log_out("Project: ", project)
log_out("Input File: data/02_spatial.csv")
log_out("Total input records: ", n_initial)
log_out("Inverted depths swapped: ", n_inverted)
log_out("Invalid depth intervals omitted: ", n_invalid)
log_out("Valid horizons retained: ", nrow(df_valid))
log_out("================================================================================\n")

# PTF Reference Functions
calc_reference_ptfs <- function(om_vec) {
  res <- list()
  if (is.null(om_vec) || sum(!is.na(om_vec)) == 0) return(res)
  
  om_c <- pmin(pmax(om_vec, 0.01), 70)
  
  res[["Saini (1996)"]] <- list(
    name = "Saini (1996)",
    formula = "1.62 - 0.06 * OM",
    pred = round(pmax(pmin(1.62 - 0.06 * om_c, 2.65), 0.2), 3)
  )
  res[["Drew (1973)"]] <- list(
    name = "Drew (1973)",
    formula = "1 / (0.6268 + 0.0361 * OM)",
    pred = round(pmax(pmin(1 / (0.6268 + 0.0361 * om_c), 2.65), 0.2), 3)
  )
  res[["Jeffrey (1979)"]] <- list(
    name = "Jeffrey (1979)",
    formula = "1.482 - 0.6786 * ln(OM)",
    pred = round(pmax(pmin(1.482 - 0.6786 * log(om_c), 2.65), 0.2), 3)
  )
  res[["Grigal (1989)"]] <- list(
    name = "Grigal (1989)",
    formula = "0.669 + 0.941 * exp(-0.06 * OM)",
    pred = round(pmax(pmin(0.669 + 0.941 * exp(-0.06 * om_c), 2.65), 0.2), 3)
  )
  res[["Adams (1973)"]] <- list(
    name = "Adams (1973)",
    formula = "100 / (OM/0.244 + (100-OM)/2.65)",
    pred = round(pmax(pmin(100 / ((om_c / 0.244) + ((100 - om_c) / 2.65)), 2.65), 0.2), 3)
  )
  res[["Honeyset & Ratkowsky (1989)"]] <- list(
    name = "Honeyset & Ratkowsky (1989)",
    formula = "1 / (0.564 + 0.0556 * OM)",
    pred = round(pmax(pmin(1 / (0.564 + 0.0556 * om_c), 2.65), 0.2), 3)
  )
  res
}

fit_local_models <- function(df_val, om_full) {
  om_full_c <- pmin(pmax(om_full, 0.01), 70)
  val_om_c  <- pmin(pmax(df_val$OM, 0.01), 70)
  val_bd    <- df_val$BD
  
  candidates <- list()
  
  # Linear: BD ~ OM
  m1 <- tryCatch(stats::lm(val_bd ~ val_om_c), error = function(e) NULL)
  if (!is.null(m1)) {
    cf <- stats::coef(m1)
    sign_b <- ifelse(cf[2] >= 0, "+", "-")
    f_str <- sprintf("%.3f %s %.4f*OM", cf[1], sign_b, abs(cf[2]))
    p_val <- pmax(pmin(stats::predict(m1, newdata = data.frame(val_om_c = val_om_c)), 2.65), 0.2)
    p_all <- round(pmax(pmin(stats::predict(m1, newdata = data.frame(val_om_c = om_full_c)), 2.65), 0.2), 3)
    candidates[["Linear"]] <- list(formula = f_str, pred_val = p_val, pred_all = p_all)
  }
  
  # Logarithmic: BD ~ ln(OM)
  m2 <- tryCatch(stats::lm(val_bd ~ log(val_om_c)), error = function(e) NULL)
  if (!is.null(m2)) {
    cf <- stats::coef(m2)
    sign_b <- ifelse(cf[2] >= 0, "+", "-")
    f_str <- sprintf("%.3f %s %.4f*ln(OM)", cf[1], sign_b, abs(cf[2]))
    p_val <- pmax(pmin(stats::predict(m2, newdata = data.frame(val_om_c = val_om_c)), 2.65), 0.2)
    p_all <- round(pmax(pmin(stats::predict(m2, newdata = data.frame(val_om_c = om_full_c)), 2.65), 0.2), 3)
    candidates[["Logarithmic"]] <- list(formula = f_str, pred_val = p_val, pred_all = p_all)
  }
  
  # Reciprocal: 1/BD ~ OM
  m3 <- tryCatch(stats::lm(I(1 / val_bd) ~ val_om_c), error = function(e) NULL)
  if (!is.null(m3)) {
    cf <- stats::coef(m3)
    sign_b <- ifelse(cf[2] >= 0, "+", "-")
    f_str <- sprintf("1 / (%.4f %s %.4f*OM)", cf[1], sign_b, abs(cf[2]))
    pred_inv_val <- stats::predict(m3, newdata = data.frame(val_om_c = val_om_c))
    p_val <- pmax(pmin(ifelse(pred_inv_val > 0, 1 / pred_inv_val, 2.65), 2.65), 0.2)
    pred_inv_all <- stats::predict(m3, newdata = data.frame(val_om_c = om_full_c))
    p_all <- round(pmax(pmin(ifelse(pred_inv_all > 0, 1 / pred_inv_all, 2.65), 2.65), 0.2), 3)
    candidates[["Reciprocal"]] <- list(formula = f_str, pred_val = p_val, pred_all = p_all)
  }
  
  # Exponential: ln(BD) ~ OM
  m4 <- tryCatch(stats::lm(log(val_bd) ~ val_om_c), error = function(e) NULL)
  if (!is.null(m4)) {
    cf <- stats::coef(m4)
    sign_b <- ifelse(cf[2] >= 0, "+", "-")
    f_str <- sprintf("%.4f * exp(%s%.4f*OM)", exp(cf[1]), ifelse(cf[2] >= 0, "", "-"), abs(cf[2]))
    pred_log_val <- stats::predict(m4, newdata = data.frame(val_om_c = val_om_c))
    p_val <- pmax(pmin(exp(pred_log_val), 2.65), 0.2)
    pred_log_all <- stats::predict(m4, newdata = data.frame(val_om_c = om_full_c))
    p_all <- round(pmax(pmin(exp(pred_log_all), 2.65), 0.2), 3)
    candidates[["Exponential"]] <- list(formula = f_str, pred_val = p_val, pred_all = p_all)
  }
  
  if (length(candidates) == 0) return(NULL)
  
  rmse_list <- sapply(candidates, function(cand) sqrt(mean((val_bd - cand$pred_val)^2)))
  best_name <- names(which.min(rmse_list))
  best_cand <- candidates[[best_name]]
  
  list(
    name = paste("Simple local fit (", best_name, ")", sep = ""),
    formula = best_cand$formula,
    pred_val = best_cand$pred_val,
    pred_all = best_cand$pred_all
  )
}

# Determine Bulk Density and Organic Matter columns
bd_col <- if (is_str(cfg$roles$bulk_density)) as.character(cfg$roles$bulk_density) else NULL
soc_col <- if (is_str(cfg$roles$organic_carbon)) as.character(cfg$roles$organic_carbon) else NULL
om_col <- if (is_str(cfg$roles$organic_matter)) as.character(cfg$roles$organic_matter) else NULL

has_bd <- !is.null(bd_col) && (bd_col %in% names(df_valid))
has_soc <- !is.null(soc_col) && (soc_col %in% names(df_valid))
has_om <- !is.null(om_col) && (om_col %in% names(df_valid))

# Derive OM vector
om_vec <- NULL
if (has_om) {
  om_vec <- as.numeric(df_valid[[om_col]])
} else if (has_soc) {
  # van Bemmelen factor
  om_vec <- as.numeric(df_valid[[soc_col]]) * 1.724
}

ptf_catalogue <- NULL
local_fit_res <- NULL
chosen_ptf_pred <- NULL
chosen_ptf_name <- NULL

if (!is.null(om_vec) && sum(!is.na(om_vec)) > 0) {
  ptf_catalogue <- calc_reference_ptfs(om_vec)
}

log_out("--- BULK DENSITY (BD) CONTRAST & PTF EVALUATION ---")

eval_table <- data.frame(
  PTF = character(0),
  n_val = integer(0),
  R2 = numeric(0),
  RMSE = numeric(0),
  Bias = numeric(0),
  stringsAsFactors = FALSE
)

if (has_bd && !is.null(om_vec)) {
  bd_vec <- as.numeric(df_valid[[bd_col]])
  val_mask <- !is.na(bd_vec) & (bd_vec >= 0.2) & (bd_vec <= 2.65) & !is.na(om_vec) & (om_vec > 0)
  n_val <- sum(val_mask)
  
  log_out(sprintf("Valid paired observations (measured BD and OM): n = %d", n_val))
  
  if (n_val > 0 && !is.null(ptf_catalogue)) {
    for (p_name in names(ptf_catalogue)) {
      pred_sub <- ptf_catalogue[[p_name]]$pred[val_mask]
      obs_sub <- bd_vec[val_mask]
      
      rmse <- sqrt(mean((obs_sub - pred_sub)^2))
      bias <- mean(pred_sub - obs_sub)
      r2 <- max(0, stats::cor(obs_sub, pred_sub)^2, na.rm = TRUE)
      
      eval_table <- rbind(eval_table, data.frame(
        PTF = p_name,
        n_val = n_val,
        R2 = round(r2, 3),
        RMSE = round(rmse, 3),
        Bias = round(bias, 3),
        stringsAsFactors = FALSE
      ))
    }
  }
  
  # Local fit evaluation if n >= threshold (default 30)
  local_threshold <- 30
  if (n_val >= local_threshold) {
    df_val_sub <- data.frame(BD = bd_vec[val_mask], OM = om_vec[val_mask])
    local_fit_res <- fit_local_models(df_val_sub, om_vec)
    
    if (!is.null(local_fit_res)) {
      rmse_loc <- sqrt(mean((bd_vec[val_mask] - local_fit_res$pred_val)^2))
      bias_loc <- mean(local_fit_res$pred_val - bd_vec[val_mask])
      r2_loc <- max(0, stats::cor(bd_vec[val_mask], local_fit_res$pred_val)^2, na.rm = TRUE)
      
      eval_table <- rbind(eval_table, data.frame(
        PTF = local_fit_res$name,
        n_val = n_val,
        R2 = round(r2_loc, 3),
        RMSE = round(rmse_loc, 3),
        Bias = round(bias_loc, 3),
        stringsAsFactors = FALSE
      ))
    }
  } else {
    log_out(msg("ped_bd_no_local", lang, n_val, local_threshold, repo_root = repo_root))
  }
} else {
  log_out("No measured BD column or OM/SOC available for contrast.")
}

# Print evaluation table to report
if (nrow(eval_table) > 0) {
  log_out("\n", msg("ped_bd_catalogue", lang, repo_root = repo_root))
  log_out(sprintf("%-32s | %-6s | %-6s | %-12s | %-12s", "PTF / Model", "n val", "R2", "RMSE (g/cm3)", "Bias (g/cm3)"))
  log_out(paste(rep("-", 76), collapse = ""))
  for (i in seq_len(nrow(eval_table))) {
    log_out(sprintf("%-32s | %-6d | %-6.3f | %-12.3f | %-+12.3f",
                    eval_table$PTF[i], eval_table$n_val[i],
                    eval_table$R2[i], eval_table$RMSE[i], eval_table$Bias[i]))
  }
  log_out("")
  
  # Pick best model based on minimum RMSE
  best_idx <- which.min(eval_table$RMSE)
  chosen_ptf_name <- eval_table$PTF[best_idx]
  if (!is.null(local_fit_res) && chosen_ptf_name == local_fit_res$name) {
    chosen_ptf_pred <- local_fit_res$pred_all
  } else if (!is.null(ptf_catalogue) && chosen_ptf_name %in% names(ptf_catalogue)) {
    chosen_ptf_pred <- ptf_catalogue[[chosen_ptf_name]]$pred
  }
} else if (!is.null(ptf_catalogue)) {
  chosen_ptf_name <- "Saini (1996)"
  chosen_ptf_pred <- ptf_catalogue[[chosen_ptf_name]]$pred
  log_out(sprintf("No measured BD available. Default reference PTF: %s", chosen_ptf_name))
}

# Imputation Decision
impute_req <- isTRUE(cfg$impute_bulk_density)

if (impute_req && !is.null(chosen_ptf_pred)) {
  # Impute only into separate column bd_imputed, NEVER overwrite original
  df_valid$bd_imputed <- chosen_ptf_pred
  n_imputed <- sum(!is.na(chosen_ptf_pred))
  log_out(sprintf("\n[IMPUTATION APPLIED] %s", msg("ped_bd_imputed", lang, chosen_ptf_name, repo_root = repo_root)))
  log_out(sprintf("Populated 'bd_imputed' with %d values.", n_imputed))
} else {
  log_out(sprintf("\n[NOTICE] %s", msg("ped_bd_not_imputed", lang, repo_root = repo_root)))
}

out_csv <- file.path(data_dir, "03_clean.csv")
readr::write_csv(df_valid, out_csv)

close(rep_con)

record_decision(
  project = project,
  step = "1.3",
  decision = "Pedological validation and bulk density modeling",
  details = sprintf("Retained %d horizons. Impute BD: %s. Output: data/03_clean.csv", nrow(df_valid), impute_req),
  repo_root = repo_root
)

cat(msg("ped_complete", lang, out_csv, report_path, repo_root = repo_root), "\n")
