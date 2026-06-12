# Series Explorer Panel Registry
#
# Builds panel definitions from series_codes.rds for the series explorer block.
# Each panel renders one X-13ARIMA-SEATS series as an echarts4r line chart.

# -- Spec category colors -----------------------------------------------------

sx_spec_colors <- function() {
  list(
    Core          = "#3b82f6",
    X11           = "#059669",
    Seats         = "#8b5cf6",
    Regression    = "#ea580c",
    Spectrum      = "#dc2626",
    History       = "#9333ea",
    Transform     = "#0d9488",
    Forecast      = "#2563eb",
    Slidingspans  = "#c026d3",
    Estimate      = "#65a30d",
    Identify      = "#475569",
    Outlier       = "#b91c1c",
    Check         = "#ca8a04",
    Force         = "#6366f1",
    Series        = "#64748b"
  )
}

# -- Default selection ---------------------------------------------------------

#' @noRd
sx_default_panels <- function() {
  c("final", "seasonal", "trend", "irregular", "original")
}

# -- Specs excluded or method-locked -------------------------------------------

#' Specs that always fail (need special model configs we can't guarantee)
#' @noRd
sx_excluded_specs <- function() {
  c("Composite", "X11regression")
}

#' Specs shown by default (without "Advanced" toggle)
#' @noRd
sx_basic_specs <- function() {
  c("Core", "Seats", "X11", "Forecast", "Transform", "Series")
}

#' Series codes that return non-plottable types (data.frame)
#' @noRd
sx_excluded_codes <- function() {
  c("acm", "rcm", "rts", "iac", "ipc")
}

#' Map spec -> required method ("x11", "seats", or "any")
#' @noRd
sx_spec_method <- function(spec) {
  switch(spec,
    X11   = "x11",
    Seats = "seats",
    "any"
  )
}

#' Detect whether a seas model uses X-11 or SEATS
#' @noRd
sx_model_method <- function(model) {
  if (!is.null(model$spc$x11)) "x11" else "seats"
}

# -- Series extraction ---------------------------------------------------------

#' Extract a series from a seas model
#'
#' Core aliases use dedicated extractors; everything else uses
#' \code{seasonal::series()}.
#'
#' @param model A seas model object
#' @param code Series short_name code
#' @return A ts/mts object, or NULL
#' @noRd
sx_extract_series <- function(model, code) {
  switch(code,
    final     = seasonal::final(model),
    trend     = seasonal::trend(model),
    irregular = seasonal::irregular(model),
    original  = seasonal::original(model),
    seasonal  = {
      tryCatch(
        seasonal::series(model, "s10"),
        error = function(e) seasonal::series(model, "d10")
      )
    },
    seasonal::series(model, code)
  )
}

# -- Empty chart ---------------------------------------------------------------

#' @noRd
sx_empty_chart <- function(msg) {
  echarts4r::e_charts(height = 80) |>
    echarts4r::e_list(list(
      title = list(
        text = msg,
        left = "center", top = "center",
        textStyle = list(fontSize = 13, color = "#9ca3af", fontWeight = 400)
      ),
      xAxis = list(show = FALSE),
      yAxis = list(show = FALSE)
    ))
}

# -- Matrix fallback -----------------------------------------------------------

