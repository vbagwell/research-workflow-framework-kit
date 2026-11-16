# =====================================================================
# Framework Kit: integrated research workflow (template)
# Ported from the originating study's production controls, 2026-11-06
# Revised: 2026-11-16 (repro_baseline_path: long-path-safe baseline copies)
#          2026-10-25
# =====================================================================
#
# =============================================================================
# _repro_common.R - Shared definitions for the baseline freeze and the
#                   reproduction check (library file; sourced, never run alone)
# =============================================================================
#
# Sourced by 12_freeze_repro_baseline.R and 12_verify_reproduction.R so the two
# use ONE definition of: which files are in scope, how each kind of file is
# fingerprinted, which content is volatile, and how a run's ledger is read.
#
# SCOPE: every file under Analysis/Results except
#   14_Reproducibility/  (the check's own files)
#   15_Run_Logs/         (run logs; read separately as the run ledger)
#   any _to_delete/, Archive/ or archive/ folder, Office lock files (~$...),
#   .RData / .Rhistory, and self-timestamped script logs (*_LOG_YYYY-...).
#   13_Manual/ is in scope but is hand-built, so it is reported separately
#   (CHANGED is information there, not a reproduction failure).
#
# FINGERPRINTS:
#   .xlsx  content hash per sheet (cell values, numbers at 8 significant
#          digits), so xlsx zip timestamps never trip it; the file
#          fingerprint is the hash of the sheet hashes.
#   other  hash of the bytes (.png/.svg were confirmed byte-identical across
#          the 2026-10-09 and 2026-10-12 runs for every unchanged chart);
#          .txt/.csv/.log/.md are hashed after masking timestamps.
#
# VOLATILE CONTENT (masked before hashing, in both freeze and verify):
#   - date-time stamps such as 2026-10-25 14:50:25, 2026-10-25_14-50-25,
#     2026-10-25T14:50 (a bare date such as 2026-05-26 is NOT masked, since
#     dates can be real content)
#   - whole sheets whose name matches VOLATILE_SHEETS (run-timing sheets)
#   Add a pattern below if a verify report shows a file that differs ONLY in
#   run-specific content; record why next to it.
# =============================================================================

# openxlsx is OPTIONAL. With it, .xlsx outputs are fingerprinted by sheet
# content (cell values, numbers at 8 significant digits, volatile sheets and
# timestamps masked). Without it, .xlsx files are fingerprinted as bytes and the
# manifest records method "bytes (openxlsx not installed)"; a byte fingerprint is
# stricter (any re-save differs), so install openxlsx for content verification.
HAS_OPENXLSX <- requireNamespace("openxlsx", quietly = TRUE)
if (HAS_OPENXLSX) suppressWarnings(suppressMessages(library(openxlsx)))

VOLATILE_SHEETS <- c(
  "(?i)run[_ ]?timing"     # 00_data_diagnostic_general.xlsx sheet 00c: seconds per step
)
TIMESTAMP_RE <- "[0-9]{4}-[0-9]{2}-[0-9]{2}[ T_][0-9]{2}[:\\-][0-9]{2}([:\\-][0-9]{2}(\\.[0-9]+)?)?( ?[A-Z]{2,4})?"

repro_find_root <- function() {
  starts <- character(0)
  for (i in rev(seq_len(sys.nframe()))) {
    of <- sys.frame(i)$ofile
    if (!is.null(of)) starts <- c(starts, dirname(normalizePath(of, winslash = "/", mustWork = FALSE)))
  }
  starts <- unique(c(starts, normalizePath(getwd(), winslash = "/", mustWork = FALSE)))
  for (st in starts) {
    r <- st
    while (!file.exists(file.path(r, "Data", "Study_Data.csv")) && dirname(r) != r) r <- dirname(r)
    if (file.exists(file.path(r, "Data", "Study_Data.csv"))) return(r)
  }
  stop("Could not find the project root (the folder containing Data/Study_Data.csv).")
}

