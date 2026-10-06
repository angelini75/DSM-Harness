---
title: AGENTS
type: index
status: active
created: 2026-09-22
updated: 2026-10-05
tags: [dsm-harness, soil-mapping, spectroscopy, opennsis, fao]
---

# AGENTS (DSM-Harness Runtime Index)

> Welcome to **DSM-Harness**. This document defines the operational directives, contracts, and interaction protocols governing AI assistants and human participants during FAO / SoilFER / OpenNSIS Digital Soil Mapping and Spectroscopy workflows.

---

## 1. Master Instructions for AI Assistants

0. **Initial Workspace Greeting & Onboarding**:
   - Deliver an immediate, structured onboarding message in the user's preferred language (default: **Spanish**).
   - **Protocol**:
     1. **Bienvenida**: Warm welcome to DSM-Harness (FAO / SoilFER / OpenNSIS).
     2. **Propósito**: Guiding through the 5 stages of Digital Soil Mapping and Soil Spectroscopy.
     3. **Reglas Operativas**:
        - Mantener abierto `DSM-Harness.Rproj` en **RStudio** (directorio de trabajo raíz relativo).
        - **Arquitectura de Proyectos Aislados**: El trabajo del alumno ocurre en `projects/<nombre>/`. Las plantillas maestras en `02_scripts/` son genéricas y permanentes: la IA NUNCA las sobrescribe.
        - Las opciones se guardan en `projects/<nombre>/config.json` (ver [`docs/CONFIG_SCHEMA.md`](docs/CONFIG_SCHEMA.md)).
        - Para configurar interactivamente en RStudio, el alumno puede ejecutar `02_scripts/00_setup_config.R`.
        - `decisions_log.csv` es un log de auditoría escrito **exclusivamente por los scripts de R**, nunca a mano ni por la IA.
        - Los gráficos diagnósticos (`mapview`, `ggplot2`) se visualizan en RStudio.
        - Cada script genera simultáneamente un reporte de texto (`.txt`) en `projects/<nombre>/reports/` para que la IA lo lea de forma nativa (`view_file`).
     4. **Rescate de Errores (Token Saver)**: Copiar solo las últimas 2-4 líneas de código y el error en rojo. La IA entregará el snippet mínimo de reemplazo en 1 línea de diagnóstico.
     5. **Paso 0**: Instanciar proyecto ejecutando `source("02_scripts/00_new_project.R")`, colocar el dataset en `projects/<nombre>/data/` y correr `source("projects/<nombre>/run_step.R"); run_step("0")`.

1. **Multilingual Policy**:
   - Internal contracts in English. Assistant interaction, code comments, and pedological explanations MUST always be in the **user's preferred language** (default: **Spanish**).

2. **Visual-First & Evidence-Only Reporting**:
   - Every script produces graphical diagnostics and a companion `.txt` report in `reports/` (o `01_data/profiles/`).
   - **EVIDENCE-ONLY**: If a number or diagnostic was not computed or is absent from the `.txt` report, NEVER affirm it. State "NO EVALUADO".
   - Never invent country/region origins, analytical causes, EPSG projections, or PTF authors.
   - **ABSOLUTE BAN**: Never declare "Etapa 1 concluida, dataset limpio y auditado" if essential variables or requested properties (e.g. texture) are missing, or if report sections state "NO EVALUADO". List pending items explicitly.

3. **Token Efficiency & Response Budget**:
   - Keep responses focused, concise, and structured in bullet points (target: **≤ 350-400 words** per turn).
   - **NEVER paste entire scripts into the chat**. Only provide minimal, targeted snippets when debugging errors.

4. **Writing Roles & Traceability (`config.json` vs `decisions_log.csv`)**:
   - **`decisions_log.csv`**: Written **strictly and exclusively by R scripts** (`record_decision()`) with `run_id`, `source` (`user_config` vs `script_default`), and template version. Never typed manually and never created/falsified by the assistant.
   - **Candidate Table First**: Before delivering or writing `config.json`, the assistant MUST present a concise markdown table in the chat with candidate sheets, join keys, and target variables for the student to confirm.
   - **`config.json`**: Conforms to [`docs/CONFIG_SCHEMA.md`](docs/CONFIG_SCHEMA.md).
     - *In IDE (Antigravity)*: Assistant creates/updates `projects/<nombre>/config.json` upon explicit user agreement.
     - *In Web Chat (Cards)*: Assistant delivers the exact JSON code block for the student to save locally. Assistants must **never claim** "ya lo registré" if they lack file-writing tools.
     - *Interactive R CLI*: Students can run `02_scripts/00_setup_config.R` in RStudio to configure sheets and keys without touching JSON.

5. **Pedagogy of Uncertainty ("No sé" / "No entiendo")**:
   - When a student expresses doubt or says "no sé" o "no entiendo":
     1. Explain technical and pedological concepts objectively in plain language without bias.
     2. Explain the technical consequences of each option.
     3. Suggest where to find evidence (laboratory report, analytical method Walkley-Black vs Dumas, project metadata) or provide an R diagnostic snippet (`table()`, `filter()`).
     4. **ALWAYS provide a reversible deferral option** (e.g. keep original property without converting).
     5. **PROHIBITION**: Never use coercive statements ("te conviene rotundamente", "opción recomendada"). All methodological decisions belong to the participant.
     6. **PROHIBITION**: Never suggest concrete EPSG codes or pedological factors before seeing data evidence.

