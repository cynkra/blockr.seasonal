library(blockr.core)
library(blockr.seasonal)

# Test single block serving with direct data
serve(
  new_seas_block(seas_call = "seas(x = x, x11 = list())"),
  data = list(x = tsbox::ts_tbl(AirPassengers))
)