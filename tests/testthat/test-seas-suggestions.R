# The suggestions are seasonal.website's labels and nothing else, and every
# one of them has to produce a call X-13 accepts. The second test is the one
# that matters: a phrase that writes an illegal argument is worse than no
# phrase at all.

test_that("every label is one seasonal.website offers", {
  # seasonalview:::lFOpts, transcribed. If the website's lists change, this
  # is the test that says so.
  website <- c(
    "X11", "Logarithmic", "Square Root", "No Transformation",
    "1-Day before Easter", "1-Week before Easter",
    "1-Coefficient", "6-Coefficients",
    "Low Critical Value (3)", "Medium Critical Value (4)",
    "High Critical Value (5)"
  )
  said <- vapply(seas_suggestions(), function(s) s$say, "")
  # The one exception is the ARIMA model, which the website lists by its own
  # notation rather than by a name.
  expect_setequal(setdiff(said, "(0 1 1)(0 1 1)"), website)
})

test_that("no suggestion writes what seas() already does", {
  # "AIC Test", "Auto Search", "Auto Critical Value" and "AIC Test Easter" are
  # the website's AUTOMATIC entries, and they are seas()'s defaults: a
  # suggestion for one would add a line to the call that changes nothing.
  said <- vapply(seas_suggestions(), function(s) s$say, "")
  expect_false(any(grepl("^(AIC Test|Auto )", said)))
})

test_that("each suggestion names an argument the catalog knows", {
  catalog <- get_x13_catalog()
  for (s in seas_suggestions()) {
    expect_true(!is.null(catalog[[s$name]]),
                info = paste(s$say, "names", s$name))
  }
})

test_that("each suggestion's value is one the argument takes", {
  catalog <- get_x13_catalog()
  for (s in seas_suggestions()) {
    entry <- catalog[[s$name]]
    if (is.null(entry$values)) next
    allowed <- vapply(entry$values, function(v) v$value, "")
    for (v in as.character(unlist(s$value))) {
      expect_true(v %in% allowed, info = paste(s$say, "->", s$name, "=", v))
    }
  }
})

test_that("the call a suggestion writes is one X-13 runs", {
  skip_if_not_installed("seasonal")
  for (s in seas_suggestions()) {
    rows <- list(list(name = s$name, value = s$value))
    args <- seas_call_args(rows)
    m <- tryCatch(
      do.call(seasonal::seas, c(list(x = datasets::AirPassengers), args)),
      error = function(e) e
    )
    expect_s3_class(m, "seas")
  }
})

test_that("a spec row is in the call while empty, an argument row is not", {
  expect_equal(names(seas_call_args(list(list(name = "x11", value = "")))),
               "x11")
  expect_length(
    seas_call_args(list(list(name = "transform.function", value = ""))), 0L
  )
})

test_that("only x11 is offered as a spec", {
  # Measured, in data-raw/x13-args.R: the other nine either error when empty,
  # or produce an identical series because seas() already sends them.
  catalog <- get_x13_catalog()
  specs <- names(Filter(function(e) identical(e$type, "spec"), catalog))
  expect_equal(specs, "x11")
})

test_that("the picker offers 208 of the 285 arguments", {
  catalog <- get_x13_catalog()
  hidden <- vapply(catalog, function(e) isTRUE(e$hidden), logical(1))
  expect_equal(length(catalog), 285L)
  expect_equal(sum(!hidden), 208L)
})

test_that("what is hidden is hidden for one of three reasons", {
  catalog <- get_x13_catalog()
  nm <- names(catalog)
  hidden <- nm[vapply(catalog, function(e) isTRUE(e$hidden), logical(1))]

  arg <- sub("^.*\\.", "", hidden)
  spec <- sub("\\..*$", "", hidden)
  kept <- c("series.span", "series.modelspan",
            "series.appendfcst", "series.appendbcst")

  reason <- arg %in% c("print", "save", "savelog") |
    spec %in% c("composite", "metadata") |
    (spec == "series" & !hidden %in% kept)
  expect_true(all(reason))

  # And the two from the series spec that people actually use are offered.
  for (k in kept) expect_false(isTRUE(catalog[[k]]$hidden), info = k)
})

test_that("a hidden argument keeps its description and its type", {
  # It is hidden from the picker, not deleted: a restored board holding
  # `outlier.save` still has to render a control and say what it is.
  e <- get_x13_catalog()[["outlier.save"]]
  expect_true(isTRUE(e$hidden))
  expect_true(nzchar(e$description))
  expect_true(nzchar(e$type))
})

test_that("nothing a suggestion names is hidden", {
  catalog <- get_x13_catalog()
  for (s in seas_suggestions()) {
    expect_false(isTRUE(catalog[[s$name]]$hidden), info = s$say)
  }
})

test_that("the expression is one call, not a local() around one", {
  e <- make_seas_expr(list(list(name = "transform.function", value = "log")),
                      arg_names = c(x = ".arg1"))
  expect_identical(as.character(e[[1L]][[1L]]), "::")
  expect_false(grepl("local", paste(deparse(e), collapse = " ")))
})

test_that("what the strip shows is what core runs", {
  rows <- list(list(name = "x11", value = ""),
               list(name = "regression.variables", value = list("td")))
  e <- make_seas_expr(rows, arg_names = c(x = ".arg1"))
  txt <- seas_expr_text(e)

  # Every argument of the call is in the text, and the substitution marker is
  # the only thing taken out of it.
  expect_match(txt, "seasonal::seas")
  expect_match(txt, "x11 = list()", fixed = TRUE)
  expect_match(txt, 'regression.variables = "td"', fixed = TRUE)
  expect_match(txt, "tsbox::ts_ts(.arg1)", fixed = TRUE)
  expect_false(grepl(".(", txt, fixed = TRUE))
})

test_that("the strip prints one argument per line", {
  rows <- list(list(name = "x11", value = ""),
               list(name = "transform.function", value = "log"))
  txt <- seas_expr_text(make_seas_expr(rows, arg_names = c(x = ".arg1")))

  lines <- strsplit(txt, "\n", fixed = TRUE)[[1L]]
  expect_equal(lines[[1L]], "seasonal::seas(")
  expect_equal(lines[[length(lines)]], ")")
  # the series, and one line per argument set
  expect_equal(length(lines), 5L)
  expect_true(all(grepl("^  ", lines[2:4])))

  # A call with nothing but the series still gets its own line, which is how
  # seasonal.website prints it.
  empty <- seas_expr_text(make_seas_expr(list(), arg_names = c(x = ".arg1")))
  expect_equal(length(strsplit(empty, "\n", fixed = TRUE)[[1L]]), 3L)
})
