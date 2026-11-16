# =====================================================================
# Framework Kit: integrated research workflow (template)
# Ported from the originating study's production controls, 2026-11-06
# Revised: 2026-11-16 (baseline copies read via repro_baseline_path)
#          2026-10-25
# =====================================================================

# =============================================================================
# 12_verify_reproduction.R - Check a run against the frozen baseline
# =============================================================================
# Rewritten 2026-10-25. The former version compared only the 92 tables in
# 11_Tables_and_Figures (figures by size), so a script that failed mid-run and
# left an old workbook behind still produced "REPRODUCES". This version checks
# the RUN as well as its outputs:
#
#   A. SCRIPTS  (from the run ledger in Results/15_Run_Logs)
#      ERROR      a script ended in error                              -> FAIL
#      NOT RUN    a script in the baseline run is absent from this run -> FAIL
#      UNFINISHED the run has no RUN_SUMMARY.txt (stopped part-way)    -> FAIL
#      CODE CHANGED  the script's md5 differs from the baseline run    -> listed
#   B. OUTPUTS  (every file in scope; see _repro_common.R)
#      MATCH      content identical to the baseline
#      DIFFERS    content changed; the report shows which sheets and
#                 the first changed cells (or lines), old -> new       -> FAIL
#      STALE      baseline says this run writes it, but this run did
#                 not (the 2026-10-12 case)                            -> FAIL
#      MISSING    in the baseline, not on disk                         -> FAIL
#      LEFTOVER   on disk, not in the baseline, not written by this
#                 run, outside 13_Manual                               -> FAIL
#      NEW        written by this run, not in the baseline             -> REVIEW
#      13_Manual  hand-built: MATCH or CHANGED (information, not a reproduction
#                 failure), MISSING still fails
#
# VERDICT: REPRODUCES only when there is no FAIL. NEW items are listed for
# review (a deliberate new output means the baseline needs re-freezing).
#
# WHICH RUN: the latest FULL run (00_run_ALL.R) by default; set
# VERIFY_RUN_ID <- "<run id>" before sourcing to check another.
# Run 00_run_ALL.R first: a check without a fresh run would only compare the
# baseline with itself plus whatever is on disk, and now reports that plainly.
#
# Writes (Results/14_Reproducibility):
#   VERIFY_REPORT_<stamp>.txt   summary, every non-MATCH item, and details
#   VERIFY_DETAIL_<stamp>.csv   one row per script and per file
# Under Rscript, exits with status 1 when the verdict is not REPRODUCES.
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

if (exists("VERIFY_MODE") && !identical(VERIFY_MODE, "integrity"))
  cat("NOTE: VERIFY_MODE '", VERIFY_MODE, "' is retired. To recompute, run 00_run_ALL.R, then this check.\n", sep = "")
if (!file.exists(REPRO_MANIFEST)) stop("No REPRO_MANIFEST.csv found. Run 12_freeze_repro_baseline.R first.")
mtxt <- readLines(REPRO_MANIFEST, warn = FALSE)
banner <- mtxt[grepl("^#", mtxt)]
if (!any(grepl(MANIFEST_FORMAT, banner, fixed = TRUE)))
  stop("REPRO_MANIFEST.csv is in the pre-2026-10-25 format (tables in 11_Tables_and_Figures only). ",
       "Run 00_run_ALL.R, then 12_freeze_repro_baseline.R, to create a full baseline.")
bval <- function(key) { b <- grep(paste0("^# ", key, ": "), banner, value = TRUE); if (length(b)) sub(paste0("^# ", key, ": "), "", b[1]) else NA_character_ }
man <- utils::read.csv(REPRO_MANIFEST, comment.char = "#", stringsAsFactors = FALSE,
                       colClasses = "character")
bdir <- file.path(REPRO_OUTDIR, bval("Baseline files"))
base_ledger <- { p <- file.path(REPRO_OUTDIR, bval("Ledger")); if (file.exists(p)) utils::read.csv(p, stringsAsFactors = FALSE) else NULL }
base_code   <- { p <- file.path(REPRO_OUTDIR, bval("Code"));   if (file.exists(p)) utils::read.csv(p, stringsAsFactors = FALSE) else NULL }

run_id <- if (exists("VERIFY_RUN_ID")) VERIFY_RUN_ID else repro_latest_full_run()
run <- repro_read_run(run_id)
written <- if (is.null(run)) character(0) else repro_run_written(run)

rows <- list()
add <- function(kind, item, status, fail, detail = "") rows[[length(rows) + 1]] <<-
  data.frame(kind = kind, item = item, status = status, fail = fail, detail = detail, stringsAsFactors = FALSE)

