test_that("i18n catalogue has full key parity between en.yml and es.yml", {
  en_path <- file.path(repo_root, "02_scripts", "i18n", "en.yml")
  es_path <- file.path(repo_root, "02_scripts", "i18n", "es.yml")
  
  expect_true(file.exists(en_path))
  expect_true(file.exists(es_path))
  
  en_keys <- names(yaml::read_yaml(en_path))
  es_keys <- names(yaml::read_yaml(es_path))
  
  missing_in_es <- setdiff(en_keys, es_keys)
  missing_in_en <- setdiff(es_keys, en_keys)
  
  expect_equal(missing_in_es, character(0))
  expect_equal(missing_in_en, character(0))
})

test_that("Static check: no uncatalogued literal strings in script outputs or errors", {
  script_files <- c(
    file.path(repo_root, "02_scripts", "00_inspect_data.R"),
    file.path(repo_root, "02_scripts", "01_1_byod_audit.R"),
    file.path(repo_root, "02_scripts", "01_2_byod_audit.R"),
    file.path(repo_root, "02_scripts", "01_3_byod_audit.R")
  )
  
  # 1. Verify that stop() calls in scripts do NOT take hardcoded literal strings
  for (sf in script_files) {
    expect_true(file.exists(sf))
    lines <- readLines(sf)
    for (i in seq_along(lines)) {
      l <- lines[i]
      if (grepl("^\\s*#", l)) next
      if (grepl("stop\\s*\\(", l)) {
        is_literal_stop <- grepl('stop\\s*\\(\\s*["\']', l)
        expect_false(
          is_literal_stop,
          info = sprintf("Literal string in stop() at %s:%d: %s", basename(sf), i, l)
        )
      }
    }
  }
  
  # 2. Patterns of English sentences that should be catalogued instead of hard-coded
  suspicious_patterns <- c(
    "Inspection completed",
    "Mapping completed",
    "Spatial audit completed",
    "Pedological audit completed",
    "Coordinates appear to be",
    "Identified Profile sheet",
    "Merged table dimensions",
    "Invalid depth intervals",
    "No data file found",
    "Join key error",
    "No non-NA coordinates",
    "Depth columns.*not found",
    "must be run within a project context"
  )
  
  for (sf in script_files) {
    lines <- readLines(sf)
    for (pat in suspicious_patterns) {
      matches <- grep(pat, lines, value = TRUE)
      active_matches <- matches[!grepl("^\\s*#", matches)]
      expect_equal(
        length(active_matches), 0,
        info = sprintf("Found hardcoded sentence '%s' in %s: %s", pat, basename(sf), paste(active_matches, collapse = "; "))
      )
    }
  }
})
