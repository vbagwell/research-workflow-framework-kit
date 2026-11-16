# =====================================================================
# Framework Kit: integrated research workflow (template)
# Ported from the originating study's production controls, 2026-11-06
# Revised: 2026-11-16 (baseline copies via repro_baseline_path; a failed copy stops the freeze)
#          2026-10-25
# =====================================================================

# =============================================================================
# 12_freeze_repro_baseline.R - Freeze the accepted results as the baseline
# =============================================================================
# Rewritten 2026-10-25. The former version fingerprinted only the 92 tables and
# 7 figures in 11_Tables_and_Figures, and froze whatever was on disk. On
# 2026-10-12 a diagnostic script failed mid-run, its workbook was left over
# from an earlier run, and the check still passed. This version:
#
#   1. Freezes a RUN, not just a folder. It reads the latest FULL run
#      (00_run_ALL.R) from Results/15_Run_Logs and REFUSES to freeze if
#      that run did not finish, if any script in it ended in ERROR, or if any
#      file in an R output folder was NOT written by that run (a leftover).
#      Set FREEZE_FORCE <- TRUE before sourcing only to override deliberately;
#      the override is written into the manifest banner.
#   2. Covers every output under Analysis/Results (scope and fingerprints are
#      defined once in _repro_common.R), including the hand-built 13_Manual.
#   3. Records, per file, which script wrote it in the frozen run.
#   4. Keeps the frozen run's ledger and code fingerprint, and a COPY of every
#      baseline file in 14_Reproducibility/BASELINE_FILES_<stamp>/, so the
#      verify step can show exactly which cells or lines changed, not just
#      that a hash differs.
#
# RUN THIS on a FULL run whose results you accept as canonical. Re-run only
# when you deliberately accept a new set of results.
#
# Writes (Results/14_Reproducibility):
#   REPRO_MANIFEST.csv                 the baseline verify reads (fixed name;
#                                      banner line keeps the freeze time, which
#                                      12_purge_stale_outputs.R also reads)
#   REPRO_MANIFEST_<stamp>.csv         dated archive copy
#   BASELINE_RUN_LEDGER_<stamp>.csv    ledger of the frozen run
#   BASELINE_CODE_<stamp>.csv          code fingerprint of the frozen run
#   BASELINE_FILES_<stamp>/            copy of every baseline file
# =============================================================================

# --- Run logging (03_Preparation/02_logging.R, added 2026-10-25). Under a
#     runner this does nothing. Sourced on its own, this script is re-run under
#     the logger, so its output, warnings, errors and output files are recorded
#     in Results/15_Run_Logs. -----------------------------------------
local({ .b <- normalizePath(getwd(), winslash = "/", mustWork = FALSE)
  for (.i in seq_len(sys.nframe())) { .of <- sys.frame(.i)$ofile
    if (!is.null(.of)) .b <- dirname(normalizePath(.of, winslash = "/", mustWork = FALSE)) }
  .lg <- function(d) file.path(d, "Code", "03_Preparation", "02_logging.R")
  while (!file.exists(.lg(.b)) && dirname(.b) != .b) .b <- dirname(.b)
  if (!exists("kit_log_standalone", mode = "function", envir = globalenv()))
    sys.source(.lg(.b), envir = globalenv()) })
kit_log_standalone()

local({
  .here <- NA_character_
  for (.i in seq_len(sys.nframe())) { .of <- sys.frame(.i)$ofile
    if (!is.null(.of)) .here <- dirname(normalizePath(.of, winslash = "/", mustWork = FALSE)) }
  if (is.na(.here)) .here <- file.path(getwd(), "Code", "12_Reproducibility")
  sys.source(file.path(.here, "_repro_common.R"), envir = globalenv())
})

force <- exists("FREEZE_FORCE") && isTRUE(FREEZE_FORCE)
run_id <- if (exists("FREEZE_RUN_ID")) FREEZE_RUN_ID else repro_latest_full_run()
run <- repro_read_run(run_id)
problems <- character(0)
if (is.null(run)) {
  problems <- c(problems, paste0("No FULL run found in ", REPRO_LOGDIR,
    ". Run 00_run_ALL.R (which logs the run) before freezing."))
} else {
  if (!run$finished) problems <- c(problems, paste0("Run ", run_id, " has no RUN_SUMMARY.txt: it did not finish."))
  if (!is.null(run$ledger)) {
    bad <- run$ledger[run$ledger$status != "OK", , drop = FALSE]
    if (nrow(bad)) problems <- c(problems, paste0("Run ", run_id, " has ", nrow(bad),
      " script(s) that ended in ERROR: ", paste(bad$script, collapse = ", ")))
  } else problems <- c(problems, paste0("Run ", run_id, " has no RUN_LEDGER.csv."))
}

