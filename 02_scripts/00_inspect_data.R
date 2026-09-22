# ==============================================================================
# DSM-Harness | 00_inspect_data.R: Escudriñador Exhaustivo de Datasets (BYOD)
# ==============================================================================
# OBJETIVO:
# Este script escudriña el archivo de datos provisto (sea Excel con múltiples
# hojas o delimitado .csv/.tsv/.txt), analizando exhaustivamente todas las hojas,
# columnas, tipos de datos (class), porcentaje de valores nulos, muestras de
# valores reales NO NULOS y rangos numéricos.
#
# IMPORTANTE:
# - No omite columnas con valores vacíos en las primeras filas.
# - No trunca los nombres de las columnas.
# - Examina el vector completo de cada columna para deducir su tipo real.
#
# El resultado se imprime en la consola de RStudio y se guarda automáticamente
# en '01_data/profiles/data_inspection_report.txt'.
# La IA utilizará ese reporte descriptivo para diseñar a medida tu script
# de auditoría '02_scripts/01_1_byod_audit.R'.
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
  avail <- list.files("01_data/profiles", pattern = "\\.(xlsx|xls|csv|txt|tsv)$", full.names = TRUE)
  avail <- avail[!grepl("data_inspection_report\\.txt$", avail)]
  avail <- avail[!grepl("step1_.*\\.csv$", avail)]
  avail <- avail[!grepl("cleaned_profiles\\.csv$", avail)]
  
  if (length(avail) > 0) {
    cat(sprintf("[AVISO] No se encontro '%s'. Usando archivo detectado: '%s'\n", input_file, avail[1]))
    input_file <- avail[1]
  } else {
    stop(sprintf("\n[ERROR] No se encontro el archivo '%s' ni ningun archivo de datos en '01_data/profiles/'.\nPor favor coloca tu archivo en esa carpeta y verifica la ruta.", input_file))
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
log_line("  DSM-HARNESS: REPORTE DESCRIPTIVO ESTRUCTURAL DEL DATASET (BYOD)")
log_line("================================================================================")
log_line("Fecha y hora: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"))
log_line("Archivo inspeccionado: ", input_file)
log_line("Formato detectado: .", ext)
log_line("Tamano del archivo: ", round(file.size(input_file) / 1024, 2), " KB")
log_line("================================================================================\n")

# ------------------------------------------------------------------------------
# 3. Función de Inspección Exhaustiva de DataFrames
# ------------------------------------------------------------------------------

