# ============================================================
# 03 - Run ESS-DIVE CoreMS merge workflow
#
# This wrapper:
#   1. Reads the original ESS-DIVE CoreMS_MergeProcess.Rmd
#   2. Leaves the original file unchanged
#   3. Creates a temporary patched copy that:
#        - uses this project's CoreMS_Output folder
#        - writes to this project's Merged_Output folder
#        - uses dataset name HJA_2016_HJW_2025
#        - translates ESS-DIVE underscore column names back
#          to the names expected by CoreMS_MergeProcess.Rmd
#        - uses the local getLambda.R if internet is unavailable
#        - updates the old as.peakData() element-column syntax
#          for the currently installed ftmsRanalysis version
#   4. Renders the temporary copy
#
# The ESS-DIVE source Rmd is never modified.
# ============================================================


library(here)
library(rmarkdown)


# ------------------------------------------------------------
# Project paths
# ------------------------------------------------------------

essdive_script <- here(
  "v2_WHONDRS_HJW_Sample_Data",
  "v2_WHONDRS_HJW_Sample_Data",
  "FTICR",
  "FTICR_Instructions",
  "CoreMS_MergeProcess.Rmd"
)

getlambda_path <- here(
  "v2_WHONDRS_HJW_Sample_Data",
  "v2_WHONDRS_HJW_Sample_Data",
  "FTICR",
  "FTICR_Instructions",
  "getLambda.R"
)

corems_dir <- here("CoreMS_Output")

output_dir <- here("Merged_Output")


# ------------------------------------------------------------
# Check required files/folders
# ------------------------------------------------------------

if (!file.exists(essdive_script)) {
  stop(
    "Could not find ESS-DIVE CoreMS_MergeProcess.Rmd:\n",
    essdive_script
  )
}

if (!file.exists(getlambda_path)) {
  stop(
    "Could not find ESS-DIVE getLambda.R:\n",
    getlambda_path
  )
}

if (!dir.exists(corems_dir)) {
  stop(
    "Could not find CoreMS_Output folder:\n",
    corems_dir
  )
}

if (!dir.exists(output_dir)) {
  dir.create(
    output_dir,
    recursive = TRUE
  )
}


# ------------------------------------------------------------
# Check CoreMS input files
# ------------------------------------------------------------

corems_files <- list.files(
  corems_dir,
  pattern = "\\.corems\\.csv$",
  full.names = TRUE
)

cat(
  "\nCoreMS files found:",
  length(corems_files),
  "\n"
)

if (length(corems_files) == 0) {
  stop(
    "No .corems.csv files found in CoreMS_Output."
  )
}


# ------------------------------------------------------------
# Read original ESS-DIVE Rmd
# ------------------------------------------------------------

rmd <- readLines(
  essdive_script,
  warn = FALSE
)


# ------------------------------------------------------------
# Patch dataset name
# ------------------------------------------------------------

dataset_old <- 'dataset.name = "Test_Processed"'

dataset_new <- 'dataset.name = "HJA_2016_HJW_2025"'

if (!any(rmd == dataset_old)) {
  stop(
    "Could not find expected dataset.name line in ",
    "CoreMS_MergeProcess.Rmd."
  )
}

rmd[rmd == dataset_old] <- dataset_new


# ------------------------------------------------------------
# Patch input directory
# ------------------------------------------------------------

input_old <- 'path_to_dir = easycsv::choose_dir()'

input_new <- paste0(
  'path_to_dir = "',
  gsub("\\\\", "/", corems_dir),
  '"'
)

if (!any(rmd == input_old)) {
  stop(
    "Could not find expected path_to_dir line in ",
    "CoreMS_MergeProcess.Rmd."
  )
}

rmd[rmd == input_old] <- input_new


# ------------------------------------------------------------
# Patch output directory
# ------------------------------------------------------------

output_old <- 'output_dir = paste0(path_to_dir, "/Merged_Output/")'

output_new <- paste0(
  'output_dir = "',
  gsub("\\\\", "/", output_dir),
  '/"'
)

if (!any(rmd == output_old)) {
  stop(
    "Could not find expected output_dir line in ",
    "CoreMS_MergeProcess.Rmd."
  )
}

rmd[rmd == output_old] <- output_new


# ------------------------------------------------------------
# Patch local getLambda fallback
# ------------------------------------------------------------

lambda_old <- '  source("path/to/getLambda.R")'

lambda_new <- paste0(
  '  source("',
  gsub("\\\\", "/", getlambda_path),
  '")'
)

if (!any(rmd == lambda_old)) {
  stop(
    "Could not find expected getLambda fallback line in ",
    "CoreMS_MergeProcess.Rmd."
  )
}

rmd[rmd == lambda_old] <- lambda_new


# ------------------------------------------------------------
# Translate ESS-DIVE formatted CoreMS column names
#
# The archived .corems.csv files use names such as:
#   Calibrated_Mass
#   Molecular_Formula
#
# The original merge Rmd expects:
#   Calibrated m/z
#   Molecular Formula
#
# This translation is applied only inside the temporary Rmd.
# ------------------------------------------------------------

read_line <- '  temp = read.csv(file = file, check.names = F)'

read_position <- which(rmd == read_line)

