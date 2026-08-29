library(tidyverse)

# Merge HJW technical replicates in the processed CoreMS/ftmsRanalysis matrix.
# HJA 2016 samples are retained as-is and renamed to include the 2016 year.
# HJW 2025 peaks detected in BOTH MQ blanks are removed before replicate merging.
# HJW samples are then merged by keeping peaks present in at least 2 replicates.
# Most samples have 3 replicates, but samples with only 2 replicates are retained
# and therefore require the peak to be present in both.

# ------------------------------------------------------------
# File paths
# ------------------------------------------------------------

processed_data_path <- "Merged_Output/HJA_2016_HJW_2025-Processed_Data.csv"
field_mapping_path <- "Data/WHONDRS_HJW_Field_Metadata.csv"

merged_output_path <- "Merged_Output/HJA_2016_HJW_2025-Processed_Data_HJW_replicates_merged.csv"
column_mapping_output_path <- "Merged_Output/HJA_2016_HJW_2025-column_name_mapping.csv"
blank_report_output_path <- "Merged_Output/HJA_2016_HJW_2025-2025_blank_peaks_removed.csv"
readme_output_path <- "Merged_Output/README_HJA_2016_HJW_2025_processing.txt"


# ------------------------------------------------------------
# Read data
# ------------------------------------------------------------

processed_data <- read.csv(processed_data_path, check.names = FALSE)
field_mapping <- read.csv(field_mapping_path, check.names = FALSE)

feature_column <- "Calibrated m/z"
sample_columns <- setdiff(names(processed_data), feature_column)


# ------------------------------------------------------------
# Identify sample columns
# ------------------------------------------------------------

# HJA 2016 samples
hja_columns <- sample_columns[
  str_detect(sample_columns, "^HJA_")
]

# HJW 2025 technical replicates
hjw_replicate_columns <- sample_columns[
  str_detect(sample_columns, "^HJW_[0-9]+_SIR-[0-9]+_p[0-9]+$")
]

# HJW 2025 blanks
blank_columns <- sample_columns[
  str_detect(sample_columns, "^HJW_MQ_Blk")
]

# Other HJW columns
hjw_unmapped_columns <- sample_columns[
  str_detect(sample_columns, "^HJW_") &
    !sample_columns %in% c(hjw_replicate_columns, blank_columns)
]

# Anything else
other_columns <- setdiff(
  sample_columns,
  c(
    hja_columns,
    hjw_replicate_columns,
    blank_columns,
    hjw_unmapped_columns
  )
)


# ------------------------------------------------------------
# Check blanks
# ------------------------------------------------------------

print(blank_columns)

if (length(blank_columns) != 2) {
  stop("Expected exactly 2 HJW MQ blank columns.")
}


# ------------------------------------------------------------
# Identify peaks present in BOTH 2025 blanks
# ------------------------------------------------------------

blank_matrix <- processed_data %>%
  select(all_of(blank_columns)) %>%
  as.matrix()

blank_presence <- rowSums(
  blank_matrix > 0,
  na.rm = TRUE
)

blank_detected <- blank_presence == 2

message(
  "Peaks detected in both 2025 blanks: ",
  sum(blank_detected)
)


# Save blank peak report
blank_report <- processed_data[
  blank_detected,
  c(feature_column, blank_columns)
]

write.csv(
  blank_report,
  blank_report_output_path,
  quote = FALSE,
  row.names = FALSE
)


# ------------------------------------------------------------
# Remove blank-associated peaks ONLY from 2025 replicates
# ------------------------------------------------------------

processed_data_clean <- processed_data

processed_data_clean[
  blank_detected,
  hjw_replicate_columns
] <- 0


# ------------------------------------------------------------
# HJA 2016 column mapping
# ------------------------------------------------------------

hja_column_mapping <- tibble(
  original_column = hja_columns,
  merged_column = hja_columns,
  Site_ID = str_match(
    hja_columns,
    "^HJA_(.+)_p[0-9]+$"
  )[, 2],
  final_column = str_replace(
    hja_columns,
    "_p[0-9]+$",
    "_2016"
  ),
  rename_type = "HJA 2016 sample"
)


# ------------------------------------------------------------
# Other column mappings
# ------------------------------------------------------------

hjw_unmapped_column_mapping <- tibble(
  original_column = hjw_unmapped_columns,
  merged_column = hjw_unmapped_columns,
  Site_ID = NA_character_,
  final_column = hjw_unmapped_columns,
  rename_type = "HJW column not merged or mapped"
)

other_column_mapping <- tibble(
  original_column = other_columns,
  merged_column = other_columns,
  Site_ID = NA_character_,
  final_column = other_columns,
  rename_type = "unchanged non-HJA/HJW column"
)


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
  group_by(sample_id) %>%
  mutate(
    n_replicates = n()
  ) %>%
  ungroup()


# ------------------------------------------------------------
# Check replicate counts
# ------------------------------------------------------------

replicate_count_check <- hjw_replicate_groups %>%
  distinct(
    sample_id,
    n_replicates
  )

print(
  replicate_count_check %>%
    count(n_replicates)
)

two_replicate_groups <- replicate_count_check %>%
  filter(n_replicates == 2)

if (nrow(two_replicate_groups) > 0) {
  message("Samples with only 2 technical replicates:")
  print(two_replicate_groups)
}

if (any(replicate_count_check$n_replicates < 2)) {
  stop("At least one HJW sample has fewer than 2 technical replicates.")
}


# ------------------------------------------------------------
# Map HJW sample IDs to HJA site IDs
# ------------------------------------------------------------

