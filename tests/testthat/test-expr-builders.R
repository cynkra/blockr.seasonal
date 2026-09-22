# The call the block writes. Everything the user does in the argument band
# ends here, and the strip under the band prints this, so a mistake shows up
# as a call that reads fine and runs differently.

test_that("a spec is named and empty, which is what switches it on", {
  args <- list(list(name = "x11", value = ""))
  expect_equal(seas_call_args(args), list(x11 = quote(list())))
})

test_that("an argument with nothing in it is left out of the call", {
  # The row stays on screen from the moment it is added until a value is
  # picked, so seas() has to tolerate the gap.
  expect_equal(seas_call_args(list(list(name = "transform.function",
                                        value = ""))), list())
  expect_equal(seas_call_args(list(list(name = "outlier.types",
                                        value = character()))), list())
})

test_that("one value out of a multi is a bare string, not c()", {
  one <- seas_call_args(list(list(name = "outlier.types", value = "ao")))
  expect_equal(one, list(outlier.types = "ao"))

  two <- seas_call_args(list(list(name = "outlier.types",
                                  value = c("ao", "ls"))))
  expect_equal(two, list(outlier.types = quote(c("ao", "ls"))))
})

test_that("a numeric argument is a number, and a non-number is dropped", {
  expect_equal(seas_call_args(list(list(name = "outlier.critical",
                                        value = "3.5"))),
               list(outlier.critical = 3.5))
  expect_equal(seas_call_args(list(list(name = "outlier.critical",
                                        value = "high"))), list())
})

test_that("the call is one seas() call, with no local() around it", {
  e <- make_seas_expr(list(list(name = "transform.function", value = "log")))
  expect_true(is.call(e))
  expect_equal(e[[1L]], str2lang("seasonal::seas"))
  expect_equal(e$transform.function, "log")
  expect_equal(e$x, quote(tsbox::ts_ts(.(.arg1))))
})

test_that("xreg and xtrans arrive only when something is linked to them", {
  nms <- c(x = ".arg1", xreg = ".arg2", xtrans = ".arg3")
  bare <- make_seas_expr(list(), arg_names = nms)
  expect_null(bare$xreg)

  both <- make_seas_expr(list(), has_xreg = TRUE, has_xtrans = TRUE,
                         arg_names = nms)
  expect_equal(both$xreg, quote(.(.arg2)))
  expect_equal(both$xtrans, quote(.(.arg3)))
})

test_that("the printed call is one argument per line, without the .()", {
  txt <- seas_expr_text(make_seas_expr(list(
    list(name = "x11", value = ""),
    list(name = "transform.function", value = "log")
  )))
  expect_equal(txt, paste(
    "seasonal::seas(",
    "  x = tsbox::ts_ts(.arg1),",
    "  x11 = list(),",
    '  transform.function = "log"',
    ")",
    sep = "\n"
  ))
})

test_that("seas_expr_text() survives being handed nothing", {
  expect_equal(seas_expr_text(NULL), "")
  expect_equal(seas_expr_text(quote(x)), "")
})
