/*
================================================================================
  DiD_Greenbonds.do
  Difference-in-differences regressions for yield-to-maturity (YTM),
  estimating the green bond premium around the ECB CSPP announcement.

  Three control groups are considered:
    ctrl_noncredit : non-credit EUR-denominated green bonds
    ctrl_credit    : credit EUR-denominated green bonds
    ctrl_SEK       : SEK-denominated would-be-eligible green bonds

  Inputs  : ${data}/YTM_all_Green.dta
  Outputs : ${tables}/reg_green_ctrl_noncredit.tex
            ${tables}/reg_green_ctrl_credit.tex
            ${tables}/reg_green_ctrl_SEK.tex

  Dependencies: reghdfe, eststo, esttab, mycodebook.do
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

use "${data}/YTM_all_Green.dta"

cd "${tables}"

eststo clear

destring YTM, replace
destring GICS_4D, replace
destring MONTH, replace

drop if YTM==.

egen COUNTRY2 = group(COUNTRY)
gen ECB_ELIGIBLE_B =.

replace ECB_ELIGIBLE_B = 1 if (ECB_ELIGIBLE=="True")
replace ECB_ELIGIBLE_B=0 if (ECB_ELIGIBLE=="False")
replace ECB_ELIGIBLE_B =. if (ECB_ELIGIBLE=="")
replace ECB_ELIGIBLE_B=0 if ECB_ELIGIBLE_B==.

label var ECB_ELIGIBLE_B "CSPP Eligible = 1"

gen POST_B =.

replace POST_B = 1 if (POST=="True")
replace POST_B=0 if (POST=="False")
replace POST_B =. if (POST=="")

label var POST_B "Post = 1"

gen ELIGIBLE_POST = (POST_B==1)*(ECB_ELIGIBLE_B==1)
label var ELIGIBLE_POST "Post x CSPP Eligible"

** First Control group: Non-eligible EUR denominated green bonds
*gen GROUP_1 = 1 if CURRENCY=="EUR" & GREEN_BOND=="True"

* Implicitely, CREDIT==FALSE only defined for Stoxx600.
gen ctrl_noncredit = 1 if CURRENCY=="EUR" & GREEN_BOND=="True" & CREDIT=="False" | (ECB_ELIGIBLE=="True" & GICS_4D!=.)

gen ctrl_credit = 1 if (CURRENCY=="EUR" & GREEN_BOND=="True" & CREDIT=="True" & ECB_ELIGIBLE=="False")| (CURRENCY=="EUR" & GREEN_BOND=="True" & ECB_ELIGIBLE=="True")

gen ctrl_SEK = 1  if (CURRENCY=="SEK" & GREEN_BOND=="True" & WOULD_BE_ELIGIBLE=="1.0")| (CURRENCY=="EUR" & GREEN_BOND=="True" & ECB_ELIGIBLE=="True" & CREDIT!="")
* Unsure whether treatment group for group 4 should change... Include only Eligible EUR or all EUR?

** Summary stats:
gen EUR_denominated = (CURRENCY=="EUR")
gen non_credit = (CREDIT=="False")
gen green_bond = (GREEN_BOND=="True")

label var YTM "Yield to maturity"
label var green_bond "Green Bond = 1 "
*label var ECB_ELIGIBLE "CSPP-eligible bond = 1", replace
label var EUR_denominated "Euro-denominated = 1"
label var non_credit "Non-credit corporate bond = 1"

/* already done in summary stats at bond level
foreach i in  GROUP_2 GROUP_3 GROUP_4 {
estpost sum YTM green_bond ECB_ELIGIBLE_B EUR_denominated non_credit if `i'==1
esttab using "${tables}/summarystats_`i'.tex", cells("count mean sd min max") noobs nonumber label  style(tex) replace collabels("Obs." "Mean" "Sd" "Min" "Max")
}*/

** Regressions:  GROUP_3
foreach i in  ctrl_noncredit ctrl_credit ctrl_SEK {
    reghdfe YTM ELIGIBLE_POST ECB_ELIGIBLE_B POST_B if `i'==1, noabsorb nocon vce(cl ISIN)
	eststo mano, title("")
	estadd local BondFE "No"
	estadd local WeekFE "No"
	estadd local CountryMonthFE "No"
	estadd local SectorMonthFE "No"
	
	mycodebook ISIN  if `i'==1
	estadd scalar nb_bonds = r(nv_ISIN)
	
	reghdfe YTM ELIGIBLE_POST  if `i'==1, absorb(ISIN WEEK ) nocon vce(cl ISIN)
	eststo bondweek, title("")
	estadd local BondFE "Yes"
	estadd local WeekFE "Yes"
	estadd local CountryMonthFE "No"
	estadd local SectorMonthFE "No"
	mycodebook ISIN  if `i'==1
	estadd scalar nb_bonds = r(nv_ISIN)
	
	reghdfe YTM ELIGIBLE_POST  if `i'==1, absorb(ISIN WEEK COUNTRY2#MONTH) nocon vce(cl ISIN)
	eststo bwcm, title("")
	estadd local BondFE "Yes"
	estadd local WeekFE "Yes"
	estadd local CountryMonthFE "Yes"
	estadd local SectorMonthFE "No"
	mycodebook ISIN  if `i'==1
	estadd scalar nb_bonds = r(nv_ISIN)
	
	reghdfe YTM ELIGIBLE_POST  if `i'==1, absorb(ISIN WEEK GICS_4D#MONTH) nocon vce(cl ISIN)
	eststo bwsm, title("")
	estadd local BondFE "Yes"
	estadd local WeekFE "Yes"
	estadd local CountryMonthFE "No"
	estadd local SectorMonthFE "Yes"
	
	mycodebook ISIN  if `i'==1
	estadd scalar nb_bonds = r(nv_ISIN)
	
	
	esttab mano bondweek bwcm bwsm using "${tables}/reg_green_`i'.tex", cells(b(star fmt(3) label("Coef.")) t(par fmt(3) label("t-stat"))) legend label varlabels(_cons Constant) stats(nb_bonds r2_a BondFE WeekFE CountryMonthFE SectorMonthFE, fmt(0 3) labels("Number of distinct bonds" "Adj. R-squared" "Bond FE" "Week FE" "Country x Month FE" "Sector x Month FE" )) style(tex) replace starlevels(* 0.10 ** 0.05 *** 0.01)
	eststo clear

}

