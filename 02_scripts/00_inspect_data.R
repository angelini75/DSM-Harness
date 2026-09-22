# ==============================================================================
# DSM-Harness | 00_inspect_data.R: Escudriñador de Dataset de Entrada (BYOD)
# ==============================================================================
# OBJETIVO:
# Este script escudriña el archivo de datos provisto (sea Excel con múltiples
# hojas o CSV), analizando estructura, número de hojas, nombres de columnas,
# tipos de datos (class), muestras iniciales (head) y finales (tail), valores
# nulos y resúmenes estadísticos.
#
# El resultado se imprime en la consola de RStudio y se guarda automáticamente
# en '01_data/profiles/data_inspection_report.txt'.
# La IA utilizará ese reporte descriptivo para diseñar a medida tu script
# de auditoría y preparación '02_scripts/01_byod_audit.R'.
#
# INSTRUCCIONES PARA EL ALUMNO:
# 1. Abre este script en RStudio (con el proyecto DSM-Harness.Rproj abierto).
# 2. Verifica abajo que 'input_file' apunte a tu archivo.
# 3. Ejecuta todo el script (presiona el botón 'Source' o Ctrl+Shift+S).
# 4. Cuando termine, avísale a la IA en el chat que ya lo ejecutaste.
# ==============================================================================

# 1. Configuración del archivo de entrada ---------------------------------------
if (!exists("input_file")) {
  input_file <- "01_data/profiles/Profiles_data.xlsx"
}
rm(list = setdiff(ls(), c("input_file", "output_report")))

# Archivo de salida donde se guardará el reporte descriptivo
if (!exists("output_report")) {
  output_report <- "01_data/profiles/data_inspection_report.txt"
}

# ------------------------------------------------------------------------------
# 2. Verificación de existencia del archivo
# ------------------------------------------------------------------------------
if (!file.exists(input_file)) {
  # Si la ruta exacta no existe, buscar alternativas en 01_data/profiles/
  avail <- list.files("01_data/profiles", pattern = "\\.(xlsx|xls|csv|txt)$", full.names = TRUE)
  # Excluir el reporte si ya existiera
  avail <- avail[!grepl("data_inspection_report\\.txt$", avail)]
  
  if (length(avail) > 0) {
    cat(sprintf("[AVISO] No se encontro '%s'. Usando archivo detectado: '%s'\n", input_file, avail[1]))
    input_file <- avail[1]
  } else {
    stop(sprintf("\n[ERROR] No se encontro el archivo '%s' ni ningun archivo en '01_data/profiles/'.\nPor favor verifica la ruta de tu archivo.", input_file))
  }
}

ext <- tolower(tools::file_ext(input_file))

# Crear carpeta de salida si no existe
out_dir <- dirname(output_report)
if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)

# Iniciar captura de texto para consola y archivo simultáneamente
report_con <- file(output_report, open = "wt", encoding = "UTF-8")

log_line <- function(...) {
  msg <- paste0(...)
  cat(msg, "\n")
  cat(msg, "\n", file = report_con)
}

log_line("================================================================================")
log_line("  DSM-HARNESS: REPORTE DESCRIPTIVO ESTRUCTURAL DEL DATASET")
log_line("================================================================================")
log_line("Fecha y hora: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"))
log_line("Archivo inspeccionado: ", input_file)
log_line("Formato detectado: .", ext)
log_line("Tamano del archivo: ", round(file.size(input_file) / 1024, 2), " KB")
log_line("================================================================================\n")

# ------------------------------------------------------------------------------
# 3. Procesamiento según formato: Excel (.xlsx, .xls) o CSV (.csv, .txt)
# ------------------------------------------------------------------------------

