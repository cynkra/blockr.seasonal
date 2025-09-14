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
