# ==============================================================================
# DSM-Harness | 00_inspect_data.R: Escudriñador Estructural de Datasets (BYOD)
# ==============================================================================
# OBJETIVO:
# Este script escudriña el dataset provisto (.xlsx, .xls o .csv), analizando
# hojas, columnas, tipos de datos, porcentaje de nulos, identificación estricta
# de claves primarias/foráneas y detección de réplicas analíticas.
#
# Genera un reporte sintético y compacto (estrictamente ≤ 6-8 KB) en:
# 'reports/data_inspection_report.txt' (en proyectos) o
# '01_data/profiles/data_inspection_report.txt' (en raíz).
#
# INSTRUCCIONES PARA EL ALUMNO:
# 1. Abre este script en RStudio (con el proyecto DSM-Harness.Rproj abierto).
# 2. Ejecuta todo el script (presiona el botón 'Source' o Ctrl+Shift+S).
# 3. Avísale a la IA en el chat que ya lo ejecutaste.
# ==============================================================================

# 1. Configuración de rutas y archivo de entrada --------------------------------
proj_active <- if (exists("PROJECT_DIR") && !is.null(PROJECT_DIR) && nzchar(as.character(PROJECT_DIR))) {
  as.character(PROJECT_DIR)
} else if (exists("CURRENT_PROJECT_DIR") && !is.null(CURRENT_PROJECT_DIR) && nzchar(as.character(CURRENT_PROJECT_DIR))) {
  as.character(CURRENT_PROJECT_DIR)
} else if (dir.exists("data") && dir.exists("reports")) {
  "."
} else {
  NULL
}

if (!is.null(proj_active)) {
  default_data_dir <- file.path(proj_active, "data")
  default_rep_dir  <- file.path(proj_active, "reports")
  proj_cfg_file    <- file.path(proj_active, "config.json")
} else {
  default_data_dir <- "01_data/profiles"
  default_rep_dir  <- "01_data/profiles"
  proj_cfg_file    <- file.path(default_data_dir, "user_config.json")
}

# Carga de motor i18n
i18n_candidates <- c(
  if (!is.null(proj_active)) file.path(proj_active, "scripts", "00_i18n.R"),
  if (!is.null(proj_active)) file.path(proj_active, "00_i18n.R"),
  if (!is.null(proj_active)) file.path(proj_active, "02_scripts", "00_i18n.R"),
  "02_scripts/00_i18n.R",
  "scripts/00_i18n.R",
  "00_i18n.R"
)
for (cand in i18n_candidates) {
  if (!is.null(cand) && file.exists(cand)) {
    tryCatch(source(cand, local = FALSE), error = function(e) NULL)
    break
  }
}

lang <- if (exists("get_project_language")) {
  if (file.exists(proj_cfg_file) && requireNamespace("jsonlite", quietly = TRUE)) {
    cfg_tmp <- tryCatch(jsonlite::fromJSON(proj_cfg_file, simplifyVector = FALSE), error = function(e) NULL)
    get_project_language(cfg_tmp)
  } else {
    get_project_language()
  }
} else "es"
is_en <- identical(lang, "en")

if (!exists("input_file") || is.null(input_file) || !nzchar(input_file) || !file.exists(input_file)) {
  input_file <- NULL
  if (file.exists(proj_cfg_file) && requireNamespace("jsonlite", quietly = TRUE)) {
    cfg_tmp <- tryCatch(jsonlite::fromJSON(proj_cfg_file, simplifyVector = FALSE), error = function(e) NULL)
    if (!is.null(cfg_tmp$input_file) && file.exists(as.character(cfg_tmp$input_file))) {
      input_file <- as.character(cfg_tmp$input_file)
    }
  }
}

