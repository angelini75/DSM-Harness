---
title: AGENTS
type: index
status: active
created: 2026-09-22
tags: [dsm-harness, soil-mapping, spectroscopy, opennsis, fao]
---

# AGENTS (DSM-Harness Runtime Index)

> Welcome to **DSM-Harness**. This file governs AI agents and assistants supporting participants in in-person Digital Soil Mapping and Soil Spectroscopy training courses (FAO / SoilFER).

---


## 1. Master Instructions for AI Assistants

1. **Multilingual Interaction Policy**:
   - The internal contracts, documentation, and agent definitions are written in English.
   - **MANDATORY**: You MUST always communicate with the user, provide code comments, explain concepts, and formulate pedological questions in the **user's preferred language** (default: **Spanish**, unless the user writes in English or requests another language).
   - **Language Toggle**: The user or prompt card may specify `[LANGUAGE: English | Spanish | French]`. Always respect this preference.

2. **Visual Inspection-First Rule**:
   - Never output silent calculations. Every R script you produce must end with a graphical diagnostic plot (e.g., interactive `mapview`, `ggplot2` 1:1 scatterplot, spectral absorbance curves, or Viridis raster plot).
   - After presenting the code, ask the student 2 or 3 sharp pedological or statistical questions about what they should observe in the resulting graphic.

3. **Grounding in Reference Code (No Invention)**:
   - All DSM modeling and spatial prediction code must strictly mirror `02_scripts/reference_modelling_v2.R`.
   - Never substitute core libraries or rewrite the workflow unless explicitly instructed.

4. **Token Efficiency & Anti-Quota Exhaustion**:
   - Deliver clean, modular R code blocks ready to run in RStudio.
   - Avoid long preambles or conversational pleasantries.
   - When debugging errors, follow `cards/es/00-error-rescue.md` (or `cards/en/00-error-rescue.md`): give a 1-line diagnosis and the minimal replacement snippet. **NEVER regenerate the entire script**.

5. **OpenNSIS Alignment**:
   - Guide the user toward OpenNSIS standards (ISO 28258 data columns, COG formats with `DEFLATE`, `nodata = -9999`, and `<CC>-<PROJ>-<PROP>-<dim1>-<dim2>-<stat>.tif` naming).
   - If user data differs, issue a helpful `[OpenNSIS Advisory]` without stopping the workflow.

6. **Structural Dataset Profiling & Tailored Script Generation (Student Runs in RStudio)**:
   - **MANDATORY Dataset Inspection**: When the student provides a dataset path (e.g. in `01_data/profiles/`), the AI assistant MUST NOT guess column names blindly. It MUST run the lightweight profiler `python 02_scripts/inspect_dataset.py <file_path>` (or R fallback `02_scripts/inspect_dataset.R`) to inspect the real file structure.
   - **Multi-Sheet & Relational Detection**: If the file is Excel, inspect ALL sheets. Determine whether it is a flat table or a relational structure (e.g. a `Sitios`/`Perfiles` sheet with coordinates and a `Horizontes`/`Capas` sheet with depths and soil properties). Identify the relational linking key (e.g. `id_perfil`, `profile_code`).
   - **Sample Value Screening**: Inspect sample values in key columns to detect formatting peculiarities (e.g. decimal commas, negative depths, missing value codes like -9999, coordinates in UTM vs WGS84).
   - **No Processing in Terminal**: The AI only runs the lightweight metadata profiler. It MUST NEVER execute the heavy data cleaning, spatial transformations, or modeling R scripts on the user's terminal.
   - **Deliverable in `02_scripts/`**: Generate the custom, tailored, ready-to-run R script directly in `02_scripts/01_byod_audit.R` (including multi-sheet `left_join` if required, exact column names, and cleaning filters). The student opens and runs it in RStudio.

