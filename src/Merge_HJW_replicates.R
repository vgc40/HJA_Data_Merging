library(tidyverse)

# Merge HJW technical replicates in the processed CoreMS/ftmsRanalysis matrix.
# HJA samples are retained as-is and renamed to include the 2016 collection year.
# HJW samples are merged by keeping peaks present in at least two replicate columns,
# then renamed with the HJA site code from the field metadata and the 2025 year.

processed_data_path <- "Merged_Output/HJA_2016_HJW_2025-Processed_Data.csv"
field_mapping_path <- "Data/WHONDRS_HJW_Field_Metadata.csv"
merged_output_path <- "Merged_Output/HJA_2016_HJW_2025-Processed_Data_HJW_replicates_merged.csv"
column_mapping_output_path <- "Merged_Output/HJA_2016_HJW_2025-column_name_mapping.csv"

processed_data <- read.csv(processed_data_path, check.names = FALSE)
field_mapping <- read.csv(field_mapping_path, check.names = FALSE)

feature_column <- "Calibrated m/z"
sample_columns <- setdiff(names(processed_data), feature_column)

hja_columns <- sample_columns[str_detect(sample_columns, "^HJA_")]
hjw_replicate_columns <- sample_columns[str_detect(sample_columns, "^HJW_[0-9]+_SIR-[0-9]+_p[0-9]+$")]
hjw_unmapped_columns <- sample_columns[str_detect(sample_columns, "^HJW_") & !sample_columns %in% hjw_replicate_columns]
other_columns <- setdiff(sample_columns, c(hja_columns, hjw_replicate_columns, hjw_unmapped_columns))

hja_column_mapping <- tibble(
  original_column = hja_columns,
  merged_column = hja_columns,
  Site_ID = str_match(hja_columns, "^HJA_(.+)_p[0-9]+$")[, 2],
  final_column = str_replace(hja_columns, "_p[0-9]+$", "_2016"),
  rename_type = "HJA 2016 sample"
)

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

hjw_replicate_groups <- tibble(column = hjw_replicate_columns) %>%
  mutate(
    sample_id = str_replace(column, "^(HJW_[0-9]+)_SIR-[0-9]+_p[0-9]+$", "\\1")
  ) %>%
  group_by(sample_id) %>%
  mutate(n_replicates = n()) %>%
  ungroup()

hjw_sample_mapping <- hjw_replicate_groups %>%
  distinct(sample_id) %>%
  left_join(field_mapping, by = c("sample_id" = "Parent_ID")) %>%
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
  select(sample_id, Site_ID, final_column, rename_type)

replicate_column_mapping <- hjw_replicate_groups %>%
  left_join(hjw_sample_mapping, by = "sample_id") %>%
  transmute(
    original_column = column,
    merged_column = sample_id,
    Site_ID = Site_ID,
    final_column = final_column,
    rename_type = rename_type
  )

merged_data <- processed_data %>%
  select(all_of(feature_column), all_of(hja_columns), all_of(hjw_unmapped_columns), all_of(other_columns))

names(merged_data)[match(hja_column_mapping$original_column, names(merged_data))] <- hja_column_mapping$final_column

for (sample_id in unique(hjw_replicate_groups$sample_id)) {
  replicate_columns <- hjw_replicate_groups %>%
    filter(sample_id == !!sample_id) %>%
    pull(column)

  replicate_matrix <- processed_data %>%
    select(all_of(replicate_columns)) %>%
    as.matrix()

  presence_count <- rowSums(replicate_matrix > 0, na.rm = TRUE)

  merged_intensity <- apply(replicate_matrix, 1, function(x) {
    detected_values <- x[!is.na(x) & x > 0]

    if (length(detected_values) >= 2) {
      mean(detected_values)
    } else {
      0
    }
  })

  final_column <- hjw_sample_mapping %>%
    filter(sample_id == !!sample_id) %>%
    pull(final_column)

  merged_data[[final_column]] <- if_else(presence_count >= 2, merged_intensity, 0)
}

column_mapping <- bind_rows(
  hja_column_mapping,
  hjw_unmapped_column_mapping,
  other_column_mapping,
  replicate_column_mapping
) %>%
  arrange(rename_type, original_column)

write.csv(merged_data, merged_output_path, quote = FALSE, row.names = FALSE)
write.csv(column_mapping, column_mapping_output_path, quote = FALSE, row.names = FALSE)

message("Wrote merged HJW replicate matrix to: ", merged_output_path)
message("Wrote column name mapping to: ", column_mapping_output_path)
