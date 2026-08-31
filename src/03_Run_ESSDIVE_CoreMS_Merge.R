
# ============================================================
# 03 - Run ESS-DIVE CoreMS merge workflow
#
# This wrapper:
#   1. Reads the original ESS-DIVE CoreMS_MergeProcess.Rmd
#   2. Leaves the original ESS-DIVE file unchanged
#   3. Creates a temporary patched copy that:
#        - uses this project's CoreMS_Output folder
#        - writes to this project's Merged_Output folder
#        - uses dataset name HJA_2016_HJW_2025
#        - translates ESS-DIVE underscore column names back
#          to the names expected by CoreMS_MergeProcess.Rmd
#        - uses the local getLambda.R if internet is unavailable
#        - updates the old as.peakData() syntax for the
#          currently installed ftmsRanalysis version
#   4. Renders the temporary copy
#
# The original ESS-DIVE Rmd is NEVER modified.
# ============================================================


library(here)
library(rmarkdown)


# ------------------------------------------------------------
# Paths
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

corems_dir <- here(
  "CoreMS_Output"
)

output_dir <- here(
  "Merged_Output"
)


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

dataset_position <- grep(
  '^dataset\\.name\\s*=',
  rmd
)


if (length(dataset_position) != 1) {
  
  stop(
    "Could not uniquely identify dataset.name in ",
    "CoreMS_MergeProcess.Rmd."
  )
}


rmd[dataset_position] <- (
  'dataset.name = "HJA_2016_HJW_2025"'
)


# ------------------------------------------------------------
# Patch input directory
# ------------------------------------------------------------

input_position <- grep(
  '^path_to_dir\\s*=',
  rmd
)


if (length(input_position) != 1) {
  
  stop(
    "Could not uniquely identify path_to_dir in ",
    "CoreMS_MergeProcess.Rmd."
  )
}


rmd[input_position] <- paste0(
  'path_to_dir = "',
  gsub(
    "\\\\",
    "/",
    corems_dir
  ),
  '"'
)


# ------------------------------------------------------------
# Patch output directory
# ------------------------------------------------------------

output_position <- grep(
  '^output_dir\\s*=',
  rmd
)


if (length(output_position) != 1) {
  
  stop(
    "Could not uniquely identify output_dir in ",
    "CoreMS_MergeProcess.Rmd."
  )
}


rmd[output_position] <- paste0(
  'output_dir = "',
  gsub(
    "\\\\",
    "/",
    output_dir
  ),
  '/"'
)


# ------------------------------------------------------------
# Patch local getLambda fallback
# ------------------------------------------------------------

lambda_position <- grep(
  'source\\("path/to/getLambda\\.R"\\)',
  rmd
)


if (length(lambda_position) != 1) {
  
  stop(
    "Could not find getLambda fallback line."
  )
}


rmd[lambda_position] <- paste0(
  '  source("',
  gsub(
    "\\\\",
    "/",
    getlambda_path
  ),
  '")'
)


# ------------------------------------------------------------
# Translate ESS-DIVE formatted raw CoreMS column names
#
# ESS-DIVE archived .corems.csv files use names such as:
#
#   Calibrated_Mass
#   Calculated_Mass
#   Peak_Height
#   Error_ppm
#   Confidence_Score
#   Heteroatom_Class
#   Is_Isotopologue
#   Molecular_Formula
#
# CoreMS_MergeProcess.Rmd expects:
#
#   Calibrated m/z
#   Calculated m/z
#   Peak Height
#   m/z Error (ppm)
#   Confidence Score
#   Heteroatom Class
#   Is Isotopologue
#   Molecular Formula
#
# This translation occurs only in the temporary Rmd.
# ------------------------------------------------------------

read_position <- grep(
  'temp = read\\.csv\\(file = file',
  rmd
)


if (length(read_position) != 1) {
  
  stop(
    "Could not uniquely identify the CoreMS read.csv line."
  )
}


rename_block <- c(
  
  "",
  
  "  # Translate ESS-DIVE formatted column names back to",
  "  # names expected by CoreMS_MergeProcess.Rmd",
  
  "",
  
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
  '    names(temp)[names(temp) == "Molecular_Formula"] = "Molecular Formula"',

  "",

  "  # Normalize elemental absence codes in the project copy only",
  '  element_columns = c("C", "H", "O", "N", "S", "P")',
  '  missing_required_elements = setdiff(c("C", "H", "O"), names(temp))',
  '  if(length(missing_required_elements) > 0)',
  '    stop("Missing required elemental columns in ", file, ": ",',
  '         paste(missing_required_elements, collapse = ", "))',
  '  missing_optional_elements = setdiff(c("N", "S", "P"), names(temp))',
  '  if(length(missing_optional_elements) > 0)',
  '    temp[missing_optional_elements] = 0',
  '  temp = temp %>%',
  '    mutate(across(',
  '      all_of(element_columns),',
  '      ~ ifelse(is.na(.x) | .x == -9999, 0, as.numeric(.x))',
  '    ))',
  '  element_values = unlist(temp[element_columns], use.names = FALSE)',
  '  if(any(is.na(element_values)))',
  '    stop("Elemental counts could not be converted to numeric values in ", file)',
  '  if(any(element_values < 0 | element_values != round(element_values)))',
  '    stop("Elemental counts must be non-negative whole numbers in ", file)'
)


