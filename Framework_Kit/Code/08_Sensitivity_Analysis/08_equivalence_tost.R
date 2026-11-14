# =====================================================================
# Framework Kit: integrated research workflow (template)
# Revised: 2026-11-13 (margin note)
# =====================================================================
# 08_equivalence_tost.R - equivalence (TOST) for the null findings.
# A significance test can only fail to reject zero; TOST tests whether the
# effect is small enough to treat as zero. A null is certified as equivalent
# when its 90% confidence interval lies entirely inside the practical margin.
# The margin must be set BEFORE the equivalence outputs are generated and
# recorded, with its date, in the decision log (post hoc if the primary
# estimates were already known).
# DEMONSTRATION MARGIN ONLY. 0.2 SD of the outcome (Cohen's small effect) is a
# generic convention used here so the kit runs. In a real study the equivalence
# margin is a scientific decision: set it from the smallest effect that would
# matter in practice (a clinical, operational or regulatory threshold), justify
# it in the analysis plan, and record it with its date BEFORE results are seen.
MARGIN_AIM1 <- 0.2 * sd(df_main$dependent_1)   # demonstration margin, in outcome units
rows <- list()
for (spec in list(c("Aim1", "AIM1-2A-M3", "independent_2"))) {
  co <- read_model_coefs(spec[1], spec[2]); r <- co[co$term == spec[3], ]
  lo90 <- r$estimate - qnorm(0.95) * r$se; hi90 <- r$estimate + qnorm(0.95) * r$se
  verdict <- if (lo90 > -MARGIN_AIM1 && hi90 < MARGIN_AIM1) "equivalent within margin (precise null)" else if (r$p_value >= 0.05) "inconclusive: no evidence of effect, not precise enough to certify equivalence" else "not a null"
  rows[[length(rows) + 1]] <- data.frame(aim = spec[1], model = spec[2], term = spec[3], estimate = r$estimate, ci90_low = lo90, ci90_high = hi90, margin = MARGIN_AIM1, verdict = verdict)
}
out <- do.call(rbind, rows); write_table(out, "Sensitivity_TOST", OUT_SENS); cat("TOST:", paste(out$term, out$verdict, sep = ": "), "\n")
