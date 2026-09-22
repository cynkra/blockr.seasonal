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
#' @param args The argument rows, a list of `list(name =, value =)`. Each row
#'   becomes one argument of the `seasonal::seas()` call, so
#'   `list(list(name = "x11.mode", value = "mult"))` fits
#'   `seas(x, x11.mode = "mult")`. The block's own state, flat, one formal:
#'   there is no wrapper list around it.
#' @param ... Additional arguments forwarded to [blockr.core::new_transform_block()]
#'
#' @examples
#' if (interactive()) {
#'   library(blockr.core)
#'   serve(
#'     new_seas_block(
#'       args = list(list(name = "x11.mode", value = "mult"))
#'     ),
#'     data = list(x = tsbox::ts_tbl(datasets::AirPassengers))
#'   )
#' }
#'
#' @importFrom shiny moduleServer reactive reactiveVal observeEvent NS div
#'   renderText
#'   tagList
#' @importFrom htmltools htmlDependency
#'
#' @export
new_seas_block <- function(
  args = list(),
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

        r_args <- seas_args_server(input, session, args, has_xreg, has_xtrans)

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

        r_expr <- reactive({
          make_seas_expr(
            r_args(),
            has_xreg = has_xreg(),
            has_xtrans = has_xtrans(),
            arg_names = arg_names()
          )
        })

        # The strip under the arguments. One reactive feeds both it and the
        # block's expression, so what is on screen is what core evaluates.
        output$seas_expr <- renderText(seas_expr_text(r_expr()))

        list(
          expr = r_expr,
          state = list(args = r_args)
        )
      })
    },
    # -- ui -------------------------------------------------------------------
    ui = seas_args_ui,
    class = "seas_block",
    expr_type = "bquoted",
    external_ctrl = TRUE,
    allow_empty_state = "args",
    ...
  )
}
