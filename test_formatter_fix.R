#!/usr/bin/env Rscript

# Test the fixed formatter

source("R/seas-autocomplete.R")

# Test cases
test_cases <- list(
  list(
    input = "seas(x = x, x11 = list())",
    expected = "seas(x = x,\n  x11 = list()\n)"
  ),
  list(
    input = "seas(x = x, transform.power = 0, x11 = list())",
    expected = "seas(x = x,\n  transform.power = 0,\n  x11 = list()\n)"
  ),
  list(
    input = "seas(x = x, transform.power = 0, x11 = list(mode = 'mult'), regression.aictest = c('td', 'easter'))",
    expected = "seas(x = x,\n  transform.power = 0,\n  x11 = list(mode = 'mult'),\n  regression.aictest = c('td', 'easter')\n)"
  )
)

cat("Testing improved formatter...\n\n")

for (i in seq_along(test_cases)) {
  test <- test_cases[[i]]
  cat("Test", i, ":\n")
  cat("Input:\n", test$input, "\n\n")

  result <- format_seas_call(test$input)

  cat("Output:\n", result, "\n\n")
  cat("Expected:\n", test$expected, "\n\n")

  if (identical(result, test$expected)) {
    cat("✓ PASS\n")
  } else {
    cat("✗ FAIL\n")
    cat("Difference:\n")
    cat("Got:     '", gsub("\n", "\\\\n", result), "'\n", sep = "")
    cat("Expected:'", gsub("\n", "\\\\n", test$expected), "'\n", sep = "")
  }
  cat("---\n\n")
}

cat("Testing edge cases...\n")
cat("Empty string: '", format_seas_call(""), "'\n", sep = "")
cat("Single arg: '", format_seas_call("seas(x = x)"), "'\n", sep = "")