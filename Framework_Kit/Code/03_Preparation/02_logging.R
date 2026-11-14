# =====================================================================
# Framework Kit: integrated research workflow (template)
# Ported from the originating study's production controls, 2026-11-06
# Revised: 2026-10-25
# =====================================================================
#
# =============================================================================
# 02_logging.R - Run logging for every analysis script
# =============================================================================
#
# WHY THIS EXISTS:
#   Before 2026-10-25 only four scripts wrote a log file. Everything else
#   printed to the console, and the runners caught any error, printed it, and
#   carried on to "WHOLE PIPELINE COMPLETE". On 2026-10-12 the general data
#   diagnostic stopped at sheet 17, never saved its workbook, and nothing on
#   disk recorded that it had failed; the reproduction check then passed
#   because it only looked at 11_Tables_and_Figures. This file closes that gap.
#
# WHAT IT RECORDS (in Results/15_Run_Logs/<run id>/):
#   logs/NNN__<script>.log  one per script: header (script, code fingerprint,
#                           start time), the script's full console output,
#                           every message and warning, and on failure the error
#                           and a traceback; footer with status, run time,
#                           warning count and every output file it wrote.
#   RUN_LEDGER.csv          one row per script run: status OK / ERROR, timing,
#                           warnings, outputs written, error text, log name.
#   RUN_OUTPUTS.csv         one row per output file written, by which script.
#   RUN_INFO.txt            run id, kind, R version, user, data-file fingerprint.
#   CODE_FINGERPRINT.csv    md5 of every file under Analysis/Code at run start.
#   RUN_SUMMARY.txt         written at the end of a FULL run (00_run_ALL.R):
#                           counts, and the list of every failed script.
#   ../LATEST_FULL_RUN.txt  the id of the most recent FULL run, which is what
#                           12_freeze_repro_baseline.R and
#                           12_verify_reproduction.R read.
#
# HOW SCRIPTS GET LOGGED:
#   1. Through a runner. run_files() (00_prep.R), 00_run_ALL.R, the chart and
#      conversion runners and run_Tables_and_Figures.R all call
#      kit_run_script() instead of source(). Errors are still caught so one bad
#      script does not stop the batch, but every one is recorded.
#   2. On its own. Every executable script calls kit_log_standalone() at the
#      top. Under a runner that call does nothing. When you source a single
#      script yourself (RStudio Source button, or source("...")), it re-runs
#      that script under kit_run_script() so the same log and ledger row are
#      written, then returns you to the prompt. Objects the script creates
#      still land in your workspace, exactly as with a plain source().
#      Under Rscript the session then exits with status 0 (OK) or 1 (ERROR).
#   A run started by 00_run_ALL.R is a FULL run. Anything run outside it
#   collects into one ADHOC run per R session.
#
# CONSOLE: messages are echoed to the console via cat() (stdout) so they can
#   be captured; warnings are logged and still reach R's normal warning
#   summary. Nothing a script prints is suppressed.
#
# This file is self-contained (it finds the project root itself) and safe to
# source repeatedly: run state lives in .kit_log_state in the global
# environment, which survives re-sourcing of 00_prep.R and rm(list = ls()).
# =============================================================================

if (!exists(".kit_log_state", envir = globalenv(), inherits = FALSE)) {
  assign(".kit_log_state", new.env(parent = emptyenv()), envir = globalenv())
  local({
    st <- get(".kit_log_state", envir = globalenv())
    st$run_id <- NULL; st$run_dir <- NULL; st$run_kind <- NULL
    st$run_start <- NULL; st$stack <- character(0); st$seq <- 0L
    st$root <- NULL
  })
}

.kit_st <- function() get(".kit_log_state", envir = globalenv())

# --- Project root (same rule as every other script: the folder holding
#     Data/Study_Data.csv), cached once found. ---------------------------
kit_log_root <- function() {
  st <- .kit_st()
  if (!is.null(st$root) && dir.exists(st$root)) return(st$root)
  starts <- character(0)
  for (i in rev(seq_len(sys.nframe()))) {
    of <- sys.frame(i)$ofile
    if (!is.null(of)) starts <- c(starts, dirname(normalizePath(of, winslash = "/", mustWork = FALSE)))
  }
  starts <- unique(c(starts, normalizePath(getwd(), winslash = "/", mustWork = FALSE)))
  for (s in starts) {
    r <- s
    while (!file.exists(file.path(r, "Data", "Study_Data.csv")) && dirname(r) != r) r <- dirname(r)
    if (file.exists(file.path(r, "Data", "Study_Data.csv"))) { st$root <- r; return(r) }
  }
  stop("[log] could not find the project root (the folder containing Data/Study_Data.csv).")
}
.kit_code_dir    <- function() file.path(kit_log_root(), "Code")
.kit_results_dir <- function() file.path(kit_log_root(), "Results")
kit_log_dir      <- function() file.path(.kit_results_dir(), "15_Run_Logs")

