#' UDG (Unobserved Components Decomposition) Block
#'
#' Extracts detailed statistics from a seas model using udg() function.
#' The udg() function returns all available X-13ARIMA-SEATS statistics
#' as a data frame, allowing users to select specific statistics for display.
#'
#' @param selected_stats Character vector of initially selected statistics.
#'   Default is c("nobs", "aic", "bic", "loglikelihood") to show key model statistics.
#' @param ... Additional arguments passed to new_transform_block
#'
#' @export
new_udg_block <- function(selected_stats = c("nobs", "aic", "bic", "loglikelihood"), ...) {
  blockr.core::new_transform_block(
    server = function(id, data) {
      moduleServer(
        id,
        function(input, output, session) {
          # Initialize reactive values with r_ prefix
          r_selected_stats <- reactiveVal(selected_stats)
          
          # Get available statistics from the udg output
          available_stats <- reactive({
            tryCatch({
              # Get all available statistics
              udg_result <- seasonal::udg(data())
              # Extract scalar statistics only (numeric and character with length 1)
              scalar_stats <- udg_result[sapply(udg_result, function(x) 
                (is.numeric(x) || is.character(x)) && length(x) == 1)]
              names(scalar_stats)
            }, error = function(e) {
              character(0)
            })
          })
          
          # Update selectize choices when data changes
          observe({
            stats <- available_stats()
            if (length(stats) > 0) {
              # Create descriptive labels for common statistics
              stat_labels <- sapply(stats, function(stat) {
                descriptions <- list(
                  # Model information
                  "version" = "version - X-13ARIMA-SEATS version",
                  "build" = "build - Build number",
                  "freq" = "freq - Data frequency",
                  "nobs" = "nobs - Number of observations",
                  "transform" = "transform - Transformation function",
                  "arimamdl" = "arimamdl - ARIMA model specification",
                  "loglikelihood" = "loglikelihood - Log likelihood",
                  "aic" = "aic - Akaike Information Criterion",
                  "aicc" = "aicc - Corrected AIC",
                  "bic" = "bic - Bayesian Information Criterion",
                  
                  # Seasonal adjustment
                  "samode" = "samode - Seasonal adjustment mode",
                  "finmode" = "finmode - Final seasonal factors mode",
                  "seasonalma" = "seasonalma - Seasonal moving average",
                  "trendma" = "trendma - Trend moving average",
                  
                  # Quality statistics
                  "qslog" = "qslog - Q statistic on log scale",
                  "qsori" = "qsori - Q statistic original",
                  "qssadj" = "qssadj - Q statistic seasonally adjusted",
                  "qsirr" = "qsirr - Q statistic irregular",
                  
                  # Diagnostics
                  "skewness" = "skewness - Skewness of residuals",
                  "kurtosis" = "kurtosis - Kurtosis of residuals",
                  "durbinwatson" = "durbinwatson - Durbin-Watson statistic",
                  "friedman" = "friedman - Friedman test statistic",
                  
                  # Model details
                  "nmodel" = "nmodel - Number of model parameters",
                  "nreg" = "nreg - Number of regressors",
                  "variance$mle" = "variance$mle - MLE variance estimate",
                  "converged" = "converged - Model convergence status",
                  "niter" = "niter - Number of iterations",
                  
                  # Forecasting
                  "nfcst" = "nfcst - Number of forecasts",
                  "ciprob" = "ciprob - Confidence interval probability"
                )
                
                if (stat %in% names(descriptions)) {
                  descriptions[[stat]]
                } else {
                  paste0(stat, " - X-13 diagnostic statistic")
                }
              })
              
              updateSelectizeInput(
                session,
                "selected_stats",
                choices = setNames(stats, stat_labels),
                selected = intersect(isolate(r_selected_stats()), stats),
                server = FALSE
              )
            }
          })
          
          # Input observers
          observeEvent(input$selected_stats, {
            r_selected_stats(input$selected_stats)
          })
          
          # Show selected statistics info
          output$stats_info <- renderUI({
            selected <- r_selected_stats()
            if (length(selected) > 0) {
              div(
                class = "udg-stats-info",
                h5(paste("Selected Statistics:", length(selected), "of", length(available_stats())), 
                   class = "udg-stats-title"),
                if (length(selected) <= 10) {
                  tags$ul(
                    class = "udg-stats-list",
                    lapply(selected, function(stat) {
                      tags$li(tags$code(stat))
                    })
                  )
                } else {
                  p(paste("Showing", length(selected), "statistics in table below"))
                }
              )
            }
          })
          
          list(
            expr = reactive({
              selected <- r_selected_stats()
              
              if (length(selected) == 0) {
                # Return empty data frame if no statistics selected
                expr_text <- "data.frame(statistic = character(0), value = character(0))"
              } else {
                # Build expression to get udg data and convert to data frame
                selected_stats_str <- paste0("'", selected, "'", collapse = ", ")
                expr_text <- glue::glue(
                  "{{
                    # Get all statistics from udg
                    udg_result <- seasonal::udg(data)
                    
                    # Extract scalar statistics only
                    scalar_stats <- udg_result[sapply(udg_result, function(x) 
                      (is.numeric(x) || is.character(x)) && length(x) == 1)]
                    
                    # Filter to selected statistics
                    selected_names <- c({selected_stats_str})
                    available_names <- intersect(selected_names, names(scalar_stats))
                    
                    if (length(available_names) > 0) {{
                      filtered_stats <- scalar_stats[available_names]
                      data.frame(
                        statistic = names(filtered_stats),
                        value = sapply(filtered_stats, as.character),
                        row.names = NULL,
                        stringsAsFactors = FALSE
                      )
                    }} else {{
                      data.frame(
                        statistic = 'No statistics selected',
                        value = 'Please select valid UDG statistics',
                        stringsAsFactors = FALSE
                      )
                    }}
                  }}"
                )
              }
              
              parse(text = expr_text)[[1]]
            }),
            state = list(
              selected_stats = r_selected_stats
            )
          )
        }
      )
    },
    ui = function(id) {
      tagList(
        div(
          class = "udg-block-container",
          
          # CSS styling
          tags$style(HTML(
            "
            .udg-block-container {
              padding: 15px;
              background: #f8f9fa;
              border-radius: 8px;
            }
            .udg-section {
              margin-bottom: 20px;
            }
            .udg-section h4 {
              margin-top: 0;
              margin-bottom: 10px;
              color: #495057;
              font-size: 16px;
            }
            .udg-stats-info {
              background: white;
              border: 1px solid #dee2e6;
              border-radius: 4px;
              padding: 15px;
              margin-top: 15px;
            }
            .udg-stats-title {
              color: #495057;
              font-size: 14px;
              margin-bottom: 10px;
            }
            .udg-stats-list {
              margin-bottom: 0;
              padding-left: 20px;
            }
            .udg-stats-list li {
              margin-bottom: 5px;
              font-size: 13px;
            }
            .udg-stats-list code {
              background: #e9ecef;
              padding: 2px 4px;
              border-radius: 2px;
              font-size: 12px;
            }
            .selectize-control {
              margin-bottom: 0;
            }
            .selectize-dropdown .optgroup-header {
              font-weight: bold;
              background-color: #e9ecef;
              padding: 5px 10px;
              color: #495057;
            }
            .selectize-dropdown .option {
              padding: 5px 10px;
              font-size: 13px;
            }
            "
          )),
          
          # Statistics selection section
          div(
            class = "udg-section",
            h4("UDG Statistics Selection"),
            selectizeInput(
              NS(id, "selected_stats"),
              label = "Select Statistics to Display",
              choices = NULL,  # Set in server
              selected = selected_stats,
              multiple = TRUE,
              width = "100%",
              options = list(
                placeholder = "Choose statistics to display...",
                searchField = c("label", "value"),
                maxOptions = 200,
                plugins = list("remove_button"),
                render = I('{
                  option: function(item, escape) {
                    var label = item.label || item.value;
                    var parts = label.split(" - ");
                    if (parts.length > 1) {
                      return "<div>" +
                             "<strong>" + escape(parts[0]) + "</strong><br>" +
                             "<small style=\\"color: #6c757d;\\">" + escape(parts.slice(1).join(" - ")) + "</small>" +
                             "</div>";
                    }
                    return "<div>" + escape(label) + "</div>";
                  },
                  item: function(item, escape) {
                    return "<div>" + escape(item.value) + "</div>";
                  }
                }')
              )
            ),
            helpText(
              "Select multiple X-13ARIMA-SEATS diagnostic statistics to display as a data frame. ",
              "Statistics include model fit measures (aic, bic, loglikelihood), ",
              "diagnostics (skewness, kurtosis), quality measures (Q statistics), ",
              "and model information (nobs, transform, arimamdl). ",
              "Use the search box to find specific statistics by name or description."
            )
          ),
          
          # Selected statistics info
          uiOutput(NS(id, "stats_info"))
        )
      )
    },
    class = "udg_block",
    allow_empty_state = character(0),
    ...
  )
}