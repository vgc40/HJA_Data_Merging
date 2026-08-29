# ============================================================
# 04 - Clean HJW 2025 blanks and merge technical replicates
#
# Inputs:
#   Merged_Output/HJA_2016_HJW_2025-Processed_Data.csv
#   Merged_Output/HJA_2016_HJW_2025-Processed_Mol.csv
#   v2_WHONDRS_HJW_Sample_Data/WHONDRS_HJW_Field_Metadata.csv
#
# Workflow:
#   1. Validate Processed Data and Mol files
#   2. Normalize sample names by removing ".corems"
#   3. Check Molecular Formula vs MolForm
#   4. Identify:
#        - HJA 2016 samples
#        - HJW 2025 sediment technical replicates
#        - HJW 2025 blanks
#   5. Flag peaks detected in BOTH 2025 blanks
#   6. Set those peaks to zero ONLY in HJW 2025 replicates
#   7. Merge HJW technical replicates:
#        - 3 replicates -> retain if detected in >=2
#        - 2 replicates -> retain only if detected in both
#        - final intensity = mean of positive detected values
#   8. Leave HJA 2016 intensities unchanged
#   9. Final naming:
#        HJA 2016 -> HJA_<site>_2016
#        HJW 2025 -> HJA_<Site_ID>_2025
#  10. Keep all molecular rows so Data remains aligned to Mol
#
# ============================================================


library(tidyverse)


# ============================================================
# Paths
# ============================================================

processed_data_path <- file.path(
  "Merged_Output",
  "HJA_2016_HJW_2025-Processed_Data.csv"
)

processed_mol_path <- file.path(
  "Merged_Output",
  "HJA_2016_HJW_2025-Processed_Mol.csv"
)

field_metadata_path <- file.path(
  "v2_WHONDRS_HJW_Sample_Data",
  "WHONDRS_HJW_Field_Metadata.csv"
)


final_data_path <- file.path(
  "Merged_Output",
  "HJA_2016_HJW_2025-Processed_Data_Final.csv"
)

final_mol_path <- file.path(
  "Merged_Output",
  "HJA_2016_HJW_2025-Processed_Mol_Final.csv"
)

blank_report_path <- file.path(
  "Merged_Output",
  "HJA_2016_HJW_2025-Blank_Associated_Peaks.csv"
)

replicate_report_path <- file.path(
  "Merged_Output",
  "HJA_2016_HJW_2025-HJW_Replicate_Summary.csv"
)

column_mapping_path <- file.path(
  "Merged_Output",
  "HJA_2016_HJW_2025-Sample_Name_Mapping.csv"
)

formula_report_path <- file.path(
  "Merged_Output",
  "HJA_2016_HJW_2025-Molecular_Formula_vs_MolForm.csv"
)

readme_path <- file.path(
  "Merged_Output",
  "README_HJA_2016_HJW_2025_postprocessing.txt"
)


# ============================================================
# Check required files
# ============================================================

if (!file.exists(processed_data_path)) {
  stop(
    "Processed Data file not found:\n",
    processed_data_path
  )
}

if (!file.exists(processed_mol_path)) {
  stop(
    "Processed Mol file not found:\n",
    processed_mol_path
  )
}

if (!file.exists(field_metadata_path)) {
  stop(
    "HJW field metadata file not found:\n",
    field_metadata_path
  )
}


# ============================================================
# Load files
# ============================================================

processed_data <- read.csv(
  processed_data_path,
  check.names = FALSE
)

processed_mol <- read.csv(
  processed_mol_path,
  check.names = FALSE
)

field_metadata <- read.csv(
  field_metadata_path,
  check.names = FALSE
)


cat(
  "\n============================================\n",
  "VALIDATING PROCESSED DATA AND MOL FILES\n",
  "============================================\n\n",
  sep = ""
)


# ============================================================
# Validate calibrated mass column
# ============================================================

