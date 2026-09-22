# Product Requirements Document (`PRD.md`)

## 1. Project Identity & Purpose

**DSM-Harness** is an AI-orchestrated training harness for intensive 3.5-day in-person workshops on **Digital Soil Mapping (DSM)** and **Soil Spectroscopy (DRS)**, developed in alignment with the **UN-FAO SoilFER** initiative and the **OpenNSIS** spatial data infrastructure.

### The Problem
Traditional training requires allocating 40-50% of workshop time to teaching basic R programming syntax, package debugging, and file-path troubleshooting. In a 3.5-day timeframe, this leaves insufficient room for deep pedological interpretation, uncertainty analysis, and country-level mapping clinics.

### The Solution
Students leverage a personal AI assistant (using free tiers of Gemini, ChatGPT, Claude, or Antigravity) governed by this harness. The AI assumes the role of an expert R developer and data architect, while the student acts as the **lead pedologist and decision-maker**, focusing on:
1. Validating national datasets (BYOD - Bring Your Own Data).
2. Inspecting diagnostic plots (correlations, spectra, 1:1 validation, spatial patterns).
3. Interpreting pedological plausibility and prediction uncertainty.
4. Delivering OpenNSIS-compliant continuous soil maps for their countries.

---

## 2. Target Audience & Countries

Participants from 7 national soil institutes across Central America and the Caribbean:
- **Belize (BLZ)**
- **Costa Rica (CRI)**
- **Dominican Republic (DOM)**
- **El Salvador (SLV)**
- **Guatemala (GTM)**
- **Honduras (HND)**
- **Panama (PAN)**

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
- Modular, single-purpose prompt cards (`cards/`).
- Conciseness directives: code first, minimal conversational filler.
- Dedicated Error Rescue Card (`cards/00-error-rescue.md`) preventing full-script regeneration during debugging.

### 4. OpenNSIS Non-Blocking Advisory
Encourage ISO 28258 profile data structures, Cloud-Optimized GeoTIFF outputs, and ISO 19139 metadata through informative advisories without halting student progress when working with custom national data.

---

## 4. 3.5-Day Workflow Milestones

| Stage | Agenda Session | Core Objective | Key Deliverable |
| :--- | :--- | :--- | :--- |
| **Stage 1** | Day 1 PM - Day 2 AM | Environment Verification & BYOD Data Audit | Clean point dataset, coordinate validation map, depth check |
| **Stage 2** | Day 2 PM | Environmental Covariates Preparation & Extraction | Aligned raster stack, extracted training table (`dat_cov`) |
| **Stage 3** | Day 3 AM | Soil Spectroscopy (DRS) Preprocessing & Calibration | Spectral curves, chemometric model, augmented dataset |
| **Stage 4** | Day 3 PM | Quantile Regression Forest Modeling | Boruta selection, trained QRF model (`ranger`), 1:1 plot, metrics |
| **Stage 5** | Day 4 AM - PM | Spatial Prediction, Uncertainty & BYOD Clinic | Mean prediction raster, SD uncertainty raster, OpenNSIS COG |
| **Delivery** | Day 4 PM | National Presentation of Results | 5-minute country presentation of generated soil maps |
