# =====================================================================
# Framework Kit: integrated research workflow (template)
# Revised: 2026-09-11
# =====================================================================
# AIM1-2A-M1 - baseline: controls only
# One model = one script = a formula and a label. Everything else (cluster-
# robust SE, fit statistics, VIF, writing) is done by 01_helpers.R.
res <- fit_and_capture(dependent_1 ~ independent_3 + control_1 + control_2 + period_c, df_main, "AIM1-2A-M1")
write_model_sheet(res, aim = "Aim1", model = "AIM1-2A-M1")
cat("  AIM1-2A-M1:", nrow(res$coefs), "terms, N =", res$fit_stats$N, "\n")
