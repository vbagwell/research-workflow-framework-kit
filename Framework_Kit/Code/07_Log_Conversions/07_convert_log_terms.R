# =====================================================================
# Framework Kit: integrated research workflow (template)
# Revised: 2026-11-05
# =====================================================================
# 07_convert_log_terms.R - re-express log-scale effects in real terms, in a
# separate stage after estimation so the original model scale is preserved.
# RULES (state them once here and in 5.1 Reporting Conventions):
#   predictor entered as log(x + 1): coefficient b is per log-unit of (x + 1);
#     b * ln(2) is the change per DOUBLING of (x + 1), which only approximates
#     a doubling of x when x is large.
#   outcome modeled as log(y + 1): exp(b) is a ratio of adjusted geometric
#     means of (y + 1); 100 * (exp(b) - 1) is the exact percent change in that
#     geometric mean, NOT in the arithmetic-mean raw y.
# PRECISION (plan worksheet 14_Reporting_Precision): natural-unit effects at
#   one decimal, percent changes at one decimal, CI limits matched.
rows <- list()
for (spec in list(c("Aim1", "AIM1-2A-M2", "independent_1_LOG1P", "log-predictor"), c("Aim1", "AIM1-2A-M3", "independent_2", "linear"),
                  c("Aim2", "AIM2-2A-M2", "independent_1_LOG1P", "log-both"), c("Aim2", "AIM2-2A-M3", "independent_2", "log-outcome"))) {
  co <- read_model_coefs(spec[1], spec[2]); r <- co[co$term == spec[3], ]; b <- r$estimate; lo <- r$ci_low; hi <- r$ci_high
  conv <- switch(spec[4],
    "log-predictor" = sprintf("%.1f units per doubling of (x + 1) [95%% CI %.1f to %.1f]", b * log(2), lo * log(2), hi * log(2)),
    "linear"        = sprintf("%.1f units per unit of x [95%% CI %.1f to %.1f]", b, lo, hi),
    "log-outcome"   = sprintf("%.1f%% change in the adjusted geometric mean of (y + 1) per unit of x [95%% CI %.1f%% to %.1f%%]", 100 * (exp(b) - 1), 100 * (exp(lo) - 1), 100 * (exp(hi) - 1)),
    "log-both"      = sprintf("%.1f%% change in the adjusted geometric mean of (y + 1) per e-fold change in (x + 1) [95%% CI %.1f%% to %.1f%%]", 100 * (exp(b) - 1), 100 * (exp(lo) - 1), 100 * (exp(hi) - 1)))
  rows[[length(rows) + 1]] <- data.frame(aim = spec[1], model = spec[2], term = spec[3], estimate = b, ci_low = lo, ci_high = hi, p_value = r$p_value, conversion_rule = spec[4], real_terms = conv)
}
out <- do.call(rbind, rows); write_table(out, "Log_Conversions", OUT_CONV); cat("Log conversions:", nrow(out), "terms converted\n")
