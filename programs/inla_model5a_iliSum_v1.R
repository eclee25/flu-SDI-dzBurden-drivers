
## Name: Elizabeth Lee
## Date: 6/6/16
## Function: Model 5a, v1-1 covariate & sampling effort model -- after variable selection
## v1-1: One model per season, see variables selected in 'Drivers' spreadsheet
## Filenames: physicianCoverage_IMSHealth_state.csv, dbMetrics_periodicReg_ilinDt_Octfit_span0.4_degree2_analyzeDB_st.csv
## Data Source: IMS Health
## Notes: 
# 9/15/16: try new inla settings after mod 6a debug and switch to time series downscaling procedure
## 
## useful commands:
## install.packages("pkg", dependencies=TRUE, lib="/usr/local/lib/R/site-library") # in sudo R
## update.packages(lib.loc = "/usr/local/lib/R/site-library")

#### header #################################
rm(list = ls())
require(dplyr); require(tidyr); require(readr); require(DBI); require(RMySQL) # clean_data_functions dependencies
require(maptools); require(spdep) # prepare_inlaData_st.R dependencies
require(INLA) # main dependencies
require(RColorBrewer); require(ggplot2) # export_inlaData_st dependencies


#### set these! ################################
dbCodeStr <- "_ilinDt_Octfit_span0.4_degree2"
modCodeStr <- "5a_iliSum_v1-6"; testDataOn <- FALSE
seasons <- 2:9
rdmFx_RV <- "nu"
inverseLink <- function(x){exp(x)}
dig <- 4 # number of digits in the number of elements at this spatial scale (~3000 counties -> 4 digits)

#### SOURCE: clean and import model data #################################
setwd(dirname(sys.frame(1)$ofile))
source("source_clean_response_functions_cty.R") # functions to clean response and IMS coverage data (cty)
source("source_clean_data_functions.R") # functions to clean covariate data
source("source_prepare_inlaData_cty.R") # functions to aggregate all data sources for model
source("source_export_inlaData_cty.R") # functions to plot county-specific model diagnostics
source("source_export_inlaData.R") # functions to plot general model diagnostics

#### FILEPATHS #################################
setwd('../reference_data')
path_abbr_st <- paste0(getwd(), "/state_abbreviations_FIPS.csv")
path_latlon_cty <- paste0(getwd(), "/cty_pop_latlon.csv")

setwd('./UScounty_shapefiles')
path_shape_cty <- paste0(getwd(), "/gz_2010_us_050_00_500k")
path_adjMxExport_cty <- paste0(getwd(), "/US_county_adjacency.graph")

setwd("../../R_export")
path_response_cty <- paste0(getwd(), sprintf("/dbMetrics_periodicReg%s_analyzeDB_cty.csv", dbCodeStr))

# put all paths in a list to pass them around in functions
path_list <- list(path_abbr_st = path_abbr_st,
                  path_latlon_cty = path_latlon_cty,
                  path_shape_cty = path_shape_cty,
                  path_adjMxExport_cty = path_adjMxExport_cty,
                  path_response_cty = path_response_cty)


#### MAIN #################################
#### test data module ####
if (testDataOn){
  modData <- testing_module(path_list) # with driver & sampling effort variables
  # testing module formula
  formula <- y ~ 1 + f(ID, model = "iid") + f(stateID, model = "iid") + f(regionID, model = "iid") + O_imscoverage + O_careseek + X_poverty + X_H3 + offset(logE)
} else{
#### Import and process data ####
  modData <- model5a_iliSum_v1(path_list) # with driver & sampling effort variables
  #### Model 5a v1: County-level, after variable selection, one model per season ####
  formula <- y ~ 1 + f(fips, model = "iid") + f(fips_st, model = "iid") + f(regionID, model = "iid") + O_imscoverage + O_careseek + O_insured + X_poverty + X_child + X_adult + X_hospaccess + X_popdensity + X_commute + X_flight + X_vaxcovI + X_vaxcovE + X_H3 + X_humidity + offset(logE)
}


#### export formatting ####
# diagnostic plot export directories
setwd(dirname(sys.frame(1)$ofile))
dir.create(sprintf("../graph_outputs/inlaModelDiagnostics/%s", modCodeStr), showWarnings = FALSE)
setwd(sprintf("../graph_outputs/inlaModelDiagnostics/%s", modCodeStr))
path_plotExport <- getwd()

# diagnostic plot formatting
labVec <- paste("Tier", 1:5)
colVec <- brewer.pal(length(labVec), 'RdYlGn')

# csv file export directories
setwd(dirname(sys.frame(1)$ofile))
dir.create(sprintf("../R_export/inlaModelData_export/%s", modCodeStr), showWarnings = FALSE)
setwd(sprintf("../R_export/inlaModelData_export/%s", modCodeStr))
path_csvExport <- getwd()