rmd <- append(
  rmd,
  rename_block,
  after = read_position
)


# ------------------------------------------------------------
# Update old ftmsRanalysis as.peakData() syntax
#
# The ESS-DIVE Rmd has all six old arguments on ONE line:
#
#   c_cname = "C", h_cname = "H", ...
#
# Current ftmsRanalysis expects:
#
#   element_col_names = list(...)
# ------------------------------------------------------------

element_position <- grep(
  'c_cname\\s*=\\s*"C".*p_cname\\s*=\\s*"P"',
  rmd
)


if (length(element_position) != 1) {
  
  cat(
    "\nLines containing c_cname:\n"
  )
  
  print(
    grep(
      "c_cname",
      rmd,
      value = TRUE
    )
  )
  
  stop(
    "Could not uniquely identify the old ",
    "ftmsRanalysis element argument line."
  )
}


new_element_block <- c(
  
  '                       element_col_names = list(',
  
  '                         "C" = "C",',
  
  '                         "H" = "H",',
  
  '                         "O" = "O",',
  
  '                         "N" = "N",',
  
  '                         "S" = "S",',
  
  '                         "P" = "P"',
  
  '                       ),'
)


# Remove the old one-line element argument syntax
rmd <- rmd[
  -element_position
]


# Insert the new syntax in the same location
rmd <- append(
  rmd,
  new_element_block,
  after = element_position - 1
)


# ------------------------------------------------------------
# Add a final elemental-count check before ftmsRanalysis
# ------------------------------------------------------------

aspeak_position <- grep(
  "peak_icr = as\\.peakData",
  rmd
)

if (length(aspeak_position) != 1) {
  stop("Could not uniquely identify the as.peakData() call.")
}

pre_ftms_qc_block <- c(
  "",
  "# Confirm valid atom counts immediately before ftmsRanalysis",
  'element_columns = c("C", "H", "O", "N", "S", "P")',
  'element_values = unlist(mol[element_columns], use.names = FALSE)',
  'if(any(is.na(element_values)))',
  '  stop("Missing elemental counts remain before ftmsRanalysis.")',
  'if(any(element_values < 0 | element_values != round(element_values)))',
  '  stop("Invalid elemental counts remain before ftmsRanalysis.")',
  'if(any(mol$C <= 0))',
  '  stop("Carbon counts must be positive before ftmsRanalysis.")',
  ""
)

rmd <- append(
  rmd,
  pre_ftms_qc_block,
  after = aspeak_position - 1
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
# Sanity checks on temporary Rmd
# ------------------------------------------------------------

patched_rmd <- readLines(
  temp_rmd,
  warn = FALSE
)


# Check specifically for the OLD argument line
old_argument_still_present <- any(
  grepl(
    'c_cname\\s*=\\s*"C".*p_cname\\s*=\\s*"P"',
    patched_rmd
  )
)


if (old_argument_still_present) {
  
  stop(
    "Old ftmsRanalysis element argument line is still ",
    "present in the temporary Rmd."
  )
}


# Confirm the new argument was added
new_argument_present <- any(
  grepl(
    "element_col_names\\s*=",
    patched_rmd
  )
)


if (!new_argument_present) {
  
  stop(
    "element_col_names was not added to the temporary Rmd."
  )
}


cat(
  "\nftmsRanalysis compatibility patch confirmed.\n"
)


# ------------------------------------------------------------
# Optional: print patched as.peakData() area
# ------------------------------------------------------------

aspeak_position <- grep(
  "peak_icr = as\\.peakData",
  patched_rmd
)


if (length(aspeak_position) == 1) {
  
  cat(
    "\nPatched as.peakData() section:\n\n"
  )
  
  print(
    patched_rmd[
      aspeak_position:min(
        aspeak_position + 15,
        length(patched_rmd)
      )
    ]
  )
}


# ------------------------------------------------------------
# Run temporary ESS-DIVE workflow
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
  "\n============================================\n"
)

cat(
  "ESS-DIVE merge wrapper complete\n"
)

cat(
  "============================================\n\n"
)


cat(
  "Input CoreMS files:",
  length(corems_files),
  "\n"
)


cat(
  "Original ESS-DIVE Rmd was NOT modified.\n\n"
)


if (file.exists(expected_data)) {
  
  cat(
    "Processed Data file FOUND:\n",
    expected_data,
    "\n\n"
  )
  
} else {
  
  warning(
    "Expected processed Data file was not found."
  )
}


if (file.exists(expected_mol)) {
  
  cat(
    "Processed Mol file FOUND:\n",
    expected_mol,
    "\n"
  )
  
} else {
  
  warning(
    "Expected processed Mol file was not found."
  )
}


element_normalization_present <- any(
  grepl(
    "Normalize elemental absence codes in the project copy only",
    patched_rmd,
    fixed = TRUE
  )
)

pre_ftms_qc_present <- any(
  grepl(
    "Confirm valid atom counts immediately before ftmsRanalysis",
    patched_rmd,
    fixed = TRUE
  )
)

if (!element_normalization_present || !pre_ftms_qc_present) {
  stop("Elemental normalization or pre-ftmsRanalysis QC was not added.")
}
