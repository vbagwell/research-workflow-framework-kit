# =====================================================================
# Framework Kit: integrated research workflow (template)
# File:    00_prep.R
# Purpose: Data preparation. Runs ONCE per session and leaves the prepared
#          analytical data frame in memory as `df`, plus the folder map
#          and the run_files() function every runner uses.
# Revised: 2026-11-06 (run_files() fails the run on a script error and logs every script;
#          prepared-column fingerprint for _refresh_df.R)
# =====================================================================
# WHY A SEPARATE PREP FILE INSTEAD OF DOING THIS INSIDE EACH MODEL FILE
#   (1) Reproducibility: every model uses identical inputs.
#   (2) Speed: reading the CSV and building factors happens once, not once
#       per model file.
#   (3) Auditability: anyone verifying how the data were processed reads
#       ONE file.
# WHAT THIS FILE DOES
#   Section 0  folder map (DIR_* code folders, OUT_* results folders)
#   Section 1  read the frozen CSV (Data/Study_Data.csv)
#   Section 2  factors with declared reference categories
#   Section 3  derived variables (log(x + 1) forms)
#   Section 4  analytic frames as named objects
#   Section 5  drift check against the locked rules; warn loudly
#   Section 6  summary for inspection
# =====================================================================
# Self-locate when sourced directly (the bootstrap normally sets PROJECT_ROOT):
# walk up from this file, then from the working directory, to the folder that
# holds Data/Study_Data.csv. Fail with a plain message if it is not there.
if (!exists("PROJECT_ROOT")) {
  .tf <- tryCatch({ a <- commandArgs(); f <- sub("^--file=", "", a[grepl("^--file=", a)]); if (length(f)) normalizePath(f[1]) else {
    o <- NULL; for (i in rev(seq_len(sys.nframe()))) { o <- sys.frames()[[i]]$ofile; if (!is.null(o)) break }; if (is.null(o)) NA_character_ else normalizePath(o) } }, error = function(e) NA_character_)
  .up <- function(r) { while (!file.exists(file.path(r, "Code", "_bootstrap.R")) && dirname(r) != r) r <- dirname(r); r }
  PROJECT_ROOT <- if (!is.na(.tf)) .up(dirname(.tf)) else getwd()
  if (!file.exists(file.path(PROJECT_ROOT, "Code", "_bootstrap.R"))) PROJECT_ROOT <- .up(getwd())
  if (!file.exists(file.path(PROJECT_ROOT, "Code", "_bootstrap.R")))
    stop("Project root not found: no Code/_bootstrap.R above ", if (is.na(.tf)) getwd() else dirname(.tf))
  if (!file.exists(file.path(PROJECT_ROOT, "Data", "Study_Data.csv")))
    stop("Project root is ", PROJECT_ROOT, " but Data/Study_Data.csv is missing. Generate the synthetic input first: source(\"",
         file.path(PROJECT_ROOT, "Code", "02_Synthetic_Data", "00_make_synthetic_data.R"), "\"), or place your frozen CSV at ", file.path(PROJECT_ROOT, "Data", "Study_Data.csv"))
  setwd(PROJECT_ROOT); cat("[00_prep] project root:", PROJECT_ROOT, "(working directory set)\n")
}
# ---- Section 0: folder map -------------------------------------------
CODE <- file.path(PROJECT_ROOT, "Code"); RES <- file.path(PROJECT_ROOT, "Results")
DIR_VARSUM <- file.path(CODE, "04_Variable_Summary");  OUT_VARSUM <- file.path(RES, "04_Variable_Summary")
DIR_DIAG   <- file.path(CODE, "05_Diagnostics");       OUT_DIAG   <- file.path(RES, "05_Diagnostics")
DIR_AIMS   <- file.path(CODE, "06_Aims");              OUT_AIMS   <- file.path(RES, "06_Aims")
DIR_CONV   <- file.path(CODE, "07_Log_Conversions");   OUT_CONV   <- file.path(RES, "07_Log_Conversions")
DIR_SENS   <- file.path(CODE, "08_Sensitivity_Analysis"); OUT_SENS <- file.path(RES, "08_Sensitivity_Analysis")
DIR_TABFIG <- file.path(CODE, "11_Tables_and_Figures"); OUT_TABFIG <- file.path(RES, "11_Tables_and_Figures")
DIR_REPRO  <- file.path(CODE, "12_Reproducibility");   OUT_REPRO  <- file.path(RES, "14_Reproducibility")
for (d in c(OUT_VARSUM, OUT_DIAG, OUT_AIMS, OUT_CONV, OUT_SENS, OUT_TABFIG, OUT_REPRO)) dir.create(d, recursive = TRUE, showWarnings = FALSE)
DATA_PATH <- file.path(PROJECT_ROOT, "Data", "Study_Data.csv")

