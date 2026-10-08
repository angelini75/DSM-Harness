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
  stop("Step 1.1 must be run within a project context (e.g., run_step('1.1', project = 'myproj'))")
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
log_out("  DSM-HARNESS: STEP 1.1 VARIABLE MAPPING & RELATIONAL AUDIT")
log_out("================================================================================")
log_out("Date: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"))
log_out("Project: ", project)
log_out("Input File: ", cfg$input_file)
log_out("================================================================================\n")

ext <- tolower(tools::file_ext(raw_file))
id_col <- if (is_str(cfg$roles$profile_id)) as.character(cfg$roles$profile_id) else "id"
dup_strat <- if (is_str(cfg$duplicate_key_strategy)) as.character(cfg$duplicate_key_strategy) else NULL

df_merged <- NULL

if (ext %in% c("xlsx", "xls")) {
  sheets <- readxl::excel_sheets(raw_file)
  if (!is.null(cfg$sheets) && length(cfg$sheets) > 0) {
    target_sheets <- unlist(cfg$sheets)
  } else {
    target_sheets <- sheets
  }
  
  sheet_dfs <- list()
  for (sh in target_sheets) {
    if (sh %in% sheets) {
      sheet_dfs[[sh]] <- as.data.frame(readxl::read_excel(raw_file, sheet = sh, guess_max = 100000))
    }
  }
  
  if (length(sheet_dfs) == 0) {
    close(rep_con)
    stop("No sheets could be loaded from input file.", call. = FALSE)
  }
  
  if (length(sheet_dfs) == 1) {
    df_merged <- sheet_dfs[[1]]
  } else {
    top_col <- if (is_str(cfg$roles$top)) as.character(cfg$roles$top) else "top"
    bottom_col <- if (is_str(cfg$roles$bottom)) as.character(cfg$roles$bottom) else "bottom"
    
    horizon_sh_name <- NULL
    profile_sh_name <- NULL
    
    for (sh in names(sheet_dfs)) {
      cols <- names(sheet_dfs[[sh]])
      if (top_col %in% cols || bottom_col %in% cols) {
        horizon_sh_name <- sh
      } else if (id_col %in% cols) {
        profile_sh_name <- sh
      }
    }
    
    # If not distinct by depth, choose by row count
    if (is.null(horizon_sh_name) || is.null(profile_sh_name)) {
      row_counts <- sapply(sheet_dfs, nrow)
      horizon_sh_name <- names(which.max(row_counts))
      profile_sh_name <- names(which.min(row_counts))
    }
    
    log_out(sprintf("Identified Profile sheet: '%s' (%d rows)", profile_sh_name, nrow(sheet_dfs[[profile_sh_name]])))
    log_out(sprintf("Identified Horizon sheet: '%s' (%d rows)", horizon_sh_name, nrow(sheet_dfs[[horizon_sh_name]])))
    
    df_prof <- sheet_dfs[[profile_sh_name]]
    df_horiz <- sheet_dfs[[horizon_sh_name]]
    
    # Check duplicate keys in profile table
    if (id_col %in% names(df_prof)) {
      prof_ids <- df_prof[[id_col]]
      dup_mask <- duplicated(prof_ids)
      n_dups <- sum(dup_mask)
      
      if (n_dups > 0) {
        log_out(msg("map_dup_keys_found", lang, n_dups, profile_sh_name, repo_root = repo_root))
        
        if (is.null(dup_strat) || !nzchar(as.character(dup_strat))) {
          err_msg <- msg("map_dup_no_strategy", lang, repo_root = repo_root)
          log_out("[ERROR] ", err_msg)
          close(rep_con)
          stop(err_msg, call. = FALSE)
        }
        
        if (dup_strat == "fail") {
          err_msg <- msg("map_dup_fail", lang, repo_root = repo_root)
          log_out("[ERROR] ", err_msg)
          close(rep_con)
          stop(err_msg, call. = FALSE)
        } else if (dup_strat == "average") {
          orig_rows <- nrow(df_prof)
          num_cols <- names(df_prof)[sapply(df_prof, is.numeric)]
          non_num_cols <- setdiff(names(df_prof), c(num_cols, id_col))
          
          df_prof <- df_prof |>
            dplyr::group_by(dplyr::across(dplyr::all_of(id_col))) |>
            dplyr::summarise(
              dplyr::across(dplyr::all_of(num_cols), ~ mean(.x, na.rm = TRUE)),
              dplyr::across(dplyr::all_of(non_num_cols), ~ dplyr::first(.x)),
              .groups = "drop"
            ) |>
            as.data.frame()
          
          log_out(msg("map_dup_resolved", lang, "average", orig_rows, nrow(df_prof), repo_root = repo_root))
        } else if (dup_strat == "keep_first") {
          orig_rows <- nrow(df_prof)
          df_prof <- df_prof[!duplicated(df_prof[[id_col]]), ]
          log_out(msg("map_dup_resolved", lang, "keep_first", orig_rows, nrow(df_prof), repo_root = repo_root))
        }
      }
    }
    
    # Left join horizon with profile
    df_merged <- dplyr::left_join(df_horiz, df_prof, by = id_col)
    log_out(sprintf("Merged table dimensions: %d rows x %d columns\n", nrow(df_merged), ncol(df_merged)))
  }
} else {
  # CSV / Flat file
  df_merged <- as.data.frame(readr::read_csv(raw_file, guess_max = 100000, show_col_types = FALSE))
  log_out(sprintf("Loaded flat dataset: %d rows x %d columns\n", nrow(df_merged), ncol(df_merged)))
}

