# Task Card 04: Boruta & Quantile Regression Forest (`04-qrf-modeling-card.md`)

> **USE THIS CARD FOR DAY 3 PM: BORUTA FEATURE SELECTION & QRF MODELING.**  
> Copy and paste this prompt into your web chat (ChatGPT / Gemini / Claude).

---

### [PROMPT TO COPY AND PASTE]

```markdown
You are acting as the Unified DSM Panel (`dsm-panel`) for the FAO/SoilFER Digital Soil Mapping course.
I need to run feature selection with Boruta and train a Quantile Regression Forest model in RStudio.

Context:
- Working directory: Root of DSM-Harness.Rproj
- Modeling dataset: `dat_cov` (prepared with soil observations and extracted covariates)
- Target property: `{{TARGET_PROPERTY, e.g. SOC}}`
- Reference script: Strictly follow Session 1 of `02_scripts/reference_modelling_v2.R`

Please provide:
1. An R script strictly adhering to `02_scripts/reference_modelling_v2.R` that:
   - Runs `Boruta::Boruta()` for feature selection with complete cases.
   - MANDATORY PLOT 1: Generates and displays the Boruta importance plot (`plot(boruta_result)`).
   - Extracts confirmed and tentative features (`getSelectedAttributes()`).
   - Configures repeated cross-validation (`repeatedcv`, 5 folds, 5 repeats).
   - Trains a Quantile Regression Forest model with `caret::train(method = "ranger", quantreg = TRUE, importance = "permutation")`.
   - Saves the trained model to `03_outputs/module3/models/`.
   - MANDATORY PLOT 2: Displays variable importance (`plot(varImp(model))`).
   - Evaluates predictions using `02_scripts/eval.RData` and saves accuracy metrics to CSV.
   - MANDATORY PLOT 3: Renders an Observed vs Predicted 1:1 scatterplot with `ggplot2`.
2. A Statistical checkpoint detailing how to interpret the RMSE, $R^2$, and CCC metrics.
3. Two pedological questions challenging me to evaluate whether the top ranked environmental covariates make sense for the soil forming factors (SCORPAN) in my country.

Please respond in: English.
```
