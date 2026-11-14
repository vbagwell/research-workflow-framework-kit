# =====================================================================
# Framework Kit: integrated research workflow (template)
# Revised: 2026-11-06 (stable output names, rewritten each run)
# =====================================================================
# 00_data_diagnostic_general.R - Layer 2 diagnostic: the joint structure.
# Fits no model for inference. Recommends a count family per outcome,
# detects complete and quasi-separation, screens collinearity (correlation
# and VIF), classifies missingness, measures cluster sizes and ICC. Every
# finding that meets a threshold becomes a FLAG with severity, category,
# variables, action and a pointer to its source.
# OUTPUT NAMES ARE STABLE (changed 2026-11-06): every run rewrites the same
# Diag_*.xlsx files and the run log, so the reproducibility verifier can
# compare run against run. Timestamped file names made every run look like a
# new set of outputs and left the previous set behind as stale files. The run
# stamp is kept inside the FLAGS table (column run) and in the log.
# The flag comparison against the previous run reads the previous FLAGS file
# before it is overwritten.
# Timestamps are written in the full "YYYY-MM-DD HH:MM:SS" form, which the
# reproducibility verifier masks before comparing runs.
stamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S"); logf <- file.path(OUT_DIAG, "diagnostic_run_log.txt")
if (file.exists(logf)) file.remove(logf)
logit <- function(...) cat(format(Sys.time(), "%Y-%m-%d %H:%M:%S"), ..., "\n", file = logf, append = TRUE)
prev_flags <- { f <- file.path(OUT_DIAG, if (requireNamespace("openxlsx", quietly = TRUE)) "Diag_FLAGS.xlsx" else "Diag_FLAGS.csv")
  if (file.exists(f)) tryCatch(if (grepl("xlsx$", f)) openxlsx::read.xlsx(f) else read.csv(f), error = function(e) NULL) else NULL }
flags <- list(); flag <- function(sev, cat_, vars, finding, action, source) flags[[length(flags) + 1]] <<- data.frame(severity = sev, category = cat_, variables = vars, finding = finding, suggested_action = action, source = source, stringsAsFactors = FALSE)
logit("start general diagnostic", stamp)
# --- count family per outcome
fam <- do.call(rbind, lapply(c("dependent_2"), function(o) { v <- df_main[[o]]; vmr <- var(v) / mean(v); pz <- mean(v == 0); pz_pois <- mean(dpois(0, mean(v)))
  rec <- if (vmr > 1.5 && pz > pz_pois + 0.1) "screen: negative-binomial hurdle (over-dispersed, excess zeros) - provisional; confirm by fitting and comparing candidate families" else if (vmr > 1.5) "screen: negative binomial - provisional; compare with Poisson by fit" else "screen: Poisson - provisional"
  if (vmr > 1.5) flag("HIGH", "dispersion", o, sprintf("variance-to-mean %.2f, observed zeros %.1f%% vs Poisson-expected %.1f%%", vmr, 100 * pz, 100 * pz_pois), rec, "CountFamily")
  data.frame(outcome = o, var_to_mean = vmr, pct_zero = 100 * pz, pct_zero_poisson = 100 * pz_pois, recommended_family = rec) }))
logit("count family done")
# --- separation of categorical levels against a binary outcome (any dependent_2 > 0)
anyy <- as.integer(df_main$dependent_2 > 0); sep <- list()
for (v in c("independent_3", "control_2", "stratum")) { tb <- table(df_main[[v]], anyy); for (lv in rownames(tb)) { if (any(tb[lv, ] == 0)) { sep[[length(sep) + 1]] <- data.frame(variable = v, level = lv, n = sum(tb[lv, ]), separated = TRUE); flag("CRITICAL", "separation", v, paste("level", lv, "is completely separated on any(dependent_2)"), "collapse the level or set as structural zero", "Separation") } } }
sep <- if (length(sep)) do.call(rbind, sep) else data.frame(variable = character(), level = character(), n = integer(), separated = logical())
logit("separation done")
# --- collinearity: correlations among continuous predictors and VIF
cont <- c("independent_1_LOG1P", "independent_2", "control_1", "period_c"); cm <- cor(df_main[, cont])
pairs <- which(abs(cm) > 0.8 & upper.tri(cm), arr.ind = TRUE)
for (i in seq_len(nrow(pairs))) flag("HIGH", "collinearity", paste(cont[pairs[i, 1]], cont[pairs[i, 2]]), sprintf("r = %.2f", cm[pairs[i, 1], pairs[i, 2]]), "declare as alternatives; never enter both", "Correlation")
vif <- extract_vif(lm(dependent_1 ~ independent_1_LOG1P + independent_2 + independent_3 + control_1 + control_2 + period_c, df_main))
for (i in which(vif$vif > 5)) flag("MEDIUM", "collinearity", vif$term[i], sprintf("VIF %.1f", vif$vif[i]), "check whether design-accepted (temporal block) or a specification problem", "VIF")
logit("collinearity done")
# --- missingness class
miss <- data.frame(variable = names(df), pct_missing = sapply(df, function(x) 100 * mean(is.na(x))))
for (i in which(miss$pct_missing > 5)) flag("MEDIUM", "missingness", miss$variable[i], sprintf("%.1f%% missing", miss$pct_missing[i]), "test association with outcome and time before assuming ignorable", "Missingness")
# --- cluster structure and ICC (one-way ANOVA estimator on dependent_1)
cs <- table(df_main$cluster_id); a <- anova(lm(dependent_1 ~ cluster_id, df_main)); k <- length(cs); n <- nrow(df_main)
msb <- a$`Mean Sq`[1]; msw <- a$`Mean Sq`[2]; n0 <- (n - sum(cs^2) / n) / (k - 1); icc <- (msb - msw) / (msb + (n0 - 1) * msw)
clus <- data.frame(clusters = k, min_size = min(cs), median_size = median(cs), max_size = max(cs), icc_dependent_1 = icc)
if (icc > 0.05) flag("INFO", "clustering", "cluster_id", sprintf("ICC %.3f on dependent_1", icc), "cluster-robust SE on cluster_id (already the rule)", "Clusters")
logit("clusters done")
F <- if (length(flags)) do.call(rbind, flags) else data.frame(severity = character(), category = character(), variables = character(), finding = character(), suggested_action = character(), source = character())
F$run <- stamp
write_table(fam, "Diag_CountFamily", OUT_DIAG); write_table(sep, "Diag_Separation", OUT_DIAG)
write_table(data.frame(term = rownames(cm), round(cm, 3)), "Diag_Correlation", OUT_DIAG); write_table(vif, "Diag_VIF", OUT_DIAG)
write_table(miss, "Diag_Missingness", OUT_DIAG); write_table(clus, "Diag_Clusters", OUT_DIAG); write_table(F, "Diag_FLAGS", OUT_DIAG)
# run-to-run comparison of flags (against the FLAGS file this run replaced)
if (!is.null(prev_flags) && nrow(prev_flags)) { p <- prev_flags; key <- function(d) paste(d$category, d$variables, d$finding)
  cat("Flags vs previous run:", sum(!(key(F) %in% key(p))), "new,", sum(!(key(p) %in% key(F))), "resolved,", sum(key(F) %in% key(p)), "persisting\n") }
cat("General diagnostic:", nrow(F), "flags (", paste(names(table(F$severity)), table(F$severity), collapse = ", "), ")\n"); logit("end")
