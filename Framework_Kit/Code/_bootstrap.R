# =====================================================================
# Framework Kit: integrated research workflow (template)
# File:    _bootstrap.R
# Purpose: Shared project loader sourced by every analysis script.
#          Locates the project root, builds the prepared data (00_prep.R)
#          and loads the analysis helpers (01_helpers.R).
# Idempotent: sets .kit_loaded, so re-sourcing is a no-op.
# Revised: 2026-11-06 (run logger 02_logging.R loaded before the prepared data)
# =====================================================================
# WHY THIS FILE EXISTS
# Every script needs the same three things before it can do anything:
# the project root, the prepared data frame, and the helper functions.
# Putting that logic here, once, means no script carries its own copy
# and no two scripts can drift apart in how they load the project.
# =====================================================================
.this_file <- function() {
  a <- commandArgs(); f <- sub("^--file=", "", a[grepl("^--file=", a)]); if (length(f)) return(normalizePath(f[1]))
  for (i in rev(seq_len(sys.nframe()))) { o <- sys.frames()[[i]]$ofile; if (!is.null(o)) return(normalizePath(o)) }
  NA_character_
}
.find_root_from <- function(start) { r <- start; while (!file.exists(file.path(r, "Code", "_bootstrap.R")) && dirname(r) != r) r <- dirname(r); r }
if (!exists(".kit_loaded", envir = globalenv()) || !isTRUE(get(".kit_loaded", envir = globalenv()))) {

  # --- 1. Find the project root: walk up from this file (or the working
  #        directory) to the folder that contains Code/_bootstrap.R, then check the frozen input exists.
  .find_root <- function() {
    tf <- .this_file(); start <- if (is.na(tf)) getwd() else dirname(tf)
    r <- .find_root_from(start)
    if (!file.exists(file.path(r, "Code", "_bootstrap.R"))) r <- .find_root_from(getwd())   # fall back to the working directory chain
    if (!file.exists(file.path(r, "Code", "_bootstrap.R")))
      stop("Project root not found: no Code/_bootstrap.R above ", start, " or above the working directory ", getwd())
    if (!file.exists(file.path(r, "Data", "Study_Data.csv")))
      stop("Project root is ", r, " but Data/Study_Data.csv is missing. Run source(\"", file.path(r, "Code", "02_Synthetic_Data", "00_make_synthetic_data.R"),
           "\") first, or place your frozen CSV at ", file.path(r, "Data", "Study_Data.csv"))
    r
  }
  PROJECT_ROOT <- .find_root()
  assign("PROJECT_ROOT", PROJECT_ROOT, envir = globalenv())
  setwd(PROJECT_ROOT)   # the workspace is the project root from here on, as in the originating design
  cat("[bootstrap] project root:", PROJECT_ROOT, "(working directory set)\n")

  # --- 2. Load the run logger (02_logging.R: run ledger, per-script logs, output and
  #        code fingerprints), then the prepared data and folder map (00_prep.R), then the helpers.
  if (!exists("kit_run_script", mode = "function", envir = globalenv()))
    source(file.path(PROJECT_ROOT, "Code", "03_Preparation", "02_logging.R"))
  source(file.path(PROJECT_ROOT, "Code", "03_Preparation", "00_prep.R"))
  source(file.path(PROJECT_ROOT, "Code", "03_Preparation", "01_helpers.R"))

  assign(".kit_loaded", TRUE, envir = globalenv())
}
