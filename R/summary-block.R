#' Summary Block for seas models
#'
#' Creates an enhanced HTML display of seas model summaries with both
#' formatted tables and the original R summary output.
#'
#' @param ... Additional arguments passed to new_transform_block
#'
#' @export
new_summary_block <- function(...) {
  blockr.core::new_transform_block(
    server = function(id, data) {
      moduleServer(
        id,
        function(input, output, session) {
          # Store the reactive seas model
          seas_model_reactive <- reactive({
            model <- data()
            if (!is.null(model) && inherits(model, "seas")) {
              model
            } else {
              NULL
            }
          })

          # Add observer for X-13 Output button
          observeEvent(input$x13_output, {
            seas_model <- seas_model_reactive()
            if (!is.null(seas_model)) {
              # Open X-13 output in browser
              seasonal::out(seas_model)
            }
          })

          list(
            expr = reactive({
              # Return the summary as a data frame with the seas model as attribute
              parse(
                text = "{
                df <- as.data.frame(summary(data))
                attr(df, \"seas_model\") <- data
                df
              }"
              )[[1]]
            }),
            state = list()
          )
        }
      )
    },
    ui = function(id) {
      tagList() # Empty UI, custom display handled by block_ui method
    },
    class = "summary_block",
    ...
  )
}

#' Generate HTML coefficients display (seasonalview-style)
#'
#' @param x A seas model object
#' @return HTML content for coefficients
html_coefs <- function(x) {
  tryCatch(
    {
      coefs <- coef(summary(x))
      if (is.null(coefs) || nrow(coefs) == 0) {
        return(div(
          style = "text-align: center; color: #6c757d; padding: 20px;",
          "No coefficients"
        ))
      }

      # Create significance symbols
      p_vals <- coefs[, "Pr(>|z|)"]
      signif_badges <- sapply(p_vals, function(p) {
        if (is.na(p)) {
          return("")
        }
        if (p < 0.001) {
          tags$span(
            class = "badge",
            style = "background-color: #0066cc;",
            "0.1%"
          )
        } else if (p < 0.01) {
          tags$span(class = "badge", style = "background-color: #17a2b8;", "1%")
        } else if (p < 0.05) {
          tags$span(class = "badge", style = "background-color: #6c757d;", "5%")
        } else if (p < 0.1) {
          tags$span(
            class = "badge",
            style = "background-color: #6c757d;",
            "10%"
          )
        } else {
          ""
        }
      })

      # Build coefficients table
      tags$table(
        class = "table table-condensed",
        style = "width: 100%; font-size: 13px;",
        tags$tbody(
          lapply(seq_len(nrow(coefs)), function(i) {
            tags$tr(
              tags$td(
                style = "padding: 4px 8px; font-weight: 500;",
                rownames(coefs)[i]
              ),
              tags$td(
                style = "padding: 4px 8px; text-align: right; font-family: monospace;",
                sprintf("%.2f", coefs[i, "Estimate"])
              ),
              tags$td(
                style = "padding: 4px 8px; text-align: right;",
                signif_badges[[i]]
              )
            )
          })
        )
      )
    },
    error = function(e) {
      div(
        style = "text-align: center; color: #6c757d; padding: 20px;",
        "No coefficients available"
      )
    }
  )
}

#' Generate HTML statistics display (seasonalview-style)
#'
#' @param x A seas model object
#' @param digits Number of digits for formatting
#' @return HTML content for statistics
html_stats <- function(x, digits = 5) {
  tryCatch(
    {
      s <- summary(x)

      # Determine adjustment method - check the spc list in the model
      adj_method <- if (!is.null(x$spc$seats)) {
        "SEATS"
      } else if (!is.null(x$spc$x11)) {
        "X-11"
      } else {
        "Unknown"
      }

      # Get ARIMA model
      arima_model <- tryCatch(
        {
          if (!is.null(s$model$arima$model)) {
            paste0("(", paste(s$model$arima$model, collapse = " "), ")")
          } else {
            "Auto"
          }
        },
        error = function(e) "Auto"
      )

      # Get transform function
      transform_func <- tryCatch(
        {
          s$transform.function %||% "none"
        },
        error = function(e) "none"
      )

      # Get observations count
      n_obs <- tryCatch(
        {
          length(x$x)
        },
        error = function(e) NA
      )

      # Get AICc
      aicc_val <- tryCatch(
        {
          formatC(AIC(x), digits = digits)
        },
        error = function(e) "NA"
      )

      # Get BIC
      bic_val <- tryCatch(
        {
          formatC(BIC(x), digits = digits)
        },
        error = function(e) "NA"
      )

      # Build statistics table
      stats_items <- list(
        c("Adjustment", adj_method),
        c("ARIMA", arima_model),
        c("Obs.", n_obs),
        c("Transform", transform_func),
        c("AICc", aicc_val),
        c("BIC", bic_val)
      )

      tags$table(
        class = "table table-condensed",
        style = "width: 100%; font-size: 13px;",
        tags$tbody(
          lapply(stats_items, function(item) {
            tags$tr(
              tags$td(
                style = "padding: 4px 8px; font-weight: 500; background: #f8f9fa;",
                item[1]
              ),
              tags$td(
                style = "padding: 4px 8px; font-family: monospace;",
                item[2]
              )
            )
          })
        )
      )
    },
    error = function(e) {
      div(
        style = "text-align: center; color: #6c757d; padding: 20px;",
        "Statistics not available"
      )
    }
  )
}

