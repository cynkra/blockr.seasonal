#' Five Best Models Block
#'
#' Displays the five best ARIMA models considered during seasonal adjustment.
#' Shows model specifications and their AICc values.
#'
#' @param ... Additional arguments passed to new_transform_block
#'
#' @export
new_fivebestmdl_block <- function(...) {
  blockr.core::new_transform_block(
    function(id) {
      moduleServer(
        id,
        function(input, output, session) {
          # Display the five best models
          output$models_output <- renderPrint({
            req(input_data())

            model <- input_data()
            if (inherits(model, "seas")) {
              # Use fivebestmdl function from seasonal
              seasonal::fivebestmdl(model)
            }
          })

          list(
            expr = reactive({
              # Expression to get five best models
              expr_text <- "seasonal::fivebestmdl(data)"
              parse(text = expr_text)[[1]]
            }),
            # Return the fivebestmdl output
            result = reactive({
              req(input_data())

              tryCatch(
                {
                  model <- input_data()

                  # Check if input is a seas model
                  if (!inherits(model, "seas")) {
                    stop("Input must be a seas model object")
                  }

                  # Get five best models (returns text output)
                  # Capture the output as text
                  output_text <- capture.output(seasonal::fivebestmdl(model))

                  # Return as a character vector
                  # In future, this could be parsed into a data frame
                  list(
                    text = paste(output_text, collapse = "\n"),
                    raw = output_text
                  )
                },
                error = function(e) {
                  showNotification(
                    paste("Five best models error:", e$message),
                    type = "error"
                  )
                  NULL
                }
              )
            }),
            state = list()
          )
        }
      )
    },
    function(id) {
      tagList(
        div(
          class = "fivebestmdl-block-container",

          tags$style(HTML(
            "
            .fivebestmdl-block-container {
              padding: 15px;
              background: #f8f9fa;
              border-radius: 8px;
            }
            .fivebestmdl-title {
              margin-bottom: 10px;
              color: #495057;
              font-size: 16px;
              font-weight: bold;
            }
            .models-output {
              background: white;
              border: 1px solid #dee2e6;
              border-radius: 4px;
              padding: 12px;
              font-family: 'Courier New', monospace;
              font-size: 12px;
              max-height: 400px;
              overflow-y: auto;
              white-space: pre-wrap;
            }
            "
          )),

          div(
            class = "fivebestmdl-title",
            "Five Best ARIMA Models"
          ),

          div(
            class = "models-output",
            verbatimTextOutput(NS(id, "models_output"))
          ),

          helpText(
            "Shows the five best ARIMA models considered during automatic model selection. ",
            "Models are ranked by AICc (Akaike Information Criterion corrected). ",
            "Lower AICc values indicate better model fit."
          )
        )
      )
    },
    class = "fivebestmdl_block",
    ...
  )
}
