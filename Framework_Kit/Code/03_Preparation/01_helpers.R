# =====================================================================
# Framework Kit: integrated research workflow (template)
# File:    01_helpers.R
# Purpose: Shared analysis functions every model file calls. Defines
#          functions only; runs no analysis.
# Revised: 2026-11-13 (fit_and_capture: clusters matched to the fitted rows by row name)
# =====================================================================
# WHAT LIVES HERE
#   vcov_cluster()          cluster-robust (HC1) covariance, base R, with
#                           sandwich::vcovCL used instead when installed
#   extract_clustered_coefs()  coefficient table with cluster-robust SE, CI, p
#   extract_fit_stats()     N, clusters, R2, adjusted R2, AIC, residual shape
#   extract_vif()           variance-inflation factors from the design matrix
#   fit_and_capture()       OLS workhorse: fits, extracts, bundles
#   fit_univariate_table()  one-predictor-at-a-time screen
#   write_model_sheet()     one worksheet (or CSV) per model, per aim workbook
#   write_table()           any data frame to the results tree
# A model script is therefore a formula and a label:
#   source("Code/_bootstrap.R")
#   res <- fit_and_capture(dependent_1 ~ independent_1_LOG1P + <controls>, df_main, "AIM1-2A-M2")
#   write_model_sheet(res, aim = "Aim1", model = "AIM1-2A-M2")
# =====================================================================

# ---- cluster-robust covariance ---------------------------------------
vcov_cluster <- function(fit, cluster) {
  if (requireNamespace("sandwich", quietly = TRUE)) return(sandwich::vcovCL(fit, cluster = cluster, type = "HC1"))
  X <- model.matrix(fit); e <- residuals(fit); n <- nrow(X); k <- ncol(X)
  cluster <- as.factor(cluster); G <- nlevels(cluster)
  bread <- solve(crossprod(X))
  meat <- Reduce(`+`, lapply(split(seq_len(n), cluster), function(i) { s <- crossprod(X[i, , drop = FALSE], e[i]); s %*% t(s) }))
  adj <- (G / (G - 1)) * ((n - 1) / (n - k))     # HC1-type small-sample adjustment
  adj * bread %*% meat %*% bread
}

extract_clustered_coefs <- function(fit, cluster, alpha = 0.05) {
  V <- vcov_cluster(fit, cluster); b <- coef(fit); se <- sqrt(diag(V))
  z <- b / se; p <- 2 * pnorm(-abs(z)); q <- qnorm(1 - alpha / 2)
  data.frame(term = names(b), estimate = unname(b), se = unname(se),
             ci_low = unname(b - q * se), ci_high = unname(b + q * se), p_value = unname(p),
             stringsAsFactors = FALSE)
}

extract_fit_stats <- function(fit, cluster) {
  e <- residuals(fit); s <- summary(fit)
  sk <- mean((e - mean(e))^3) / sd(e)^3; ku <- mean((e - mean(e))^4) / sd(e)^4 - 3
  data.frame(N = length(e), clusters = length(unique(cluster)), r2 = s$r.squared, adj_r2 = s$adj.r.squared,
             AIC = AIC(fit), resid_skew = sk, resid_excess_kurtosis = ku)
}

extract_vif <- function(fit) {
  X <- model.matrix(fit)[, -1, drop = FALSE]
  if (ncol(X) < 2) return(data.frame(term = colnames(X), vif = NA_real_))
  vif <- sapply(seq_len(ncol(X)), function(j) { r2 <- summary(lm(X[, j] ~ X[, -j]))$r.squared; 1 / (1 - r2) })
  data.frame(term = colnames(X), vif = vif)
}

# ---- OLS workhorse -----------------------------------------------------
fit_and_capture <- function(formula, data, model_label, cluster_var = "cluster_id") {
  fit <- lm(formula, data = data)
  # Clusters for the rows lm actually used. model.frame() keeps the row NAMES of
  # `data`, which are not row positions once a frame has been filtered or
  # stratified, so match by name rather than indexing by position.
  cl  <- data[[cluster_var]][match(rownames(model.frame(fit)), rownames(data))]
  if (length(cl) != nobs(fit) || anyNA(cl))
    stop(model_label, ": could not align cluster ids with the fitted rows (", sum(is.na(cl)), " unmatched); check row names and missing ", cluster_var)
  list(label = model_label, formula = deparse1(formula), fit = fit,
       coefs = extract_clustered_coefs(fit, cl), fit_stats = extract_fit_stats(fit, cl), vif = extract_vif(fit))
}

