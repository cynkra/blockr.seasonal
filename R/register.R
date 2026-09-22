#' Register seasonal adjustment blocks
#'
#' Register all seasonal adjustment blocks with the blockr registry
#'
#' @export
register_seasonal_blocks <- function() {
  blockr.core::register_blocks(
    c(
      "new_seas_block",
      "new_seas_multi_block",
      "new_seas_triage_block",
      "new_final_block",
      "new_monthplot_block",
      "new_series_block",
      "new_seas_series_block",
      "new_fivebestmdl_block",
      "new_udg_block",
      "new_summary_block"
    ),
    name = c(
      "Seasonal Adjustment",
      "Seasonal Adjustment (many series)",
      "Triage Table",
      "Final Plot",
      "Monthplot",
      "Series Extraction",
      "Seas series",
      "Five Best Models",
      "UDG Statistics",
      "Enhanced Summary"
    ),
    description = c(
      "Perform seasonal adjustment using X-13ARIMA-SEATS",
      "Adjust every series in a long data frame with one specification",
      "One sorted row per series: model, diagnostics, and distance from a reference",
      "Plot original vs seasonally adjusted series",
      "Display seasonal patterns by month",
      "Extract time series components from seas model",
      "One series out of a fitted X-13 model: 217 codes, searched by description",
      "Show five best ARIMA models from automatic selection",
      "Extract detailed X-13 statistics using udg() function",
      "Enhanced model diagnostics and statistical tests"
    ),
    category = c(
      "transform",
      "transform",
      "table",
      "plot",
      "plot",
      "transform",
      "transform",
      "transform",
      "transform",
      "transform"
    ),
    package = utils::packageName(),
    overwrite = TRUE
  )
}
