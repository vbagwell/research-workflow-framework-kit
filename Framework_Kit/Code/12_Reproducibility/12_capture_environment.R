# =====================================================================
# Framework Kit: integrated research workflow (template)
# Revised: 2026-09-11
# =====================================================================
# 12_capture_environment.R - record the computational environment: R
# version and build, platform, BLAS/LAPACK, locale, time zone, and the
# version of every installed package. Date-stamped so successive captures
# are comparable. Add a lockfile with renv::snapshot() when renv is in use.
stamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
ip <- installed.packages()[, c("Package", "Version")]
writeLines(c(R.version.string, paste("Platform:", R.version$platform), paste("BLAS:", extSoftVersion()[["BLAS"]]),
             paste("Locale:", Sys.getlocale("LC_COLLATE")), paste("TZ:", Sys.timezone()), paste("RNG:", paste(RNGkind(), collapse = " / ")),
             paste("Captured:", format(Sys.time(), "%Y-%m-%d %H:%M %Z"))), file.path(OUT_REPRO, paste0("SESSION_INFO_", stamp, ".txt")))
write.csv(as.data.frame(ip), file.path(OUT_REPRO, paste0("PACKAGE_VERSIONS_", stamp, ".csv")), row.names = FALSE)
cat("Environment captured:", R.version.string, "|", nrow(ip), "packages\n")
