# ==============================================================================
# DSM-Harness | 00_inspect_data.R: Escudriñador Estructural de Datasets (BYOD)
# ==============================================================================
# OBJETIVO:
# Este script escudriña el dataset provisto (.xlsx, .xls o .csv), analizando
# hojas, columnas, tipos de datos, porcentaje de nulos, identificación estricta
# de claves primarias/foráneas y detección de réplicas analíticas.
#
# Genera un reporte sintético y compacto (≤ 6-8 KB) en:
# '01_data/profiles/data_inspection_report.txt'
# optimizado para no agotar la cuota de tokens en el diálogo con la IA.
#
# INSTRUCCIONES PARA EL ALUMNO:
# 1. Abre este script en RStudio (con el proyecto DSM-Harness.Rproj abierto).
# 2. Ejecuta todo el script (presiona el botón 'Source' o Ctrl+Shift+S).
# 3. Avísale a la IA en el chat que ya lo ejecutaste.
# ==============================================================================

# 1. Configuración del archivo de entrada ---------------------------------------
if (!exists("input_file") || is.null(input_file) || !nzchar(input_file)) {
  avail <- list.files("01_data/profiles", pattern = "\\.(xlsx|xls|csv|txt|tsv)$", full.names = TRUE, ignore.case = TRUE)
  avail <- avail[!grepl("(_report\\.txt|step1_.*\\.csv|cleaned_profiles\\.csv|decisions_log|mapping_confirmed|template)", avail)]
  
  if (length(avail) == 1) {
    input_file <- avail[1]
    cat(sprintf("[*] Archivo de datos detectado automáticamente: '%s'\n", input_file))
  } else if (length(avail) > 1) {
    cat("[AVISO] Se encontraron múltiples archivos de datos en '01_data/profiles/':\n")
    for (i in seq_along(avail)) cat(sprintf("  [%d] %s\n", i, avail[i]))
    cat("\nPor defecto se usará el primero. Para especificar otro, define en la consola:\n  input_file <- '01_data/profiles/tu_archivo.ext'\n\n")
    input_file <- avail[1]
  } else {
    stop("\n[ERROR] No se encontró ningún archivo de perfiles en '01_data/profiles/'.\nPor favor coloca tu dataset (.xlsx o .csv) en esa carpeta y vuelve a ejecutar.")
  }
}
rm(list = setdiff(ls(), c("input_file", "output_report")))

if (!exists("output_report")) {
  output_report <- "01_data/profiles/data_inspection_report.txt"
}

if (!file.exists(input_file)) {
  stop(sprintf("\n[ERROR] No se encontró el archivo '%s'.", input_file))
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

log_line("================================================================================")
log_line("  DSM-HARNESS: REPORTE COMPACTO DE INSPECCIÓN ESTRUCTURAL (BYOD)")
log_line("================================================================================")
log_line("Fecha y hora:         ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"))
log_line("Archivo inspeccionado: ", input_file)
log_line("Formato detectado:    .", ext, sprintf(" (%0.1f KB)", file.size(input_file) / 1024))
log_line("================================================================================\n")

