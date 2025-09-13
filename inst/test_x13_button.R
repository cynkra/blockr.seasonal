library(devtools)
load_all('.')
library(blockr.core)
library(blockr.ts)

# Create a board with the summary block containing X-13 Output button
board <- new_board(
  blocks = c(
    data = new_ts_dataset_block(dataset = "AirPassengers"),
    seas = new_seas_block(seas_call = "seas(x = x, x11 = list())"),
    summary = new_summary_block()
  ),
  links = c(
    new_link("data", "seas"),
    new_link("seas", "summary")
  )
)

# Generate screenshot for validation
blockr.core::generate_block_screenshot(
  board,
  file.path("inst", "screenshots", "summary_with_x13_button.png")
)

message("Screenshot saved to inst/screenshots/summary_with_x13_button.png")
