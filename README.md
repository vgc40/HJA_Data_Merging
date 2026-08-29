# HJA 2016 + HJW 2025 FTICR-MS Data Preparation

## Overview

This workflow prepares sediment FTICR-MS data from the 2016 HJA and 2025 HJW sampling campaigns for combined downstream analysis.

The workflow starts from the CoreMS molecular-formula assignment files distributed with the ESS-DIVE data packages and produces:

* a combined Data and Mol file
* blank-corrected and technical-replicate-merged 2025 data
* standardized sample names across sampling years
* sample-level FTICR-MS summary files

The workflow was designed to retain the processing conventions used in the original ESS-DIVE FTICR-MS workflow wherever possible while making only the modifications required to combine the two datasets and accommodate the current version of `ftmsRanalysis`.

---

## Input datasets

Two existing data packages were used.

### HJA 2016

Sediment CoreMS output files were obtained from:

`WHONDRS_HJA_2016_Sample_Data/WHONDRS_HJA_2016_Sample_Data/Sediment_CoreMS_Output_Files/`

These samples consist of one CoreMS output file per sediment sample.

There are 60 HJA 2016 sediment files.

### HJW 2025

Sediment CoreMS output files were obtained from:

`v2_WHONDRS_HJW_Sample_Data/v2_WHONDRS_HJW_Sample_Data/FTICR/Sediment_CoreMS_Output_Files/`

The 2025 samples generally contain three technical FTICR-MS replicates per parent sample.

Blank CoreMS output files were obtained from:

`v2_WHONDRS_HJW_Sample_Data/v2_WHONDRS_HJW_Sample_Data/FTICR/Blanks_CoreMS_Output_Files/`

The two available blanks are:

* `HJW_Blk-1_p05.corems.csv`
* `HJW_Blk-2_p05.corems.csv`

---

## Step 1. Collect CoreMS output files

Script:

`src/01_Create_CoreMS_Output.R`

All `.corems.csv` files used in the analysis are copied into:

`CoreMS_Output/`
Note that this file is currently in my gitignore and is therefore not committed to the repo

The script:

* collects HJA 2016 sediment files
* collects HJW 2025 sediment technical-replicate files
* collects the two HJW 2025 blank files

---

## Step 2. Check CoreMS file structure

Script:

`src/02_Check_CoreMS_Columns.R`

Before merging the datasets, the column structure of every CoreMS file is checked.

The script evaluates:

* total number of columns
* complete column-name patterns
* presence of key CoreMS fields
* consistency among HJA 2016 samples, HJW 2025 samples, and HJW 2025 blanks

Key molecular fields checked include:

* calibrated mass
* calculated mass
* peak height
* mass error
* confidence score
* heteroatom class
* isotopologue status
* molecular formula
* C, H, O, N, P, and S elemental counts

Differences in the total number of columns among files are primarily associated with optional isotope fields rather than differences in the core molecular information required for merging.

No data are modified during this step.

Outputs:

`CoreMS_Output/CoreMS_column_check.csv`

`CoreMS_Output/CoreMS_key_column_check.csv`

---

## Step 3. Merge CoreMS files using the ESS-DIVE workflow

Script:

`src/03_Run_ESSDIVE_CoreMS_Merge.R`

The combined CoreMS files are processed using the original ESS-DIVE `CoreMS_MergeProcess.Rmd` workflow supplied with the FTICR-MS data package.

The original ESS-DIVE script is not modified. Instead, the wrapper creates a temporary copy with only the changes required to run the historical workflow on the combined HJA 2016 and HJW 2025 dataset.

The wrapper:

* sets the combined dataset name to `HJA_2016_HJW_2025`
* points the workflow to `CoreMS_Output/`
* writes intermediate results to `Merged_Output/`
* translates archived underscore-style CoreMS column names back to the names expected by the original ESS-DIVE workflow
* uses the local `getLambda.R` file when needed
* updates the historical `as.peakData()` syntax for compatibility with the currently installed version of `ftmsRanalysis`

The underlying ESS-DIVE molecular-processing logic is otherwise retained.

The main intermediate outputs are:

`Merged_Output/HJA_2016_HJW_2025-Processed_Data.csv`

`Merged_Output/HJA_2016_HJW_2025-Processed_Mol.csv`

The processed Data file contains molecular-feature intensities across the original sample and technical-replicate files.

The processed Mol file contains corresponding molecular metadata and calculated FTICR-MS properties.

