# =====================================================================
# Framework Kit: integrated research workflow (template)
# Revised: 2026-11-05
# =====================================================================
# 11_export_tables.R - FIRST pass of the two-pass export: extract the
# numbers from the results workbooks into the published, numbered table
# objects. This script owns the NUMBERS. It never types a value by hand.
# Table IDs (ID01, ID02, ...) are the identifiers the cross-reference
# register binds to manuscript table numbers.
#
# Reporting precision: the decimal places below are the precision matrix,
# worksheet 14_Reporting_Precision of Templates/Analysis_Plan_Template.xlsx.
# Decide it in the plan before the analysis code is written; it is applied
# once, here, so every generated table complies by construction. Edit these
# values to your study's standard and keep the plan worksheet in step.
# Values are formatted as text so trailing zeros are kept (4.0, not 4).
PRECISION <- list(
  coef_natural = 1,  # coefficient in natural units (dependent_1 units); its SE and CI limits match
  coef_log     = 3,  # log-scale coefficient (log outcome); its SE and CI limits match
  p            = 3   # p value: three decimals, p < .001 floor, leading zero dropped
)
fmt_num <- function(x, digits) {
  out <- ifelse(is.na(x), NA_character_, sprintf("%.*f", digits, x))
  sub("^-(0\\.?0*)$", "\\1", out)    # no negative zero ("-0.0" becomes "0.0")
}
fmt_p <- function(p) {
  ifelse(is.na(p), NA_character_,
         ifelse(p < 0.001, "< .001", sub("^0\\.", ".", sprintf("%.*f", PRECISION$p, p))))
}
pub <- function(id, title, x) { x <- as.data.frame(x); write_table(x, sprintf("%s_%s", id, gsub("[^A-Za-z0-9]+", "_", title)), OUT_TABFIG); cat("  ", id, title, "\n") }
# digits: PRECISION$coef_natural for Aim 1 (dependent_1 in natural units),
# PRECISION$coef_log for Aim 2 (log(dependent_2 + 1)).
foc <- function(aim, model, terms, digits) { co <- read_model_coefs(aim, model); co <- co[co$term %in% terms, ]; data.frame(Term = co$term, Estimate = fmt_num(co$estimate, digits), `95% CI low` = fmt_num(co$ci_low, digits), `95% CI high` = fmt_num(co$ci_high, digits), p = fmt_p(co$p_value), check.names = FALSE) }
pub("ID01", "Aim 1 M2 focal coefficients", foc("Aim1", "AIM1-2A-M2", "independent_1_LOG1P", PRECISION$coef_natural))
pub("ID02", "Aim 1 M3 focal coefficients", foc("Aim1", "AIM1-2A-M3", "independent_2", PRECISION$coef_natural))
pub("ID03", "Aim 1 M7 focal coefficients", foc("Aim1", "AIM1-2A-M7", c("independent_1_LOG1P", "independent_2"), PRECISION$coef_natural))
pub("ID04", "Aim 2 M2 focal coefficients", foc("Aim2", "AIM2-2A-M2", "independent_1_LOG1P", PRECISION$coef_log))
pub("ID05", "Aim 2 M3 focal coefficients", foc("Aim2", "AIM2-2A-M3", "independent_2", PRECISION$coef_log))
lc <- if (.has_xlsx()) openxlsx::read.xlsx(file.path(OUT_CONV, "Log_Conversions.xlsx")) else read.csv(file.path(OUT_CONV, "Log_Conversions.csv"))
pub("ID06", "Real-terms conversions of the focal effects", lc[, c("aim", "model", "term", "real_terms")])
ts <- if (.has_xlsx()) openxlsx::read.xlsx(file.path(OUT_SENS, "Sensitivity_TOST.xlsx")) else read.csv(file.path(OUT_SENS, "Sensitivity_TOST.csv"))
# The kit's TOST rows are Aim 1 (natural units): estimate, 90% CI and margin at PRECISION$coef_natural.
for (v in intersect(c("estimate", "ci90_low", "ci90_high", "margin"), names(ts))) ts[[v]] <- fmt_num(ts[[v]], PRECISION$coef_natural)
pub("ID07", "Equivalence TOST results for the null findings", ts)
