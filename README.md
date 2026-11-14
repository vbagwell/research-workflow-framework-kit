# Research Workflow Framework Kit

Companion software for the manuscript *An integrated twelve-step workflow for managing complex research: planning, executing, changing and reporting multi-model studies* (Victor Paul Bagwell, submitted to *BMC Medical Research Methodology*, November 2026).

The kit is a reduced, generic implementation of the workflow described in the article. It runs end to end on a synthetic dataset with base R alone (openxlsx and sandwich are used when installed) under the same run-logging, baseline-freeze and reproducibility-verification controls as the originating study.

## Contents (48 files)

| Folder | What it holds |
|---|---|
| `Framework_Kit/Code/` | 38 R scripts: synthetic-data generator, numbered pipeline (`00_run_ALL.R`), diagnostics and model runners, baseline freeze (`run_Accept_Baseline.R`) and verification (`run_Reproducibility.R`) |
| `Framework_Kit/Code/00_Readme/` | `README.md` (how to run, requirements) and `README_HOW_TO_USE.docx` (execution guide) |
| `Framework_Kit/Templates/` | Four Excel templates (analysis plan, study map, results summary, cross-reference) and `Study_Map_Template.pptx` (overview slide plus one slide per aim) — human-maintained starting materials |
| `Framework_Kit/Data/`, `Framework_Kit/Results/` | Empty on distribution; filled by the generator and the pipeline |
| `Framework_Kit/LICENSE` | MIT |

## Quick start

See `Framework_Kit/Code/00_Readme/README.md`. In short: source the synthetic-data generator once to create `Data/Study_Data.csv`, then source `Code/00_run_ALL.R`; freeze a baseline with `run_Accept_Baseline.R` and verify a later run with `run_Reproducibility.R`.

## Citation and versions

Release `v1.0` corresponds to the archive supplied with the manuscript as Additional file 2 (`Framework_Kit_2026-11-13.zip`). An archived copy of each release is deposited in Zenodo; cite the DOI shown on the release.

## Licence

MIT — see `Framework_Kit/LICENSE`.
