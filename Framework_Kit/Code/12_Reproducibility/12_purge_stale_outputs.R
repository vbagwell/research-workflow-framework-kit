# =====================================================================
# Framework Kit: integrated research workflow (template)
# Ported from the originating study's production controls, 2026-11-06
# Revised: 2026-10-25
# =====================================================================

# =============================================================================
# 12_purge_stale_outputs.R - Quarantine superseded files in Analysis/Results
# =============================================================================
# WHY THIS EXISTS:
# The aim, chart and summary scripts write with overwrite = TRUE. That replaces
# a file of the SAME name, but nothing removes a file whose name the pipeline
# has STOPPED producing. When an output is renamed - for example
# FDA_CBER_Aim1_TherapyClass_JointWald.xlsx becoming ..._JointWald_AllStrata.xlsx
# - the run writes the new name and leaves the old file behind, where it is
# indistinguishable at a glance from a current result. Only 05_Diagnostics and
# 11_Tables_and_Figures sweep anything of their own; 06_Aims and 12_Summary do
# not, which is how three stale files survived the 2026-09-04 run.
#
# THE 24-HOUR RULE, AND WHAT ANCHORS IT
# After a full 00_run_ALL.R run, every R-generated file in the scanned folders
# carries an mtime from that run. The script picks an ANCHOR time, subtracts 24
# hours, and treats anything older than that as left over from an earlier run.
# The full run spans roughly two and a half hours, so 24 hours is a wide margin:
# a current file cannot fall outside it, and a file from a prior day cannot fall
# inside it. The window is deliberately fixed rather than tuned.
#
# Two anchors are available - set ANCHOR below:
#
#   "baseline"  Anchor on the frozen baseline recorded in REPRO_MANIFEST.csv
#               (the "# Baseline frozen (local):" line). This is the run your
#               analysis-pipeline lock certifies, so the cutoff does NOT drift when you re-run a
#               single aim. Preferred. Note the freeze is stamped AFTER the run
#               finishes, which is why the same 24-hour back-off is applied -
#               without it every output would sit before the freeze and flag.
#
#   "window"    Anchor on the newest file found in the scanned folders. Use when
#               there is no manifest, or after a run you have not yet frozen.
#               CAUTION: if you re-run one aim in isolation, the newest file is
#               from that aim and the rest of the tree looks stale. Measured on
#               this tree, a single-aim re-run makes "window" flag 173 files
#               where "baseline" still flags only the 3 genuine leftovers.
#
#   "auto"      Use "baseline" when the manifest date parses, else "window".
#   "ask"       Choose at run time (interactive sessions only).
#
# The console report always prints BOTH cutoffs so you can see what the other
# anchor would have done, and the dialog names the one in force.
#
# WHAT IT DOES
# Files that fail the rule are MOVED - never deleted - into
#   Results/14_Reproducibility/_to_delete/Results_stale_<stamp>/
# with their relative path preserved, and recorded in a CSV log beside them.
# Nothing moves until you answer Yes.
#
# The quarantine sits inside the Analysis tree on purpose: the tree gets zipped
# and re-run elsewhere, so the quarantine has to travel with it rather than sit
# at the project root. 14_Reproducibility is used because it is NOT scanned -
# moved files keep their original (old) mtimes, so a quarantine inside any
# scanned folder would be re-flagged on every subsequent run.
#
# WHAT IT WILL NEVER TOUCH
#   * 13_Manual            - authored sources (causal loop diagram, etc.)
#   * 14_Reproducibility   - baseline, renv library, session artifacts
#   * any file named in REPRO_MANIFEST.csv        (hard safety interlock)
#   * any file listed in _authored_keep.txt       (your own allowlist)
#
# HOW TO RUN:
#   Source the file. It scans, prints a report, then raises a Yes/No dialog
#   explaining the 24-hour condition. No moves anything. Yes quarantines.
#   Set REPORT_ONLY <- TRUE to scan and report with no dialog and no moves.
#
# This script fits no model, reads no study data, and loads no project state.
# Running it cannot change a result.
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

REPORT_ONLY  <- FALSE      # TRUE = scan and report only; never prompt, never move
WINDOW_HOURS <- 24         # fixed by design; the dialog explains this condition
ANCHOR       <- "auto"     # "baseline" | "window" | "auto" | "ask"

