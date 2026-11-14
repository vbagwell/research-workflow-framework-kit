# =====================================================================
# Framework Kit: integrated research workflow (template)
# Revised: 2026-09-11
# =====================================================================
# AIM1-1U-M0 - univariate screen: each registered predictor entered singly.
# A descriptive first look, not a hypothesis test and not in the focal family.
u <- fit_univariate_table("dependent_1", c("independent_1_LOG1P", "independent_2", "independent_3", "control_1", "control_2", "period_c"), df_main)
write_table(u, "Aim1_AIM1-1U-M0_univariate", OUT_AIMS)
cat("  AIM1-1U-M0: univariate screen,", length(unique(u$predictor)), "predictors\n")