The processed Data and Mol files contain 21,622 aligned molecular features.

---

## Molecular formula handling

The original CoreMS molecular assignment is retained in the `Molecular Formula` field.

During creation of the `ftmsRanalysis` object, `ftmsRanalysis` also generates a standardized molecular-formula representation called `MolForm` from the elemental composition.

Differences between `Molecular Formula` and `MolForm` were examined and found to reflect formula-formatting conventions rather than changes in elemental composition.

Examples include omission of explicit coefficients of one:

`P1`

versus:

`P`

and differences in heteroatom ordering, for example:

`C10H10O7N1P1S2`

versus:

`C10H10O7NS2P`

These formulas describe the same elemental composition.

The molecular properties calculated by `ftmsRanalysis` and the subsequent thermodynamic calculations are based on the elemental composition associated with each molecular feature.

---

## Step 4. Blank correction and technical-replicate merging

Script:

`src/04_Clean_Blanks_and_Merge_HJW_Replicates.R`

The 2016 and 2025 datasets require different treatment at this stage because technical replicates and procedural blanks are available only for the HJW 2025 dataset.

### HJA 2016 samples

The HJA 2016 samples contain one CoreMS output file per sample.

No blank correction is applied to the 2016 samples because equivalent blank files are not available for this dataset.

HJA 2016 intensity values are otherwise retained unchanged during this processing step.

### HJW 2025 blank correction

Blank correction is applied only to HJW 2025 samples.

A molecular feature is considered blank-associated only when it is detected with an intensity greater than zero in both 2025 blank samples.

The two blanks are:

* `HJW_Blk-1_p05`
* `HJW_Blk-2_p05`

A total of 285 molecular rows were detected in both blanks.

For these blank-associated molecular features, intensity is set to zero in all HJW 2025 technical-replicate columns before technical replicates are consolidated.

The molecular rows themselves are not removed from the dataset. This preserves row alignment between the Data and Mol files.

### HJW 2025 technical-replicate merging

Technical replicates are grouped by HJW parent sample.

Most HJW samples have three technical replicates.

Two samples have only two technical replicates:

* `HJW_34`
* `HJW_43`

For samples with three technical replicates, a molecular feature is retained when it is detected in at least two of the three replicates.

For samples with two technical replicates, a molecular feature is retained only when it is detected in both replicates.

For retained molecular features, the final sample intensity is calculated as the arithmetic mean of the positive detected replicate intensities only.

Blank-associated peaks are set to zero before the replicate-detection rule is applied.

---

## Standardization of final sample names

Final sample names use a common naming convention:

`HJA_<site>_<year>`

### HJA 2016

Technical filename suffixes such as `_p1` indicate ion accumulation time. These are removed and the sampling year is appended.

For example:

`HJA_155_p1`

becomes:

`HJA_155_2016`

and:

`HJA_CC-1-15m_p1`

becomes:

`HJA_CC-1-15m_2016`

### HJW 2025

HJW parent sample IDs are linked to `Site_ID` using:

`v2_WHONDRS_HJW_Sample_Data/WHONDRS_HJW_Field_Metadata.csv`

For example:

`HJW_01`

maps to:

`HJA_71_2025`

For retained molecular features, the final value is recorded as presence (1); features that do not meet the replicate-detection criterion are recorded as absence (0). Thus, the final molecular-feature matrix is a presence/absence matrix rather than an intensity matrix
---

## Final merged FTICR-MS dataset

After blank correction, technical-replicate consolidation, and sample-name standardization, the final merged dataset contains:

* 60 HJA 2016 samples
* 47 HJW 2025 samples
* 107 total samples
* 21,622 molecular features

No molecular rows are removed during blank correction or technical-replicate merging.

The final Data and Mol files therefore retain the same 21,622 molecular rows in the same calibrated-mass order.

Intermediate and provenance files generated during this processing step include:

* `Merged_Output/HJA_2016_HJW_2025-Blank_Associated_Peaks.csv`
* `Merged_Output/HJA_2016_HJW_2025-HJW_Replicate_Summary.csv`
* `Merged_Output/HJA_2016_HJW_2025-Sample_Name_Mapping.csv`
* `Merged_Output/HJA_2016_HJW_2025-Molecular_Formula_vs_MolForm.csv`

These files document blank-associated molecular features, technical-replicate structure, final sample-name mappings, and molecular-formula formatting comparisons.