inspect_dataframe <- function(df, label = "Tabla") {
  log_line(sprintf(">>> RESUMEN DE %s <<<", toupper(label)))
  
  if (is.null(df) || nrow(df) == 0 || ncol(df) == 0) {
    log_line("[AVISO]: La tabla está vacía (0 filas o 0 columnas).")
    log_line("--------------------------------------------------------------------------------\n")
    return(invisible(NULL))
  }
  
  log_line(sprintf("Dimensiones: %d filas x %d columnas", nrow(df), ncol(df)))
  log_line("--------------------------------------------------------------------------------")
  
  col_names <- names(df)
  max_w <- max(c(nchar(col_names), 16), na.rm = TRUE)
  # Limitar ancho de columna a un máximo razonable para legibilidad pero sin truncar arbitrariamente
  col_w <- min(max(max_w, 20), 45)
  
  col_info <- data.frame(
    No = seq_along(col_names),
    Columna = col_names,
    Clase = sapply(df, function(x) paste(class(x), collapse = "/")),
    Nulos = sapply(df, function(x) sum(is.na(x))),
    Nulos_Pct = round(sapply(df, function(x) mean(is.na(x)) * 100), 1),
    Valores_Unicos = sapply(df, function(x) length(unique(na.omit(x)))),
    stringsAsFactors = FALSE
  )
  
  fmt_head <- sprintf("%%-4s | %%-%ds | %%-12s | %%-8s | %%-7s | %%-10s", col_w)
  fmt_row  <- sprintf("%%-4d | %%-%ds | %%-12s | %%-8d | %%-6.1f%%%% | %%-10d", col_w)
  sep_line <- paste(rep("-", col_w + 50), collapse = "")
  
  log_line(sprintf(fmt_head, "No.", "Nombre Columna", "Clase", "NAs", "% NAs", "Unicos"))
  log_line(sep_line)
  
  for (i in seq_len(nrow(col_info))) {
    c_name_disp <- if (nchar(col_info$Columna[i]) > col_w) {
      paste0(substr(col_info$Columna[i], 1, col_w - 3), "...")
    } else {
      col_info$Columna[i]
    }
    
    log_line(sprintf(fmt_row,
                     col_info$No[i],
                     c_name_disp,
                     col_info$Clase[i],
                     col_info$Nulos[i],
                     col_info$Nulos_Pct[i],
                     col_info$Valores_Unicos[i]))
  }
  log_line(sep_line)
  log_line("")
  
  # Nombres completos de columnas (para asegurar que ningún nombre largo se pierda)
  long_cols <- col_names[nchar(col_names) > col_w]
  if (length(long_cols) > 0) {
    log_line("--- NOMBRES COMPLETOS DE COLUMNAS LARGAS ---")
    for (lc in long_cols) {
      log_line(sprintf("  [%d] %s", which(col_names == lc), lc))
    }
    log_line("")
  }
  
  # Muestra de primeros 3 valores NO NULOS por columna
  log_line("--- MUESTRA DE VALORES REALES (Primeros 3 valores NO NULOS) ---")
  for (col in col_names) {
    non_na <- na.omit(df[[col]])
    if (length(non_na) > 0) {
      sample_str <- paste(as.character(head(non_na, 3)), collapse = " | ")
      log_line(sprintf("  %-35s : %s", col, sample_str))
    } else {
      log_line(sprintf("  %-35s : [TODOS LOS VALORES SON NA]", col))
    }
  }
  log_line("")
  
  # Muestra de últimos 3 valores NO NULOS por columna (para verificar consistencia final)
  log_line("--- MUESTRA FINAL DE VALORES REALES (Ultimos 3 valores NO NULOS) ---")
  for (col in col_names) {
    non_na <- na.omit(df[[col]])
    if (length(non_na) > 3) {
      sample_str <- paste(as.character(tail(non_na, 3)), collapse = " | ")
      log_line(sprintf("  %-35s : %s", col, sample_str))
    }
  }
  log_line("")
  
  # Resumen numérico para columnas numéricas (calculado sobre valores no nulos)
  num_cols <- col_names[sapply(df, is.numeric)]
  if (length(num_cols) > 0) {
    log_line("--- RANGOS DE VARIABLES NUMERICAS (Min / Mediana / Media / Max) ---")
    for (nc in num_cols) {
      vals <- na.omit(df[[nc]])
      if (length(vals) > 0) {
        log_line(sprintf("  %-35s : Min = %g | Mediana = %g | Media = %.2f | Max = %g", 
                         nc, min(vals), median(vals), mean(vals), max(vals)))
      } else {
        log_line(sprintf("  %-35s : (100%% valores NA)", nc))
      }
    }
    log_line("")
  }
}

# ------------------------------------------------------------------------------
# 4. Procesamiento según formato: Excel (.xlsx, .xls) o CSV (.csv, .txt, .tsv)
# ------------------------------------------------------------------------------

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
    
    # guess_max = 100000 asegura que escanee todas las filas para no clasificar como 'logical'
    # columnas con NAs en las primeras filas
    df_sheet <- tryCatch(
      readxl::read_excel(input_file, sheet = s_name, guess_max = 100000),
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
  # Detección inteligente de delimitador
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
    inspect_dataframe(df_csv, label = paste("Archivo:", basename(input_file)))
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
cat("INSTRUCCION PARA EL ALUMNO:\n")
cat("Avísale a la IA en el chat que ya ejecutaste '00_inspect_data.R'.\n")
cat("La IA leera '01_data/profiles/data_inspection_report.txt' para diseñar a medida\n")
cat("tu script de mapeo de variables: '02_scripts/01_1_byod_audit.R'.\n")
cat("--------------------------------------------------------------------------------\n\n")
