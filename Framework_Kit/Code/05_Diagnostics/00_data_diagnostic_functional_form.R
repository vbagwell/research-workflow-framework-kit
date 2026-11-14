# =====================================================================
# Framework Kit: integrated research workflow (template)
# Revised: 2026-11-06 (stable output names, rewritten each run)
# =====================================================================
# 00_data_diagnostic_functional_form.R - Layer 4 diagnostic: for every
# continuous predictor, compare a straight line with a natural cubic spline
# by AIC and a likelihood-ratio test and emit a recommended form. Pre-
# modeling only: OLS is used to gauge shape; production models keep their
# own inference. The analyst chooses the final form from this and theory.
library(splines)
out <- do.call(rbind, lapply(c("independent_1_LOG1P", "control_1", "period_c"), function(v) {
  f0 <- lm(reformulate(v, "dependent_1"), df_main); f1 <- lm(as.formula(paste("dependent_1 ~ ns(", v, ", df = 4)")), df_main)
  lr <- anova(f0, f1); data.frame(predictor = v, AIC_linear = AIC(f0), AIC_spline = AIC(f1), LR_p = lr$`Pr(>F)`[2],
    recommended = if (AIC(f1) + 2 < AIC(f0) && lr$`Pr(>F)`[2] < 0.01) "spline or categorical form" else "linear") }))
write_table(out, "Diag_FunctionalForm", OUT_DIAG)   # stable name (2026-11-06): rewritten each run, so runs can be compared
cat("Functional form:", paste(out$predictor, out$recommended, sep = " -> ", collapse = "; "), "\n")
