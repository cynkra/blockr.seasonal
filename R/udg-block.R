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
new_udg_block <- function(
  selected_stats = c("nobs", "aic", "bic", "loglikelihood"),
  ...
) {
  # Load metadata for descriptions
  metadata_file <- system.file(
    "extdata",
    "udg_metadata.rds",
    package = "blockr.seasonal"
  )
  if (file.exists(metadata_file)) {
    udg_metadata <- readRDS(metadata_file)
  } else {
    # Fallback if metadata doesn't exist
    udg_metadata <- data.frame(
      statistic = character(),
      category = character(),
      description = character(),
      stringsAsFactors = FALSE
    )
  }

  blockr.core::new_transform_block(
    server = function(id, data) {
      moduleServer(
        id,
        function(input, output, session) {
          # Initialize reactive values with r_ prefix
          r_selected_stats <- reactiveVal(selected_stats)

          # Get available statistics from the udg output
          available_stats <- reactive({
            tryCatch(
              {
                # Get all available statistics
                udg_result <- seasonal::udg(data())
                # Extract scalar statistics only (numeric and character with length 1)
                scalar_stats <- udg_result[sapply(udg_result, function(x) {
                  (is.numeric(x) || is.character(x)) && length(x) == 1
                })]
                names(scalar_stats)
              },
              error = function(e) {
                character(0)
              }
            )
          })

          # Update selectize choices when data changes
          observe({
            stats <- available_stats()
            if (length(stats) > 0) {
              # Create descriptive labels using metadata
              stat_labels <- sapply(stats, function(stat) {
                # Check if we have metadata for this statistic
                meta_row <- udg_metadata[udg_metadata$statistic == stat, ]
                if (nrow(meta_row) > 0) {
                  return(paste0(stat, " - ", meta_row$description[1]))
                }
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

              # Group statistics by category
              stat_categories <- sapply(stats, function(stat) {
                meta_row <- udg_metadata[udg_metadata$statistic == stat, ]
                if (nrow(meta_row) > 0) {
                  return(meta_row$category[1])
                }
                return("Other")
              })

              # Create grouped choices
              choices_list <- list()
              unique_categories <- unique(stat_categories)
              category_order <- c(
                "Basic",
                "Model",
                "QS Test",
                "F-Test",
                "M-Stat",
                "Diagnostics",
                "Spectrum",
                "X-11",
                "Other"
              )
              ordered_categories <- intersect(category_order, unique_categories)

              for (cat in ordered_categories) {
                cat_stats <- stats[stat_categories == cat]
                cat_choices <- cat_stats
                names(cat_choices) <- stat_labels[stat_categories == cat]
                choices_list[[cat]] <- cat_choices
              }

              # Add any remaining categories
              remaining_cats <- setdiff(unique_categories, ordered_categories)
              for (cat in remaining_cats) {
                cat_stats <- stats[stat_categories == cat]
                cat_choices <- cat_stats
                names(cat_choices) <- stat_labels[stat_categories == cat]
                choices_list[[cat]] <- cat_choices
              }

              updateSelectizeInput(
                session,
                "selected_stats",
                choices = if (length(choices_list) > 1) {
                  choices_list
                } else {
                  setNames(stats, stat_labels)
                },
                selected = intersect(isolate(r_selected_stats()), stats),
                server = FALSE
              )
            }
          })

          # Input observers
          observeEvent(input$selected_stats, {
            r_selected_stats(input$selected_stats)
          })

          list(
            expr = reactive({
              selected <- r_selected_stats()

              if (length(selected) == 0) {
                # Return empty data frame if no statistics selected
                expr_text <- "data.frame(statistic = character(0), value = character(0), description = character(0))"
              } else {
                # Build expression to get udg data and convert to data frame
                selected_stats_str <- paste0(
                  "'",
                  selected,
                  "'",
                  collapse = ", "
                )

                # Build descriptions mapping for inclusion in the expression
                desc_lines <- character()
                for (stat in selected) {
                  meta_row <- udg_metadata[udg_metadata$statistic == stat, ]
                  desc <- if (nrow(meta_row) > 0) {
                    meta_row$description[1]
                  } else {
                    "X-13 diagnostic statistic"
                  }
                  # Escape single quotes in descriptions
                  desc <- gsub("'", "\\\\'", desc)
                  desc_lines <- c(
                    desc_lines,
                    paste0("                      '", stat, "' = '", desc, "'")
                  )
                }
                desc_mapping <- paste(desc_lines, collapse = ",\n")

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
                      
                      # Description mapping
                      desc_map <- c(
{desc_mapping}
                      )
                      
                      data.frame(
                        statistic = names(filtered_stats),
                        value = sapply(filtered_stats, as.character),
                        description = desc_map[names(filtered_stats)],
                        row.names = NULL,
                        stringsAsFactors = FALSE
                      )
                    }} else {{
                      data.frame(
                        statistic = 'No statistics selected',
                        value = 'Please select valid UDG statistics',
                        description = '',
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
              choices = NULL, # Set in server
              selected = selected_stats,
              multiple = TRUE,
              width = "100%",
              options = list(
                placeholder = "Choose statistics to display...",
                searchField = c("label", "value"),
                maxOptions = 200,
                plugins = list("remove_button"),
                render = I(
                  '{
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
                }'
                )
              )
            ),
            helpText(
              "Select multiple X-13ARIMA-SEATS diagnostic statistics to display as a data frame. ",
              "Statistics include model fit measures (aic, bic, loglikelihood), ",
              "diagnostics (skewness, kurtosis), quality measures (Q statistics), ",
              "and model information (nobs, transform, arimamdl). ",
              "Use the search box to find specific statistics by name or description."
            )
          )
        )
      )
    },
    class = "udg_block",
    allow_empty_state = character(0),
    ...
  )
}
