#' The argument builder
#'
#' One control surface over one state. The state is the argument rows, a list
#' of `list(name =, value =)`, and everything on screen is a view of them: the
#' rows themselves, the sentence of suggestions above the picker, and the
#' picker over the whole catalog. There is no second vocabulary and nothing to
#' reconcile on restore.
#'
#' The client owns the editing and sends the rows back whole. R sends the
#' catalog and the suggestions once, on mount, and pushes rows down again only
#' when something other than the client wrote them -- a restored board, or
#' another block through `external_ctrl`.
#'
#' @name seas-args-module
#' @keywords internal
NULL

#' UI half of the argument builder
#'
#' @param id Block namespace.
#' @return A `tagList` carrying the dependencies and the empty container the
#'   client mounts into.
#' @noRd
seas_args_ui <- function(id) {
  htmltools::tagList(
    blockr_select_catalog_dep(),
    seas_args_dep(),
    shiny::div(
      class = "block-container",
      shiny::div(id = shiny::NS(id, "seas_input"), class = "seas-args"),

      # THE CLIENT ASKS; THE SERVER DOES NOT PUSH BLIND. The catalogue used
      # to go out in a bare `observe()` at module start, which is before this
      # div is on the page whenever the block's server runs ahead of its
      # markup -- a dock panel that is not on the startup view, a block
      # evaluated because something downstream needs it. Shiny drops a custom
      # message whose handler has not registered, nothing re-sends, and the
      # argument band stays empty for the life of the session while the
      # expression below it renders fine.
      #
      # This script ships WITH the container, so it cannot run before it
      # exists. It waits for Shiny rather than for a document event, because
      # a late-mounted panel arrives long after both.
      shiny::tags$script(shiny::HTML(sprintf(
        "(function(){var f=function(){if(window.Shiny&&Shiny.setInputValue){Shiny.setInputValue('%s', Date.now(), {priority:'event'});}else{setTimeout(f,50);}};f();})();",
        shiny::NS(id, "seas_ready")
      ))),

      # THE EXPRESSION, BETWEEN WHAT YOU SET AND WHAT CAME OUT. Its own band
      # rather than another row, because it is not an input: the arguments
      # above write it and core runs it, and putting it among them would make
      # it look like one more thing to fill in.
      #
      # This belongs in blockr.ui, not here. Every block writes an expression,
      # so "let me see it" is general, and blockr.core answers it today only
      # with a board-wide modal (`generate_code_ui()`). Built here to find out
      # how it feels; see the inbox note.
      shiny::div(
        class = "seas-expr",
        shiny::textOutput(shiny::NS(id, "seas_expr"), container = function(...) {
          htmltools::tags$pre(class = "seas-expr__code", ...)
        })
      )
    )
  )
}

#' Server half of the argument builder
#'
#' Call from inside `moduleServer()`.
#'
#' @param input,session The module's `input` and `session`.
#' @param args Initial argument rows, a list of `list(name =, value =)`.
#' @param has_xreg,has_xtrans Reactives saying whether those inputs are
#'   connected. Kept for the variadic slots.
#' @return A `reactiveVal` holding the argument rows. A reactiveVal and not a
#'   reactive, because the block declares `external_ctrl = TRUE` and
#'   blockr.core refuses state it cannot write back.
#' @noRd
seas_args_server <- function(input, session, args,
                             has_xreg = shiny::reactive(FALSE),
                             has_xtrans = shiny::reactive(FALSE)) {
  ns <- session$ns
  id <- ns("seas_input")

  r_args <- shiny::reactiveVal(seas_rows(args))

  # WHAT THE CLIENT ALREADY HAS, so R does not send it back. Every edit goes
  # client -> R, and the observer below would return it unchanged: the client
  # re-renders, the control the user is typing in is destroyed, and the next
  # keystroke lands nowhere. A Backspace removes one tag and the second does
  # nothing, which is how this was found.
  #
  # A flag set and cleared inside the input observer does not work: the push
  # observer runs after it, in the same flush, by which time the flag is down.
  # Comparing is the only thing that holds across the flush.
  seen <- new.env(parent = emptyenv())
  seen$rows <- seas_rows(args)

  # The catalog is 285 entries and never changes, so it goes once -- but on
  # the CLIENT's word, not at module start. See the script in `seas_args_ui()`
  # for why the push cannot be blind.
  shiny::observeEvent(input$seas_ready, {
    session$sendCustomMessage("seas-args-init", list(
      id = id,
      catalog = get_x13_catalog(),
      suggestions = seas_suggestions(),
      open = as.list(seas_open_args()),
      args = seas_rows(shiny::isolate(r_args()))
    ))
  }, priority = 100)

  shiny::observeEvent(input$seas_input, {
    rows <- seas_rows(input$seas_input$args)
    seen$rows <- rows
    r_args(rows)
  })

  # Anything that writes the rows from the R side -- a restored board, another
  # block through external_ctrl -- redraws the client. An edit the client made
  # itself does not.
  shiny::observeEvent(r_args(), {
    rows <- seas_rows(r_args())
    if (identical(rows, seen$rows)) {
      return()
    }
    seen$rows <- rows
    session$sendCustomMessage("seas-args-update", list(id = id, args = rows))
  }, ignoreNULL = FALSE)

  r_args
}

#' Arguments whose value list is known but does not close
#'
#' X-13 takes dated terms in these (`ao1951.may`, `rp1988.jan-1988.dec`), so
#' their control has to accept a typed value beside the catalog's own.
#' @noRd
seas_open_args <- function() {
  c("regression.variables", "x11regression.variables")
}

#' Argument rows, as R holds them
#'
#' The wire carries whatever JSON gave us: a row's `value` arrives as a string
#' for a single value and as a list for a multi. Both are kept as they are --
#' `seas_call_args()` reads the catalog to decide what a value becomes in the
#' call, and a row that guessed here would guess differently there.
#'
#' What this does do is drop the shapes that are not rows at all, so a
#' malformed message cannot reach the expression builder.
#'
#' @param x A list of rows, or `NULL`.
#' @return A list of `list(name =, value =)`, possibly empty.
#' @noRd
seas_rows <- function(x) {
  if (is.null(x) || !length(x)) {
    return(list())
  }
  keep <- vapply(x, function(r) {
    is.list(r) && length(r$name) == 1L && nzchar(as.character(r$name))
  }, logical(1))
  lapply(x[keep], function(r) {
    list(name = as.character(r$name), value = r$value)
  })
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
