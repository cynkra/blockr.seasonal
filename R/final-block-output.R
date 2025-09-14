#' Custom Output Method for Final Block
#'
#' Displays dygraph with optional outlier annotations
#' @export
block_output.final_block <- function(x, result, session) {
  dygraphs::renderDygraph({
    if (is.null(result)) {
      return(NULL)
    }

    # Get number of series to determine colors
    n_series <- if ("id" %in% names(result)) {
      length(unique(result$id))
    } else {
      1
    }

    # Use tsbox colors palette
    colors_to_use <- tsbox::colors_tsbox()[seq_len(n_series)]

    # Convert to xts and create dygraph
    ts_data <- tsbox::ts_xts(result)
    dygraph <- dygraphs::dygraph(ts_data)

    # Apply styling
    dygraph <- dygraphs::dyOptions(
      dygraph,
      fillGraph = FALSE,
      drawGrid = TRUE,
      colors = colors_to_use,
      strokeWidth = 2.5
    )
    dygraph <- dygraphs::dyRangeSelector(dygraph, height = 20)

    # Add outlier annotations if available and enabled
    # Get the seas model from the result attribute
    model <- attr(result, "seas_model")

    # Get show_outliers state from the block
    show_outliers <- TRUE  # Default to TRUE
    if (!is.null(x$state) && !is.null(x$state$show_outliers)) {
      if (is.function(x$state$show_outliers)) {
        show_outliers <- x$state$show_outliers()
      } else {
        show_outliers <- x$state$show_outliers
      }
    }

    if (!is.null(model) && inherits(model, "seas") && show_outliers) {
      tryCatch({
        outliers <- seasonal::outlier(model)
        idx <- which(!is.na(outliers))

        if (length(idx) > 0) {
          outlier_times <- time(outliers)[idx]
          outlier_types <- as.character(outliers[idx])

          # Add annotation for each outlier
          for (i in seq_along(idx)) {
            # Convert time series time to date
            year <- floor(outlier_times[i])
            month <- round((outlier_times[i] %% 1) * 12) + 1
            outlier_date <- as.Date(paste0(year, "-", sprintf("%02d", month), "-01"))

            dygraph <- dygraphs::dyAnnotation(
              dygraph,
              x = outlier_date,
              text = outlier_types[i],
              width = 25,
              height = 25,
              tickHeight = 10
            )
          }
        }
      }, error = function(e) {
        # Debug: print error for development
        message("Error adding outlier annotations: ", e$message)
      })
    }

    dygraph
  })
}

#' Custom UI Method for Final Block
#' @export
block_ui.final_block <- function(id, x, ...) {
  tagList(
    dygraphs::dygraphOutput(NS(id, "result"))
  )
}