# Check duplicate keys in flat dataset if profile-level only (no top/bottom)
top_col <- if (is_str(cfg$roles$top)) as.character(cfg$roles$top) else "top"
if (!top_col %in% names(df_merged)) {
  if (id_col %in% names(df_merged)) {
    dup_mask <- duplicated(df_merged[[id_col]])
    n_dups <- sum(dup_mask)
    if (n_dups > 0) {
      log_out(msg("map_dup_keys_found", lang, n_dups, "data", repo_root = repo_root))
      if (is.null(dup_strat) || !nzchar(as.character(dup_strat))) {
        err_msg <- msg("map_dup_no_strategy", lang, repo_root = repo_root)
        log_out("[ERROR] ", err_msg)
        close(rep_con)
        stop(err_msg, call. = FALSE)
      }
      if (dup_strat == "fail") {
        err_msg <- msg("map_dup_fail", lang, repo_root = repo_root)
        log_out("[ERROR] ", err_msg)
        close(rep_con)
        stop(err_msg, call. = FALSE)
      } else if (dup_strat == "average") {
        orig_rows <- nrow(df_merged)
        num_cols <- names(df_merged)[sapply(df_merged, is.numeric)]
        non_num_cols <- setdiff(names(df_merged), c(num_cols, id_col))
        df_merged <- df_merged |>
          dplyr::group_by(dplyr::across(dplyr::all_of(id_col))) |>
          dplyr::summarise(
            dplyr::across(dplyr::all_of(num_cols), ~ mean(.x, na.rm = TRUE)),
            dplyr::across(dplyr::all_of(non_num_cols), ~ dplyr::first(.x)),
            .groups = "drop"
          ) |>
          as.data.frame()
        log_out(msg("map_dup_resolved", lang, "average", orig_rows, nrow(df_merged), repo_root = repo_root))
      } else if (dup_strat == "keep_first") {
        orig_rows <- nrow(df_merged)
        df_merged <- df_merged[!duplicated(df_merged[[id_col]]), ]
        log_out(msg("map_dup_resolved", lang, "keep_first", orig_rows, nrow(df_merged), repo_root = repo_root))
      }
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
      cols_to_drop <- c(cols_to_drop, cn)
    }
  }
}
if (!is.null(excluded_cols) && length(excluded_cols) > 0) {
  cols_to_drop <- union(cols_to_drop, excluded_cols)
}

# Never drop role columns
role_cols <- unlist(cfg$roles)
cols_to_drop <- setdiff(cols_to_drop, role_cols)

if (length(cols_to_drop) > 0) {
  df_merged <- df_merged[, !(names(df_merged) %in% cols_to_drop), drop = FALSE]
  log_out("Excluded columns: ", paste(cols_to_drop, collapse = ", "), "\n")
}

# Summary of mapped columns and roles
log_out("--- Summary of Configured Roles ---")
for (r in names(cfg$roles)) {
  log_out(sprintf("  %-16s : %s", r, as.character(cfg$roles[[r]])))
}
log_out("\nFinal mapped dataset dimensions: ", nrow(df_merged), " rows x ", ncol(df_merged), " columns")

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