feature_column <- "Calibrated m/z"


if (!feature_column %in% names(processed_data)) {
  stop(
    "'Calibrated m/z' not found in Processed Data."
  )
}

if (!feature_column %in% names(processed_mol)) {
  stop(
    "'Calibrated m/z' not found in Processed Mol."
  )
}


# ============================================================
# Validate Data/Mol row counts
# ============================================================

cat(
  "Processed Data rows:",
  nrow(processed_data),
  "\n"
)

cat(
  "Processed Mol rows:",
  nrow(processed_mol),
  "\n"
)


if (nrow(processed_data) != nrow(processed_mol)) {
  stop(
    "Processed Data and Processed Mol have different ",
    "numbers of molecular rows."
  )
}


# ============================================================
# Validate Data/Mol calibrated mass alignment
# ============================================================

mass_match <- isTRUE(
  all.equal(
    processed_data[[feature_column]],
    processed_mol[[feature_column]],
    tolerance = 1e-10,
    check.attributes = FALSE
  )
)


if (!mass_match) {
  stop(
    "Calibrated m/z values are not aligned between ",
    "Processed Data and Processed Mol."
  )
}


cat(
  "Data/Mol calibrated mass alignment: PASS\n"
)


# ============================================================
# NORMALIZE SAMPLE COLUMN NAMES
#
# ESS-DIVE merge output retains ".corems" in sample names:
#
#   HJA_155_p1.corems
#   HJW_01_SIR-1_p08.corems
#   HJW_Blk-1_p05.corems
#
# Remove ".corems" before any sample classification.
# ============================================================

original_sample_names <- setdiff(
  names(processed_data),
  feature_column
)


normalized_sample_names <- str_remove(
  original_sample_names,
  "\\.corems$"
)


names(processed_data)[
  match(
    original_sample_names,
    names(processed_data)
  )
] <- normalized_sample_names


# Make sure normalization did not create duplicates
if (anyDuplicated(names(processed_data)) > 0) {
  
  duplicate_names <- names(processed_data)[
    duplicated(names(processed_data))
  ]
  
  cat(
    "\nDuplicate column names after removing .corems:\n"
  )
  
  print(
    duplicate_names
  )
  
  stop(
    "Removing .corems created duplicate sample names."
  )
}


cat(
  "\n.corems suffix removed from sample names.\n"
)


# ============================================================
# Check Molecular Formula vs MolForm
# ============================================================

formula_mismatch_count <- NA_integer_


if (
  all(
    c(
      "Molecular Formula",
      "MolForm"
    ) %in% names(processed_mol)
  )
) {
  
  formula_check <- processed_mol %>%
    transmute(
      `Calibrated m/z`,
      `Molecular Formula`,
      MolForm,
      
      molecular_formula_clean = str_replace_all(
        `Molecular Formula`,
        "\\s+",
        ""
      ),
      
      molform_clean = str_replace_all(
        MolForm,
        "\\s+",
        ""
      ),
      
      exact_match =
        `Molecular Formula` == MolForm,
      
      whitespace_normalized_match =
        molecular_formula_clean == molform_clean
    )
  
  
  formula_mismatch_count <- sum(
    !formula_check$whitespace_normalized_match,
    na.rm = TRUE
  )
  
  
  cat(
    "\nMolecular Formula vs MolForm:\n"
  )
  
  cat(
    "Exact string matches:",
    sum(
      formula_check$exact_match,
      na.rm = TRUE
    ),
    "\n"
  )
  
  cat(
    "Exact string differences:",
    sum(
      !formula_check$exact_match,
      na.rm = TRUE
    ),
    "\n"
  )
  
  cat(
    "Differences after removing whitespace:",
    formula_mismatch_count,
    "\n"
  )
  
  
  write.csv(
    formula_check,
    formula_report_path,
    quote = FALSE,
    row.names = FALSE
  )
  
  
} else {
  
  cat(
    "\nMolecular Formula and/or MolForm column is absent.\n",
    "Formula comparison skipped.\n"
  )
}