if (!exists("input_file") || is.null(input_file) || !nzchar(input_file)) {
  avail <- list.files(default_data_dir, pattern = "\\.(xlsx|xls|csv|txt|tsv)$", full.names = TRUE, ignore.case = TRUE)
  avail <- avail[!grepl("(_report\\.txt|step1_.*\\.csv|cleaned_profiles\\.csv|decisions_log|mapping_confirmed|template)", avail)]
  
  if (length(avail) == 1) {
    input_file <- avail[1]
    if (is_en) {
      cat(sprintf("[*] Data file automatically detected: '%s'\n", input_file))
    } else {
      cat(sprintf("[*] Archivo de datos detectado automáticamente: '%s'\n", input_file))
    }
  } else if (length(avail) > 1) {
    if (is_en) {
      cat(sprintf("[NOTICE] Multiple data files found in '%s/':\n", default_data_dir))
      for (i in seq_along(avail)) cat(sprintf("  [%d] %s\n", i, avail[i]))
      cat(sprintf("\nBy default, the first one will be used. To specify another, define in console:\n  input_file <- '%s/your_file.ext'\n\n", default_data_dir))
    } else {
      cat(sprintf("[AVISO] Se encontraron múltiples archivos de datos en '%s/':\n", default_data_dir))
      for (i in seq_along(avail)) cat(sprintf("  [%d] %s\n", i, avail[i]))
      cat(sprintf("\nPor defecto se usará el primero. Para especificar otro, define en consola:\n  input_file <- '%s/tu_archivo.ext'\n\n", default_data_dir))
    }
    input_file <- avail[1]
  } else {
    if (is_en) {
      stop(sprintf("\n[ERROR] No profile dataset found in '%s/'.\nPlease place your dataset (.xlsx or .csv) in that folder and run again.", default_data_dir))
    } else {
      stop(sprintf("\n[ERROR] No se encontró ningún archivo de perfiles en '%s/'.\nPor favor coloca tu dataset (.xlsx o .csv) en esa carpeta y vuelve a ejecutar.", default_data_dir))
    }
  }
}

if (!is.null(proj_active) || !exists("output_report") || is.null(output_report) || !nzchar(output_report)) {
  output_report <- file.path(default_rep_dir, "data_inspection_report.txt")
}

if (!file.exists(input_file)) {
  if (is_en) {
    stop(sprintf("\n[ERROR] File '%s' not found.", input_file))
  } else {
    stop(sprintf("\n[ERROR] No se encontró el archivo '%s'.", input_file))
  }
}

ext <- tolower(tools::file_ext(input_file))
out_dir <- dirname(output_report)
if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)

report_con <- file(output_report, open = "wt", encoding = "UTF-8")

log_line <- function(...) {
  msg <- paste0(...)
  cat(msg, "\n")
  cat(msg, "\n", file = report_con)
}

if (is_en) {
  log_line("================================================================================")
  log_line("  DSM-HARNESS: COMPACT STRUCTURAL INSPECTION REPORT (BYOD)")
  log_line("================================================================================")
  log_line("Date and time:        ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"))
  log_line("Inspected file:       ", input_file)
  log_line("Detected format:      .", ext, sprintf(" (%0.1f KB)", file.size(input_file) / 1024))
  log_line("================================================================================\n")
} else {
  log_line("================================================================================")
  log_line("  DSM-HARNESS: REPORTE COMPACTO DE INSPECCION ESTRUCTURAL (BYOD)")
  log_line("================================================================================")
  log_line("Fecha y hora:         ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"))
  log_line("Archivo inspeccionado: ", input_file)
  log_line("Formato detectado:    .", ext, sprintf(" (%0.1f KB)", file.size(input_file) / 1024))
  log_line("================================================================================\n")
}

