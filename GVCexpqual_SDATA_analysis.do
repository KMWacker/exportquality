clear
global path "C:\Users\xxx"      /* adjust path to local system (and create "Analysis" subfolder -- see line 66 below */
cd $path

* INSHEET EUKLEMS DATA (directly from web)
use "https://www.dropbox.com/s/78sucgpgnh5amju/national%20accounts.dta?dl=1"

* MAKE GEO_NAME CONSISTENT WITH DEXQC FILE
gen new_geo_code = geo_code
replace new_geo_code = "AUT" if geo_code == "AT"
replace new_geo_code = "BEL" if geo_code == "BE"
replace new_geo_code = "BGR" if geo_code == "BG"
replace new_geo_code = "CYP" if geo_code == "CY"
replace new_geo_code = "CZE" if geo_code == "CZ"
replace new_geo_code = "DEU" if geo_code == "DE"
replace new_geo_code = "DNK" if geo_code == "DK"
replace new_geo_code = "GRC" if geo_code == "EL"
replace new_geo_code = "ESP" if geo_code == "ES"
replace new_geo_code = "FIN" if geo_code == "FI"
replace new_geo_code = "FRA" if geo_code == "FR"
replace new_geo_code = "HRV" if geo_code == "HR"
replace new_geo_code = "HUN" if geo_code == "HU"
replace new_geo_code = "IRL" if geo_code == "IE"
replace new_geo_code = "ITA" if geo_code == "IT"
replace new_geo_code = "LTU" if geo_code == "LT"
replace new_geo_code = "LUX" if geo_code == "LU"
replace new_geo_code = "LVA" if geo_code == "LV"
replace new_geo_code = "MLT" if geo_code == "MT"
replace new_geo_code = "NLD" if geo_code == "NL"
replace new_geo_code = "POL" if geo_code == "PL"
replace new_geo_code = "PRT" if geo_code == "PT"
replace new_geo_code = "ROU" if geo_code == "RO"
replace new_geo_code = "SWE" if geo_code == "SE"
replace new_geo_code = "SVN" if geo_code == "SI"
replace new_geo_code = "SVK" if geo_code == "SK"
replace new_geo_code = "GBR" if geo_code == "UK"
replace new_geo_code = "USA" if geo_code == "US"

* MAKE NACE CODES CONSISTENT WITH DEXQC.csv FILE
gen nace2_name = ""
replace nace2_name = "Basic metals" if strpos(nace_r2_name, "Manufacture of basic metals")
replace nace2_name = "Medicine" if strpos(nace_r2_name, "Manufacture of basic pharma")
replace nace2_name = "Chemicals" if strpos(nace_r2_name, "Manufacture of chemicals")
replace nace2_name = "Oil" if strpos(nace_r2_name, "Manufacture of coke and refined petro")
replace nace2_name = "Computer" if strpos(nace_r2_name, "Manufacture of computer, electronic")
replace nace2_name = "Electrical equipment" if strpos(nace_r2_name, "Manufacture of electrical equipment")
replace nace2_name = "Food, beverages, tobacco" if strpos(nace_r2_name, "Manufacture of food")
replace nace2_name = "Machinery" if strpos(nace_r2_name, "Manufacture of machinery and equip")
replace nace2_name = "Motor vehicles" if strpos(nace_r2_name, "Manufacture of motor vehicles,")
replace nace2_name = "Rubber and plastic" if strpos(nace_r2_name, "Manufacture of rubber and plastic")
replace nace2_name = "Textiles" if strpos(nace_r2_name, "Manufacture of textiles,")

gen sector_key = 0		/* to identify manufacturing sectors that can consistently be matched */
replace sector_key = 1 if nace2_name=="Medicine" | nace2_name=="Chemicals" | nace2_name=="Computer" | nace2_name=="Electrical equipment" | nace2_name=="Food, beverages, tobacco" | nace2_name=="Machinery" | nace2_name=="Motor vehicles" | nace2_name=="Textiles"

* LIMIT DATA TO RELEVANT PART
keep if year >= 2015 & year < 2020
drop if new_geo_code == geo_code
drop if nace2_name == ""

* TEMPORARY SAVE and MERGE WITH DEXQC
sort year new_geo_code nace2_name, stable
compress
save "temp_klems.dta", replace

insheet using "Data\DEXQCestimates\DEXQC.csv", clear    /* .csv file is available in Fighare repository: https://doi.org/10.6084/m9.figshare.27142644 */
rename i new_geo_code
rename k nace2_name
sort year new_geo_code nace2_name, stable

merge year new_geo_code nace2_name using "temp_klems.dta"
drop if _merge==1 	/* everything from using data merged */
rm "temp_klems.dta"

* SET PANEL
gen panel_descr = new_geo_code + "_" + nace2_name
encode panel_descr, gen(panel_id)
drop panel_descr

xtset panel_id year

* GENERATE CHANGES and averages
gen d_lnVApc = (ln(VA_CP/EMPE) - ln(L4.VA_CP/L4.EMPE))/4 if year==2019

bys panel_id: egen avgDEXQC = mean(dexqc)
bys panel_id: egen avgXQ = mean(xq)

* REGRESSIONS
areg d_lnVA avg* if sector_key==1, absorb(new_geo) rob
estimates store va_model, title(Model 1)

tab new_geo if e(sample)
tab nace2_name if e(sample)

* OUTPUT
estout va_model, cells(b(star fmt(3)) se(par fmt(2))) stats(r2 N) legend starlevels(* 0.1 ** 0.05 *** 0.01)
