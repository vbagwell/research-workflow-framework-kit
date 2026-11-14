# =====================================================================
# Framework Kit: integrated research workflow (template)
# Revised: 2026-09-11
# =====================================================================
# 11_format_tables.R - SECOND pass: house-style formatting applied in place
# to the exported tables (header fill, column widths). This script owns the
# PRESENTATION and never changes a number. It is a no-op without openxlsx.
if (.has_xlsx()) {
  for (f in list.files(OUT_TABFIG, pattern = "^ID[0-9]+_.*\\.xlsx$", full.names = TRUE)) {
    wb <- openxlsx::loadWorkbook(f); sh <- names(wb)[1]
    openxlsx::addStyle(wb, sh, openxlsx::createStyle(fontColour = "#FFFFFF", fgFill = "#1F3864", textDecoration = "bold"), rows = 1, cols = 1:20, gridExpand = TRUE)
    openxlsx::setColWidths(wb, sh, cols = 1:20, widths = "auto"); openxlsx::saveWorkbook(wb, f, overwrite = TRUE)
  }
  cat("Formatting pass applied to", length(list.files(OUT_TABFIG, pattern = "^ID")), "tables\n")
} else cat("Formatting pass skipped (openxlsx not installed); numbers are unaffected\n")
