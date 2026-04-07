#' Seasonal Adjustment Block (JS-driven argument builder)
#'
#' Performs seasonal adjustment using X-13ARIMA-SEATS via the seasonal package.
#' Each argument is entered as a separate row with autocomplete and adaptive
#' value inputs driven by the X-13 argument catalog.
#'
#' The block accepts three inputs:
#' - x: The main time series (required)
#' - xreg: External regressors (optional)
#' - xtrans: Transformation variables (optional)
#'
#' @param state List with `args` (array of objects with `name` and `value`).
#'   Each argument becomes a parameter in the `seasonal::seas()` call.
#' @param ... Additional arguments forwarded to [blockr.core::new_transform_block()]
#'
#' @examples
#' if (interactive()) {
#'   library(blockr.core)
#'   serve(
#'     new_seas_block(
#'       state = list(args = list(
#'         list(name = "x11.mode", value = "mult")
#'       ))
#'     ),
#'     data = list(x = tsbox::ts_tbl(datasets::AirPassengers))
#'   )
#' }
#'
#' @importFrom shiny moduleServer reactive reactiveVal observeEvent NS div
#'   tagList
#' @importFrom htmltools htmlDependency
#'
#' @export
new_seas_block <- function(
  state = list(args = list()),
  ...
) {
  blockr.core::new_transform_block(
    # -- server ---------------------------------------------------------------
    server = function(id, x, xreg = reactive(NULL), xtrans = reactive(NULL)) {
      moduleServer(id, function(input, output, session) {
        ns <- session$ns
        r_state <- reactiveVal(state)

        # Bidirectional sync
        self_write <- new.env(parent = emptyenv())
        self_write$active <- FALSE

        # Send catalog to JS on init
        observe({
          catalog <- get_x13_catalog()
          session$sendCustomMessage("seas-catalog",
            list(id = ns("seas_input"), catalog = catalog))
        }, priority = 100)

        # Send connection status when xreg/xtrans change
        observe({
          session$sendCustomMessage("seas-connections",
            list(
              id = ns("seas_input"),
              xreg = !is.null(xreg()),
              xtrans = !is.null(xtrans())
            ))
        })

        # JS -> R: user changed arguments
        observeEvent(input$seas_input, {
          self_write$active <- TRUE
          r_state(input$seas_input)
          self_write$active <- FALSE
        })

        # R -> JS: external control changed state
        observeEvent(r_state(), {
          if (!self_write$active) {
            session$sendCustomMessage("seas-block-update",
              list(id = ns("seas_input"), state = r_state()))
          }
        })

        list(
          expr = reactive({
            s <- r_state()
            make_seas_expr(
              s$args %||% list(),
              has_xreg = !is.null(xreg()),
              has_xtrans = !is.null(xtrans())
            )
          }),
          state = list(state = r_state)
        )
      })
    },
    # -- ui -------------------------------------------------------------------
    ui = function(id) {
      tagList(
        blockr_core_js_dep(),
        blockr_blocks_css_dep(),
        blockr_select_dep(),
        blockr_select_rich_dep(),
        seas_block_dep(),
        div(
          class = "block-container",
          div(
            id = NS(id, "seas_input"),
            class = "seas-block-container"
          )
        )
      )
    },
    class = "seas_block",
    expr_type = "bquoted",
    external_ctrl = TRUE,
    allow_empty_state = "state",
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
    if (inherits(result, "seas")) {
      summary(result)
    } else {
      cat("No seasonal adjustment model available")
    }
  })
}
