#!/usr/bin/env Rscript

#' Update Series Codes Data from seasonal Package
#'
#' This script fetches and parses the series codes from the seasonal package
#' GitHub repository and saves them as an RDS file for use in blockr.seasonal.
#'
#' Run this script when the seasonal package updates its series definitions.

library(httr)
library(stringr)

# URL to the series.R file in seasonal package
url <- "https://raw.githubusercontent.com/christophsax/seasonal/main/R/series.R"

message("Fetching series.R from seasonal package...")
response <- GET(url)

if (status_code(response) != 200) {
  stop("Failed to fetch series.R from GitHub. Status code: ", status_code(response))
}

# Get the content
content <- content(response, "text", encoding = "UTF-8")

message("Parsing series codes from documentation...")

# The series codes are in the roxygen documentation as a table
# Extract lines that look like table entries
lines <- str_split(content, "\n")[[1]]

# Find lines that are part of the table (contain \tab)
table_lines <- lines[str_detect(lines, "\\\\tab")]
table_lines <- table_lines[str_detect(table_lines, "\\\\cr")]

# Parse each line
series_data <- list()

for (line in table_lines) {
  # Skip the header line
  if (str_detect(line, "\\*\\*spec\\*\\*")) next
  
  # Split by \tab
  parts <- str_split(line, "\\\\tab")[[1]]
  
  if (length(parts) >= 4) {
    # Clean up each part
    spec <- str_trim(str_replace_all(parts[1], "#' ", ""))
    long_name <- str_trim(parts[2])
    short_name <- str_trim(parts[3])
    # Remove \cr from description
    description <- str_trim(str_replace_all(parts[4], "\\\\cr", ""))
    
    # Skip empty entries
    if (nzchar(spec) && nzchar(short_name)) {
      series_data[[length(series_data) + 1]] <- list(
        spec = spec,
        long_name = long_name,
        short_name = short_name,
        description = description
      )
    }
  }
}

# Convert to data frame
if (length(series_data) > 0) {
  series_df <- do.call(rbind, lapply(series_data, as.data.frame, stringsAsFactors = FALSE))
} else {
  stop("No series codes found in the documentation")
}

# Add some commonly used series that are extraction functions (not in the table)
# These are mentioned in the seasonal package documentation
additional_series <- data.frame(
  spec = c("core", "core", "core", "core", "core"),
  long_name = c("original", "final", "seasonal", "trend", "irregular"),
  short_name = c("original", "final", "seasonal", "trend", "irregular"),
  description = c(
    "Original series",
    "Seasonally adjusted (final) series",
    "Seasonal component", 
    "Trend-cycle component",
    "Irregular component"
  ),
  stringsAsFactors = FALSE
)

# Check if these aren't already in the data
existing_codes <- series_df$short_name
new_codes <- additional_series[!additional_series$short_name %in% existing_codes, ]
if (nrow(new_codes) > 0) {
  series_df <- rbind(new_codes, series_df)
}

# Sort by spec and then by short_name
series_df <- series_df[order(series_df$spec, series_df$short_name), ]

# Remove duplicates if any
series_df <- series_df[!duplicated(series_df$short_name), ]

# Clean up spec names for better display
series_df$spec <- str_to_title(series_df$spec)

message(sprintf("Parsed %d series codes", nrow(series_df)))

# Show summary by spec
spec_summary <- table(series_df$spec)
message("\nSeries by specification:")
for (spec in names(spec_summary)) {
  message(sprintf("  %s: %d series", spec, spec_summary[[spec]]))
}

# Save as RDS
# Get the package root directory
pkg_root <- here::here()
output_file <- file.path(pkg_root, "inst", "extdata", "series_codes.rds")
if (!file.exists(dirname(output_file))) {
  dir.create(dirname(output_file), recursive = TRUE)
}

saveRDS(series_df, output_file)
message(sprintf("\nSaved series codes to: %s", output_file))

# Also save as CSV for inspection
csv_file <- sub("\\.rds$", ".csv", output_file)
write.csv(series_df, csv_file, row.names = FALSE)
message(sprintf("Also saved as CSV for inspection: %s", csv_file))

# Show a sample of the data
message("\nSample of parsed data:")
print(head(series_df, 10))

message("\nUpdate complete!")