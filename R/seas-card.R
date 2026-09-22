#' How a fitted model reads
#'
#' The other side of the chart/table switch. [blockr.ts::ts_resolve()] says
#' how a `seas` object draws -- original against adjusted -- and this says how
#' it reads: what the model estimated, what it is, and whether its residuals
#' behave, in three columns.
#'
#' EVERY NUMBER COMES FROM broom, which seasonal 1.11.0 ships: `tidy()` is the
#' regARIMA coefficients, `glance()` is the one-row fit summary. Nothing here
#' computes a statistic, so nothing here can disagree with `summary()`.
#'
#' The significance chips are blockr.stats' ladder, unchanged: 0.1, 1 and 5
#' per cent as one blue alpha ramp, 10 per cent grey, nothing above that. A
#' fixed box so only the colour varies down the column.
#'
#' @param x A `seas` or `seas_multi` object.
#' @return A `tagList`.
#' @name seas-model-view
#' @keywords internal
NULL

#' @exportS3Method blockr.ts::ts_model_view
ts_model_view.seas <- function(x) {
  htmltools::tagList(
    seas_card_css_dep(),
    htmltools::div(
      class = "seas-card",
      seas_card_coefs(x),
      seas_card_facts(x),
      seas_card_tests(x)
    )
  )
}

#' @exportS3Method blockr.ts::ts_model_view
ts_model_view.seas_multi <- function(x) {
  # ONE MODEL GETS THE CARD, SEVERAL GET THE TRIAGE. With twenty series the
  # useful thing is which two need a hand, which is what seas_triage() is, and
  # it is a block rather than a preview: reading it needs the reference series
  # the triage compares against.
  models <- x$series %||% x
  htmltools::tagList(
    seas_card_css_dep(),
    htmltools::div(
      class = "seas-card seas-card--many",
      htmltools::p(paste0(
        length(models), " models, one per series. The card shows one; for a ",
        "round this size the useful read is the triage table."
      )),
      htmltools::tags$code(paste(utils::head(names(models), 12), collapse = ", "))
    )
  )
}

#' Three columns of the card
#' @noRd
seas_card_coefs <- function(x) {
  td <- tryCatch(broom::tidy(x), error = function(e) NULL)
  if (is.null(td) || !nrow(td)) {
    return(htmltools::div(
      class = "seas-card__col",
      htmltools::div(class = "seas-card__empty", "No regARIMA coefficients.")
    ))
  }
  htmltools::div(
    class = "seas-card__col",
    lapply(seq_len(nrow(td)), function(i) {
      htmltools::div(
        class = "seas-kv",
        htmltools::span(class = "seas-kv__k", td$term[[i]]),
        htmltools::span(class = "seas-kv__v", seas_fmt_est(td$estimate[[i]])),
        htmltools::span(class = "seas-kv__c", seas_chip(td$p.value[[i]]))
      )
    })
  )
}

#' @noRd
seas_card_facts <- function(x) {
  gl <- tryCatch(broom::glance(x), error = function(e) NULL)
  facts <- list()
  add <- function(label, value) {
    if (is.null(value) || !length(value) || is.na(value[[1L]])) return()
    facts[[length(facts) + 1L]] <<- c(label, format(value[[1L]]))
  }
  if (!is.null(gl)) {
    add("Adjustment", gl$adjustment)
    add("ARIMA", gl$arima)
    add("Obs.", gl$nobs)
    add("Transform", gl$transform)
    add("AICc", round(gl$AICc, 2))
    add("BIC", round(gl$BIC, 2))
  }
  htmltools::div(
    class = "seas-card__col",
    lapply(facts, function(f) {
      htmltools::div(
        class = "seas-kv",
        htmltools::span(class = "seas-kv__k", f[[1L]]),
        htmltools::span(class = "seas-kv__v", f[[2L]])
      )
    })
  )
}

#' @noRd
seas_card_tests <- function(x) {
  gl <- tryCatch(broom::glance(x), error = function(e) NULL)
  if (is.null(gl)) {
    return(htmltools::div(class = "seas-card__col"))
  }
  # The statistic alone does not say whether a test rejects, so the p-value
  # rides with the null hypothesis rather than in a column of its own.
  tests <- list(
    list("QS", gl$qs, gl$qs.p.value, "no seasonality in the adjusted series"),
    list("Box-Ljung", gl$box.ljung, gl$box.ljung.p.value,
         "no residual autocorrelation"),
    list("Shapiro", gl$shapiro, gl$shapiro.p.value,
         "normal distribution of residuals")
  )
  htmltools::div(
    class = "seas-card__col",
    lapply(tests, function(t) {
      if (is.null(t[[2L]]) || !length(t[[2L]]) || is.na(t[[2L]])) return(NULL)
      htmltools::div(
        class = "seas-kv seas-kv--test",
        htmltools::span(
          class = "seas-kv__k",
          t[[1L]],
          htmltools::tags$em(
            "H0: ", t[[4L]],
            if (!is.null(t[[3L]]) && !is.na(t[[3L]])) {
              paste0(" · p ", format(round(t[[3L]], 3), nsmall = 3))
            }
          )
        ),
        htmltools::span(class = "seas-kv__v", format(round(t[[2L]], 4)))
      )
    })
  )
}

#' Two decimals, except where two decimals would print an effect as zero
#'
#' The weekday coefficient of an AirPassengers fit is -0.0029, and "-0.00" is
#' not a number anyone can read. Right-aligned tabular figures, so the ragged
#' width costs nothing.
#' @noRd
seas_fmt_est <- function(x) {
  if (!is.finite(x)) {
    return("")
  }
  if (abs(x) < 0.005) format(signif(x, 2)) else format(round(x, 2), nsmall = 2)
}

#' The significance ladder, blockr.stats'
#' @noRd
seas_chip <- function(p) {
  if (is.null(p) || !is.finite(p) || p >= 0.1) {
    return(NULL)
  }
  step <- if (p < 0.001) "" else if (p < 0.01) " seas-chip--1" else
    if (p < 0.05) " seas-chip--5" else " seas-chip--10"
  label <- if (p < 0.001) "0.1%" else if (p < 0.01) "1%" else
    if (p < 0.05) "5%" else "10%"
  htmltools::span(class = paste0("seas-chip", step), label)
}

#' @noRd
seas_card_css_dep <- function() {
  htmltools::htmlDependency(
    name = "seas-card-css",
    version = seas_asset_version(),
    src = system.file("css", package = "blockr.seasonal"),
    stylesheet = "seas-card.css"
  )
}