fit_univariate_table <- function(outcome, predictors, data, cluster_var = "cluster_id") {
  do.call(rbind, lapply(predictors, function(p) {
    r <- fit_and_capture(as.formula(paste(outcome, "~", p)), data, paste0("U_", p), cluster_var)
    out <- r$coefs[-1, ]; out$predictor <- p; out$N <- r$fit_stats$N; out
  }))
}

# ---- writers -------------------------------------------------------------
# One workbook per aim, one worksheet per model. If openxlsx is not installed
# the same content is written as one CSV per model in a folder per aim, so
# the kit runs anywhere.
.has_xlsx <- function() requireNamespace("openxlsx", quietly = TRUE)

write_model_sheet <- function(res, aim, model, out_dir = OUT_AIMS) {
  block <- rbind(
    data.frame(section = "model", key = c("label", "formula"), value = c(res$label, res$formula), stringsAsFactors = FALSE),
    data.frame(section = "fit", key = names(res$fit_stats), value = as.character(round(unlist(res$fit_stats), 6)), stringsAsFactors = FALSE))
  coefs <- res$coefs; coefs$section <- "coefficient"
  if (.has_xlsx()) {
    f <- file.path(out_dir, paste0(aim, "_Results.xlsx"))
    wb <- if (file.exists(f)) openxlsx::loadWorkbook(f) else openxlsx::createWorkbook()
    if (model %in% names(wb)) openxlsx::removeWorksheet(wb, model)
    openxlsx::addWorksheet(wb, model)
    openxlsx::writeData(wb, model, block, startRow = 1)
    openxlsx::writeData(wb, model, coefs, startRow = nrow(block) + 3)
    openxlsx::writeData(wb, model, res$vif, startRow = nrow(block) + nrow(coefs) + 6)
    openxlsx::saveWorkbook(wb, f, overwrite = TRUE)
  } else {
    d <- file.path(out_dir, paste0(aim, "_Results")); dir.create(d, showWarnings = FALSE, recursive = TRUE)
    write.csv(block, file.path(d, paste0(model, "_fit.csv")), row.names = FALSE)
    write.csv(coefs, file.path(d, paste0(model, "_coefs.csv")), row.names = FALSE)
    write.csv(res$vif, file.path(d, paste0(model, "_vif.csv")), row.names = FALSE)
  }
  invisible(NULL)
}

write_table <- function(x, name, out_dir) {
  dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
  if (.has_xlsx()) openxlsx::write.xlsx(x, file.path(out_dir, paste0(name, ".xlsx")), overwrite = TRUE)
  else write.csv(x, file.path(out_dir, paste0(name, ".csv")), row.names = FALSE)
  invisible(NULL)
}

# ---- reading a model back (used by conversions, sensitivity, export) ----
read_model_coefs <- function(aim, model, out_dir = OUT_AIMS) {
  if (.has_xlsx()) {
    f <- file.path(out_dir, paste0(aim, "_Results.xlsx"))
    # Keep empty rows: they separate the fit block, the coefficient table and the
    # VIF table on the worksheet. The coefficient rows are also tagged "coefficient"
    # in column 7, which is the authoritative filter.
    sh <- openxlsx::read.xlsx(f, sheet = model, colNames = FALSE, skipEmptyRows = FALSE, skipEmptyCols = FALSE)
    i <- which(!is.na(sh[, 1]) & sh[, 1] == "term")[1]
    j <- which(is.na(sh[, 1]) | sh[, 1] == ""); j <- j[j > i]; end <- if (length(j)) j[1] - 1 else nrow(sh)
    out <- sh[(i + 1):end, 1:7]; names(out) <- c("term", "estimate", "se", "ci_low", "ci_high", "p_value", "section")
    out <- out[!is.na(out$section) & out$section == "coefficient", 1:6]
    for (c in 2:6) out[[c]] <- as.numeric(out[[c]]); rownames(out) <- NULL; out
  } else read.csv(file.path(out_dir, paste0(aim, "_Results"), paste0(model, "_coefs.csv")), stringsAsFactors = FALSE)
}