#' Convert a plain matrix (e.g. ACF/PACF tables) to a long data frame
#'
#' Uses row index as "time" and reshapes columns into an \code{id} column
#' so \code{sx_render_series()} can plot each column as a separate line.
#'
#' @param mat A matrix with named columns
#' @return A data frame with time, value, id columns
#' @noRd
sx_matrix_to_tbl <- function(mat) {
  if (!is.matrix(mat) || ncol(mat) == 0) return(NULL)
  cnames <- colnames(mat)
  if (is.null(cnames)) cnames <- paste0("V", seq_len(ncol(mat)))
  idx <- seq_len(nrow(mat))

  # Use first column only if there are too many (e.g. 5-col diagnostic tables)
  # to keep the chart readable
  use_cols <- if (ncol(mat) <= 3) seq_len(ncol(mat)) else 1L

  rows <- lapply(use_cols, function(j) {
    data.frame(
      time = as.Date("1970-01-01") + idx,
      value = mat[, j],
      id = cnames[j],
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

# -- Panel registry ------------------------------------------------------------

#' Build panel definitions from series_codes.rds
#'
#' Excludes Composite and X11regression specs (always fail) and non-plottable
#' codes.  Each panel carries a \code{method} field (\code{"x11"},
#' \code{"seats"}, or \code{"any"}) so the block can filter at runtime.
#'
#' @return Named list of panel definitions
#' @noRd
series_explorer_panels <- function() {
  series_codes_file <- system.file(
    "extdata", "series_codes.rds",
    package = "blockr.seasonal"
  )

  if (file.exists(series_codes_file)) {
    series_codes <- readRDS(series_codes_file)
  } else {
    series_codes <- data.frame(
      spec = c("Core", "Core", "Core", "Core", "Core"),
      short_name = c("original", "final", "seasonal", "trend", "irregular"),
      description = c(
        "Original series",
        "Seasonally adjusted (final) series",
        "Seasonal component",
        "Trend-cycle component",
        "Irregular component"
      ),
      stringsAsFactors = FALSE
    )
  }

  # Filter out always-failing specs and non-plottable codes
  excluded_specs <- sx_excluded_specs()
  excluded_codes <- sx_excluded_codes()
  keep <- !(series_codes$spec %in% excluded_specs) &
          !(series_codes$short_name %in% excluded_codes)
  series_codes <- series_codes[keep, ]

  colors <- sx_spec_colors()

  panels <- lapply(seq_len(nrow(series_codes)), function(i) {
    row <- series_codes[i, ]
    code <- row$short_name
    spec <- row$spec
    color <- colors[[spec]] %||% "#64748b"
    method <- sx_spec_method(spec)

    list(
      id = code,
      label = code,
      description = row$description,
      category = spec,
      method = method,
      color = color,
      render = local({
        .code <- code
        .color <- color
        function(model) {
          ts_data <- tryCatch(
            sx_extract_series(model, .code),
            error = function(e) NULL
          )
          if (is.null(ts_data)) {
            return(sx_empty_chart(
              paste("Series", .code, "not available for this model")
            ))
          }

          tbl <- tryCatch(
            tsbox::ts_tbl(ts_data),
            error = function(e) NULL
          )

          # Fallback for plain matrix (ACF, PACF, etc.)
          if (is.null(tbl) && is.matrix(ts_data)) {
            tbl <- sx_matrix_to_tbl(ts_data)
          }

          if (is.null(tbl) || nrow(tbl) == 0) {
            return(sx_empty_chart(
              paste("Series", .code, "returned no data")
            ))
          }

          sx_render_series(tbl, .code, .color)
        }
      })
    )
  })

  stats::setNames(panels, vapply(panels, `[[`, character(1L), "id"))
}

# -- Chart renderer ------------------------------------------------------------

#' Render a time series as an echarts4r line chart
#'
#' Handles single-series (ts) and multi-series (mts) data.
#' \code{tsbox::ts_tbl()} on an mts produces a data frame with an \code{id}
#' column — each unique id becomes a separate line.
#'
#' @param tbl Data frame with time, value columns (and optionally id)
#' @param code Series code
#' @param color Base line colour (used for single-series; multi-series
#'   get auto-assigned colours)
#' @noRd
sx_render_series <- function(tbl, code, color) {
  if (nrow(tbl) == 0) return(sx_empty_chart("No data"))

  # Normalise column names
  if (!"time" %in% colnames(tbl) && "time" %in% tolower(colnames(tbl))) {
    colnames(tbl)[tolower(colnames(tbl)) == "time"] <- "time"
  }
  if (!"value" %in% colnames(tbl) && "value" %in% tolower(colnames(tbl))) {
    colnames(tbl)[tolower(colnames(tbl)) == "value"] <- "value"
  }

  has_id <- "id" %in% colnames(tbl)
  ids <- if (has_id) unique(tbl$id) else code

  multi_colors <- c(
    "#3b82f6", "#059669", "#dc2626", "#d97706", "#8b5cf6",
    "#0891b2", "#ea580c", "#9333ea", "#65a30d", "#c026d3"
  )

  series_list <- list()
  for (idx in seq_along(ids)) {
    s <- ids[idx]
    sub <- if (has_id) tbl[tbl$id == s, ] else tbl
    sub <- sub[order(sub$time), ]

    data_points <- lapply(seq_len(nrow(sub)), function(i) {
      list(value = list(
        as.numeric(as.POSIXct(sub$time[i])) * 1000,
        sub$value[i]
      ))
    })

    s_color <- if (length(ids) == 1) {
      color
    } else {
      multi_colors[((idx - 1L) %% length(multi_colors)) + 1L]
    }

    series_list[[idx]] <- list(
      type = "line",
      name = s,
      data = data_points,
      smooth = TRUE,
      showSymbol = FALSE,
      lineStyle = list(color = s_color, width = 2),
      itemStyle = list(color = s_color)
    )
  }

  # Area gradient for single-series only
  if (length(ids) == 1) {
    hex <- sub("^#", "", color)
    cr <- strtoi(substr(hex, 1, 2), 16L)
    cg <- strtoi(substr(hex, 3, 4), 16L)
    cb <- strtoi(substr(hex, 5, 6), 16L)
    series_list[[1]]$areaStyle <- list(color = list(
      type = "linear", x = 0, y = 0, x2 = 0, y2 = 1,
      colorStops = list(
        list(offset = 0.05,
             color = sprintf("rgba(%d,%d,%d,0.15)", cr, cg, cb)),
        list(offset = 0.95,
             color = sprintf("rgba(%d,%d,%d,0)", cr, cg, cb))
      )
    ))
    series_list[[1]]$lineStyle$width <- 2.5
  }

  show_legend <- length(ids) > 1

  echarts4r::e_charts(height = 250) |>
    echarts4r::e_list(list(
      backgroundColor = "transparent",
      tooltip = list(
        trigger = "axis",
        confine = TRUE,
        backgroundColor = "rgba(255,255,255,0.98)",
        borderColor = "#d1d5db",
        borderWidth = 1,
        textStyle = list(color = "#1f2937", fontSize = 12)
      ),
      legend = list(
        show = show_legend, bottom = 0, left = "center",
        textStyle = list(fontSize = 11, color = "#6b7280")
      ),
      grid = list(
        left = 50, right = 20, top = 10,
        bottom = if (show_legend) 35 else 20,
        borderColor = "transparent"
      ),
      xAxis = list(
        type = "time",
        axisLine = list(show = FALSE),
        axisTick = list(show = FALSE),
        axisLabel = list(color = "#9ca3af", fontSize = 11),
        splitLine = list(show = FALSE)
      ),
      yAxis = list(
        type = "value",
        axisLine = list(show = FALSE),
        axisTick = list(show = FALSE),
        axisLabel = list(color = "#9ca3af", fontSize = 11),
        splitLine = list(
          show = TRUE,
          lineStyle = list(color = "#e5e7eb", type = "dashed")
        )
      ),
      series = series_list
    ))
}