# ============================================================
# Identify sample columns
# ============================================================

sample_columns <- setdiff(
  names(processed_data),
  feature_column
)


# ------------------------------------------------------------
# HJA 2016
#
# Examples:
#   HJA_155_p1
#   HJA_CC-1-15m_p1
#   HJA_KerryCreek2_p1
# ------------------------------------------------------------

hja_columns <- sample_columns[
  str_detect(
    sample_columns,
    "^HJA_.*_p[0-9]+$"
  )
]


# ------------------------------------------------------------
# HJW 2025 sediment technical replicates
#
# Example:
#   HJW_01_SIR-1_p08
# ------------------------------------------------------------

hjw_replicate_columns <- sample_columns[
  str_detect(
    sample_columns,
    "^HJW_[0-9]+_SIR-[0-9]+_p[0-9]+$"
  )
]


# ------------------------------------------------------------
# HJW 2025 blanks
#
# Examples:
#   HJW_Blk-1_p05
#   HJW_Blk-2_p05
# ------------------------------------------------------------

blank_columns <- sample_columns[
  str_detect(
    sample_columns,
    "^HJW_.*Blk.*_p[0-9]+$"
  )
]


cat(
  "\n============================================\n",
  "SAMPLE COLUMN CHECK\n",
  "============================================\n\n",
  sep = ""
)


cat(
  "HJA 2016 sample columns:",
  length(hja_columns),
  "\n"
)

cat(
  "HJW 2025 replicate columns:",
  length(hjw_replicate_columns),
  "\n"
)

cat(
  "HJW 2025 blank columns:",
  length(blank_columns),
  "\n\n"
)


cat(
  "Blank columns:\n"
)

print(
  blank_columns
)


# ============================================================
# Validate blanks
# ============================================================

if (length(blank_columns) != 2) {
  
  stop(
    "Expected exactly 2 HJW blank columns, but found ",
    length(blank_columns),
    "."
  )
}


# ============================================================
# Check for unclassified sample columns
# ============================================================

classified_columns <- c(
  hja_columns,
  hjw_replicate_columns,
  blank_columns
)


unclassified_columns <- setdiff(
  sample_columns,
  classified_columns
)


if (length(unclassified_columns) > 0) {
  
  cat(
    "\nWARNING: Sample columns not classified as ",
    "HJA, HJW replicate, or blank:\n"
  )
  
  print(
    unclassified_columns
  )
}


# ============================================================
# Build HJW replicate groups
# ============================================================

hjw_replicate_groups <- tibble(
  replicate_column = hjw_replicate_columns
) %>%
  mutate(
    
    sample_id = str_replace(
      replicate_column,
      "^(HJW_[0-9]+)_SIR-[0-9]+_p[0-9]+$",
      "\\1"
    )
    
  ) %>%
  group_by(
    sample_id
  ) %>%
  mutate(
    n_replicates = n()
  ) %>%
  ungroup()


replicate_summary <- hjw_replicate_groups %>%
  distinct(
    sample_id,
    n_replicates
  ) %>%
  arrange(
    sample_id
  )


cat(
  "\nHJW replicate-count distribution:\n"
)

print(
  replicate_summary %>%
    count(
      n_replicates
    )
)


# ============================================================
# Validate replicate counts
# ============================================================

invalid_replicate_groups <- replicate_summary %>%
  filter(
    !n_replicates %in% c(
      2,
      3
    )
  )


if (nrow(invalid_replicate_groups) > 0) {
  
  cat(
    "\nUnexpected replicate counts:\n"
  )
  
  print(
    invalid_replicate_groups
  )
  
  stop(
    "At least one HJW sample does not have 2 or 3 ",
    "technical replicates."
  )
}


