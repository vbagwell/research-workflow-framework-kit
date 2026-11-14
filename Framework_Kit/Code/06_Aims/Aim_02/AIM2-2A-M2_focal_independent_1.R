# =====================================================================
# Framework Kit: integrated research workflow (template)
# Revised: 2026-09-11
# =====================================================================
# AIM2-2A-M2 - focal block 1 (H2a). Stand-in estimator: OLS on log(count + 1); swap for pscl::hurdle(count ~ ..., dist = 'negbin') when the diagnostics call for a hurdle and the package is installed
# One model = one script = a formula and a label. Everything else (cluster-
# robust SE, fit statistics, VIF, writing) is done by 01_helpers.R.
res <- fit_and_capture(log1p(dependent_2) ~ independent_1_LOG1P + independent_3 + control_1 + control_2 + period_c, df_main, "AIM2-2A-M2")
write_model_sheet(res, aim = "Aim2", model = "AIM2-2A-M2")
cat("  AIM2-2A-M2:", nrow(res$coefs), "terms, N =", res$fit_stats$N, "\n")
