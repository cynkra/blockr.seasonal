# new_seas_series_block(), on a board.
#
#   Rscript blockr.seasonal/dev/app-seas-series.R
#
# Three tabs:
#
#   SEATS model  the fitted model, from a static block rather than
#                new_seas_block(), which is in flight in another session.
#   Seas series  the block, opened on original + adjusted + trend, which is
#                the seasonal adjustment view and used to be three blocks.
#                One multi-select over the 217 X-13 codes, description as the
#                label and the code trailing, grouped by spec, searched over
#                both. The chart is ts_display's, not one of ours.
#   X11 model    the same block against an X11 fit, so the list changes: X11
#                tables appear and the SEATS ones leave, because series()
#                errors on a code the model's method did not compute.
for (p in c("blockr.core", "blockr.ui", "blockr.dag", "blockr.dock",
            "blockr.dplyr", "blockr.ts", "blockr.seasonal")) {
  pkgload::load_all(file.path("/workspace", p), quiet = TRUE)
}

options(
  blockr.dock_is_locked = FALSE,
  blockr.tabular_display = blockr.ts::ts_display
)

seats <- seasonal::seas(datasets::AirPassengers)
x11 <- seasonal::seas(datasets::AirPassengers, x11 = "")

message("SEATS saves: ", paste(names(seats$series), collapse = ", "))
message("offered: ", nrow(blockr.seasonal:::seas_series_choices(seats)),
        " (SEATS)  ", nrow(blockr.seasonal:::seas_series_choices(x11)), " (X11)")

board <- blockr.dock::new_dock_board(
  blocks = c(
    fit = blockr.core::new_static_block(seats, block_name = "A SEATS model"),
    series = blockr.seasonal::new_seas_series_block(
      series = c("original", "final", "trend"), block_name = "Seas series"
    ),
    fit11 = blockr.core::new_static_block(x11, block_name = "An X11 model"),
    series11 = blockr.seasonal::new_seas_series_block(
      series = "d10", block_name = "Seas series (X11)"
    )
  ),
  links = blockr.core::links(
    from = c("fit", "fit11"),
    to = c("series", "series11")
  ),
  extensions = list(blockr.dag::new_dag_extension())
)

port <- if (exists("blockr_port")) blockr_port() else 3838L
message("http://localhost:", port)
shiny::runApp(serve(board, "seas_series"),
              port = port, host = "0.0.0.0", launch.browser = FALSE)
