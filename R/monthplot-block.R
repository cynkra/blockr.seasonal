#' Monthplot Block
#'
#' Displays seasonal patterns by month/period using the monthplot function.
#' Shows the seasonal subseries for each period across years.
#'
#' @param ... Additional arguments passed to new_plot_block
#'
#' @export
new_monthplot_block <- function(...) {
  blockr.core::new_plot_block(
    server = function(id, data) {
      moduleServer(
        id,
        function(input, output, session) {
          list(
            expr = reactive({
              # Simple expression: call monthplot on the seas model
              # monthplot.seas S3 method will be dispatched automatically
              expr_text <- "monthplot(data)"
              parse(text = expr_text)[[1]]
            }),
            state = list()
          )
        }
      )
    },
    ui = function(id) {
      tagList(
        div(
          class = "monthplot-block-container",

          tags$style(HTML(
            "
            .monthplot-block-container {
              padding: 10px;
              background: #f8f9fa;
              border-radius: 4px;
            }
            .monthplot-block-title {
              margin-bottom: 10px;
              color: #495057;
              font-size: 14px;
              font-weight: bold;
            }
            "
          )),

          div(
            class = "monthplot-block-title",
            "Seasonal Patterns by Period"
          ),

          helpText(
            "Displays seasonal patterns across periods (months/quarters). ",
            "Each line represents a different year, showing seasonal variation."
          )
        )
      )
    },
    class = "monthplot_block",
    ...
  )
}
