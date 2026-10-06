# Especificación de Contrato para Bloques ADAPT (`docs/ADAPT_CONTRACT.md`)

Este documento define el **contrato formal, entorno de ejecución e invariantes** de los puntos de extensión (`ADAPT`) en las plantillas maestras de DSM-Harness (`02_scripts/`).

---

## 1. Principio Arquitectónico: Puntos de Inserción, No Reemplazo Destructivo

1. **Ranuras de Inserción (*Insertion Slots*)**:
   - Los bloques delimitados por `# >>> ADAPT:<nombre>` y `# <<< ADAPT:<nombre>` son **puntos de inserción limpios**, no regiones de lógica de la plantilla que el alumno o la IA deban sobrescribir.
   - La lógica estructural de la plantilla (lectura de archivos, loops relacionales, validación de variables esenciales, cálculo de métricas) reside **fuera** del bloque ADAPT y se mantiene intacta.
2. **Prohibición de "Reemplazar el Bloque"**:
   - **PROHIBIDO**: NUNCA indiques *"Reemplaza todo el bloque entre etiquetas"*. Dicha instrucción destruye la lógica circundante de la plantilla.
   - **OBLIGATORIO**: Instruye siempre *"Inserta el siguiente código dentro del punto de extensión `# >>> ADAPT:<nombre>`"*.
3. **Trazabilidad y Detección de Cambios (`00_audit_diff.R`)**:
   - `00_audit_diff.R` compara las líneas entre las etiquetas del proyecto contra la plantilla maestra.
   - Cuando se inserta código en el punto de extensión, el script audita y documenta limpiamente el número de líneas añadidas sin registrar falsos positivos de rotura de plantilla.

---

## 2. Firma Canónica de Auditoría (`record_decision`)

Toda modificación adaptada en código que altere datos o tome decisiones metodológicas debe registrarse llamando a la función `record_decision()` disponible en el entorno del script:

```r
record_decision(
  step,               # Numérico o caracter: ej. 1.1, 1.2, 1.3
  criterion,          # Caracter: aspecto evaluado (ej. "Mapeo personalizado", "Filtro regional")
  decision,           # Caracter: decisión metodológica aplicada
  source = "user_config", # "user_config" o "script_default"
  affected_rows = 0,  # Entero: filas modificadas/afectadas
  affected_profiles = 0, # Entero: perfiles afectados
  details = ""        # Caracter: descripción técnica complementaria
)
```

---

## 3. Contrato Detallado por Script y Bloque

### A. Paso 1.1 (`01_1_byod_audit.R`)

#### Bloque 1: `# >>> ADAPT:read_and_join`
* **Ubicación**: Inmediatamente tras la lectura y unión de hojas de sitios y horizontes.
* **Propósito**: Inserción de transformaciones tabulares, normalización de IDs o filtros previos al análisis de variables.
* **Entorno y Objetos Disponibles**:
  | Objeto | Tipo | Descripción |
  | :--- | :--- | :--- |
  | `dat_raw` | `data.frame` / `tbl_df` | Dataset consolidado tras unión relacional. |
  | `user_cfg` | `list` | Configuración parseada desde `config.json`. |
  | `input_file` | `character` | Ruta al archivo de datos de entrada. |
  | `exact_dup_rows` | `integer` | Conteo de filas exactamente duplicadas. |
  | `record_decision`| `function` | Función de auditoría en `decisions_log.csv`. |
* **Invariantes Requeridos**:
  - `dat_raw` debe mantenerse como un `data.frame` válido con los datos listos para el paso de mapeo.

#### Bloque 2: `# >>> ADAPT:column_mapping`
* **Ubicación**: Inmediatamente tras el mapeo estándar heurístico/declarativo y la suma de arenas (`sand_sum`).
* **Propósito**: Registro de correspondencias complejas, cálculo de razones analíticas (ej. C/N, bases cambiables) o variables derivadas no contempladas en `config.json`.
* **Entorno y Objetos Disponibles**:
  | Objeto | Tipo | Descripción |
  | :--- | :--- | :--- |
  | `dat_raw` | `data.frame` | Dataset con todas las columnas originales y derivadas. |
  | `mapping` | `data.frame` | Tabla de mapeo con columnas `Original` y `Estandar_DSM`. |
  | `rename_vector`| `character` (nombrado) | Vector de renombrado: `c("Estandar_DSM" = "Columna_Original")`. |
  | `cols_raw` | `character` | Nombres de columnas presentes en `dat_raw`. |
  | `user_cfg` | `list` | Configuración parseada desde `config.json`. |
  | `record_decision`| `function` | Función de auditoría. |