.kit_now <- function(t = Sys.time()) format(t, "%Y-%m-%d %H:%M:%S")
.kit_md5 <- function(p) if (file.exists(p)) unname(tools::md5sum(p)) else NA_character_
.kit_rel <- function(p, base) {
  p <- normalizePath(p, winslash = "/", mustWork = FALSE)
  base <- paste0(normalizePath(base, winslash = "/", mustWork = FALSE), "/")
  if (!length(p)) return(character(0))
  ifelse(startsWith(tolower(p), tolower(base)), substring(p, nchar(base) + 1), p)
}
.kit_append_csv <- function(df, path) {
  suppressWarnings(utils::write.table(df, path, sep = ",", row.names = FALSE,
                                      col.names = !file.exists(path),
                                      append = file.exists(path), qmethod = "double"))
}
.kit_oneline <- function(x) gsub("[\r\n]+", " | ", trimws(paste(x, collapse = " ")))

# --- Every file the analysis has written under Analysis/Results, excluding the
#     logs themselves and the purge quarantine. --------------------------------
.kit_results_files <- function() {
  rd <- .kit_results_dir()
  f <- list.files(rd, recursive = TRUE, full.names = TRUE, all.files = FALSE)
  rel <- .kit_rel(f, rd)
  keep <- !grepl("^15_Run_Logs/", rel) & !grepl("(^|/)_to_delete/", rel) &
          !grepl("(^|/)\\.(RData|Rhistory)$", rel) & !grepl("(^|/)~\\$", rel)
  f[keep]
}

.kit_snapshot <- function() {
  f <- .kit_results_files()
  fi <- file.info(f)
  data.frame(file = f, size = fi$size, mtime = as.numeric(fi$mtime), stringsAsFactors = FALSE)
}

# --- Start a run. kind = "FULL" (00_run_ALL.R) or "ADHOC". --------------------
kit_run_begin <- function(kind = "FULL") {
  st <- .kit_st()
  t0 <- Sys.time()
  id <- paste0(format(t0, "%Y-%m-%d_%H%M%S"), "_", kind)
  dir <- file.path(kit_log_dir(), id)
  dir.create(file.path(dir, "logs"), recursive = TRUE, showWarnings = FALSE)
  st$run_id <- id; st$run_dir <- dir; st$run_kind <- kind; st$run_start <- t0
  st$stack <- character(0); st$seq <- 0L
  root <- kit_log_root()
  dat <- file.path(root, "Data", "Study_Data.csv")
  di <- file.info(dat)
  writeLines(c(
    paste("Run id:            ", id),
    paste("Kind:              ", kind),
    paste("Started (local):   ", format(t0, "%Y-%m-%d %H:%M:%S %Z")),
    paste("Started (UTC):     ", format(t0, tz = "UTC", usetz = TRUE)),
    paste("R:                 ", R.version.string),
    paste("Platform:          ", R.version$platform),
    paste("User:              ", Sys.info()[["user"]]),
    paste("Project root:      ", root),
    paste("Data file:         ", dat),
    paste("Data bytes:        ", di$size),
    paste("Data modified:     ", format(di$mtime, "%Y-%m-%d %H:%M:%S")),
    paste("Data md5:          ", .kit_md5(dat))
  ), file.path(dir, "RUN_INFO.txt"))
  cd <- .kit_code_dir()
  cf <- list.files(cd, recursive = TRUE, full.names = TRUE)
  cf <- cf[!grepl("(^|/)~\\$", cf)]
  fp <- data.frame(file = .kit_rel(cf, cd), bytes = file.info(cf)$size,
                   md5 = unname(tools::md5sum(cf)), stringsAsFactors = FALSE)
  utils::write.csv(fp, file.path(dir, "CODE_FINGERPRINT.csv"), row.names = FALSE)
  cat(sprintf("[log] %s run %s started; logs in %s\n", kind, id, dir))
  invisible(id)
}

.kit_ensure_run <- function() {
  st <- .kit_st()
  if (is.null(st$run_id) || !dir.exists(st$run_dir)) kit_run_begin("ADHOC")
  invisible(st$run_id)
}