# --- Locate the project root the same way the rest of the codebase does -------
.find_root <- function() {
  here <- NA_character_
  for (i in seq_len(sys.nframe())) {
    of <- sys.frame(i)$ofile
    if (!is.null(of)) { here <- dirname(normalizePath(of, winslash = "/", mustWork = FALSE)); break }
  }
  starts <- unique(c(if (!is.na(here)) here,
                     normalizePath(getwd(), winslash = "/", mustWork = FALSE)))
  for (st in starts) {
    r <- st
    while (!file.exists(file.path(r, "Data", "Study_Data.csv")) &&
           dirname(r) != r) r <- dirname(r)
    if (file.exists(file.path(r, "Data", "Study_Data.csv"))) return(r)
  }
  stop("Could not locate the project root (Data/Study_Data.csv not found).")
}

# --- Yes/No dialog: RStudio -> Windows -> tcltk -> console --------------------
# Returns TRUE only on an explicit Yes. If no human can be asked (Rscript, a
# scheduled task), returns FALSE so an unattended run can never move files.
.ask_yes_no <- function(title, msg) {
  if (requireNamespace("rstudioapi", quietly = TRUE)) {
    avail <- isTRUE(try(rstudioapi::isAvailable(), silent = TRUE))
    if (avail) {
      ans <- try(rstudioapi::showQuestion(title, msg,
                                          ok = "Yes - move them",
                                          cancel = "No - cancel"), silent = TRUE)
      if (!inherits(ans, "try-error")) return(isTRUE(ans))
    }
  }
  if (.Platform$OS.type == "windows") {
    ans <- try(utils::winDialog(type = "yesno", message = msg), silent = TRUE)
    if (!inherits(ans, "try-error") && length(ans) && !is.null(ans))
      return(identical(toupper(as.character(ans)), "YES"))
  }
  if (isTRUE(capabilities("tcltk")) && requireNamespace("tcltk", quietly = TRUE)) {
    ans <- suppressWarnings(try(tcltk::tkmessageBox(title = title, message = msg,
                                   icon = "warning", type = "yesno"), silent = TRUE))
    if (!inherits(ans, "try-error"))
      return(identical(tolower(as.character(ans)), "yes"))
  }
  if (interactive()) {
    cat("\n", msg, "\n", sep = "")
    return(utils::menu(c("Yes - move them", "No - cancel")) == 1L)
  }
  cat("\n  No interactive prompt is available (non-interactive session).\n",
      "  Refusing to move anything. Run this from RStudio.\n\n", sep = "")
  FALSE
}

ROOT    <- .find_root()
RESULTS <- file.path(ROOT, "Results")
if (!dir.exists(RESULTS)) stop("Results tree not found at: ", RESULTS)

# Quarantine lives INSIDE the Analysis tree so it travels when the tree is
# zipped and handed to someone else to run. 14_Reproducibility is deliberate:
# it is not in SCAN_DIRS, so quarantined files - which keep their old mtimes -
# are never re-scanned and re-flagged on the next run.
QUARANTINE <- file.path(RESULTS, "14_Reproducibility", "_to_delete")

# Folders that hold R-generated output and are therefore in scope.
SCAN_DIRS <- c("04_Variable_Summary", "05_Diagnostics", "06_Aims",
               "07_Log_Conversions", "08_Sensitivity_Analysis",
               "09_Supplementary_Analysis", "10_Charts",
               "11_Tables_and_Figures", "12_Summary")

# --- Safety interlock 1: never move a file tracked in the repro manifest ------
manifest_names <- character(0)
baseline_time  <- as.POSIXct(NA)
mf <- file.path(RESULTS, "14_Reproducibility", "REPRO_MANIFEST.csv")
if (file.exists(mf)) {
  mtxt <- readLines(mf, warn = FALSE)
  # "# Baseline frozen (local): 2026-09-04 08:22 EDT   (89 tables, 7 figures)"
  bl <- grep("Baseline frozen", mtxt, value = TRUE)
  if (length(bl)) {
    m <- regmatches(bl[1], regexpr("[0-9]{4}-[0-9]{2}-[0-9]{2}[ T][0-9]{2}:[0-9]{2}", bl[1]))
    if (length(m)) baseline_time <- as.POSIXct(sub("T", " ", m), format = "%Y-%m-%d %H:%M")
  }
  mtxt <- mtxt[!grepl("^#", mtxt)]                      # drop the baseline banner
  con  <- textConnection(mtxt)
  md   <- try(utils::read.csv(con, stringsAsFactors = FALSE), silent = TRUE)
  try(close(con), silent = TRUE)
  if (!inherits(md, "try-error") && "file" %in% names(md))
    manifest_names <- basename(as.character(md$file))
}