# 2. Función de inspección ultra-compacta (≤ 6-8 KB total) -----------------------
inspect_dataframe_compact <- function(df, label = "Tabla") {
  if (is_en) {
    log_line(sprintf(">>> SUMMARY OF %s <<<", toupper(label)))
  } else {
    log_line(sprintf(">>> RESUMEN DE %s <<<", toupper(label)))
  }
  
  if (is.null(df) || nrow(df) == 0 || ncol(df) == 0) {
    if (is_en) {
      log_line("[NOTICE]: Table is empty (0 rows or 0 columns).")
    } else {
      log_line("[AVISO]: La tabla está vacía (0 filas o 0 columnas).")
    }
    log_line("--------------------------------------------------------------------------------\n")
    return(invisible(NULL))
  }
  
  n_rows <- nrow(df)
  n_cols <- ncol(df)
  col_names <- names(df)
  if (is_en) {
    log_line(sprintf("Dimensions: %d rows x %d columns", n_rows, n_cols))
  } else {
    log_line(sprintf("Dimensiones: %d filas x %d columnas", n_rows, n_cols))
  }
  
  col_classes <- sapply(df, function(x) paste(class(x), collapse = "/"))
  col_nas     <- sapply(df, function(x) sum(is.na(x)))
  col_na_pct  <- round((col_nas / n_rows) * 100, 1)
  col_uniques <- sapply(df, function(x) length(unique(na.omit(x))))
  
  # 1. Candidatos estrictos a claves primarias/foráneas
  is_key_pattern <- grepl("^(id|code|codigo|perfil|sitio|profile|site|pedon|calicata|horiz|layer|capa|muestra|sample)$|(_id|_code|_key|_codigo|_nr|_no)$|^(id_|cod_)", 
                          tolower(trimws(col_names)))
  is_true_key <- is_key_pattern & (col_uniques > 2 | n_rows <= 3) & ((col_uniques / pmax(n_rows - col_nas, 1)) > 0.05)
  cand_keys <- col_names[is_true_key]
  
  # 2. Coordenadas espaciales
  is_coord <- grepl("^(x|y|lon|lat|longitude|latitude|este|norte|coord_x|coord_y|x_coord|y_coord)$|(_x|_y|_lon|_lat)$",
                    tolower(trimws(col_names)))
  cand_coords <- col_names[is_coord]
  
  # 3. Profundidades
  is_depth <- grepl("^(top|bottom|upper|lower|desde|hasta|prof_desde|prof_hasta|prof_ini|prof_fin|depth_from|depth_to|depth)$|(_top|_bot|_from|_to|_desde|_hasta)$",
                    tolower(trimws(col_names)))
  cand_depths <- col_names[is_depth]
  
  # 4. Propiedades edafológicas objetivo
  is_soil_prop <- grepl("^(soc|cos|om|mo|humus|ph|clay|arcilla|sand|arena|silt|limo|bd|da|densidad|cec|cic|n|nitrogen|p|fosforo)",
                        tolower(trimws(col_names)))
  cand_props <- col_names[is_soil_prop]
  
  identified_cols <- unique(c(cand_keys, cand_coords, cand_depths, cand_props))
  other_cols <- setdiff(col_names, identified_cols)
  
  # Imprimir sección de Claves
  if (length(cand_keys) > 0) {
    if (is_en) log_line("  [CANDIDATE KEYS / IDS]:") else log_line("  [CLAVES / IDS CANDIDATOS]:")
    for (ck in cand_keys) {
      vals_no_na <- na.omit(df[[ck]])
      n_dup <- sum(duplicated(vals_no_na))
      pct_dup <- if (length(vals_no_na) > 0) round((n_dup / length(vals_no_na)) * 100, 1) else 0
      dup_info <- if (is_en) {
        if (n_dup == 0) "100% unique" else sprintf("%d duplicates (%.1f%%)", n_dup, pct_dup)
      } else {
        if (n_dup == 0) "100% únicos" else sprintf("%d duplicados (%.1f%%)", n_dup, pct_dup)
      }
      lbl_u <- if (is_en) "Unique" else "Únicos"
      log_line(sprintf("    - %-25s | %s: %-6d | NAs: %4.1f%% | %s", ck, lbl_u, col_uniques[ck], col_na_pct[ck], dup_info))
    }
  } else {
    if (is_en) {
      log_line("  [CANDIDATE KEYS / IDS]: No column with ID pattern detected.")
    } else {
      log_line("  [CLAVES / IDS CANDIDATOS]: Ninguna columna con patrón de ID detectada.")
    }
  }
  
  # Imprimir sección de Coordenadas
  if (length(cand_coords) > 0) {
    if (is_en) log_line("  [DETECTED COORDINATES]:") else log_line("  [COORDENADAS DETECTADAS]:")
    for (cc in cand_coords) {
      v <- suppressWarnings(as.numeric(na.omit(df[[cc]])))
      rng_str <- if (length(v) > 0) {
        if (is_en) sprintf("Range: [%g, %g]", round(min(v), 2), round(max(v), 2))
        else sprintf("Rango: [%g, %g]", round(min(v), 2), round(max(v), 2))
      } else {
        if (is_en) "No numeric values" else "Sin valores numéricos"
      }
      log_line(sprintf("    - %-25s | NAs: %4.1f%% | %s", cc, col_na_pct[cc], rng_str))
    }
  }
  
  # Imprimir sección de Profundidades
  if (length(cand_depths) > 0) {
    if (is_en) log_line("  [DEPTH LIMITS]:") else log_line("  [LIMITES DE PROFUNDIDAD]:")
    for (cd in cand_depths) {
      v <- suppressWarnings(as.numeric(na.omit(df[[cd]])))
      rng_str <- if (length(v) > 0) {
        if (is_en) sprintf("Range: [%g, %g] cm", round(min(v), 1), round(max(v), 1))
        else sprintf("Rango: [%g, %g] cm", round(min(v), 1), round(max(v), 1))
      } else {
        if (is_en) "No values" else "Sin valores"
      }
      log_line(sprintf("    - %-25s | NAs: %4.1f%% | %s", cd, col_na_pct[cd], rng_str))
    }
  }
  
  # Imprimir sección de Propiedades Edafológicas
  if (length(cand_props) > 0) {
    if (is_en) log_line("  [KEY SOIL PROPERTIES]:") else log_line("  [PROPIEDADES EDAFOLÓGICAS CLAVE]:")
    for (cp in cand_props) {
      v <- suppressWarnings(as.numeric(na.omit(df[[cp]])))
      stats_str <- if (length(v) > 0) sprintf("Min: %g | Med: %g | Max: %g", round(min(v), 2), round(median(v), 2), round(max(v), 2))
                   else (if (is_en) "Text / No numeric values" else "Texto / Sin numéricos")
      log_line(sprintf("    - %-25s | NAs: %4.1f%% | %s", cp, col_na_pct[cp], stats_str))
    }
  }
  
  # Resumen de otras columnas (en una línea o dos compactas)
  if (length(other_cols) > 0) {
    lbl_oth <- if (is_en) "OTHER COLUMNS" else "OTRAS COLUMNAS"
    log_line(sprintf("  [%s (%d)]: %s", lbl_oth, length(other_cols), paste(head(other_cols, 20), collapse = ", ")))
    if (length(other_cols) > 20) {
      if (is_en) {
        log_line(sprintf("    (... and %d additional columns)", length(other_cols) - 20))
      } else {
        log_line(sprintf("    (... y %d columnas adicionales)", length(other_cols) - 20))
      }
    }
  }
  log_line("--------------------------------------------------------------------------------\n")
}

