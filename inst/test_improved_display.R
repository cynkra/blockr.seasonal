library(blockr.core)
library(blockr.seasonal)
library(blockr.ts)

# Create a seasonal adjustment dashboard with improved display
board <- new_board(
  blocks = c(
    data = new_ts_dataset_block(dataset = "AirPassengers"),
    seas = new_seas_block(seas_call = "seas(x = x, x11 = list())"),
    month = new_monthplot_block()
  ),
  links = c(
    new_link("data", "seas"),
    new_link("seas", "month")
  )
)

# Serve the dashboard
serve(board)
