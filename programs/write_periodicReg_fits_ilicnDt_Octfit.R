
## Name: Elizabeth Lee
## Date: 10/26/15
## Function: perform periodic regression on the detrended relative ilicn (ilicnDt)
## ilicDt metric defined: after using loess smoother to generate fitted values during summer weeks, we divided observed ilic by smoothed loess fits for entire time series
## used write_loess_fits_ILIc.R to generate ilicDt data
## lm(ILIc/timetrend ~ t + cos(2*pi*t/52.18) + sin(2*pi*t/52.18))

## Filenames: 
## Data Source: 
## Notes: code2 = 'Octfit' --> October to April is flu period, but we fit the seasonal regression from April to October (i.e., expanded definition of summer) in order to improve phase of regression fits
## 52.18 weeks per year in the regression model
## 12-10-15 - add spatial scale option (zip3 or state)
## 
## useful commands:
## install.packages("pkg", dependencies=TRUE, lib="/usr/local/lib/R/site-library") # in sudo R
## update.packages(lib.loc = "/usr/local/lib/R/site-library")

write_periodicReg_fits_ilicnDt_Octfit <- function(span.var, degree.var, spatial){
  print(deparse(sys.call()))
  
  #### header ####################################
  require(dplyr); require(readr)
  require(ggplot2)
  require(broom)
  require(tidyr)
  setwd(dirname(sys.frame(1)$ofile))
  
  #### header ################################
  code <- ''
  code2 <- '_Octfit'
  ## uncomment when running script separately
  # spatial <- list(scale = "state", stringcode = "State", stringabbr = "_st")
  # span.var <- 0.4 # 0.4, 0.6
  # degree.var <- 2
  code.str <- sprintf('_span%s_degree%s', span.var, degree.var)
  
  #### import data ####################################
  setwd('../R_export')

  if (spatial$scale == 'zip3'){
    ILI_full_df <- read_csv(file=sprintf('loess%s_all%sMods_ILIcn.csv', code.str, spatial$stringcode), col_types=list(zip3 = col_character(), ili = col_integer(), pop = col_integer(), cov_z.y = col_double(), alpha_z.y = col_double(), ILIc = col_double(), cov_below5 = col_logical(), .fitted=col_double(), .se.fit=col_double(), ilicn.dt=col_double(), ILIcn = col_double())) %>%
      rename(scale = zip3, .fittedLoess = .fitted, .se.fitLoess = .se.fit)
  } else if (spatial$scale == 'state'){
    ILI_full_df <- read_csv(file=sprintf('loess%s_all%sMods_ILIcn.csv', code.str, spatial$stringcode), col_types=list(state = col_character(), ili = col_integer(), pop = col_integer(), cov_z.y = col_double(), alpha_z.y = col_double(), ILIc = col_double(), cov_below5 = col_logical(), .fitted=col_double(), .se.fit=col_double(), ilicn.dt=col_double(), ILIcn = col_double())) %>%
      rename(scale = state, .fittedLoess = .fitted, .se.fitLoess = .se.fit)
  }
  
  #### process data for periodic regression ####################################
  # create new data for augment
  newbasedata <- ILI_full_df %>% select(Thu.week, t) %>% unique %>% filter(Thu.week < as.Date('2009-05-01'))
  
  # perform periodic regression
  print('performing periodic regression')
  allMods <- ILI_full_df %>% filter(fit.week) %>% filter(Thu.week < as.Date('2009-05-01')) %>% 
    filter(incl.lm) %>% group_by(scale) %>%
    do(fitZip3 = lm(ilicn.dt ~ t + cos(2*pi*t/52.18) + sin(2*pi*t/52.18), data = ., na.action=na.exclude))
  allMods_tidy <- tidy(allMods, fitZip3)
  allMods_aug <- augment(allMods, fitZip3, newdata= newbasedata)
  allMods_glance <- glance(allMods, fitZip3)
  
  # after augment - join ILI data to fits
  allMods_fit_ILI <- right_join((allMods_aug %>% select(-t)), (ILI_full_df %>% filter(Thu.week < as.Date('2009-05-01'))), by=c('Thu.week', 'scale')) %>% 
    mutate(Thu.week=as.Date(Thu.week, origin="1970-01-01")) %>% 
    mutate(week=as.Date(week, origin="1970-01-01")) 
  
  
  #### write data to file ####################################
  print(sprintf('writing periodic reg data to file %s', code.str))
  setwd('../R_export')
  
  # rename variable "scale" to zip3 or state
  perReg <- scaleRename(spatial$scale, allMods_fit_ILI)
  tidCoef <- scaleRename(spatial$scale, allMods_tidy)
  sumStats <- scaleRename(spatial$scale, allMods_glance)
  
  # write fitted and original IR data 
  write.csv(perReg, file=sprintf('periodicReg_%sall%sMods_ilicnDt%s%s.csv', code, spatial$stringcode, code2, code.str), row.names=FALSE)
  # write tidy coefficient dataset
  write.csv(tidCoef, file=sprintf('tidyCoef_periodicReg_%sall%sMods_ilicnDt%s%s.csv', code, spatial$stringcode, code2, code.str), row.names=FALSE)
  # write summary statistics for all models
  write.csv(sumStats, file=sprintf('summaryStats_periodicReg_%sall%sMods_ilicnDt%s%s.csv', code, spatial$stringcode, code2, code.str), row.names=FALSE)
  
}


