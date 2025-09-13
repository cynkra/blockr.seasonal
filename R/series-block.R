#' Series Extraction Block
#'
#' Extracts specific components or series from a seas model as time series.
#' Returns blockr.ts compatible time series objects that can be
#' used with other blockr.ts blocks and displays as dygraph.
#'
#' @param series Which series to extract. Can be standard components like
#'   "final", "seasonal", "trend", "irregular", "original" or any X-13
#'   series code (e.g., "d10", "d11", "d12", "d13", etc.)
#' @param ... Additional arguments passed to new_ts_transform_block
#'
#' @export
new_series_block <- function(series = "final", ...) {
  # Load series codes data
  series_codes_file <- system.file(
    "extdata",
    "series_codes.rds",
    package = "blockr.seasonal"
  )
  if (file.exists(series_codes_file)) {
    series_codes <- readRDS(series_codes_file)
  } else {
    # Fallback if RDS doesn't exist
    series_codes <- data.frame(
      spec = c("Core", "Core", "Core", "Core", "Core"),
      short_name = c("original", "final", "seasonal", "trend", "irregular"),
      description = c(
        "Original series",
        "Seasonally adjusted (final) series",
        "Seasonal component",
        "Trend-cycle component",
        "Irregular component"
      ),
      stringsAsFactors = FALSE
    )
  }

  blockr.ts::new_ts_transform_block(
    server = function(id, data) {
      moduleServer(
        id,
        function(input, output, session) {
          # Initialize reactive values with r_ prefix
          r_series <- reactiveVal(series)

          # Create choices for selectize
          # Group by spec and format as "code - description"
          create_choices <- function() {
            choices_list <- list()

            for (spec in unique(series_codes$spec)) {
              spec_data <- series_codes[series_codes$spec == spec, ]
              spec_choices <- setNames(
                spec_data$short_name,
                paste0(spec_data$short_name, " - ", spec_data$description)
              )
              choices_list[[spec]] <- spec_choices
            }

            choices_list
          }

          # Update selectize with choices
          observe({
            updateSelectizeInput(
              session,
              "series",
              choices = create_choices(),
              selected = isolate(r_series()),
              server = FALSE
            )
          })

          # Input observers
          observeEvent(input$series, {
            r_series(input$series)
          })

          # Display selected series description
          output$series_description <- renderUI({
            selected <- r_series()
            if (!is.null(selected) && selected %in% series_codes$short_name) {
              series_info <- series_codes[series_codes$short_name == selected, ]
              div(
                class = "series-description-box",
                h4(
                  class = "series-description-title",
                  series_info$short_name[1],
                  " - ",
                  series_info$description[1]
                ),
                p(
                  class = "series-description-spec",
                  "Category: ",
                  tags$strong(series_info$spec[1])
                )
              )
            }
          })

          list(
            expr = reactive({
              selected_series <- r_series()

              # Use seasonal::series() for flexible extraction
              # It handles both standard components and X-13 series codes
              expr_text <- glue::glue(
                "{{
                  # Extract series from seas model
                  extracted <- seasonal::series(data, '{selected_series}')
                  
                  # Convert to tsbox format for dygraph display
                  tsbox::ts_tbl(extracted)
                }}"
              )

              parse(text = expr_text)[[1]]
            }),
            state = list(
              series = r_series
            )
          )
        }
      )
    },
    ui = function(id) {
      tagList(
        div(
          class = "series-block-container",

          tags$style(HTML(
            "
            .series-block-container {
              padding: 10px;
              background: #f8f9fa;
              border-radius: 4px;
            }
            .series-block-title {
              margin-bottom: 10px;
              color: #495057;
              font-size: 14px;
              font-weight: bold;
            }
            /* Description box styling */
            .series-description-box {
              background: white;
              border: 2px solid #007bff;
              border-radius: 6px;
              padding: 15px;
              margin: 15px 0;
              box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            }
            .series-description-title {
              color: #007bff;
              font-size: 16px;
              font-weight: 600;
              margin: 0 0 8px 0;
            }
            .series-description-spec {
              color: #6c757d;
              font-size: 13px;
              margin: 0;
            }
            /* Custom styles for selectize dropdown */
            .selectize-dropdown-content {
              max-height: 400px;
              overflow-y: auto;
            }
            .selectize-dropdown .optgroup-header {
              font-weight: bold;
              background-color: #e9ecef;
              padding: 5px 10px;
              color: #495057;
            }
            .selectize-dropdown .option {
              padding: 5px 10px;
            }
            .selectize-dropdown .option .series-code {
              font-weight: bold;
              color: #007bff;
            }
            .selectize-dropdown .option .series-desc {
              color: #6c757d;
              font-size: 0.9em;
            }
            "
          )),

          div(
            class = "series-block-title",
            "Series Extraction"
          ),

          selectizeInput(
            NS(id, "series"),
            label = "Select Series",
            choices = NULL, # Set in server
            selected = series,
            width = "100%",
            options = list(
              placeholder = "Search by code or description...",
              searchField = c("label", "value"),
              maxOptions = 500,
              render = I(
                '{
                option: function(item, escape) {
                  var label = item.label || item.value;
                  var parts = label.split(" - ");
                  if (parts.length > 1) {
                    return "<div>" +
                           "<span class=\\"series-code\\">" + escape(parts[0]) + "</span> - " +
                           "<span class=\\"series-desc\\">" + escape(parts.slice(1).join(" - ")) + "</span>" +
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

          # Display selected series description
          uiOutput(NS(id, "series_description")),

          helpText(
            "Search and select from 260+ available X-13ARIMA-SEATS series. ",
            "Type to search by code (e.g., 'd11') or description (e.g., 'seasonal'). ",
            "Series are grouped by specification type."
          )
        )
      )
    },
    class = "series_block",
    ...
  )
}
