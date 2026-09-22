# ==============================================================================
# DSM-Harness | Dataset Inspector & Profiler (R Fallback)
# ==============================================================================
# Usage: Rscript inspect_dataset.R <path_to_file>
# ==============================================================================

args <- commandArgs(trailingOnly = TRUE)
if (length(args) == 0) {
  stop("Usage: Rscript inspect_dataset.R <path_to_file>")
}

file_path <- args[1]
if (!file.exists(file_path)) {
  stop(sprintf("File not found: %s", file_path))
}

ext <- tolower(tools::file_ext(file_path))

if (ext %in% c("xlsx", "xls")) {
  if (!requireNamespace("readxl", quietly = TRUE)) {
    stop("Package 'readxl' is required to inspect Excel files.")
  }
  
  sheets <- readxl::excel_sheets(file_path)
  cat(sprintf("\n=== EXCEL DATASET INSPECTION: %s ===\n", file_path))
  cat(sprintf("Total Sheets: %d [%s]\n\n", length(sheets), paste(sheets, collapse = ", ")))
  
  for (s in sheets) {
    df_sample <- tryCatch(
      readxl::read_excel(file_path, sheet = s, n_max = 3),
      error = function(e) NULL
    )
    if (!is.null(df_sample)) {
      cat(sprintf("--- Sheet: '%s' ---\n", s))
      cat(sprintf("Columns (%d): %s\n", ncol(df_sample), paste(names(df_sample), collapse = ", ")))
      cat("Sample values (first row):\n")
      for (col in names(df_sample)) {
        val <- as.character(df_sample[[col]][1])
        cat(sprintf("  * %s = %s\n", col, ifelse(is.na(val), "NA", val)))
      }
      cat("\n")
    }
  }
} else if (ext == "csv") {
  cat(sprintf("\n=== CSV DATASET INSPECTION: %s ===\n", file_path))
  df_sample <- read.csv(file_path, nrows = 3, stringsAsFactors = FALSE)
  cat(sprintf("Columns (%d): %s\n", ncol(df_sample), paste(names(df_sample), collapse = ", ")))
  cat("Sample values (first row):\n")
  for (col in names(df_sample)) {
    val <- as.character(df_sample[[col]][1])
    cat(sprintf("  * %s = %s\n", col, ifelse(is.na(val), "NA", val)))
  }
} else {
  stop(sprintf("Unsupported file format: .%s", ext))
}
