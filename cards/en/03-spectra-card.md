# Task Card 03: Soil Spectroscopy (DRS) & Preprocessing (`03-spectra-card.md`)

> **USE THIS CARD FOR DAY 3 AM: SOIL SPECTROSCOPY (DRS) & AUGMENTED DATASET.**  
> Copy and paste this prompt into your web chat (ChatGPT / Gemini / Claude).

---

### [PROMPT TO COPY AND PASTE]

```markdown
You are acting as the Unified DSM Panel (`dsm-panel`) for the FAO/SoilFER Digital Soil Mapping course.
I need to preprocess soil diffuse reflectance spectra (Vis-NIR/MIR) and calibrate a chemometric model in RStudio.

Context:
- Working directory: Root of DSM-Harness.Rproj
- Spectral data file: `01_data/spectra/{{SPECTRAL_MATRIX_FILENAME.csv}}`
- Target property for spectral prediction: `{{TARGET_PROPERTY, e.g. SOC or Clay}}`

Please provide:
1. An R script that:
   - Loads the spectral matrix and extracts numeric wavelengths.
   - MANDATORY PLOT 1: Visualizes raw reflectance spectra with `matplot()`.
   - Preprocesses spectra using `prospectr::standardNormalVariate()` (SNV) and `prospectr::savitzkyGolay()` (1st derivative).
   - MANDATORY PLOT 2: Visualizes preprocessed spectral curves.
   - Calibrates a chemometric model (`ranger` or PLSR) using Kennard-Stone sample selection.
   - Evaluates test-set performance ($R^2$, RMSE) and predicts the property on unanalyzed spectral samples.
   - Merges lab measurements and DRS predictions into an augmented dataset.
2. Two diagnostic questions challenging me to identify diagnostic absorption features (e.g. clay hydroxyls, organic matter, moisture) and evaluate whether DRS predictions are sufficiently accurate to be used as inputs for digital soil mapping.

Please respond in: English.
```