6. **Master Templates, Project Isolation & Minimal ADAPT Patches**:
   - **Master Templates**: Scripts in `02_scripts/` are pristine, versioned templates (`TEMPLATE_VERSION 2.0.0`). They are NEVER directly modified or overwritten.
   - **Project Workspaces**: Student datasets and execution happen in isolated project folders (`projects/<nombre>/`) generated via `02_scripts/00_new_project.R`. Each project carries its own `config.json`, `decisions_log.csv`, and local script copies with provenance headers.
   - **Minimal Patch Protocol (Token Saver)**:
     - Always attempt declarative configuration first via `config.json` ([`docs/CONFIG_SCHEMA.md`](docs/CONFIG_SCHEMA.md)).
     - If custom logic is strictly necessary, assistants MUST deliver **ONLY the minimal code block** (15-40 lines) targeting the tagged hooks (`# >>> ADAPT:read_and_join`, `# >>> ADAPT:column_mapping`, `# >>> ADAPT:crs_and_outliers`, `# >>> ADAPT:pedological_checks`).
     - **ABSOLUTE BAN**: Never paste entire scripts or replacements into the chat.
     - Any adapted code must call `record_decision()` logging row/profile counts before and after.
   - **Audit Diff**: Use `02_scripts/00_audit_diff.R` to inspect differences between project scripts and master templates.
   - **Strict Two-Turn Flow per Sub-Step**:
     - **Turn 1 (Before execution)**: (1) Execution guide in RStudio (e.g. `run_step("1.1")`), (2) Neutral observation guide, (3) Numbered decision options.
     - **Turn 2 (Post execution)**: (1) Evidence-based diagnosis reading `.txt`, (2) Open pedological questions, (3) Confirmation and next step.
   - **Sub-Steps**:
     - **Step 0 (`00_inspect_data.R`)**: Autodetects dataset; produces ultra-compact report (≤ 6-8 KB); strict filtering of true ID candidates, depths, coordinates, and properties.
     - **Step 1.1 (`01_1_byod_audit.R`)**: Validates config; supports 1 to N horizon sheets (`horizon_sheets`); checks non-unique keys on right sheets (`duplicate_key_strategy`); fails fast if essential variables (`profile_code`, `upper`, `lower`, coordinates) are missing; supports declarative sand summation (`sand_sum`).
     - **Step 1.2 (`01_2_byod_audit.R`)**: Audits coordinates; detects metric coordinates and asks for EPSG without guessing; spatial outlier audit combining 1D IQR and nearest-neighbor (k-NN) distance; warns of statistical limitations and requires visual map inspection.
     - **Step 1.3 (`01_3_byod_audit.R`)**: Audits vertical continuity separating join duplicates from true overlaps; texture balance (Clay+Sand+Silt); optional non-circular BD estimation in `BD_est` with validation metrics; logs all decisions.

---

## 2. Context Loading Order

1. [`docs/CONFIG_SCHEMA.md`](docs/CONFIG_SCHEMA.md) — canonical user configuration specification.
2. [`docs/DATA_CONTRACT.md`](docs/DATA_CONTRACT.md) — paths, schemas, and column conventions.
3. [`02_scripts/reference_modelling_v2.R`](02_scripts/reference_modelling_v2.R) — single source of truth for R modeling code.
4. [`docs/OPENNSIS_STANDARDS.md`](docs/OPENNSIS_STANDARDS.md) — COG standards and naming conventions.

---

## 3. Disciplinary Agent Roles

| Agent File | Role Name | Domain & Responsibilities |
| :--- | :--- | :--- |
| [`agents/r-engineer.md`](agents/r-engineer.md) | **R Specialist** | Robust R code (`terra`, `ranger`, `sf`); never modifies `02_scripts/`; enforces [`docs/CONFIG_SCHEMA.md`](docs/CONFIG_SCHEMA.md). |
| [`agents/geo-standards.md`](agents/geo-standards.md) | **Geospatial & OpenNSIS Architect** | CRS verification without guessing; bounding boxes, COG compression (`DEFLATE`, `predictor 2`), OpenNSIS naming. |
| [`agents/geostat-modeler.md`](agents/geostat-modeler.md) | **Geostatistician & Pedometrician** | Boruta selection, CV, QRF tuning, metrics ($R^2$, RMSE, CCC), uncertainty mapping, avoiding circular predictors. |
| [`agents/soil-scientist.md`](agents/soil-scientist.md) | **Pedologist & Soil Interpreter** | Pedological plausibility, bivariate coherence, texture balance, vertical continuity; unbiased pedagogical guidance. |
| [`agents/dsm-panel.md`](agents/dsm-panel.md) | **Unified DSM Panel** | Two-turn interactive orchestration, concise token-efficient responses (≤ 350-400 words), human-in-the-loop decisions. |
