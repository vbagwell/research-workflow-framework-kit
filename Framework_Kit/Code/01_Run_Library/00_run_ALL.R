# =====================================================================
# Framework Kit: integrated research workflow (template)
# Revised: 2026-11-06 (logged FULL run with ledger, fingerprints and fail-stop; fresh-session guard)
# =====================================================================
# 00_run_ALL.R - master runner for the whole pipeline
# Runs every step in order by calling each step's own runner. Sourcing this
# one file reproduces every result from Data/Study_Data.csv forward.
# THE ORDER (and why it matters):
#   0 Prep + helpers      loaded once, up front, reused by every step
#   1 Variable summary    the codebook and univariate profile
#   2 Diagnostics         structure, estimability, functional form, flags
#   3 Aim 1, Aim 2        the models: WRITE the results workbooks later steps READ
#   4 Log conversions     log-scale effects re-expressed in real terms
#   5 Sensitivity         equivalence, alternative clustering
#   6 Tables and figures  the published set, refreshed LAST so it reflects
#                         everything the earlier steps just wrote
# TURNING A STEP OFF: put a # in front of its line in STEPS.
# WHAT A FULL RUN RECORDS (Results/15_Run_Logs/<run id>/): RUN_INFO.txt (R,
#   platform, data file bytes and md5), CODE_FINGERPRINT.csv (md5 of every code
#   file), one log per script, RUN_LEDGER.csv (status, seconds, warnings, outputs
#   per script), RUN_OUTPUTS.csv (every results file each script wrote), and
#   RUN_SUMMARY.txt with the verdict. LATEST_FULL_RUN.txt points at the last
#   FULL run; the baseline freeze and the verifier use it.
# FAIL-STOP: a script error stops the run and the summary says so. A FULL run
#   that reaches the end is therefore one in which every script finished.
# FRESH SESSION: source this file in a new R session (RStudio: Session > Restart
#   R). A session that already holds a prepared df, or packages attached by an
#   earlier run, can make a later run depend on state the next user will not have.
.this_file <- function() {
  a <- commandArgs(); f <- sub("^--file=", "", a[grepl("^--file=", a)]); if (length(f)) return(normalizePath(f[1]))
  for (i in rev(seq_len(sys.nframe()))) { o <- sys.frames()[[i]]$ofile; if (!is.null(o)) return(normalizePath(o)) }
  NA_character_
}
.find_root_from <- function(start) { r <- start; while (!file.exists(file.path(r, "Code", "_bootstrap.R")) && dirname(r) != r) r <- dirname(r); r }
here <- local({ tf <- .this_file(); if (is.na(tf)) file.path(.find_root_from(getwd()), "Code", "01_Run_Library") else dirname(tf) })
if (exists(".kit_loaded", envir = globalenv()) && isTRUE(get(".kit_loaded", envir = globalenv())) &&
    !isTRUE(getOption("kit.allow_reused_session", FALSE)))
  stop("00_run_ALL.R: this R session already holds a loaded kit workspace. Restart R (RStudio: Session > Restart R) ",
       "and source this file again, so the FULL run starts from a fresh session. ",
       "To override deliberately: options(kit.allow_reused_session = TRUE).")
source(file.path(dirname(here), "03_Preparation", "02_logging.R"))
kit_run_begin("FULL")
source(file.path(here, "run_Prep_and_Helpers.R"))
STEPS <- c(
  "run_Variable_Summary.R",
  "run_Diagnostics.R",
  "run_Aim_01.R",
  "run_Aim_02.R",
  "run_Log_Conversions.R",
  "run_Sensitivity.R",
  "run_Tables_and_Figures.R"
)
T0 <- Sys.time()
for (s in STEPS) {
  cat("\n##### ", s, " #####\n"); t0 <- Sys.time()
  ok <- kit_run_script(file.path(here, s), local = FALSE)
  cat(sprintf("##### %s finished in %.1f s\n", s, as.numeric(difftime(Sys.time(), t0, units = "secs"))))
  if (!isTRUE(ok) && !isTRUE(getOption("kit.continue_on_error", FALSE))) { kit_run_end(); stop("00_run_ALL.R: step ", s, " failed; the FULL run is incomplete (see RUN_SUMMARY.txt).") }
}
res <- kit_run_end()
cat(sprintf("\nPipeline finished in %.1f s. Next: run_Accept_Baseline.R freezes this run as the baseline; a second fresh FULL run followed by run_Reproducibility.R verifies it.\n",
            as.numeric(difftime(Sys.time(), T0, units = "secs"))))
