# =====================================================================
# Framework Kit: integrated research workflow (template)
# Revised: 2026-11-06 (checks the prepared-column fingerprint as well as the row count)
# =====================================================================
# _refresh_df.R - guarantee the workspace holds the pristine, full-sample df
# before a runner does any analysis. Sourced at the TOP of every runner.
# WHY: two things can leave the wrong df behind and make a later run
# silently analyse the wrong rows: (1) sourcing a single stratum script by
# hand, which overwrites the global df with a subset; (2) an editor
# restoring a saved workspace on start-up. This guard compares the row
# count with the fingerprint stamped by 00_prep.R and rebuilds if needed.
.this_file <- function() {
  a <- commandArgs(); f <- sub("^--file=", "", a[grepl("^--file=", a)]); if (length(f)) return(normalizePath(f[1]))
  for (i in rev(seq_len(sys.nframe()))) { o <- sys.frames()[[i]]$ofile; if (!is.null(o)) return(normalizePath(o)) }
  NA_character_
}
.find_root_from <- function(start) { r <- start; while (!file.exists(file.path(r, "Code", "_bootstrap.R")) && dirname(r) != r) r <- dirname(r); r }
.kit_root <- local({ tf <- .this_file(); .find_root_from(if (is.na(tf)) getwd() else dirname(tf)) })
.kit_fp_now <- if (exists("df")) paste(paste0(names(df), ":", vapply(df, function(x) paste(class(x), collapse = "/"), "")), collapse = "|") else ""
if (!exists("df") || !exists(".kit_df_n") || nrow(df) != .kit_df_n ||
    !exists(".kit_df_fp") || !identical(.kit_fp_now, .kit_df_fp)) {
  cat("[_refresh_df] df missing, stale, a subset, or its prepared columns changed: rebuilding from 00_prep.R\n")
  assign(".kit_loaded", FALSE, envir = globalenv())
  source(file.path(.kit_root, "Code", "_bootstrap.R"))
}