files <- repro_scope_files()
written <- if (is.null(run)) character(0) else repro_run_written(run)
leftover <- files[!repro_is_manual(files) & !(files %in% written)]
if (length(leftover)) problems <- c(problems, paste0(length(leftover),
  " file(s) in R output folders were NOT written by run ", run_id,
  " (left over from an earlier run, or written outside the pipeline):\n    ",
  paste(leftover, collapse = "\n    "),
  "\n  Re-run the script that should write them, or move them out (12_purge_stale_outputs.R)."))

if (length(problems)) {
  cat("\n*** FREEZE CHECKS FAILED ***\n", paste0("  - ", problems, collapse = "\n"), "\n", sep = "")
  if (!force) stop("Baseline NOT frozen. Fix the problems above, or set FREEZE_FORCE <- TRUE to override deliberately.")
  cat("FREEZE_FORCE is TRUE: freezing anyway; the override is recorded in the manifest.\n")
}

cat("Fingerprinting", length(files), "files ...\n")
man <- do.call(rbind, lapply(files, repro_fingerprint))
man$origin <- ifelse(repro_is_manual(man$file), "MANUAL",
                     ifelse(man$file %in% written, "RUN", "NOT_WRITTEN_BY_RUN"))
man$written_by <- vapply(man$file, function(f) if (is.null(run)) NA_character_ else repro_leaf_writer(run, f), "")

stamp <- format(Sys.time(), "%Y_%m_%d_%H%M")
bdir_name <- paste0("BASELINE_FILES_", stamp)
bdir <- file.path(REPRO_OUTDIR, bdir_name)
for (f in man$file) {
  dest <- repro_baseline_path(bdir, f)
  dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
  ok <- file.copy(file.path(REPRO_RESULTS, f), dest, overwrite = TRUE, copy.date = TRUE)
  if (!isTRUE(ok)) stop("Baseline copy failed for: ", f, " (destination ", nchar(dest), " characters)")
}
if (!is.null(run)) {
  if (!is.null(run$ledger)) utils::write.csv(run$ledger, file.path(REPRO_OUTDIR, paste0("BASELINE_RUN_LEDGER_", stamp, ".csv")), row.names = FALSE)
  if (!is.null(run$code))   utils::write.csv(run$code,   file.path(REPRO_OUTDIR, paste0("BASELINE_CODE_", stamp, ".csv")), row.names = FALSE)
}

n_tab <- sum(man$ext == "xlsx"); n_fig <- sum(man$ext %in% c("png", "svg"))
banner <- c(
  paste0("# Baseline frozen (local): ", format(Sys.time(), "%Y-%m-%d %H:%M %Z"),
         "   (", nrow(man), " files: ", n_tab, " workbooks, ", n_fig, " figures, ",
         sum(man$origin == "MANUAL"), " manual)"),
  paste0("# Format: ", MANIFEST_FORMAT),
  paste0("# Run: ", if (is.null(run)) "NONE" else run_id),
  paste0("# Baseline files: ", bdir_name),
  paste0("# Ledger: ", if (is.null(run)) "NONE" else paste0("BASELINE_RUN_LEDGER_", stamp, ".csv")),
  paste0("# Code: ", if (is.null(run)) "NONE" else paste0("BASELINE_CODE_", stamp, ".csv")),
  paste0("# Forced: ", if (length(problems)) paste("YES -", gsub("[\r\n]+", " ", paste(problems, collapse = " | "))) else "no"))
writeLines(banner, REPRO_MANIFEST)
suppressWarnings(utils::write.table(man, REPRO_MANIFEST, append = TRUE, sep = ",",
                                    row.names = FALSE, col.names = TRUE, qmethod = "double"))
archive <- file.path(REPRO_OUTDIR, paste0("REPRO_MANIFEST_", stamp, ".csv"))
file.copy(REPRO_MANIFEST, archive, overwrite = TRUE)

cat("Froze baseline from run", run_id, ":", nrow(man), "files (",
    n_tab, "workbooks,", n_fig, "figures,", sum(man$origin == "MANUAL"), "manual )\n",
    "  manifest:       ", REPRO_MANIFEST, "\n",
    "  archive copy:   ", archive, "\n",
    "  baseline files: ", bdir, "\n")

# End of 12_freeze_repro_baseline.R
