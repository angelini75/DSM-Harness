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
  "cv_repeats",
  "tiles",
  "cores",
  "ram_gb",
  "ram_share",
  "country_code",
  "project_code"
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
  
  if (!exists("get_target_id", mode = "function")) {
    targets_path <- file.path(repo_root, "R", "targets.R")
    if (file.exists(targets_path)) source(targets_path, local = FALSE)
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
      target_ids <- character(0)
      target_code_tuples <- character(0)

      for (idx in seq_along(cfg$targets)) {
        tgt <- cfg$targets[[idx]]
        if (!is.list(tgt) || is.null(tgt$property) || is.null(tgt$d1) || is.null(tgt$d2)) {
          errors <- c(errors, msg("val_invalid_target_item", lang, idx, repo_root = repo_root))
        } else {
          d1_val <- suppressWarnings(as.numeric(tgt$d1))
          d2_val <- suppressWarnings(as.numeric(tgt$d2))
          if (is.na(d1_val) || is.na(d2_val) || d1_val >= d2_val) {
            errors <- c(errors, msg("val_target_depths_order", lang, idx, repo_root = repo_root))
          } else {
            # Collect canonical target ID
            tid <- get_target_id(tgt$property, d1_val, d2_val)
            target_ids <- c(target_ids, tid)

            # Format validation for per-target code whenever present
            if (!is.null(tgt$code)) {
              c_val <- as.character(tgt$code)
              if (length(tgt$code) != 1 || !nzchar(c_val) || !grepl("^[A-Za-z0-9_]+$", c_val)) {
                errors <- c(errors, msg("val_invalid_target_code", lang, idx, c_val, repo_root = repo_root))
              } else {
                # Tuple for code + d1 + d2 uniqueness
                d1_str <- gsub("\\.", "_", as.character(d1_val))
                d2_str <- gsub("\\.", "_", as.character(d2_val))
                code_tuple <- sprintf("%s_%s_%s", c_val, d1_str, d2_str)
                target_code_tuples <- c(target_code_tuples, code_tuple)
              }
            }
          }
        }
      }

      # Validate target_ids uniqueness across targets
      if (length(target_ids) > 0 && any(duplicated(target_ids))) {
        dup_ids <- unique(target_ids[duplicated(target_ids)])
        errors <- c(errors, msg("val_duplicate_target_id", lang, paste(dup_ids, collapse = ", "), repo_root = repo_root))
      }

      # Validate that no two targets share the same code + d1 + d2
      if (length(target_code_tuples) > 0 && any(duplicated(target_code_tuples))) {
        dup_codes <- unique(target_code_tuples[duplicated(target_code_tuples)])
        errors <- c(errors, msg("val_duplicate_target_code", lang, paste(dup_codes, collapse = ", "), repo_root = repo_root))
      }
    }
  }

  # 6c. Check tiles if present
  if (!is.null(cfg$tiles)) {
    if (!is.list(cfg$tiles) || is.null(cfg$tiles$cols) || is.null(cfg$tiles$rows)) {
      errors <- c(errors, msg("val_invalid_tiles_shape", lang, repo_root = repo_root))
    } else {
      cols_val <- suppressWarnings(as.numeric(cfg$tiles$cols))
      rows_val <- suppressWarnings(as.numeric(cfg$tiles$rows))
      if (is.na(cols_val) || cols_val < 1 || is.na(rows_val) || rows_val < 1) {
        errors <- c(errors, msg("val_invalid_tiles_values", lang, repo_root = repo_root))
      } else if (rows_val != 1) {
        errors <- c(errors, msg("val_tiles_rows_not_one", lang, as.character(cfg$tiles$rows), repo_root = repo_root))
      }
    }
  }

  # 6d. Check hardware parameters if present: cores, ram_gb, ram_share
  if (!is.null(cfg$cores)) {
    c_val <- suppressWarnings(as.numeric(cfg$cores))
    if (is.na(c_val) || c_val < 1 || c_val != as.integer(c_val)) {
      errors <- c(errors, msg("val_invalid_cores", lang, repo_root = repo_root))
    }
  }
  if (!is.null(cfg$ram_gb)) {
    r_val <- suppressWarnings(as.numeric(cfg$ram_gb))
    if (is.na(r_val) || r_val <= 0) {
      errors <- c(errors, msg("val_invalid_ram_gb", lang, repo_root = repo_root))
    }
  }
  if (!is.null(cfg$ram_share)) {
    s_val <- suppressWarnings(as.numeric(cfg$ram_share))
    if (is.na(s_val) || s_val <= 0 || s_val > 1) {
      errors <- c(errors, msg("val_invalid_ram_share", lang, repo_root = repo_root))
    }
  }

  # 6e. Check country_code and project_code if present
  if (!is.null(cfg$country_code)) {
    if (!is.character(cfg$country_code) || length(cfg$country_code) != 1 || !nzchar(trimws(cfg$country_code))) {
      errors <- c(errors, msg("val_invalid_code_field", lang, "country_code", repo_root = repo_root))
    }
  }
  if (!is.null(cfg$project_code)) {
    if (!is.character(cfg$project_code) || length(cfg$project_code) != 1 || !nzchar(trimws(cfg$project_code))) {
      errors <- c(errors, msg("val_invalid_code_field", lang, "project_code", repo_root = repo_root))
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
