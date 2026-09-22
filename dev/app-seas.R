# The seas block, on the blockr.ts contract.
#
#   Rscript blockr.seasonal/dev/app-seas.R
#
# One board, two tabs: the series that goes in, and the model that comes out.
# The block returns a `seas` object and draws anyway, because
# `ts_resolve.seas()` tells blockr.ts's display how a model becomes a frame.
for (p in c("blockr.core", "blockr.ui", "blockr.dag", "blockr.dock",
            "blockr.ts", "blockr.seasonal")) {
  pkgload::load_all(file.path("/workspace", p), quiet = TRUE)
}

options(
  blockr.dock_is_locked = FALSE,
  blockr.tabular_display = blockr.ts::ts_display
)

board <- blockr.dock::new_dock_board(
  blocks = c(
    series = blockr.ts::new_ts_dataset_block(
      dataset = "AirPassengers", block_name = "Series"
    ),
    adjust = blockr.seasonal::new_seas_block(block_name = "seas")
  ),
  links = blockr.core::links(from = "series", to = "adjust"),
  extensions = list(blockr.dag::new_dag_extension())
)

port <- if (exists("blockr_port")) blockr_port() else 3838L
message("http://localhost:", port)
shiny::runApp(serve(board, "seas"), port = port, host = "0.0.0.0",
              launch.browser = FALSE)
