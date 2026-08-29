library(tidyverse)

# ============================================================
# 01 - Create combined CoreMS_Output folder
#
# Collect:
# - 2016 HJA sediment CoreMS CSV files
# - 2025 HJW sediment CoreMS CSV files
# - 2025 HJW blank CoreMS CSV files
#
# No processing is done in this script.
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

file.copy(
  from = all_files,
  to = output_dir,
  overwrite = TRUE
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
  source_path = all_files
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