# 3. Procesamiento según formato -----------------------------------------------
if (ext %in% c("xlsx", "xls")) {
  if (!requireNamespace("readxl", quietly = TRUE)) {
    if (is_en) {
      stop("The 'readxl' package is required to read Excel files. Install with install.packages('readxl').")
    } else {
      stop("La librería 'readxl' es necesaria para leer archivos Excel. Instala con install.packages('readxl').")
    }
  }
  
  sheets <- readxl::excel_sheets(input_file)
  if (is_en) {
    log_line(sprintf("EXCEL STRUCTURE: File contains %d sheet(s): [%s]\n", 
                     length(sheets), paste(paste0("'", sheets, "'"), collapse = ", ")))
  } else {
    log_line(sprintf("ESTRUCTURA EXCEL: El archivo contiene %d hoja(s): [%s]\n", 
                     length(sheets), paste(paste0("'", sheets, "'"), collapse = ", ")))
  }
  
  for (s_name in sheets) {
    df_sheet <- tryCatch(
      readxl::read_excel(input_file, sheet = s_name, guess_max = 100000),
      error = function(e) {
        if (is_en) {
          log_line("[ERROR reading sheet '", s_name, "']: ", e$message)
        } else {
          log_line("[ERROR al leer hoja '", s_name, "']: ", e$message)
        }
        NULL
      }
    )
    
    if (!is.null(df_sheet)) {
      lbl_sh <- if (is_en) paste("Sheet:", s_name) else paste("Hoja:", s_name)
      inspect_dataframe_compact(df_sheet, label = lbl_sh)
    }
  }
  
} else if (ext %in% c("csv", "txt", "tsv")) {
  first_lines <- readLines(input_file, n = 5, warn = FALSE)
  delim <- ","
  if (length(first_lines) > 0) {
    semis  <- sum(gregexpr(";", first_lines[[1]])[[1]] > 0)
    commas <- sum(gregexpr(",", first_lines[[1]])[[1]] > 0)
    tabs   <- sum(gregexpr("\t", first_lines[[1]])[[1]] > 0)
    if (semis > commas && semis > tabs) delim <- ";"
    if (tabs > commas && tabs > semis) delim <- "\t"
  }
  if (is_en) {
    log_line(sprintf("TEXT STRUCTURE: Detected delimiter: '%s'\n", delim))
  } else {
    log_line(sprintf("ESTRUCTURA TEXTO: Delimitador detectado: '%s'\n", delim))
  }
  
  df_csv <- tryCatch(
    read.table(input_file, header = TRUE, sep = delim, stringsAsFactors = FALSE, 
               check.names = FALSE, fill = TRUE, quote = "\""),
    error = function(e) {
      if (is_en) {
        log_line("[ERROR reading file]: ", e$message)
      } else {
        log_line("[ERROR al leer archivo]: ", e$message)
      }
      NULL
    }
  )
  
  if (!is.null(df_csv)) {
    lbl_f <- if (is_en) paste("File:", basename(input_file)) else paste("Archivo:", basename(input_file))
    inspect_dataframe_compact(df_csv, label = lbl_f)
  }
} else {
  if (is_en) {
    log_line("[ERROR]: Unrecognized format. Please provide a .xlsx, .xls or .csv file.")
  } else {
    log_line("[ERROR]: Formato no reconocido. Por favor proporciona un archivo .xlsx, .xls o .csv.")
  }
}