# --- Run one script under the logger. Returns TRUE (OK) or FALSE (ERROR),
#     invisibly. Errors are recorded, never re-thrown. ---------------------------
#   local: passed to source(). FALSE = global environment (same as a plain
#          source()); run_files() passes a fresh child of the global env.
kit_run_script <- function(path, local = FALSE, pre = NULL) {
  st <- .kit_st()
  .kit_ensure_run()
  path <- normalizePath(path, winslash = "/", mustWork = FALSE)
  rel <- .kit_rel(path, .kit_code_dir())
  st$seq <- st$seq + 1L
  seq <- st$seq
  parent <- if (length(st$stack)) st$stack[length(st$stack)] else ""
  logname <- sprintf("%03d__%s.log", seq, gsub("[/\\\\ ]+", "__", sub("\\.R$", "", rel)))
  logpath <- file.path(st$run_dir, "logs", logname)
  smd5 <- .kit_md5(path)
  t0 <- Sys.time()
  con <- file(logpath, open = "wt", encoding = "UTF-8")
  writeLines(c(
    paste0("Script:   ", rel),
    paste0("Run id:   ", st$run_id),
    paste0("Called by: ", if (nzchar(parent)) parent else "(top level)"),
    paste0("Script md5: ", smd5),
    paste0("Started:  ", .kit_now(t0)),
    strrep("-", 78)), con)
  flush(con)
  st$stack <- c(st$stack, rel)
  depth <- length(st$stack)
  n_warn <- 0L; err_msg <- NA_character_; tb <- character(0)
  before <- .kit_snapshot()
  sink_depth <- sink.number()
  sink(con, split = TRUE)
  status <- tryCatch({
    if (!file.exists(path)) stop("script file not found: ", path)
    withCallingHandlers({
      if (is.function(pre)) pre()   # optional step logged with this script (see kit_log_standalone)
      source(path, local = local, echo = FALSE) },
      message = function(m) {
        cat(conditionMessage(m))
        invokeRestart("muffleMessage")
      },
      warning = function(w) {
        n_warn <<- n_warn + 1L
        # only the innermost logger prints it; the sinks carry the line up to
        # every enclosing log and the console
        if (length(st$stack) == depth) {
          cl <- conditionCall(w)
          cat(sprintf("[%s] WARNING: %s%s\n", format(Sys.time(), "%H:%M:%S"),
                      .kit_oneline(conditionMessage(w)),
                      if (!is.null(cl)) paste0("  (in ", .kit_oneline(deparse(cl, nlines = 1)), ")") else ""))
        }
      },
      error = function(e) {
        calls <- sys.calls()
        txt <- vapply(calls, function(cl) .kit_oneline(deparse(cl, nlines = 1, width.cutoff = 150)), "")
        tb <<- utils::tail(txt[!grepl("^(withCallingHandlers|tryCatch|tryCatchList|tryCatchOne|doTryCatch|kit_run_script|withVisible|eval|source|\\.handleSimpleError|h|kit_log_standalone)\\(", txt)], 25)
      })
    "OK"
  }, error = function(e) {
    err_msg <<- .kit_oneline(conditionMessage(e))
    "ERROR"
  })
  t1 <- Sys.time()
  secs <- round(as.numeric(difftime(t1, t0, units = "secs")), 1)
  # outputs: files under Analysis/Results that are new, or whose size or
  # modification time changed, between the snapshots before and after
  after <- .kit_snapshot()
  prev <- before[match(after$file, before$file), , drop = FALSE]
  chg <- is.na(prev$file) | prev$size != after$size | prev$mtime != after$mtime
  chg[is.na(chg)] <- TRUE
  new <- after$file[chg]
  out_rel <- .kit_rel(new, .kit_results_dir())
  out_bytes <- after$size[chg]
  if (status == "ERROR") {
    cat(sprintf("\n*** ERROR in %s: %s\n", rel, err_msg))
    if (length(tb)) cat("    Traceback (outermost first):\n",
                        paste0("      ", tb, collapse = "\n"), "\n", sep = "")
  }
  cat(sprintf("  [log] %s: %s (%.1f s, %d warning%s, %d output%s)\n", rel, status, secs,
              n_warn, if (n_warn == 1) "" else "s", length(new), if (length(new) == 1) "" else "s"))
  while (sink.number() > sink_depth) sink()
  writeLines(c(
    strrep("-", 78),
    paste0("Status:   ", status),
    if (status == "ERROR") paste0("Error:    ", err_msg),
    paste0("Ended:    ", .kit_now(t1)),
    paste0("Seconds:  ", secs),
    paste0("Warnings: ", n_warn),
    paste0("Outputs written (", length(new), "):"),
    if (length(new)) paste0("  ", out_rel, "  (", out_bytes, " bytes)")), con)
  close(con)
  st$stack <- st$stack[-length(st$stack)]
  .kit_append_csv(data.frame(
    run_id = st$run_id, seq = seq, depth = depth, parent = parent, script = rel,
    script_md5 = smd5, started = .kit_now(t0), ended = .kit_now(t1), seconds = secs,
    status = status, warnings = n_warn, outputs = length(new),
    error = err_msg, log = logname, stringsAsFactors = FALSE),
    file.path(st$run_dir, "RUN_LEDGER.csv"))
  if (length(new))
    .kit_append_csv(data.frame(
      run_id = st$run_id, seq = seq, depth = depth, script = rel, output = out_rel,
      bytes = out_bytes, modified = .kit_now(file.info(new)$mtime), stringsAsFactors = FALSE),
      file.path(st$run_dir, "RUN_OUTPUTS.csv"))
  invisible(status == "OK")
}

