
## Name: Elizabeth Lee
## Date: 12/17/16
## Function: Model 9a v3, one-season model, shift1 iliSum, child population, no spatial dependence term
## 
## Filenames: physicianCoverage_IMSHealth_state.csv, dbMetrics_periodicReg_ilinDt_Octfit_span0.4_degree2_analyzeDB_st.csv
## Data Source: IMS Health
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
dbCodeStr <- "_ilinDt_Octfit_child_span0.4_degree2"
modCodeStr <- "9a_iliSum_v3-2"
seasons <- 3:9
rdmFx_RV <- "nu"
likString <- "normal"
dig <- 4 # number of digits in the number of elements at this spatial scale (~3000 counties -> 4 digits)

#### SOURCE: clean and import model data #################################
setwd(dirname(sys.frame(1)$ofile))
source("source_clean_response_functions_cty.R") # functions to clean response and IMS coverage data (cty)
source("source_clean_data_functions.R") # functions to clean covariate data
source("source_prepare_inlaData_cty.R") # functions to aggregate all data sources for model
source("source_export_inlaData_cty.R") # functions to plot county-specific model diagnostics
source("source_export_inlaData.R") # functions to plot general model diagnostics
source("source_export_inlaData_hurdle.R") # data export functions for hurdle model

#### FILEPATHS #################################
setwd('../reference_data')
path_abbr_st <- paste0(getwd(), "/state_abbreviations_FIPS.csv")
path_latlon_cty <- paste0(getwd(), "/cty_pop_latlon.csv")

setwd('./UScounty_shapefiles')
path_adjMxExport_cty <- paste0(getwd(), "/US_county_adjacency.graph")
path_graphIdx_cty <- paste0(getwd(), "/US_county_graph_index.csv")
path_shape_cty <- paste0(getwd(), "/gz_2010_us_050_00_500k") # for dbf metadata only

setwd("../../R_export")
path_response_cty <- paste0(getwd(), sprintf("/dbMetrics_periodicReg%s_analyzeDB_cty.csv", dbCodeStr))

# put all paths in a list to pass them around in functions
path_list <- list(path_abbr_st = path_abbr_st,
                  path_latlon_cty = path_latlon_cty,
                  path_shape_cty = path_shape_cty,
                  path_adjMxExport_cty = path_adjMxExport_cty,
                  path_response_cty = path_response_cty, 
                  path_graphIdx_cty = path_graphIdx_cty)


#### MAIN #################################
#### Import and process data ####
modData <- model9a_iliSum_v3(path_list) 
#%>%
# remove_randomObs_stratifySeas(0.4)

formula <- Y ~ -1 + 
  f(ID_nonzero, model = "iid") +
  f(fips_nonzero, model = "iid") + 
  f(graphIdx_nonzero, model = "besag", graph = path_adjMxExport_cty) +
  f(fips_st_nonzero, model = "iid") + 
  f(regionID_nonzero, model = "iid") + 
  intercept_nonzero + O_imscoverage_nonzero + O_careseek_nonzero + O_insured_nonzero + O_imscoverage_nonzero*O_careseek_nonzero + X_poverty_nonzero + X_adult_nonzero + X_hospaccess_nonzero + X_popdensity_nonzero + X_housdensity_nonzero + X_vaxcovI_nonzero + X_vaxcovE_nonzero + X_H3A_nonzero + X_B_nonzero + X_priorImmunity_nonzero + X_humidity_nonzero + X_pollution_nonzero + X_singlePersonHH_nonzero + X_H3A_nonzero*X_adult_nonzero + offset(logE_nonzero)

 

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

# dic dataframe
dicData <- rep(NA, length(seasons)*6)

