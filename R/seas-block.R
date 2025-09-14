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

          # Submit button observer - format and apply
          observeEvent(input$submit, {
            call_text <- input$seas_call %||% ""

            # Format the code first
            formatted_code <- format_seas_call(call_text)

            # Update the editor with formatted code if it changed
            if (formatted_code != call_text) {
              shinyAce::updateAceEditor(
                session,
                "seas_call",
                value = formatted_code
              )
            }

            # Apply the formatted code
            apply_seas_call(formatted_code)
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

            .custom-dropdown-menu {
              max-height: 400px;
              overflow-y: auto;
              min-width: 250px;
            }

            .dropdown-header {
              font-weight: 600;
              color: #495057;
              padding: 4px 16px;
              margin-top: 4px;
            }

            .dropdown-item {
              display: block;
              padding: 6px 16px;
              font-size: 14px;
              color: #212529;
              text-decoration: none;
              white-space: nowrap;
              cursor: pointer;
            }

            .dropdown-item:hover {
              background-color: #f8f9fa;
              color: #16181b;
            }

            .btn-outline-secondary {
              border-color: #6c757d;
            }

            .btn-outline-secondary:hover {
              background-color: #6c757d;
              color: white;
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
              value = format_seas_call(seas_call),  # Format on startup
              height = "260px"  # Increased by ~3 lines (20px per line)
            ),

            # Examples dropdown and help
            div(
              style = "margin-top: 10px; position: relative;",

              # Custom dropdown menu for examples
              div(
                style = "display: inline-block; margin-right: 15px; position: relative;",
                tags$button(
                  class = "btn btn-outline-secondary",
                  type = "button",
                  id = NS(id, "examplesDropdown"),
                  onclick = sprintf("toggleExamplesDropdown('%s')", NS(id, "examplesMenu")),
                  style = "display: flex; align-items: center; gap: 5px;",
                  icon("lightbulb"),
                  " Insert Example ",
                  tags$span(style = "font-size: 12px;", "▼")
                ),
                div(
                  id = NS(id, "examplesMenu"),
                  class = "custom-dropdown-menu",
                  style = "display: none; position: absolute; top: 100%; left: 0; z-index: 1000; background: white; border: 1px solid #dee2e6; border-radius: 4px; box-shadow: 0 2px 5px rgba(0,0,0,0.1); margin-top: 2px;",

                  # Basic models
                  h6(class = "dropdown-header", "Basic Models"),
                  tags$a(
                    class = "dropdown-item seas-example-item",
                    href = "#",
                    onclick = sprintf("insertExample('%s', 'seas(x = x, x11 = list())'); return false;", NS(id, "seas_call")),
                    "X-11 Adjustment"
                  ),
                  tags$a(
                    class = "dropdown-item seas-example-item",
                    href = "#",
                    onclick = sprintf("insertExample('%s', 'seas(x = x)'); return false;", NS(id, "seas_call")),
                    "SEATS (default)"
                  ),

                  div(class = "dropdown-divider", style = "margin: 0; border-top: 1px solid #dee2e6;"),

                  # Transformations
                  h6(class = "dropdown-header", "Transformations"),
                  tags$a(
                    class = "dropdown-item seas-example-item",
                    href = "#",
                    onclick = sprintf("insertExample('%s', 'seas(x = x, transform.function = \"log\")'); return false;", NS(id, "seas_call")),
                    "Log transformation"
                  ),
                  tags$a(
                    class = "dropdown-item seas-example-item",
                    href = "#",
                    onclick = sprintf("insertExample('%s', 'seas(x = x, transform.power = 0)'); return false;", NS(id, "seas_call")),
                    "Box-Cox (auto λ)"
                  ),
                  tags$a(
                    class = "dropdown-item seas-example-item",
                    href = "#",
                    onclick = sprintf("insertExample('%s', 'seas(x = x, transform.function = \"auto\")'); return false;", NS(id, "seas_call")),
                    "Auto transformation"
                  ),

                  div(class = "dropdown-divider", style = "margin: 0; border-top: 1px solid #dee2e6;"),

                  # ARIMA models
                  h6(class = "dropdown-header", "ARIMA Models"),
                  tags$a(
                    class = "dropdown-item seas-example-item",
                    href = "#",
                    onclick = sprintf("insertExample('%s', 'seas(x = x, arima.model = \"(0 1 1)(0 1 1)\")'); return false;", NS(id, "seas_call")),
                    "Airline model"
                  ),
                  tags$a(
                    class = "dropdown-item seas-example-item",
                    href = "#",
                    onclick = sprintf("insertExample('%s', 'seas(x = x, arima.model = \"(1 1 0)(0 1 1)\")'); return false;", NS(id, "seas_call")),
                    "ARIMA (1,1,0)(0,1,1)"
                  ),
                  tags$a(
                    class = "dropdown-item seas-example-item",
                    href = "#",
                    onclick = sprintf("insertExample('%s', 'seas(x = x, automdl = list())'); return false;", NS(id, "seas_call")),
                    "Auto ARIMA selection"
                  ),

                  div(class = "dropdown-divider", style = "margin: 0; border-top: 1px solid #dee2e6;"),

                  # Advanced
                  h6(class = "dropdown-header", "Advanced Options"),
                  tags$a(
                    class = "dropdown-item seas-example-item",
                    href = "#",
                    onclick = sprintf("insertExample('%s', 'seas(x = x, regression.variables = c(\"td\", \"easter[8]\"))'); return false;", NS(id, "seas_call")),
                    "Trading days & Easter"
                  ),
                  tags$a(
                    class = "dropdown-item seas-example-item",
                    href = "#",
                    onclick = sprintf("insertExample('%s', 'seas(x = x, outlier.types = c(\"ao\", \"ls\", \"tc\"))'); return false;", NS(id, "seas_call")),
                    "Outlier detection"
                  ),
                  tags$a(
                    class = "dropdown-item seas-example-item",
                    href = "#",
                    onclick = sprintf("insertExample('%s', 'seas(x = x, forecast.maxlead = 24)'); return false;", NS(id, "seas_call")),
                    "24-month forecast"
                  )
                )
              ),

              # Inline help text
              span(
                class = "text-muted small",
                style = "line-height: 32px;",
                tags$code("Ctrl+Space"), ": autocomplete | ",
                "Drag bottom edge to resize editor"
              ),

              # JavaScript for dropdown and inserting examples
              tags$script(HTML("
                function toggleExamplesDropdown(menuId) {
                  var menu = document.getElementById(menuId);
                  if (menu) {
                    menu.style.display = menu.style.display === 'none' ? 'block' : 'none';
                  }
                }

                function formatSeasCall(code_text) {
                  // Port of R's format_seas_call function
                  if (!code_text || code_text.trim() === '') {
                    return code_text || '';
                  }

                  try {
                    code_text = code_text.trim();

                    // Basic formatting for seas() calls
                    if (/^(seasonal::)?seas\\s*\\(/.test(code_text)) {
                      // Remove extra whitespace
                      code_text = code_text.replace(/\\s+/g, ' ');

                      // Split on commas that are not inside nested parentheses or quotes
                      var chars = code_text.split('');
                      var paren_level = 0;
                      var in_quotes = false;
                      var quote_char = '';
                      var splits = [];

                      for (var i = 0; i < chars.length; i++) {
                        var char = chars[i];

                        if (!in_quotes && (char === '\"' || char === \"'\")) {
                          in_quotes = true;
                          quote_char = char;
                        } else if (in_quotes && char === quote_char && (i === 0 || chars[i - 1] !== '\\\\')) {
                          in_quotes = false;
                          quote_char = '';
                        } else if (!in_quotes) {
                          if (char === '(') {
                            paren_level++;
                          } else if (char === ')') {
                            paren_level--;
                          } else if (char === ',' && paren_level === 1) {
                            // Found a top-level comma in seas()
                            splits.push(i);
                          }
                        }
                      }

                      if (splits.length > 0) {
                        // Split the string at the comma positions
                        var parts = [];
                        var start_pos = 0;

                        for (var j = 0; j < splits.length; j++) {
                          var split_pos = splits[j];
                          var part = code_text.substring(start_pos, split_pos);
                          parts.push(part.trim());
                          start_pos = split_pos + 1;
                        }
                        // Add the last part
                        if (start_pos < code_text.length) {
                          var last_part = code_text.substring(start_pos);
                          parts.push(last_part.trim());
                        }

                        // Reconstruct with proper formatting
                        if (parts.length > 1) {
                          var first_part = parts[0];  // 'seas(x = x'

                          // Build list of formatted arguments (all except first)
                          var formatted_args = [];

                          // Process all arguments except the first
                          for (var k = 1; k < parts.length; k++) {
                            var part = parts[k];
                            // Check if this is the last part and has closing parenthesis
                            if (k === parts.length - 1 && /\\)\\s*$/.test(part)) {
                              // Remove closing parenthesis from the argument
                              var arg = part.replace(/\\)\\s*$/, '').trim();
                              if (arg.length > 0) {
                                formatted_args.push('  ' + arg);
                              }
                            } else {
                              // Regular argument
                              formatted_args.push('  ' + part.trim());
                            }
                          }

                          // Build final result
                          if (/\\)\\s*$/.test(parts[parts.length - 1])) {
                            // Has closing parenthesis
                            return first_part + ',\\n' + formatted_args.join(',\\n') + '\\n)';
                          } else {
                            // No closing parenthesis
                            return first_part + ',\\n' + formatted_args.join(',\\n');
                          }
                        }
                      }
                    }

                    // If no formatting needed or failed, return original
                    return code_text;
                  } catch(e) {
                    // If formatting fails, return original
                    return code_text || '';
                  }
                }

                function insertExample(editorId, example) {
                  var editorEl = document.getElementById(editorId);
                  if (editorEl) {
                    var editor = ace.edit(editorEl);
                    // Format the example using the same logic as R
                    var formattedExample = formatSeasCall(example);
                    editor.setValue(formattedExample);
                    editor.clearSelection();
                    editor.focus();
                  }
                  // Close dropdown
                  var dropdowns = document.querySelectorAll('.custom-dropdown-menu');
                  dropdowns.forEach(function(dd) {
                    dd.style.display = 'none';
                  });
                }

                // Close dropdown when clicking outside
                document.addEventListener('click', function(e) {
                  if (!e.target.closest('.btn-outline-secondary') && !e.target.closest('.custom-dropdown-menu')) {
                    var dropdowns = document.querySelectorAll('.custom-dropdown-menu');
                    dropdowns.forEach(function(dd) {
                      dd.style.display = 'none';
                    });
                  }
                });
              "))
            )
          ),

          # Submit button section
          div(
            class = "seas-submit-section",
            actionButton(
              NS(id, "submit"),
              "Apply Changes",
              icon = icon("paper-plane"),
              class = "btn btn-success btn-seas-submit"
            ),
            br(),
            div(
              class = "small text-muted mt-2",
              "Click to format and apply your seasonal adjustment specification"
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
