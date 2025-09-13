# blockr.seasonal

Seasonal adjustment capabilities for the blockr ecosystem using X-13ARIMA-SEATS and TRAMO/SEATS. This package introduces a **novel pattern** in blockr: blocks that output statistical model objects rather than data or plots, enabling reactive model-based workflows.

## Installation

```r
# From GitHub
devtools::install_github("blockr/blockr.seasonal")

# From the monorepo
devtools::load_all("/path/to/blockr/blockr.seasonal")
```

## Quick Start

![Seasonal Adjustment Dashboard](man/figures/seasonal-dashboard.png)

```r
library(blockr.core)
library(blockr.seasonal)
library(blockr.ts)


serve(
  new_seas_block(
    seas_call = "seas(x = x, x11 = list())"),
  data = list(x = tsbox::ts_tbl(AirPassengers))
)

# Create a seasonal adjustment dashboard
board <- blockr.core::new_board(
  blocks = c(
    data = blockr.ts::new_ts_dataset_block(dataset = "AirPassengers"),
    seas = new_seas_block(seas_call = "seas(x)")
  ),
  links = c(
    blockr.core::new_link("data", "seas", "x")
  )
)

# Serve the dashboard
serve(board)


serve(
  new_seas_block(
    seas_call = "seas(x = x, x11 = list())"),
  data = list(x = tsbox::ts_tbl(AirPassengers))
)



# Create a seasonal adjustment dashboard
board <- new_board(
  blocks = c(
    data = blockr.ts::new_ts_dataset_block(dataset = "AirPassengers"),
    seas = new_seas_block(seas_call = "seas(x = x, x11 = list())"),
    summary = new_udg_block()
  ),
  links = c(
    new_link("data", "seas"),
    new_link("seas", "summary")
  )
)

# Serve the dashboard
serve(board)


# Create a seasonal adjustment dashboard
board <- new_board(
  blocks = c(
    data = blockr.ts::new_ts_dataset_block(dataset = "AirPassengers"),
    seas = new_seas_block(seas_call = "seas(x = x, x11 = list())"),
    summary = new_summary_block()
    # month = new_monthplot_block()
  ),
  links = c(
    new_link("data", "seas"),
    new_link("seas", "summary")
    # new_link("seas", "month")
  )
)

# Serve the dashboard
serve(board)
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

## Block Documentation

### Core Block

#### `new_seas_block()`

Creates the main seasonal adjustment block using X-13ARIMA-SEATS.

**Parameters:**
- `seas_call`: String containing the complete seas() call (default: `"seas(x = x, x11 = list())"`)
- `show_summary`: Boolean to display model summary in block (default: TRUE)

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

#### `new_series_block()`

Extracts specific components from the seasonal adjustment.

**Parameters:**
- `component`: Component to extract ("trend", "seasonal", "irregular", etc.)

**Input:** seas model from `new_seas_block()`
**Output:** blockr.ts time series object (can be used with any blockr.ts blocks)

### Diagnostic Blocks

#### `new_fivebestmdl_block()`

Compares the five best ARIMA models.

**Input:** seas model from `new_seas_block()`
**Output:** Model comparison table

#### `new_summary_block()`

Enhanced model diagnostics and statistical tests.

**Input:** seas model from `new_seas_block()`
**Output:** Detailed diagnostic summary

## Example Workflows

### Minimal Working Example

```r
library(blockr.core)
library(blockr.seasonal)
library(blockr.ts)

# Standalone usage - with data source
serve(
  new_board(
    blocks = c(
      data = blockr.ts::new_ts_dataset_block(dataset = "AirPassengers"),
      seas = new_seas_block(seas_call = "seas(x = x, x11 = list())")
    ),
    links = c(
      new_link("data", "seas")
    )
  )
)


```

### Basic Seasonal Adjustment

```r
# Simple X-11 adjustment
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

### Advanced Analysis with Multiple Views

```r
# Complex adjustment with diagnostics
serve(
  new_board(
    blocks = c(
      data = blockr.ts::new_ts_dataset_block(dataset = "AirPassengers"),
      seas = new_seas_block(
        seas_call = "seas(x = x, x11 = list(mode = 'mult'))",
        show_summary = TRUE
      ),
      final = new_final_block(),
      month = new_monthplot_block(),
      trend = new_series_block(component = "trend"),
      models = new_fivebestmdl_block()
    ),
    links = c(
      new_link("data", "seas"),
      new_link("seas", "final"),
      new_link("seas", "month"),
      new_link("seas", "trend"),
      new_link("seas", "models")
    )
  )
)
```

### Interactive Model Exploration

```r
# Real-time model specification editing
serve(
  new_board(
    blocks = c(
      data = blockr.ts::new_ts_dataset_block(dataset = "USAccDeaths"),
      # Try different specifications interactively:
      # "seas(x = x, x11 = list())"
      # "seas(x = x, seats = list())"
      # "seas(x = x, x11 = list(mode = 'mult'))"
      # "seas(x = x, x11 = list(x11.mode = 'logadd'))"
      seas = new_seas_block(seas_call = "seas(x = x, seats = list())"),
      final = new_final_block(),
      month = new_monthplot_block()
    ),
    links = c(
      new_link("data", "seas"),
      new_link("seas", "final"),
      new_link("seas", "month")
    )
  )
)
```

## Dependencies

- `seasonal`: Core seasonal adjustment functionality (X-13ARIMA-SEATS)
- `shinyAce`: Interactive editor for seas() specifications
- `blockr.core`: blockr framework
- `blockr.ts`: Time series compatibility and visualization
- `glue`: String interpolation for expression building

## Development

### Screenshot Validation

```r
# Generate screenshots to verify blocks work
source("inst/scripts/generate_seasonal_screenshot.R")
```

Screenshots validate that:
- ✅ Model block generates seas objects correctly
- ✅ Visualization blocks consume model and produce plots
- ✅ Component extraction returns proper time series
- ✅ All reactive updates work when model changes

### Key Patterns

1. **Model-as-Output**: First blockr package where blocks output statistical models
2. **Reactive Model Updates**: All downstream blocks react to model specification changes
3. **Expression Building**: Uses `parse(text = glue::glue())` pattern for clean code generation
4. **State Management**: All parameters properly tracked in reactive state
5. **Error Handling**: Graceful handling of invalid seasonal adjustment specifications

## Success Metrics

A successful blockr.seasonal implementation:

✅ **Introduces model-as-output pattern** to blockr ecosystem
✅ **Enables interactive seasonal adjustment** workflows
✅ **Provides essential diagnostic views** for time series analysis
✅ **Integrates seamlessly** with blockr.ts for time series handling
✅ **Maintains blockr coding standards** and patterns
✅ **Creates foundation** for statistical modeling blocks

## Future Enhancements

- **Broom Integration**: Tidy model summaries as data frames
- **Additional Plots**: Spectrum analysis, SI ratios, residual diagnostics
- **Model Comparison**: Side-by-side evaluation of different specifications
- **Export Capabilities**: Save adjusted series and models
- **Advanced UI**: More sophisticated controls beyond ace editor

---

**blockr.seasonal establishes the pattern for statistical modeling in blockr**, where models become first-class citizens that can be passed between blocks for analysis and visualization.