# The card is the other side of the chart/table switch. Its job is to show a
# model rather than die on it: the table preview this replaces answered a
# `seas` object with "missing value where TRUE/FALSE needed".

test_that("a seas object reads as a card", {
  skip_if_not_installed("seasonal")
  skip_if_not_installed("broom")
  m <- seasonal::seas(datasets::AirPassengers)
  html <- paste(as.character(blockr.ts::ts_model_view(m)), collapse = "")

  expect_match(html, "seas-card")
  # what it estimated, what it is, whether the residuals behave
  expect_match(html, "MA-Seasonal", fixed = TRUE)
  expect_match(html, "ARIMA", fixed = TRUE)
  expect_match(html, "Box-Ljung", fixed = TRUE)
  # and a null hypothesis under each test, since a statistic alone says
  # nothing about whether it rejects
  expect_match(html, "H0", fixed = TRUE)
})

test_that("every number in the card comes from broom", {
  skip_if_not_installed("seasonal")
  skip_if_not_installed("broom")
  m <- seasonal::seas(datasets::AirPassengers)
  html <- paste(as.character(blockr.ts::ts_model_view(m)), collapse = "")

  gl <- broom::glance(m)
  expect_match(html, gl$arima, fixed = TRUE)
  expect_match(html, gl$adjustment, fixed = TRUE)
  expect_match(html, format(round(gl$AICc, 2)), fixed = TRUE)
})

test_that("a coefficient too small for two decimals keeps its meaning", {
  # -0.0029 must not print as "-0.00".
  expect_equal(seas_fmt_est(-0.002949699), "-0.0029")
  expect_equal(seas_fmt_est(0.4973), "0.50")
})

test_that("the chip ladder stops at ten per cent", {
  expect_null(seas_chip(0.2))
  expect_match(as.character(seas_chip(0.07)), "10%", fixed = TRUE)
  expect_match(as.character(seas_chip(0.0004)), "0.1%", fixed = TRUE)
  # the strongest level carries no modifier class, so only colour varies
  expect_false(grepl("seas-chip--", as.character(seas_chip(0.0004))))
})

test_that("a round of models says so rather than showing one of them", {
  skip_if_not_installed("seasonal")
  m <- seasonal::seas(cbind(datasets::mdeaths, datasets::fdeaths))
  html <- paste(as.character(blockr.ts::ts_model_view(m)), collapse = "")
  expect_match(html, "2 models", fixed = TRUE)
  expect_match(html, "mdeaths", fixed = TRUE)
})

test_that("anything that is not a model still gets the table preview", {
  # NULL is what tells the display to fall through.
  expect_null(blockr.ts::ts_model_view(datasets::mtcars))
  expect_null(blockr.ts::ts_model_view(datasets::AirPassengers))
})
