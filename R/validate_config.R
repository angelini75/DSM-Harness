# ==============================================================================
# DSM-Harness v2 | validate_config.R
# Configuration validator enforcing roles, categories, enums, shapes, and paths
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
  "tables",
  "base_table",
  "joins",
  "roles",
  "columns",
  "categories",
  "excluded_categories",
  "excluded_columns",
  "duplicate_key_strategy",
  "source_crs",
  "impute_bulk_density",
  "targets",
  "boruta_max_runs",
  "min_support",
  "refit",
  "cv_folds",
  "cv_repeats"
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

ALLOWED_LANGUAGES <- c(
  "en",
  "es"
)

validate_config <- function(cfg, data_cols = NULL, stop_on_error = TRUE, repo_root = NULL, target_cols_only = FALSE) {
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
  
  # 2. Check required top-level fields: project, language, input_file
  for (req in c("project", "language", "input_file")) {
    if (is.null(cfg[[req]]) || length(cfg[[req]]) == 0 || !nzchar(as.character(cfg[[req]][1]))) {
      errors <- c(errors, msg("val_missing_field", lang, req, repo_root = repo_root))
    }
  }
  
  # Check language is valid enum
  if (!is.null(cfg$language)) {
    l_val <- as.character(cfg$language)
    if (!(l_val %in% ALLOWED_LANGUAGES)) {
      errors <- c(errors, msg(
        "val_invalid_enum", lang, l_val, "language",
        paste(ALLOWED_LANGUAGES, collapse = " | "),
        repo_root = repo_root
      ))
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
  
  # 6. Check categories shape and values
  cat_map <- cfg$categories %||% cfg$columns
  if (!is.null(cat_map) && length(cat_map) > 0) {
    # Validate shape: must be named list where each value is a single scalar character string
    shape_error_reported <- FALSE
    for (col in names(cat_map)) {
      val <- cat_map[[col]]
      if (is.null(val) || length(val) != 1 || is.list(val) || !is.atomic(val)) {
        if (!shape_error_reported) {
          errors <- c(errors, msg("val_invalid_cat_shape", lang, repo_root = repo_root))
          shape_error_reported <- TRUE
        }
      } else {
        cat_val <- as.character(val)
        if (!(cat_val %in% ALLOWED_CATEGORIES)) {
          errors <- c(errors, msg(
            "val_invalid_category", lang, cat_val, col,
            paste(ALLOWED_CATEGORIES, collapse = ", "),
            repo_root = repo_root
          ))
        }
      }
    }
  }
  
  # 6b. Check targets shape and values
  if (!is.null(cfg$targets)) {
    if (!is.list(cfg$targets)) {
      errors <- c(errors, msg("val_invalid_targets", lang, repo_root = repo_root))
    } else {
      for (idx in seq_along(cfg$targets)) {
        tgt <- cfg$targets[[idx]]
        if (!is.list(tgt) || is.null(tgt$property) || is.null(tgt$d1) || is.null(tgt$d2)) {
          errors <- c(errors, msg("val_invalid_target_item", lang, idx, repo_root = repo_root))
        } else {
          d1_val <- suppressWarnings(as.numeric(tgt$d1))
          d2_val <- suppressWarnings(as.numeric(tgt$d2))
          if (is.na(d1_val) || is.na(d2_val) || d1_val >= d2_val) {
            errors <- c(errors, msg("val_target_depths_order", lang, idx, repo_root = repo_root))
          }
        }
      }
    }
  }

  # 7. Check configured columns against dataset columns (if provided)
  if (!is.null(data_cols) && length(data_cols) > 0) {
    if (!target_cols_only) {
      # Check roles (supporting table.column syntax)
      if (!is.null(cfg$roles)) {
        for (r in names(cfg$roles)) {
          col_name <- as.character(cfg$roles[[r]])
          # match exact col_name or stripped table prefix (e.g. "profiles.x" -> "x")
          col_bare <- sub("^[^.]+\\.", "", col_name)
          if (!(col_name %in% data_cols) && !(col_bare %in% data_cols)) {
            errors <- c(errors, msg("val_col_not_found", lang, col_name, repo_root = repo_root))
          }
        }
      }
      
      # Check category mappings (skipping columns dropped in excluded_categories or excluded_columns)
      if (!is.null(cat_map) && !isTRUE(shape_error_reported)) {
        excluded_cats <- unlist(cfg$excluded_categories %||% list())
        excluded_cols <- unlist(cfg$excluded_columns %||% list())
        for (col_name in names(cat_map)) {
          cat_val <- as.character(cat_map[[col_name]])
          if (cat_val %in% excluded_cats || col_name %in% excluded_cols) {
            next
          }
          col_bare <- sub("^[^.]+\\.", "", col_name)
          if (!(col_name %in% data_cols) && !(col_bare %in% data_cols)) {
            errors <- c(errors, msg("val_col_not_found", lang, col_name, repo_root = repo_root))
          }
        }
      }
    }

    # Check target properties (always checked against data_cols)
    if (!is.null(cfg$targets) && is.list(cfg$targets)) {
      for (tgt in cfg$targets) {
        if (is.list(tgt) && !is.null(tgt$property)) {
          col_name <- as.character(tgt$property)
          col_bare <- sub("^[^.]+\\.", "", col_name)
          if (!(col_name %in% data_cols) && !(col_bare %in% data_cols)) {
            errors <- c(errors, msg("val_col_not_found", lang, col_name, repo_root = repo_root))
          }
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
