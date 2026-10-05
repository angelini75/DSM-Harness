# ==============================================================================
# DSM-Harness | 00_audit_diff.R: Auditoría de Diferencias y Procedencia
# ==============================================================================
# OBJETIVO:
# Comparar los scripts adaptados del alumno en 'projects/<nombre>/scripts/' contra
# las plantillas maestras en '02_scripts/', identificando qué bloques ADAPT
# fueron modificados por el alumno/IA, listando las diferencias y auditando
# el log de decisiones ('decisions_log.csv').
#
# INSTRUCCIONES:
# Ejecuta este script en RStudio (Source o Ctrl+Shift+S) para auditar un proyecto.
# ==============================================================================

cat("\n==============================================================================\n")
cat("  DSM-HARNESS | AUDITORÍA DE DIFERENCIAS Y PROCEDENCIA DE PROYECTO\n")
cat("==============================================================================\n\n")

proj_roots <- list.dirs("projects", recursive = FALSE)
if (length(proj_roots) == 0) {
  cat("[AVISO] No se encontraron proyectos en 'projects/'.\n")
  cat("Crea un proyecto primero con: source('02_scripts/00_new_project.R')\n\n")
  return(invisible(NULL))
}

if (!exists("project_name") || is.null(project_name) || !nzchar(project_name)) {
  if (length(proj_roots) == 1) {
    project_name <- basename(proj_roots[1])
  } else if (interactive()) {
    cat("Proyectos disponibles:\n")
    for (i in seq_along(proj_roots)) cat(sprintf("  [%d] %s\n", i, basename(proj_roots[i])))
    p_idx <- as.integer(readline(prompt = "Selecciona el número de proyecto: "))
    if (is.na(p_idx) || p_idx < 1 || p_idx > length(proj_roots)) p_idx <- 1
    project_name <- basename(proj_roots[p_idx])
  } else {
    project_name <- basename(proj_roots[1])
  }
}

proj_dir <- file.path("projects", project_name)
cat(sprintf("[*] Auditando proyecto: '%s' (%s)\n", project_name, proj_dir))
cat("------------------------------------------------------------------------------\n")

# 1. Auditoría del log de decisiones -------------------------------------------
log_file <- file.path(proj_dir, "decisions_log.csv")
if (file.exists(log_file)) {
  log_df <- tryCatch(read.csv(log_file, stringsAsFactors = FALSE), error = function(e) NULL)
  if (!is.null(log_df) && nrow(log_df) > 0) {
    cat(sprintf("[OK] Log de auditoría: %d decisiones registradas por los scripts de R.\n", nrow(log_df)))
    for (r in seq_len(min(5, nrow(log_df)))) {
      cat(sprintf("  [%s | Paso %s] %s -> %s (afectó: %s filas)\n",
                  log_df$timestamp[r], log_df$step[r], log_df$criterion[r], 
                  log_df$user_decision[r], log_df$affected_rows[r]))
    }
    if (nrow(log_df) > 5) cat(sprintf("  ... y %d registros más.\n", nrow(log_df) - 5))
  } else {
    cat("[*] Log de auditoría: Archivo presente pero sin registros aún (0 decisiones).\n")
  }
} else {
  cat("[AVISO] Log de auditoría no encontrado en el proyecto.\n")
}
cat("------------------------------------------------------------------------------\n")

# 2. Comparación de scripts adaptados vs plantillas maestras -------------------
script_files <- c("00_inspect_data.R", "01_1_byod_audit.R", "01_2_byod_audit.R", "01_3_byod_audit.R")

for (sf in script_files) {
  master_path  <- file.path("02_scripts", sf)
  project_path <- file.path(proj_dir, "scripts", sf)
  
  if (!file.exists(project_path)) {
    cat(sprintf("[NO ENCONTRADO]: %s\n", project_path))
    next
  }
  
  p_lines <- readLines(project_path, encoding = "UTF-8", warn = FALSE)
  m_lines <- readLines(master_path, encoding = "UTF-8", warn = FALSE)
  
  # Extraer metadata de procedencia
  prov_lines <- p_lines[grepl("^# (TEMPLATE_VERSION|COPIED_FROM|CREATED_AT|ADAPTED_BLOCKS):", p_lines)]
  t_ver <- gsub(".*TEMPLATE_VERSION:\\s*", "", p_lines[grepl("TEMPLATE_VERSION:", p_lines)][1])
  
  # Filtrar cabeceras de procedencia y diferencias de rutas relativas
  p_body <- p_lines[!grepl("^# --- PROVENANCE|^# TEMPLATE_VERSION|^# COPIED_FROM|^# CREATED_AT|^# ADAPTED_BLOCKS|^# ---", p_lines)]
  
  # Normalizar rutas locales a genéricas para comparar lógica pura
  p_norm <- gsub(sprintf("projects/%s/data", project_name), "01_data/profiles", p_body, fixed = TRUE)
  p_norm <- gsub(sprintf("projects/%s/reports", project_name), "01_data/profiles", p_norm, fixed = TRUE)
  p_norm <- gsub(sprintf("projects/%s/config.json", project_name), "01_data/profiles/user_config.json", p_norm, fixed = TRUE)
  p_norm <- gsub(sprintf("projects/%s/decisions_log.csv", project_name), "01_data/profiles/decisions_log.csv", p_norm, fixed = TRUE)
  
  m_norm <- m_lines[!grepl("^# --- PROVENANCE", m_lines)]
  
  # Detectar si difiere de la plantilla maestra
  is_identical <- (length(p_norm) == length(m_norm)) && all(p_norm == m_norm)
  
  if (is_identical) {
    cat(sprintf("[INTACTO] %-22s: Idéntico a plantilla maestra (v%s)\n", sf, t_ver))
  } else {
    cat(sprintf("[ADAPTADO] %-20s: Presenta parches locales adaptados\n", sf))
    
    # Extraer bloques ADAPT modificados
    adapt_tags <- unique(gsub(".*ADAPT:([a-zA-Z0-9_]+).*", "\\1", p_lines[grepl("ADAPT:", p_lines)]))
    for (tag in adapt_tags) {
      p_tag_lines <- p_lines[grep(paste0(">>> ADAPT:", tag), p_lines):grep(paste0("<<< ADAPT:", tag), p_lines)]
      m_tag_lines <- m_lines[grep(paste0(">>> ADAPT:", tag), m_lines):grep(paste0("<<< ADAPT:", tag), m_lines)]
      
      tag_diff <- length(p_tag_lines) != length(m_tag_lines) || any(p_tag_lines != m_tag_lines)
      if (tag_diff) {
        cat(sprintf("  -> Bloque modificado: [ADAPT:%s] (%d líneas en proyecto vs %d en plantilla)\n",
                    tag, length(p_tag_lines), length(m_tag_lines)))
      }
    }
  }
}

cat("==============================================================================\n\n")