#' Generate HTML tests display (seasonalview-style)
#'
#' @param x A seas model object
#' @param digits Number of digits for formatting
#' @return HTML content for tests
html_tests <- function(x, digits = 4) {
  tryCatch(
    {
      s <- summary(x)
      test_results <- list()

      # QS Test for seasonality
      if (!is.null(s$qsv)) {
        qsv <- s$qsv
        qs_val <- as.numeric(qsv["qs"])
        qs_pval <- as.numeric(qsv["p-val"])

        qs_badge <- if (!is.na(qs_pval)) {
          if (qs_pval < 0.001) {
            tags$span(
              class = "badge",
              style = "background-color: #dc3545;",
              "0.1%"
            )
          } else if (qs_pval < 0.01) {
            tags$span(
              class = "badge",
              style = "background-color: #dc3545;",
              "1%"
            )
          } else if (qs_pval < 0.05) {
            tags$span(
              class = "badge",
              style = "background-color: #ffc107; color: #212529;",
              "5%"
            )
          } else if (qs_pval < 0.1) {
            tags$span(
              class = "badge",
              style = "background-color: #17a2b8;",
              "10%"
            )
          } else {
            ""
          }
        } else {
          ""
        }

        test_results <- c(
          test_results,
          list(list(
            name = "QS",
            hypothesis = "H0: no seasonality in final series",
            value = formatC(qs_val, digits = digits),
            badge = qs_badge
          ))
        )
      }

      # Box-Ljung Test - use residuals from summary or residuals() function
      resid <- if (!is.null(s$resid)) {
        s$resid
      } else {
        tryCatch(residuals(x), error = function(e) NULL)
      }

      if (!is.null(resid)) {
        bltest <- Box.test(resid, lag = 24, type = "Ljung")

        bl_badge <- if (!is.na(bltest$p.value)) {
          if (bltest$p.value < 0.001) {
            tags$span(
              class = "badge",
              style = "background-color: #dc3545;",
              "0.1%"
            )
          } else if (bltest$p.value < 0.01) {
            tags$span(
              class = "badge",
              style = "background-color: #dc3545;",
              "1%"
            )
          } else if (bltest$p.value < 0.05) {
            tags$span(
              class = "badge",
              style = "background-color: #ffc107; color: #212529;",
              "5%"
            )
          } else if (bltest$p.value < 0.1) {
            tags$span(
              class = "badge",
              style = "background-color: #17a2b8;",
              "10%"
            )
          } else {
            ""
          }
        } else {
          ""
        }

        test_results <- c(
          test_results,
          list(list(
            name = "Box-Ljung",
            hypothesis = "H0: no residual autocorrelation",
            value = formatC(bltest$statistic, digits = digits),
            badge = bl_badge
          ))
        )

        # Shapiro-Wilk Test
        swtest <- shapiro.test(resid)

        sw_badge <- if (!is.na(swtest$p.value)) {
          if (swtest$p.value < 0.001) {
            tags$span(
              class = "badge",
              style = "background-color: #dc3545;",
              "0.1%"
            )
          } else if (swtest$p.value < 0.01) {
            tags$span(
              class = "badge",
              style = "background-color: #dc3545;",
              "1%"
            )
          } else if (swtest$p.value < 0.05) {
            tags$span(
              class = "badge",
              style = "background-color: #ffc107; color: #212529;",
              "5%"
            )
          } else if (swtest$p.value < 0.1) {
            tags$span(
              class = "badge",
              style = "background-color: #17a2b8;",
              "10%"
            )
          } else {
            ""
          }
        } else {
          ""
        }

        test_results <- c(
          test_results,
          list(list(
            name = "Shapiro",
            hypothesis = "H0: normal distr. of residuals",
            value = formatC(swtest$statistic, digits = digits),
            badge = sw_badge
          ))
        )
      }

      if (length(test_results) > 0) {
        tags$table(
          class = "table table-condensed",
          style = "width: 100%; font-size: 13px;",
          tags$tbody(
            lapply(test_results, function(test) {
              tags$tr(
                tags$td(
                  style = "padding: 4px 8px;",
                  tags$div(
                    tags$strong(test$name),
                    tags$br(),
                    tags$small(
                      style = "color: #6c757d;",
                      test$hypothesis
                    )
                  )
                ),
                tags$td(
                  style = "padding: 4px 8px; text-align: right; font-family: monospace;",
                  test$value
                ),
                tags$td(
                  style = "padding: 4px 8px; text-align: right;",
                  test$badge
                )
              )
            })
          )
        )
      } else {
        div(
          style = "text-align: center; color: #6c757d; padding: 20px;",
          "No tests available"
        )
      }
    },
    error = function(e) {
      div(
        style = "text-align: center; color: #6c757d; padding: 20px;",
        "Tests not available"
      )
    }
  )
}

