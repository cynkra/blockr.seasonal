#' The X-13 argument builder, shared by the seas blocks
#'
#' Both `new_seas_block()` and `new_seas_multi_block()` configure the same
#' `seasonal::seas()` call through the same JS argument builder: one row per
#' spec argument, autocompleted from the parsed X-13 manual. Only what they do
#' with the resulting arguments differs, so the UI and the R-to-JS wiring live
#' here and the blocks keep the expression.
#'
#' @name seas-args-module
#' @keywords internal
NULL

#' UI half of the argument builder
#'
#' @param id Block namespace.
#' @return A `tagList` carrying the dependencies and the empty container the
#'   JS component mounts into.
#' @noRd
seas_args_ui <- function(id) {
  htmltools::tagList(
    blockr_core_js_dep(),
    blockr_blocks_css_dep(),
    blockr_select_dep(),
    blockr_select_rich_dep(),
    seas_block_dep(),
    shiny::div(
      class = "block-container",
      shiny::div(
        id = shiny::NS(id, "seas_input"),
        class = "seas-block-container"
      )
    )
  )
}

#' Server half of the argument builder
#'
#' Call from inside `moduleServer()`. Sends the catalog and the connection
#' status to the client, and keeps `r_state` and the client in sync in both
#' directions.
#'
#' @param input,session The module's `input` and `session`.
#' @param state Initial state, a list with an `args` element.
#' @param has_xreg,has_xtrans Reactives saying whether those inputs are
#'   connected. The client greys the corresponding rows when they are not.
#' @return A `reactiveVal` holding the block state.
#' @noRd
seas_args_server <- function(input, session, state,
                             has_xreg = shiny::reactive(FALSE),
                             has_xtrans = shiny::reactive(FALSE)) {
  ns <- session$ns
  r_state <- shiny::reactiveVal(state)

  # Guards the R -> JS push while R is handling a JS -> R message, so a state
  # change the client already knows about is not echoed back to it.
  self_write <- new.env(parent = emptyenv())
  self_write$active <- FALSE

  shiny::observe({
    session$sendCustomMessage(
      "seas-catalog",
      list(id = ns("seas_input"), catalog = get_x13_catalog())
    )
  }, priority = 100)

  shiny::observe({
    session$sendCustomMessage(
      "seas-connections",
      list(id = ns("seas_input"), xreg = has_xreg(), xtrans = has_xtrans())
    )
  })

  shiny::observeEvent(input$seas_input, {
    self_write$active <- TRUE
    r_state(input$seas_input)
    self_write$active <- FALSE
  })

  shiny::observeEvent(r_state(), {
    if (!self_write$active) {
      session$sendCustomMessage(
        "seas-block-update",
        list(id = ns("seas_input"), state = r_state())
      )
    }
  })

  r_state
}

#' The symbols blockr.core binds variadic inputs to
#'
#' An unnamed variadic slot is `.arg1`, `.arg2`, ...; a named link keeps its
#' own name. Mirrors `blockr.core:::dot_arg_refs()`, which is internal, so it
#' is reimplemented here rather than reached into.
#'
#' @param x The `...args` list.
#' @return A character vector of symbol names, one per input.
#' @noRd
dot_refs <- function(x) {
  nms <- names(x)
  if (is.null(nms)) nms <- character(length(x))
  unnamed <- !nzchar(nms)
  replace(nms, unnamed, paste0(".arg", seq_len(sum(unnamed))))
}