two_replicate_groups <- replicate_summary %>%
  filter(
    n_replicates == 2
  )


cat(
  "\nSamples with exactly 2 technical replicates:\n"
)

print(
  two_replicate_groups
)


# ============================================================
# Validate field metadata
# ============================================================

if (!"Parent_ID" %in% names(field_metadata)) {
  stop(
    "Parent_ID not found in HJW field metadata."
  )
}


if (!"Site_ID" %in% names(field_metadata)) {
  stop(
    "Site_ID not found in HJW field metadata."
  )
}


# ============================================================
# Build Parent_ID -> Site_ID mapping
# ============================================================

field_mapping <- field_metadata %>%
  select(
    Parent_ID,
    Site_ID
  ) %>%
  filter(
    !is.na(Parent_ID),
    Parent_ID != ""
  ) %>%
  distinct()


mapping_conflicts <- field_mapping %>%
  group_by(
    Parent_ID
  ) %>%
  summarise(
    n_site_ids = n_distinct(
      Site_ID
    ),
    .groups = "drop"
  ) %>%
  filter(
    n_site_ids > 1
  )


if (nrow(mapping_conflicts) > 0) {
  
  cat(
    "\nConflicting Parent_ID -> Site_ID mappings:\n"
  )
  
  print(
    mapping_conflicts
  )
  
  stop(
    "At least one Parent_ID maps to multiple Site_ID values."
  )
}


field_mapping <- field_mapping %>%
  distinct(
    Parent_ID,
    .keep_all = TRUE
  )


# ============================================================
# Map HJW parent samples to final names
# ============================================================

hjw_sample_mapping <- replicate_summary %>%
  left_join(
    field_mapping,
    by = c(
      "sample_id" = "Parent_ID"
    )
  ) %>%
  mutate(
    
    Site_ID = as.character(
      Site_ID
    ),
    
    final_column = if_else(
      !is.na(Site_ID) &
        Site_ID != "",
      paste0(
        "HJA_",
        Site_ID,
        "_2025"
      ),
      NA_character_
    )
    
  )


# ------------------------------------------------------------
# Check unmapped samples
# ------------------------------------------------------------

unmapped_hjw <- hjw_sample_mapping %>%
  filter(
    is.na(final_column)
  )


if (nrow(unmapped_hjw) > 0) {
  
  cat(
    "\nHJW samples that could not be mapped to Site_ID:\n"
  )
  
  print(
    unmapped_hjw
  )
  
  stop(
    "At least one HJW sample could not be mapped ",
    "to Site_ID."
  )
}


# ------------------------------------------------------------
# Check duplicate final names
# ------------------------------------------------------------

duplicate_final_names <- hjw_sample_mapping %>%
  count(
    final_column
  ) %>%
  filter(
    n > 1
  )


if (nrow(duplicate_final_names) > 0) {
  
  cat(
    "\nDuplicate final HJW sample names:\n"
  )
  
  print(
    duplicate_final_names
  )
  
  stop(
    "Multiple HJW Parent_ID values map to the same ",
    "final sample name."
  )
}


# ============================================================
# Identify peaks detected in BOTH blanks
# ============================================================

blank_matrix <- processed_data %>%
  select(
    all_of(
      blank_columns
    )
  ) %>%
  as.matrix()


blank_presence_count <- rowSums(
  blank_matrix > 0,
  na.rm = TRUE
)


blank_associated <- blank_presence_count == 2


cat(
  "\n============================================\n",
  "BLANK FILTERING\n",
  "============================================\n\n",
  sep = ""
)


cat(
  "Total molecular rows:",
  nrow(processed_data),
  "\n"
)

cat(
  "Peaks detected in BOTH blanks:",
  sum(blank_associated),
  "\n"
)


# ============================================================
# Save blank-associated peak report
# ============================================================

blank_report <- processed_data[
  blank_associated,
  c(
    feature_column,
    blank_columns
  ),
  drop = FALSE
]


