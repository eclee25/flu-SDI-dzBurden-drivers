## Name: Elizabeth Lee
## Date: 10/12/16
## Function: post-processing program for any inla model, for a set of models with the same structure: plot extra residual diagnostics 
## Filenames: 
## Data Source: IMS Health
## Notes: need to SSH into snow server
## 
## useful commands:
## install.packages("pkg", dependencies=TRUE, lib="/usr/local/lib/R/site-library") # in sudo R
## update.packages(lib.loc = "/usr/local/lib/R/site-library")

#### header #################################
require(readr)

#### SOURCE: clean and import model data #################################
setwd(dirname(sys.frame(1)$ofile))
source("source_prepare_inlaData_cty.R") # remove_gammaQQ_outliers
source("source_export_inlaDiagnostics.R") # plot_diag_scatter_hurdle function, calculate_residuals
source("source_clean_response_functions_cty.R") # cty response functions
# source("source_variableSelection_cty.R") # prepare_allCov_iliSum_cty/_raw
source("source_clean_data_functions.R") # functions to clean covariate data

#### set these! ################################
dbCodeStr <- "_ilinDt_Octfit_span0.4_degree2"
modCodeStr <- "8a_iliSum_v2-6"
seasons <- c(3:9)
likString <- "normal"
source("source_calculate_residuals_shift1.R") # calculate_residuals function (source_calculate_residuals_shift1.R for iliSum; source_calculate_residuals.R for epiDur)

#### IMPORT FILEPATHS #################################
setwd('../reference_data')
path_abbr_st <- paste0(getwd(), "/state_abbreviations_FIPS.csv")
path_latlon_cty <- paste0(getwd(), "/cty_pop_latlon.csv")

setwd('./UScounty_shapefiles')
path_adjMxExport_cty <- paste0(getwd(), "/US_county_adjacency.graph")
path_graphIdx_cty <- paste0(getwd(), "/US_county_graph_index.csv")
path_shape_cty <- paste0(getwd(), "/gz_2010_us_050_00_500k") # for dbf metadata only

setwd('../stateFlightpassenger_graph')
path_graphExport_st <- paste0(getwd(), "/US_statePassenger_edgelist.txt")
path_graphIdx_st <- paste0(getwd(), "/US_statePassenger_graph_index.csv")

setwd("../../R_export")
path_response_cty <- paste0(getwd(), sprintf("/dbMetrics_periodicReg%s_analyzeDB_cty.csv", dbCodeStr))

# put all paths in a list to pass them around in functions
path_list <- list(path_abbr_st = path_abbr_st,
                  path_latlon_cty = path_latlon_cty,
                  path_shape_cty = path_shape_cty,
                  path_adjMxExport_cty = path_adjMxExport_cty,
                  path_response_cty = path_response_cty, 
                  path_graphIdx_cty = path_graphIdx_cty,
                  path_graphExport_st = path_graphExport_st,
                  path_graphIdx_st = path_graphIdx_st)

#### EXPORT FILEPATHS #################################
# predictor plot export directories
setwd(dirname(sys.frame(1)$ofile))
setwd(sprintf("../graph_outputs/inlaModelDiagnostics/%s", modCodeStr))
dir.create("./diag_predictors", showWarnings = FALSE)
setwd("./diag_predictors")
path_plotExport <- getwd()
# dir.create("./rawresid_rawpredictors", showWarnings = FALSE)
# dir.create("./rawresid_stdpredictors", showWarnings = FALSE)
# dir.create("./stdresid_rawpredictors", showWarnings = FALSE)
dir.create("./stdresid_stdpredictors", showWarnings = FALSE)

# error plot export directories
setwd(dirname(sys.frame(1)$ofile))
setwd(sprintf("../graph_outputs/inlaModelDiagnostics/%s", modCodeStr))
dir.create("./diag_errors", showWarnings = FALSE)
setwd("./diag_errors")
path_plotExport2 <- getwd()

# # index plot export directories
# setwd(dirname(sys.frame(1)$ofile))
# setwd(sprintf("../graph_outputs/inlaModelDiagnostics/%s", modCodeStr))
# dir.create("./diag_index", showWarnings = FALSE)
# setwd("./diag_index")
# path_plotExport3 <- getwd()

#### Residuals vs. predictors #################################
# csv file export directories
setwd(dirname(sys.frame(1)$ofile))
setwd(sprintf("../R_export/inlaModelData_export/%s", modCodeStr))
path_csvExport <- getwd()

#### IMPORT MODEL DATA #################################
modData <- model8a_iliSum_v7(path_list)

# ### raw residuals vs raw data ####
# path_plotExport_scatter_rr <- paste0(path_plotExport, "/rawresid_rawpredictors/diag_rawresid_raw")
# importPlot_diag_scatter_predictors_spatiotemporal(path_csvExport, path_plotExport_scatter_rr, paste0(likString, "_", modCodeStr), "yhat_rawresid", rmodData)

# #### raw residuals vs std data ####
# path_plotExport_scatter_rs <- paste0(path_plotExport, "/rawresid_stdpredictors/diag_rawresid_")
# importPlot_diag_scatter_predictors_spatiotemporal(path_csvExport, path_plotExport_scatter_rs, paste0(likString, "_", modCodeStr), "yhat_rawresid", modData)

# #### std residuals vs raw data ####
# path_plotExport_scatter_sr <- paste0(path_plotExport, "/stdresid_rawpredictors/diag_resid_raw")
# importPlot_diag_scatter_predictors_spatiotemporal(path_csvExport, path_plotExport_scatter_sr, paste0(likString, "_", modCodeStr), "yhat_resid", rmodData)

#### std residuals vs std data ####
path_plotExport_scatter_ss <- paste0(path_plotExport, "/stdresid_stdpredictors/diag_resid_")
importPlot_diag_scatter_predictors_spatiotemporal(path_csvExport, path_plotExport_scatter_ss, paste0(likString, "_", modCodeStr), "yhat_resid", modData)

#### Distribution of response, residuals and all predictors #################################
path_plotExport_distr <- paste0(path_plotExport, "/diag_distr_")
importPlot_diag_data_distribution(path_csvExport, path_plotExport_distr, paste0(likString, "_", modCodeStr), modData)

### vs. county iid group terms #################################
path_plotExport_spatial <- paste0(path_plotExport2, "/diag_")
importPlot_diag_scatter_ctyerrors_spatiotemporal(path_csvExport, path_plotExport_spatial, likString)

### vs. observation iid error terms #################################
path_plotExport_error <- paste0(path_plotExport2, "/diag_")
importPlot_diag_scatter_errors_spatiotemporal(path_csvExport, path_plotExport_error, likString)

# #### vs. index #################################
# path_plotExport_index <- paste0(path_plotExport3, "/diag_")
# importPlot_diag_index_spatiotemporal(path_csvExport, path_plotExport_index, likString)


