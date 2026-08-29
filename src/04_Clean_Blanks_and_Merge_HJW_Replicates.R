library(tidyverse)

# ============================================================
# 04 - Blank clean HJW 2025 and merge technical replicates
#
# Input:
#   Merged_Output/HJA_2016_HJW_2025-Processed_Data.csv
#
# Rules:
#   - Blank filtering applies ONLY to HJW 2025
#   - A peak is considered blank-associated only if detected
#     in BOTH 2025 blanks
#   - Blank-associated peaks are set to zero in HJW 2025
#     technical replicates
#   - HJA 2016 samples are not blank filtered
#   - HJW technical replicates are retained if detected in
#     at least 2 replicates
#       3 reps -> 2 of 3
#       2 reps -> 2 of 2
#   - Retained intensity = mean of positive replicate values
# ============================================================


# ------------------------------------------------------------
# Paths
# ------------------------------------------------------------

processed_data_path <- paste0(
  "Merged_Output/",
  "HJA_2016_HJW_2025-Processed_Data.csv"
)

field_mapping_path <- paste0(
  "v2_WHONDRS_HJW_Sample_Data/",
  "WHONDRS_HJW_Field_Metadata.csv"
)

merged_output_path <- paste0(
  "Merged_Output/",
  "HJA_2016_HJW_2025-Processed_Data_HJW_replicates_merged.csv"
)

blank_report_path <- paste0(
  "Merged_Output/",
  "HJA_2016_HJW_2025-blank_associated_peaks.csv"
)

replicate_report_path <- paste0(
  "Merged_Output/",
  "HJA_2016_HJW_2025-HJW_replicate_counts.csv"
)

column_mapping_path <- paste0(
  "Merged_Output/",
  "HJA_2016_HJW_2025-column_name_mapping.csv"
)

readme_path <- paste0(
  "Merged_Output/",
  "README_HJA_2016_HJW_2025_postprocessing.txt"
)


# ------------------------------------------------------------
# Load data
# ------------------------------------------------------------

processed_data <- read.csv(
  processed_data_path,
  check.names = FALSE
)

field_mapping <- read.csv(
  field_mapping_path,
  check.names = FALSE
)


# ------------------------------------------------------------
# Identify columns
# ------------------------------------------------------------

feature_column <- "Calibrated m/z"

if (!feature_column %in% names(processed_data)) {
  stop("Could not find 'Calibrated m/z' in processed data.")
}

sample_columns <- setdiff(
  names(processed_data),
  feature_column
)


# 2016 HJA samples
hja_columns <- sample_columns[
  str_detect(
    sample_columns,
    "^HJA_"
  )
]


# 2025 HJW sediment technical replicates
hjw_replicate_columns <- sample_columns[
  str_detect(
    sample_columns,
    "^HJW_[0-9]+_SIR-[0-9]+_p[0-9]+$"
  )
]


# HJW blanks
blank_columns <- sample_columns[
  str_detect(
    sample_columns,
    "^HJW_.*Blk"
  )
]


cat("\n2016 HJA columns:", length(hja_columns), "\n")
cat(
  "2025 HJW replicate columns:",
  length(hjw_replicate_columns),
  "\n"
)
cat(
  "2025 blank columns:",
  length(blank_columns),
  "\n\n"
)

print(blank_columns)


# ------------------------------------------------------------
# Check blanks
# ------------------------------------------------------------

if (length(blank_columns) != 2) {
  stop(
    "Expected exactly 2 HJW blank columns, but found ",
    length(blank_columns)
  )
}


# ------------------------------------------------------------
# Identify peaks present in BOTH blanks
# ------------------------------------------------------------

blank_matrix <- processed_data %>%
  select(
    all_of(blank_columns)
  ) %>%
  as.matrix()


blank_presence <- rowSums(
  blank_matrix > 0,
  na.rm = TRUE
)


blank_detected <- blank_presence == 2


cat(
  "Peaks detected in both blanks:",
  sum(blank_detected),
  "\n"
)


