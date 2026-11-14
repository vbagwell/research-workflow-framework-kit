# =====================================================================
# Framework Kit: integrated research workflow (template)
# Revised: 2026-09-11
# =====================================================================
# 08_alternative_clustering.R - re-estimate the standard errors of the focal
# coefficients under an alternative cluster definition (here the stratum by
# cluster interaction as a coarser level). Point estimates are held fixed;
# only the variance estimator changes, so the comparison isolates the
# clustering choice.
fit <- lm(dependent_1 ~ independent_1_LOG1P + independent_3 + control_1 + control_2 + period_c, df_main)
alt <- paste(df_main$stratum, substr(df_main$cluster_id, 1, 3))
a <- extract_clustered_coefs(fit, df_main$cluster_id); b <- extract_clustered_coefs(fit, alt)
out <- data.frame(term = a$term, estimate = a$estimate, se_primary = a$se, se_alternative = b$se, p_primary = a$p_value, p_alternative = b$p_value)
write_table(out[out$term == "independent_1_LOG1P", ], "Sensitivity_Clustering", OUT_SENS); cat("Alternative clustering: done\n")
