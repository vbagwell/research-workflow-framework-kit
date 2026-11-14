# =====================================================================
# Framework Kit: integrated research workflow (template)
# Revised: 2026-09-11
# =====================================================================
# run_Prep_and_Helpers.R - load the analysis foundation (prep + helpers)
# by hand, for an interactive session. Every other runner does this itself.
.this_file <- function() {
  a <- commandArgs(); f <- sub("^--file=", "", a[grepl("^--file=", a)]); if (length(f)) return(normalizePath(f[1]))
  for (i in rev(seq_len(sys.nframe()))) { o <- sys.frames()[[i]]$ofile; if (!is.null(o)) return(normalizePath(o)) }
  NA_character_
}
.find_root_from <- function(start) { r <- start; while (!file.exists(file.path(r, "Code", "_bootstrap.R")) && dirname(r) != r) r <- dirname(r); r }
.kit_root <- local({ tf <- .this_file(); .find_root_from(if (is.na(tf)) getwd() else dirname(tf)) })
assign(".kit_loaded", FALSE, envir = globalenv()); source(file.path(.kit_root, "Code", "_bootstrap.R"))