#### run models by season ################################
for (s in seasons){
  modData_full <- modData %>% filter(season == s) %>% mutate(ID = seq_along(fips))
  starting1 <- inla(formula, family = "gaussian", data = modData_full, 
              control.family = list(link = "log"),
              control.fixed = list(mean = 0, prec = 1, mean.intercept = 0, prec.intercept = 1), # set prior parameters for regression coefficients and intercepts
              control.predictor = list(compute = TRUE), # compute summary statistics on fitted values
              control.compute = list(dic = TRUE, cpo = TRUE),
              control.inla = list(correct = TRUE, correct.factor = 10, diagonal = 1000, strategy = "gaussian", int.strategy = "eb"),
              verbose = TRUE)
  mod <- inla(formula, family = "gaussian", data = modData_full, 
                    control.family = list(link = "log"),
                    control.fixed = list(mean = 0, prec = 1, mean.intercept = 0, prec.intercept = 1), # set prior parameters for regression coefficients and intercepts
                    control.predictor = list(compute = TRUE), # compute summary statistics on fitted values
                    control.compute = list(dic = TRUE, cpo = TRUE),
                    control.inla = list(correct = TRUE, correct.factor = 10, diagonal = 0, tolerance = 1e-6),
                    control.mode = list(result = starting1, restart = TRUE),
                    verbose = TRUE,
                    keep = TRUE, debug = TRUE)

  #### model summary outputs ################################
  # 9/15/16 reorganized like inla_model6a_iliSum_v1
  
  #### write DIC and CPO values in separate tables by season ####
  # file path 
  path_csvExport_dic <- paste0(path_csvExport, sprintf("/modFit_%s_S%s.csv", modCodeStr, s))
  # DIC & CPO file formatting
  dicData <- tbl_df(data.frame(modCodeStr = c(), season = c(), exportDate = c(), DIC = c(), CPO = c(), cpoFail = c()))
  dicData <- bind_rows(dicData, list(modCodeStr = modCodeStr, season = s, exportDate = as.character(Sys.Date()), DIC = mod$dic$dic, CPO = sum(log(mod$cpo$cpo), na.rm=TRUE), cpoFail = sum(mod$cpo$failure, na.rm=TRUE)))
  # write DIC & CPO to file
  export_DIC(path_csvExport_dic, dicData)
  
  #### write random and group effect identities ####
  # file path
  path_csvExport_ids <- paste0(path_csvExport, sprintf("/ids_%s_S%s.csv", modCodeStr, s))
  # write identity codes to file
  export_ids(path_csvExport_ids, modData_full)
  
  #### write fixed and random effects summary statistics ####
  # file path
  path_csvExport_summaryStats <- paste0(path_csvExport, sprintf("/summaryStats_%s_S%s.csv", modCodeStr, s))
  # write all summary statistics to file 
  # 8/17/16 control flow to export summary statistics of hyperparameters
  # 9/15/16 no export_summaryStats version without hyperpar
  export_summaryStats(path_csvExport_summaryStats, mod, rdmFx_RV, modCodeStr, dbCodeStr, s) # assuming hyperpar, fixed, spatial, state ID, and region ID exist

  #### process fitted values for each model ################################
  path_csvExport_summaryStatsFitted <- paste0(path_csvExport, sprintf("/summaryStatsFitted_%s_S%s.csv", modCodeStr, s))
  mod_fitted <- export_summaryStats_fitted(path_csvExport_summaryStatsFitted, mod, modData_full, modCodeStr, dbCodeStr, s)
  
  #### Diagnostic plots ################################
  path_plotExport_rdmFxSample <- paste0(path_plotExport, sprintf("/inla_%s_%s1-6_marg_S%s.png", modCodeStr, rdmFx_RV, s))
  plot_rdmFx_marginalsSample(path_plotExport_rdmFxSample, mod$marginals.random$fips, rdmFx_RV)
  
  #### figures (agnostic to likelihood) ####
  # marginal posteriors: fixed effects
  path_plotExport_fixedFxMarginals <- paste0(path_plotExport)
  plot_fixedFx_marginals(path_plotExport_fixedFxMarginals, mod$marginals.fixed, modCodeStr, s)
  
  # observations (y_i)  
  path_plotExport_obsY <- paste0(path_plotExport, sprintf("/choro_obsY_%s_S%s.png", modCodeStr, s))
  plot_countyChoro(path_plotExport_obsY, modData_full, "y", "tier", TRUE)
  
}

# #### export model data ###
# setwd(dirname(sys.frame(1)$ofile))
# write_csv(modData_full, "testmethod_inlaData_model3b_v1.csv")