---

## Step 5. Generate sample-level FTICR-MS summary files

The final Data and Mol files are used to generate sample-level summary tables following the established FTICR-MS summary workflow.

### Compound-class summary

For each sample, the number of detected molecular features belonging to each `bs1_class` compound category is counted.

Only molecular features with sample intensity greater than zero are considered detected.

Output:

`Results/HJA_2016_HJW_2025_Compound_Class_Summary.csv`

### Elemental-composition summary

The elemental-composition category for each molecular feature is reconstructed from the C, H, O, N, S, and P columns.

Examples include:

* `CHOP`
* `CHONP`
* `CHOSP`
* `CHONSP`

For each sample, the number of detected molecular features belonging to each elemental-composition category is counted.

Only molecular features with intensity greater than zero are included.

Output:

`Results/HJA_2016_HJW_2025_Elemental_Composition_Summary.csv`

### Molecular-property summary

For each sample, mean, median, and standard deviation are calculated across detected molecular features for molecular properties including:

* aromaticity index
* modified aromaticity index
* double-bond equivalents
* DBE-O
* Kendrick mass
* Kendrick mass defect
* nominal oxidation state of carbon (NOSC)
* H:C ratio
* O:C ratio
* N:C ratio
* P:C ratio
* N:P ratio
* Gibbs free-energy-related metrics
* Gibbs free energy per C mol
* oxygen-utilization/lambda metrics

These summaries are presence based.

A molecular feature contributes to the summary when its sample intensity is greater than zero. Peak intensity is not used as a weighting factor when calculating these molecular-property summaries.

Output:

`Results/HJA_2016_HJW_2025_MolInfo_Summary.csv`

---

## Current analysis-ready products

The final analysis-ready FTICR-MS files are stored in:

`Results/`

### Molecular intensity data

`Results/HJA_2016_HJW_2025-Processed_Data_Final.csv`

This is the final molecular-feature intensity matrix containing the 60 HJA 2016 samples and 47 HJW 2025 samples after 2025 blank correction, technical-replicate consolidation, and sample-name standardization.

### Molecular metadata

`Results/HJA_2016_HJW_2025-Processed_Mol_Final.csv`

This file contains molecular metadata corresponding to the same 21,622 molecular features in the final intensity matrix, including elemental composition, molecular classifications, and derived FTICR-MS and thermodynamic properties.

### Compound-class summary

`Results/HJA_2016_HJW_2025_Compound_Class_Summary.csv`

This file contains the number of detected molecular features belonging to each compound class for every final sample.

### Elemental-composition summary

`Results/HJA_2016_HJW_2025_Elemental_Composition_Summary.csv`

This file contains the number of detected molecular features belonging to each elemental-composition category for every final sample.

### Molecular-property summary

`Results/HJA_2016_HJW_2025_MolInfo_Summary.csv`

This file contains sample-level mean, median, and standard deviation values for molecular properties across detected molecular features.

---

## Directory roles

`CoreMS_Output/`

Contains the combined raw `.corems.csv` files used as input to the merge workflow, along with structural QA and manifest files.

`Merged_Output/`

Contains intermediate merged files, processing outputs, provenance information, blank reports, technical-replicate reports, and other files generated while preparing the final dataset.

`Results/`

Contains the final analysis-ready products intended for downstream statistical and ecological analyses.

`src/`

Contains the R scripts used to reproduce the data-preparation workflow.

---

## Analysis-ready status

At this stage:

* the HJA 2016 and HJW 2025 CoreMS outputs have been combined
* input file structures have been checked
* the original ESS-DIVE CoreMS merge workflow has been retained as the basis of molecular processing
* compatibility changes required for the current `ftmsRanalysis` version have been isolated in the wrapper script
* molecular Data and Mol tables have been aligned
* the two HJW 2025 blanks have been incorporated into the cleaning procedure
* blank-associated peaks have been removed from the 2025 sample intensities
* HJW 2025 technical replicates have been consolidated using a reproducible detection rule
* HJA 2016 intensities have been retained without 2025-specific blank filtering
* sample names have been standardized across years
* molecular-formula differences associated with `MolForm` have been reviewed and attributed to formula-formatting conventions
* sample-level compound-class, elemental-composition, and molecular-property summaries have been generated
* final analysis-ready files have been placed in `Results/`

The files in `Results/` are the products intended for downstream analysis.
