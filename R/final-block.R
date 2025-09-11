#' Final Plot Block
#'
#' Displays the original and seasonally adjusted series from a seas model.
#' This is the most important diagnostic plot for seasonal adjustment.
#'
#' @param ... Additional arguments passed to new_plot_block
#'
#' @export
new_final_block <- function(...) {
  blockr.core::new_plot_block(
    function(id, data) {
      moduleServer(
        id,
        function(input, output, session) {
          
          list(
            expr = reactive({
              # Extract final (adjusted) series from seas model
              expr_text <- "seasonal::final(data)"
              parse(text = expr_text)[[1]]
            }),
            # Transform the seas model into plottable data
            result = reactive({
              req(data())
              
              tryCatch({
                model <- data()
                
                # Check if input is a seas model
                if (!inherits(model, "seas")) {
                  stop("Input must be a seas model object")
                }
                
                # Extract original and adjusted series
                original <- seasonal::original(model)
                adjusted <- seasonal::final(model)
                
                # Combine into a single ts object for plotting
                combined <- cbind(
                  Original = original,
                  Adjusted = adjusted
                )
                
                # Return the combined series
                combined
              }, error = function(e) {
                showNotification(
                  paste("Final plot error:", e$message),
                  type = "error"
                )
                NULL
              })
            }),
            # Use blockr.ts plotting method
            plot_expr = reactive({
              # Use dygraphs via blockr.ts for consistency
              expr_text <- "blockr.ts:::plot_dygraph(data)"
              parse(text = expr_text)[[1]]
            }),
            state = list()
          )
        }
      )
    },
    function(id) {
      tagList(
        div(
          class = "final-block-container",
          
          tags$style(HTML(
            "
            .final-block-container {
              padding: 10px;
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
            "Original vs Seasonally Adjusted Series"
          ),
          
          helpText(
            "Compares the original time series with the seasonally adjusted series. ",
            "The adjusted series removes seasonal patterns while preserving trend and irregular components."
          )
        )
      )
    },
    class = "final_block",
    ...
  )
}