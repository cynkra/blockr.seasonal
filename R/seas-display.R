#' How a fitted model draws
#'
#' `seasonal::seas()` returns a model, not a frame, and the block returns it
#' unchanged: everything the preview shows -- the adjusted series, the
#' coefficients, the diagnostics -- is in the model and nowhere else. The
#' preview works because blockr.ts dispatches its display on the DATA:
#' [blockr.ts::ts_resolve()] is the seam where a package says how its own
#' class becomes a frame, and the two methods below are all a `seas` object
#' needs to chart wherever it lands.
#'
#' WHAT THE CHART SHOWS IS THE PAIR, original and adjusted, because that is
#' the comparison a seasonal adjustment exists to make. Anything else --
#' trend, seasonal factors, irregular, any of the X-13 tables -- comes out of
#' the extraction block, which writes an ordinary `seasonal::` call the
#' exported document can carry.
#'
#' The original is not free: `augment.seas()` does not carry it, and inside
#' the model it is `final() * adjustfac`. `seasonal::original()` says the same
#' thing without the arithmetic.
#'
#' @param x A `seas` or `seas_multi` object.
#' @return A tsbox frame, or `NULL` when the model did not converge.
#' @name seas-display
#' @keywords internal
NULL

#' @exportS3Method blockr.ts::ts_resolve
ts_resolve.seas <- function(x) {
  seas_pair_frame(x)
}

#' @exportS3Method blockr.ts::ts_resolve
ts_resolve.seas_multi <- function(x) {

  # One model per input series, so the id column has two things to carry: the
  # series it came from and which of the two lines it is. Pasted, because a
  # tsbox frame has ONE id column and the chart legend reads it.
  parts <- lapply(names(x$series %||% x), function(nm) {
    d <- seas_pair_frame(x[[nm]])
    if (is.null(d)) {
      return(NULL)
    }
    d$id <- paste(nm, d$id, sep = " / ")
    d
  })
  parts <- Filter(Negate(is.null), parts)
  if (!length(parts)) {
    return(NULL)
  }
  do.call(rbind, parts)
}

#' One model, two named series
#' @noRd
seas_pair_frame <- function(x) {
  adjusted <- tryCatch(seasonal::final(x), error = function(e) NULL)
  if (is.null(adjusted)) {
    return(NULL)
  }
  original <- tryCatch(seasonal::original(x), error = function(e) NULL)

  # ts_c() names its id column by deparsing its arguments, so the names have
  # to be written into the call rather than left to be discovered. See the
  # combine block in blockr.ts for what happens when they are not.
  pair <- if (is.null(original)) {
    tsbox::ts_c(adjusted = adjusted)
  } else {
    tsbox::ts_c(original = original, adjusted = adjusted)
  }
  suppressMessages(tsbox::ts_tbl(pair))
}

`%||%` <- function(x, y) if (is.null(x)) y else x