if (length(read_position) != 1) {
  stop(
    "Could not find the expected CoreMS read.csv line in ",
    "CoreMS_MergeProcess.Rmd."
  )
}

rename_block <- c(
  "",
  "  # Translate ESS-DIVE formatted column names back to",
  "  # the names expected by CoreMS_MergeProcess.Rmd",
  '  if("Calibrated_Mass" %in% names(temp))',
  '    names(temp)[names(temp) == "Calibrated_Mass"] = "Calibrated m/z"',
  "",
  '  if("Calculated_Mass" %in% names(temp))',
  '    names(temp)[names(temp) == "Calculated_Mass"] = "Calculated m/z"',
  "",
  '  if("Peak_Height" %in% names(temp))',
  '    names(temp)[names(temp) == "Peak_Height"] = "Peak Height"',
  "",
  '  if("Error_ppm" %in% names(temp))',
  '    names(temp)[names(temp) == "Error_ppm"] = "m/z Error (ppm)"',
  "",
  '  if("Confidence_Score" %in% names(temp))',
  '    names(temp)[names(temp) == "Confidence_Score"] = "Confidence Score"',
  "",
  '  if("Heteroatom_Class" %in% names(temp))',
  '    names(temp)[names(temp) == "Heteroatom_Class"] = "Heteroatom Class"',
  "",
  '  if("Is_Isotopologue" %in% names(temp))',
  '    names(temp)[names(temp) == "Is_Isotopologue"] = "Is Isotopologue"',
  "",
  '  if("Molecular_Formula" %in% names(temp))',
  '    names(temp)[names(temp) == "Molecular_Formula"] = "Molecular Formula"'
)

rmd <- append(
  rmd,
  rename_block,
  after = read_position
)


# ------------------------------------------------------------
# Patch old ftmsRanalysis as.peakData() element arguments
#
# Old ESS-DIVE Rmd uses:
#   c_cname
#   h_cname
#   o_cname
#   n_cname
#   s_cname
#   p_cname
#
# Current ftmsRanalysis uses:
#   element_col_names = list(...)
# ------------------------------------------------------------

old_element_block <- c(
  '  c_cname = "C",',
  '  h_cname = "H",',
  '  o_cname = "O",',
  '  n_cname = "N",',
  '  s_cname = "S",',
  '  p_cname = "P",'
)

element_positions <- which(
  rmd %in% old_element_block
)

if (length(element_positions) != 6) {
  stop(
    "Could not find all six old ftmsRanalysis element ",
    "arguments in CoreMS_MergeProcess.Rmd."
  )
}

first_element_position <- min(
  element_positions
)

# Remove old lines
rmd <- rmd[
  -element_positions
]

# Insert new syntax
new_element_block <- c(
  '  element_col_names = list(',
  '    "C" = "C",',
  '    "H" = "H",',
  '    "O" = "O",',
  '    "N" = "N",',
  '    "S" = "S",',
  '    "P" = "P"',
  '  ),'
)

rmd <- append(
  rmd,
  new_element_block,
  after = first_element_position - 1
)


# ------------------------------------------------------------
# Save temporary patched Rmd
# ------------------------------------------------------------

temp_rmd <- file.path(
  tempdir(),
  "CoreMS_MergeProcess_HJA_HJW.Rmd"
)

writeLines(
  rmd,
  temp_rmd
)

cat(
  "\nTemporary patched Rmd created:\n",
  temp_rmd,
  "\n"
)


# ------------------------------------------------------------
# Render temporary ESS-DIVE workflow
# ------------------------------------------------------------

cat(
  "\nRunning ESS-DIVE CoreMS merge workflow...\n\n"
)

rmarkdown::render(
  input = temp_rmd,
  output_file = "CoreMS_MergeProcess_HJA_HJW.html",
  output_dir = output_dir,
  envir = new.env(
    parent = globalenv()
  ),
  quiet = FALSE
)


# ------------------------------------------------------------
# Check expected outputs
# ------------------------------------------------------------

expected_data <- file.path(
  output_dir,
  "HJA_2016_HJW_2025-Processed_Data.csv"
)

expected_mol <- file.path(
  output_dir,
  "HJA_2016_HJW_2025-Processed_Mol.csv"
)


cat(
  "\nProcessing finished.\n"
)

cat(
  "\nExpected processed Data file:\n",
  expected_data,
  "\n"
)

cat(
  "\nExpected processed Mol file:\n",
  expected_mol,
  "\n"
)


if (file.exists(expected_data)) {
  
  cat(
    "\nProcessed Data file found.\n"
  )
  
} else {
  
  warning(
    "Expected processed Data file was not found."
  )
}


if (file.exists(expected_mol)) {
  
  cat(
    "Processed Mol file found.\n"
  )
  
} else {
  
  warning(
    "Expected processed Mol file was not found."
  )
}


# ------------------------------------------------------------
# Final summary
# ------------------------------------------------------------

cat(
  "\n============================================\n"
)

cat(
  "ESS-DIVE merge wrapper complete\n"
)

cat(
  "============================================\n"
)

cat(
  "Input CoreMS files:",
  length(corems_files),
  "\n"
)

cat(
  "Original ESS-DIVE Rmd was NOT modified.\n"
)

cat(
  "Outputs written to:\n",
  output_dir,
  "\n"
)