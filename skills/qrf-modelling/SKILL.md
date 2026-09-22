---
name: qrf-modelling
description: Feature selection with Boruta and Quantile Regression Forest training with ranger/caret following reference_modelling_v2.R.
---

# Skill: Boruta Feature Selection & Quantile Regression Forest Modeling

This skill implements Session 1 of the official SoilFER reference script (`02_scripts/reference_modelling_v2.R`).

---

## 1. Procedure & Reference Implementation

### Step 1: Feature Selection with `Boruta`
```r
library(Boruta)

# Prepare complete cases
target <- "SOC"  # Target continuous property
d <- dat_cov %>%
  dplyr::select(all_of(target), all_of(cov_names)) %>%
  na.omit() %>% 
  as.data.frame()

set.seed(1)
boruta_result <- Boruta(
  y = d[, target],
  x = d[, cov_names],
  maxRuns = 100,
  doTrace = 1
)

# Extract confirmed and tentative predictors
selected_features <- getSelectedAttributes(boruta_result, withTentative = TRUE)

# Save and render Boruta importance plot
png(paste0("03_outputs/module3/figures/boruta_", target, ".png"), 
    width = 18, height = 22, units = "cm", res = 150)
par(las = 1, mar = c(4, 10, 4, 2) + 0.1)
plot(boruta_result, horizontal = TRUE, las = 1, ylab = "", xlab = "Importance", cex.axis = 0.7)
dev.off()

plot(boruta_result, horizontal = TRUE, las = 1, ylab = "", xlab = "Importance", cex.axis = 0.7)
```

### Step 2: Configure & Train Quantile Regression Forest (`ranger`)
```r
library(caret)
library(ranger)

# 1. Set up Cross-Validation
cv_control <- trainControl(
  method = "repeatedcv",
  number = 5,
  repeats = 5,
  savePredictions = TRUE
)

# 2. Hyperparameter Grid
mtry_base <- max(1, round(length(selected_features) / 3))
tune_grid <- expand.grid(
  mtry = c(max(1, mtry_base - round(mtry_base/2)), 
           mtry_base, 
           mtry_base + round(mtry_base/2)),
  min.node.size = 5,
  splitrule = c("variance", "extratrees")
)

# 3. Model Training
model <- caret::train(
  y = d[, target],
  x = d[, selected_features],
  method = "ranger",
  quantreg = TRUE,
  importance = "permutation",
  trControl = cv_control,
  tuneGrid = tune_grid,
  num.threads = max(1, parallel::detectCores() - 1)
)

# Save model object
saveRDS(model, paste0("03_outputs/module3/models/ranger_model_", target, ".rds"))

# Plot & save Variable Importance
plot(varImp(model), main = paste("Variable Importance -", target))
```

### Step 3: Accuracy Assessment & 1:1 Scatterplot
```r
# Extract predictions from best tuned combination
cv_preds <- model$pred %>%
  filter(mtry == model$bestTune$mtry,
         splitrule == model$bestTune$splitrule,
         min.node.size == model$bestTune$min.node.size)

obs_vals <- cv_preds$obs
pred_vals <- cv_preds$pred

# Validation Metrics
load("02_scripts/eval.RData")
accuracy <- eval(pred_vals, obs_vals)[, 1:6]
write_csv(accuracy, paste0("03_outputs/module3/validation/", target, "_accuracy.csv"))
print(accuracy)

# 1:1 Observed vs Predicted Scatterplot
residuals <- tibble(Observed = obs_vals, Predicted = pred_vals)
g_scatter <- ggplot(residuals, aes(x = Observed, y = Predicted)) +
  geom_point(alpha = 0.3, color = "steelblue") +
  geom_abline(slope = 1, intercept = 0, color = "red", linewidth = 1) +
  ylim(c(min(residuals$Observed), max(residuals$Observed))) +
  coord_fixed() +
  labs(title = paste("Observed vs Predicted -", target),
       subtitle = paste("R² =", round(accuracy$R2[1], 3), "| RMSE =", round(accuracy$RMSE[1], 3))) +
  theme_minimal()

print(g_scatter)
ggsave(g_scatter, filename = paste0("03_outputs/module3/figures/scatterplot_", target, ".png"),
       width = 12, height = 12, units = "cm")
```
