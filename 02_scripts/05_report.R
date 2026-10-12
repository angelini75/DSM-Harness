# ==============================================================================
# DSM-Harness v2 | Step 5: Final Evaluation & Mapping Report
# ==============================================================================

# Ensure %||% is available
if (!exists("%||%", mode = "function")) {
  `%||%` <- function(a, b) {
    if (!is.null(a)) a else b
  }
}

# Resolve repository root
if (!exists("repo_root") || is.null(repo_root)) {
  if (exists("find_repo_root", mode = "function")) {
    repo_root <- find_repo_root()
  } else {
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
}

# Load i18n
if (!exists("msg", mode = "function")) {
  i18n_path <- file.path(repo_root, "02_scripts", "i18n", "load_i18n.R")
  if (file.exists(i18n_path)) source(i18n_path, local = FALSE)
}

# Resolve project context
if (!exists("project", inherits = FALSE) || is.null(project)) {
  stop(msg("step_context_missing", "en", "5", "5", repo_root = repo_root), call. = FALSE)
}

if (!exists("proj_root") || is.null(proj_root)) {
  proj_root <- file.path(repo_root, "projects", project)
}

# Load decisions helper
decisions_path <- file.path(repo_root, "R", "decisions.R")
if (file.exists(decisions_path)) source(decisions_path, local = FALSE)

# Load config validator
val_path <- file.path(repo_root, "R", "validate_config.R")
if (file.exists(val_path)) source(val_path, local = FALSE)

# Load config.json
config_file <- file.path(proj_root, "config.json")
if (!file.exists(config_file)) {
  stop(msg("config_missing", "en", config_file, repo_root = repo_root), call. = FALSE)
}

cfg <- jsonlite::fromJSON(config_file, simplifyVector = FALSE)
lang <- cfg$language %||% "en"
project <- cfg$project %||% basename(proj_root)

# Precision 7: Clear message if pandoc is missing
if (!rmarkdown::pandoc_available()) {
  stop(msg("report_pandoc_missing", lang, repo_root = repo_root), call. = FALSE)
}

# Validate config against clean data columns
clean_file <- file.path(proj_root, "data", "03_clean.csv")
data_cols <- NULL
if (file.exists(clean_file)) {
  header_df <- read.csv(clean_file, nrows = 1, check.names = FALSE)
  data_cols <- names(header_df)
}
validate_config(cfg, data_cols = data_cols, stop_on_error = TRUE, repo_root = repo_root, target_cols_only = TRUE)

country_code <- trimws(cfg$country_code %||% "")
project_code <- trimws(cfg$project_code %||% "")

# Configure output directories
maps_dir <- file.path(proj_root, "outputs", "maps")
rep_dir  <- file.path(proj_root, "reports")
if (!dir.exists(rep_dir)) dir.create(rep_dir, recursive = TRUE)

# Determine targets for report generation
configured_targets <- cfg$targets %||% list()
if (length(configured_targets) == 0) {
  stop(msg("report_no_targets", lang, repo_root = repo_root), call. = FALSE)
}

# Build valid target IDs
all_target_specs <- list()
all_target_ids <- character(0)

for (idx in seq_along(configured_targets)) {
  tgt <- configured_targets[[idx]]
  prop <- tgt$property
  d1 <- tgt$d1
  d2 <- tgt$d2
  safe_prop <- make.names(prop)
  d1_str <- gsub("\\.", "_", as.character(d1))
  d2_str <- gsub("\\.", "_", as.character(d2))
  safe_id <- sprintf("%s_%s_%s", safe_prop, d1_str, d2_str)
  alt_id <- sprintf("%s_%s_%s", prop, d1_str, d2_str)
  
  tgt$safe_id <- safe_id
  tgt$alt_id <- alt_id
  tgt$idx <- idx
  
  all_target_specs[[idx]] <- tgt
  all_target_ids <- c(all_target_ids, safe_id)
}

# Filter by runner argument 'targets' if provided
selected_targets <- list()
runner_targets <- if (exists("targets") && !is.null(targets)) targets else NULL

if (!is.null(runner_targets) && length(runner_targets) > 0) {
  for (tgt in all_target_specs) {
    if (tgt$safe_id %in% runner_targets || tgt$alt_id %in% runner_targets || tgt$property %in% runner_targets) {
      selected_targets[[length(selected_targets) + 1]] <- tgt
    }
  }
  if (length(selected_targets) == 0) {
    stop(msg("report_no_matching_targets", lang, paste(runner_targets, collapse = ", "), paste(unique(all_target_ids), collapse = ", "), repo_root = repo_root), call. = FALSE)
  }
} else {
  for (tgt in all_target_specs) {
    is_enabled <- if (is.null(tgt$enabled)) TRUE else isTRUE(tgt$enabled)
    if (is_enabled) {
      selected_targets[[length(selected_targets) + 1]] <- tgt
    }
  }
  if (length(selected_targets) == 0) {
    stop(msg("report_no_targets", lang, repo_root = repo_root), call. = FALSE)
  }
}

refit_flag <- if (exists("refit") && !is.null(refit)) isTRUE(refit) else isTRUE(cfg$refit)

rmd_template <- file.path(repo_root, "02_scripts", "05_variable_report.Rmd")
if (!file.exists(rmd_template)) {
  stop(msg("script_not_found", lang, "5", rmd_template, repo_root = repo_root), call. = FALSE)
}

# Main reporting loop across selected targets
for (tgt in selected_targets) {
  prop <- tgt$property
  d1 <- tgt$d1
  d2 <- tgt$d2
  safe_id <- tgt$safe_id
  
  d1_int <- as.character(d1)
  d2_int <- as.character(d2)
  
  html_file   <- file.path(rep_dir, sprintf("report_%s.html", safe_id))
  report_file <- file.path(rep_dir, sprintf("50_report_%s.txt", safe_id))
  
  # Precision 3: Skip existing reports unless refit
  if (file.exists(html_file) && !refit_flag) {
    cat(sprintf(msg("report_skipping_existing", lang, repo_root = repo_root), safe_id, safe_id), "\n")
    next
  }
  
  # Check prediction maps
  mean_filename <- sprintf("%s-%s-%s-%s-%s-mean.tif", country_code, project_code, toupper(prop), d1_int, d2_int)
  sd_filename   <- sprintf("%s-%s-%s-%s-%s-sd.tif",   country_code, project_code, toupper(prop), d1_int, d2_int)
  mean_path     <- file.path(maps_dir, mean_filename)
  sd_path       <- file.path(maps_dir, sd_filename)
  
  if (!file.exists(mean_path) || !file.exists(sd_path)) {
    stop(msg("report_missing_maps", lang, safe_id, repo_root = repo_root), call. = FALSE)
  }
  
  # Check model and data files
  cov_data_file <- file.path(proj_root, "data", sprintf("04_cov_%s.csv", safe_id))
  model_file    <- file.path(proj_root, "outputs", "models", paste0(safe_id, ".rds"))
  metrics_file  <- file.path(proj_root, "outputs", "models", paste0("metrics_", safe_id, ".json"))
  
  rep_con <- file(report_file, open = "wt", encoding = "UTF-8")
  log_out <- function(txt) {
    cat(txt, "\n")
    cat(txt, "\n", file = rep_con)
  }
  
  log_out(msg("report_header", lang, repo_root = repo_root))
  log_out(sprintf(msg("report_date", lang, repo_root = repo_root), format(Sys.time(), "%Y-%m-%d %H:%M:%S")))
  log_out(sprintf(msg("report_project", lang, repo_root = repo_root), project))
  log_out(sprintf(msg("report_target_header", lang, repo_root = repo_root), prop, d1, d2))
  
  t_start <- proc.time()
  log_out(sprintf(msg("report_rendering", lang, repo_root = repo_root), safe_id))
  
  # Report title from catalogue
  report_title <- sprintf(msg("rmd_title", lang, repo_root = repo_root), prop, as.numeric(d1), as.numeric(d2))
  
  rmd_params <- list(
    report_title = report_title,
    project = project,
    lang = lang,
    repo_root = repo_root,
    proj_root = proj_root,
    target_id = safe_id,
    property = prop,
    d1 = d1,
    d2 = d2,
    country_code = country_code,
    project_code = project_code,
    cov_data_path = cov_data_file,
    model_path = model_file,
    metrics_path = metrics_file,
    mean_map_path = mean_path,
    sd_map_path = sd_path
  )
  
  # Render in isolated environment
  rmarkdown::render(
    input = rmd_template,
    output_file = html_file,
    params = rmd_params,
    quiet = TRUE,
    envir = new.env(parent = globalenv())
  )
  
  elapsed_sec <- as.numeric((proc.time() - t_start)["elapsed"])
  log_out(sprintf(msg("report_target_completed", lang, repo_root = repo_root), safe_id, elapsed_sec))
  
  log_out("================================================================================")
  log_out(sprintf(msg("report_saved", lang, repo_root = repo_root), html_file, report_file))
  close(rep_con)
  
  # Audit log
  record_decision(
    project = project,
    step = "5",
    decision = sprintf("Final evaluation HTML report generated for target %s: %s", safe_id, basename(html_file)),
    details = sprintf("Report HTML: %s; Diagnostic: %s", html_file, report_file),
    repo_root = repo_root
  )
}

cat(msg("report_all_completed", lang, repo_root = repo_root), "\n")
