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
  stop("Step 0 must be run within a project context (e.g., run_step('0', project = 'myproj'))")
}

proj_root <- file.path(repo_root, "projects", project)
lang <- if (exists("lang", inherits = FALSE) && !is.null(lang)) lang else "en"

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
  # Exclude fixed output files
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
log_out("Date: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"))
log_out("Project: ", project)
log_out("File: ", rel_input_file)
log_out("Format: .", ext)
log_out("File size: ", round(file.size(raw_file) / 1024, 2), " KB")
log_out("================================================================================\n")

# Inspection helper
inspect_table <- function(df, tbl_name) {
  log_out(sprintf("--- Sheet / Table: %s ---", tbl_name))
  log_out(sprintf("Dimensions: %d rows x %d columns\n", nrow(df), ncol(df)))
  
  if (nrow(df) == 0 || ncol(df) == 0) {
    log_out("Table is empty (0 rows or 0 columns).\n")
    return()
  }
  
  col_names <- names(df)
  log_out(sprintf("%-30s | %-12s | %-10s | %s", "Column Name", "Type", "% Missing", "Range / Distinct Samples"))
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
        val_sample <- "[All NA]"
      }
    } else {
      non_na <- as.character(col_data[!is.na(col_data) & nzchar(trimws(as.character(col_data)))])
      n_distinct <- length(unique(non_na))
      if (n_distinct > 0) {
        first_few <- paste(utils::head(unique(non_na), 3), collapse = ", ")
        val_sample <- sprintf("%d distinct (e.g. %s)", n_distinct, first_few)
      } else {
        val_sample <- "[All NA/empty]"
      }
    }
    
    log_out(sprintf("%-30s | %-12s | %9.1f%% | %s", cn, col_type, pct_na, val_sample))
  }
  log_out("\n")
}

# Inspect according to format
if (ext %in% c("xlsx", "xls")) {
  sheets <- readxl::excel_sheets(raw_file)
  log_out("Detected sheets (", length(sheets), "): ", paste(sheets, collapse = ", "), "\n")
  for (sh in sheets) {
    df_sheet <- tryCatch(
      as.data.frame(readxl::read_excel(raw_file, sheet = sh, guess_max = 100000)),
      error = function(e) {
        log_out(sprintf("Error reading sheet '%s': %s\n", sh, e$message))
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
