#' Final Series Block
#'
#' Extracts the seasonally adjusted series (and optionally the original series)
#' from a seas model and displays it as a dygraph with outlier annotations.
#'
#' @param include_original Logical. Include the original series alongside the adjusted series (default: TRUE)
#' @param show_outliers Logical. Display outlier annotations on the plot (default: TRUE)
#' @param ... Additional arguments passed to new_ts_transform_block
#'
#' @export
new_final_block <- function(include_original = TRUE, show_outliers = TRUE, ...) {
  blockr.ts::new_ts_transform_block(
    server = function(id, data) {
      moduleServer(
        id,
        function(input, output, session) {
          # Initialize reactive values with r_ prefix
          r_include_original <- reactiveVal(include_original)
          r_show_outliers <- reactiveVal(show_outliers)

          # Input observers
          observeEvent(input$include_original, {
            r_include_original(input$include_original)
          })

          observeEvent(input$show_outliers, {
            r_show_outliers(input$show_outliers)
          })

          list(
            expr = reactive({
              include_orig <- r_include_original()

              if (include_orig) {
                # Return both original and adjusted series
                expr_text <- "
                {
                  # Extract series from seas model
                  original <- seasonal::original(data)
                  adjusted <- seasonal::final(data)

                  # Combine into multivariate ts object
                  combined <- cbind(Original = original, Adjusted = adjusted)

                  # Convert to tsbox format for dygraph display
                  result <- tsbox::ts_tbl(combined)

                  # Attach the seas model as an attribute for outlier extraction
                  attr(result, 'seas_model') <- data
                  result
                }"
              } else {
                # Return only adjusted series
                expr_text <- "
                {
                  # Extract adjusted series from seas model
                  adjusted <- seasonal::final(data)

                  # Convert to tsbox format for dygraph display
                  result <- tsbox::ts_tbl(adjusted)

                  # Attach the seas model as an attribute for outlier extraction
                  attr(result, 'seas_model') <- data
                  result
                }"
              }

              parse(text = expr_text)[[1]]
            }),
            state = list(
              include_original = r_include_original,
              show_outliers = r_show_outliers
            )
          )
        }
      )
    },
    ui = function(id) {
      tagList(
        div(
          class = "final-block-container",

          tags$style(HTML(
            "
            .final-block-container {
              padding: 10px;
              background: #f8f9fa;
              border-radius: 4px;
            }
            .final-block-title {
              margin-bottom: 10px;
              color: #495057;
              font-size: 14px;
              font-weight: bold;
            }
            "
          )),

          div(
            class = "final-block-title",
            "Seasonally Adjusted Series"
          ),

          checkboxInput(
            NS(id, "include_original"),
            label = "Include original series",
            value = include_original
          ),

          checkboxInput(
            NS(id, "show_outliers"),
            label = "Show outlier annotations",
            value = show_outliers
          ),

          helpText(
            "Displays the seasonally adjusted series from the seasonal adjustment model.",
            "When 'Include original series' is checked, also shows the original series for comparison.",
            "When 'Show outlier annotations' is checked, displays detected outliers as annotations on the plot."
          )
        )
      )
    },
    class = "final_block",
    ...
  )
}

#' Custom UI Method for Final Block
#' @export
block_ui.final_block <- function(id, x, ...) {
  tagList(
    dygraphs::dygraphOutput(NS(id, "result"))
  )
}

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