# ------------------------------------------------------------
# Save blank-associated peak report
# ------------------------------------------------------------

blank_report <- processed_data[
  blank_detected,
  c(
    feature_column,
    blank_columns
  )
]

write.csv(
  blank_report,
  blank_report_path,
  quote = FALSE,
  row.names = FALSE
)


# ------------------------------------------------------------
# Blank-clean ONLY HJW 2025 replicate columns
# ------------------------------------------------------------

processed_data_clean <- processed_data


processed_data_clean[
  blank_detected,
  hjw_replicate_columns
] <- 0


# ------------------------------------------------------------
# Group HJW technical replicates
# ------------------------------------------------------------

hjw_replicate_groups <- tibble(
  column = hjw_replicate_columns
) %>%
  mutate(
    sample_id = str_replace(
      column,
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


replicate_count_check <- hjw_replicate_groups %>%
  distinct(
    sample_id,
    n_replicates
  )


print(
  replicate_count_check %>%
    count(
      n_replicates
    )
)


write.csv(
  replicate_count_check,
  replicate_report_path,
  quote = FALSE,
  row.names = FALSE
)


# ------------------------------------------------------------
# Check replicate counts
# ------------------------------------------------------------

if (
  any(
    replicate_count_check$n_replicates < 2
  )
) {
  
  print(
    replicate_count_check %>%
      filter(
        n_replicates < 2
      )
  )
  
  stop(
    "At least one HJW sample has fewer than 2 replicates."
  )
}


two_replicate_groups <- replicate_count_check %>%
  filter(
    n_replicates == 2
  )


if (
  nrow(two_replicate_groups) > 0
) {
  
  cat(
    "\nSamples with only 2 technical replicates:\n"
  )
  
  print(
    two_replicate_groups
  )
}


# ------------------------------------------------------------
# Map HJW Parent_ID to final HJA Site_ID
# ------------------------------------------------------------

hjw_sample_mapping <- hjw_replicate_groups %>%
  distinct(
    sample_id
  ) %>%
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
      !is.na(Site_ID),
      paste0(
        "HJA_",
        Site_ID,
        "_2025"
      ),
      sample_id
    )
  ) %>%
  select(
    sample_id,
    Site_ID,
    final_column
  )


# Check for samples that failed to map
unmapped <- hjw_sample_mapping %>%
  filter(
    is.na(Site_ID)
  )


if (
  nrow(unmapped) > 0
) {
  
  cat(
    "\nWARNING: HJW samples not found in field metadata:\n"
  )
  
  print(
    unmapped
  )
}


# ------------------------------------------------------------
# Start final output with calibrated mass + HJA 2016
# ------------------------------------------------------------

merged_data <- processed_data_clean %>%
  select(
    all_of(feature_column),
    all_of(hja_columns)
  )


# ------------------------------------------------------------
# Rename HJA 2016 samples
# ------------------------------------------------------------

hja_mapping <- tibble(
  original_column = hja_columns,
  final_column = str_replace(
    hja_columns,
    "_p[0-9]+$",
    "_2016"
  ),
  year = 2016
)


names(merged_data)[
  match(
    hja_mapping$original_column,
    names(merged_data)
  )
] <- hja_mapping$final_column


# ------------------------------------------------------------
# Merge HJW technical replicates
# ------------------------------------------------------------

