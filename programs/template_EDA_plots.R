## Name: Elizabeth Lee
## Date: 6/2/16
## Function: template code to automate plotting for choropleths and time series; plot functions found in source_EDA_plots.R
## Filename: 
## 
## useful commands:
## install.packages("pkg", dependencies=TRUE, lib="/usr/local/lib/R/site-library") # in sudo R
## update.packages(lib.loc = "/usr/local/lib/R/site-library")
rm(list = ls())
#### header ####################################
require(ggplot2)
require(dplyr)
require(readr)
require(RColorBrewer)

setwd(dirname(sys.frame(1)$ofile))
source("source_clean_data_functions.R")
source("source_EDA_plots.R")

#### SET THESE! PART 1 ################################
# dbCodeStr <- "_ilinDt_Octfit_span0.4_degree2"
num <- 6

#### import data ################################
setwd('../reference_data')
abbrDat <- read_csv("state_abbreviations_FIPS.csv", col_types = list(FIPS = col_character())) %>%
  rename(fips_st = FIPS)
path_latlon_cty <- paste0(getwd(), "/cty_pop_latlon.csv")

# import covariate data
importDat <- cleanX_popDensity_cty()

#### clean data ################################
# for choro
# required data format: year = year or season, covariate = variable name, value = covariate value, fips = county fips id
fullDat <- importDat %>%
  gather(covariate, value, popDensity) %>%
  arrange(fips, year) 

# for ts
# required data format: year = year or season, covariate = variable name, value = covariate value, fips = county fips id, fips_st = state fips id, State = full state name, Abbreviation = state abbreviation, for.plot = each state has a different number
uqst <- abbrDat %>% select(State) %>% distinct(State) %>% arrange(State) %>%
  mutate(for.plot = seq_along(1:nrow(.)))
fullDat2 <- fullDat %>%
  mutate(fips_st = substring(fips, 1, 2)) %>%
  left_join(abbrDat, by = "fips_st") %>%
  left_join(uqst, by = "State")
indexes <- seq(1, max(fullDat2 %>% select(for.plot)), by=num)
years <- fullDat2 %>% select(year) %>% distinct(year) %>% filter(!is.na(year)) %>% arrange(year) %>% unlist
varnames <- fullDat2 %>% select(covariate) %>% unique %>% unlist

#### SET THESE! PART 2 ################################
## general parameters ##
plotfolder <- "EDA_popDensity_Census_cty"
src <- 'Census'
spatial <- 'cty'

## choropleth parameters ##
# one per covariate "code"
choroParams <- list(spatial = spatial, code = 'popDensity', lab = 'Population Density', src = src, yr = years) # one per covariate
choroplotParams <- list(labVec = paste("Tier", 1:5), colVec = brewer.pal(5, 'RdYlGn'), h = 5, w = 8, dp = 300)

## time series parameters ##
tsParams <- list(indexes = indexes, years = years, varnames = varnames, spatial = spatial, src = src) 
tsplotParams <- list(num = 6, h = 12, w = 12, dp = 300, leg.lab = c("Pop Density per Sq Mile")) # all covariates together


#### draw plots ################################
setwd(dirname(sys.frame(1)$ofile))
dir.create(sprintf("../graph_outputs/%s", plotfolder), showWarnings = FALSE)
setwd(sprintf("../graph_outputs/%s", plotfolder))

# choropleths
dir.create("./choro", showWarnings = FALSE)
setwd("./choro")
choroplots_cty_1yr(fullDat, choroParams, choroplotParams) # one per covariate "code"
choroplots_cty(fullDat, choroParams, choroplotParams)

# time series
dir.create("../ts", showWarnings = FALSE)
setwd("../ts")
tsplots_cty(fullDat2, tsParams, tsplotParams) # all covariates together