# --- Safety interlock 2: your own allowlist of authored, non-R sources --------
# Every authored, non-R source lives in 13_Manual, which is excluded from the scan
# wholesale, so no built-in exceptions are needed. If an authored file ever has to
# live in a scanned folder, add its Results-relative path to _authored_keep.txt
# rather than editing this script.
KEEP_DEFAULT <- character(0)
keep_file <- file.path(RESULTS, "_authored_keep.txt")
keep_rel  <- KEEP_DEFAULT
if (file.exists(keep_file)) {
  k <- trimws(readLines(keep_file, warn = FALSE))
  k <- k[nzchar(k) & !grepl("^#", k)]
  keep_rel <- unique(c(keep_rel, k))
}

# --- Scan ---------------------------------------------------------------------
dirs  <- file.path(RESULTS, SCAN_DIRS)
dirs  <- dirs[dir.exists(dirs)]
files <- list.files(dirs, recursive = TRUE, full.names = TRUE, all.files = TRUE, no.. = TRUE)
files <- files[!dir.exists(files)]
if (!length(files)) stop("No files found under: ", paste(SCAN_DIRS, collapse = ", "))

info <- file.info(files)
rel  <- sub(paste0("^", gsub("([.|()\\^{}+$*?\\[\\]])", "\\\\\\1", RESULTS), "/"), "", files)

newest          <- max(info$mtime, na.rm = TRUE)
cutoff_window   <- newest - WINDOW_HOURS * 3600
cutoff_baseline <- if (!is.na(baseline_time)) baseline_time - WINDOW_HOURS * 3600 else as.POSIXct(NA)

anchor <- ANCHOR
if (identical(anchor, "ask")) {
  if (interactive()) {
    cat("\n  Choose the staleness condition:\n")
    ch <- utils::menu(c(
      paste0("Baseline anchor  - frozen ",
             if (is.na(baseline_time)) "(unavailable)" else format(baseline_time, "%Y-%m-%d %H:%M"),
             "  -> cutoff ",
             if (is.na(cutoff_baseline)) "n/a" else format(cutoff_baseline, "%Y-%m-%d %H:%M")),
      paste0("Newest-file window - newest ", format(newest, "%Y-%m-%d %H:%M"),
             "  -> cutoff ", format(cutoff_window, "%Y-%m-%d %H:%M"))))
    anchor <- if (ch == 1L) "baseline" else if (ch == 2L) "window" else "none"
    if (identical(anchor, "none")) stop("Cancelled at the anchor prompt.")
  } else anchor <- "auto"
}
if (identical(anchor, "auto")) anchor <- if (!is.na(cutoff_baseline)) "baseline" else "window"
if (identical(anchor, "baseline") && is.na(cutoff_baseline)) {
  cat("\n  NOTE: no baseline date found in REPRO_MANIFEST.csv - falling back to the newest-file window.\n")
  anchor <- "window"
}
cutoff <- if (identical(anchor, "baseline")) cutoff_baseline else cutoff_window
anchor_label <- if (identical(anchor, "baseline"))
  paste0("frozen baseline ", format(baseline_time, "%Y-%m-%d %H:%M")) else
  paste0("newest output ",   format(newest,        "%Y-%m-%d %H:%M"))

is_stale  <- info$mtime < cutoff
is_kept   <- rel %in% keep_rel
is_locked <- basename(files) %in% manifest_names
flag      <- is_stale & !is_kept & !is_locked

cat("\n=============================================================\n")
cat("  Stale-output scan of Results\n")
cat("=============================================================\n")
cat("  scanned folders : ", length(dirs), "\n", sep = "")
cat("  files scanned   : ", length(files), "\n", sep = "")
cat("  anchor in force : ", anchor, "  (", anchor_label, ")\n", sep = "")
cat("  newest output   : ", format(newest, "%Y-%m-%d %H:%M"),
    "   -> window cutoff   ", format(cutoff_window, "%Y-%m-%d %H:%M"), "\n", sep = "")
