# ==============================================================================
#
# Format output files from CoreMS to comply with ESS-DIVE CSV reporting format (Velliquette et al. 2021)
#
# ==============================================================================
#
# Author: Brieanne Forbes (brieanne.forbes@pnnl.gov)
# 23 June 2026
#
# ======================= Notes =================================

# I left my computer as it was running csvs, it ran everything before. It didnt 
# renames csvs so I will need to delete the old ones. then I need to run everything else 

# ==============================================================================

require(pacman)
p_load(tidyverse,
       rstudioapi) #install and/or library necessary packages

# remove anything in the environment
rm(list=ls(all=T))

# ============ set WD to the path of the data package ==========================

#insert the path of the data package folder
current_path <- getActiveDocumentContext()$path 
setwd(dirname(current_path))
setwd("./..")

# ================================= get files ================================

corems_files <- list.files(path = '.', pattern = 'CoreMS.*\\.csv$', recursive = T, full.names = T, ignore.case = T)

data_files <- corems_files[grepl('CoreMS_Processed_ICR_Data', corems_files)]

mol_files <- corems_files[grepl('CoreMS_Processed_ICR_Mol', corems_files)]

cal_files <- corems_files[grepl('CoreMS_Processed_ICR_Calibration', corems_files)]

output_files <- corems_files[grepl('.corems', corems_files)]

xml_files <- list.files(path = '.', pattern = '.xml', recursive = T, full.names = T, ignore.case = T)

json_files <- list.files(path = '.', pattern = '.json', recursive = T, full.names = T, ignore.case = T)

cal_files <- list.files(path = '.', pattern = '.cal', recursive = T, full.names = T, ignore.case = T)

# ================================== data files ===============================

  
data <- read_csv(data_files, show_col_types = FALSE)%>%
  mutate_if(is.numeric, ~round(., 9)) %>%
  rename(Calibrated_Mass = `Calibrated m/z`)%>%
  rename_with(~ str_remove(.x, "\\.corems"))  # remove ".corems" from sample names

current_names <- colnames(data)
matched_indices <- match(current_names, mapping$FTICR_Sample_Name)
colnames(data) <- ifelse(is.na(matched_indices), 
                          current_names, 
                          mapping$New_Name[matched_indices]) 

data <- data%>%
  select(1, everything())%>%
  select(1, sort(colnames(.)[-1]))
  
write_csv(data, data_files) # rewrite file with same name
  

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
  mutate_if(is.numeric, ~ round(., 9)) %>%
  rename(
    Sample_Name = Sample,
    Calibration_Points = "Cal. Points",
    Calibration_Threshold = "Cal. Thresh.",
    Calibration_RMSE =  'Cal. RMS Error (ppm)',
    Calibration_Order = "Cal. Order"
  ) %>% 
  left_join(mapping, by = c('Sample_Name' = 'FTICR_Sample_Name')) %>%
  select(-Sample_Name) %>%
  rename(Sample_Name = New_Name) %>%
  relocate(Sample_Name, 1)
  
write_csv(cal, cal_files) # rewrite files with same name
 

# ===============================  output files ================================

for (m in output_files) {

  output <- read_csv(m, show_col_types = FALSE,
                     col_types = cols(
                       `13C` = col_double(),
                       `18O` = col_double(),
                       `33S` = col_double(),
                       `34S` = col_double(),
                       .default = col_guess())
                     )%>%
    select(-Adduct) %>%
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
  
  
  new_name <- mapping %>%
    filter(FTICR_Sample_Name == basename(m) %>% str_remove(., '.corems.csv') ) %>%
    pull(New_Name)

  full_new_name <- str_c(dirname(m),'/', new_name, '.corems.csv')


  write_csv(output, full_new_name)
  
}

# ===============================  jsons ================================

for (json in json_files) {
  
  json_new_name <- mapping %>% 
    filter(FTICR_Sample_Name == basename(json) %>% str_remove(., '.corems.json') ) %>%
    pull(New_Name)
  
  json_full_new_name <- str_c(dirname(json),'/', json_new_name, '.corems.json')
  
  file.rename(json, json_full_new_name)
  
}
# ===============================  cal ================================

for (cal in cal_files) {
  
  cal_new_name <- mapping %>% 
    filter(FTICR_Sample_Name == basename(cal) %>% str_remove(., '.corems.cal') ) %>%
    pull(New_Name)
  
  cal_full_new_name <- str_c(dirname(cal),'/', cal_new_name, '.corems.cal')
  
  file.rename(cal, cal_full_new_name)
  
}
# ===============================  xmls ================================

for (xml in xml_files) {
  
  xml_new_name <- mapping %>% 
    filter(FTICR_Sample_Name == basename(xml) %>% str_remove(., '.xml') ) %>%
    pull(New_Name)
  
  xml_full_new_name <- str_c(dirname(xml),'/', xml_new_name, '.xml')
  
  file.rename(xml, xml_full_new_name)
  
}
