
## Name: Elizabeth Lee
## Date: 3/10/16
## Function: Model 3f covariate & sampling effort model
## Filenames: physicianCoverage_IMSHealth_state.csv, dbMetrics_periodicReg_ilinDt_Octfit_span0.4_degree2_analyzeDB_st.csv
## Data Source: IMS Health
## Notes: need to SSH into snow server
##        - v2: rm random effect
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
modCodeStr <- "3f_iliSum_v2"
seasons <- 2:9


#### SOURCE: clean and import model data #################################
setwd(dirname(sys.frame(1)$ofile))
source("source_clean_data_functions.R") # functions to clean original data sources
source("source_prepare_inlaData_st.R") # functions to aggregate all data sources for model
source("source_export_inlaData_st.R") # functions to export data and plots related to model


#### FILEPATHS #################################
setwd('../reference_data')
path_pop_st <- paste0(getwd(), "/pop_st_Census_00-10.csv")
path_abbr_st <- paste0(getwd(), "/state_abbreviations_FIPS.csv")
path_latlon_st <- paste0(getwd(), "/state_latlon.csv")

setwd('./USstate_shapefiles')
path_shape_st <- paste0(getwd(), "/gz_2010_us_040_00_500k")
path_adjMxExport_st <- paste0(getwd(), "/US_state_adjacency.graph")

setwd("../../R_export")
path_response_st <- paste0(getwd(), sprintf("/dbMetrics_periodicReg%s_analyzeDB_st.csv", dbCodeStr))
path_imsCov_st <- paste0(getwd(), "/physicianCoverage_IMSHealth_state.csv")

# put all paths in a list to pass them around in functions
path_list <- list(path_pop_st = path_pop_st,
                  path_abbr_st = path_abbr_st,
                  path_latlon_st = path_latlon_st,
                  path_shape_st = path_shape_st,
                  path_adjMxExport_st = path_adjMxExport_st,
                  path_response_st = path_response_st, 
                  path_imsCov_st = path_imsCov_st)


#### MAIN #################################
#### Import and process data ####
modData <- model3f_iliSum_v1(path_list) # with driver & sampling effort variables


#### INLA modeling ################################
# Model 3f: Covariates, sampling effort
# Covariates, sampling effort
formula <- logy ~ -1 + I(O_imscoverage) + I(O_careseek) + I(O_insured) + I(X_poverty)


#### export formatting ####
# diagnostic plot export directories
setwd(dirname(sys.frame(1)$ofile))
dir.create(sprintf("../graph_outputs/inlaModelDiagnostics/%s", modCodeStr), showWarnings = FALSE)
# diagnostic plot formatting
labVec <- paste("Tier", 1:5)
colVec <- brewer.pal(length(labVec), 'RdYlGn')
# csv file export directories
setwd(dirname(sys.frame(1)$ofile))
dir.create(sprintf("../R_export/inlaModelData_export/%s", modCodeStr), showWarnings = FALSE)
setwd(sprintf("../R_export/inlaModelData_export/%s", modCodeStr))
# csv file formatting
dicData <- tbl_df(data.frame(modCodeStr = c(), season = c(), exportDate = c(), DIC = c()))
path_csvExport_dic <- paste0(getwd(), sprintf("/dic_%s.csv", modCodeStr))


#### run models by season ####
for (s in seasons){
  modData_full <- combine_shapefile_modelData_st(path_list, modData, s)
  mod <- inla(formula, family = "gaussian", data = modData_full, 
              control.predictor = list(compute = TRUE), # compute summary statistics on fitted values
              control.compute = list(dic = TRUE),
              verbose = TRUE,
              offset = logE) # offset (log link with Gaussian)
 
  #### save DIC values ####
  dicData <- bind_rows(dicData, list(modCodeStr = modCodeStr, season = s, exportDate= as.character(Sys.Date()), DIC = mod$dic$dic))
  
  #### assign seasonal paths ####
  setwd(dirname(sys.frame(1)$ofile))
  setwd(sprintf("../graph_outputs/inlaModelDiagnostics/%s", modCodeStr))
  path_plotExport_fixedFxMarginals <- paste0(getwd())
  path_plotExport_yhat_st <- paste0(getwd(), sprintf("/choro_fitY_%s_S%s.png", modCodeStr, s))
  path_plotExport_obsY_st <- paste0(getwd(), sprintf("/choro_obsY_%s_S%s.png", modCodeStr, s))
  path_plotExport_predDBRatio_st <- paste0(getwd(), sprintf("/choro_dbRatio_%s_S%s.png", modCodeStr, s))
  
  setwd(dirname(sys.frame(1)$ofile))
  setwd(sprintf("../R_export/inlaModelData_export/%s", modCodeStr))
  path_csvExport_summaryStatsFitted <- paste0(getwd(), sprintf("/summaryStatsFitted_%s_S%s.csv", modCodeStr, s))
  
  #### process plot data ####
  # write csv of summary statistics for fitted values
  fittedDat <- export_summaryStats_fitted(path_csvExport_summaryStatsFitted, mod) %>%
    select(ID, mean, sd, mode) %>% 
    mutate(ID = as.numeric(substring(ID, 5, nchar(ID)))) %>%
    mutate(mean = exp(mean), sd = exp(sd), mode = exp(mode)) %>%
    rename(yhat_mn = mean, yhat_sd = sd, yhat_mode = mode)
  
  plotDat <- left_join(modData_full, fittedDat, by = "ID") %>%
    mutate(yhat_bin = cut(yhat_mode, breaks = quantile(yhat_mode, probs = seq(0, 1, by = 1/3), na.rm=T), ordered_result = TRUE, include.lowest = TRUE)) %>%
    mutate(yhat_bin = factor(yhat_bin, levels = rev(levels(yhat_bin)))) %>% 
    mutate(obsY_bin = cut(y, breaks = quantile(y, probs = seq(0, 1, by = 1/3), na.rm=T), include.lowest = TRUE, ordered_result = TRUE)) %>%
    mutate(obsY_bin = factor(obsY_bin, levels = rev(levels(obsY_bin)))) %>% 
    mutate(dbRatio = yhat_mode/E) %>%
    mutate(dbRatio_bin = cut(dbRatio, breaks = quantile(dbRatio, probs = seq(0, 1, by = 1/5), na.rm=T), ordered_result = TRUE, include.lowest = TRUE)) %>%
    mutate(dbRatio_bin = factor(dbRatio_bin, levels = rev(levels(dbRatio_bin))))
 
  
  #### INLA diagnostic plots ####
  # plot marginal posteriors for fixed effects
  plot_fixedFx_marginals(path_plotExport_fixedFxMarginals, mod, modCodeStr, s)
  
  # plot choropleth of fitted values (yhat_i)
  plot_state_choropleth(path_plotExport_yhat_st, plotDat, "yhat_bin", "tier")
  # plot_state_choropleth(path_plotExport_yhat_st, plotDat, "yhat_bin", "gradient")
  
  # plot choropleth of observations (y_i)  
  plot_state_choropleth(path_plotExport_obsY_st, plotDat, "obsY_bin", "tier")
  # plot_state_choropleth(path_plotExport_obsY_st, plotDat, "y", "gradient")
  
  # plot choropleth of burden ratio (mu_i/E) 
  plot_state_choropleth(path_plotExport_predDBRatio_st, plotDat, "dbRatio_bin", "tier")
  
  #### INLA summary statistics export ####

}

#### INLA CSV file export - across seasons ####
export_DIC(path_csvExport_dic, dicData)




