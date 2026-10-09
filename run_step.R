# ==============================================================================
# DSM-Harness v2 | run_step.R
# Main runner for DSM-Harness pipeline steps
# ==============================================================================

# Ensure %||% is available
if (!exists("%||%", mode = "function")) {
  `%||%` <- function(a, b) {
    if (!is.null(a)) a else b
  }
}

find_repo_root <- function(start_dir = getwd()) {
  curr <- normalizePath(start_dir, winslash = "/", mustWork = FALSE)
  while (nchar(curr) > 0 && dirname(curr) != curr) {
    if (file.exists(file.path(curr, "DSM-Harness.Rproj"))) {
      return(curr)
    }
    curr <- dirname(curr)
  }
  normalizePath(start_dir, winslash = "/", mustWork = FALSE)
}

# Helper to load i18n
.ensure_i18n <- function(repo_root) {
  if (!exists("msg", mode = "function")) {
    i18n_path <- file.path(repo_root, "02_scripts", "i18n", "load_i18n.R")
    if (file.exists(i18n_path)) {
      source(i18n_path, local = FALSE)
    }
  }
}

# Step to script mapping
.step_to_script <- function(step) {
  step_str <- as.character(step)
  mapping <- list(
    "0"   = "00_inspect_data.R",
    "00"  = "00_inspect_data.R",
    "1.1" = "01_1_byod_audit.R",
    "01_1"= "01_1_byod_audit.R",
    "1.2" = "01_2_byod_audit.R",
    "01_2"= "01_2_byod_audit.R",
    "1.3" = "01_3_byod_audit.R",
    "01_3"= "01_3_byod_audit.R"
  )
  mapping[[step_str]]
}

new_project <- function(name, language = "en", repo_root = NULL) {
  if (missing(name) || !nzchar(name)) {
    cat("[ERROR] Project name must be provided: new_project(\"my_project\", language = \"en\")\n")
    return(invisible(FALSE))
  }
  
  if (is.null(repo_root)) {
    repo_root <- find_repo_root()
  }
  .ensure_i18n(repo_root)
  
  lang <- if (language %in% c("en", "es")) language else "en"
  
  proj_dir <- file.path(repo_root, "projects", name)
  dirs_to_create <- c(
    file.path(proj_dir, "data"),
    file.path(proj_dir, "reports"),
    file.path(proj_dir, "covariates"),
    file.path(proj_dir, "outputs"),
    file.path(proj_dir, "custom")
  )
  
  for (d in dirs_to_create) {
    if (!dir.exists(d)) {
      dir.create(d, recursive = TRUE)
    }
  }
  
  # Initialize minimal config.json if not present
  config_path <- file.path(proj_dir, "config.json")
  if (!file.exists(config_path)) {
    initial_cfg <- list(
      project = name,
      language = lang
    )
    jsonlite::write_json(initial_cfg, config_path, auto_unbox = TRUE, pretty = TRUE)
  }
  
  info_msg <- if (lang == "es") {
    sprintf("[INFO] Proyecto '%s' inicializado (idioma: %s) en: %s", name, lang, proj_dir)
  } else {
    sprintf("[INFO] Project '%s' initialized (language: %s) at: %s", name, lang, proj_dir)
  }
  cat(info_msg, "\n")
  invisible(TRUE)
}

