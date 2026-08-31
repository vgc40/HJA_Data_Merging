required_packages <- c(
  "rmarkdown", "dplyr", "tidyr", "ggplot2", "readr", "stringr",
  "purrr", "tibble", "forcats", "vegan", "permute", "knitr"
)

missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]

if (length(missing_packages) > 0) {
  stop(
    "Install the required R packages before rendering: ",
    paste(missing_packages, collapse = ", ")
  )
}

if (!rmarkdown::pandoc_available()) {
  pandoc_candidates <- c(
    Sys.getenv("RSTUDIO_PANDOC"),
    file.path(
      Sys.getenv("ProgramFiles"),
      "RStudio", "resources", "app", "bin", "quarto", "bin", "tools"
    )
  )
  pandoc_candidates <- pandoc_candidates[
    file.exists(file.path(pandoc_candidates, "pandoc.exe"))
  ]
  if (length(pandoc_candidates) == 0) {
    stop("Pandoc was not found. Install Pandoc or render from RStudio.")
  }
  Sys.setenv(RSTUDIO_PANDOC = pandoc_candidates[[1]])
}

rmarkdown::render(
  input = "analysis/01_HJA_2016_vs_2025_FTICR_Analysis.Rmd",
  output_file = "01_HJA_2016_vs_2025_FTICR_Analysis.html",
  output_dir = "analysis",
  knit_root_dir = getwd(),
  envir = new.env(parent = globalenv()),
  clean = TRUE
)
