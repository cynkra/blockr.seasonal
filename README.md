# blockr.seasonal

Seasonal adjustment capabilities for the blockr ecosystem using X-13ARIMA-SEATS and TRAMO/SEATS. This package introduces a new pattern in blockr: blocks that output statistical model objects rather than data or plots, enabling reactive model-based workflows.

## Installation

```r
pak::pak("cynkra/blockr.seasonal")
```

## Quick Start

```r
library(blockr.core)
library(blockr.seasonal)
library(blockr.ts)

# Simple seasonal adjustment
serve(
  new_board(
    blocks = c(
      data = blockr.ts::new_ts_dataset_block(dataset = "AirPassengers"),
      seas = new_seas_block(seas_call = "seas(x = x, x11 = list())"),
      final = new_final_block()
    ),
    links = c(
      new_link("data", "seas"),
      new_link("seas", "final")
    )
  )
)
```

## Comprehensive Dashboard Example

This example demonstrates **ALL available blocks** in blockr.seasonal:

```r
library(blockr.core)
library(blockr.seasonal)
library(blockr.ts)

# Complete seasonal adjustment dashboard with all blocks
serve(
  new_board(
    blocks = c(
      # Data input
      data = blockr.ts::new_ts_dataset_block(dataset = "AirPassengers"),

      # Main seasonal adjustment block with interactive editor
      seas = new_seas_block(
        seas_call = "seas(x = x, x11 = list())"
      ),

      # Visualization blocks
      final = new_final_block(),           # Original vs adjusted series
      month = new_monthplot_block(),       # Seasonal patterns by month

      # Diagnostic blocks
      series = new_series_block(            # Extract components
        series = "d10"
      ),
      models = new_fivebestmdl_block(),    # Five best ARIMA models
      udg = new_udg_block(),                # X-13 statistics via udg()
      summary = new_summary_block()        # Enhanced model summary
    ),

    # Link all blocks to the seasonal adjustment model
    links = c(
      new_link("data", "seas"),
      new_link("seas", "final"),
      new_link("seas", "month"),
      new_link("seas", "series"),
      new_link("seas", "models"),
      new_link("seas", "udg"),
      new_link("seas", "summary")
    )
  )
)
```

## Key Innovation: Model-as-Output Pattern

blockr.seasonal is the **first blockr package where blocks output statistical model objects**. The main `new_seas_block()` outputs a `seas` model that downstream blocks consume for visualization and analysis.

### Benefits of This Pattern

✅ **Single model computation** with multiple diagnostic views
✅ **Reactive updates** across all diagnostics when model changes
✅ **Natural workflow** for statistical modeling in blockr
✅ **Efficient computation** - model calculated once, used many times

### How It Works

```
┌──────────────────────────────────────────┐
│         SEAS MODEL BLOCK                 │
│  [Interactive seas() specification]      │
│  [Model summary output]                  │
└──────────────────────────────────────────┘
                    ↓
    ┌───────────────┴───────────────┐
    ↓               ↓               ↓
┌─────────┐   ┌─────────┐   ┌─────────┐
│ Final   │   │ Month   │   │ Series  │
│ Plot    │   │ Plot    │   │ Extract │
└─────────┘   └─────────┘   └─────────┘
```

## Available Blocks

### Core Block

#### `new_seas_block()`

Creates the main seasonal adjustment block using X-13ARIMA-SEATS.

**Parameters:**
- `seas_call`: String containing the complete seas() call (default: `"seas(x = x, x11 = list())"`)

**Features:**
- Interactive Ace editor for modifying seasonal adjustment specifications
- Real-time model summary display
- Error handling for invalid specifications
- Outputs seas model object for downstream blocks

### Visualization Blocks

#### `new_final_block()`

Displays original vs seasonally adjusted series.

**Input:** seas model from `new_seas_block()`
**Output:** Interactive dygraph showing both series overlaid

#### `new_monthplot_block()`

Shows seasonal patterns by month/period.

**Input:** seas model from `new_seas_block()`
**Output:** Monthplot showing seasonal subseries

### Transform/Extract Blocks

#### `new_series_block()`

Extracts specific components from the seasonal adjustment.

**Parameters:**
- `component`: Component to extract ("trend", "seasonal", "irregular", "final", etc.)

**Input:** seas model from `new_seas_block()`
**Output:** blockr.ts time series object (can be used with any blockr.ts blocks)

### Diagnostic Blocks

#### `new_fivebestmdl_block()`

Compares the five best ARIMA models from automatic model selection.

**Input:** seas model from `new_seas_block()`
**Output:** Model comparison table showing BIC, AIC, and other statistics

#### `new_udg_block()`

Extracts detailed X-13 statistics using the `udg()` function.

**Input:** seas model from `new_seas_block()`
**Output:** Comprehensive X-13 diagnostics and statistics

#### `new_summary_block()`

Enhanced model diagnostics and statistical tests.

**Input:** seas model from `new_seas_block()`
**Output:** Detailed diagnostic summary with tests and quality measures

### Using External Regressors

```r
library(blockr.core)
library(blockr.seasonal)

# Prepare data with Chinese New Year regressor
air_data <- tsbox::ts_tbl(datasets::AirPassengers)
cny_regressor <- tsbox::ts_tbl(
  seasonal::genhol(seasonal::cny, start = 0, end = 6, center = "calendar")
)

# Seasonal adjustment with external regressor
# Both x and xreg are automatically converted to ts format inside the block
blockr.core::serve(
  new_seas_block(
    seas_call = "seas(x = x, xreg = xreg, regression.variables = 'td')"
  ),
  data = list(
    x = air_data,
    xreg = cny_regressor
  )
)
```

## Future Enhancements

- **Additional Plots**: Spectrum analysis, SI ratios, residual diagnostics
- **Model Comparison**: Side-by-side evaluation of different specifications
- **Export Capabilities**: Save adjusted series and models
- **Advanced UI**: More sophisticated controls beyond ace editor
