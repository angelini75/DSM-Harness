# ==============================================================================
# DSM-Harness | Etapa 01: Auditoría y Preparación de Perfiles (BYOD)
# ==============================================================================
# NOTA DE ARQUITECTURA MODULAR:
# Para evitar sobreescrituras, facilitar la trazabilidad y permitir la inspección
# visual paso a paso en RStudio, la Etapa 1 está dividida en 3 scripts independientes:
#
#  -> 02_scripts/01_1_byod_audit.R : Mapeo relacional y selección estricta de variables DSM
#                                    (Salida: '01_data/profiles/step1_1_variables.csv')
#
#  -> 02_scripts/01_2_byod_audit.R : Validación espacial, CRS (WGS84), visor de mapa
#                                    (Salida: '01_data/profiles/step1_2_spatial.csv')
#
#  -> 02_scripts/01_3_byod_audit.R : Profundidades, coherencia analítica y Saxton PTF
#                                    (Salida: '01_data/profiles/cleaned_profiles.csv')
#
# Cada sub-paso genera simultáneamente un reporte de texto complementario
# ('step1_1_variables_report.txt', 'step1_2_spatial_report.txt', 'step1_3_pedological_report.txt')
# que la IA lee para interactuar con tus resultados y formular preguntas de reflexión.
# ==============================================================================

cat("\n==============================================================================\n")
cat("  DSM-HARNESS: ETAPA 1 - GUIA DE EJECUCION MODULAR\n")
cat("==============================================================================\n")
cat("Por favor ejecuta los scripts en RStudio en el siguiente orden secuencial:\n\n")
cat("  1. '02_scripts/01_1_byod_audit.R' -> Variables y relaciones\n")
cat("  2. '02_scripts/01_2_byod_audit.R' -> Validacion espacial y mapa\n")
cat("  3. '02_scripts/01_3_byod_audit.R' -> Profundidades y coherencia edafologica\n\n")
cat("Entre cada paso, avísale a la IA en el chat para revisar los reportes y avanzar.\n")
cat("==============================================================================\n\n")
