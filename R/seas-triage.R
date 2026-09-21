#' Triage a round of seasonal adjustments
#'
#' One row per series, the columns an analyst reads before deciding which
#' series to look at: what model X-13 chose, whether it logged, how many
#' outliers it needed, and whether seasonality survives in the adjusted series.
#' With a `reference` it also says how far the adjustment is from an answer you
#' already trust, usually the statistical office's own published series.
#'
#' The point of the table is that it is sorted. Adjusting twenty series is
#' cheap and reading twenty diagnostic panels is not, so the round produces one
#' table and the table names the two series that need a hand.
#'
#' `flags` is deliberately a list of what tripped rather than a verdict.
#' `residual seasonality` means the QS statistic on the seasonally adjusted
#' series exceeds `qs_crit`; `no transform` means X-13 chose to model the
#' series in levels, which on a series that grows multiplicatively is the
#' single most common way an automatic adjustment goes wrong; `off reference`
#' means the worst month is further than `ref_crit` percent from `reference`.
#'
#' @param models Named list of `seas` models, as returned by
#'   [new_seas_multi_block()]. Elements that are conditions rather than models
#'   are reported as failed rather than dropped.
#' @param reference Optional long data frame holding an adjustment to compare
#'   against: a series column, a time column and a numeric value column.
#' @param ref_series,ref_time,ref_value Which of `reference`'s columns fill
#'   those three roles. `NULL` resolves by type, which is right for a tidy
#'   three-column frame and wrong the moment the frame carries a second
#'   numeric column: a published file that keeps its `is_adj` flag beside the
#'   value would otherwise be compared against the flag.
#' @param since Optional date. Restricts the comparison with `reference` to
#'   observations from this date on. A twenty-year-old revision is not what
#'   anybody is deciding about.
#' @param qs_crit QS critical value for residual seasonality. The default
#'   `7.81` is the 5 percent point of a chi-squared with two degrees of
#'   freedom, which is what the QS statistic is compared against.
#' @param ref_crit Percent. Worst-month deviation from `reference` above which
#'   the series is flagged.
#'
#' @return A data frame, one row per series, sorted worst first: by deviation
#'   from `reference` when there is one, by QS otherwise.
#'
#' @examples
#' models <- list(
#'   air = seasonal::seas(datasets::AirPassengers),
#'   nott = seasonal::seas(datasets::nottem)
#' )
#' seas_triage(models)
#'
#' @export
seas_triage <- function(models, reference = NULL,
                        ref_series = NULL, ref_time = NULL, ref_value = NULL,
                        since = NULL, qs_crit = 7.81, ref_crit = 5) {

  stopifnot(is.list(models))
  if (is.null(names(models))) {
    names(models) <- paste0("series_", seq_along(models))
  }

  ref <- if (is.null(reference)) {
    NULL
  } else {
    as_long_series(reference, ref_series, ref_time, ref_value)
  }

  rows <- lapply(names(models), function(nm) {
    triage_row(nm, models[[nm]], ref, since, qs_crit, ref_crit)
  })
  out <- do.call(rbind, rows)

  # Worst first, and a series that failed to adjust is the worst there is, so
  # its missing key sorts above every number rather than off the bottom.
  key <- if (is.null(ref)) out$qs else out$worst_pct
  out <- out[order(-ifelse(is.na(key), Inf, key)), , drop = FALSE]
  row.names(out) <- NULL
  out
}

