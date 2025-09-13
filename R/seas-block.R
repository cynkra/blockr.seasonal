#' Seasonal Adjustment Block
#'
#' Performs seasonal adjustment using X-13ARIMA-SEATS via the seasonal package.
#' This block introduces a novel pattern in blockr: returning a statistical model
#' object rather than data, enabling downstream blocks to consume the model.
#'
#' Features:
#' - Height-adjustable ACE editor with resizing handle
#' - Comprehensive autocomplete for seas() parameters and values
#' - Submit button with validation (changes applied only on submit)
#' - Enhanced syntax highlighting for R code
#' - Error handling with user-friendly notifications
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

          # Store the validated expression and state
          r_expr_validated <- reactiveVal(NULL)
          r_seas_call_validated <- reactiveVal(seas_call)

          # Update autocomplete categories on startup (completer already in UI)
          observe({
            initialize_seas_ace_editor(session)
          })

          # Format button observer
          observeEvent(input$format, {
            current_code <- input$seas_call %||% ""
            formatted_code <- format_seas_call(current_code)

            if (formatted_code != current_code) {
              shinyAce::updateAceEditor(
                session,
                "seas_call",
                value = formatted_code
              )

              showNotification(
                "Code formatted with one argument per line",
                type = "message",
                duration = 2
              )
            } else {
              showNotification(
                "Code is already well formatted",
                type = "message",
                duration = 2
              )
            }
          })

          # Parse and validate seas call
          parse_seas_call <- function(call_text) {
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
          }

          # Initialize with default expression
          observe({
            if (is.null(r_expr_validated())) {
              tryCatch({
                expr <- parse_seas_call(r_seas_call_validated())
                r_expr_validated(expr)
              }, error = function(e) {
                # Keep NULL if initial parse fails
                NULL
              })
            }
          })

          # Apply changes when submit button is clicked
          apply_seas_call <- function(call_text) {
            if (identical(trimws(call_text), "")) {
              showNotification(
                "Please enter a seas() call",
                type = "warning",
                duration = 3
              )
              return()
            }

            # Validation
            expr <- try(parse_seas_call(call_text), silent = TRUE)
            if (inherits(expr, "try-error")) {
              showNotification(
                paste("Parse error:", as.character(expr)),
                type = "error",
                duration = 5
              )
              return()
            }

            # Test evaluation (without actually running on data)
            tryCatch({
              # Just validate the expression structure
              r_expr_validated(expr)
              r_seas_call_validated(call_text)
              r_seas_call(call_text)

              showNotification(
                "Seasonal adjustment specification updated",
                type = "message",
                duration = 2
              )
            }, error = function(e) {
              showNotification(
                paste("Validation error:", e$message),
                type = "error",
                duration = 5
              )
            })
          }

          # Submit button observer
          observeEvent(input$submit, {
            call_text <- input$seas_call %||% ""
            apply_seas_call(call_text)
          })

          list(
            expr = reactive({
              r_expr_validated()
            }),
            state = list(
              seas_call = r_seas_call_validated
            )
          )
        }
      )
    },
    ui = function(id) {
      tagList(
        # Include shinyjs for JavaScript functionality
        shinyjs::useShinyjs(),

        div(
          class = "seas-block-container",

          # Enhanced CSS for modern layout
          tags$style(HTML(
            "
            .seas-block-container {
              padding: 20px;
              background: #f8f9fa;
              border-radius: 12px;
              box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            }

            .seas-section {
              margin-bottom: 25px;
            }

            .seas-section h4 {
              margin-top: 0;
              margin-bottom: 12px;
              color: #495057;
              font-size: 18px;
              font-weight: 600;
            }

            .seas-help-text {
              margin-top: 12px;
              padding: 12px;
              background: #e3f2fd;
              border-left: 4px solid #2196f3;
              border-radius: 4px;
              font-size: 13px;
              color: #1565c0;
              line-height: 1.5;
            }

            .seas-submit-section {
              text-align: right;
              margin-top: 20px;
              padding-top: 15px;
              border-top: 1px solid #dee2e6;
            }

            .btn-seas-submit {
              background: #28a745;
              border: none;
              padding: 10px 24px;
              font-weight: 500;
              transition: all 0.2s;
            }

            .btn-seas-submit:hover {
              background: #218838;
              transform: translateY(-1px);
            }

            .btn-seas-format {
              border: 2px solid #007bff;
              color: #007bff;
              padding: 10px 20px;
              font-weight: 500;
              transition: all 0.2s;
            }

            .btn-seas-format:hover {
              background: #007bff;
              color: white;
              transform: translateY(-1px);
            }

            .btn-group .btn {
              border-radius: 6px;
              margin-right: 10px;
            }

            .btn-group .btn:last-child {
              margin-right: 0;
            }

            .seas-examples {
              margin-top: 8px;
              font-size: 12px;
              color: #6c757d;
            }

            .seas-examples code {
              background: #f1f3f4;
              padding: 2px 4px;
              border-radius: 3px;
              font-family: 'Monaco', 'Consolas', monospace;
            }
            "
          )),

          # Seas call editor section with enhanced UI
          div(
            class = "seas-section",
            h4(
              icon("cogs"),
              " Seasonal Adjustment Specification"
            ),

            # Height-adjustable ACE editor with embedded autocomplete
            setup_seas_ace_editor(
              NS(id, "seas_call"),
              value = seas_call,
              height = "200px"
            ),

            # Enhanced help text with examples
            div(
              class = "seas-help-text",
              strong("💡 Tips:"),
              br(),
              "• Use ", tags$code("Ctrl+Space"), " for autocompletion",
              br(),
              "• Try: ", tags$code("transform.power = 0"), " for Box-Cox transformation",
              br(),
              "• Resize editor by dragging the bottom edge",

              div(
                class = "seas-examples",
                br(),
                strong("Common examples:"),
                br(),
                "Basic X-11: ", tags$code("seas(x = x, x11 = list())"),
                br(),
                "SEATS: ", tags$code("seas(x = x, seats = list())"),
                br(),
                "Multiplicative: ", tags$code("seas(x = x, x11 = list(mode = 'mult'))"),
                br(),
                "With transformation: ", tags$code("seas(x = x, transform.power = 0, x11 = list())")
              )
            )
          ),

          # Submit button section
          div(
            class = "seas-submit-section",
            div(
              class = "btn-group",
              role = "group",
              actionButton(
                NS(id, "format"),
                "Format Code",
                icon = icon("indent"),
                class = "btn btn-outline-primary btn-seas-format"
              ),
              actionButton(
                NS(id, "submit"),
                "Apply Changes",
                icon = icon("paper-plane"),
                class = "btn btn-success btn-seas-submit"
              )
            ),
            br(),
            div(
              class = "small text-muted mt-2",
              "Use ", strong("Format Code"), " to organize arguments (one per line), then ", strong("Apply Changes"), " to update the model"
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
