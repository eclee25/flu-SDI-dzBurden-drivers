
## Name: Elizabeth Lee
## Date: 6/2/16
## Function: functions to perform EDA for variable selection at cty level
## Filenames: 
## Data Source: 
## Notes: 
## 
## useful commands:
## install.packages("pkg", dependencies=TRUE, lib="/usr/local/lib/R/site-library") # in sudo R
## update.packages(lib.loc = "/usr/local/lib/R/site-library")

require(dplyr); require(tidyr)


#### functions for data aggregation  ################################

prepare_allCov_iliSum_cty <- function(filepathList){
  # iliSum response, all sampling effort, and driver variables
  # y = response, E = expected response
  print(match.call())
  print(filepathList)
  
  #### import data ####
  # IMS Health based tables
  mod_cty_df <- cleanR_iliSum_cty(filepathList)
  imsCov_cty_df <- cleanO_imsCoverage_cty()
  # all county tables
  sahieIns_cty_df <- cleanO_sahieInsured_cty()
  saipePov_cty_df <- cleanX_saipePoverty_cty()
  saipeInc_cty_df <- cleanX_saipeIncome_cty()
  ahrfMcaid_cty_df <- cleanX_ahrfMedicaidEligibles_cty()
  ahrfMcare_cty_df <- cleanX_ahrfMedicareEligibles_cty()
  censusInfTodPop_cty_df <- cleanX_censusInfantToddlerPop_cty()
  censusChPop_cty_df <- cleanX_censusChildPop_cty()
  censusAdPop_cty_df <- cleanX_censusAdultPop_cty()
  censusEldPop_cty_df <- cleanX_censusElderlyPop_cty()
  ahrfHosp_cty_df <- cleanX_ahrfHospitals_cty()
  ahrfPhys_cty_df <- cleanX_ahrfPhysicians_cty()
  popDens_cty_df <- cleanX_popDensity_cty()
  housDens_cty_df <- cleanX_housDensity_cty()
  acsCommutInflows_cty_prep <- cleanX_acsCommutInflows_cty()
  btsPass_cty_df <- cleanX_btsPassInflows_cty()
  narrSpecHum_cty_df <- cleanX_noaanarrSpecHum_cty()
  narrSfcTemp_cty_df <- cleanX_noaanarrSfcTemp_cty()
  # all state tables 
  infantAnyVax_df <- cleanX_nisInfantAnyVaxCov_st()
  infantFullVax_df <- cleanX_nisInfantFullVaxCov_st()
  # all region tables
  cdcFluPos_df <- cleanX_cdcFluview_fluPos_region()
  cdcH3_df <- cleanX_cdcFluview_H3_region() %>% select(-region)
  
  #### join data ####
  dummy_df <- full_join(mod_cty_df, imsCov_cty_df, by = c("year", "fips"))
  dummy_df2 <- full_join(dummy_df, sahieIns_cty_df, by = c("year", "fips"))
  
  full_df <- full_join(dummy_df2, saipePov_cty_df, by = c("year", "fips")) %>%
    full_join(saipeInc_cty_df, by = c("year", "fips")) %>%
    full_join(ahrfMcaid_cty_df, by = c("year", "fips")) %>%
    full_join(ahrfMcare_cty_df, by = c("year", "fips")) %>%
    full_join(censusInfTodPop_cty_df, by = c("year", "fips")) %>%
    full_join(censusChPop_cty_df, by = c("year", "fips")) %>%
    full_join(censusAdPop_cty_df, by = c("year", "fips")) %>%
    full_join(censusEldPop_cty_df, by = c("year", "fips")) %>%
    full_join(ahrfHosp_cty_df, by = c("year", "fips")) %>%
    full_join(ahrfPhys_cty_df, by = c("year", "fips")) %>%
    full_join(popDens_cty_df, by = c("year", "fips")) %>%
    full_join(housDens_cty_df, by = c("year", "fips")) %>%
    full_join(acsCommutInflows_cty_prep, by = c("year", "fips" = "fips_wrk")) %>%
    full_join(btsPass_cty_df, by = c("season", "fips" = "fips_dest")) %>%
    mutate(fips_st = substring(fips, 1, 2)) %>% # region is linked by state fips code
    full_join(cdcFluPos_df, by = c("season", "fips_st" = "fips")) %>%
    full_join(cdcH3_df, by = c("season", "fips_st" = "fips")) %>%
    full_join(narrSpecHum_cty_df, by = c("season", "fips")) %>%
    full_join(narrSfcTemp_cty_df, by = c("season", "fips")) %>%
    group_by(season) %>%
    mutate(O_imscoverage = centerStandardize(adjProviderCoverage)) %>%
    mutate(O_careseek = centerStandardize(visitsPerProvider)) %>%
    mutate(O_insured = centerStandardize(insured)) %>%
    mutate(X_poverty = centerStandardize(poverty)) %>%
    mutate(X_income = centerStandardize(income)) %>%
    mutate(X_mcaid = centerStandardize(mcaidElig)) %>%
    mutate(X_mcare = centerStandardize(mcareElig)) %>%
    mutate(X_infantToddler = centerStandardize(infantToddler)) %>%
    mutate(X_child = centerStandardize(child)) %>%
    mutate(X_adult = centerStandardize(adult)) %>%
    mutate(X_elderly = centerStandardize(elderly)) %>%
    mutate(X_hospaccess = centerStandardize(hospitalAccess)) %>% 
    mutate(X_physaccess = centerStandardize(physicianAccess)) %>%
    mutate(X_popdensity = centerStandardize(popDensity)) %>%
    mutate(X_housdensity = centerStandardize(housDensity)) %>%
    mutate(X_commute = centerStandardize(commutInflows_prep)) %>% # commutInflows_prep/pop and commutInflows_prep raw look similar in EDA choropleths
    mutate(X_flight = centerStandardize(pass)) %>%
    mutate(X_fluPos = centerStandardize(fluPos)) %>%
    mutate(X_H3 = centerStandardize(H3)) %>%
    mutate(X_humidity = centerStandardize(humidity)) %>%
    mutate(X_temperature = centerStandardize(temperature)) %>%
    ungroup %>%
    select(-fips_st, -adjProviderCoverage, -visitsPerProvider, -insured, -poverty, -income, -mcaidElig, -mcareElig, -infantToddler, -child, -adult, -elderly, -hospitalAccess, -physicianAccess, -popDensity, -housDensity, -commutInflows_prep, -pass, -fluPos, -H3, -humidity, -temperature) %>%
    filter(season %in% 2:9)
  
  return(full_df)
}
################################



#### test the functions here  ################################

# test <- model_singleVariable_inla_st(allDat2, "iliSum", 2, "X_poverty")