# ==============================================================================
#
# Format output files from CoreMS to comply with ESS-DIVE CSV reporting format (Velliquette et al. 2021)
#
# ==============================================================================
#
# Author: Brieanne Forbes (brieanne.forbes@pnnl.gov)
# 16 July 2026
#
# ==============================================================================

require(pacman)
p_load(tidyverse) #install and/or library necessary packages

# remove anything in the environment
rm(list=ls(all=T))

# ================================= User inputs ================================

#insert the path of the data package folder
dir <- ''

# ============ set WD to the path of the data package ==========================

setwd(dir)

# ================================= get files ================================

corems_files <- list.files(path = '.', pattern = 'CoreMS.*\\.csv$', recursive = T, full.names = T, ignore.case = T)

data_files <- corems_files[grepl('CoreMS_Processed_ICR_Data', corems_files)]

mol_files <- corems_files[grepl('CoreMS_Processed_ICR_Mol', corems_files)]

cal_files <- corems_files[grepl('CoreMS_Processed_ICR_Calibration', corems_files)]

output_files <- corems_files[grepl('.corems', corems_files)]

# ================================== data files ===============================

data <- read_csv(data_files, show_col_types = FALSE)%>%
    mutate_if(is.numeric, ~round(., 9)) %>%
    rename_with(~ str_remove(.x, "\\.corems")) %>% # remove ".corems" from sample names
    rename_with(~ str_remove(.x, "_[^_]*$")) %>% # remove IAT from sample names
    rename(Calibrated_Mass = `Calibrated m/z`)

sed_data <- data %>%
  select(Calibrated_Mass, contains('SIR'))

water_data <- data %>%
  select(Calibrated_Mass, contains('ICR')) %>%
  select(-'HJW_25_ICR-2') # remove sample with deviation

write_csv(sed_data, './v2_WHONDRS_HJW_Sample_Data/FTICR/WHONDRS_HJW_Sediment_CoreMS_Processed_ICR_Data.csv') 
write_csv(water_data, './v2_WHONDRS_HJW_Sample_Data/FTICR/WHONDRS_HJW_Water_CoreMS_Processed_ICR_Data.csv') 

# ================================  mol files ==================================


mol <- read_csv(mol_files, show_col_types = FALSE) %>%
    mutate_if(is.numeric, ~round(., 9)) %>%
    select(-`Molecular Formula`) %>% #remove column as it is the same as MolForm column 
    rename(Calibrated_Mass = `Calibrated m/z`,
           Is_Isotopologue = `Is Isotopologue`,
           Heteroatom_Class = `Heteroatom Class`,
           Calculated_Mass = `Calculated m/z`,
           Error_ppm = `m/z Error (ppm)`) %>%
    mutate_all(function(x) if(is.numeric(x)) ifelse(is.na(x), -9999, x) else ifelse(is.na(x), 'N/A', x)) #replace na values with -9999 or N/A
  
write_csv(mol, mol_files) # rewrite files with same name


# ================================= cal files ==================================

cal <- read_csv(cal_files, show_col_types = FALSE) %>%
    mutate_if(is.numeric, ~round(., 9)) %>%
    rename(Sample_Name = Sample,
           Calibration_Points = "Cal. Points",
           Calibration_Threshold = "Cal. Thresh.",
           Calibration_RMSE =  'Cal. RMS Error (ppm)',
           Calibration_Order = "Cal. Order" )%>% 
    mutate(Sample_Name = str_remove(Sample_Name, "_[^_]*$")) # remove IAT from sample names

sed_calib <- cal %>%
  filter(str_detect(Sample_Name, 'SIR'))

water_calib <- cal %>%
  filter(str_detect(Sample_Name, 'ICR'))%>%
  filter(Sample_Name != 'HJW_25_ICR-2')

blank_calib<- cal %>%
  filter(str_detect(Sample_Name, 'Blk'))
  
write_csv(sed_calib, './v2_WHONDRS_HJW_Sample_Data/FTICR/WHONDRS_HJW_Sediment_CoreMS_Processed_ICR_Calibration.csv') 
write_csv(water_calib, './v2_WHONDRS_HJW_Sample_Data/FTICR/WHONDRS_HJW_Water_CoreMS_Processed_ICR_Calibration.csv') 
write_csv(blank_calib, './v2_WHONDRS_HJW_Sample_Data/FTICR/WHONDRS_HJW_Blank_CoreMS_Processed_ICR_Calibration.csv') 


# ===============================  output files ================================

for (m in output_files) {

  output <- read_csv(m, show_col_types = FALSE,
                     col_types = cols(
                       `13C` = col_double(),
                       `15N` = col_double(),
                       `17O` = col_double(),
                       `18O` = col_double(),
                       `33S` = col_double(),
                       `34S` = col_double(),
                       .default = col_guess())
                     )%>%
    mutate_if(is.numeric, ~round(., 9)) %>%
    rename_with(~ str_replace_all(.x, " ", "_")) %>% # replace all spaces in column names with underscores
    rename( Mass = `m/z`,
            Calibrated_Mass = `Calibrated_m/z`,
            Calculated_Mass = `Calculated_m/z`,
            S_N = `S/N`,
            Error_ppm = `m/z_Error_(ppm)`,
            Error_Score = `m/z_Error_Score`,
            OtoC_ratio = `O/C`,
            HtoC_ratio = `H/C`)%>%
    mutate_all(function(x) if(is.numeric(x)) ifelse(is.na(x), -9999, x) else ifelse(is.na(x), 'N/A', x)) #replace na values with -9999 or N/A

  
  write_csv(output, m) # rewrite files with same name
  
}
