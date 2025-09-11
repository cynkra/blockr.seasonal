#' Register seasonal adjustment blocks
#'
#' Register all seasonal adjustment blocks with the blockr registry
#'
#' @export
register_seasonal_blocks <- function() {
  blockr.core::register_blocks(
    c(
      "new_seas_block",
      "new_final_block",
      "new_monthplot_block",
      "new_series_block",
      "new_fivebestmdl_block"
    ),
    name = c(
      "Seasonal Adjustment",
      "Final Plot",
      "Monthplot",
      "Series Extraction",
      "Five Best Models"
    ),
    description = c(
      "Perform seasonal adjustment using X-13ARIMA-SEATS",
      "Plot original vs seasonally adjusted series",
      "Display seasonal patterns by month",
      "Extract time series components from seas model",
      "Show five best ARIMA models from automatic selection"
    ),
    category = c(
      "transform",
      "plot",
      "plot",
      "transform",
      "transform"
    ),
    package = utils::packageName(),
    overwrite = TRUE
  )
}