log_line("================================================================================")
if (is_en) {
  log_line("  END OF COMPACT INSPECTION REPORT")
} else {
  log_line("  FIN DEL REPORTE DE INSPECCIÓN COMPACTO")
}
log_line("================================================================================")
close(report_con)

if (is_en) {
  cat(sprintf("\n[OK] Compact report generated at: %s (%0.1f KB)\n", output_report, file.size(output_report) / 1024))
  cat("--------------------------------------------------------------------------------\n")
  cat("INSTRUCTION FOR STUDENT:\n")
  cat("Notify the AI in chat that you ran '00_inspect_data.R'.\n")
  cat("The AI will natively read the report to agree on mapping decisions with you.\n")
  cat("--------------------------------------------------------------------------------\n\n")
} else {
  cat(sprintf("\n[OK] Reporte compacto generado en: %s (%0.1f KB)\n", output_report, file.size(output_report) / 1024))
  cat("--------------------------------------------------------------------------------\n")
  cat("INSTRUCCIÓN PARA EL ALUMNO:\n")
  cat("Avísale a la IA en el chat que ya ejecutaste '00_inspect_data.R'.\n")
  cat("La IA leerá nativamente el reporte para acordar contigo las decisiones de mapeo.\n")
  cat("--------------------------------------------------------------------------------\n\n")
}
