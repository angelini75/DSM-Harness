---
name: spectra-drs
description: Diffuse Reflectance Spectroscopy (DRS) preprocessing, chemometric calibration, and augmented dataset assembly.
---

# Skill: Soil Spectroscopy (DRS) Integration for DSM

This skill implements spectral preprocessing, chemometric modeling, and the integration of DRS-predicted soil observations with conventional laboratory measurements into an augmented DSM dataset.

---

## 1. Procedure & Checklist

### Step 1: Read & Visualize Raw Spectra
1. Load spectral matrix (rows = soil samples, columns = wavelengths or wavenumbers in Vis-NIR or MIR).
2. Clean column names to numeric wavelengths:
   ```r
   wavelengths <- as.numeric(gsub("[^0-9.]", "", colnames(spectra)))
   ```
3. Plot raw reflectance / absorbance spectra:
   ```r
   matplot(wavelengths, t(spectra), type = "l", lty = 1, col = rgb(0, 0, 0, 0.1),
           xlab = "Wavelength (nm)", ylab = "Reflectance", main = "Raw Soil Spectra")
   ```

### Step 2: Preprocessing with `prospectr`
1. **Standard Normal Variate (SNV)** to remove scatter and particle-size baseline shifts:
   ```r
   library(prospectr)
   sp_snv <- standardNormalVariate(X = spectra)
   ```
2. **Savitzky-Golay Smoothing & Derivatives**:
   ```r
   # 1st derivative with polynomial order 2 and window size 11
   sp_sg <- savitzkyGolay(X = sp_snv, m = 1, p = 2, w = 11)
   ```
3. Plot preprocessed spectra to verify characteristic absorption features (e.g. clay lattice hydroxyls at 1400/2200 nm, organic matter across visible region, water bands at 1900 nm).

### Step 3: Chemometric Model Calibration
1. Split into calibration (70-80%) and validation (20-30%) using Kennard-Stone sampling:
   ```r
   sel <- kenStone(X = sp_sg, k = round(0.75 * nrow(sp_sg)))
   cal_idx <- sel$model
   val_idx <- sel$test
   ```
2. Train Random Forest / PLS model:
   ```r
   library(ranger)
   rf_spec <- ranger(
     y = target_lab[cal_idx],
     x = sp_sg[cal_idx, ],
     num.trees = 500,
     importance = "impurity"
   )
   ```
3. Evaluate calibration performance ($R^2$, RMSE, RPD) on the test set.

### Step 4: Assembling the Augmented Dataset
1. Predict target soil property on all unanalyzed spectral samples:
   ```r
   spec_preds <- predict(rf_spec, data = sp_sg[!has_lab_measurement, ])$predictions
   ```
2. Combine traditional laboratory measurements and DRS-derived predictions into a unified training dataset with an origin flag (`data_source: "LAB"` vs `"DRS"`).
3. Compute prediction variance to propagate DRS uncertainty into the downstream DSM stage.
