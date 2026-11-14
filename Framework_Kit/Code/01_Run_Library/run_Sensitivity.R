# =====================================================================
# Framework Kit: integrated research workflow (template)
# Revised: 2026-09-11
# =====================================================================
# run_Sensitivity.R - thin runner: sources every script in Code/08_Sensitivity_Analysis in
# name order, each in its own environment. Knows only its own folder, so the
# entry point cannot fall out of step with the scripts.
.this_file <- function() {
  a <- commandArgs(); f <- sub("^--file=", "", a[grepl("^--file=", a)]); if (length(f)) return(normalizePath(f[1]))
  for (i in rev(seq_len(sys.nframe()))) { o <- sys.frames()[[i]]$ofile; if (!is.null(o)) return(normalizePath(o)) }
  NA_character_
}
.find_root_from <- function(start) { r <- start; while (!file.exists(file.path(r, "Code", "_bootstrap.R")) && dirname(r) != r) r <- dirname(r); r }
.here <- local({ tf <- .this_file(); if (is.na(tf)) .find_root_from(getwd()) else dirname(tf) })
if (!file.exists(file.path(.here, "_refresh_df.R"))) .here <- file.path(.find_root_from(getwd()), "Code", "01_Run_Library")
source(file.path(.here, "_refresh_df.R"))
run_files(DIR_SENS, label = "08_Sensitivity_Analysis")
