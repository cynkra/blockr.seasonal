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

#' Generate HTML coefficients display
#'
#' @param x A seas model object
#' @return HTML content for coefficients
html_coefs <- function(x) {
  tryCatch(
    {
      coefs <- coef(summary(x))
      if (is.null(coefs) || nrow(coefs) == 0) {
        return(div(class = "seas-empty", "No coefficients"))
      }

      p_vals <- coefs[, "Pr(>|z|)"]

      div(
        class = "seas-rows",
        lapply(seq_len(nrow(coefs)), function(i) {
          p <- p_vals[i]
          badge <- coef_badge(p)
          div(
            class = "seas-row",
            span(class = "seas-key", rownames(coefs)[i]),
            span(
              class = "seas-value",
              sprintf("%.2f", coefs[i, "Estimate"]),
              badge
            )
          )
        })
      )
    },
    error = function(e) {
      div(class = "seas-empty", "No coefficients available")
    }
  )
}

#' Badge for coefficient significance (blue = good)
#' @noRd
coef_badge <- function(p) {
  if (is.na(p)) return(NULL)
  if (p < 0.05) {
    tags$span(class = "seas-badge seas-badge-sig",
              if (p < 0.001) "***" else if (p < 0.01) "**" else "*")
  } else if (p < 0.1) {
    tags$span(class = "seas-badge seas-badge-marginal", "\u00B7")
  } else {
    NULL
  }
}

#' Generate HTML statistics display
#'
#' @param x A seas model object
#' @param digits Number of digits for formatting
#' @return HTML content for statistics
html_stats <- function(x, digits = 5) {
  tryCatch(
    {
      s <- summary(x)

      adj_method <- if (!is.null(x$spc$seats)) {
        "SEATS"
      } else if (!is.null(x$spc$x11)) {
        "X-11"
      } else {
        "Unknown"
      }

      arima_model <- tryCatch(
        {
          if (!is.null(s$model$arima$model)) {
            as.character(s$model$arima$model)
          } else {
            "Auto"
          }
        },
        error = function(e) "Auto"
      )

      transform_func <- tryCatch(s$transform.function %||% "none",
                                 error = function(e) "none")
      n_obs <- tryCatch(length(x$x), error = function(e) NA)
      aicc_val <- tryCatch(formatC(AIC(x), digits = digits),
                           error = function(e) "NA")
      bic_val <- tryCatch(formatC(BIC(x), digits = digits),
                          error = function(e) "NA")

      stats_items <- list(
        c("Adjustment", adj_method),
        c("ARIMA", arima_model),
        c("Obs.", n_obs),
        c("Transform", transform_func),
        c("AICc", aicc_val),
        c("BIC", bic_val)
      )

      div(
        class = "seas-rows",
        lapply(stats_items, function(item) {
          div(
            class = "seas-row",
            span(class = "seas-key", item[1]),
            span(class = "seas-value", item[2])
          )
        })
      )
    },
    error = function(e) {
      div(class = "seas-empty", "Statistics not available")
    }
  )
}

#' Generate HTML tests display
#'
#' @param x A seas model object
#' @param digits Number of digits for formatting
#' @return HTML content for tests
html_tests <- function(x, digits = 4) {
  tryCatch(
    {
      s <- summary(x)
      test_results <- list()

      # QS Test for seasonality — rejection is GOOD (confirms seasonality)
      if (!is.null(s$qsv)) {
        qsv <- s$qsv
        qs_val <- as.numeric(qsv["qs"])
        qs_pval <- as.numeric(qsv["p-val"])
        test_results <- c(test_results, list(list(
          name = "QS",
          hypothesis = "H0: no seasonality in final series",
          value = formatC(qs_val, digits = digits),
          badge = test_badge(qs_pval, reject_is_bad = TRUE)
        )))
      }

      # Box-Ljung & Shapiro — rejection is BAD (residual problems)
      resid <- if (!is.null(s$resid)) {
        s$resid
      } else {
        tryCatch(residuals(x), error = function(e) NULL)
      }

      if (!is.null(resid)) {
        bltest <- Box.test(resid, lag = 24, type = "Ljung")
        test_results <- c(test_results, list(list(
          name = "Box-Ljung",
          hypothesis = "H0: no residual autocorrelation",
          value = formatC(bltest$statistic, digits = digits),
          badge = test_badge(bltest$p.value, reject_is_bad = TRUE)
        )))

        swtest <- shapiro.test(resid)
        test_results <- c(test_results, list(list(
          name = "Shapiro",
          hypothesis = "H0: normal distr. of residuals",
          value = formatC(swtest$statistic, digits = digits),
          badge = test_badge(swtest$p.value, reject_is_bad = TRUE)
        )))
      }

      if (length(test_results) > 0) {
        div(
          class = "seas-rows",
          lapply(test_results, function(test) {
            div(
              class = "seas-row",
              span(class = "seas-key", title = test$hypothesis, test$name),
              span(class = "seas-value", test$value, test$badge)
            )
          })
        )
      } else {
        div(class = "seas-empty", "No tests available")
      }
    },
    error = function(e) {
      div(class = "seas-empty", "Tests not available")
    }
  )
}

