# Research Workflow Framework Kit

Companion software for the manuscript *From research question to publication: an integrated methods workflow for managing complex, multi-model studies* (Victor Paul Bagwell, submitted to *BMC Medical Research Methodology*, November 2026).

The kit is a reduced, generic implementation of the workflow described in the article. It runs end to end on a synthetic dataset with base R alone (openxlsx and sandwich are used when installed) under the same run-logging, baseline-freeze and reproducibility-verification controls as the originating study.

## Contents (48 files)

| Folder | What it holds |
|---|---|
| `Framework_Kit/Code/` | 38 R scripts: synthetic-data generator, numbered pipeline (`01_Run_Library/00_run_ALL.R`), diagnostics and model runners, baseline freeze (`run_Accept_Baseline.R`) and verification (`run_Reproducibility.R`) |
| `Framework_Kit/Code/00_Readme/` | `README.md` (how to run, requirements) and `README_HOW_TO_USE.docx` (execution guide) |
| `Framework_Kit/Templates/` | Four Excel templates (analysis plan, study map, results summary, cross-reference) and `Study_Map_Template.pptx` (overview slide plus one slide per aim) — human-maintained starting materials |
| `Framework_Kit/Data/`, `Framework_Kit/Results/` | Empty on distribution; filled by the generator and the pipeline |
| `Framework_Kit/LICENSE` | MIT |

## Quick start

See `Framework_Kit/Code/00_Readme/README.md`. In short: source the synthetic-data generator once to create `Data/Study_Data.csv`, then source `Code/01_Run_Library/00_run_ALL.R`; freeze a baseline with `run_Accept_Baseline.R` and verify a later run with `run_Reproducibility.R`.

## Citation and versions

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.24294039.svg)](https://doi.org/10.5281/zenodo.24294039)

Release `v1.2` (November 2026) corresponds to the archive supplied with the manuscript as Additional file 2 (`Framework_Kit_2026-11-16.zip`). Change from v1.1: baseline copies are long-path safe (`repro_baseline_path()` in `12_Reproducibility/_repro_common.R` shortens a stored copy's file name when the full path would exceed 250 characters; the freeze stops on any failed copy; the verifier reads copies through the same function). Zenodo version DOI: 10.5281/zenodo.24294039 (all versions: 10.5281/zenodo.24234653). Cite as: Bagwell VP. Research Workflow Framework Kit, v1.2. Zenodo; 2026. https://doi.org/10.5281/zenodo.24294039

Release `v1.1` (November 16, 2026; `Framework_Kit_2026-11-16.zip`, superseded the same day) is archived in Zenodo: DOI 10.5281/zenodo.24293140. Changes from v1.0: the variable registry of the analysis-plan template carries a causal-role column (exposure, outcome, confounder, mediator, effect modifier, collider, instrument, proxy, descendant of outcome) with the handling rule that follows from each role and a legend of those rules; the reporting-precision worksheet adds a row for predicted and event probabilities (3 decimals, interval limits matched); README path corrected.

Release `v1.0` (November 14, 2026; `Framework_Kit_2026-11-13.zip`) is archived in Zenodo: DOI 10.5281/zenodo.24234654.

## License

MIT License — see `Framework_Kit/LICENSE`.