write.csv(
  blank_report,
  blank_report_path,
  quote = FALSE,
  row.names = FALSE
)


# ============================================================
# Blank-clean ONLY HJW 2025 replicate columns
# ============================================================

processed_data_clean <- processed_data


processed_data_clean[
  blank_associated,
  hjw_replicate_columns
] <- 0


# ============================================================
# Start final data with calibrated mass + HJA 2016
# ============================================================

final_data <- processed_data_clean %>%
  select(
    all_of(
      feature_column
    ),
    all_of(
      hja_columns
    )
  )


# ============================================================
# Rename HJA 2016 samples
#
# Examples:
#
# HJA_155_p1
#      ->
# HJA_155_2016
#
# HJA_CC-1-15m_p1
#      ->
# HJA_CC-1-15m_2016
#
# ============================================================

hja_mapping <- tibble(
  
  original_column = hja_columns,
  
  parent_sample = str_remove(
    hja_columns,
    "_p[0-9]+$"
  ),
  
  final_column = paste0(
    str_remove(
      hja_columns,
      "_p[0-9]+$"
    ),
    "_2016"
  ),
  
  year = 2016,
  
  n_technical_replicates = 1
)


names(final_data)[
  match(
    hja_mapping$original_column,
    names(final_data)
  )
] <- hja_mapping$final_column


# ============================================================
# Merge HJW technical replicates
# ============================================================

cat(
  "\n============================================\n",
  "MERGING HJW TECHNICAL REPLICATES\n",
  "============================================\n\n",
  sep = ""
)


for (
  current_sample in unique(
    hjw_replicate_groups$sample_id
  )
) {
  
  replicate_columns <- hjw_replicate_groups %>%
    filter(
      sample_id == current_sample
    ) %>%
    pull(
      replicate_column
    )
  
  
  n_reps <- length(
    replicate_columns
  )
  
  
  replicate_matrix <- processed_data_clean %>%
    select(
      all_of(
        replicate_columns
      )
    ) %>%
    as.matrix()
  
  
  # ----------------------------------------------------------
  # Number of positive detections
  # ----------------------------------------------------------
  
  presence_count <- rowSums(
    replicate_matrix > 0,
    na.rm = TRUE
  )
  
  
  # ----------------------------------------------------------
  # Mean positive intensity only
  # ----------------------------------------------------------
  
  positive_mean <- apply(
    replicate_matrix,
    1,
    function(x) {
      
      positive_values <- x[
        !is.na(x) &
          x > 0
      ]
      
      
      if (length(positive_values) == 0) {
        
        return(
          0
        )
      }
      
      
      mean(
        positive_values
      )
    }
  )
  
  
  # ----------------------------------------------------------
  # Retention rule
  #
  # 3 reps -> >=2 positive
  # 2 reps -> both positive
  # ----------------------------------------------------------
  
  merged_intensity <- ifelse(
    presence_count >= 2,
    positive_mean,
    0
  )
  
  
  final_column_name <- hjw_sample_mapping %>%
    filter(
      sample_id == current_sample
    ) %>%
    pull(
      final_column
    )
  
  
  final_data[[final_column_name]] <- merged_intensity
  
  
  cat(
    current_sample,
    "->",
    final_column_name,
    "| replicates:",
    n_reps,
    "| retained peaks:",
    sum(
      merged_intensity > 0
    ),
    "\n"
  )
}


# ============================================================
# Build HJW mapping report
# ============================================================

hjw_mapping_report <- hjw_replicate_groups %>%
  left_join(
    hjw_sample_mapping,
    by = c(
      "sample_id",
      "n_replicates"
    )
  ) %>%
  transmute(
    
    original_column = replicate_column,
    
    parent_sample = sample_id,
    
    final_column,
    
    year = 2025,
    
    n_technical_replicates = n_replicates
  )


