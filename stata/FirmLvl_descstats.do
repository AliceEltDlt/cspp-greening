/*
================================================================================
  FirmLvl_descstats.do
  Summary statistics and correlation matrix at the firm level.

  Inputs  : ${data}/firm_level_data.csv
  Outputs : ${tables}/desc_firm_level.tex
            ${tables}/correlation_matrix.tex
            ${tables}/desc_ei_by_sec.tex

  Run after: data construction (Python notebooks)
================================================================================
*/

// ── Path globals ─────────────────────────────────────────────────────────────
// Set these once here; all cd commands below use these globals.
// Override from the command line with: stata-mp -b do main.do [data_path] [output_path]
if "${data}" == "" global data    "data/clean"
if "${tables}" == "" global tables  "output/tables"
if "${figures}" == "" global figures "output/figures"
// ─────────────────────────────────────────────────────────────────────────────

cd "${data}"

import delimited "${data}/firm_level_data.csv", clear

cd "${tables}"
eststo clear

label var size "\multicolumn{1}{C{2.5cm}}{Size          }"
label var leverage "\multicolumn{1}{C{2.5cm}}{Leverage}"
label var sales "\multicolumn{1}{C{2.5cm}}{Sales}"

gen issued_eur_green_bond_binary = (issued_eur_green_bond=="True")
label var issued_eur_green_bond_binary "Issued EUR denominated green bond"
gen green_bond_issuer_binary = (green_bond_issuer=="True")
label var green_bond_issuer_binary "\multicolumn{1}{C{2.5cm}}{Green bond issuer}"

label var scope_1_emissions "\multicolumn{1}{C{2.5cm}}{Scope 1 Emissions}"
label var scope_2_emissions "\multicolumn{1}{C{2.5cm}}{Scope 2 Emissions}"
label var scope_1_intensity "\multicolumn{1}{C{2.5cm}}{Scope 1 Intensity}"
label var scope_2_intensity "\multicolumn{1}{C{2.5cm}}{Scope 2 Intensity}"

label var scope_1_emissions_rk "\multicolumn{1}{c}{Scope 1 Emissions Rank \\ (global)}"
label var scope_2_emissions_rk "\multicolumn{1}{c}{Scope 2 Emissions Rank \\ (global)}"
label var scope_1_intensity_rk "\multicolumn{1}{c}{Scope 1 Intensity Rank \\ (global)}"
label var scope_2_intensity_rk "\multicolumn{1}{c}{Scope 2 Intensity Rank \\ (global)}"

label var scope_1_emissions_rk2d "\multicolumn{1}{c}{Scope 1 Emissions Rank \\ (2d)}"
label var scope_2_emissions_rk2d "\multicolumn{1}{c}{Scope 2 Emissions Rank \\ (2d)}"
label var scope_1_intensity_rk2d "\multicolumn{1}{c}{Scope 1 Intensity Rank \\ (2d)}"
label var scope_2_intensity_rk2d "\multicolumn{1}{c}{Scope 2 Intensity Rank \\ (2d)}"

label var scope_1_emissions_rk4d "\multicolumn{1}{c}{Scope 1 Emissions Rank \\ (4d)}"
label var scope_2_emissions_rk4d "\multicolumn{1}{c}{Scope 2 Emissions Rank \\ (4d)}"
label var scope_1_intensity_rk4d "\multicolumn{1}{c}{Scope 1 Intensity Rank \\ (4d)}"
label var scope_2_intensity_rk4d "\multicolumn{1}{c}{Scope 2 Intensity Rank \\ (4d)}"

label var scope_1_emissions_green_f "\multicolumn{1}{C{2.5cm}}{Green firm wrt global scope 1 emissions}"
label var scope_1_emissions_brown_f "\multicolumn{1}{C{2.5cm}}{Brown firm wrt  global scope 1 emissions}"
label var scope_1_emissions_green_4d "\multicolumn{1}{C{2.5cm}}{Green firm wrt (4d)-sectoral scope 1 emissions}"
label var scope_1_emissions_brown_4d "\multicolumn{1}{C{2.5cm}}{Brown firm wrt (4d)-sectoral scope 1 emissions}"

estpost sum size leverage sales /// 
scope_1_emissions scope_2_emissions scope_1_intensity scope_2_intensity, ///
det
esttab using "${tables}/desc_firm_level.tex", cells("mean(fmt(%5.3f)) sd(fmt(%5.3f)) min(fmt(%5.3f)) p5(fmt(%5.3f)) p50(fmt(%5.3f)) p95(fmt(%5.3f)) max(fmt(%5.3f)) count(fmt(%5.0f))") ///
noobs nonumber label  style(tex) replace ///
collabels("Mean" "Sd" "Min" "p5" "Median" "p95" "Max" "Obs.") wide

estpost correlate green_bond_issuer_binary size scope_1_emissions /// 
scope_1_intensity scope_1_emissions_green_f scope_1_emissions_brown_f /// 
scope_1_emissions_green_4d scope_1_emissions_brown_4d, matrix
esttab . using "${tables}/correlation_matrix.tex", not unstack compress noobs label /// 
style(tex) replace star(* 0.10 ** 0.05 *** 0.01)  nonumber

eststo desc_ei_by_sec: quietly estpost tabstat scope_1_emissions ///
 scope_1_intensity, by(gics_4d) statistics(mean sd) columns(statistics) listwise 
 
esttab desc_ei_by_sec using "${tables}/desc_ei_by_sec.tex", main(mean) aux(sd) nostar nonote nonumber replace style(tex)