#' One triage row
#'
#' @inheritParams seas_triage
#' @param name Series name.
#' @param model A `seas` model, or the condition its fit raised.
#' @param ref Long reference frame with columns `id`, `time`, `value`, or NULL.
#' @noRd
triage_row <- function(name, model, ref, since, qs_crit, ref_crit) {

  empty <- data.frame(
    series = name, n = NA_integer_,
    start = as.Date(NA), end = as.Date(NA),
    arima = NA_character_, transform = NA_character_,
    outliers = NA_integer_, qs = NA_real_,
    worst_pct = NA_real_, median_pct = NA_real_,
    flags = NA_character_,
    stringsAsFactors = FALSE
  )

  if (!inherits(model, "seas")) {
    empty$flags <- paste0("failed: ", conditionMessage(model))
    return(empty)
  }

  u <- seasonal::udg(model)
  scalar <- function(key, f = as.character) {
    v <- u[[key]]
    if (is.null(v) || !length(v)) return(if (identical(f, as.numeric)) NA_real_ else NA_character_)
    f(v[[1]])
  }

  adj <- seasonal::final(model)
  tt <- stats::time(adj)
  row <- empty
  row$n <- length(adj)
  row$start <- yearfrac_to_date(min(tt), stats::frequency(adj))
  row$end <- yearfrac_to_date(max(tt), stats::frequency(adj))
  row$arima <- scalar("arimamdl")
  # `aictrans` is what the AIC test chose, and only exists when the test ran.
  # A forced `transform.function` reports under `transform` instead.
  row$transform <- scalar("aictrans")
  if (is.na(row$transform)) row$transform <- scalar("transform")
  row$outliers <- sum(grepl("^(AO|LS|TC)", names(stats::coef(model))))
  row$qs <- round(scalar("qssadj", as.numeric), 2)

  flags <- character()
  if (!is.na(row$qs) && row$qs > qs_crit) {
    flags <- c(flags, "residual seasonality")
  }
  # X-13 reports the chosen transform as a phrase, not a code. Anything that is
  # not a transformation is a level model, which is what the flag is about.
  if (!is.na(row$transform) && grepl("^no transform", tolower(row$transform))) {
    flags <- c(flags, "no transform")
  }

  if (!is.null(ref)) {
    cmp <- compare_to_reference(adj, ref[ref$id == name, , drop = FALSE], since)
    row$worst_pct <- cmp$worst
    row$median_pct <- cmp$median
    if (!is.na(cmp$worst) && cmp$worst > ref_crit) {
      flags <- c(flags, "off reference")
    }
  }

  row$flags <- if (length(flags)) paste(flags, collapse = "; ") else "ok"
  row
}

#' Worst and median percentage gap against a reference series
#'
#' @param adj A `ts` holding the adjusted series.
#' @param ref One series' worth of the reference frame.
#' @param since Optional start date.
#' @return A list with `worst` and `median`, in percent.
#' @noRd
compare_to_reference <- function(adj, ref, since = NULL) {
  na <- list(worst = NA_real_, median = NA_real_)
  if (!nrow(ref)) return(na)

  own <- data.frame(
    time = yearfrac_to_date(as.numeric(stats::time(adj)), stats::frequency(adj)),
    mine = as.numeric(adj)
  )
  j <- merge(own, ref[c("time", "value")], by = "time")
  names(j)[names(j) == "value"] <- "ref"
  if (!is.null(since)) j <- j[j$time >= as.Date(since), , drop = FALSE]
  j <- j[is.finite(j$mine) & is.finite(j$ref) & j$ref != 0, , drop = FALSE]
  if (!nrow(j)) return(na)

  dev <- 100 * abs(j$mine / j$ref - 1)
  list(worst = round(max(dev), 2), median = round(stats::median(dev), 2))
}

#' Turn a long data frame into `id` / `time` / `value`
#'
#' Accepts whatever the board happens to be carrying and names the three
#' columns by role, using the same type-based resolution the multi-series
#' block uses.
#'
#' @param d A data frame.
#' @param series,time,value Column names, or `NULL` to resolve by type.
#' @return A data frame with columns `id`, `time`, `value`.
#' @noRd
as_long_series <- function(d, series = NULL, time = NULL, value = NULL) {
  stopifnot(is.data.frame(d))
  picks <- resolve_series_columns(d, series, time, value)
  if (any(vapply(picks, is.null, logical(1)))) {
    stop(
      "reference needs a series column, a time column and a numeric value ",
      "column; found ", paste(names(d), collapse = ", "),
      call. = FALSE
    )
  }
  out <- d[c(picks$series, picks$time, picks$value)]
  names(out) <- c("id", "time", "value")
  out$id <- as.character(out$id)
  out
}

#' `ts` time to a Date
#'
#' `stats::time()` counts in fractional years. Comparing against a published
#' file means matching on calendar dates, and rounding the fraction to the
#' period index is the only way that survives floating point.
#'
#' @param x Fractional years.
#' @param freq Series frequency.
#' @noRd
yearfrac_to_date <- function(x, freq) {
  yr <- floor(x + 1e-8)
  per <- round((x - yr) * freq) + 1
  as.Date(sprintf("%d-%02d-01", as.integer(yr), as.integer((per - 1) * 12 / freq + 1)))
}
