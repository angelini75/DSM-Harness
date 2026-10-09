# ==============================================================================
# DSM-Harness v2 | 02_scripts/00_inspect_data.R
# Step 0: Exhaustive Dataset Profiling & Structural Inspection
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
  stop(msg("step_context_missing", "en", "0", "0", repo_root = repo_root), call. = FALSE)
}

proj_root <- file.path(repo_root, "projects", project)

# Detect language from config.json if present
if (!exists("lang", inherits = FALSE) || is.null(lang)) {
  cfg_file <- file.path(proj_root, "config.json")
  if (file.exists(cfg_file)) {
    c_data <- tryCatch(jsonlite::fromJSON(cfg_file, simplifyVector = FALSE), error = function(e) NULL)
    lang <- c_data$language %||% "en"
  } else {
    lang <- "en"
  }
}

# Locate raw input file
data_dir <- file.path(proj_root, "data")
reports_dir <- file.path(proj_root, "reports")
if (!dir.exists(reports_dir)) dir.create(reports_dir, recursive = TRUE)

raw_file <- NULL
if (exists("cfg", inherits = FALSE) && !is.null(cfg) && !is.null(cfg$input_file)) {
  candidate <- file.path(proj_root, cfg$input_file)
  if (file.exists(candidate)) raw_file <- candidate
}

if (is.null(raw_file)) {
  avail <- list.files(data_dir, pattern = "\\.(xlsx|xls|csv|tsv|txt)$", full.names = TRUE, ignore.case = TRUE)
  avail <- avail[!grepl("(01_mapped|02_spatial|03_clean|04_cov_.*)\\.csv$", avail, ignore.case = TRUE)]
  if (length(avail) > 0) {
    raw_file <- avail[1]
  }
}

if (is.null(raw_file) || !file.exists(raw_file)) {
  stop(msg("inspect_no_file", lang, data_dir, repo_root = repo_root), call. = FALSE)
}

report_path <- file.path(reports_dir, "00_inspection.txt")
rep_con <- file(report_path, open = "wt", encoding = "UTF-8")

log_out <- function(...) {
  line <- paste0(...)
  cat(line, "\n")
  cat(line, "\n", file = rep_con)
}

ext <- tolower(tools::file_ext(raw_file))
rel_input_file <- sub(paste0("^", normalizePath(proj_root, winslash = "/", mustWork = FALSE), "/?"), "", normalizePath(raw_file, winslash = "/", mustWork = FALSE))

log_out("================================================================================")
log_out(msg("inspect_header", lang, repo_root = repo_root))
log_out("================================================================================")
log_out(msg("inspect_date", lang, format(Sys.time(), "%Y-%m-%d %H:%M:%S"), repo_root = repo_root))
log_out(msg("inspect_project", lang, project, repo_root = repo_root))
log_out(msg("inspect_file", lang, rel_input_file, repo_root = repo_root))
log_out(msg("inspect_format", lang, ext, repo_root = repo_root))
log_out(msg("inspect_file_size", lang, round(file.size(raw_file) / 1024, 2), repo_root = repo_root))
log_out("================================================================================\n")

# Inspection helper
inspect_table <- function(df, tbl_name) {
  log_out(msg("inspect_sheet_summary", lang, tbl_name, repo_root = repo_root))
  log_out(msg("inspect_dimensions", lang, nrow(df), ncol(df), repo_root = repo_root), "\n")
  
  if (nrow(df) == 0 || ncol(df) == 0) {
    log_out(msg("inspect_empty_table", lang, repo_root = repo_root), "\n")
    return()
  }
  
  col_names <- names(df)
  log_out(msg("inspect_col_header", lang, repo_root = repo_root))
  log_out(paste(rep("-", 80), collapse = ""))
  
  for (cn in col_names) {
    col_data <- df[[cn]]
    col_type <- class(col_data)[1]
    pct_na <- round(sum(is.na(col_data)) / length(col_data) * 100, 1)
    
    val_sample <- ""
    if (is.numeric(col_data)) {
      non_na <- col_data[!is.na(col_data)]
      if (length(non_na) > 0) {
        val_sample <- sprintf("[%g, %g]", min(non_na), max(non_na))
      } else {
        val_sample <- msg("inspect_all_na", lang, repo_root = repo_root)
      }
    } else {
      non_na <- as.character(col_data[!is.na(col_data) & nzchar(trimws(as.character(col_data)))])
      n_distinct <- length(unique(non_na))
      if (n_distinct > 0) {
        first_few <- paste(utils::head(unique(non_na), 3), collapse = ", ")
        val_sample <- msg("inspect_distinct_sample", lang, n_distinct, first_few, repo_root = repo_root)
      } else {
        val_sample <- msg("inspect_all_empty", lang, repo_root = repo_root)
      }
    }
    
    log_out(sprintf("%-30s | %-12s | %9.1f%% | %s", cn, col_type, pct_na, val_sample))
  }
  log_out("\n")
}

# Inspect according to format
if (ext %in% c("xlsx", "xls")) {
  sheets <- readxl::excel_sheets(raw_file)
  log_out(msg("inspect_sheets_found", lang, length(sheets), paste(sheets, collapse = ", "), repo_root = repo_root), "\n")
  for (sh in sheets) {
    df_sheet <- tryCatch(
      as.data.frame(readxl::read_excel(raw_file, sheet = sh, guess_max = 100000)),
      error = function(e) {
        log_out(msg("inspect_read_error", lang, sh, e$message, repo_root = repo_root), "\n")
        NULL
      }
    )
    if (!is.null(df_sheet)) {
      inspect_table(df_sheet, sh)
    }
  }
} else {
  # CSV / delimited
  df_csv <- as.data.frame(readr::read_csv(raw_file, guess_max = 100000, show_col_types = FALSE))
  inspect_table(df_csv, "data")
}

close(rep_con)

record_decision(
  project = project,
  step = "0",
  decision = "Inspected raw data file",
  details = sprintf("Inspected '%s' format .%s. Output report: reports/00_inspection.txt", rel_input_file, ext),
  repo_root = repo_root
)

cat(msg("inspect_complete", lang, report_path, repo_root = repo_root), "\n")