* **Invariantes Requeridos**:
  - Si se añade una nueva variable a conservar, debe registrarse agregando una fila a `mapping` (`Original`, `Estandar_DSM`) y su elemento correspondiente en `rename_vector`.
  - Alternativamente, si solo se desea conservar columnas adicionales sin renombrado, se debe usar la clave declarativa `"keep_columns": ["colA", "colB"]` en `config.json` antes de recurrir a código ADAPT.

---

### B. Paso 1.2 (`01_2_byod_audit.R`)

#### Bloque: `# >>> ADAPT:crs_and_outliers`
* **Ubicación**: Tras la transformación de coordenadas y el cálculo del filtro univariado de dispersión (IQR 3×).
* **Propósito**: Lógica de georreferenciación personalizada (ej. transformación con datum local no estándar) o marcado de outliers espaciales según polígonos/máscaras territoriales.
* **Entorno y Objetos Disponibles**:
  | Objeto | Tipo | Descripción |
  | :--- | :--- | :--- |
  | `dat_valid` | `data.frame` | Dataset con perfiles que tienen coordenadas no nulas. |
  | `outlier_mask` | `logical` | Vector booleano indicando candidatos a outlier detectados por IQR 3×. |
  | `source_crs` | `integer` / `NULL` | Código EPSG declarado en `config.json`. |
  | `is_projected_coords` | `logical` | `TRUE` si las coordenadas están en rango métrico proyectado. |
  | `user_cfg` | `list` | Configuración de usuario. |
  | `record_decision` | `function` | Función de auditoría. |
* **Invariantes Requeridos**:
  - `dat_valid` debe conservar obligatoriamente las columnas `longitude` y `latitude` en grados WGS84 (o en coordenadas métricas planas si el CRS no fue especificado).

---

### C. Paso 1.3 (`01_3_byod_audit.R`)

#### Bloque: `# >>> ADAPT:pedological_checks`
* **Ubicación**: Tras la auditoría de límites de profundidad, texturas, pH, SOC y evaluación del catálogo de PTFs de densidad aparente.
* **Propósito**: Inserción de reglas de coherencia edafológica regionales, filtros de horizontes diagnósticos o PTFs locales específicas con predictores adicionales.
* **Entorno y Objetos Disponibles**:
  | Objeto | Tipo | Descripción |
  | :--- | :--- | :--- |
  | `dat` | `data.frame` | Dataset con variables DSM y columnas de auditoría previas. |
  | `ptf_eval_table` | `data.frame` | Tabla comparativa de PTFs evaluadas (`PTF`, `Formula`, `n_val`, `R2`, `RMSE`, `Bias`). |
  | `all_models_list`| `list` | Lista de modelos PTF evaluados con sus nombres, fórmulas y predicciones. |
  | `user_cfg` | `list` | Configuración de usuario. |
  | `record_decision` | `function` | Función de auditoría. |
* **Invariantes Requeridos**:
  - `dat` debe conservar las columnas esenciales de horizontes (`upper`, `lower`, `profile_code`) y el dataset no debe reducirse de forma imprevista sin registrar la decisión en `record_decision()`.

---

## 4. Reglas Operativas para Asistentes de IA

1. **Declarativo Primero**: Antes de sugerir un parche en código ADAPT, verifica si el requerimiento puede resolverse declarativamente en `config.json` (ej: `keep_columns`, `sand_sum`, `duplicate_key_strategy`, `selected_ptf`).
2. **Inspección de Contexto Previa**: Si se requiere un parche, pide al alumno pegar las líneas actuales del bloque ADAPT si hay duda del estado local.
3. **Formato del Parche**:
   - Entrega exclusivamente el bloque mínimo (15-30 líneas) delimitado entre los comentarios `# >>> ADAPT:<tag>` y `# <<< ADAPT:<tag>`.
   - Instruye: *"Copia e inserta este bloque dentro de la sección `# >>> ADAPT:<tag>` en tu script local `projects/<nombre>/scripts/<script>.R`"*.
   - **NUNCA indiques borrar el código que rodea al bloque.**