inspect_dataframe <- function(df, label = "Tabla") {
  log_line(sprintf(">>> RESUMEN DE %s <<<", toupper(label)))
  log_line(sprintf("Dimensiones: %d filas x %d columnas", nrow(df), ncol(df)))
  log_line("--------------------------------------------------------------------------------")
  
  col_info <- data.frame(
    Columna = names(df),
    Clase = sapply(df, function(x) paste(class(x), collapse = "/")),
    Nulos = sapply(df, function(x) sum(is.na(x))),
    Nulos_Pct = round(sapply(df, function(x) mean(is.na(x)) * 100), 1),
    Valores_Unicos = sapply(df, function(x) length(unique(na.omit(x)))),
    stringsAsFactors = FALSE
  )
  
  log_line(sprintf("%-4s | %-25s | %-12s | %-8s | %-7s | %-12s", 
                   "No.", "Nombre Columna", "Clase", "NAs", "% NAs", "Unicos"))
  log_line(paste(rep("-", 78), collapse = ""))
  for (i in seq_len(nrow(col_info))) {
    log_line(sprintf("%-4d | %-25s | %-12s | %-8d | %-6.1f%% | %-12d", 
                     i, 
                     substr(col_info$Columna[i], 1, 25), 
                     col_info$Clase[i], 
                     col_info$Nulos[i], 
                     col_info$Nulos_Pct[i], 
                     col_info$Valores_Unicos[i]))
  }
  log_line("--------------------------------------------------------------------------------\n")
  
  # Primeras 3 filas (head)
  log_line("--- MUESTRA INICIAL: HEAD (Primeras 3 filas) ---")
  head_df <- head(df, 3)
  for (col in names(head_df)) {
    vals <- paste(as.character(head_df[[col]]), collapse = " | ")
    log_line(sprintf("  %-25s : %s", substr(col, 1, 25), vals))
  }
  log_line("")
  
  # Ultimas 3 filas (tail)
  log_line("--- MUESTRA FINAL: TAIL (Ultimas 3 filas) ---")
  tail_df <- tail(df, 3)
  for (col in names(tail_df)) {
    vals <- paste(as.character(tail_df[[col]]), collapse = " | ")
    log_line(sprintf("  %-25s : %s", substr(col, 1, 25), vals))
  }
  log_line("")
  
  # Resumen numerico rapido para columnas numericas
  num_cols <- names(df)[sapply(df, is.numeric)]
  if (length(num_cols) > 0) {
    log_line("--- RANGOS DE VARIABLES NUMERICAS (Min / Mediana / Max) ---")
    for (nc in num_cols) {
      vals <- df[[nc]][!is.na(df[[nc]])]
      if (length(vals) > 0) {
        log_line(sprintf("  %-25s : Min = %g | Mediana = %g | Max = %g", 
                         substr(nc, 1, 25), min(vals), median(vals), max(vals)))
      } else {
        log_line(sprintf("  %-25s : (Todos los valores son NA)", substr(nc, 1, 25)))
      }
    }
    log_line("")
  }
}

if (ext %in% c("xlsx", "xls")) {
  if (!requireNamespace("readxl", quietly = TRUE)) {
    stop("La libreria 'readxl' es necesaria para leer archivos Excel. Instala con install.packages('readxl').")
  }
  
  sheets <- readxl::excel_sheets(input_file)
  log_line(sprintf("ESTRUCTURA EXCEL: El archivo contiene %d hoja(s): [%s]\n", 
                   length(sheets), paste(paste0("'", sheets, "'"), collapse = ", ")))
  
  for (s_name in sheets) {
    log_line("================================================================================")
    log_line(sprintf("HOJA EXCEL: '%s'", s_name))
    log_line("================================================================================")
    
    df_sheet <- tryCatch(
      readxl::read_excel(input_file, sheet = s_name),
      error = function(e) {
        log_line("[ERROR al leer hoja '", s_name, "']: ", e$message)
        NULL
      }
    )
    
    if (!is.null(df_sheet)) {
      inspect_dataframe(df_sheet, label = paste("Hoja:", s_name))
    }
  }
  
} else if (ext %in% c("csv", "txt", "tsv")) {
  # Deteccion de delimitador en texto plano
  first_lines <- readLines(input_file, n = 5, warn = FALSE)
  delim <- ","
  if (length(first_lines) > 0) {
    semis <- sum(gregexpr(";", first_lines[[1]])[[1]] > 0)
    commas <- sum(gregexpr(",", first_lines[[1]])[[1]] > 0)
    tabs <- sum(gregexpr("\t", first_lines[[1]])[[1]] > 0)
    if (semis > commas && semis > tabs) delim <- ";"
    if (tabs > commas && tabs > semis) delim <- "\t"
  }
  log_line(sprintf("ESTRUCTURA CSV: Delimitador detectado: '%s'\n", delim))
  
  df_csv <- tryCatch(
    read.table(input_file, header = TRUE, sep = delim, stringsAsFactors = FALSE, check.names = FALSE),
    error = function(e) {
      log_line("[ERROR al leer CSV]: ", e$message)
      NULL
    }
  )
  
  if (!is.null(df_csv)) {
    inspect_dataframe(df_csv, label = paste("Archivo CSV:", basename(input_file)))
  }
  
} else {
  log_line("[ERROR]: Formato no reconocido. Por favor proporciona un archivo .xlsx, .xls o .csv.")
}

log_line("================================================================================")
log_line("  FIN DEL REPORTE DESCRIPTIVO")
log_line("================================================================================")
close(report_con)

cat(sprintf("\n[OK] Reporte generado y guardado con exito en:\n  -> %s\n\n", output_report))
cat("--------------------------------------------------------------------------------\n")
cat("INSTRUCCION:\n")
cat("Avísale a la IA en el chat que ya ejecutaste '00_inspect_data.R'.\n")
cat("La IA leera '01_data/profiles/data_inspection_report.txt' y disenara tu script a medida.\n")
cat("--------------------------------------------------------------------------------\n\n")