hjw_sample_mapping <- hjw_replicate_groups %>%
  distinct(sample_id) %>%
  left_join(
    field_mapping,
    by = c("sample_id" = "Parent_ID")
  ) %>%
  mutate(
    Site_ID = as.character(Site_ID),
    
    final_column = if_else(
      !is.na(Site_ID),
      paste0("HJA_", Site_ID, "_2025"),
      sample_id
    ),
    
    rename_type = if_else(
      !is.na(Site_ID),
      "HJW replicate group mapped to HJA 2025 sample",
      "HJW replicate group not found in field mapping"
    )
  ) %>%
  select(
    sample_id,
    Site_ID,
    final_column,
    rename_type
  )


# ------------------------------------------------------------
# Replicate column mapping
# ------------------------------------------------------------

replicate_column_mapping <- hjw_replicate_groups %>%
  left_join(
    hjw_sample_mapping,
    by = "sample_id"
  ) %>%
  transmute(
    original_column = column,
    merged_column = sample_id,
    Site_ID = Site_ID,
    final_column = final_column,
    rename_type = rename_type
  )


# ------------------------------------------------------------
# Start merged dataset
#
# Blanks are not included.
# ------------------------------------------------------------

merged_data <- processed_data_clean %>%
  select(
    all_of(feature_column),
    all_of(hja_columns),
    all_of(hjw_unmapped_columns),
    all_of(other_columns)
  )


# Rename HJA samples with 2016 year
names(merged_data)[
  match(
    hja_column_mapping$original_column,
    names(merged_data)
  )
] <- hja_column_mapping$final_column


# ------------------------------------------------------------
# Merge HJW 2025 technical replicates
#
# Rule:
# 3 replicates -> peak must occur in at least 2 of 3
# 2 replicates -> peak must occur in both 2 of 2
#
# Both are handled by presence_count >= 2.
# ------------------------------------------------------------

for (sample_id in unique(hjw_replicate_groups$sample_id)) {
  
  replicate_columns <- hjw_replicate_groups %>%
    filter(sample_id == !!sample_id) %>%
    pull(column)
  
  replicate_matrix <- processed_data_clean %>%
    select(all_of(replicate_columns)) %>%
    as.matrix()
  
  presence_count <- rowSums(
    replicate_matrix > 0,
    na.rm = TRUE
  )
  
  merged_intensity <- apply(
    replicate_matrix,
    1,
    function(x) {
      
      detected_values <- x[
        !is.na(x) & x > 0
      ]
      
      if (length(detected_values) >= 2) {
        mean(detected_values)
      } else {
        0
      }
    }
  )
  
  final_column <- hjw_sample_mapping %>%
    filter(sample_id == !!sample_id) %>%
    pull(final_column)
  
  merged_data[[final_column]] <- if_else(
    presence_count >= 2,
    merged_intensity,
    0
  )
}


# ------------------------------------------------------------
# Column mapping table
# ------------------------------------------------------------

column_mapping <- bind_rows(
  hja_column_mapping,
  hjw_unmapped_column_mapping,
  other_column_mapping,
  replicate_column_mapping
) %>%
  arrange(
    rename_type,
    original_column
  )


# ------------------------------------------------------------
# Write merged outputs
# ------------------------------------------------------------

write.csv(
  merged_data,
  merged_output_path,
  quote = FALSE,
  row.names = FALSE
)

write.csv(
  column_mapping,
  column_mapping_output_path,
  quote = FALSE,
  row.names = FALSE
)


# ------------------------------------------------------------
# Write simple processing README
# ------------------------------------------------------------

two_rep_text <- if (nrow(two_replicate_groups) > 0) {
  paste(
    two_replicate_groups$sample_id,
    collapse = ", "
  )
} else {
  "None"
}

readme_text <- paste0(
  "HJA 2016 + HJW 2025 FTICR-MS processing\n",
  "=======================================\n\n",
  
  "HJA 2016:\n",
  "- HJA 2016 samples were not blank filtered because 2016 blanks were not available.\n",
  "- Samples were renamed HJA_<Site_ID>_2016.\n\n",
  
  "HJW 2025 blank filtering:\n",
  "- Blank filtering was applied only to HJW 2025 technical replicates.\n",
  "- Blanks used: ",
  paste(blank_columns, collapse = ", "),
  "\n",
  "- A calibrated m/z peak was removed from the 2025 replicate data only when detected in BOTH blanks.\n",
  "- Number of blank-associated peaks: ",
  sum(blank_detected),
  "\n\n",
  
  "HJW 2025 technical replicate merging:\n",
  "- Peaks were retained when detected in at least 2 technical replicates.\n",
  "- For samples with 3 replicates, this is a 2-of-3 rule.\n",
  "- For samples with 2 replicates, this is a 2-of-2 rule.\n",
  "- Retained peak intensity was the mean of the positive replicate intensities.\n",
  "- Samples with only 2 technical replicates: ",
  two_rep_text,
  "\n",
  "- Merged samples were renamed HJA_<Site_ID>_2025.\n"
)

writeLines(
  readme_text,
  readme_output_path
)


# ------------------------------------------------------------
# Final summary
# ------------------------------------------------------------

message("Done.")

message(
  "Peaks removed from 2025 because present in both blanks: ",
  sum(blank_detected)
)

message(
  "Merged data: ",
  merged_output_path
)

message(
  "Column mapping: ",
  column_mapping_output_path
)

message(
  "Blank report: ",
  blank_report_output_path
)

message(
  "README: ",
  readme_output_path
)