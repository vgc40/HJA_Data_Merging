HJA 2016 + HJW 2025 FTICR-MS processing
=======================================

HJA 2016:
- HJA 2016 samples were not blank filtered because 2016 blanks were not available.
- Samples were renamed HJA_<Site_ID>_2016.

HJW 2025 blank filtering:
- Blank filtering was applied only to HJW 2025 technical replicates.
- Blanks used: HJW_MQ_Blk-1_p05, HJW_MQ_Blk-2_p05
- A calibrated m/z peak was removed from the 2025 replicate data only when detected in BOTH blanks.
- Number of blank-associated peaks: 416

HJW 2025 technical replicate merging:
- Peaks were retained when detected in at least 2 technical replicates.
- For samples with 3 replicates, this is a 2-of-3 rule.
- For samples with 2 replicates, this is a 2-of-2 rule.
- Retained peak intensity was the mean of the positive replicate intensities.
- Samples with only 2 technical replicates: HJW_34, HJW_43
- Merged samples were renamed HJA_<Site_ID>_2025.

