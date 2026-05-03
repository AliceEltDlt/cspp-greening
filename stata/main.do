/*
================================================================================
  main.do
  Master script — runs the full analysis pipeline in order.

  Usage (from the repo root):
    stata-mp -b do stata/main.do

  To override default paths, set globals before calling:
    global data    "/path/to/data/clean"
    global tables  "/path/to/output/tables"
    global figures "/path/to/output/figures"
    stata-mp -b do stata/main.do

  Pipeline order:
    1. mycodebook.do        — define helper program (must run first)
    2. BondLvl_descstats.do — summary statistics at bond level
    3. FirmLvl_descstats.do — summary statistics at firm level
    4. DiD_Greenbonds.do    — DiD regressions: green bond yield premium
    5. DiD_Brownbonds.do    — DiD regressions: brown firm yield penalty
    6. EventStudy.do        — event study: CARs around CSPP announcement
================================================================================
*/

// ── Path globals (override before running if needed) ─────────────────────────
if "${data}"    == "" global data    "data/clean"
if "${tables}"  == "" global tables  "output/tables"
if "${figures}" == "" global figures "output/figures"
// ─────────────────────────────────────────────────────────────────────────────

// ── Stata settings ───────────────────────────────────────────────────────────
set more off
set scheme uncluttered
// ─────────────────────────────────────────────────────────────────────────────

// ── Required packages (install once) ─────────────────────────────────────────
// Uncomment on first run:
// ssc install reghdfe
// ssc install estout
// ssc install distinct
// ssc install tabout
// ─────────────────────────────────────────────────────────────────────────────

di "============================================================"
di "  Step 1 — Load helper program: mycodebook"
di "============================================================"
do stata/mycodebook.do

di "============================================================"
di "  Step 2 — Bond-level descriptive statistics"
di "============================================================"
do stata/BondLvl_descstats.do

di "============================================================"
di "  Step 3 — Firm-level descriptive statistics"
di "============================================================"
do stata/FirmLvl_descstats.do

di "============================================================"
di "  Step 4 — DiD regressions: green bond yield premium"
di "============================================================"
do stata/DiD_Greenbonds.do

di "============================================================"
di "  Step 5 — DiD regressions: brown firm yield penalty"
di "============================================================"
do stata/DiD_Brownbonds.do

di "============================================================"
di "  Step 6 — Event study: CARs around CSPP announcement"
di "============================================================"
do stata/EventStudy.do

di "============================================================"
di "  All steps complete."
di "  Tables written to: ${tables}"
di "  Figures written to: ${figures}"
di "============================================================"
