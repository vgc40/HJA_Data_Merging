HJA 2016 + HJW 2025 FTICR-MS post-processing
================================================

UPSTREAM PROCESSING
-------------------
Input Data and Mol files were generated using the ESS-DIVE CoreMS_MergeProcess.Rmd workflow.

SAMPLE NAME NORMALIZATION
-------------------------
The ESS-DIVE merge output retained the .corems suffix from raw CoreMS filenames.
The .corems suffix was removed before sample grouping or renaming.

DATA/MOL QA
-----------
Processed Data rows: 21622
Processed Mol rows: 21622
Calibrated m/z alignment between Data and Mol: PASS
Number of Molecular Formula versus MolForm differences after whitespace normalization: 21622.

HJA 2016
--------
HJA 2016 samples were not blank filtered because 2016 blanks were not available.
HJA 2016 intensities were otherwise unchanged.
Technical suffixes such as _p1 were removed.
Final naming is HJA_<site>_2016.

HJW 2025 BLANK FILTERING
------------------------
Blank filtering was applied only to HJW 2025 technical replicate columns.
Blanks used: HJW_Blk-1_p05, HJW_Blk-2_p05
A peak was considered blank-associated only when detected in BOTH blanks.
Blank-associated peaks were set to zero in all HJW 2025 technical replicates before replicate merging.
Number of blank-associated rows: 285

HJW 2025 TECHNICAL REPLICATE MERGING
------------------------------------
Technical replicate peaks were retained when detected in at least 2 replicate files.
For samples with 3 replicates this is a 2-of-3 rule.
For samples with 2 replicates this is a 2-of-2 rule.
replicate intensities only.
Samples with only 2 technical replicates: HJW_34, HJW_43
HJW Parent_ID values were mapped to Site_ID using WHONDRS_HJW_Field_Metadata.csv.
Final naming is HJA_<Site_ID>_2025.

FINAL DATASET
-------------
HJA 2016 samples: 60
HJW 2025 samples: 47
Total final samples: 107
Molecular rows: 21622
No molecular rows were removed during blank filtering or technical replicate merging.

