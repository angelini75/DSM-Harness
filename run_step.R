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

new_project <- function(name, repo_root = NULL) {
  if (missing(name) || !nzchar(name)) {
    cat("[ERROR] Project name must be provided: new_project(\"my_project\")\n")
    return(invisible(FALSE))
  }
  
  if (is.null(repo_root)) {
    repo_root <- find_repo_root()
  }
  
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
  
  cat(sprintf("[INFO] Project '%s' initialized at: %s\n", name, proj_dir))
  invisible(TRUE)
}

run_step <- function(step, project) {
  repo_root <- find_repo_root()
  .ensure_i18n(repo_root)
  
  # Default language for pre-config messages
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
    # Check if a file matching step name exists directly in 02_scripts
    candidate <- file.path(repo_root, "02_scripts", paste0(step, ".R"))
    if (file.exists(candidate)) {
      script_filename <- paste0(step, ".R")
    } else {
      cat("[ERROR] ", msg("script_not_found", default_lang, step, paste0("02_scripts/", step, ".R"), repo_root = repo_root), "\n", sep = "")
      return(invisible(FALSE))
    }
  }
  
  # 3. Check config.json (required for step >= 1.1)
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
  
  # 5. Execute in fresh environment via sys.source
  env <- new.env(parent = globalenv())
  env$project <- project
  env$proj_root <- proj_root
  env$repo_root <- repo_root
  env$cfg <- cfg
  env$lang <- lang
  env$step <- step
  
  # Announce step execution
  cat(msg("step_running", lang, step, project, repo_root = repo_root), "\n")
  
  success <- TRUE
  tryCatch(
    {
      sys.source(script_path, envir = env)
    },
    error = function(e) {
      cat("[ERROR] ", msg("step_error", lang, e$message, repo_root = repo_root), "\n", sep = "")
      success <<- FALSE
    }
  )
  
  if (success) {
    cat(msg("step_success", lang, step, repo_root = repo_root), "\n")
    return(invisible(TRUE))
  } else {
    return(invisible(FALSE))
  }
}
