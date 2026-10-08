test_that("Step 0 inspects CSV and 2-sheet Excel datasets", {
  # 1. Test CSV inspection
  proj_csv <- "test_inspect_csv"
  cleanup_test_project(proj_csv)
  on.exit(cleanup_test_project(proj_csv), add = TRUE)
  
  create_synthetic_dataset(proj_csv, format = "csv")
  res_csv <- run_step("0", project = proj_csv)
  
  expect_true(res_csv)
  rep_csv_file <- file.path(repo_root, "projects", proj_csv, "reports", "00_inspection.txt")
  expect_true(file.exists(rep_csv_file))
  
  csv_content <- readLines(rep_csv_file)
  expect_true(any(grepl("Column Name", csv_content)))
  expect_true(any(grepl("soc", csv_content)))
  expect_true(any(grepl("upper", csv_content)))
  
  # 2. Test Excel inspection (multi-sheet)
  proj_xlsx <- "test_inspect_xlsx"
  cleanup_test_project(proj_xlsx)
  on.exit(cleanup_test_project(proj_xlsx), add = TRUE)
  
  create_synthetic_dataset(proj_xlsx, format = "excel")
  res_xlsx <- run_step("0", project = proj_xlsx)
  
  expect_true(res_xlsx)
  rep_xlsx_file <- file.path(repo_root, "projects", proj_xlsx, "reports", "00_inspection.txt")
  expect_true(file.exists(rep_xlsx_file))
  
  xlsx_content <- readLines(rep_xlsx_file)
  expect_true(any(grepl("Sheet / Table: profiles", xlsx_content)))
  expect_true(any(grepl("Sheet / Table: horizons", xlsx_content)))
  expect_true(any(grepl("elevation", xlsx_content)))
  expect_true(any(grepl("clay", xlsx_content)))
})
