/*
================================================================================
  BondLvl_descstats.do
  Summary statistics at the bond level.

  Inputs  : ${data}/bond_data.dta
  Outputs : ${tables}/bonds_count.tex
            ${tables}/summarystats_0.tex  (conventional bonds)
            ${tables}/summarystats_1.tex  (green bonds)

  Run after: data construction (Python notebooks)
================================================================================
*/

clear all

// ── Path globals ─────────────────────────────────────────────────────────────
// Set these once here; all cd commands below use these globals.
// Override from the command line with: stata-mp -b do main.do [data_path] [output_path]
if "${data}" == "" global data    "data/clean"
if "${tables}" == "" global tables  "output/tables"
if "${figures}" == "" global figures "output/figures"
// ─────────────────────────────────────────────────────────────────────────────

cd "${data}"

use "${data}/bond_data.dta"

cd "${tables}"

label var YTM "Yield-to-Maturity"
label var Time_to_Maturity "Time to Maturity (in years)"
label var Cpn "Coupon"
label var Amt_Issued "Amount Issued (in M\\$)"

replace Amt_Issued = Amt_Issued / (1e6)

**** 

*preserve
gen nb_distinct_isin=.
label var nb_distinct_isin "# distinct bonds"
gen nb_distinct_gvkey=.
label var nb_distinct_gvkey "# distinct issuers"
gen nb_distinct_eligible=.
label var nb_distinct_eligible "# distinct CSPP eligible bonds"

local to_count_distinct nb_distinct_isin nb_distinct_gvkey nb_distinct_eligible

foreach i in 0 1 {
	distinct(ISIN) if  GREEN_BOND == `i'
	replace  nb_distinct_isin=r(ndistinct) if GREEN_BOND== `i'
	distinct(GVKEY)  if  GREEN_BOND == `i'
	replace  nb_distinct_gvkey=r(ndistinct) if GREEN_BOND== `i'
	distinct(ISIN)  if  GREEN_BOND == `i' & ECB_ELIGIBLE==1
	replace  nb_distinct_eligible=r(ndistinct) if GREEN_BOND== `i'
 }

label define bondtype 0 "Conventional bonds" 1 "Green bonds"
label values GREEN_BOND bondtype
tabout GREEN_BOND using "${tables}/bonds_count.tex", replace  ptotal(none) cells(min nb_distinct_gvkey  min nb_distinct_isin min nb_distinct_eligible ) sum h1(nil) h2(nil) h3( & \# distinct issuers &  \# distinct bonds &  \# CSPP-Eligible bonds \\) style(tex) format(0) topf(top.tex) botf(bot.tex)

**** 
foreach i in 0 1 {
	estpost su YTM Time_to_Maturity Cpn Amt_Issued if  GREEN_BOND == `i', detail 
	esttab using "${tables}/summarystats_`i'.tex", cells("mean(fmt(%5.3f)) sd(fmt(%5.3f)) min(fmt(%5.3f)) p5(fmt(%5.3f)) p50(fmt(%5.3f)) p95(fmt(%5.3f)) max(fmt(%5.3f))") noobs nonumber label  style(tex) replace collabels("Mean" "Sd" "Min" "p5" "Median" "p95" "Max") 

 }

