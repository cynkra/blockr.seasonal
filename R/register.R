#' Register seasonal adjustment blocks
#'
#' Register all seasonal adjustment blocks with the blockr registry
#'
#' @export
register_seasonal_blocks <- function() {
  blockr.core::register_blocks(
    c(
      "new_seas_block",
      "new_seas_triage_block",
      "new_seas_series_block",
      "new_fivebestmdl_block",
      "new_udg_block",
      "new_summary_block"
    ),
    name = c(
      "Seasonal Adjustment",
      "Triage Table",
      "Seas series",
      "Five Best Models",
      "UDG Statistics",
      "Enhanced Summary"
    ),
    description = c(
      "Perform seasonal adjustment using X-13ARIMA-SEATS",
      "One sorted row per series: model, diagnostics, and distance from a reference",
      "One series out of a fitted X-13 model: 217 codes, searched by description",
      "Show five best ARIMA models from automatic selection",
      "Extract detailed X-13 statistics using udg() function",
      "Enhanced model diagnostics and statistical tests"
    ),
    category = c(
      "transform",
      "table",
      "transform",
      "transform",
      "transform",
      "transform"
    ),
    package = utils::packageName(),
    overwrite = TRUE
  )
}
