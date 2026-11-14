# =====================================================================
# Framework Kit: integrated research workflow (template)
# Revised: 2026-09-11
# =====================================================================
# AIM1-2A-M7 - saturated: all focal blocks plus an interaction block (robustness)
# One model = one script = a formula and a label. Everything else (cluster-
# robust SE, fit statistics, VIF, writing) is done by 01_helpers.R.
res <- fit_and_capture(dependent_1 ~ independent_1_LOG1P + independent_2 + independent_1_LOG1P:independent_3 + independent_3 + control_1 + control_2 + period_c, df_main, "AIM1-2A-M7")
write_model_sheet(res, aim = "Aim1", model = "AIM1-2A-M7")
cat("  AIM1-2A-M7:", nrow(res$coefs), "terms, N =", res$fit_stats$N, "\n")
