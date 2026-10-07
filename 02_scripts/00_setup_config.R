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

# Carga de motor i18n
i18n_candidates <- c("02_scripts/00_i18n.R", "00_i18n.R")
for (cand in i18n_candidates) {
  if (file.exists(cand)) {
    tryCatch(source(cand, local = FALSE), error = function(e) NULL)
    break
  }
}

# 2. Cargar config existente o plantilla base ----------------------------------
cfg <- list()
if (file.exists(config_file)) {
  tryCatch({
    cfg <- jsonlite::fromJSON(config_file, simplifyVector = FALSE)
  }, error = function(e) NULL)
}

if (length(cfg) == 0 && file.exists(template_file)) {
  cfg <- jsonlite::fromJSON(template_file, simplifyVector = FALSE)
  cfg$`_comment` <- NULL
}

lang <- if (!is.null(cfg$language) && cfg$language %in% c("es", "en")) {
  cfg$language
} else if (exists("get_project_language")) {
  get_project_language(cfg)
} else "es"

is_en <- identical(lang, "en")

if (is_en) {
  cat("\n==============================================================================\n")
  cat("  DSM-HARNESS | CONFIGURATION ASSISTANT (user_config.json)\n")
  cat("==============================================================================\n\n")
} else {
  cat("\n==============================================================================\n")
  cat("  DSM-HARNESS | ASISTENTE DE CONFIGURACIÓN (user_config.json)\n")
  cat("==============================================================================\n\n")
}

# 1. Detectar archivo de datos -------------------------------------------------
avail <- list.files("01_data/profiles", pattern = "\\.(xlsx|xls|csv|txt|tsv)$", full.names = TRUE, ignore.case = TRUE)
avail <- avail[!grepl("(_report\\.txt|step1_.*\\.csv|cleaned_profiles\\.csv|decisions_log|mapping_confirmed|template)", avail)]

selected_file <- NULL
if (length(avail) == 1) {
  selected_file <- avail[1]
  if (is_en) cat(sprintf("[*] Detected data file: %s\n", selected_file))
  else cat(sprintf("[*] Archivo de datos detectado: %s\n", selected_file))
} else if (length(avail) > 1) {
  if (is_en) {
    cat("[*] Available files in 01_data/profiles/:\n")
    for (i in seq_along(avail)) cat(sprintf("  [%d] %s\n", i, basename(avail[i])))
    if (interactive()) {
      choice <- readline(prompt = "Select file number [1]: ")
      choice_idx <- as.integer(trimws(choice))
      if (is.na(choice_idx) || choice_idx < 1 || choice_idx > length(avail)) choice_idx <- 1
      selected_file <- avail[choice_idx]
    } else {
      selected_file <- avail[1]
    }
  } else {
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
  }
} else {
  if (is_en) cat("[NOTICE] No file detected in '01_data/profiles/'.\n")
  else cat("[AVISO] No se detectó ningún archivo en '01_data/profiles/'.\n")
  selected_file <- "01_data/profiles/mis_datos.xlsx"
}

cfg$input_file <- selected_file
if (is.null(cfg$language)) cfg$language <- lang

# 3. Inspeccionar hojas si es Excel -------------------------------------------
ext <- tolower(tools::file_ext(selected_file))
if (ext %in% c("xlsx", "xls") && file.exists(selected_file) && requireNamespace("readxl", quietly = TRUE)) {
  sheets <- readxl::excel_sheets(selected_file)
  if (is_en) {
    cat(sprintf("\n[*] Sheets detected in Excel (%d): [%s]\n", length(sheets), paste(sheets, collapse = ", ")))
  } else {
    cat(sprintf("\n[*] Hojas detectadas en Excel (%d): [%s]\n", length(sheets), paste(sheets, collapse = ", ")))
  }
  
  if (length(sheets) == 1) {
    cfg$site_sheet <- sheets[1]
    cfg$horizon_sheets <- list()
  } else if (interactive()) {
    p_conf <- if (is_en) "\nDo you want to configure sheets interactively? (y/n) [y]: " else "\n¿Deseas configurar las hojas interactivamente? (s/n) [s]: "
    cat(p_conf)
    ans <- tolower(trimws(readline()))
    if (ans %in% c("", "s", "si", "y", "yes")) {
      if (is_en) cat("Available sheets:\n") else cat("Hojas disponibles:\n")
      for (i in seq_along(sheets)) cat(sprintf("  [%d] %s\n", i, sheets[i]))
      
      p_site <- if (is_en) "Sheet number for SITES/PROFILES [1]: " else "Número de hoja de SITIOS/PERFILES [1]: "
      site_idx <- as.integer(readline(prompt = p_site))
      if (is.na(site_idx) || site_idx < 1 || site_idx > length(sheets)) site_idx <- 1
      cfg$site_sheet <- sheets[site_idx]
      
      p_key <- if (is_en) "Key column name in sites sheet (e.g. site_id): " else "Nombre de columna clave en la hoja de sitios (ej. id_sitio): "
      s_key <- trimws(readline(prompt = p_key))
      if (nzchar(s_key)) cfg$site_key <- s_key
      
      p_nh <- if (is_en) "\nHow many HORIZON sheets do you want to link? [1]: " else "\n¿Cuántas hojas de HORIZONTES deseas vincular? [1]: "
      cat(p_nh)
      n_h_str <- trimws(readline())
      n_h <- as.integer(n_h_str)
      if (is.na(n_h) || n_h < 1) n_h <- 1
      
      h_list <- list()
      for (h_i in seq_len(n_h)) {
        if (is_en) cat(sprintf("\n--- Configuring Horizon Sheet #%d ---\n", h_i))
        else cat(sprintf("\n--- Configurando Hoja de Horizontes #%d ---\n", h_i))
        p_hidx <- if (is_en) sprintf("Sheet number for Horizons #%d: ", h_i) else sprintf("Número de hoja para Horizontes #%d: ", h_i)
        h_idx <- as.integer(readline(prompt = p_hidx))
        if (is.na(h_idx) || h_idx < 1 || h_idx > length(sheets)) h_idx <- min(2, length(sheets))
        h_name <- sheets[h_idx]
        
        p_jkey <- if (is_en) sprintf("Join column in '%s' (join_key): ", h_name) else sprintf("Columna de unión en '%s' (join_key): ", h_name)
        j_key <- trimws(readline(prompt = p_jkey))
        if (!nzchar(j_key)) j_key <- if (!is.null(cfg$site_key)) cfg$site_key else "id"
        
        item <- list(sheet = h_name, join_key = j_key)
        if (h_i < n_h) {
          p_hzkey <- if (is_en) "¿Does this sheet introduce a unique horizon key to link with next sheets? (leave blank if not applicable): "
                     else "¿Esta hoja introduce una clave única de horizonte para unir con las siguientes? (dejar vacío si no aplica): "
          hz_key <- trimws(readline(prompt = p_hzkey))
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
if (is_en) {
  cat(sprintf("\n[OK] Configuration successfully saved to:\n  -> %s\n\n", config_file))
  cat("You can now run '02_scripts/01_1_byod_audit.R' in RStudio.\n")
  cat("==============================================================================\n\n")
} else {
  cat(sprintf("\n[OK] Configuración guardada exitosamente en:\n  -> %s\n\n", config_file))
  cat("Ahora puedes ejecutar '02_scripts/01_1_byod_audit.R' en RStudio.\n")
  cat("==============================================================================\n\n")
}
