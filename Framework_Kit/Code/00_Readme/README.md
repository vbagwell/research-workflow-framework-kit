# Framework Kit: integrated research workflow (template)

This is the reduced, generic version of the workflow described in the paper
"From research question to publication: an integrated workflow for
planning, analyzing and reporting complex, multi-model studies". It runs end to end on a synthetic dataset with base R alone, and uses openxlsx and sandwich when they
are installed (one workbook per aim with one worksheet per model, and
sandwich::vcovCL for the cluster-robust covariance).

Requirements, stated plainly:
- Analysis pipeline (00_run_ALL.R): base R. Without openxlsx every table is
  written as CSV; without sandwich a base-R HC1 cluster-robust covariance is used.
- Baseline freeze and verification (run_Accept_Baseline.R, run_Reproducibility.R):
  base R runs them, but CONTENT fingerprints of .xlsx outputs need openxlsx;
  without it .xlsx files are fingerprinted as bytes (method recorded in the
  manifest as "bytes (openxlsx not installed)"). Install openxlsx for the
  documented content-level verification.
- The four Excel templates (plan, study map, results summary, cross-reference)
  and the PowerPoint study-map template (Templates/Study_Map_Template.pptx: an
  overview slide and one slide per aim, every entry a <placeholder>) are
  HUMAN-MAINTAINED starting materials. The pipeline does not fill them; the
  example rows in them are illustrative placeholders, not verified outputs.
