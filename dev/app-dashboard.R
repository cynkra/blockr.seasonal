# Seasonal adjustment dashboard -- the whole block set on one board.
#
#   ts dataset -> seas -> { series explorer, final, monthplot, udg }
#
# The seas block returns a `seas` MODEL, not data. Everything downstream reads
# that one fit, so changing the specification in the argument builder moves all
# four views at once.
#
#   Rscript blockr.seasonal/dev/app-dashboard.R
pkgload::load_all("/workspace/blockr.core", quiet = TRUE)
pkgload::load_all("/workspace/blockr.dag", quiet = TRUE)
pkgload::load_all("/workspace/blockr.dock", quiet = TRUE)
pkgload::load_all("/workspace/blockr.ts", quiet = TRUE)
pkgload::load_all("/workspace/blockr.seasonal", quiet = TRUE)

options(blockr.dock_is_locked = FALSE)

board <- blockr.dock::new_dock_board(
  blocks = c(
    data = blockr.ts::new_ts_dataset_block(dataset = "AirPassengers"),
    seas = new_seas_block(),
    explorer = new_series_explorer_block(),
    final = new_final_block(),
    month = new_monthplot_block(),
    udg = new_udg_block()
  ),
  links = blockr.core::links(
    from = c("data", "seas", "seas", "seas", "seas"),
    to   = c("seas", "explorer", "final", "month", "udg")
  ),
  extensions = list(blockr.dag::new_dag_extension())
)

# blockr_port() is defined in .devcontainer/.Rprofile; 3838-3847 is the only
# range forwarded to the host.
port <- if (exists("blockr_port")) blockr_port() else 3838L
message("http://localhost:", port)
shiny::runApp(serve(board, "seasonal_dashboard"),
              port = port, host = "0.0.0.0", launch.browser = FALSE)
