#' Series Explorer Block
#'
#' A searchable dropdown series picker using \code{Blockr.SelectRich} with an
#' echarts4r chart preview.  Extracts the chosen component from a \code{seas}
#' model and returns it as a \code{tsbox}-compatible data frame for downstream
#' blocks.
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
    server = function(id, ...args) {
      shiny::moduleServer(
        id,
        function(input, output, session) {
          all_panels_static <- series_explorer_panels()
          ns <- session$ns

          r_series <- shiny::reactiveVal(series)
          r_advanced <- shiny::reactiveVal(advanced)

          r_method <- shiny::reactive({
            model <- data()
            shiny::req(inherits(model, "seas"))
            sx_model_method(model)
          })

          # Helper: get data from first variadic input
          data <- shiny::reactive({
            d <- ...args[["1"]]
            shiny::req(d)
            d
          })

          r_panels <- shiny::reactive({
            method <- r_method()
            Filter(function(p) {
              p$method == "any" || p$method == method
            }, all_panels_static)
          })

          # Build items for SelectRich
          r_items <- shiny::reactive({
            panels <- r_panels()
            show_advanced <- r_advanced()
            basic_specs <- sx_basic_specs()

            if (!show_advanced) {
              panels <- Filter(function(p) p$category %in% basic_specs, panels)
            }

            lapply(unname(panels), function(p) {
              list(
                value = p$id,
                label = p$id,
                description = p$description,
                group = p$category,
                meta = p$category
              )
            })
          })

          # Send items to client whenever they change
          shiny::observe({
            items <- r_items()
            session$sendCustomMessage(
              ns("sx_set_items"),
              list(items = items, selected = shiny::isolate(r_series()))
            )
          })

          # Receive selection from client
          shiny::observeEvent(input$sx_series, {
            r_series(input$sx_series)
          })

          # Advanced toggle
          shiny::observeEvent(input$advanced, {
            r_advanced(isTRUE(input$advanced))
            # Re-send items with new filter
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
                paste0("Series \"", sel, "\" not available for this model")
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
              parse(text = glue::glue(
                "tsbox::ts_tbl(blockr.seasonal:::sx_extract_series(.(`1`), '{selected_series}'))"
              ))[[1]]
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

      # Group colors for the SelectRich
      colors_json <- jsonlite::toJSON(sx_spec_colors(), auto_unbox = TRUE)

      shiny::tagList(
        blockr_core_js_dep(),
        blockr_select_rich_dep(),
        sx_explorer_css(),
        shiny::div(
          class = "sx-block",

          # Top row: SelectRich container + advanced toggle
          shiny::div(class = "sx-top-row",
            shiny::div(class = "sx-select-wrap",
              shiny::div(id = ns("sx_select_container"))
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
        ),

        # JS: create SelectRich and wire to Shiny
        shiny::tags$script(shiny::HTML(sprintf("
          $(function() {
            var containerId = '%s';
            var setItemsMsgId = '%s';
            var inputId = '%s';
            var groupColors = %s;

            var srich = null;

            // Create SelectRich once the container exists
            var initInterval = setInterval(function() {
              var container = document.getElementById(containerId);
              if (!container || typeof Blockr === 'undefined' || !Blockr.SelectRich) return;
              clearInterval(initInterval);

              srich = Blockr.SelectRich.create(container, {
                items: [],
                selected: null,
                placeholder: 'Search series\\u2026',
                groupColors: groupColors,
                onChange: function(value) {
                  Shiny.setInputValue(inputId, value, {priority: 'event'});
                }
              });
            }, 100);

            // Receive items from server
            Shiny.addCustomMessageHandler(setItemsMsgId, function(msg) {
              if (!srich) return;
              srich.setItems(msg.items || []);
              if (msg.selected) srich.setValue(msg.selected);
            });
          });
        ", ns("sx_select_container"), ns("sx_set_items"), ns("sx_series"),
           colors_json)))
      )
    },
    dat_valid = function(...args) {
      stopifnot(length(...args) >= 1L)
      if (!inherits(...args[[1]], "seas")) {
        stop("Input must be a seas model object")
      }
    },
    expr_type = "bquoted",
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
