#' Series Explorer Block
#'
#' A searchable dropdown series picker with an echarts4r chart preview.
#' Extracts the chosen component from a \code{seas} model and returns it
#' as a \code{tsbox}-compatible data frame for downstream blocks.
#'
#' The dropdown automatically filters to show only series compatible with
#' the current model method (SEATS or X-11).  An \emph{Advanced} toggle
#' reveals diagnostic series that are hidden by default.
#'
#' @param series Initial series code to display (default: \code{"final"})
#' @param advanced Whether to show advanced series by default
#' @param ... Forwarded to \code{\link[blockr.core]{new_transform_block}}
#'
#' @return A transform block of class \code{series_explorer_block}
#'
#' @export
new_series_explorer_block <- function(series = "final",
                                      advanced = FALSE,
                                      ...) {

  blockr.core::new_transform_block(
    server = function(id, data) {
      shiny::moduleServer(
        id,
        function(input, output, session) {
          all_panels_static <- series_explorer_panels()

          r_series <- shiny::reactiveVal(series)
          r_advanced <- shiny::reactiveVal(advanced)

          r_method <- shiny::reactive({
            model <- data()
            shiny::req(inherits(model, "seas"))
            sx_model_method(model)
          })

          r_panels <- shiny::reactive({
            method <- r_method()
            Filter(function(p) {
              p$method == "any" || p$method == method
            }, all_panels_static)
          })

          # Build grouped choices for selectize
          r_choices <- shiny::reactive({
            panels <- r_panels()
            show_advanced <- r_advanced()
            basic_specs <- sx_basic_specs()

            if (!show_advanced) {
              panels <- Filter(function(p) p$category %in% basic_specs, panels)
            }

            specs <- unique(vapply(panels, `[[`, character(1L), "category"))
            choices <- list()
            for (spec in specs) {
              spec_panels <- Filter(function(p) p$category == spec, panels)
              choices[[spec]] <- stats::setNames(
                vapply(spec_panels, `[[`, character(1L), "id"),
                vapply(spec_panels, function(p) {
                  paste0(p$id, " \u2014 ", p$description)
                }, character(1L))
              )
            }
            choices
          })

          shiny::observe({
            choices <- r_choices()
            shiny::updateSelectizeInput(
              session, "series",
              choices = choices,
              selected = shiny::isolate(r_series()),
              server = FALSE
            )
          })

          shiny::observeEvent(input$series, {
            r_series(input$series)
          })

          shiny::observeEvent(input$advanced, {
            r_advanced(isTRUE(input$advanced))
          })

          # Render chart
          output$chart <- shiny::renderUI({
            model <- data()
            shiny::req(inherits(model, "seas"))
            sel <- r_series()
            panels <- r_panels()
            shiny::req(sel)

            if (!sel %in% names(panels)) {
              return(sx_empty_chart(
                paste0("Series \"", sel,
                       "\" not available for this model")
              ))
            }

            panel <- panels[[sel]]
            tryCatch(
              panel$render(model),
              error = function(e) sx_empty_chart(
                paste("Error:", conditionMessage(e))
              )
            )
          })

          list(
            expr = shiny::reactive({
              selected_series <- r_series()
              expr_text <- glue::glue(
                "tsbox::ts_tbl(blockr.seasonal:::sx_extract_series(data, '{selected_series}'))"
              )
              parse(text = expr_text)[[1]]
            }),
            state = list(
              series = r_series,
              advanced = r_advanced
            )
          )
        }
      )
    },
    ui = function(id) {
      ns <- shiny::NS(id)

      # Build the color map as JSON for the JS render function
      colors_json <- jsonlite::toJSON(sx_spec_colors(), auto_unbox = TRUE)

      # SVG path for graph-up icon
      icon_path <- paste0(
        '<path fill-rule="evenodd" d="M0 0h1v15h15v1H0zm14.817 3.113a.5',
        '.5 0 0 1 .07.704l-4.5 5.5a.5.5 0 0 1-.74.037L7.06 6.767l-3.656',
        ' 5.027a.5.5 0 0 1-.808-.588l4-5.5a.5.5 0 0 1 .758-.06l2.609 ',
        '2.61 4.15-5.073a.5.5 0 0 1 .704-.07"/>'
      )

      shiny::tagList(
        sx_explorer_css(),
        shiny::div(
          class = "sx-block",

          # Top row: selectize + advanced toggle
          shiny::div(class = "sx-top-row",
            shiny::div(class = "sx-select-wrap",
              shiny::selectizeInput(
                ns("series"),
                label = NULL,
                choices = NULL,
                width = "100%",
                options = list(
                  placeholder = "Search series...",
                  searchField = c("label", "value"),
                  maxOptions = 500,
                  render = I(sprintf("
                    (function() {
                      var specColors = %s;
                      var iconPath = '%s';

                      var hexToRgba = function(hex, alpha) {
                        var r = parseInt(hex.slice(1,3), 16);
                        var g = parseInt(hex.slice(3,5), 16);
                        var b = parseInt(hex.slice(5,7), 16);
                        return 'rgba(' + r + ',' + g + ',' + b + ',' + alpha + ')';
                      };

                      var makeSvg = function(color, size) {
                        return '<svg xmlns=\"http://www.w3.org/2000/svg\" ' +
                          'width=\"' + size + '\" height=\"' + size + '\" ' +
                          'fill=\"' + color + '\" viewBox=\"0 0 16 16\">' +
                          iconPath + '</svg>';
                      };

                      return {
                        option: function(item, escape) {
                          var label = item.label || item.value;
                          var parts = label.split(' \\u2014 ');
                          var code = parts[0] || item.value;
                          var desc = parts.length > 1 ? parts.slice(1).join(' ') : '';
                          var optgroup = item.optgroup || '';
                          var color = specColors[optgroup] || '#64748b';
                          var bgColor = hexToRgba(color, 0.15);

                          return '<div class=\"sx-option\">' +
                            '<div class=\"sx-option-icon\" style=\"background:' + bgColor + '\">' +
                              makeSvg(color, 18) +
                            '</div>' +
                            '<div class=\"sx-option-content\">' +
                              '<div class=\"sx-option-header\">' +
                                '<span class=\"sx-option-name\">' + escape(code) + '</span>' +
                                '<span class=\"sx-option-cat\">' + escape(optgroup) + '</span>' +
                              '</div>' +
                              (desc ? '<div class=\"sx-option-desc\">' + escape(desc) + '</div>' : '') +
                            '</div>' +
                          '</div>';
                        },
                        item: function(item, escape) {
                          var label = item.label || item.value;
                          var parts = label.split(' \\u2014 ');
                          var code = parts[0] || item.value;
                          var desc = parts.length > 1 ? parts.slice(1).join(' ') : '';
                          var optgroup = item.optgroup || '';
                          var color = specColors[optgroup] || '#64748b';
                          var bgColor = hexToRgba(color, 0.15);

                          return '<div class=\"sx-item-selected\">' +
                            '<div class=\"sx-item-icon\" style=\"background:' + bgColor + '\">' +
                              makeSvg(color, 12) +
                            '</div>' +
                            '<span class=\"sx-item-name\">' + escape(code) + '</span>' +
                            '<span class=\"sx-item-desc\">' + escape(desc) + '</span>' +
                          '</div>';
                        }
                      };
                    })()", colors_json, icon_path))
                )
              )
            ),
            shiny::div(class = "sx-adv-wrap",
              shiny::tags$label(class = "sx-adv-label",
                shiny::tags$input(
                  type = "checkbox",
                  id = ns("advanced"),
                  class = "sx-adv-check"
                ),
                shiny::tags$span(class = "sx-adv-text", "Advanced")
              )
            )
          ),

          # Chart
          shiny::div(class = "sx-chart-wrap",
            shiny::uiOutput(ns("chart"))
          )
        )
      )
    },
    dat_valid = function(data) {
      if (!inherits(data, "seas")) {
        stop("Input must be a seas model object")
      }
    },
    class = "series_explorer_block",
    ...
  )
}

#' @rdname new_series_explorer_block
#' @param id Module ID
#' @param x Block object
#' @importFrom blockr.core block_ui
#' @method block_ui series_explorer_block
#' @export
block_ui.series_explorer_block <- function(id, x, ...) {
  shiny::tagList()
}

#' @rdname new_series_explorer_block
#' @param result Evaluation result
#' @param session Shiny session object
#' @importFrom blockr.core block_output
#' @method block_output series_explorer_block
#' @export
block_output.series_explorer_block <- function(x, result, session) {
  shiny::renderUI(NULL)
}
