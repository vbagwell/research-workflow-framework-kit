# =====================================================================
# Framework Kit: integrated research workflow (template)
# Revised: 2026-09-11
# =====================================================================
# 00_variable_summary.R - Layer 1 diagnostic: profile every variable in
# isolation. The univariate facts (skew, zero inflation, dispersion,
# near-constancy, missingness) decide which model families are candidates.
# Output: Results/04_Variable_Summary/Variable_Summary (one row per column)
# and the codebook of metric definitions. Populates 03_VarSummary_Results
# of the plan workbook.
prof <- function(x, name) {
  num <- is.numeric(x); n <- length(x); miss <- sum(is.na(x)); v <- x[!is.na(x)]
  row <- data.frame(variable = name, type = if (num) "numeric" else "categorical", n = n, missing = miss,
                    pct_missing = round(100 * miss / n, 2), distinct = length(unique(v)), stringsAsFactors = FALSE)
  if (num) {
    m <- mean(v); s <- sd(v); z <- mean(v == 0)
    sk <- if (s > 0) mean((v - m)^3) / s^3 else NA; ku <- if (s > 0) mean((v - m)^4) / s^4 - 3 else NA
    vmr <- if (m != 0) var(v) / m else NA
    shape <- if (is.na(sk)) "constant" else if (abs(sk) < 0.5) "symmetric" else if (sk > 2) "heavily right-skewed" else if (sk > 0) "right-skewed" else "left-skewed"
    row <- cbind(row, data.frame(mean = m, sd = s, median = median(v), min = min(v), max = max(v), pct_zero = round(100 * z, 1),
                                 var_to_mean = vmr, skewness = sk, excess_kurtosis = ku, shape = shape,
                                 zero_inflation = if (z > 0.5) "high" else if (z > 0.2) "moderate" else "low",
                                 near_constant = (s / max(abs(m), 1e-9)) < 0.01))
  } else {
    tb <- sort(table(v), decreasing = TRUE)
    row <- cbind(row, data.frame(mean = NA, sd = NA, median = NA, min = NA, max = NA, pct_zero = NA, var_to_mean = NA, skewness = NA,
                                 excess_kurtosis = NA, shape = "categorical", zero_inflation = NA,
                                 near_constant = (tb[1] / length(v)) > 0.99))
    row$dominant_level <- names(tb)[1]; row$dominant_pct <- round(100 * tb[1] / length(v), 1)
  }
  row
}
summ <- do.call(rbind, lapply(names(df), function(nm) { r <- prof(df[[nm]], nm); if (is.null(r$dominant_level)) { r$dominant_level <- NA; r$dominant_pct <- NA }; r }))
codebook <- data.frame(metric = c("var_to_mean", "zero_inflation", "skewness", "shape", "near_constant"),
  definition = c("variance divided by mean; > 1 signals over-dispersion for a count (negative binomial over Poisson)",
                 "share of zeros: high > 50%, moderate > 20%; high suggests a hurdle or zero-inflated structure",
                 "population moment estimator; |skew| > 2 suggests a log transform or a skewed-outcome family",
                 "synthesised label from skewness", "sd/mean < 1% or one level > 99%: candidate to drop, will separate"))
write_table(summ, "Variable_Summary", OUT_VARSUM); write_table(codebook, "Variable_Summary_Codebook", OUT_VARSUM)
cat("Variable summary:", nrow(summ), "variables profiled\n")
