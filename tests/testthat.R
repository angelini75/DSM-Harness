library(testthat)

repo_root <- normalizePath(".", winslash = "/", mustWork = FALSE)
testthat::test_dir(file.path(repo_root, "tests", "testthat"), stop_on_failure = TRUE)