#' Generate HTML summary for seas model (main function)
#'
#' Pure function to generate HTML display from a seas model
#' @param seas_model A seas model object
#' @return A tagList with HTML content
html_summary <- function(seas_model) {
  if (is.null(seas_model) || !inherits(seas_model, "seas")) {
    return(div(
      style = "padding: 20px; text-align: center; color: #6c757d;",
      "No seasonal adjustment model available"
    ))
  }

  # Build HTML with 3-column layout
  tagList(
    # CSS styling
    tags$style(HTML(
      "
      .seas-summary-container {
        padding: 15px;
        background: white;
      }
      .seas-summary-header {
        font-size: 18px;
        font-weight: 600;
        color: #212529;
        margin-bottom: 20px;
        padding-bottom: 10px;
        border-bottom: 2px solid #e9ecef;
      }
      .seas-column-header {
        font-size: 14px;
        font-weight: 600;
        color: #495057;
        margin-bottom: 15px;
        padding-bottom: 5px;
        border-bottom: 1px solid #e9ecef;
      }
      .table-condensed {
        border-collapse: collapse;
      }
      .table-condensed td {
        border-bottom: 1px solid #e9ecef;
      }
      .table-condensed tr:last-child td {
        border-bottom: none;
      }
      .badge {
        display: inline-block;
        padding: 2px 6px;
        font-size: 10px;
        font-weight: 700;
        line-height: 1;
        color: #fff;
        text-align: center;
        white-space: nowrap;
        vertical-align: baseline;
        border-radius: 3px;
      }
    "
    )),

    div(
      class = "seas-summary-container",

      # Main header
      div(class = "seas-summary-header", "Summary"),

      # Three column layout using Bootstrap grid
      tags$div(
        class = "row",

        # Left column - Coefficients
        tags$div(
          class = "col-md-4",
          div(class = "seas-column-header", "Coefficients"),
          html_coefs(seas_model)
        ),

        # Middle column - Statistics
        tags$div(
          class = "col-md-4",
          div(class = "seas-column-header", "Statistics"),
          html_stats(seas_model)
        ),

        # Right column - Tests
        tags$div(
          class = "col-md-4",
          div(class = "seas-column-header", "Tests"),
          html_tests(seas_model)
        )
      )
    )
  )
}

# Helper function for null coalescing
`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

#' @export
block_ui.summary_block <- function(id, x, ...) {
  tagList(
    # Add X-13 Output button
    div(
      style = "margin-bottom: 10px;",
      actionButton(
        NS(id, "x13_output"),
        label = tagList(
          icon("file-text"),
          "X-13 Output"
        ),
        class = "btn-default"
      )
    ),
    uiOutput(NS(id, "result"))
  )
}

#' @export
block_output.summary_block <- function(x, result, session) {
  # result is the data frame from summary with seas model as attribute
  renderUI({
    # Extract the seas model from the result's attribute
    seas_model <- attr(result, "seas_model")
    html_summary(seas_model)
  })
}
