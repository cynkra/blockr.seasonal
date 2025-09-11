#' Seasonal Adjustment Block
#'
#' Performs seasonal adjustment using X-13ARIMA-SEATS via the seasonal package.
#' This block introduces a novel pattern in blockr: returning a statistical model
#' object rather than data, enabling downstream blocks to consume the model.
#'
#' @param seas_call String containing the complete seas() call (default: "seas(x = x, x11 = list())")
#' @param show_summary Whether to display model summary in the block
#' @param ... Additional arguments passed to new_transform_block
#'
#' @export
new_seas_block <- function(
  seas_call = "seas(x = x, x11 = list())",
  show_summary = TRUE,
  ...
) {
  blockr.core::new_transform_block(
    function(id, x) {  # Named input x instead of generic data
      moduleServer(
        id,
        function(input, output, session) {
          # Initialize reactive values with r_ prefix
          r_seas_call <- reactiveVal(seas_call)
          r_show_summary <- reactiveVal(show_summary)
          
          # Track the model for summary display
          r_model <- reactiveVal(NULL)
          
          # Input observers
          observeEvent(input$seas_call, {
            r_seas_call(input$seas_call)
          })
          
          observeEvent(input$show_summary, {
            r_show_summary(input$show_summary)
          })
          
          # Summary output
          output$summary <- renderPrint({
            if (r_show_summary() && !is.null(r_model())) {
              tryCatch({
                summary(r_model())
              }, error = function(e) {
                cat("Model not yet computed or error in model summary")
              })
            }
          })
          
          list(
            expr = reactive({
              # Build expression using parse/glue pattern
              call_text <- r_seas_call()
              
              # Auto-prefix seas with seasonal:: if not already present
              if (!grepl("seasonal::", call_text)) {
                call_text <- gsub("seas\\(", "seasonal::seas(", call_text)
              }
              
              # Pre-process x to ts format, then evaluate user's complete seas() call
              expr_text <- glue::glue(
                "{{
                  x <- tsbox::ts_ts(x)
                  {call_text}
                }}"
              )
              
              parse(text = expr_text)[[1]]
            }),
            # Execute expression and store model for summary
            result = reactive({
              # Check if x exists and has data
              if (!length(x())) {
                return(NULL)
              }
              
              tryCatch({
                # Get the data from upstream
                input_data <- x()
                
                # Pre-process and evaluate the seas call
                call_text <- r_seas_call()
                
                # Auto-prefix seas with seasonal:: if not already present
                if (!grepl("seasonal::", call_text)) {
                  call_text <- gsub("seas\\(", "seasonal::seas(", call_text)
                }
                
                # Create environment with x as the input data
                env <- new.env()
                env$x <- tsbox::ts_ts(input_data)
                
                # Parse and execute the seas() call
                expr <- parse(text = call_text)[[1]]
                model <- eval(expr, envir = env)
                
                r_model(model)
                
                # Return the model for downstream blocks
                model
              }, error = function(e) {
                showNotification(
                  paste("Seasonal adjustment error:", e$message),
                  type = "error"
                )
                NULL
              })
            }),
            state = list(
              seas_call = r_seas_call,
              show_summary = r_show_summary
            )
          )
        }
      )
    },
    function(id) {
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
          ),
          
          # Summary display control
          checkboxInput(
            NS(id, "show_summary"),
            label = "Show model summary",
            value = show_summary
          ),
          
          # Summary output section
          conditionalPanel(
            condition = paste0("input['", NS(id, "show_summary"), "'] == true"),
            div(
              class = "seas-section",
              h4("Model Summary"),
              div(
                class = "summary-container",
                verbatimTextOutput(NS(id, "summary"))
              )
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