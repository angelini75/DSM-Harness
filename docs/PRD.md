# Product Requirements Document (`PRD.md`)

## 1. Project Identity & Purpose

**DSM-Harness** is an AI-orchestrated training harness for in-person workshops on **Digital Soil Mapping (DSM)** and **Soil Spectroscopy (DRS)**, developed in alignment with the **UN-FAO SoilFER** initiative and the **[OpenNSIS](https://github.com/un-fao/OpenNSIS)** spatial data infrastructure.

### The Problem
Traditional training requires allocating 40-50% of workshop time to teaching basic R programming syntax, package debugging, and file-path troubleshooting. In short, intensive workshops, this leaves insufficient room for deep pedological interpretation, uncertainty analysis, and country-level mapping clinics.

### The Solution
Students leverage a personal AI assistant (using free tiers of Gemini, ChatGPT, Claude, or Antigravity) governed by this harness. The AI assumes the role of an expert R developer and data architect, while the student acts as the **lead pedologist and decision-maker**, focusing on:
1. Validating national datasets (BYOD - Bring Your Own Data).
2. Inspecting diagnostic plots (correlations, spectra, 1:1 validation, spatial patterns).
3. Interpreting pedological plausibility and prediction uncertainty.
4. Delivering OpenNSIS-compliant continuous soil maps for their countries.

---

## 2. Target Audience

Soil scientists, pedometricians, GIS analysts, and national soil institute professionals. The workflow is modular and designed to adapt to workshops of variable duration (e.g. 3, 4, or 5 days).

---

## 3. Core Pedagogical Doctrines

### 1. "Visual Inspection-First" Rule
No AI-generated script shall execute calculations silently. Every single step must:
1. Render an immediate diagnostic or analytical plot in RStudio (interactive mapview, ggplot2 scatterplot, spectral curve, boxplot, or multi-panel raster).
2. Prompt the student with 2-3 focused pedological questions regarding what they observe in the graphic.

### 2. Strict Script Grounding ("No Invention")
All modeling and spatial prediction code must strictly mirror the official SoilFER reference implementation:
- `02_scripts/reference_modelling_v2.R` (Boruta feature selection, caret + ranger Quantile Regression Forest, tiled spatial interpolation, mosaic, and Viridis cartography).

### 3. Token-Lean Architecture (Free-Tier Resilient)
To prevent students from hitting AI rate limits or exhausting free daily quotas:
- Modular, single-purpose prompt cards (`cards/es/` and `cards/en/`).
- Conciseness directives: code first, minimal conversational filler.
- Dedicated Error Rescue Card (`cards/<lang>/00-error-rescue.md`) preventing full-script regeneration during debugging.

### 4. OpenNSIS Non-Blocking Advisory
Encourage ISO 28258 profile data structures, Cloud-Optimized GeoTIFF outputs, and ISO 19139 metadata through informative advisories without halting student progress when working with custom national data.

---

## 4. Modular Workflow Pipeline

| Stage | Methodological Module | Core Objective | Key Deliverable |
| :--- | :--- | :--- | :--- |
| **Stage 1** | BYOD Data Audit & Prep | Environment verification, coordinate validation in country boundary, depth check | Clean point dataset, coordinate validation map, depth check |
| **Stage 2** | Environmental Covariates | SCORPAN raster stack inspection, CRS reprojection, and point extraction | Aligned raster stack, extracted training table (`dat_cov`) |
| **Stage 3** | Soil Spectroscopy (DRS) | Preprocessing (`prospectr`: SNV, Savitzky-Golay), chemometric calibration | Spectral curves, chemometric model, augmented dataset |
| **Stage 4** | Predictive Modeling (QRF) | Quantile Regression Forest modeling, Boruta selection, cross-validation | Boruta importance, trained QRF model, 1:1 plot, metrics |
| **Stage 5** | Spatial Prediction & Delivery | Tiled spatial prediction, uncertainty estimation, OpenNSIS COG export | Mean prediction raster, SD uncertainty raster, OpenNSIS COG & metadata |

---

## 5. Reference Repositories

- [OpenNSIS](https://github.com/un-fao/OpenNSIS) — Open National Soil Information System (FAO).
- [SoilFER-Training-Manual](https://github.com/SoilFER/SoilFER-Training-Manual) — Technical Manual for SoilFER Training.
- [SoilFER-Training-Resources](https://github.com/SoilFER/SoilFER-Training-Resources) — Code, scripts, and practice datasets for SoilFER Training.