# 2. Función de inspección estricta y compacta ----------------------------------
inspect_dataframe_compact <- function(df, label = "Tabla") {
  log_line(sprintf(">>> RESUMEN DE %s <<<", toupper(label)))
  
  if (is.null(df) || nrow(df) == 0 || ncol(df) == 0) {
    log_line("[AVISO]: La tabla está vacía (0 filas o 0 columnas).")
    log_line("--------------------------------------------------------------------------------\n")
    return(invisible(NULL))
  }
  
  n_rows <- nrow(df)
  n_cols <- ncol(df)
  col_names <- names(df)
  log_line(sprintf("Dimensiones: %d filas x %d columnas", n_rows, n_cols))
  log_line("--------------------------------------------------------------------------------")
  
  # Clasificación de roles de columnas
  col_classes <- sapply(df, function(x) paste(class(x), collapse = "/"))
  col_nas     <- sapply(df, function(x) sum(is.na(x)))
  col_na_pct  <- round((col_nas / n_rows) * 100, 1)
  col_uniques <- sapply(df, function(x) length(unique(na.omit(x))))
  
  # Identificación estricta de candidatos a clave (evitando columnas categóricas)
  is_key_pattern <- grepl("^(id|code|codigo|perfil|sitio|profile|site|pedon|calicata|horiz|layer|capa|muestra|sample)$|(_id|_code|_key|_codigo|_nr|_no)$|^(id_|cod_)", 
                          tolower(trimws(col_names)))
  # Un identificador genuino no puede tener 1 o 2 valores únicos si la tabla tiene muchas filas (salvo tablas diminutas)
  is_true_key_candidate <- is_key_pattern & (col_uniques > 2 | n_rows <= 3) & ((col_uniques / pmax(n_rows - col_nas, 1)) > 0.05)
  
  suggested_role <- ifelse(is_true_key_candidate, "ID/Clave",
                           ifelse(sapply(df, is.numeric), "Numérica", "Texto/Cat"))
  
  # Imprimir tabla sintética
  max_w <- min(max(c(nchar(col_names), 16), na.rm = TRUE), 35)
  fmt_head <- sprintf("%%-3s | %%-%ds | %%-10s | %%-7s | %%-7s | %%-10s", max_w)
  fmt_row  <- sprintf("%%-3d | %%-%ds | %%-10s | %%-6.1f%%%% | %%-7d | %%-10s", max_w)
  sep_line <- paste(rep("-", max_w + 48), collapse = "")
  
  log_line(sprintf(fmt_head, "No.", "Columna", "Clase", "% NAs", "Únicos", "Rol"))
  log_line(sep_line)
  
  for (i in seq_along(col_names)) {
    c_disp <- if (nchar(col_names[i]) > max_w) paste0(substr(col_names[i], 1, max_w - 3), "...") else col_names[i]
    log_line(sprintf(fmt_row, i, c_disp, col_classes[i], col_na_pct[i], col_uniques[i], suggested_role[i]))
  }
  log_line(sep_line)
  log_line("")
  
  # Auditoría enfocada de duplicados en ID/Claves candidatas reales
  cand_keys <- col_names[is_true_key_candidate]
  if (length(cand_keys) > 0) {
    log_line("--- CLAVES CANDIDATAS Y AUDITORÍA DE RÉPLICAS/DUPLICADOS ---")
    any_dup <- FALSE
    for (ck in cand_keys) {
      vals_no_na <- na.omit(df[[ck]])
      n_dup <- sum(duplicated(vals_no_na))
      if (n_dup > 0) {
        any_dup <- TRUE
        pct_dup <- round((n_dup / length(vals_no_na)) * 100, 1)
        dup_vals <- unique(vals_no_na[duplicated(vals_no_na)])
        ex_str <- paste(as.character(head(dup_vals, 3)), collapse = ", ")
        log_line(sprintf("  [ALERTA CLAVE DUPLICADA] '%s': %d filas repetidas (%.1f%%). Ej: [%s]",
                         ck, n_dup, pct_dup, ex_str))
      } else {
        log_line(sprintf("  [OK CLAVE ÚNICA] '%s': 100%% valores únicos (%d registros).", ck, length(vals_no_na)))
      }
    }
    if (any_dup) {
      log_line("  -> NOTA: Si corresponde a réplicas de laboratorio, el Paso 1.1 permite promediar o marcar banderas.\n")
    } else {
      log_line("")
    }
  }
  
  # Resumen compacto de variables numéricas relevantes (Min / Media / Max)
  num_cols <- col_names[sapply(df, is.numeric)]
  if (length(num_cols) > 0) {
    log_line("--- RESUMEN DE VARIABLES NUMÉRICAS (Mín / Mediana / Máx) ---")
    # Priorizar variables edafológicas o mostrar hasta 15
    for (nc in head(num_cols, 15)) {
      v <- na.omit(df[[nc]])
      if (length(v) > 0) {
        log_line(sprintf("  %-30s : Mín = %g | Med = %g | Máx = %g", 
                         nc, round(min(v), 2), round(median(v), 2), round(max(v), 2)))
      }
    }
    if (length(num_cols) > 15) {
      log_line(sprintf("  (... y %d variables numéricas adicionales)", length(num_cols) - 15))
    }
    log_line("")
  }
}

# 3. Procesamiento según formato -----------------------------------------------
if (ext %in% c("xlsx", "xls")) {
  if (!requireNamespace("readxl", quietly = TRUE)) {
    stop("La librería 'readxl' es necesaria para leer archivos Excel. Instala con install.packages('readxl').")
  }
  
  sheets <- readxl::excel_sheets(input_file)
  log_line(sprintf("ESTRUCTURA EXCEL: El archivo contiene %d hoja(s): [%s]\n", 
                   length(sheets), paste(paste0("'", sheets, "'"), collapse = ", ")))
  
  for (s_name in sheets) {
    log_line("================================================================================")
    log_line(sprintf("HOJA EXCEL: '%s'", s_name))
    log_line("================================================================================")
    
    df_sheet <- tryCatch(
      readxl::read_excel(input_file, sheet = s_name, guess_max = 100000),
      error = function(e) {
        log_line("[ERROR al leer hoja '", s_name, "']: ", e$message)
        NULL
      }
    )
    
    if (!is.null(df_sheet)) {
      inspect_dataframe_compact(df_sheet, label = paste("Hoja:", s_name))
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
  log_line(sprintf("ESTRUCTURA TEXTO: Delimitador detectado: '%s'\n", delim))
  
  df_csv <- tryCatch(
    read.table(input_file, header = TRUE, sep = delim, stringsAsFactors = FALSE, 
               check.names = FALSE, fill = TRUE, quote = "\""),
    error = function(e) {
      log_line("[ERROR al leer archivo]: ", e$message)
      NULL
    }
  )
  
  if (!is.null(df_csv)) {
    inspect_dataframe_compact(df_csv, label = paste("Archivo:", basename(input_file)))
  }
} else {
  log_line("[ERROR]: Formato no reconocido. Por favor proporciona un archivo .xlsx, .xls o .csv.")
}

log_line("================================================================================")
log_line("  FIN DEL REPORTE DE INSPECCIÓN COMPACTO")
log_line("================================================================================")
close(report_con)

cat(sprintf("\n[OK] Reporte compacto generado en: %s (%0.1f KB)\n", output_report, file.size(output_report) / 1024))
cat("--------------------------------------------------------------------------------\n")
cat("INSTRUCCIÓN PARA EL ALUMNO:\n")
cat("Avísale a la IA en el chat que ya ejecutaste '00_inspect_data.R'.\n")
cat("La IA leerá nativamente el reporte para acordar contigo las decisiones de mapeo.\n")
cat("--------------------------------------------------------------------------------\n\n")
