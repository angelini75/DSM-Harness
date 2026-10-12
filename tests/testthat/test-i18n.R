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
    file.path(repo_root, "02_scripts", "01_3_byod_audit.R"),
    file.path(repo_root, "02_scripts", "02_covariates.R"),
    file.path(repo_root, "02_scripts", "03_model.R"),
    file.path(repo_root, "02_scripts", "03_b_resources.R")
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
  
  # 2. Verify that log_out() calls only pass dividers or standard tag prefixes if using literal strings
  for (sf in script_files) {
    lines <- readLines(sf)
    for (i in seq_along(lines)) {
      l <- lines[i]
      if (grepl("^\\s*#", l)) next
      if (grepl("log_out\\s*\\(", l)) {
        lit_match <- regmatches(l, regexpr('log_out\\s*\\(\\s*["\'][^"\']+["\']', l))
        if (length(lit_match) > 0) {
          content <- gsub('^log_out\\s*\\(\\s*["\']|["\']$', '', lit_match)
          content_clean <- gsub('\\\\n', '', content)
          is_allowed <- (nchar(content_clean) == 0) ||
                        grepl('^[= -]+$', content_clean) ||
                        grepl('^\\[(ERROR|NOTICE|INFO|IMPUTACI..N)\\] ?$', content_clean)
          expect_true(
            is_allowed,
            info = sprintf("Non-divider literal string in log_out() at %s:%d: %s", basename(sf), i, l)
          )
        }
      }
    }
  }

  # 3. Patterns of English sentences that should be catalogued instead of hard-coded
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
    "must be run within a project context",
    "HARDWARE ENVIRONMENT:",
    "COVARIATE RASTER VOLUME:",
    "MODEL ARTIFACTS:",
    "STEP 4 TILING ADVISORY:",
    "CRS mismatch",
    "Resolution mismatch",
    "Extent mismatch",
    "No profiles have sufficient depth support"
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

test_that("es.yml loads correctly with UTF-8 encoding even when LC_CTYPE is C", {
  old_lc <- Sys.getlocale("LC_CTYPE")
  on.exit(try(Sys.setlocale("LC_CTYPE", old_lc), silent = TRUE), add = TRUE)
  try(Sys.setlocale("LC_CTYPE", "C"), silent = TRUE)
  
  # Clear cache to force fresh disk reload
  if (exists(".i18n_cache", mode = "environment")) {
    rm(list = ls(envir = .i18n_cache), envir = .i18n_cache)
  }
  
  cat_es <- load_catalog("es", repo_root = repo_root)
  expect_true(is.list(cat_es))
  expect_true(length(cat_es) > 0)
  
  # Check Spanish accented characters decode intact
  expect_true(grepl("SELECCIÓN", cat_es$model_header, fixed = TRUE))
  expect_true(grepl("ENTORNO DE HARDWARE:", cat_es$res_sec_hardware, fixed = TRUE))
  expect_true(grepl("Categoría", cat_es$val_invalid_category, fixed = TRUE))
  expect_true(grepl("inválida", cat_es$val_invalid_category, fixed = TRUE))
  expect_true(grepl("extensión", cat_es$cov_outside_raster, fixed = TRUE))
})


