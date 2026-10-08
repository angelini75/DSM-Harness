# ==============================================================================
# DSM-Harness v2 | load_i18n.R
# Message catalogue loader and internationalization helper
# ==============================================================================

# Operator %||% for base R compatibility (< 4.4)
if (!exists("%||%", mode = "function")) {
  `%||%` <- function(a, b) {
    if (!is.null(a)) a else b
  }
}

.i18n_cache <- new.env(parent = emptyenv())

find_repo_root <- function(start_dir = getwd()) {
  curr <- normalizePath(start_dir, winslash = "/", mustWork = FALSE)
  while (nchar(curr) > 0 && dirname(curr) != curr) {
    if (file.exists(file.path(curr, "DSM-Harness.Rproj"))) {
      return(curr)
    }
    curr <- dirname(curr)
  }
  # Fallback to current working directory
  normalizePath(start_dir, winslash = "/", mustWork = FALSE)
}

load_catalog <- function(lang = "en", repo_root = NULL) {
  if (is.null(repo_root)) {
    repo_root <- find_repo_root()
  }
  
  if (exists(lang, envir = .i18n_cache)) {
    return(get(lang, envir = .i18n_cache))
  }
  
  cat_file <- file.path(repo_root, "02_scripts", "i18n", paste0(lang, ".yml"))
  if (!file.exists(cat_file)) {
    # Fallback to en
    cat_file <- file.path(repo_root, "02_scripts", "i18n", "en.yml")
  }
  
  if (file.exists(cat_file)) {
    cat_data <- yaml::read_yaml(cat_file)
    assign(lang, cat_data, envir = .i18n_cache)
    return(cat_data)
  }
  
  list()
}

msg <- function(key, lang = "en", ..., repo_root = NULL) {
  catalog <- load_catalog(lang, repo_root = repo_root)
  val <- catalog[[key]]
  
  if (is.null(val)) {
    # Fallback to English if not found
    en_catalog <- load_catalog("en", repo_root = repo_root)
    val <- en_catalog[[key]]
  }
  
  if (is.null(val)) {
    val <- key
  }
  
  dots <- list(...)
  if (length(dots) > 0) {
    do.call(sprintf, c(list(val), dots))
  } else {
    val
  }
}