# ---- A. Scripts ------------------------------------------------------------------
if (is.null(run)) {
  add("run", if (is.na(run_id)) "(none)" else run_id, "NO RUN LOG", TRUE,
      "No FULL run log found; outputs below cannot be tied to a run. Run 00_run_ALL.R, then verify.")
} else {
  if (!run$finished) add("run", run_id, "UNFINISHED", TRUE, "No RUN_SUMMARY.txt: the run stopped before 00_run_ALL.R finished.")
  led <- run$ledger
  if (is.null(led)) { add("run", run_id, "NO LEDGER", TRUE, "RUN_LEDGER.csv missing."); led <- data.frame(script = character(), status = character(), error = character(), log = character(), script_md5 = character()) }
  for (i in seq_len(nrow(led))) if (led$status[i] != "OK")
    add("script", led$script[i], "ERROR", TRUE, paste0(led$error[i], "  [log: 15_Run_Logs/", run_id, "/logs/", led$log[i], "]"))
  if (!is.null(base_ledger)) {
    for (s in setdiff(unique(base_ledger$script), unique(led$script)))
      add("script", s, "NOT RUN", TRUE, "In the baseline run, absent from this run.")
    for (s in setdiff(unique(led$script), unique(base_ledger$script)))
      add("script", s, "NEW SCRIPT", FALSE, "Ran in this run, not in the baseline run.")
  }
  if (!is.null(base_code) && !is.null(run$code)) {
    cm <- merge(base_code[, c("file", "md5")], run$code[, c("file", "md5")], by = "file", all = TRUE, suffixes = c(".base", ".run"))
    ch <- cm[is.na(cm$md5.base) | is.na(cm$md5.run) | cm$md5.base != cm$md5.run, , drop = FALSE]
    for (i in seq_len(nrow(ch))) add("code", ch$file[i],
      if (is.na(ch$md5.base[i])) "CODE ADDED" else if (is.na(ch$md5.run[i])) "CODE REMOVED" else "CODE CHANGED", FALSE,
      "Code differs from the baseline run; differences in its outputs may be intended.")
  }
}

# ---- B. Outputs --------------------------------------------------------------------
col_letter <- function(n) { s <- ""; while (n > 0) { r <- (n - 1) %% 26; s <- paste0(LETTERS[r + 1], s); n <- (n - 1) %/% 26 }; s }
xlsx_diff <- function(rel) {
  old <- if (dir.exists(bdir)) repro_read_xlsx(repro_baseline_path(bdir, rel)) else NULL
  new <- repro_read_xlsx(file.path(REPRO_RESULTS, rel))
  if (is.null(old) || is.null(new)) return("(baseline copy not available for a cell-level comparison)")
  msg <- character(0)
  for (s in union(names(old), names(new))) {
    a <- old[[s]]; b <- new[[s]]
    if (is.null(a)) { msg <- c(msg, paste0("sheet '", s, "' added")); next }
    if (is.null(b)) { msg <- c(msg, paste0("sheet '", s, "' removed")); next }
    if (identical(a, b)) next
    nr <- max(nrow(a), nrow(b)); nc <- max(ncol(a), ncol(b))
    pad <- function(m) { o <- matrix("", nr, nc); if (length(m)) o[seq_len(nrow(m)), seq_len(ncol(m))] <- m; o }
    A <- pad(a); B <- pad(b); d <- which(A != B, arr.ind = TRUE)
    d <- d[order(d[, 1], d[, 2]), , drop = FALSE]
    shown <- utils::head(seq_len(nrow(d)), 5)
    cells <- vapply(shown, function(k) sprintf("%s%d: '%s' -> '%s'", col_letter(d[k, 2]), d[k, 1],
                    substr(A[d[k, 1], d[k, 2]], 1, 60), substr(B[d[k, 1], d[k, 2]], 1, 60)), "")
    msg <- c(msg, paste0("sheet '", s, "': ", nrow(d), " cell(s) differ",
                         if (!identical(dim(a), dim(b))) sprintf(" (size %dx%d -> %dx%d)", nrow(a), ncol(a), nrow(b), ncol(b)) else "",
                         "; ", paste(cells, collapse = "; ")))
  }
  paste(msg, collapse = " || ")
}
text_diff <- function(rel) {
  if (!dir.exists(bdir)) return("")
  a <- repro_text_lines(repro_baseline_path(bdir, rel)); b <- repro_text_lines(file.path(REPRO_RESULTS, rel))
  n <- max(length(a), length(b)); a <- c(a, rep("<none>", n - length(a))); b <- c(b, rep("<none>", n - length(b)))
  d <- which(a != b)
  paste0(length(d), " line(s) differ; first at line ", d[1], ": '", substr(a[d[1]], 1, 80), "' -> '", substr(b[d[1]], 1, 80), "'")
}

current <- repro_scope_files()
cat("Fingerprinting", length(current), "files ...\n")
cur <- do.call(rbind, lapply(current, repro_fingerprint))
cur_fp <- setNames(cur$fingerprint, cur$file)

