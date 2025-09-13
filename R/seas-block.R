#' Seasonal Adjustment Block
#'
#' Performs seasonal adjustment using X-13ARIMA-SEATS via the seasonal package.
#' This block introduces a novel pattern in blockr: returning a statistical model
#' object rather than data, enabling downstream blocks to consume the model.
#'
#' @param seas_call String containing the complete seas() call (default: "seas(x = x, x11 = list())")
#' @param ... Additional arguments passed to new_transform_block
#'
#' @export
new_seas_block <- function(
  seas_call = "seas(x = x, x11 = list())",
  ...
) {
  blockr.core::new_transform_block(
    server = function(id, x) {
      # Named input x instead of generic data
      moduleServer(
        id,
        function(input, output, session) {
          # Initialize reactive values with r_ prefix
          r_seas_call <- reactiveVal(seas_call)

          # Input observers
          observeEvent(input$seas_call, {
            r_seas_call(input$seas_call)
          })

          list(
            expr = reactive({
              # Build expression for blockr to evaluate
              call_text <- r_seas_call()

              # Auto-prefix seas with seasonal:: if not already present
              if (!grepl("seasonal::", call_text)) {
                call_text <- gsub("seas\\(", "seasonal::seas(", call_text)
              }

              # Create expression that converts x to ts and evaluates seas
              expr_text <- glue::glue(
                "local({{
                  x <- tsbox::ts_ts(x)
                  {call_text}
                }})"
              )

              parse(text = expr_text)[[1]]
            }),
            state = list(
              seas_call = r_seas_call
            )
          )
        }
      )
    },
    ui = function(id) {
      tagList(
        div(
          class = "seas-block-container",

          # CSS for clean layout
          tags$style(HTML(
            "
            .seas-block-container {
              padding: 15px;
              background: #f8f9fa;
              border-radius: 8px;
            }
            .seas-section {
              margin-bottom: 20px;
            }
            .seas-section h4 {
              margin-top: 0;
              margin-bottom: 10px;
              color: #495057;
              font-size: 16px;
            }
            .ace-editor-container {
              border: 1px solid #dee2e6;
              border-radius: 4px;
              overflow: hidden;
            }
            .summary-container {
              max-height: 400px;
              overflow-y: auto;
              background: white;
              border: 1px solid #dee2e6;
              border-radius: 4px;
              padding: 10px;
              font-family: monospace;
              font-size: 12px;
            }
            "
          )),

          # Seas call editor section
          div(
            class = "seas-section",
            h4("Seasonal Adjustment Specification"),
            div(
              class = "ace-editor-container",
              shinyAce::aceEditor(
                NS(id, "seas_call"),
                value = seas_call,
                mode = "r",
                theme = "textmate",
                height = "100px",
                fontSize = 14,
                showLineNumbers = FALSE,
                highlightActiveLine = TRUE
              )
            ),
            helpText(
              "Enter the complete seas() call. Examples: ",
              "seas(x = x, x11 = list()), ",
              "seas(x = x, seats = list()), ",
              "seas(x = x, x11 = list(mode = 'mult'))"
            )
          )
        )
      )
    },
    class = "seas_block",
    allow_empty_state = character(0),
    ...
  )
}

#' @export
block_ui.seas_block <- function(id, x, ...) {
  tagList(
    verbatimTextOutput(NS(id, "result"))
  )
}

#' @export
block_output.seas_block <- function(x, result, session) {
  renderPrint({
    if (is.null(result)) {
      return(NULL)
    }

    # Display the seas model summary
    if (inherits(result, "seas")) {
      summary(result)
    } else {
      cat("No seasonal adjustment model available")
    }
  })
}
