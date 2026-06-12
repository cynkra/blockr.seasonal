# Series Explorer Demo
#
# Pipeline:
#   ts_data → seas model → series explorer
pkgload::load_all("blockr.core")
pkgload::load_all("blockr.dag")
pkgload::load_all("blockr.dock")
pkgload::load_all("blockr.ts")
pkgload::load_all("blockr.seasonal")

board <- blockr.dock::new_dock_board(
  blocks = c(
    data = blockr.ts::new_ts_dataset_block(dataset = "AirPassengers"),
    seas = new_seas_block(),
    explorer = new_series_explorer_block()
  ),
  links = blockr.core::links(
    from = c("data", "seas"),
    to = c("seas", "explorer")
  ),
  extensions = list(
    blockr.dag::new_dag_extension()
  )
)

app <- serve(board, "series_explorer_demo")
shiny::runApp(app)