REPRO_ROOT    <- repro_find_root()
REPRO_RESULTS <- file.path(REPRO_ROOT, "Results")
REPRO_OUTDIR  <- file.path(REPRO_RESULTS, "14_Reproducibility")
REPRO_LOGDIR  <- file.path(REPRO_RESULTS, "15_Run_Logs")
REPRO_MANIFEST <- file.path(REPRO_OUTDIR, "REPRO_MANIFEST.csv")
MANIFEST_FORMAT <- "repro-manifest v2"
dir.create(REPRO_OUTDIR, showWarnings = FALSE, recursive = TRUE)

repro_md5_string <- function(s) {
  tf <- tempfile(); on.exit(unlink(tf))
  writeBin(charToRaw(enc2utf8(s)), tf)
  unname(tools::md5sum(tf))
}
repro_rel <- function(p) {
  base <- paste0(normalizePath(REPRO_RESULTS, winslash = "/", mustWork = FALSE), "/")
  p <- normalizePath(p, winslash = "/", mustWork = FALSE)
  ifelse(startsWith(tolower(p), tolower(base)), substring(p, nchar(base) + 1), p)
}

# --- Files in scope ------------------------------------------------------------
repro_scope_files <- function() {
  f <- list.files(REPRO_RESULTS, recursive = TRUE, full.names = TRUE)
  rel <- repro_rel(f)
  drop <- grepl("^(14_Reproducibility|15_Run_Logs)/", rel) |
          grepl("(^|/)(_to_delete|Archive|archive)/", rel) |
          grepl("(^|/)~\\$", rel) |
          grepl("(^|/)\\.(RData|Rhistory)$", rel) |
          grepl("_LOG_[0-9]{4}-[0-9]{2}-[0-9]{2}", basename(rel)) |
          rel == "README.txt"          # the kit's placeholder note in Results/, not a pipeline output
  sort(rel[!drop])
}
repro_folder <- function(rel) sub("/.*$", "", rel)
repro_is_manual <- function(rel) repro_folder(rel) == "13_Manual"

# --- Canonical cell text --------------------------------------------------------
repro_canon <- function(x) {
  if (is.numeric(x)) return(ifelse(is.na(x), "NA_", formatC(x, format = "g", digits = 8)))
  x <- ifelse(is.na(x), "NA_", trimws(as.character(x)))
  gsub(TIMESTAMP_RE, "<TIMESTAMP>", x, perl = TRUE)
}

# --- Read every sheet of a workbook as a canonical character matrix -------------
repro_read_xlsx <- function(path) {
  if (!HAS_OPENXLSX) return(NULL)
  shts <- tryCatch(getSheetNames(path), error = function(e) NULL)
  if (is.null(shts)) return(NULL)
  out <- list()
  for (s in shts) {
    if (any(vapply(VOLATILE_SHEETS, function(p) grepl(p, s, perl = TRUE), logical(1)))) {
      out[[s]] <- matrix("<VOLATILE SHEET>", 1, 1); next
    }
    d <- tryCatch(read.xlsx(path, sheet = s, colNames = FALSE,
                            skipEmptyRows = FALSE, skipEmptyCols = FALSE),
                  error = function(e) NULL)
    out[[s]] <- if (is.null(d) || !NROW(d)) matrix(character(0), 0, 0) else
      do.call(cbind, lapply(d, repro_canon))
  }
  out
}
repro_sheet_hash <- function(m) {
  if (!length(m)) return(repro_md5_string(""))
  repro_md5_string(paste(dim(m)[1], dim(m)[2], paste(m, collapse = "|"), sep = "#"))
}
repro_text_lines <- function(path) {
  x <- tryCatch(readLines(path, warn = FALSE, encoding = "UTF-8"), error = function(e) character(0))
  gsub(TIMESTAMP_RE, "<TIMESTAMP>", x, perl = TRUE)
}
repro_png_dims <- function(path) {
  con <- file(path, "rb"); on.exit(close(con))
  sig <- readBin(con, "raw", 24)
  if (length(sig) < 24) return(c(NA, NA))
  c(sum(as.integer(sig[17:20]) * 256^(3:0)), sum(as.integer(sig[21:24]) * 256^(3:0)))
}

