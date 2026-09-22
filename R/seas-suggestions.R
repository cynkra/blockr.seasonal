#' What to try, in seasonal.website's own words
#'
#' The block opens empty, because leaving an argument out is what X-13 does
#' best. A line above the picker suggests a few things to change, and every
#' phrase in it is a label from `seasonalview:::lFOpts` -- the option lists
#' behind seasonal.website's six dropdowns -- rather than wording of ours.
#' Someone who has used the website reads the same strings here.
#'
#' THE PHRASE IS A LABEL, NOT A HIDING PLACE. Clicking one adds the argument
#' it names as an ordinary row, with the value in its control, so what it did
#' is on screen a line later and can be changed or removed like anything else.
#'
#' The AUTOMATIC entries of those lists are deliberately absent: *AIC Test*,
#' *Auto Search*, *Auto Critical Value* and *AIC Test Easter* are what
#' `seas()` already does, so clicking them would add a line to the call that
#' changes nothing.
#'
#' @section Why some are `alt`:
#' Several labels write one argument -- three transformations, three critical
#' values. Only the first of each is in the sentence; the others wait behind
#' the picker, because once the row exists its control offers all of them
#' anyway.
#'
#' @return A list of suggestions, each with the argument `name` it writes, the
#'   `value` it writes, the website's label (`say`), the words that make it a
#'   sentence (`before`, `after`), the website question it belongs to (`of`),
#'   and whether it is an alternative to one already listed (`alt`).
#' @noRd
seas_suggestions <- function() {
  list(
    sug("x11", "", "X11", "the ", " method", "Adjustment Method"),

    sug("transform.function", "log", "Logarithmic",
        "a ", " transformation", "Pre-Transformation"),
    sug("transform.function", "sqrt", "Square Root",
        "a ", " transformation", "Pre-Transformation", alt = TRUE),
    sug("transform.function", "none", "No Transformation",
        "", "", "Pre-Transformation", alt = TRUE),

    sug("regression.variables", list("td"), "6-Coefficients",
        "", " for trading days", "Trading Days"),
    sug("regression.variables", list("td1coef"), "1-Coefficient",
        "", " for trading days", "Trading Days", alt = TRUE),
    sug("regression.variables", list("easter[8]"), "1-Week before Easter",
        "", "", "Holiday", alt = TRUE),
    sug("regression.variables", list("easter[1]"), "1-Day before Easter",
        "", "", "Holiday", alt = TRUE),

    sug("outlier.critical", "3", "Low Critical Value (3)",
        "a ", " for outliers", "Outlier"),
    sug("outlier.critical", "4", "Medium Critical Value (4)",
        "a ", " for outliers", "Outlier", alt = TRUE),
    sug("outlier.critical", "5", "High Critical Value (5)",
        "a ", " for outliers", "Outlier", alt = TRUE),

    sug("arima.model", "(0 1 1)(0 1 1)", "(0 1 1)(0 1 1)",
        "the ", " model", "Arima Model")
  )
}

#' @noRd
sug <- function(name, value, say, before, after, of, alt = FALSE) {
  list(name = name, value = value, say = say, before = before,
       after = after, of = of, alt = alt)
}