#' Badge for test p-values
#'
#' For tests where rejection signals a problem (Box-Ljung, Shapiro),
#' significant = red warning. For all tests, marginal = amber.
#' @noRd
test_badge <- function(p, reject_is_bad = TRUE) {
  if (is.null(p) || is.na(p)) return(NULL)
  if (p < 0.05) {
    cls <- if (reject_is_bad) "seas-badge seas-badge-warn"
           else "seas-badge seas-badge-sig"
    label <- if (p < 0.001) "***" else if (p < 0.01) "**" else "*"
    tags$span(class = cls, label)
  } else if (p < 0.1) {
    cls <- if (reject_is_bad) "seas-badge seas-badge-warn-marginal"
           else "seas-badge seas-badge-marginal"
    tags$span(class = cls, "\u00B7")
  } else {
    NULL
  }
}

#' Generate HTML summary for seas model (main function)
#'
#' Pure function to generate HTML display from a seas model
#' @param seas_model A seas model object
#' @param session Optional session object for adding button functionality
#' @return A tagList with HTML content
html_summary <- function(seas_model, session = NULL) {
  if (is.null(seas_model) || !inherits(seas_model, "seas")) {
    return(div(class = "seas-empty", "No seasonal adjustment model available"))
  }

  # Extract model identity for subtitle
  s <- tryCatch(summary(seas_model), error = function(e) NULL)
  arima_spec <- tryCatch(
    {
      if (!is.null(s$model$arima$model)) {
        as.character(s$model$arima$model)
      } else {
        "Auto"
      }
    },
    error = function(e) "Auto"
  )
  adj_method <- if (!is.null(seas_model$spc$seats)) {
    "SEATS"
  } else if (!is.null(seas_model$spc$x11)) {
    "X-11"
  } else {
    NULL
  }

  tagList(
    seas_summary_css_dep(),

    div(
      class = "seas-summary",

      # Model identity bar
      div(
        class = "seas-summary-model",
        span(class = "seas-summary-model-spec", paste("ARIMA", arima_spec)),
        if (!is.null(adj_method)) {
          span(class = "seas-summary-model-tag", adj_method)
        },
        if (!is.null(session)) {
          actionLink(
            session$ns("x13_output"),
            label = tagList(icon("terminal"), "X-13"),
            class = "seas-x13-btn"
          )
        }
      ),

      # Three column layout
      tags$div(
        class = "row",
        tags$div(
          class = "col-md-4",
          div(class = "seas-col-header", "Coefficients"),
          html_coefs(seas_model)
        ),
        tags$div(
          class = "col-md-4",
          div(class = "seas-col-header", "Statistics"),
          html_stats(seas_model)
        ),
        tags$div(
          class = "col-md-4",
          div(class = "seas-col-header", "Tests"),
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
  uiOutput(NS(id, "result"))
}

#' @export
block_output.summary_block <- function(x, result, session) {
  # Store the seas model in the parent environment for button access
  seas_model <- attr(result, "seas_model")

  # Create observer for button click
  observeEvent(session$input$x13_output, {
    if (!is.null(seas_model) && inherits(seas_model, "seas")) {
      seasonal::out(seas_model)
    }
  })

  # Return the UI with session for the X-13 link
  renderUI({
    html_summary(seas_model, session)
  })
}