# --- End a run: write RUN_SUMMARY.txt and print it. ----------------------------
kit_run_end <- function() {
  st <- .kit_st()
  if (is.null(st$run_id)) return(invisible(NULL))
  t1 <- Sys.time()
  lp <- file.path(st$run_dir, "RUN_LEDGER.csv")
  led <- if (file.exists(lp)) utils::read.csv(lp, stringsAsFactors = FALSE) else
    data.frame(status = character(), depth = integer(), script = character(),
               error = character(), log = character(), warnings = integer())
  fails <- led[led$status == "ERROR", , drop = FALSE]
  # an error is caught by the kit_run_script() call for the script that raised
  # it, so the runner that called it still reads OK; list in run order
  fails <- fails[order(fails$seq), , drop = FALSE]
  verdict <- if (nrow(fails) == 0)
    "RUN COMPLETE: every script finished without error." else
    sprintf("RUN FINISHED WITH FAILURES: %d script run(s) ended in ERROR. Results from this run are NOT complete.",
            nrow(fails))
  lines <- c(
    paste("Run id:          ", st$run_id),
    paste("Kind:            ", st$run_kind),
    paste("Started (local): ", .kit_now(st$run_start)),
    paste("Ended (local):   ", .kit_now(t1)),
    paste("Minutes:         ", round(as.numeric(difftime(t1, st$run_start, units = "mins")), 1)),
    paste("Script runs:     ", nrow(led)),
    paste("OK:              ", sum(led$status == "OK")),
    paste("ERROR:           ", nrow(fails)),
    paste("Warnings:        ", sum(led$warnings[led$depth == 1], na.rm = TRUE), "(counted at top level, includes nested scripts)"),
    "",
    verdict,
    if (nrow(fails)) c("", "Failed scripts (in run order; each log file holds the error and traceback):",
                       sprintf("  %s\n      error: %s\n      log:   logs/%s", fails$script, fails$error, fails$log)))
  writeLines(lines, file.path(st$run_dir, "RUN_SUMMARY.txt"))
  if (identical(st$run_kind, "FULL"))
    writeLines(st$run_id, file.path(kit_log_dir(), "LATEST_FULL_RUN.txt"))
  cat("\n", paste(rep("=", 78), collapse = ""), "\n", paste(lines, collapse = "\n"), "\n",
      paste(rep("=", 78), collapse = ""), "\n", sep = "")
  st$run_id <- NULL; st$run_dir <- NULL; st$run_kind <- NULL; st$run_start <- NULL
  st$stack <- character(0)
  invisible(list(n_fail = nrow(fails), failed = fails$script))
}

# --- Call at the top of every executable script. ------------------------------
#   Under a runner: does nothing. Sourced on its own: re-runs the script under
#   kit_run_script(), then returns to the prompt (interactive) or exits with
#   status 0/1 (Rscript), so the rest of the outer source() does not run twice.
kit_log_standalone <- function() {
  st <- .kit_st()
  if (length(st$stack) > 0) return(invisible(FALSE))
  path <- NA_character_
  for (i in rev(seq_len(sys.nframe()))) {
    of <- sys.frame(i)$ofile
    if (!is.null(of)) { path <- of; break }
  }
  if (is.na(path)) return(invisible(FALSE))   # pasted into the console, not sourced from a file
  # Before a script sourced on its own runs, make sure the workspace df is the
  # prepared full sample, exactly as the runners do (01_Run_Library/
  # _refresh_df.R). Without this a reused R session could hand the script a
  # subset or raw-CSV df, because each script skips _bootstrap.R once
  # .kit_loaded is TRUE (added 2026-10-25). Scripts in 03_Preparation build
  # that data themselves and are left alone. The check runs inside the
  # script's own log entry, so a rebuild shows in its log.
  pre <- NULL
  .p <- normalizePath(path, winslash = "/", mustWork = FALSE)
  .rf <- file.path(.kit_code_dir(), "01_Run_Library", "_refresh_df.R")
  if (!grepl("/Code/03_Preparation/", .p, fixed = TRUE) && file.exists(.rf))
    pre <- function() source(.rf, local = FALSE, echo = FALSE)
  ok <- kit_run_script(path, local = FALSE, pre = pre)
  if (interactive()) invokeRestart("abort")
  quit(save = "no", status = if (isTRUE(ok)) 0L else 1L)
}

# End of 02_logging.R
