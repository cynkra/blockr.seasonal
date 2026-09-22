#' Register seasonal adjustment blocks
#'
#' Three entries, where there were six. The seas block returns the fitted
#' model and reads itself through `ts_model_view()`, so the blocks that
#' existed to render a fit -- an HTML summary, a picker over `udg()`'s 348
#' statistics, the five candidate models -- were answering a question the
#' block now answers about itself. What is left is one block per SHAPE: fit a
#' model, take series out of a fit, put many fits in a table.
#'
#' @export
register_seasonal_blocks <- function() {
  blockr.core::register_blocks(
    c(
      "new_seas_block",
      "new_seas_series_block",
      "new_seas_triage_block"
    ),
    name = c(
      "Seasonal Adjustment",
      "Seas series",
      "Triage Table"
    ),
    description = c(
      "Perform seasonal adjustment using X-13ARIMA-SEATS",
      "One series out of a fitted X-13 model: 212 codes, searched by description",
      "One sorted row per series: model, diagnostics, and distance from a reference"
    ),
    category = c(
      "transform",
      "transform",
      "table"
    ),
    package = utils::packageName(),
    overwrite = TRUE
  )
}
