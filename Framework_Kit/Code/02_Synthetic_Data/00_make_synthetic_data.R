# =====================================================================
# Framework Kit: integrated research workflow (template)
# File:    00_make_synthetic_data.R
# Purpose: Generate a synthetic dataset so the whole kit runs end to end
#          without any real data. Writes Data/Study_Data.csv, the frozen
#          input that is the reproducibility boundary of the kit.
# Revised: 2026-11-13 (optional KIT_MISSING_RATE for testing with missing values)
# =====================================================================
# THE VARIABLES (generic names, replace with your own in the registry)
#   record_id       one row per record
#   cluster_id      the grouping unit for cluster-robust standard errors
#   stratum         a two-level stratum (A / B) for stratified re-estimation
#   dependent_1     continuous outcome (Aim 1), right-skewed, in units
#   dependent_2     count outcome with excess zeros (Aim 2)
#   independent_1   continuous focal predictor, skewed, entered as log(x + 1)
#   independent_2   binary focal predictor
#   independent_3   categorical focal predictor (four levels)
#   control_1       continuous control
#   control_2       categorical control (three levels)
#   period          calendar period (integer), a temporal control
# =====================================================================
set.seed(20260911)
n <- 4000
.this_file <- function() {
  a <- commandArgs(); f <- sub("^--file=", "", a[grepl("^--file=", a)]); if (length(f)) return(normalizePath(f[1]))
  for (i in rev(seq_len(sys.nframe()))) { o <- sys.frames()[[i]]$ofile; if (!is.null(o)) return(normalizePath(o)) }
  NA_character_
}
.up_kit <- function(r) { while (!file.exists(file.path(r, "Code", "_bootstrap.R")) && dirname(r) != r) r <- dirname(r); r }
root <- local({ tf <- .this_file(); r <- .up_kit(if (is.na(tf)) getwd() else dirname(tf)); if (!file.exists(file.path(r, "Code", "_bootstrap.R"))) r <- .up_kit(getwd())
  if (!file.exists(file.path(r, "Code", "_bootstrap.R"))) stop("Kit root not found (no Code/_bootstrap.R above this script or the working directory)"); r })
cluster_id   <- sprintf("C%03d", sample(1:120, n, replace = TRUE, prob = rexp(120)))
stratum      <- sample(c("A", "B"), n, replace = TRUE, prob = c(0.3, 0.7))
independent_1 <- round(rlnorm(n, 2, 1))
independent_2 <- rbinom(n, 1, 0.25)
independent_3 <- sample(c("L1", "L2", "L3", "L4"), n, replace = TRUE)
control_1    <- rnorm(n, 50, 10)
control_2    <- sample(c("G1", "G2", "G3"), n, replace = TRUE)
period       <- sample(2010:2024, n, replace = TRUE)
cl_eff       <- rnorm(120, 0, 8)[as.integer(sub("C", "", cluster_id))]
mu1 <- 120 + 12 * log1p(independent_1) + 0 * independent_2 +   # independent_2 has NO effect on dependent_1 by design: the null that TOST certifies
       c(L1 = 0, L2 = 15, L3 = 30, L4 = 5)[independent_3] + 0.4 * (control_1 - 50) +
       c(G1 = 0, G2 = 6, G3 = -4)[control_2] + 1.5 * (period - 2010) + cl_eff
dependent_1  <- round(pmax(5, mu1 + rgamma(n, shape = 2, scale = 15) - 30))
gate <- plogis(-1.2 + 0.6 * log1p(independent_1) + 1.0 * independent_2 + 0.02 * (control_1 - 50))
any  <- rbinom(n, 1, gate)
cnt  <- rnbinom(n, mu = exp(0.3 + 0.35 * log1p(independent_1) + 0.5 * independent_2), size = 1.5)
dependent_2 <- ifelse(any == 1, pmax(1, cnt), 0)
df <- data.frame(record_id = sprintf("R%05d", 1:n), cluster_id, stratum, dependent_1, dependent_2,
                 independent_1, independent_2, independent_3, control_1 = round(control_1, 2), control_2, period,
                 stringsAsFactors = FALSE)
# OPTIONAL TEST MODE: set the environment variable KIT_MISSING_RATE (for example
# Sys.setenv(KIT_MISSING_RATE = "0.05") before sourcing) to blank that share of
# values at random in control_1 and independent_2, so the prep filter, the
# per-model fitted N and the cluster alignment can be exercised with missing
# data. The default is 0 (complete data), which is what the kit documents.
miss_rate <- suppressWarnings(as.numeric(Sys.getenv("KIT_MISSING_RATE", "0")))
if (is.finite(miss_rate) && miss_rate > 0) {
  for (v in c("control_1", "independent_2")) { idx <- sample(n, round(miss_rate * n)); df[[v]][idx] <- NA }
  cat("KIT_MISSING_RATE =", miss_rate, ": missing values introduced in control_1 and independent_2\n")
}
dir.create(file.path(root, "Data"), showWarnings = FALSE)
write.csv(df, file.path(root, "Data", "Study_Data.csv"), row.names = FALSE)
cat("Synthetic data written:", file.path(root, "Data", "Study_Data.csv"), "(", nrow(df), "rows x", ncol(df), "cols )\n")
