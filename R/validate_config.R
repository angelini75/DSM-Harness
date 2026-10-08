# ==============================================================================
# DSM-Harness v2 | validate_config.R
# Configuration validator enforcing roles, categories, enums, and relative paths
# ==============================================================================

# Ensure %||% is available
if (!exists("%||%", mode = "function")) {
  `%||%` <- function(a, b) {
    if (!is.null(a)) a else b
  }
}

ALLOWED_CONFIG_KEYS <- c(
  "language",
  "project",
  "input_file",
  "sheets",
  "roles",
  "columns",
  "categories",
  "excluded_categories",
  "excluded_columns",
  "duplicate_key_strategy",
  "source_crs",
  "impute_bulk_density"
)

ALLOWED_ROLES <- c(
  "profile_id",
  "x",
  "y",
  "top",
  "bottom",
  "bulk_density",
  "organic_carbon",
  "organic_matter"
)

REQUIRED_ROLES <- c(
  "profile_id",
  "x",
  "y",
  "top",
  "bottom"
)

ALLOWED_CATEGORIES <- c(
  "texture",
  "organic matter and density",
  "chemistry",
  "salts and conductivity",
  "nutrients",
  "other",
  "identification",
  "location",
  "depth"
)

ALLOWED_DUP_STRATEGIES <- c(
  "fail",
  "average",
  "keep_first"
)

validate_config <- function(cfg, data_cols = NULL, stop_on_error = TRUE, repo_root = NULL) {
  if (is.null(repo_root)) {
    if (exists("find_repo_root", mode = "function")) {
      repo_root <- find_repo_root()
    } else {
      repo_root <- getwd()
    }
  }
  
  if (!exists("msg", mode = "function")) {
    i18n_path <- file.path(repo_root, "02_scripts", "i18n", "load_i18n.R")
    if (file.exists(i18n_path)) source(i18n_path, local = FALSE)
  }
  
  lang <- cfg$language %||% "en"
  errors <- character(0)
  
  # 1. Check for unknown top-level keys
  unknown_keys <- setdiff(names(cfg), ALLOWED_CONFIG_KEYS)
  if (length(unknown_keys) > 0) {
    for (k in unknown_keys) {
      errors <- c(errors, msg("val_unknown_key", lang, k, repo_root = repo_root))
    }
  }
  
  # 2. Check required top-level fields
  for (req in c("project", "input_file")) {
    if (is.null(cfg[[req]]) || !nzchar(as.character(cfg[[req]]))) {
      errors <- c(errors, msg("val_missing_field", lang, req, repo_root = repo_root))
    }
  }
  
  # 3. Check input_file is relative
  if (!is.null(cfg$input_file)) {
    in_file <- as.character(cfg$input_file)
    if (grepl("^(/|[A-Za-z]:[/\\]|\\\\|~)", in_file)) {
      errors <- c(errors, msg("val_path_absolute", lang, in_file, repo_root = repo_root))
    }
  }
  
  # 4. Check duplicate_key_strategy enum
  if (!is.null(cfg$duplicate_key_strategy)) {
    strat <- as.character(cfg$duplicate_key_strategy)
    if (!(strat %in% ALLOWED_DUP_STRATEGIES)) {
      errors <- c(errors, msg(
        "val_invalid_enum", lang, strat, "duplicate_key_strategy",
        paste(ALLOWED_DUP_STRATEGIES, collapse = " | "),
        repo_root = repo_root
      ))
    }
  }
  
  # 5. Check roles
  if (is.null(cfg$roles) || length(cfg$roles) == 0) {
    errors <- c(errors, msg("val_missing_field", lang, "roles", repo_root = repo_root))
  } else {
    role_names <- names(cfg$roles)
    invalid_roles <- setdiff(role_names, ALLOWED_ROLES)
    if (length(invalid_roles) > 0) {
      for (r in invalid_roles) {
        errors <- c(errors, msg(
          "val_invalid_role", lang, r, as.character(cfg$roles[[r]]),
          paste(ALLOWED_ROLES, collapse = ", "),
          repo_root = repo_root
        ))
      }
    }
    
    missing_req_roles <- setdiff(REQUIRED_ROLES, role_names)
    if (length(missing_req_roles) > 0) {
      errors <- c(errors, msg(
        "map_missing_roles", lang,
        paste(missing_req_roles, collapse = ", "),
        repo_root = repo_root
      ))
    }
  }
  
  # 6. Check categories
  cat_map <- cfg$categories %||% cfg$columns
  if (!is.null(cat_map) && length(cat_map) > 0) {
    for (col in names(cat_map)) {
      cat_val <- as.character(cat_map[[col]])
      if (!(cat_val %in% ALLOWED_CATEGORIES)) {
        errors <- c(errors, msg(
          "val_invalid_category", lang, cat_val, col,
          paste(ALLOWED_CATEGORIES, collapse = ", "),
          repo_root = repo_root
        ))
      }
    }
  }
  
  # 7. Check configured columns against dataset columns (if provided)
  if (!is.null(data_cols) && length(data_cols) > 0) {
    # Check roles
    if (!is.null(cfg$roles)) {
      for (r in names(cfg$roles)) {
        col_name <- as.character(cfg$roles[[r]])
        if (!(col_name %in% data_cols)) {
          errors <- c(errors, msg("val_col_not_found", lang, col_name, repo_root = repo_root))
        }
      }
    }
    
    # Check category mappings
    if (!is.null(cat_map)) {
      for (col_name in names(cat_map)) {
        if (!(col_name %in% data_cols)) {
          errors <- c(errors, msg("val_col_not_found", lang, col_name, repo_root = repo_root))
        }
      }
    }
  }
  
  if (length(errors) > 0) {
    if (stop_on_error) {
      stop(paste(errors, collapse = "\n"), call. = FALSE)
    }
    return(list(valid = FALSE, errors = errors))
  }
  
  list(valid = TRUE, errors = character(0))
}