#### run models by season ################################
for (i in 1:length(seasons)){
  s <- seasons[i]
  modData_full <- modData %>% filter(season == s) 
  modData_hurdle <- convert_hurdleModel_nz_spatiotemporal(modData_full)
  
  starting3 <- inla(formula, 
                    family = "gaussian", 
                    data = modData_hurdle, 
                    control.fixed = list(mean = 0, prec = 1/100), # set prior parameters for regression coefficients
                    control.predictor = list(compute = TRUE, link = rep(1, nrow(modData_full))), 
                    control.inla = list(correct = TRUE, correct.factor = 10, diagonal = 10, strategy = "gaussian", int.strategy = "eb"), # http://www.r-inla.org/events/newfeaturesinr-inlaapril2015; http://www.r-inla.org/?place=msg%2Fr-inla-discussion-group%2Fuf2ZGh4jmWc%2FA0rdPE5W7uMJ
                    verbose = TRUE)
  
  starting4 <- inla(formula, 
                    family = "gaussian", 
                    data = modData_hurdle, 
                    control.fixed = list(mean = 0, prec = 1/100), # set prior parameters for regression coefficients
                    control.predictor = list(compute = TRUE, link = rep(1, nrow(modData_full))), # compute summary statistics on fitted values, link designates that NA responses are calculated according to the first likelihood for the first (nrow(modData_full)) rows & the second likelihood for the second (nrow(modData_full)) rows
                    control.inla = list(correct = TRUE, correct.factor = 10, diagonal = 1, strategy = "gaussian", int.strategy = "eb"), # http://www.r-inla.org/events/newfeaturesinr-inlaapril2015; http://www.r-inla.org/?place=msg%2Fr-inla-discussion-group%2Fuf2ZGh4jmWc%2FA0rdPE5W7uMJ
                    control.mode = list(result = starting3, restart = TRUE),
                    verbose = TRUE)
  
  mod <- inla(formula, 
              family = "gaussian", 
              data = modData_hurdle, 
              # control.family = list(link="identity"), 
              control.fixed = list(mean = 0, prec = 1/100), # set prior parameters for regression coefficients
              control.predictor = list(compute = TRUE, link = rep(1, nrow(modData_full))), # compute summary statistics on fitted values, link designates that NA responses are calculated according to the first likelihood
              control.compute = list(dic = TRUE, cpo = TRUE),
              control.inla = list(correct = TRUE, correct.factor = 10, diagonal = 0, tolerance = 1e-6),
              control.mode = list(result = starting4, restart = TRUE),
              verbose = TRUE,
              keep = TRUE, debug = TRUE) 
  
  #### model summary outputs ################################
  # 7/20/16 reorganized
  
  #### clean DIC and CPO values ####
  dicData[((i*6)-5):(i*6)] <- unlist(c(modCodeStr, s, as.character(Sys.Date()), mod$dic$dic, sum(log(mod$cpo$cpo), na.rm=TRUE), sum(mod$cpo$failure, na.rm=TRUE), use.names=FALSE))
  
  
  #### write random and group effect identities ####
  # file path
  path_csvExport_ids <- paste0(path_csvExport, sprintf("/ids_%s_S%s.csv", modCodeStr, s))
  # write identity codes to file
  export_ids(path_csvExport_ids, modData_full)
  
  
  #### write fixed and random effects summary statistics ####
  # file path
  path_csvExport_summaryStats <- paste0(path_csvExport, sprintf("/summaryStats_%s_S%s.csv", modCodeStr, s))
  # write all summary statistics to file
  export_summaryStats_hurdle_likString(path_csvExport_summaryStats, mod, rdmFx_RV, modCodeStr, dbCodeStr, s, likString) # assuming hyperpar, fixed always exist
  
  
  #### process fitted values for each model ################################
  # gamma model processing
  path_csvExport_fittedNonzero <- paste0(path_csvExport, sprintf("/summaryStatsFitted_%s_%s_S%s.csv", likString, modCodeStr, s))
  dummy_nz <- mod$summary.fitted.values[1:nrow(modData_full),]
  mod_nz_fitted <- export_summaryStats_fitted_hurdle(path_csvExport_fittedNonzero, dummy_nz, modData_full, modCodeStr, dbCodeStr, s)


  #### Diagnostic plots ################################
 
  #### gamma likelihood figures ####
  # marginal posteriors: first 6 random effects (nu or phi)
  if (!is.null(mod$marginals.random$fips_nonzero)){
    # marginal posteriors: first 6 random effects (nu or phi)
    path_plotExport_rdmFxSample_nonzero <- paste0(path_plotExport, sprintf("/inla_%s_%s1-6_marg_%s_S%s.png", modCodeStr, rdmFx_RV, likString, s))
    plot_rdmFx_marginalsSample(path_plotExport_rdmFxSample_nonzero, mod$marginals.random$fips_nonzero, rdmFx_RV)
  }


}

#### write DIC for all years to file #### 
path_csvExport_dic <- paste0(path_csvExport, sprintf("/modFit_%s.csv", modCodeStr))
dicData2 <- as.data.frame(matrix(dicData, nrow = length(seasons), byrow = TRUE))
names(dicData2) <- c("modCodeStr", "season", "exportDate", "DIC", "CPO", "cpoFail")

# write DIC & CPO to file
export_DIC(path_csvExport_dic, dicData2) 

