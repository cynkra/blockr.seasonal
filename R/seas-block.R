#' Seasonal Adjustment Block (JS-driven argument builder)
#'
#' Performs seasonal adjustment using X-13ARIMA-SEATS via the seasonal package.
#' Each argument is entered as a separate row with autocomplete and adaptive
#' value inputs driven by the X-13 argument catalog.
#'
#' The block is variadic: the first connected input is the main time series,
#' the second (optional) is external regressors (xreg), and the third
#' (optional) is transformation variables (xtrans).
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
    # -- server (variadic: 1=x, 2=xreg, 3=xtrans) ---------------------------
    server = function(id, ...args) {
      moduleServer(id, function(input, output, session) {

        # Variadic slots, in order: 1 = x, 2 = xreg, 3 = xtrans.
        n_inputs <- reactive(length(...args))
        has_xreg <- reactive(n_inputs() >= 2L)
        has_xtrans <- reactive(n_inputs() >= 3L)

        r_state <- seas_args_server(input, session, state, has_xreg, has_xtrans)

        # Map the slots onto seas()'s semantic arguments, by the symbol each
        # input is bound to rather than by its position name.
        arg_names <- reactive({
          refs <- dot_refs(...args)
          if (!length(refs)) {
            return(stats::setNames(character(), character()))
          }
          mapped <- character(length(refs))
          mapped[1] <- "x"
          if (length(refs) >= 2) mapped[2] <- "xreg"
          if (length(refs) >= 3) mapped[3] <- "xtrans"
          stats::setNames(refs, mapped)
        })

        list(
          expr = reactive({
            s <- r_state()
            make_seas_expr(
              s$args %||% list(),
              has_xreg = has_xreg(),
              has_xtrans = has_xtrans(),
              arg_names = arg_names()
            )
          }),
          state = list(state = r_state)
        )
      })
    },
    # -- ui -------------------------------------------------------------------
    ui = seas_args_ui,
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