run_step <- function(step, project) {
  repo_root <- find_repo_root()
  .ensure_i18n(repo_root)
  
  default_lang <- "en"
  
  # 1. Validate project argument
  if (missing(project) || is.null(project) || !nzchar(as.character(project))) {
    cat("[ERROR] ", msg("project_missing", default_lang, repo_root = repo_root), "\n", sep = "")
    return(invisible(FALSE))
  }
  
  project <- as.character(project)
  proj_root <- file.path(repo_root, "projects", project)
  if (!dir.exists(proj_root)) {
    cat("[ERROR] ", msg("project_not_found", default_lang, proj_root, repo_root = repo_root), "\n", sep = "")
    return(invisible(FALSE))
  }
  
  # 2. Map step to script file
  script_filename <- .step_to_script(step)
  if (is.null(script_filename)) {
    candidate <- file.path(repo_root, "02_scripts", paste0(step, ".R"))
    if (file.exists(candidate)) {
      script_filename <- paste0(step, ".R")
    } else {
      cat("[ERROR] ", msg("script_not_found", default_lang, step, paste0("02_scripts/", step, ".R"), repo_root = repo_root), "\n", sep = "")
      return(invisible(FALSE))
    }
  }
  
  # 3. Check config.json
  config_path <- file.path(proj_root, "config.json")
  cfg <- NULL
  lang <- default_lang
  
  if (file.exists(config_path)) {
    cfg <- tryCatch(
      jsonlite::fromJSON(config_path, simplifyVector = FALSE),
      error = function(e) {
        cat("[ERROR] Failed to parse config.json: ", e$message, "\n", sep = "")
        NULL
      }
    )
    if (is.null(cfg)) return(invisible(FALSE))
    lang <- cfg$language %||% default_lang
  } else {
    step_str <- as.character(step)
    if (step_str != "0" && step_str != "00") {
      cat("[ERROR] ", msg("config_missing", default_lang, config_path, repo_root = repo_root), "\n", sep = "")
      return(invisible(FALSE))
    }
  }
  
  # 4. Resolve script path (check custom override first)
  custom_candidates <- c(
    file.path(proj_root, "custom", script_filename),
    file.path(proj_root, "custom", paste0(step, ".R"))
  )
  
  script_path <- NULL
  for (cpath in custom_candidates) {
    if (file.exists(cpath)) {
      cat(msg("custom_override", lang, step, cpath, repo_root = repo_root), "\n")
      script_path <- cpath
      break
    }
  }
  
  if (is.null(script_path)) {
    script_path <- file.path(repo_root, "02_scripts", script_filename)
  }
  
  if (!file.exists(script_path)) {
    cat("[ERROR] ", msg("script_not_found", lang, step, script_path, repo_root = repo_root), "\n", sep = "")
    return(invisible(FALSE))
  }
  
  # 5. Execute in fresh environment via sys.source with full error & traceback capture
  env <- new.env(parent = globalenv())
  env$project <- project
  env$proj_root <- proj_root
  env$repo_root <- repo_root
  env$cfg <- cfg
  env$lang <- lang
  env$step <- step
  
  cat(msg("step_running", lang, step, project, repo_root = repo_root), "\n")
  
  err_call <- NULL
  err_trace <- NULL
  success <- TRUE
  
  tryCatch(
    withCallingHandlers(
      sys.source(script_path, envir = env),
      error = function(e) {
        err_call <<- conditionCall(e)
        err_trace <<- sys.calls()
      }
    ),
    error = function(e) {
      success <<- FALSE
      
      # Write error report with call and traceback to reports/<step>_error.txt
      rep_dir <- file.path(proj_root, "reports")
      if (!dir.exists(rep_dir)) dir.create(rep_dir, recursive = TRUE)
      
      step_clean <- gsub("[^A-Za-z0-9._-]", "_", as.character(step))
      err_file <- file.path(rep_dir, paste0(step_clean, "_error.txt"))
      err_con <- file(err_file, open = "wt", encoding = "UTF-8")
      
      cat("================================================================================\n", file = err_con)
      cat("  DSM-HARNESS: STEP EXECUTION ERROR REPORT\n", file = err_con)
      cat("================================================================================\n", file = err_con)
      cat("Timestamp:    ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n", file = err_con)
      cat("Project:      ", project, "\n", file = err_con)
      cat("Step:         ", as.character(step), "\n", file = err_con)
      cat("Script:       ", script_path, "\n", file = err_con)
      cat("Error:        ", conditionMessage(e), "\n", file = err_con)
      if (!is.null(err_call)) {
        cat("Failing Call: ", paste(deparse(err_call), collapse = "\n              "), "\n", file = err_con)
      }
      cat("--------------------------------------------------------------------------------\n", file = err_con)
      cat("TRACEBACK:\n", file = err_con)
      if (!is.null(err_trace) && length(err_trace) > 0) {
        # Format traceback lines cleanly
        for (idx in seq_along(err_trace)) {
          c_str <- paste(deparse(err_trace[[idx]]), collapse = " ")
          cat(sprintf("[%02d] %s\n", idx, c_str), file = err_con)
        }
      } else {
        cat("No traceback calls captured.\n", file = err_con)
      }
      cat("================================================================================\n", file = err_con)
      close(err_con)
      
      cat("[ERROR] ", msg("step_error", lang, conditionMessage(e), repo_root = repo_root), "\n", sep = "")
      cat(msg("step_error_saved", lang, err_file, repo_root = repo_root), "\n", sep = "")
    }
  )
  
  if (success) {
    cat(msg("step_success", lang, step, repo_root = repo_root), "\n")
    return(invisible(TRUE))
  } else {
    return(invisible(FALSE))
  }
}
