# ==============================================================================
# DSM-Harness | 00_setup_config.R: Asistente Interactivo de Configuración
# ==============================================================================
# OBJETIVO:
# Este script asiste al alumno en la creación o actualización de
# '01_data/profiles/user_config.json' de forma amigable e interactiva desde la
# consola de RStudio, evitando la edición manual directa de archivos JSON.
#
# INSTRUCCIONES:
# Ejecuta este script en RStudio (Source o Ctrl+Shift+S) y sigue las preguntas en consola.
# ==============================================================================

if (!requireNamespace("jsonlite", quietly = TRUE)) {
  stop("El paquete 'jsonlite' es requerido. Instálalo con: install.packages('jsonlite')")
}

config_file <- "01_data/profiles/user_config.json"
template_file <- "01_data/profiles/user_config.template.json"

cat("\n==============================================================================\n")
cat("  DSM-HARNESS | ASISTENTE DE CONFIGURACIÓN (user_config.json)\n")
cat("==============================================================================\n\n")

# 1. Detectar archivo de datos -------------------------------------------------
avail <- list.files("01_data/profiles", pattern = "\\.(xlsx|xls|csv|txt|tsv)$", full.names = TRUE, ignore.case = TRUE)
avail <- avail[!grepl("(_report\\.txt|step1_.*\\.csv|cleaned_profiles\\.csv|decisions_log|mapping_confirmed|template)", avail)]

selected_file <- NULL
if (length(avail) == 1) {
  selected_file <- avail[1]
  cat(sprintf("[*] Archivo de datos detectado: %s\n", selected_file))
} else if (length(avail) > 1) {
  cat("[*] Archivos disponibles en 01_data/profiles/:\n")
  for (i in seq_along(avail)) cat(sprintf("  [%d] %s\n", i, basename(avail[i])))
  if (interactive()) {
    choice <- readline(prompt = "Selecciona el número de archivo [1]: ")
    choice_idx <- as.integer(trimws(choice))
    if (is.na(choice_idx) || choice_idx < 1 || choice_idx > length(avail)) choice_idx <- 1
    selected_file <- avail[choice_idx]
  } else {
    selected_file <- avail[1]
  }
} else {
  cat("[AVISO] No se detectó ningún archivo en '01_data/profiles/'.\n")
  selected_file <- "01_data/profiles/mis_datos.xlsx"
}

# 2. Cargar config existente o plantilla base ----------------------------------
cfg <- list()
if (file.exists(config_file)) {
  tryCatch({
    cfg <- jsonlite::fromJSON(config_file, simplifyVector = FALSE)
    cat(sprintf("[*] Se encontró un archivo de configuración existente: '%s'\n", config_file))
  }, error = function(e) {
    cat("[AVISO] Error al leer config existente, se usará plantilla base.\n")
  })
}

if (length(cfg) == 0 && file.exists(template_file)) {
  cfg <- jsonlite::fromJSON(template_file, simplifyVector = FALSE)
  cfg$`_comment` <- NULL
}

cfg$input_file <- selected_file

# 3. Inspeccionar hojas si es Excel -------------------------------------------
ext <- tolower(tools::file_ext(selected_file))
if (ext %in% c("xlsx", "xls") && file.exists(selected_file) && requireNamespace("readxl", quietly = TRUE)) {
  sheets <- readxl::excel_sheets(selected_file)
  cat(sprintf("\n[*] Hojas detectadas en Excel (%d): [%s]\n", length(sheets), paste(sheets, collapse = ", ")))
  
  if (length(sheets) == 1) {
    cfg$site_sheet <- sheets[1]
    cfg$horizon_sheets <- list()
  } else if (interactive()) {
    cat("\n¿Deseas configurar las hojas interactivamente? (s/n) [s]: ")
    ans <- tolower(trimws(readline()))
    if (ans %in% c("", "s", "si", "y", "yes")) {
      cat("Hojas disponibles:\n")
      for (i in seq_along(sheets)) cat(sprintf("  [%d] %s\n", i, sheets[i]))
      
      site_idx <- as.integer(readline(prompt = "Número de hoja de SITIOS/PERFILES [1]: "))
      if (is.na(site_idx) || site_idx < 1 || site_idx > length(sheets)) site_idx <- 1
      cfg$site_sheet <- sheets[site_idx]
      
      s_key <- trimws(readline(prompt = "Nombre de columna clave en la hoja de sitios (ej. id_sitio): "))
      if (nzchar(s_key)) cfg$site_key <- s_key
      
      cat("\n¿Cuántas hojas de HORIZONTES deseas vincular? [1]: ")
      n_h_str <- trimws(readline())
      n_h <- as.integer(n_h_str)
      if (is.na(n_h) || n_h < 1) n_h <- 1
      
      h_list <- list()
      for (h_i in seq_len(n_h)) {
        cat(sprintf("\n--- Configurando Hoja de Horizontes #%d ---\n", h_i))
        h_idx <- as.integer(readline(prompt = sprintf("Número de hoja para Horizontes #%d: ", h_i)))
        if (is.na(h_idx) || h_idx < 1 || h_idx > length(sheets)) h_idx <- min(2, length(sheets))
        h_name <- sheets[h_idx]
        
        j_key <- trimws(readline(prompt = sprintf("Columna de unión en '%s' (join_key): ", h_name)))
        if (!nzchar(j_key)) j_key <- if (!is.null(cfg$site_key)) cfg$site_key else "id"
        
        item <- list(sheet = h_name, join_key = j_key)
        if (h_i < n_h) {
          hz_key <- trimws(readline(prompt = sprintf("¿Esta hoja introduce una clave única de horizonte para unir con las siguientes? (dejar vacío si no aplica): ")))
          if (nzchar(hz_key)) item$horiz_key <- hz_key
        }
        h_list[[h_i]] <- item
      }
      cfg$horizon_sheets <- h_list
    }
  }
}

# 4. Guardar archivo JSON -----------------------------------------------------
jsonlite::write_json(cfg, config_file, auto_unbox = TRUE, pretty = TRUE)
cat(sprintf("\n[OK] Configuración guardada exitosamente en:\n  -> %s\n\n", config_file))
cat("Ahora puedes ejecutar '02_scripts/01_1_byod_audit.R' en RStudio.\n")
cat("==============================================================================\n\n")
