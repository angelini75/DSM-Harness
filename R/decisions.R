# ==============================================================================
# DSM-Harness v2 | decisions.R
# Shared decision logging for project audit tracking
# ==============================================================================

record_decision <- function(project, step, decision, details, repo_root = NULL) {
  if (is.null(repo_root)) {
    if (exists("find_repo_root", mode = "function")) {
      repo_root <- find_repo_root()
    } else {
      repo_root <- getwd()
    }
  }
  
  proj_dir <- file.path(repo_root, "projects", project)
  if (!dir.exists(proj_dir)) {
    dir.create(proj_dir, recursive = TRUE)
  }
  
  log_file <- file.path(proj_dir, "decisions_log.csv")
  
  entry <- data.frame(
    timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    step = as.character(step),
    decision = as.character(decision),
    details = as.character(details),
    stringsAsFactors = FALSE
  )
  
  if (file.exists(log_file)) {
    utils::write.table(
      entry,
      file = log_file,
      sep = ",",
      row.names = FALSE,
      col.names = FALSE,
      append = TRUE,
      qmethod = "double"
    )
  } else {
    utils::write.table(
      entry,
      file = log_file,
      sep = ",",
      row.names = FALSE,
      col.names = TRUE,
      append = FALSE,
      qmethod = "double"
    )
  }
}