cat("  frozen baseline : ",
    if (is.na(baseline_time)) "(none found)          " else format(baseline_time, "%Y-%m-%d %H:%M"),
    "   -> baseline cutoff ",
    if (is.na(cutoff_baseline)) "(n/a)" else format(cutoff_baseline, "%Y-%m-%d %H:%M"), "\n", sep = "")
cat("  STALE CUTOFF    : ", format(cutoff, "%Y-%m-%d %H:%M"),
    "  (", anchor_label, " - ", WINDOW_HOURS, "h)\n", sep = "")
cat("  manifest-locked : ", sum(is_locked), "\n", sep = "")
cat("  allowlisted     : ", sum(is_kept & is_stale), "\n", sep = "")
cat("  TO QUARANTINE   : ", sum(flag), "\n\n", sep = "")

if (sum(is_kept & is_stale)) {
  cat("  Kept (authored, older by design):\n")
  for (p in rel[is_kept & is_stale]) cat("     - ", p, "\n", sep = "")
  cat("\n")
}

if (!sum(flag)) {
  cat("  Nothing to quarantine. Results tree is clean.\n\n")
} else {
  cat("  Candidates:\n")
  for (i in which(flag))
    cat("     ", format(info$mtime[i], "%Y-%m-%d"), "  ",
        formatC(info$size[i], big.mark = ",", format = "d", width = 10), "  ",
        rel[i], "\n", sep = "")
  cat("\n")

  if (REPORT_ONLY) {
    cat("  REPORT_ONLY is TRUE - nothing was moved and no prompt was shown.\n\n")
  } else {
    stamp <- format(Sys.time(), "%Y-%m-%d_%H%M%S")
    dest  <- file.path(QUARANTINE, paste0("Results_stale_", stamp))

    shown <- rel[flag]
    if (length(shown) > 8) shown <- c(shown[1:8], paste0("... and ", length(rel[flag]) - 8, " more"))

    msg <- paste0(
      "STALE-OUTPUT CLEANUP\n\n",
      "The ", WINDOW_HOURS, "-hour condition (anchor: ", anchor, "):\n",
      "Anchored on the ", anchor_label, ".\n",
      "Anything written more than ", WINDOW_HOURS, " hours before that - i.e. before\n",
      format(cutoff, "%Y-%m-%d %H:%M"), " - is treated as left over from an EARLIER run\n",
      "and is not part of the current results.\n\n",
      if (identical(anchor, "window"))
        "CAUTION: this anchor follows the newest file. If you re-ran only one\naim, the rest of the tree will look stale - check the list.\n\n"
      else
        "This anchor is the run your analysis-pipeline lock certifies, so it does\nnot drift if you re-run a single aim.\n\n",
      "Protected and never moved: 13_Manual, 14_Reproducibility, the ",
      length(manifest_names), " files\n",
      "in REPRO_MANIFEST.csv, and anything in _authored_keep.txt.\n\n",
      sum(flag), " file(s) would be MOVED (not deleted) to:\n",
      "Results/14_Reproducibility/_to_delete/\n",
      "   Results_stale_", stamp, "/\n\n",
      paste0("  - ", shown, collapse = "\n"), "\n\n",
      "Move them now?"
    )

    if (!.ask_yes_no("Stale-output cleanup - confirm", msg)) {
      cat("  Cancelled. Nothing was moved.\n\n")
    } else {
      moved <- character(0); failed <- character(0)
      for (i in which(flag)) {
        target <- file.path(dest, rel[i])
        dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
        ok <- file.rename(files[i], target)
        if (!ok) {                                   # cross-device fallback
          ok <- file.copy(files[i], target, overwrite = FALSE, copy.date = TRUE)
          if (ok) ok <- file.remove(files[i])
        }
        if (ok) moved <- c(moved, rel[i]) else failed <- c(failed, rel[i])
      }
      if (length(moved)) {
        log <- data.frame(moved_utc = format(Sys.time(), tz = "UTC"),
                          relative_path = moved, stringsAsFactors = FALSE)
        utils::write.csv(log, file.path(dest, "_purge_log.csv"), row.names = FALSE)
      }
      cat("  Moved ", length(moved), " file(s) to:\n     ", dest, "\n", sep = "")
      if (length(failed)) {
        cat("  FAILED to move ", length(failed), " file(s):\n", sep = "")
        for (p in failed) cat("     - ", p, "\n", sep = "")
      }
      cat("  Nothing was deleted. Review the folder, then remove it yourself.\n\n")
    }
  }
}

# End of 12_purge_stale_outputs.R
