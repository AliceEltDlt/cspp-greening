/*
================================================================================
  EventStudy.do
  Event study: t-tests and KS-tests on Cumulative Abnormal Returns (CARs)
  around the ECB CSPP climate-related announcement.

  CARs are pre-computed in Event_Study_GB_2010_2020.ipynb
  and loaded here from CARs.dta / CARs_6_09.dta.

  Analysis sections:
    1. By green bond issuer status
    2. By firm greenness (scope 1 emissions, full vs 4-digit GICS)
    3. [Commented] By CSPP participation
    4. [Commented] By industry x greenness
    5. By CSPP-eligible green bond ownership
    6. Market value of equity lost by brown firms

  Inputs  : ${data}/CARs.dta
  Outputs : ${tables}/CAR_ea_greeni.tex
            ${figures}/CAR_densities_F.png
            ${figures}/CAR_densities_4D.png
            ${figures}/CAR_densities_GB.png
            ${tables}/MVE_lost_summstats.tex

  Dependencies: scheme-uncluttered.scheme, mycodebook.do
================================================================================
*/

/* 
CAR (Cumulative Abnormal Returns) are computed in the notebook "Event_Study_GB_2010_2020.ipynb" which produces the "CARs_6_09.dta" file.
In each of the section, ttests are conducted with different subgroups of data.
*/

set scheme uncluttered

clear all

// ── Path globals ─────────────────────────────────────────────────────────────
// Set these once here; all cd commands below use these globals.
// Override from the command line with: stata-mp -b do main.do [data_path] [output_path]
if "${data}" == "" global data    "data/clean"
if "${tables}" == "" global tables  "output/tables"
if "${figures}" == "" global figures "output/figures"
// ─────────────────────────────────────────────────────────────────────────────

cd "${data}"
use "${data}/CARs.dta"

eststo clear

label variable CAR_around "CAR around event ([-1, 1] days)"
label variable CAR_before "CAR before event ([-50, -11] days)"
* For now, there is not enough data to have some meaningful CAR_after. (to_update)
label variable CAR_after "CAR after event ([11, 36] days)"

cd "${tables}"
*cd C:\Users\eliet\Desktop\GreenBonds_Stata\Tables_CAR

gen GREEN_BOND_ISSUER_B =.
replace GREEN_BOND_ISSUER_B = 1 if GREEN_BOND_ISSUER == "True"
replace GREEN_BOND_ISSUER_B = 0 if GREEN_BOND_ISSUER == "False"
drop GREEN_BOND_ISSUER
gen GREEN_BOND_ISSUER = GREEN_BOND_ISSUER_B
drop GREEN_BOND_ISSUER_B

**destring IS_CSPP, replace
gen IS_CSPP_B =.
replace IS_CSPP_B = 1 if IS_CSPP == "True"
replace IS_CSPP_B = 0 if IS_CSPP == "False"
drop IS_CSPP
gen IS_CSPP = IS_CSPP_B
drop IS_CSPP_B

egen groupl = group(Industries_grouped_by_intensity), label
egen group = group(Industries_grouped_by_intensity)
label define greenl 0 "Brown firms" 1 "Green firms" 

* to_update: for now, we dont have data on certification.

gen NONBANK_GREEN_ISSUER = (GREEN_BOND_ISSUER==1) * (CREDIT==0)
replace NONBANK_GREEN_ISSUER = . if NONBANK_GREEN_ISSUER == 0 
replace NONBANK_GREEN_ISSUER = 0 if (GREEN_BOND_ISSUER==0) * (CREDIT==0)

*gen ELIGIBLE_GREEN_ISSUER = (GREEN_BOND_ISSUER=="True") * (CSPP_ELIG==1)
*replace ELIGIBLE_GREEN_ISSUER = . if ELIGIBLE_GREEN_ISSUER == 0 
*replace ELIGIBLE_GREEN_ISSUER = 0 if (GREEN_BOND_ISSUER=="False") * CSPP_ELIG

foreach i in GREEN_BOND_ISSUER NONBANK_GREEN_ISSUER  {
      gen `i'__R = (1-`i')
}

eststo greeni: estpost ttest CAR_around, by(GREEN_BOND_ISSUER__R)
eststo non_greeni: estpost ttest CAR_around, by(NONBANK_GREEN_ISSUER__R)

