/*
================================================================================
  mycodebook.do
  Helper program: wraps -codebook- and -distinct- to return the number of
  distinct values for each variable as a return scalar (r(nv_<varname>)).

  Usage:
    mycodebook ISIN if GROUP==1
    estadd scalar nb_bonds = r(nv_ISIN)

  Called by: DiD_Brownbonds.do, DiD_Greenbonds.do, EventStudy.do
================================================================================
*/

// ── Path globals ─────────────────────────────────────────────────────────────
// Set these once here; all cd commands below use these globals.
// Override from the command line with: stata-mp -b do main.do [data_path] [output_path]
if "${data}" == "" global data    "data/clean"
if "${tables}" == "" global tables  "output/tables"
if "${figures}" == "" global figures "output/figures"
// ─────────────────────────────────────────────────────────────────────────────

capture program drop mycodebook
program mycodebook, rclass
syntax [varlist] [if] [in][, *]
codebook `varlist' `if' `in', `options'
capture ssc install distinct
foreach var of varlist `varlist' {
    qui distinct `var' `if' `in'
    return scalar nv_`var' = r(ndistinct)
}
end