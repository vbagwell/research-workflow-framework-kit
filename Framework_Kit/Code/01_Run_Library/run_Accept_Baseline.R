# =====================================================================
# Framework Kit: integrated research workflow (template)
# Revised: 2026-11-06
# =====================================================================
# run_Accept_Baseline.R - FREEZE the reproducibility baseline from the latest
# completed FULL run (Results/15_Run_Logs/LATEST_FULL_RUN.txt).
# The freeze refuses (unless FREEZE_FORCE <- TRUE) when that run did not
# finish, when any script ended in ERROR, or when a results file was not
# written by that run (a leftover from an earlier run or a hand-placed file).
# It records a content fingerprint of EVERY results file (xlsx by cell
# content, text with timestamps masked, figures by bytes and pixel size),
# copies the files, the run ledger and the code fingerprints beside the
# manifest, so a later run can be judged against them.
# PROTOCOL (the analysis-pipeline lock): fresh session -> 00_run_ALL.R ->
# this file -> fresh session -> 00_run_ALL.R -> run_Reproducibility.R.
# --- Run logging (03_Preparation/02_logging.R). Under a runner this does
#     nothing. Sourced on its own, this script is re-run under the logger, so its
#     output, warnings, errors and output files are recorded in Results/15_Run_Logs.
local({ .b <- normalizePath(getwd(), winslash = "/", mustWork = FALSE)
  for (.i in seq_len(sys.nframe())) { .of <- sys.frame(.i)$ofile
    if (!is.null(.of)) .b <- dirname(normalizePath(.of, winslash = "/", mustWork = FALSE)) }
  .lg <- function(d) file.path(d, "Code", "03_Preparation", "02_logging.R")
  while (!file.exists(.lg(.b)) && dirname(.b) != .b) .b <- dirname(.b)
  if (!exists("kit_log_standalone", mode = "function", envir = globalenv()))
    sys.source(.lg(.b), envir = globalenv()) })
kit_log_standalone()
.this_file <- function() {
  a <- commandArgs(); f <- sub("^--file=", "", a[grepl("^--file=", a)]); if (length(f)) return(normalizePath(f[1]))
  for (i in rev(seq_len(sys.nframe()))) { o <- sys.frames()[[i]]$ofile; if (!is.null(o)) return(normalizePath(o)) }
  NA_character_
}
.find_root_from <- function(start) { r <- start; while (!file.exists(file.path(r, "Code", "_bootstrap.R")) && dirname(r) != r) r <- dirname(r); r }
here <- local({ tf <- .this_file(); if (is.na(tf)) file.path(.find_root_from(getwd()), "Code", "01_Run_Library") else dirname(tf) }); repro <- file.path(dirname(here), "12_Reproducibility")
source(file.path(dirname(here), "_bootstrap.R"))
kit_run_script(file.path(repro, "12_capture_environment.R"), local = FALSE)
kit_run_script(file.path(repro, "12_freeze_repro_baseline.R"), local = FALSE)