esttab greeni non_greeni  using "${tables}/Tables/CAR_ea_greeni.tex", mtitles("\multicolumn{1}{M}{Green bond issuer \\ vs non green bond issuer}" "\multicolumn{1}{M}{Non-bank green bond issuer \\ vs non-bank non green bond issuers}") replace starlevels(* 0.10 ** 0.05 *** 0.01) ///
label nonumber

foreach s in "4D" "F"  {

gen NON_FINANCIAL_GREEN = (SCOPE_1_EMISSIONS_GREEN_`s'==1) * (CREDIT==0)
replace NON_FINANCIAL_GREEN = . if NON_FINANCIAL_GREEN==0
replace NON_FINANCIAL_GREEN = 0 if (SCOPE_1_EMISSIONS_BROWN_`s'==1) * (CREDIT==0)

replace SCOPE_1_EMISSIONS_GREEN_`s'=. if SCOPE_1_EMISSIONS_GREEN_`s'==0
replace SCOPE_1_EMISSIONS_GREEN_`s'=0 if SCOPE_1_EMISSIONS_BROWN_`s'==1

replace SCOPE_2_EMISSIONS_GREEN_`s'=. if SCOPE_2_EMISSIONS_GREEN_`s'==0
replace SCOPE_2_EMISSIONS_GREEN_`s'=0 if SCOPE_2_EMISSIONS_BROWN_`s'==1

foreach i in SCOPE_1_EMISSIONS_GREEN_`s' SCOPE_2_EMISSIONS_GREEN_`s' NON_FINANCIAL_GREEN{
      gen `i'__R = (1-`i')
}

/* For now, abandon ttests on the mean
eststo green1: estpost ttest CAR_around, by(SCOPE_1_EMISSIONS_GREEN_`s'__R)
eststo green2: estpost ttest CAR_around, by(SCOPE_2_EMISSIONS_GREEN_`s'__R)
eststo non_financial_green: estpost ttest CAR_around, by(NON_FINANCIAL_GREEN__R)
esttab green1 non_financial_green using "${tables}/Tables/CAR_greenness_`s'.tex", mtitles("\multicolumn{1}{M}{Green firms vs brown firms \\ (wrt scope 1)}" "\multicolumn{1}{M}{Non-bank green \\ vs non-bank brown}") replace starlevels(* 0.10 ** 0.05 *** 0.01) ///
label nonumber 
*/

kdensity CAR_around if SCOPE_1_EMISSIONS_GREEN_`s'__R==1 & CREDIT==0, lc("211 78 79") plot(kdensity CAR_around if SCOPE_1_EMISSIONS_GREEN_`s'__R==0 & CREDIT==0, lc("116 192 116")) legend(label(1 "Brown firms") label(2 "Green firms") rows(1)) legend(on) title("") ytitle("")
graph export "${figures}/CAR_densities_`s'.png", replace as(png) width(2300) height(1500)
ksmirnov CAR_around  if CREDIT==0, by(SCOPE_1_EMISSIONS_GREEN_`s'__R    )

* Compute equivalent loss in Market value of equity:
gen MVE_lost_brown_`s' = ((CAR_around/100)*MVE_5_business_days_before_event)/(1e6) if SCOPE_1_EMISSIONS_GREEN_`s'__R ==1
gen MVE_lost_nfbrown_`s' = ((CAR_around/100)*MVE_5_business_days_before_event)/(1e6) if NON_FINANCIAL_GREEN__R ==1

*estpost tabstat MVE_lost_brown if SCOPE_1_EMISSIONS_GREEN_`s'__R ==1, statistics()
*esttab using "${tables}/Tables/CAR_MVElost_`s'.tex", noobs nonumber label  style(tex) replace

/*
gen GREEN_CSPP = (SCOPE_1_EMISSIONS_GREEN_`s'==1) * (IS_CSPP==1)
replace GREEN_CSPP = . if GREEN_CSPP ==0
replace GREEN_CSPP = 0 if (SCOPE_1_EMISSIONS_GREEN_`s'==0) * IS_CSPP

gen GREEN_CSPP_NO_CSPP = (SCOPE_1_EMISSIONS_GREEN_`s'==1) * (IS_CSPP==1)
replace GREEN_CSPP_NO_CSPP = . if GREEN_CSPP_NO_CSPP ==0
replace GREEN_CSPP_NO_CSPP = 0 if (SCOPE_1_EMISSIONS_GREEN_`s'==1) * (IS_CSPP==0)

foreach i in GREEN_CSPP GREEN_CSPP_NO_CSPP {
      gen `i'__R = (1-`i')
}

eststo green_cspp: estpost ttest CAR_around, by(GREEN_CSPP__R)
eststo green_cspp_no: estpost ttest CAR_around, by(GREEN_CSPP_NO_CSPP__R)

esttab green_cspp green_cspp_no using "${tables}/Tables/CAR_cspp_`s'.tex",  cells(b(star fmt(3) label("Coef.")) t(par fmt(3) label("t-stat"))) mtitles("\multicolumn{1}{M}{Green firms which have been or are in the CSPP \\ vs \\ Brown firms which have been or are in the CSPP}" "\multicolumn{1}{M}{Green firms which have been or are in the CSPP \\ vs Green firms that have never been in the CSPP}") replace starlevels(* 0.10 ** 0.05 *** 0.01) label nonumber

ttest CAR_around==0 if group==1
ttest CAR_around==0 if group==2
ttest CAR_around==0 if group==3
ttest CAR_around==0 if group==4
ttest CAR_around==0 if group==5

su group, meanonly
	
forval i = 1/`r(max)' {
	gen _`i'_green_g =.
	replace _`i'_green_g = 1 if (group==`i') & (SCOPE_1_EMISSIONS_GREEN_`s'==1)
	replace _`i'_green_g =. if _`i'_green_g ==0
	replace _`i'_green_g =0 if (SCOPE_1_EMISSIONS_BROWN_`s'==1) & (group==`i')
	

	label values _`i'_green_g greenl  
	
	eststo CAR_detailed_`i': quietly estpost tabstat ///
    CAR_around if group==`i', by(_`i'_green_g) ///
	statistics(mean sd) columns(statistics) listwise
	
    gen _`i'_green_g__R = (1-_`i'_green_g)
	
	eststo _`i'_ind : estpost ttest CAR_around, by(_`i'_green_g__R)
}

esttab *_ind using "${tables}/Tables/green_decile_by_industry_`s'.tex", replace starlevels(* 0.10 ** 0.05 *** 0.01) mtitles(" Industrials, Consumer products and services" "Consumer Services, Software \& services, Telecommunication and Media" "Energy, Utilities, Transportation, Materials" "Financials" "Healthcare") style(tex)

esttab CAR_detailed_* using "${tables}/Tables/CAR_detailed_`s'.tex", main(mean) aux(sd) nostar nonote nonumber mtitles("\multicolumn{1}{M}{Industrials, \\ Consumer products and services}" "\multicolumn{1}{M}{Consumer Services, Software \& services, \\ Telecommunication and Media}" "\multicolumn{1}{M}{Energy, Utilities, \\ Transportation, Materials}" "Financials" "Healthcare") replace style(tex)
*/
drop NON_FINANCIAL_GREEN* 
*GREEN_CSPP* GREEN_CSPP_NO_CSPP* *_green_g*
eststo clear
}

kdensity CAR_around if CSPPe_GB==1 & CREDIT==0, lc("116 192 116") plot(kdensity CAR_around if CSPPe_GB==0 & CREDIT==0, lc("211 78 79")) legend(label(1 "Has a CSPP-eligible GB") label(2 "No CSPP-eligible GB") rows(1)) legend(on) title("")
graph export "${figures}/CAR_densities_GB.png", replace as(png) width(2300) height(1500)

ksmirnov CAR_around  if CREDIT==0, by(CSPPe_GB    )

label variable MVE_lost_brown_F "Brown firms  wrt global emissions"
label variable MVE_lost_brown_4D "Brown firms  wrt sectoral emissions"
label variable MVE_lost_nfbrown_4D "Non-bank brown firms wrt sectoral emissions"
label variable MVE_lost_nfbrown_F "Non-bank brown firms wrt global emissions"

estpost sum MVE_lost_*, det
esttab using "${tables}/Tables/MVE_lost_summstats.tex", cells("mean(fmt(%5.0f)) sd(fmt(%5.0f)) min(fmt(%5.0f)) p5(fmt(%5.0f)) p50(fmt(%5.0f)) p95(fmt(%5.0f)) max(fmt(%5.0f)) count(fmt(%5.0f))") ///
noobs nonumber label  style(tex) replace ///
collabels("Mean" "Sd" "Min" "p5" "Median" "p95" "Max" "Obs.") wide