for (i in seq_len(nrow(man))) {
  f <- man$file[i]; manual <- man$origin[i] == "MANUAL"
  if (!(f %in% current)) { add(if (manual) "manual" else "output", f, "MISSING", TRUE, "In the baseline, not on disk."); next }
  same <- identical(unname(cur_fp[f]), man$fingerprint[i])
  if (manual) { add("manual", f, if (same) "MATCH" else "CHANGED", FALSE, if (same) "" else "Hand-built file edited since the freeze."); next }
  stale <- !is.null(run) && man$origin[i] == "RUN" && !(f %in% written)
  if (stale) add("output", f, "STALE", TRUE, paste0("Not rewritten by run ", run_id,
                 "; expected writer: ", man$written_by[i], ". The file on disk is from an earlier run."))
  if (!same) {
    det <- switch(man$ext[i],
      xlsx = xlsx_diff(f),
      png  = sprintf("png %sx%s -> %sx%s px, %s -> %s bytes", man$width[i], man$height[i],
                     cur$width[cur$file == f], cur$height[cur$file == f], man$bytes[i], cur$bytes[cur$file == f]),
      txt = , csv = , log = , md = text_diff(f),
      sprintf("%s -> %s bytes", man$bytes[i], cur$bytes[cur$file == f]))
    add("output", f, "DIFFERS", TRUE, det)
  } else if (!stale) add("output", f, "MATCH", FALSE)
}
for (f in setdiff(current, man$file)) {
  if (repro_is_manual(f)) add("manual", f, "NEW (manual)", FALSE, "Hand-built file added since the freeze.")
  else if (f %in% written) add("output", f, "NEW", FALSE, "Written by this run, not in the baseline; re-freeze if intended.")
  else add("output", f, "LEFTOVER", TRUE, "Not in the baseline and not written by this run: left over from an earlier run or written outside the pipeline.")
}

res <- do.call(rbind, rows)
nfail <- sum(res$fail)
cnt <- function(k, s) sum(res$kind == k & res$status == s)
verdict <- if (nfail == 0) {
  if (any(res$status %in% c("NEW", "NEW SCRIPT", "NEW (manual)", "CHANGED")))
    "REPRODUCES: no failures. Items marked NEW or CHANGED are listed for review." else
    "REPRODUCES: every script ran without error and every output matches the frozen baseline."
} else sprintf("DOES NOT REPRODUCE: %d failing item(s). See the FAIL list below.", nfail)

stamp <- format(Sys.time(), "%Y_%m_%d_%H%M")
fmt <- function(r) sprintf("  %-12s %-9s %s%s", r$status, r$kind, r$item, ifelse(nzchar(r$detail), paste0("\n               ", r$detail), ""))
fails <- res[res$fail, , drop = FALSE]; review <- res[!res$fail & !(res$status %in% c("MATCH")), , drop = FALSE]
rep <- c(
  paste("Reproduction check (local):", format(Sys.time(), "%Y-%m-%d %H:%M %Z")),
  paste("Baseline:  ", sub("^# ", "", banner[1])),
  paste("Baseline run:", bval("Run"), "  Forced freeze:", bval("Forced")),
  paste("Run checked:", if (is.null(run)) "NONE FOUND" else run_id,
        if (!is.null(run) && !run$finished) "(UNFINISHED)" else ""),
  "",
  "SCRIPTS",
  sprintf("  scripts run: %d   ERROR: %d   NOT RUN: %d   code files changed since baseline run: %d",
          if (is.null(run) || is.null(run$ledger)) 0L else nrow(run$ledger), cnt("script", "ERROR"), cnt("script", "NOT RUN"),
          sum(res$kind == "code")),
  "OUTPUTS",
  sprintf("  checked: %d   MATCH: %d   DIFFERS: %d   STALE: %d   MISSING: %d   LEFTOVER: %d   NEW: %d",
          sum(man$origin != "MANUAL") + sum(res$status %in% c("NEW", "LEFTOVER")),
          cnt("output", "MATCH"), cnt("output", "DIFFERS"), cnt("output", "STALE"),
          cnt("output", "MISSING"), cnt("output", "LEFTOVER"), cnt("output", "NEW")),
  "13_MANUAL (hand-built; information only unless MISSING)",
  sprintf("  MATCH: %d   CHANGED: %d   MISSING: %d   NEW: %d", cnt("manual", "MATCH"), cnt("manual", "CHANGED"),
          cnt("manual", "MISSING"), cnt("manual", "NEW (manual)")),
  "",
  verdict,
  if (nrow(fails)) c("", "FAIL", unlist(lapply(split(fails, seq_len(nrow(fails))), fmt))),
  if (nrow(review)) c("", "FOR REVIEW (not failures)", unlist(lapply(split(review, seq_len(nrow(review))), fmt))))
writeLines(rep, file.path(REPRO_OUTDIR, paste0("VERIFY_REPORT_", stamp, ".txt")))
utils::write.csv(res, file.path(REPRO_OUTDIR, paste0("VERIFY_DETAIL_", stamp, ".csv")), row.names = FALSE)
cat(paste(rep, collapse = "\n"), "\n")
# Under Rscript, signal failure with exit status 1. When this script is running
# under the run logger, hand the status to the logger so the log is finished
# first (02_logging.R exits with it); otherwise quit directly.
if (nfail > 0 && !interactive()) {
  if (exists(".kit_log_state", envir = globalenv()) &&
      length(get(".kit_log_state", envir = globalenv())$stack) > 0) {
    assign("KIT_EXIT_STATUS", 1L, envir = globalenv())
  } else quit(status = 1, save = "no")
}

# End of 12_verify_reproduction.R
