# ==============================================================================
# DSM-Harness v2 | 02_scripts/01_1_byod_audit.R
# Step 1.1: Variable Mapping, Relational Joins & Duplicate Key Resolution
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

if (!exists("project", inherits = FALSE) || is.null(project)) {
  stop(msg("step_context_missing", "en", "1.1", "1.1", repo_root = repo_root), call. = FALSE)
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

# Validate configuration
validate_config(cfg, stop_on_error = TRUE, repo_root = repo_root)

# Locate raw input file
raw_file <- file.path(proj_root, cfg$input_file)
if (!file.exists(raw_file)) {
  stop(msg("map_input_missing", lang, raw_file, repo_root = repo_root), call. = FALSE)
}

report_path <- file.path(reports_dir, "11_mapping.txt")
rep_con <- file(report_path, open = "wt", encoding = "UTF-8")

log_out <- function(...) {
  line <- paste0(...)
  cat(line, "\n")
  cat(line, "\n", file = rep_con)
}

log_out("================================================================================")
log_out(msg("map_header", lang, repo_root = repo_root))
log_out("================================================================================")
log_out(msg("map_date", lang, format(Sys.time(), "%Y-%m-%d %H:%M:%S"), repo_root = repo_root))
log_out(msg("map_project", lang, project, repo_root = repo_root))
log_out(msg("map_input_file", lang, cfg$input_file, repo_root = repo_root))
log_out("================================================================================\n")

ext <- tolower(tools::file_ext(raw_file))
id_role_val <- if (is_str(cfg$roles$profile_id)) as.character(cfg$roles$profile_id) else "id"
dup_strat <- if (is_str(cfg$duplicate_key_strategy)) as.character(cfg$duplicate_key_strategy) else NULL

# Table loader helper
load_table <- function(tbl_name) {
  if (ext %in% c("xlsx", "xls")) {
    as.data.frame(readxl::read_excel(raw_file, sheet = tbl_name, guess_max = 100000))
  } else {
    tbl_path <- if (file.exists(file.path(proj_root, tbl_name))) {
      file.path(proj_root, tbl_name)
    } else if (!is.null(cfg$tables) && !is.null(cfg$tables[[tbl_name]]) && file.exists(file.path(proj_root, cfg$tables[[tbl_name]]))) {
      file.path(proj_root, cfg$tables[[tbl_name]])
    } else {
      raw_file
    }
    as.data.frame(readr::read_csv(tbl_path, guess_max = 100000, show_col_types = FALSE))
  }
}

df_merged <- NULL

# Check if joins are declaratively specified
if (!is.null(cfg$joins) && length(cfg$joins) > 0) {
  # Base table defines the rows
  base_tbl_name <- as.character(cfg$base_table %||% cfg$sheets[[1]] %||% "base")
  df_merged <- load_table(base_tbl_name)
  base_origin_map <- as.list(setNames(rep(base_tbl_name, ncol(df_merged)), names(df_merged)))
  collided_col_names <- character(0)
  
  log_out(msg("map_base_table", lang, base_tbl_name, nrow(df_merged), ncol(df_merged), repo_root = repo_root), "\n")
  
  for (idx in seq_along(cfg$joins)) {
    j <- cfg$joins[[idx]]
    inc_tbl_name <- as.character(j$table %||% j$right)
    log_out(msg("map_applying_join", lang, idx, inc_tbl_name, repo_root = repo_root))
    
    df_inc <- load_table(inc_tbl_name)
    
    # Parse join keys
    by_spec <- j$by
    if (is.null(names(by_spec)) || !any(nzchar(names(by_spec)))) {
      base_keys <- as.character(unlist(by_spec))
      inc_keys <- as.character(unlist(by_spec))
    } else {
      base_keys <- names(by_spec)
      inc_keys <- as.character(unlist(by_spec))
    }
    
    log_out(msg("map_join_keys", lang, paste(sprintf("%s = %s", base_keys, inc_keys), collapse = ", "), repo_root = repo_root))
    
    # Verify keys exist
    missing_b <- setdiff(base_keys, names(df_merged))
    missing_inc <- setdiff(inc_keys, names(df_inc))
    if (length(missing_b) > 0 || length(missing_inc) > 0) {
      close(rep_con)
      stop(msg("map_join_key_error", lang, paste(missing_b, collapse=", "), paste(missing_inc, collapse=", "), repo_root = repo_root), call. = FALSE)
    }
    
    # Check duplicate keys in incoming table
    inc_key_df <- df_inc[, inc_keys, drop = FALSE]
    dup_mask <- duplicated(inc_key_df)
    n_dups <- sum(dup_mask)
    
    if (n_dups > 0) {
      log_out(msg("map_dup_keys_found", lang, n_dups, inc_tbl_name, repo_root = repo_root))
      
      if (is.null(dup_strat) || !nzchar(as.character(dup_strat))) {
        err_msg <- msg("map_dup_no_strategy", lang, inc_tbl_name, repo_root = repo_root)
        log_out("[ERROR] ", err_msg)
        close(rep_con)
        stop(err_msg, call. = FALSE)
      }
      
      if (dup_strat == "fail") {
        err_msg <- msg("map_dup_fail", lang, inc_tbl_name, repo_root = repo_root)
        log_out("[ERROR] ", err_msg)
        close(rep_con)
        stop(err_msg, call. = FALSE)
      } else if (dup_strat == "average") {
        orig_inc_rows <- nrow(df_inc)
        num_cols <- names(df_inc)[sapply(df_inc, is.numeric)]
        num_cols <- setdiff(num_cols, inc_keys)
        non_num_cols <- setdiff(names(df_inc), c(num_cols, inc_keys))
        
        df_inc <- df_inc |>
          dplyr::group_by(dplyr::across(dplyr::all_of(inc_keys))) |>
          dplyr::summarise(
            dplyr::across(dplyr::all_of(num_cols), ~ mean(.x, na.rm = TRUE)),
            dplyr::across(dplyr::all_of(non_num_cols), ~ dplyr::first(.x)),
            .groups = "drop"
          ) |>
          as.data.frame()
        
        log_out(msg("map_dup_resolved", lang, inc_tbl_name, "average", orig_inc_rows, nrow(df_inc), repo_root = repo_root))
      } else if (dup_strat == "keep_first") {
        orig_inc_rows <- nrow(df_inc)
        df_inc <- df_inc[!duplicated(df_inc[, inc_keys, drop = FALSE]), , drop = FALSE]
        log_out(msg("map_dup_resolved", lang, inc_tbl_name, "keep_first", orig_inc_rows, nrow(df_inc), repo_root = repo_root))
      }
    }
    
    # Check unmatched keys on either side
    base_comp_keys <- do.call(paste, c(df_merged[, base_keys, drop = FALSE], sep = "____"))
    inc_comp_keys <- do.call(paste, c(df_inc[, inc_keys, drop = FALSE], sep = "____"))
    n_unmatched_base <- sum(!base_comp_keys %in% inc_comp_keys)
    n_unmatched_inc <- sum(!inc_comp_keys %in% base_comp_keys)
    
    log_out(msg("map_unmatched_base", lang, inc_tbl_name, n_unmatched_base, repo_root = repo_root))
    log_out(msg("map_unmatched_incoming", lang, inc_tbl_name, n_unmatched_inc, repo_root = repo_root))
    
    # Resolve column name collisions explicitly (no automatic .x / .y)
    overlapping_cols <- setdiff(intersect(names(df_merged), names(df_inc)), union(base_keys, inc_keys))
    if (length(overlapping_cols) > 0) {
      for (oc in overlapping_cols) {
        orig_tbl <- base_origin_map[[oc]] %||% base_tbl_name
        new_base_col <- if (grepl("\\.", oc)) oc else paste0(orig_tbl, ".", oc)
        new_inc_col <- paste0(inc_tbl_name, ".", oc)
        
        # Rename in df_merged
        names(df_merged)[names(df_merged) == oc] <- new_base_col
        base_origin_map[[new_base_col]] <- orig_tbl
        base_origin_map[[oc]] <- NULL
        
        # Rename in df_inc
        names(df_inc)[names(df_inc) == oc] <- new_inc_col
        base_origin_map[[new_inc_col]] <- inc_tbl_name
        
        collided_col_names <- union(collided_col_names, oc)
        log_out(msg("map_collision_resolved", lang, oc, new_base_col, new_inc_col, repo_root = repo_root))
      }
    }
    
    # Resolve collisions for columns in df_inc that match previously collided bare column names
    remaining_inc_cols <- setdiff(names(df_inc), union(base_keys, inc_keys))
    for (inc_c in remaining_inc_cols) {
      is_already_collided <- inc_c %in% collided_col_names || any(grepl(paste0("\\.", inc_c, "$"), names(df_merged)))
      is_already_prefixed <- grepl(paste0("^", inc_tbl_name, "\\."), inc_c)
      if (is_already_collided && !is_already_prefixed) {
        new_inc_col <- paste0(inc_tbl_name, ".", inc_c)
        names(df_inc)[names(df_inc) == inc_c] <- new_inc_col
        base_origin_map[[new_inc_col]] <- inc_tbl_name
        collided_col_names <- union(collided_col_names, inc_c)
        log_out(msg("map_collision_resolved_inc", lang, inc_c, inc_tbl_name, new_inc_col, repo_root = repo_root))
      }
    }
    
    # Track origin of incoming columns
    for (inc_c in setdiff(names(df_inc), inc_keys)) {
      base_origin_map[[inc_c]] <- inc_tbl_name
    }
    
    # Perform join
    rows_before <- nrow(df_merged)
    join_by_vector <- setNames(inc_keys, base_keys)
    df_merged <- dplyr::left_join(df_merged, df_inc, by = join_by_vector)
    
    log_out(msg("map_join_rows", lang, rows_before, nrow(df_merged), repo_root = repo_root), "\n")
  }
} else {
  # Single table or flat file
  if (ext %in% c("xlsx", "xls")) {
    sheets <- readxl::excel_sheets(raw_file)
    target_sheet <- if (!is.null(cfg$sheets) && length(cfg$sheets) > 0) cfg$sheets[[1]] else sheets[1]
    df_merged <- as.data.frame(readxl::read_excel(raw_file, sheet = target_sheet, guess_max = 100000))
  } else {
    df_merged <- as.data.frame(readr::read_csv(raw_file, guess_max = 100000, show_col_types = FALSE))
  }
  log_out(msg("map_loaded_flat", lang, nrow(df_merged), ncol(df_merged), repo_root = repo_root), "\n")
  
  # Only deduplicate flat datasets if profile-level only (no depth columns)
  top_col <- if (is_str(cfg$roles$top)) as.character(cfg$roles$top) else "top"
  if (!top_col %in% names(df_merged)) {
    if (id_role_val %in% names(df_merged)) {
      dup_mask <- duplicated(df_merged[[id_role_val]])
      n_dups <- sum(dup_mask)
      if (n_dups > 0) {
        log_out(msg("map_dup_keys_found", lang, n_dups, "data", repo_root = repo_root))
        if (is.null(dup_strat) || !nzchar(as.character(dup_strat))) {
          err_msg <- msg("map_dup_no_strategy", lang, "data", repo_root = repo_root)
          log_out("[ERROR] ", err_msg)
          close(rep_con)
          stop(err_msg, call. = FALSE)
        }
        if (dup_strat == "fail") {
          err_msg <- msg("map_dup_fail", lang, "data", repo_root = repo_root)
          log_out("[ERROR] ", err_msg)
          close(rep_con)
          stop(err_msg, call. = FALSE)
        } else if (dup_strat == "average") {
          orig_rows <- nrow(df_merged)
          num_cols <- names(df_merged)[sapply(df_merged, is.numeric)]
          non_num_cols <- setdiff(names(df_merged), c(num_cols, id_role_val))
          df_merged <- df_merged |>
            dplyr::group_by(dplyr::across(dplyr::all_of(id_role_val))) |>
            dplyr::summarise(
              dplyr::across(dplyr::all_of(num_cols), ~ mean(.x, na.rm = TRUE)),
              dplyr::across(dplyr::all_of(non_num_cols), ~ dplyr::first(.x)),
              .groups = "drop"
            ) |>
            as.data.frame()
          log_out(msg("map_dup_resolved", lang, "data", "average", orig_rows, nrow(df_merged), repo_root = repo_root))
        } else if (dup_strat == "keep_first") {
          orig_rows <- nrow(df_merged)
          df_merged <- df_merged[!duplicated(df_merged[[id_role_val]]), , drop = FALSE]
          log_out(msg("map_dup_resolved", lang, "data", "keep_first", orig_rows, nrow(df_merged), repo_root = repo_root))
        }
      }
    }
  }
}

# Resolve roles that might reference table.column or bare names
for (r in names(cfg$roles)) {
  role_target <- as.character(cfg$roles[[r]])
  if (!role_target %in% names(df_merged)) {
    matching_cols <- grep(paste0("\\.", role_target, "$"), names(df_merged), value = TRUE)
    if (length(matching_cols) == 1) {
      cfg$roles[[r]] <- matching_cols[1]
    }
  }
}

# Handle category / column exclusions
cat_map <- cfg$categories %||% cfg$columns
excluded_cats <- unlist(cfg$excluded_categories)
excluded_cols <- unlist(cfg$excluded_columns)

cols_to_drop <- character(0)
if (!is.null(excluded_cats) && length(excluded_cats) > 0 && !is.null(cat_map)) {
  for (cn in names(cat_map)) {
    if (as.character(cat_map[[cn]]) %in% excluded_cats) {
      matches <- c(cn, grep(paste0("\\.", cn, "$"), names(df_merged), value = TRUE))
      cols_to_drop <- union(cols_to_drop, matches)
    }
  }
}
if (!is.null(excluded_cols) && length(excluded_cols) > 0) {
  cols_to_drop <- union(cols_to_drop, excluded_cols)
}

# Never drop role columns
role_cols <- unlist(cfg$roles)
role_cols_bare <- sub("^[^.]+\\.", "", role_cols)
all_role_matches <- unique(c(role_cols, names(df_merged)[names(df_merged) %in% role_cols], names(df_merged)[sub("^[^.]+\\.", "", names(df_merged)) %in% role_cols_bare]))

cols_to_drop <- setdiff(cols_to_drop, all_role_matches)

if (length(cols_to_drop) > 0) {
  df_merged <- df_merged[, !(names(df_merged) %in% cols_to_drop), drop = FALSE]
  log_out(msg("map_excluded_cols", lang, paste(cols_to_drop, collapse = ", "), repo_root = repo_root), "\n")
}

# Summary of mapped columns and roles
log_out(msg("map_summary_roles", lang, repo_root = repo_root))
for (r in names(cfg$roles)) {
  log_out(sprintf("  %-16s : %s", r, as.character(cfg$roles[[r]])))
}
log_out("\n", msg("map_final_dims", lang, nrow(df_merged), ncol(df_merged), repo_root = repo_root))

# Write output file
out_csv <- file.path(data_dir, "01_mapped.csv")
readr::write_csv(df_merged, out_csv)

close(rep_con)

record_decision(
  project = project,
  step = "1.1",
  decision = "Mapped and joined dataset",
  details = sprintf("Output data/01_mapped.csv (%d rows, %d cols). Dup strategy: %s", nrow(df_merged), ncol(df_merged), dup_strat %||% "none"),
  repo_root = repo_root
)

cat(msg("map_complete", lang, out_csv, report_path, repo_root = repo_root), "\n")
