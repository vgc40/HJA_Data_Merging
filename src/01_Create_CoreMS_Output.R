library(tidyverse)

# ============================================================
# 01 - Create combined CoreMS_Output folder
#
# Collect:
# - 2016 HJA sediment CoreMS CSV files
# - 2025 HJW sediment CoreMS CSV files
# - 2025 HJW blank CoreMS CSV files
#
# Source files are copied unchanged first. Elemental absence codes are then
# normalized only in the staged CoreMS_Output copies used by this project.
# ============================================================


# ------------------------------------------------------------
# Source folders
# ------------------------------------------------------------

hja_2016_dir <- paste0(
  "WHONDRS_HJA_2016_Sample_Data/",
  "WHONDRS_HJA_2016_Sample_Data/",
  "Sediment_CoreMS_Output_Files"
)

hjw_2025_dir <- paste0(
  "v2_WHONDRS_HJW_Sample_Data/",
  "v2_WHONDRS_HJW_Sample_Data/",
  "FTICR/",
  "Sediment_CoreMS_Output_Files"
)

hjw_2025_blank_dir <- paste0(
  "v2_WHONDRS_HJW_Sample_Data/",
  "v2_WHONDRS_HJW_Sample_Data/",
  "FTICR/",
  "Blanks_CoreMS_Output_Files"
)

output_dir <- "CoreMS_Output"


# ------------------------------------------------------------
# Create output folder
# ------------------------------------------------------------

if (!dir.exists(output_dir)) {
  dir.create(output_dir)
}


# ------------------------------------------------------------
# Find CoreMS CSV files
# ------------------------------------------------------------

hja_2016_files <- list.files(
  hja_2016_dir,
  pattern = "\\.corems\\.csv$",
  full.names = TRUE
)

hjw_2025_files <- list.files(
  hjw_2025_dir,
  pattern = "\\.corems\\.csv$",
  full.names = TRUE
)

hjw_2025_blank_files <- list.files(
  hjw_2025_blank_dir,
  pattern = "\\.corems\\.csv$",
  full.names = TRUE
)


# ------------------------------------------------------------
# Print what was found
# ------------------------------------------------------------

cat("\n2016 sediment files:", length(hja_2016_files), "\n")
cat("2025 sediment replicate files:", length(hjw_2025_files), "\n")
cat("2025 blank files:", length(hjw_2025_blank_files), "\n\n")

cat("2025 blanks:\n")
print(basename(hjw_2025_blank_files))


# ------------------------------------------------------------
# Check blanks
# ------------------------------------------------------------

if (length(hjw_2025_blank_files) != 2) {
  stop(
    "Expected exactly 2 HJW 2025 blank CoreMS files, but found ",
    length(hjw_2025_blank_files)
  )
}


# ------------------------------------------------------------
# Combine file list
# ------------------------------------------------------------

all_files <- c(
  hja_2016_files,
  hjw_2025_files,
  hjw_2025_blank_files
)


# ------------------------------------------------------------
# Make sure filenames are unique
# ------------------------------------------------------------

if (any(duplicated(basename(all_files)))) {
  stop(
    "Duplicate filenames found between source folders."
  )
}


# ------------------------------------------------------------
# Copy files into CoreMS_Output
# ------------------------------------------------------------

copy_success <- file.copy(
  from = all_files,
  to = output_dir,
  overwrite = TRUE
)

if (any(!copy_success)) {
  stop(
    "Failed to copy: ",
    paste(basename(all_files[!copy_success]), collapse = ", ")
  )
}


# ------------------------------------------------------------
# Normalize elemental counts in staged copies only
# ------------------------------------------------------------

element_columns <- c("C", "H", "O", "N", "S", "P")
staged_files <- file.path(output_dir, basename(all_files))
element_replacement_counts <- integer(length(staged_files))

for (file_index in seq_along(staged_files)) {
  staged_file <- staged_files[file_index]
  staged_data <- read.csv(
    staged_file,
    check.names = FALSE,
    stringsAsFactors = FALSE
  )

  required_elements <- c("C", "H", "O")
  missing_required_elements <- setdiff(required_elements, names(staged_data))
  if (length(missing_required_elements) > 0) {
    stop(
      "Missing required elemental columns in ", basename(staged_file), ": ",
      paste(missing_required_elements, collapse = ", ")
    )
  }

  missing_optional_elements <- setdiff(c("N", "S", "P"), names(staged_data))
  if (length(missing_optional_elements) > 0) {
    staged_data[missing_optional_elements] <- 0
  }

  element_values_before <- as.matrix(staged_data[element_columns])
  element_replacement_counts[file_index] <- sum(
    is.na(element_values_before) | element_values_before == -9999
  )

  staged_data <- staged_data %>%
    mutate(across(
      all_of(element_columns),
      ~ ifelse(is.na(.x) | .x == -9999, 0, as.numeric(.x))
    ))

  element_values_after <- unlist(
    staged_data[element_columns],
    use.names = FALSE
  )

  if (any(is.na(element_values_after))) {
    stop(
      "Elemental counts could not be converted to numeric values in ",
      basename(staged_file)
    )
  }

  if (any(element_values_after < 0 |
          element_values_after != round(element_values_after))) {
    stop(
      "Elemental counts must be non-negative whole numbers in ",
      basename(staged_file)
    )
  }

  write.csv(
    staged_data,
    staged_file,
    quote = FALSE,
    row.names = FALSE,
    na = ""
  )
}

cat(
  "Elemental NA/-9999 values replaced with zero in staged copies:",
  sum(element_replacement_counts),
  "\n"
)


# ------------------------------------------------------------
# Check output
# ------------------------------------------------------------

copied_files <- list.files(
  output_dir,
  pattern = "\\.corems\\.csv$"
)

cat("\nFiles copied to CoreMS_Output:", length(copied_files), "\n")

if (length(copied_files) != length(all_files)) {
  stop(
    "Number of files in CoreMS_Output does not match ",
    "number of source files."
  )
}


# ------------------------------------------------------------
# Create simple manifest
# ------------------------------------------------------------

manifest <- tibble(
  file_name = basename(all_files),
  source = c(
    rep("HJA_2016_sediment", length(hja_2016_files)),
    rep("HJW_2025_sediment", length(hjw_2025_files)),
    rep("HJW_2025_blank", length(hjw_2025_blank_files))
  ),
  source_path = all_files,
  staged_element_values_replaced = element_replacement_counts
)

write.csv(
  manifest,
  "CoreMS_Output/CoreMS_file_manifest.csv",
  quote = FALSE,
  row.names = FALSE
)


# ------------------------------------------------------------
# Final summary
# ------------------------------------------------------------

cat("\nDone.\n")
cat("Created:", output_dir, "\n")
cat("2016 sediment files:", length(hja_2016_files), "\n")
cat("2025 sediment files:", length(hjw_2025_files), "\n")
cat("2025 blank files:", length(hjw_2025_blank_files), "\n")
cat("Total CoreMS files:", length(all_files), "\n")
