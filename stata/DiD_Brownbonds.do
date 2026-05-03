/*
================================================================================
  DiD_Brownbonds.do
  Difference-in-differences regressions for yield-to-maturity (YTM),
  comparing green vs brown firms among CSPP-eligible bonds.

  Identifies the causal effect of the ECB's CSPP announcement on the
  borrowing cost of firms classified as brown (high-emissions) relative
  to green firms, using bond and week fixed effects plus industry x month
  and country x month controls.

  Inputs  : ${data}/YTM_all_Brown.dta
  Outputs : ${tables}/reg_brown_SCOPE_1_EMISSIONS_F.tex
            ${tables}/reg_brown_SCOPE_1_INTENSITY_F.tex
            ${tables}/reg_brown_SCOPE_1_EMISSIONS_4D.tex
            ${tables}/reg_brown_SCOPE_1_INTENSITY_4D.tex

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
eststo clear

use "${data}/YTM_all_Brown.dta"

cd "${tables}"

destring YTM, replace
destring MONTH, replace
destring GICS_4D, replace

drop if YTM==.
egen COUNTRY2 = group(COUNTRY)

gen EUR_denominated = (CURRENCY=="EUR")

label var YTM "Yield to maturity"
label var GREEN_BOND "Green Bond = 1 "
label var ECB_ELIGIBLE "CSPP-eligible bond = 1"
label var EUR_denominated "Euro-denominated = 1"
label var CREDIT "Corporate bond issued by a credit institution = 1"

gen POST_B =.

replace POST_B = 1 if (POST==1)
replace POST_B=0 if (POST==0)

label var POST_B "Post = 1"

label var SCOPE_1_EMISSIONS_GREEN_F "Green Firm (full) = 1 "
label var SCOPE_1_EMISSIONS_BROWN_F "Brown Firm (full) = 1 "

/*
gen BROWN_POST = (POST_B==1)*(SCOPE_1_EMISSIONS_BROWN_F==1)
label var BROWN_POST "Post x Brown (full)"

gen GROUP_1 = 1 if (SCOPE_1_EMISSIONS_GREEN_F==1) | (SCOPE_1_EMISSIONS_BROWN_F==1)
label var GROUP_1 "em_f"
gen GROUP_2 = 1 if (SCOPE_1_EMISSIONS_GREEN_4D==1) | (SCOPE_1_EMISSIONS_BROWN_4D==1)
label var GROUP_2 "em_4d"

local groups GROUP_1 GROUP_2
*/

** Regressions: 
foreach u in "SCOPE_1" {
foreach t in "EMISSIONS" "INTENSITY" {
*local lab: variable label `g'
foreach s in "F" "4D"{

label var `u'_`t'_BROWN_`s' "Brown"
gen BROWN_POST = (POST_B==1)*(`u'_`t'_BROWN_`s'==1)
label var BROWN_POST "Post x Brown"

gen GROUP = (`u'_`t'_GREEN_`s'==1) | (`u'_`t'_BROWN_`s'==1)
	
reghdfe YTM BROWN_POST `u'_`t'_BROWN_`s' POST_B if (GROUP==1) & (ECB_ELIGIBLE==1), noabsorb nocon vce(cl ISIN)
eststo mano, title("")
estadd local BondFE "No"
estadd local WeekFE "No"
estadd local IssuerFE "No"
estadd local CountryMonthFE "No"
estadd local SectorMonthFE "No"

mycodebook ISIN  if (GROUP==1) & (ECB_ELIGIBLE==1)
estadd scalar nb_bonds = r(nv_ISIN)
	
reghdfe YTM BROWN_POST if GROUP==1 & ECB_ELIGIBLE==1, absorb(ISIN WEEK) nocon vce(cl ISIN)
eststo bondweek, title("")
estadd local BondFE "Yes"
estadd local WeekFE "Yes"
estadd local IssuerFE "No"
estadd local CountryMonthFE "No"
estadd local SectorMonthFE "No"

mycodebook ISIN  if GROUP==1 & ECB_ELIGIBLE==1
estadd scalar nb_bonds = r(nv_ISIN)

reghdfe YTM BROWN_POST if GROUP==1 & ECB_ELIGIBLE==1, absorb(ISIN WEEK GVKEY) nocon vce(cl ISIN)
eststo bondissweek, title("")
estadd local BondFE "Yes"
estadd local WeekFE "Yes"
estadd local IssuerFE "Yes"
estadd local CountryMonthFE "No"
estadd local SectorMonthFE "No"

mycodebook ISIN  if GROUP==1 & ECB_ELIGIBLE==1
estadd scalar nb_bonds = r(nv_ISIN)
	
reghdfe YTM BROWN_POST  if GROUP==1 & ECB_ELIGIBLE==1, absorb(ISIN WEEK COUNTRY2#MONTH) nocon vce(cl ISIN)
eststo bwcm, title("")
estadd local BondFE "Yes"
estadd local WeekFE "Yes"
estadd local IssuerFE "No"
estadd local CountryMonthFE "Yes"
estadd local SectorMonthFE "No"

mycodebook ISIN  if GROUP==1 & ECB_ELIGIBLE==1
estadd scalar nb_bonds = r(nv_ISIN)
	
reghdfe YTM BROWN_POST  if GROUP==1 & ECB_ELIGIBLE==1, absorb(ISIN WEEK GICS_4D#MONTH) nocon vce(cl ISIN)
eststo bwsm, title("")
estadd local BondFE "Yes"
estadd local WeekFE "Yes"
estadd local IssuerFE "No"
estadd local CountryMonthFE "No"
estadd local SectorMonthFE "Yes"

mycodebook ISIN  if GROUP==1 & ECB_ELIGIBLE==1
estadd scalar nb_bonds = r(nv_ISIN)
	
esttab mano bondweek bondissweek bwcm bwsm using "${tables}/reg_brown_`u'_`t'_`s'.tex", cells(b(star fmt(3) label("Coef.")) t(par fmt(3) label("t-stat"))) legend label varlabels(_cons Constant) stats(nb_bonds r2_a BondFE WeekFE IssuerFE CountryMonthFE SectorMonthFE, fmt(0 3) labels("Number of distinct bonds" "Adj. R-squared" "Bond FE" "Week FE" "Issuer FE" "Country x Month FE" "Sector x Month FE" )) style(tex) replace starlevels(* 0.10 ** 0.05 *** 0.01)
eststo clear

drop GROUP
drop BROWN_POST
	
}
}
}