# --- Baseline copy path (Windows 260-character path limit) ----------------------
#     The freeze copies every baseline file under BASELINE_FILES_<stamp>/. On
#     Windows that prefix can push a long results path past the 260-character
#     limit, and file.copy() then fails with only a warning. The copy is
#     therefore stored under a shortened file name when needed: the leading
#     characters of the name and the extension are kept and a "~" marks the
#     cut. The manifest keeps the real relative path, so fingerprint comparison
#     is unaffected; freeze and verify both resolve the copy through this
#     function.
repro_baseline_path <- function(bdir, rel, limit = 250L) {
  p <- file.path(bdir, rel)
  if (nchar(p) <= limit) return(p)
  d <- dirname(p); b <- basename(rel); ext <- tools::file_ext(b)
  stem <- if (nzchar(ext)) substr(b, 1, nchar(b) - nchar(ext) - 1L) else b
  room <- limit - nchar(d) - 1L - (if (nzchar(ext)) nchar(ext) + 1L else 0L) - 1L
  if (room < 8L) room <- 8L
  short <- paste0(substr(stem, 1L, room), "~")
  file.path(d, if (nzchar(ext)) paste0(short, ".", ext) else short)
}

# --- Fingerprint one file (path relative to Analysis/Results) -------------------
#     Returns a one-row data.frame.
repro_fingerprint <- function(rel) {
  p <- file.path(REPRO_RESULTS, rel)
  ext <- tolower(tools::file_ext(rel))
  w <- NA_integer_; h <- NA_integer_; sheets <- NA_character_; method <- "bytes"
  if (ext == "xlsx") {
    m <- repro_read_xlsx(p)
    if (is.null(m)) {
      fp <- unname(tools::md5sum(p)); method <- if (HAS_OPENXLSX) "bytes (unreadable as xlsx)" else "bytes (openxlsx not installed)"
    } else {
      sh <- vapply(m, repro_sheet_hash, character(1))
      sheets <- paste(paste0(names(sh), "=", sh), collapse = ";")
      fp <- repro_md5_string(sheets); method <- "xlsx content"
    }
  } else if (ext %in% c("txt", "csv", "log", "md")) {
    fp <- repro_md5_string(paste(repro_text_lines(p), collapse = "\n")); method <- "text (timestamps masked)"
  } else {
    fp <- unname(tools::md5sum(p))
    if (ext == "png") { d <- repro_png_dims(p); w <- d[1]; h <- d[2] }
  }
  data.frame(file = rel, folder = repro_folder(rel), ext = ext, method = method,
             fingerprint = fp, sheets = sheets, bytes = file.info(p)$size,
             width = w, height = h, stringsAsFactors = FALSE)
}

# --- Run ledger ------------------------------------------------------------------
repro_latest_full_run <- function() {
  lf <- file.path(REPRO_LOGDIR, "LATEST_FULL_RUN.txt")
  if (!file.exists(lf)) return(NA_character_)
  trimws(readLines(lf, n = 1, warn = FALSE))
}
repro_read_run <- function(run_id) {
  d <- file.path(REPRO_LOGDIR, run_id)
  if (is.na(run_id) || !dir.exists(d)) return(NULL)
  rd <- function(f) { p <- file.path(d, f); if (file.exists(p)) utils::read.csv(p, stringsAsFactors = FALSE) else NULL }
  info <- if (file.exists(file.path(d, "RUN_INFO.txt"))) readLines(file.path(d, "RUN_INFO.txt"), warn = FALSE) else character(0)
  list(id = run_id, dir = d, info = info,
       finished = file.exists(file.path(d, "RUN_SUMMARY.txt")),
       ledger = rd("RUN_LEDGER.csv"), outputs = rd("RUN_OUTPUTS.csv"),
       code = rd("CODE_FINGERPRINT.csv"))
}
repro_run_written <- function(run) {
  if (is.null(run$outputs) || !nrow(run$outputs)) return(character(0))
  unique(run$outputs$output)
}
repro_leaf_writer <- function(run, rel) {
  o <- run$outputs
  if (is.null(o)) return(NA_character_)
  o <- o[o$output == rel, , drop = FALSE]
  if (!nrow(o)) return(NA_character_)
  o$script[which.max(o$depth)]
}

# End of _repro_common.R
