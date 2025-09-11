#' Series Extraction Block
#'
#' Extracts specific components from a seas model as time series.
#' Returns blockr.ts compatible time series objects that can be
#' used with other blockr.ts blocks.
#'
#' @param component Which component to extract ("final", "seasonal", "trend", "irregular", "original")
#' @param ... Additional arguments passed to new_transform_block
#'
#' @export
new_series_block <- function(
  component = "final",
  ...
) {
  blockr.core::new_transform_block(
    function(id) {
      moduleServer(
        id,
        function(input, output, session) {
          # Initialize reactive values
          r_component <- reactiveVal(component)
          
          # Input observers
          observeEvent(input$component, {
            r_component(input$component)
          })
          
          # Display extracted series info
          output$series_info <- renderPrint({
            req(input_data())
            
            model <- input_data()
            if (inherits(model, "seas")) {
              comp <- r_component()
              series <- switch(
                comp,
                "original" = seasonal::original(model),
                "final" = seasonal::final(model),
                "seasonal" = seasonal::seasonal(model),
                "trend" = seasonal::trend(model),
                "irregular" = seasonal::irregular(model),
                NULL
              )
              
              if (!is.null(series)) {
                cat("Time Series Properties:\n")
                cat("- Frequency:", frequency(series), "\n")
                cat("- Start:", paste(start(series), collapse = "/"), "\n")
                cat("- End:", paste(end(series), collapse = "/"), "\n")
                cat("- Length:", length(series), "observations\n")
              }
            }
          })
          
          list(
            expr = reactive({
              # Build extraction expression
              comp <- r_component()
              expr_text <- glue::glue(
                "seasonal::{comp}(data)"
              )
              parse(text = expr_text)[[1]]
            }),
            # Extract the series
            result = reactive({
              req(input_data())
              
              tryCatch({
                model <- input_data()
                
                # Check if input is a seas model
                if (!inherits(model, "seas")) {
                  stop("Input must be a seas model object")
                }
                
                # Extract the specified component
                comp <- r_component()
                series <- switch(
                  comp,
                  "original" = seasonal::original(model),
                  "final" = seasonal::final(model),
                  "seasonal" = seasonal::seasonal(model),
                  "trend" = seasonal::trend(model),
                  "irregular" = seasonal::irregular(model),
                  seasonal::final(model)  # default
                )
                
                # Return as blockr.ts compatible time series
                # The series is already a ts object from seasonal package
                series
              }, error = function(e) {
                showNotification(
                  paste("Series extraction error:", e$message),
                  type = "error"
                )
                NULL
              })
            }),
            state = list(
              component = r_component
            )
          )
        }
      )
    },
    function(id) {
      tagList(
        div(
          class = "series-block-container",
          
          tags$style(HTML(
            "
            .series-block-container {
              padding: 15px;
              background: #f8f9fa;
              border-radius: 8px;
            }
            .series-section {
              margin-bottom: 15px;
            }
            .series-section label {
              font-weight: bold;
              color: #495057;
              font-size: 14px;
            }
            .series-info {
              background: white;
              border: 1px solid #dee2e6;
              border-radius: 4px;
              padding: 10px;
              font-family: monospace;
              font-size: 12px;
              margin-top: 10px;
            }
            "
          )),
          
          div(
            class = "series-section",
            selectInput(
              NS(id, "component"),
              label = "Component to Extract",
              choices = c(
                "Original Series" = "original",
                "Seasonally Adjusted (Final)" = "final",
                "Seasonal Component" = "seasonal",
                "Trend Component" = "trend",
                "Irregular Component" = "irregular"
              ),
              selected = component,
              width = "100%"
            )
          ),
          
          div(
            class = "series-info",
            verbatimTextOutput(NS(id, "series_info"))
          ),
          
          helpText(
            "Extracts time series components from the seasonal adjustment model. ",
            "The extracted series can be used with other blockr.ts blocks for further analysis."
          )
        )
      )
    },
    class = "series_block",
    allow_empty_state = character(0),
    ...
  )
}