for (
  sample_id in unique(
    hjw_replicate_groups$sample_id
  )
) {
  
  replicate_columns <- hjw_replicate_groups %>%
    filter(
      sample_id == !!sample_id
    ) %>%
    pull(
      column
    )
  
  
  replicate_matrix <- processed_data_clean %>%
    select(
      all_of(replicate_columns)
    ) %>%
    as.matrix()
  
  
  # Number of replicates with positive detection
  presence_count <- rowSums(
    replicate_matrix > 0,
    na.rm = TRUE
  )
  
  
  # Mean of positive detected intensities
  merged_intensity <- apply(
    replicate_matrix,
    1,
    function(x) {
      
      detected_values <- x[
        !is.na(x) &
          x > 0
      ]
      
      if (
        length(detected_values) >= 2
      ) {
        
        mean(
          detected_values
        )
        
      } else {
        
        0
        
      }
    }
  )
  
  
  final_column <- hjw_sample_mapping %>%
    filter(
      sample_id == !!sample_id
    ) %>%
    pull(
      final_column
    )
  
  
  # >=2 means:
  #   2 of 3 for normal samples
  #   2 of 2 for samples with only 2 replicates
  merged_data[
    [final_column]
  ] <- if_else(
    presence_count >= 2,
    merged_intensity,
    0
  )
}


# ------------------------------------------------------------
# Column mapping report
# ------------------------------------------------------------

hjw_column_mapping <- hjw_replicate_groups %>%
  left_join(
    hjw_sample_mapping,
    by = "sample_id"
  ) %>%
  transmute(
    original_column = column,
    final_column = final_column,
    year = 2025
  )


column_mapping <- bind_rows(
  hja_mapping,
  hjw_column_mapping
)


write.csv(
  column_mapping,
  column_mapping_path,
  quote = FALSE,
  row.names = FALSE
)


# ------------------------------------------------------------
# Save final matrix
# ------------------------------------------------------------

write.csv(
  merged_data,
  merged_output_path,
  quote = FALSE,
  row.names = FALSE
)


# ------------------------------------------------------------
# README
# ------------------------------------------------------------

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


readme_text <- paste0(
  
  "HJA 2016 + HJW 2025 FTICR-MS post-processing\n",
  "================================================\n\n",
  
  "Input:\n",
  "- HJA_2016_HJW_2025-Processed_Data.csv\n",
  "- Generated using the ESS-DIVE CoreMS merge workflow.\n\n",
  
  "HJA 2016:\n",
  "- HJA 2016 samples were not blank filtered because ",
  "2016 blanks were not available.\n",
  "- HJA 2016 sample columns were retained unchanged except ",
  "for addition of the _2016 suffix.\n\n",
  
  "HJW 2025 blank filtering:\n",
  "- Blank filtering was applied only to HJW 2025 ",
  "technical replicate columns.\n",
  "- Blanks used: ",
  paste(
    blank_columns,
    collapse = ", "
  ),
  "\n",
  "- A peak was considered blank-associated only when ",
  "detected in BOTH blanks.\n",
  "- Blank-associated peaks were set to zero in all HJW ",
  "2025 technical replicate columns.\n",
  "- Number of blank-associated peaks: ",
  sum(blank_detected),
  "\n\n",
  
  "HJW 2025 technical replicate merging:\n",
  "- Peaks were retained when detected in at least ",
  "2 technical replicates.\n",
  "- Samples with 3 replicates therefore use a 2-of-3 rule.\n",
  "- Samples with 2 replicates use a 2-of-2 rule.\n",
  "- Retained peak intensity is the mean of positive ",
  "replicate intensities only.\n",
  "- Samples with only 2 technical replicates: ",
  two_rep_text,
  "\n",
  "- Final 2025 columns were renamed HJA_<Site_ID>_2025.\n\n",
  
  "Important:\n",
  "- Molecular rows were NOT removed from the dataset.\n",
  "- This preserves row correspondence with the processed ",
  "Mol file.\n"
)


writeLines(
  readme_text,
  readme_path
)


# ------------------------------------------------------------
# Final summary
# ------------------------------------------------------------

cat("\nDone.\n")

cat(
  "Blank-associated peaks:",
  sum(blank_detected),
  "\n"
)

cat(
  "HJA 2016 final samples:",
  length(hja_columns),
  "\n"
)

cat(
  "HJW 2025 final samples:",
  nrow(hjw_sample_mapping),
  "\n"
)

cat(
  "Final data matrix:",
  merged_output_path,
  "\n"
)

cat(
  "README:",
  readme_path,
  "\n"
)