# ============================================================
# Full sample-name mapping
# ============================================================

sample_name_mapping <- bind_rows(
  hja_mapping,
  hjw_mapping_report
)


write.csv(
  sample_name_mapping,
  column_mapping_path,
  quote = FALSE,
  row.names = FALSE
)


# ============================================================
# Save replicate summary
# ============================================================

write.csv(
  hjw_sample_mapping,
  replicate_report_path,
  quote = FALSE,
  row.names = FALSE
)


# ============================================================
# Final sample name checks
# ============================================================

final_sample_columns <- setdiff(
  names(final_data),
  feature_column
)


bad_final_names <- final_sample_columns[
  !str_detect(
    final_sample_columns,
    "^HJA_.*_(2016|2025)$"
  )
]


if (length(bad_final_names) > 0) {
  
  cat(
    "\nUnexpected final sample names:\n"
  )
  
  print(
    bad_final_names
  )
  
  stop(
    "At least one final sample name does not follow ",
    "HJA_<site>_<year>."
  )
}


if (
  any(
    str_detect(
      final_sample_columns,
      "\\.corems"
    )
  )
) {
  
  stop(
    ".corems is still present in final sample names."
  )
}


if (
  any(
    str_detect(
      final_sample_columns,
      "_p[0-9]+"
    )
  )
) {
  
  stop(
    "Technical replicate suffixes are still present ",
    "in final sample names."
  )
}


cat(
  "\nFinal sample naming check: PASS\n"
)


# ============================================================
# Final Data/Mol alignment check
# ============================================================

if (
  nrow(final_data) !=
  nrow(processed_mol)
) {
  
  stop(
    "Final Data and Mol files do not have the same ",
    "number of rows."
  )
}


final_mass_match <- isTRUE(
  all.equal(
    final_data[[feature_column]],
    processed_mol[[feature_column]],
    tolerance = 1e-10,
    check.attributes = FALSE
  )
)


if (!final_mass_match) {
  
  stop(
    "Final Data and Mol calibrated masses are not aligned."
  )
}


cat(
  "Final Data/Mol alignment: PASS\n"
)


# ============================================================
# Save final Data and Mol
# ============================================================

write.csv(
  final_data,
  final_data_path,
  quote = FALSE,
  row.names = FALSE
)


# Mol metadata itself does not change during replicate merging
write.csv(
  processed_mol,
  final_mol_path,
  quote = FALSE,
  row.names = FALSE
)


# ============================================================
# Final summary statistics
# ============================================================

n_hja_final <- length(
  hja_columns
)

n_hjw_final <- nrow(
  hjw_sample_mapping
)

n_total_final <- ncol(
  final_data
) - 1


# ============================================================
# README
# ============================================================

two_rep_text <- if (
  nrow(two_replicate_groups) > 0
) {
  
  paste(
    two_replicate_groups$sample_id,
    collapse = ", "
  )
  
} else {
  
  "None"
}


formula_text <- if (
  is.na(formula_mismatch_count)
) {
  
  paste0(
    "Molecular Formula versus MolForm comparison was ",
    "not possible because one or both columns were absent."
  )
  
} else {
  
  paste0(
    "Number of Molecular Formula versus MolForm differences ",
    "after whitespace normalization: ",
    formula_mismatch_count,
    "."
  )
}