# run_files(): source every .R file in a folder, in name order, each in its
# own fresh environment (parent = global) so scripts share df but not temporaries.
# Each script runs under the run logger (kit_run_script(): its own log file,
# warnings, error and traceback, outputs written, script md5, ledger row).
# FAIL-STOP: a script error stops the run (so a FULL run that reaches the end
# is one in which every script finished). Set options(kit.continue_on_error = TRUE)
# to keep going and collect every failure in the ledger instead.
run_files <- function(dir, label = basename(dir), pattern = "\\.R$") {
  files <- sort(list.files(dir, pattern = pattern, full.names = TRUE))
  cat("\n=== Running", length(files), "file(s) in", label, "===\n")
  failed <- character(0)
  for (f in files) {
    ok <- kit_run_script(f, local = new.env(parent = globalenv()))
    if (!isTRUE(ok)) {
      failed <- c(failed, basename(f))
      if (!isTRUE(getOption("kit.continue_on_error", FALSE)))
        stop("run_files(", label, "): ", basename(f), " ended in ERROR; the run is stopped. ",
             "See the script log in Results/15_Run_Logs/<run id>/logs/.")
    }
  }
  if (length(failed)) warning("run_files(", label, "): ", length(failed), " script(s) failed: ", paste(failed, collapse = ", "))
  invisible(length(failed) == 0)
}

# ---- Section 1: read the frozen input ---------------------------------
df <- read.csv(DATA_PATH, stringsAsFactors = FALSE)

# ---- Section 2: factors with declared reference categories -----------
# The reference level is the comparison baseline in every coefficient table.
# Declare them here, once, and record them in 06_Global_Rules of the plan.
df$stratum       <- factor(df$stratum, levels = c("A", "B"))
df$independent_3 <- factor(df$independent_3, levels = c("L1", "L2", "L3", "L4"))   # L1 = reference
df$control_2     <- factor(df$control_2, levels = c("G1", "G2", "G3"))             # G1 = reference
df$independent_2 <- as.integer(df$independent_2)

# ---- Section 3: derived variables -------------------------------------
df$independent_1_LOG1P <- log1p(df$independent_1)   # per-unit change = e-fold change in (x + 1)
df$period_c <- df$period - min(df$period)           # centred temporal control

# ---- Section 4: analytic frames ---------------------------------------
# DELIBERATE CHOICE: one complete-case analytic frame per aim, shared by every
# model of that aim, so that the models are compared on the same records and
# the fitted N is the same across the model ladder. This drops a record that is
# missing ANY listed outcome or predictor, including the other aim's outcome.
# If model-specific samples are wanted instead (each model keeping every record
# complete for ITS OWN variables), build df_main without this filter and let
# lm()'s na.action drop rows per model; fit_and_capture() aligns cluster ids to
# the rows actually fitted, and the fitted N is then reported per model.
df_main   <- df[complete.cases(df[, c("dependent_1", "dependent_2", "independent_1_LOG1P", "independent_2",
                                       "independent_3", "control_1", "control_2", "period_c")]), ]
df_strat_A <- df_main[df_main$stratum == "A", ]
df_strat_B <- df_main[df_main$stratum == "B", ]

# ---- Section 5: drift check against the locked rules -----------------
# Locked rules (record the same numbers in 06_Global_Rules of the plan):
LOCKED_N_MIN <- 1000
if (nrow(df_main) < LOCKED_N_MIN) warning("DRIFT: df_main has ", nrow(df_main), " rows, below the locked minimum of ", LOCKED_N_MIN)
if (!all(levels(df$independent_3) == c("L1", "L2", "L3", "L4"))) warning("DRIFT: independent_3 levels differ from the locked set")
.kit_df_n  <- nrow(df)   # row-count fingerprint used by _refresh_df.R to detect a stale or subset df
# Prepared-column fingerprint: names and classes of every prepared column, in
# order. _refresh_df.R rebuilds df if a script added, dropped or re-typed a
# column, which a row count alone cannot see.
.kit_df_fp <- paste(paste0(names(df), ":", vapply(df, function(x) paste(class(x), collapse = "/"), "")), collapse = "|")

# ---- Section 6: summary -----------------------------------------------
cat(sprintf("Prepared: df %d x %d | df_main %d | stratum A %d | stratum B %d | clusters %d\n",
            nrow(df), ncol(df), nrow(df_main), nrow(df_strat_A), nrow(df_strat_B), length(unique(df$cluster_id))))