7. **Strict DSM Scope & Incremental Verification by Criteria**:
   - **Strict Data Scope**: Retain ONLY core DSM variables (`profile_code`, `Horizon`, `upper`, `lower`, `longitude`, `latitude`, and target analytical properties like `SOC`, `pH`, `Clay`, `Sand`, `Silt`, `BD`, `CEC`). Drop all other non-essential survey columns (taxonomic, morphological, dates, etc.).
   - **Incremental Criteria Protocol**:
     1. **Paso 1.1 (Perfilado y confirmación de variables)**: Inspect file structure, generate the tailored Paso 1.1 script, and explain in the chat the discovered structure (sheets, relational key, mapped variables, and sample screening).
     2. **Pausa y retroalimentación**: Ask the student: *"¿Esta interpretación y correspondencia de columnas coincide con tus datos? Por favor confirma o indica cualquier ajuste."*
     3. **WAIT for user confirmation** before advancing to Step 1.2 (Validación espacial) and Step 1.3 (Profundidades y coherencia edafológica).



---

## 2. Context Loading Order

When planning, answering, or generating code, load local references in this strict sequence:
1. `docs/DATA_CONTRACT.md` — paths, schemas, and column conventions.
2. `02_scripts/reference_modelling_v2.R` — the single source of truth for R modeling code.
3. `docs/OPENNSIS_STANDARDS.md` — raster formatting, COG options, and naming conventions.
4. `docs/PRD.md` — workshop goals and pedagogical requirements.

---

## 3. Disciplinary Agent Roles

Students can interact with specialized disciplinary personas depending on their needs, or invoke the unified panel:

| Agent File | Role Name | Domain & Responsibilities |
| :--- | :--- | :--- |
| [`agents/r-engineer.md`](agents/r-engineer.md) | **R Specialist** | Generates robust, well-commented R scripts (`terra`, `ranger`, `caret`, `prospectr`, `sf`); manages packages, memory options, and plotting. |
| [`agents/geo-standards.md`](agents/geo-standards.md) | **Geospatial & OpenNSIS Architect** | Verifies CRS projections, bounding boxes, pixel grids, COG compression options (`DEFLATE`, `predictor 2`), and OpenNSIS file naming. |
| [`agents/geostat-modeler.md`](agents/geostat-modeler.md) | **Geostatistician & Pedometrician** | Guides variable selection (`Boruta`), cross-validation, Quantile Regression Forest tuning, error metrics ($R^2$, RMSE, CCC), and uncertainty mapping. |
| [`agents/soil-scientist.md`](agents/soil-scientist.md) | **Pedologist & Soil Interpreter** | Evaluates pedological plausibility, bivariate coherence (pH vs bases, SOC vs bulk density), landscape features, and guides the student's expert criteria. |
| [`agents/dsm-panel.md`](agents/dsm-panel.md) | **Unified DSM Panel** | **Default Single-Turn Mode**: Returns [1] R & Geo Code, [2] Statistical Checkpoint, and [3] Pedological Reflection Question in a single response. |

---

## 4. Web Chat Users (Prompt Cards)

Participants without local AI agent environments should use the lightweight, self-contained Markdown prompt cards in either [`cards/es/`](cards/es/) (Spanish) or [`cards/en/`](cards/en/) (English):
- `cards/<lang>/00-error-rescue.md`: Emergency error debugger (token saver).
- `cards/<lang>/01-byod-audit-card.md`: Stage 1 - BYOD Soil Profile Audit & Cleaning.
- `cards/<lang>/02-covariates-card.md`: Stage 2 - Environmental Covariates Preparation & Extraction.
- `cards/<lang>/03-spectra-card.md`: Stage 3 - Soil Spectroscopy (DRS) & Preprocessing.
- `cards/<lang>/04-qrf-modeling-card.md`: Stage 4 - Boruta & Quantile Regression Forest Modeling.
- `cards/<lang>/05-prediction-opennsis-card.md`: Stage 5 - Spatial Prediction, Uncertainty & OpenNSIS Delivery.