readme_text <- paste0(
  
  "HJA 2016 + HJW 2025 FTICR-MS post-processing\n",
  "================================================\n\n",
  
  "UPSTREAM PROCESSING\n",
  "-------------------\n",
  "Input Data and Mol files were generated using the ",
  "ESS-DIVE CoreMS_MergeProcess.Rmd workflow.\n\n",
  
  "SAMPLE NAME NORMALIZATION\n",
  "-------------------------\n",
  "The ESS-DIVE merge output retained the .corems suffix ",
  "from raw CoreMS filenames.\n",
  "The .corems suffix was removed before sample grouping ",
  "or renaming.\n\n",
  
  "DATA/MOL QA\n",
  "-----------\n",
  "Processed Data rows: ",
  nrow(processed_data),
  "\n",
  "Processed Mol rows: ",
  nrow(processed_mol),
  "\n",
  "Calibrated m/z alignment between Data and Mol: PASS\n",
  formula_text,
  "\n\n",
  
  "HJA 2016\n",
  "--------\n",
  "HJA 2016 samples were not blank filtered because ",
  "2016 blanks were not available.\n",
  "HJA 2016 intensities were otherwise unchanged.\n",
  "Technical suffixes such as _p1 were removed.\n",
  "Final naming is HJA_<site>_2016.\n\n",
  
  "HJW 2025 BLANK FILTERING\n",
  "------------------------\n",
  "Blank filtering was applied only to HJW 2025 ",
  "technical replicate columns.\n",
  "Blanks used: ",
  paste(
    blank_columns,
    collapse = ", "
  ),
  "\n",
  "A peak was considered blank-associated only when ",
  "detected in BOTH blanks.\n",
  "Blank-associated peaks were set to zero in all HJW ",
  "2025 technical replicates before replicate merging.\n",
  "Number of blank-associated rows: ",
  sum(blank_associated),
  "\n\n",
  
  "HJW 2025 TECHNICAL REPLICATE MERGING\n",
  "------------------------------------\n",
  "Technical replicate peaks were retained when detected ",
  "in at least 2 replicate files.\n",
  "For samples with 3 replicates this is a 2-of-3 rule.\n",
  "For samples with 2 replicates this is a 2-of-2 rule.\n",
  "Final intensity is the mean of positive detected ",
  "replicate intensities only.\n",
  "Samples with only 2 technical replicates: ",
  two_rep_text,
  "\n",
  "HJW Parent_ID values were mapped to Site_ID using ",
  "WHONDRS_HJW_Field_Metadata.csv.\n",
  "Final naming is HJA_<Site_ID>_2025.\n\n",
  
  "FINAL DATASET\n",
  "-------------\n",
  "HJA 2016 samples: ",
  n_hja_final,
  "\n",
  "HJW 2025 samples: ",
  n_hjw_final,
  "\n",
  "Total final samples: ",
  n_total_final,
  "\n",
  "Molecular rows: ",
  nrow(final_data),
  "\n",
  "No molecular rows were removed during blank filtering ",
  "or technical replicate merging.\n"
)


writeLines(
  readme_text,
  readme_path
)


# ============================================================
# Final console summary
# ============================================================

cat(
  "\n============================================\n",
  "SCRIPT 04 COMPLETE\n",
  "============================================\n\n",
  sep = ""
)


cat(
  "Molecular rows:",
  nrow(final_data),
  "\n"
)

cat(
  "Blank-associated peaks:",
  sum(blank_associated),
  "\n"
)

cat(
  "HJA 2016 final samples:",
  n_hja_final,
  "\n"
)

cat(
  "HJW 2025 final samples:",
  n_hjw_final,
  "\n"
)

cat(
  "Total final samples:",
  n_total_final,
  "\n\n"
)


cat(
  "First 10 final sample names:\n"
)

print(
  head(
    final_sample_columns,
    10
  )
)


cat(
  "\nFinal Data:\n",
  final_data_path,
  "\n\n"
)

cat(
  "Final Mol:\n",
  final_mol_path,
  "\n\n"
)

cat(
  "Sample-name mapping:\n",
  column_mapping_path,
  "\n\n"
)

cat(
  "Blank report:\n",
  blank_report_path,
  "\n\n"
)

cat(
  "Replicate summary:\n",
  replicate_report_path,
  "\n\n"
)

cat(
  "Formula comparison:\n",
  formula_report_path,
  "\n\n"
)

cat(
  "README:\n",
  readme_path,
  "\n"
)