- Testing with missing data: set Sys.setenv(KIT_MISSING_RATE = "0.05") before
  sourcing the synthetic-data generator (see that script's header).

## Run it (two lines, in this order)

Step 1, once: create the frozen input. The kit ships with an EMPTY Data folder.
Nothing else runs until Data/Study_Data.csv exists, so run the synthetic-data
generator first (or place your own frozen CSV there under that name):

    source("<kit>/Code/02_Synthetic_Data/00_make_synthetic_data.R")

Step 2: run the whole pipeline. It loads prep and helpers itself, so nothing
else has to be run before it:

    source("<kit>/Code/01_Run_Library/00_run_ALL.R")

Replace <kit> with the folder you unpacked the kit into, for example
D:/Projects/Framework_Kit. Full paths work from any working directory. The
relative form (source("Code/...")) works only when the kit folder is the
working directory. Every script finds the project root on its own (the
folder that holds Code/_bootstrap.R) and sets the working directory to it.

What a run records. 00_run_ALL.R is a logged FULL run: Results/15_Run_Logs/<run id>/
holds RUN_INFO.txt (R, platform, data file bytes and md5), CODE_FINGERPRINT.csv
(md5 of every code file), one log per script (output, warnings, error and
traceback), RUN_LEDGER.csv (status, seconds, warnings and outputs per script),
RUN_OUTPUTS.csv (every results file each script wrote) and RUN_SUMMARY.txt with
the verdict. A script error STOPS the run (fail-stop), so a FULL run that
reaches the end is one in which every script finished. Source 00_run_ALL.R in
a fresh R session; it refuses to start in a session that already holds a loaded
workspace. _refresh_df.R rebuilds the prepared data when a script left a subset
behind or changed its columns (row count and column fingerprint).

Reproducibility is two runners, nothing to set and nothing to edit:

    source("<kit>/Code/01_Run_Library/run_Accept_Baseline.R")    # FREEZE: fingerprint every output of the latest completed FULL run
    source("<kit>/Code/01_Run_Library/run_Reproducibility.R")    # VERIFY: judge the latest completed FULL run against the frozen baseline

The freeze refuses a run that did not finish, that had a script error, or
that left a results file it did not write (a leftover). The verifier reports
per script (ERROR, NOT RUN, NEW SCRIPT), per code file (CHANGED, ADDED,
REMOVED) and per output (MATCH, DIFFERS with the first differing cells,
STALE, MISSING, LEFTOVER, NEW), then a verdict, in a dated VERIFY_REPORT in
Results/14_Reproducibility. Timestamps inside files are masked before
comparison. It does not freeze a baseline on first use: a baseline accepted
immediately before verification would only show that the saved outputs agree
with themselves.

The analysis-pipeline lock (a demonstrated rebuild) is: fresh session,
00_run_ALL.R, run_Accept_Baseline.R, fresh session, 00_run_ALL.R,
run_Reproducibility.R. On the synthetic data with R 4.3.3 this protocol ran
on 2026-11-06: 23 script runs, 0 errors, 24 outputs, 24 MATCH, verdict
REPRODUCES. To run one aim alone, source its runner (for example
run_Aim_01.R); it is logged as an ADHOC run. To switch a step off, comment
its line in the STEPS list of 00_run_ALL.R.

## Adapt it to your study
1. Replace Data/Study_Data.csv with your frozen input, keeping the file name
   or changing it in _bootstrap.R and 00_prep.R.
2. Edit 00_prep.R: factor reference levels, derived variables, analytic frames,
   the drift-check rules. Record the same in the plan workbook (Templates/).
3. Rename the generic variables (dependent_1, independent_1, control_1, ...)
   in the model scripts to your own, or keep the generic names and map them in
   the variable registry.
   Give every registry variable a causal role (exposure, outcome, confounder,
   mediator, effect modifier, collider, instrument, proxy, descendant of
   outcome) and the handling rule that follows from it (adjust, interaction
   term, exclude from the total-effect model, never adjust); the legend under
   the registry table in the plan template lists the rules. Set the roles from
   a drawn diagram before any model is fitted, and keep the diagram with the
   plan.
4. Add a model: copy a script in Code/06_Aims/Aim_01, change the formula and
   the identifier. The runner picks it up by file name order.
5. Add an aim: copy the Aim_01 folder and run_Aim_01.R, add the runner to
   STEPS in 00_run_ALL.R.
6. Add a sensitivity analysis: a new script in 08_Sensitivity_Analysis that
   reads a model with read_model_coefs() and writes with write_table().
7. Publish a table: add a pub() line in 11_export_tables.R with the next ID.
8. Set the reporting precision before the analysis code is written:
   worksheet 14_Reporting_Precision of the plan template fixes the decimal
   places for every kind of reported quantity (p three decimals with the
   < .001 floor, ratios two, natural-unit coefficients one, log-scale
   coefficients three, AIC one, diagnostics two, CI limits and SEs matched to
   their estimate, leading zero dropped only for p and R2). The kit applies it
   once, in code: PRECISION, fmt_num() and fmt_p() at the top of
   11_export_tables.R format every published table, and
   07_convert_log_terms.R writes the real-terms text at the same precision.
   If your standard differs, change it there and in the plan worksheet
   together. Sweep the hand-maintained artifacts (prose, study map, results
   summary) against the same worksheet.

## Layout
Code/ and Results/ share stage numbers: 04 variable summary, 05 diagnostics,
06 aims, 07 log conversions, 08 sensitivity, 11 tables and figures.
Code/12_Reproducibility writes to Results/14_Reproducibility; the run logs
are in Results/15_Run_Logs. Every output file has a stable name and is
rewritten by each run, so runs can be compared file for file.

## Revised 2026-11-16
Baseline copies are long-path safe. The freeze stores every baseline copy
under BASELINE_FILES_<stamp>/; on Windows a long results path under that
prefix can exceed the 260-character limit, and file.copy() then fails with
only a warning. repro_baseline_path() in 12_Reproducibility/_repro_common.R
now shortens the stored file name when the full path would exceed 250
characters (leading characters and extension kept, "~" marks the cut); the
manifest keeps the real relative path, so fingerprint comparison is
unchanged. 12_freeze_repro_baseline.R stops on any failed copy instead of
warning, and 12_verify_reproduction.R reads the copies through the same
function.

## Revised 2026-11-06
The production controls of the originating study were ported into the kit:
the run logger (03_Preparation/02_logging.R), the fail-stop run_files(), the
fresh-session guard and logged FULL run in 00_run_ALL.R, the column
fingerprint in _refresh_df.R, the run-gated baseline freeze and the full
verifier (scripts, code and every output), and stable diagnostic output names.
