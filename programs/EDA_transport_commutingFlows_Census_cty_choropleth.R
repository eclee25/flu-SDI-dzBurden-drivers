
## Name: Elizabeth Lee
## Date: 11/16/15
## Function: EDA for commuting flows into work county, Census data 1990 & 2000
## Filenames: clean_transport_Census00.csv, clean_transport_Census90.csv
## Data Source: 
## Notes: 
## 
## useful commands:
## install.packages("pkg", dependencies=TRUE, lib="/usr/local/lib/R/site-library") # in sudo R
## update.packages(lib.loc = "/usr/local/lib/R/site-library")

#### header #################################
rm(list = ls())
require(dplyr); require(tidyr)
require(ggplot2)
require(readr)
  
setwd(dirname(sys.frame(1)$ofile)) # only works if you source the program

#### read data ################################
setwd("../../../../Sandra Goldlust's Work/EL_SG_Shared_Work/mySQL_Tables/transport_Census00")
str <- c(rep("c", 10), "i")
transDat00 <- read_csv("clean_transport_Census00.csv", col_types = paste0(str, collapse=''))
setwd("../transport_Census90")
str <- c(rep("c", 10), "icc")
transDat90 <- read_csv("clean_transport_Census90.csv", col_types = paste0(str, collapse=''), na = '\\N')

setwd(dirname(sys.frame(1)$ofile))
setwd('../../../Census/Source_Data')
popDat <- read_csv("CO-EST00INT-TOT.csv") %>%
  mutate(cty = substr.Right(paste0("00", COUNTY), 3)) %>% 
  mutate(st = substr.Right(paste0("0", STATE), 2)) %>%
  mutate(fips = paste0(st, cty)) %>%
  select(fips, POPESTIMATE2000)

#### data cleaning ################################
processDat <- function(transData){
  fullDat <- transData %>%
    mutate(Res_fips = paste0(Res_ST, Res_CO), Wrk_fips = substr.Right(paste0(Wrk_ST, Wrk_CO), 5)) %>%
    filter(substring(Wrk_ST, 1, 1) == '0') %>% # domestic workplace
    group_by(Wrk_fips) %>%
    summarise(rawvalue = sum(Count, na.rm=T)) %>%
    left_join(popDat, by = c("Wrk_fips" = "fips"))  %>% 
    mutate(region = as.numeric(Wrk_fips)) %>%
    mutate(normvalue = rawvalue/POPESTIMATE2000*1000)
  return(fullDat)
}

fullDat00 <- processDat(transDat00)
fullDat90 <- processDat(transDat90)

#### plot formatting ################################
h <- 5; w <- 8; dp <- 300
require(choroplethr)
require(choroplethrMaps)

# #### choropleth ################################
setwd(dirname(sys.frame(1)$ofile)) # only works if you source the program
dir.create(sprintf('../graph_outputs/EDA_transport_commutingFlows_Census_cty'), showWarnings=FALSE) # create directory if not exists
setwd('../graph_outputs/EDA_transport_commutingFlows_Census_cty')

choro00 <- county_choropleth(fullDat00 %>% 
                               dplyr::rename(value = normvalue), legend = "Into Wk county per 1000") 
ggsave("commutingInflowsNorm_Census_2000_cty.png", choro00, width = w, height = h, dpi = dp)
choro00r <- county_choropleth(fullDat00 %>% 
                                dplyr::rename(value = rawvalue), legend = "Into Wk county") 
ggsave("commutingInflows_Census_2000_cty.png", choro00r, width = w, height = h, dpi = dp)

choro90 <- county_choropleth(fullDat90 %>% 
                               dplyr::rename(value = normvalue), legend = "Into Wk county per 1000") 
ggsave("commutingInflowsNorm_Census_1990_cty.png", choro90, width = w, height = h, dpi = dp)
choro90r <- county_choropleth(fullDat90 %>% 
                                dplyr::rename(value = rawvalue), legend = "Into Wk county") 
ggsave("commutingInflows_Census_1990_cty.png", choro90r, width = w, height = h, dpi = dp)

#### scatter bw access & population variables ################################
scatterPlot <- function(dataset){
  dummy <- dataset %>% 
    dplyr::rename(pop = POPESTIMATE2000)
  scatters <- ggplot(dummy, aes(x = rawvalue,  y = pop)) +
    geom_point(color = 'black') +
    theme_bw(base_size = 12, base_family = "") +
    scale_x_continuous(name = "commuters to work county")
    # scale_y_log10(limits = c(1, 30000000)) + scale_x_log10(limits = c(1, 30000000))
    # coord_cartesian(xlim = c(1, 30000000), ylim = c(1, 30000000)) +
  return(scatters)
}
  
sp00 <- scatterPlot(fullDat00)
ggsave("scatterPop_transport_commutingFlows_Census_cty_2000.png", sp00, width = w, height = h, dpi = dp)
sp90 <- scatterPlot(fullDat90)
ggsave("scatterPop_transport_commutingFlows_Census_cty_1990.png", sp90, width = w, height = h, dpi = dp)
# 11/18/15