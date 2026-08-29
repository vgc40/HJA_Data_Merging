library(tidyverse)

# ============================================================
# 02 - Check CoreMS file structure before merging
#
# Compare column names across:
# - HJA 2016 sediment
# - HJW 2025 sediment replicates
# - HJW 2025 blanks
#
# No data are modified.
# ============================================================


# ------------------------------------------------------------
# Files collected in Step 01
# ------------------------------------------------------------

files <- list.files(
  "CoreMS_Output",
  pattern = "\\.corems\\.csv$",
  full.names = TRUE
)


# ------------------------------------------------------------
# Read only the header of each file
# ------------------------------------------------------------

column_check <- lapply(files, function(file) {
  
  x <- read.csv(
    file,
    nrows = 1,
    check.names = FALSE
  )
  
  tibble(
    file_name = basename(file),
    n_columns = ncol(x),
    columns = paste(names(x), collapse = " | ")
  )
}) %>%
  bind_rows()


# ------------------------------------------------------------
# Identify sample type
# ------------------------------------------------------------

column_check <- column_check %>%
  mutate(
    source = case_when(
      str_detect(file_name, "^HJA_") ~ "HJA_2016",
      str_detect(file_name, "^HJW_Blk") ~ "HJW_2025_blank",
      str_detect(file_name, "^HJW_") ~ "HJW_2025_sediment",
      TRUE ~ "unknown"
    )
  )


# ------------------------------------------------------------
# Print unique schemas
# ------------------------------------------------------------

schema_summary <- column_check %>%
  distinct(
    source,
    n_columns,
    columns
  )

print(
  schema_summary,
  n = Inf
)


# ------------------------------------------------------------
# Count how many schemas occur within each source
# ------------------------------------------------------------

schema_counts <- column_check %>%
  count(
    source,
    n_columns,
    columns,
    name = "n_files"
  )

print(
  schema_counts,
  n = Inf
)


# ------------------------------------------------------------
# Check key columns individually
# ------------------------------------------------------------

key_columns <- c(
  "Calibrated_Mass",
  "Calibrated m/z",
  "Calculated_Mass",
  "Calculated m/z",
  "Peak_Height",
  "Peak Height",
  "Error_ppm",
  "m/z Error (ppm)",
  "Confidence_Score",
  "Confidence Score",
  "Heteroatom_Class",
  "Heteroatom Class",
  "Is_Isotopologue",
  "Is Isotopologue",
  "Molecular_Formula",
  "Molecular Formula",
  "C",
  "H",
  "O",
  "N",
  "P",
  "S"
)


key_column_check <- lapply(files, function(file) {
  
  x <- read.csv(
    file,
    nrows = 1,
    check.names = FALSE
  )
  
  tibble(
    file_name = basename(file),
    column = key_columns,
    present = key_columns %in% names(x)
  )
}) %>%
  bind_rows() %>%
  mutate(
    source = case_when(
      str_detect(file_name, "^HJA_") ~ "HJA_2016",
      str_detect(file_name, "^HJW_Blk") ~ "HJW_2025_blank",
      str_detect(file_name, "^HJW_") ~ "HJW_2025_sediment",
      TRUE ~ "unknown"
    )
  )


key_summary <- key_column_check %>%
  group_by(
    source,
    column
  ) %>%
  summarise(
    files_with_column = sum(present),
    total_files = n(),
    .groups = "drop"
  ) %>%
  filter(files_with_column > 0)

print(
  key_summary,
  n = Inf
)


# ------------------------------------------------------------
# Save reports
# ------------------------------------------------------------

write.csv(
  column_check,
  "CoreMS_Output/CoreMS_column_check.csv",
  quote = FALSE,
  row.names = FALSE
)

write.csv(
  key_summary,
  "CoreMS_Output/CoreMS_key_column_check.csv",
  quote = FALSE,
  row.names = FALSE
)


# ------------------------------------------------------------
# Summary
# ------------------------------------------------------------

cat("\nDone.\n")
cat("Total CoreMS files checked:", length(files), "\n")
cat("Unique schemas found:", nrow(schema_summary), "\n")