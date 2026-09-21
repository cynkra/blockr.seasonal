#' Seasonal Adjustment of Many Series
#'
#' Adjusts every series in a long data frame with the same `seasonal::seas()`
#' specification and returns one model per series.
#'
#' This is the block the single-series [new_seas_block()] is not. A statistical
#' office does not adjust a series, it runs a round: pull the twenty or forty
#' series that make up a release, adjust all of them, and find the two that need
#' a hand. Feed the result to [new_seas_triage_block()] to see which those are.
#'
#' The input is long: one column naming the series, one time column, one
#' numeric value column. The value column has to be numeric already; published
#' files often carry footnote markers in it, and coercing silently here would
#' turn a suppressed observation into a missing one without anybody seeing it.
#'
#' A series that fails to adjust does NOT kill the block. Its error is kept in
#' place of the model, so one bad series out of twenty costs you that series
#' rather than the round, and the triage table can report it.
#'
#' @param series Column naming the series. `NULL` picks the first character or
#'   factor column. Named `series` rather than `id` because a block server's
#'   own first argument is `id`, the namespace.
#' @param time Time column. `NULL` picks the first `Date` or `POSIXct` column.
#' @param value Value column. `NULL` picks the first numeric column.
#' @param state List with `args`, the X-13 specification, in the same shape
#'   [new_seas_block()] uses.
#' @param ... Forwarded to [blockr.core::new_transform_block()].
#'
#' @return A transform block of class `seas_multi_block`, whose result is a
#'   named list of `seas` models.
#'
#' @examples
#' if (interactive()) {
#'   blockr.core::serve(
#'     new_seas_multi_block(),
#'     data = list(
#'       x = data.frame(
#'         id = rep(c("a", "b"), each = 144),
#'         time = rep(seq(as.Date("1949-01-01"), by = "month",
#'                        length.out = 144), 2),
#'         value = c(as.numeric(datasets::AirPassengers),
#'                   as.numeric(datasets::AirPassengers) * 2)
#'       )
#'     )
#'   )
#' }
#'
#' @export
new_seas_multi_block <- function(series = NULL,
                                 time = NULL,
                                 value = NULL,
                                 state = list(args = list()),
                                 ...) {
  blockr.core::new_transform_block(
    server = function(id, data) {
      shiny::moduleServer(id, function(input, output, session) {
        ns <- session$ns

        r_series <- shiny::reactiveVal(NULL)
        r_time <- shiny::reactiveVal(NULL)
        r_value <- shiny::reactiveVal(NULL)
        r_state <- seas_args_server(input, session, state)

        cols <- shiny::reactive({
          d <- data()
          shiny::req(is.data.frame(d))
          d
        })

        # Resolve each role once the data is known. The resolved name is what
        # goes into state, so a board saved from an auto-detected pick reopens
        # on the same columns even if the data later gains another Date column.
        shiny::observeEvent(cols(), {
          d <- cols()
          picks <- resolve_series_columns(
            d,
            series = r_series() %||% series,
            time = r_time() %||% time,
            value = r_value() %||% value
          )
          r_series(picks$series)
          r_time(picks$time)
          r_value(picks$value)
        })

        # Push the column choices to the three selects. R stays authoritative
        # about the current pick: the widget is told what it is, never asked.
        shiny::observe({
          d <- cols()
          for (role in c("series", "time", "value")) {
            cur <- switch(role,
              series = r_series(), time = r_time(), value = r_value()
            )
            select_row_set(session, "seas-multi-cols", role, names(d), cur)
          }
        })

        shiny::observeEvent(input$sel_series, r_series(input$sel_series))
        shiny::observeEvent(input$sel_time, r_time(input$sel_time))
        shiny::observeEvent(input$sel_value, r_value(input$sel_value))

        list(
          expr = shiny::reactive({
            shiny::req(r_series(), r_time(), r_value())
            make_seas_multi_expr(
              args = r_state()$args %||% list(),
              id_col = r_series(),
              time_col = r_time(),
              value_col = r_value()
            )
          }),
          state = list(
            series = r_series,
            time = r_time,
            value = r_value,
            state = r_state
          )
        )
      })
    },
    ui = function(id) {
      htmltools::tagList(
        select_row_ui(
          id,
          list(
            list(name = "series", label = "Series"),
            list(name = "time", label = "Time"),
            list(name = "value", label = "Value")
          ),
          msg = "seas-multi-cols"
        ),
        seas_args_ui(id)
      )
    },
    class = "seas_multi_block",
    expr_type = "bquoted",
    allow_empty_state = c("series", "time", "value", "state"),
    ...
  )
}

#' Pick the id, time and value columns
#'
#' A name that is given and present wins. Otherwise the role is filled by type:
#' the first character or factor column, the first date column, the first
#' numeric column.
#'
#' @param d A data frame.
#' @param series,time,value Requested column names, or `NULL`.
#' @return A list with `series`, `time` and `value`, each a column name or
#'   `NULL`.
#' @noRd
resolve_series_columns <- function(d, series = NULL, time = NULL,
                                   value = NULL) {
  has <- function(x) !is.null(x) && length(x) == 1L && x %in% names(d)
  first_of <- function(pred) {
    hit <- names(d)[vapply(d, pred, logical(1))]
    if (length(hit)) hit[[1]] else NULL
  }

  list(
    series = if (has(series)) series else {
      first_of(function(x) is.character(x) || is.factor(x))
    },
    time = if (has(time)) time else {
      first_of(function(x) inherits(x, c("Date", "POSIXct", "yearmon", "yearqtr")))
    },
    value = if (has(value)) value else first_of(is.numeric)
  )
}

#' Build the many-series adjustment expression
#'
#' Emits plain R: take the three columns, split by series, adjust each. The
#' `tryCatch` is load-bearing rather than defensive, see [new_seas_multi_block()].
#'
#' @param args Rows from the argument builder.
#' @param id_col,time_col,value_col Column names.
#' @param input_ref Symbol the data input is bound to.
#' @return A language object.
#' @noRd
make_seas_multi_expr <- function(args, id_col, time_col, value_col,
                                 input_ref = "data") {
  seas_call <- as.call(c(
    list(
      str2lang("seasonal::seas"),
      quote(tsbox::ts_ts(tsbox::ts_regular(z)))
    ),
    seas_call_args(args)
  ))

  blockr.core::bbquote(
    local({
      d <- .(x_ref)[c(.(id_col), .(time_col), .(value_col))]
      names(d) <- c("id", "time", "value")
      d <- d[stats::complete.cases(d), ]
      lapply(
        split(d[c("time", "value")], d[["id"]]),
        function(z) tryCatch(.(seas_call), error = function(e) e)
      )
    }),
    list(
      x_ref = call(".", as.name(input_ref)),
      id_col = id_col,
      time_col = time_col,
      value_col = value_col,
      seas_call = seas_call
    )
  )
}

#' @export
block_ui.seas_multi_block <- function(id, x, ...) {
  shiny::verbatimTextOutput(shiny::NS(id, "result"))
}

#' @export
block_output.seas_multi_block <- function(x, result, session) {
  shiny::renderPrint({
    if (is.null(result)) {
      return(invisible(NULL))
    }
    ok <- vapply(result, inherits, logical(1), "seas")
    cat(sum(ok), "of", length(result), "series adjusted\n\n")
    for (nm in names(result)) {
      m <- result[[nm]]
      if (inherits(m, "seas")) {
        u <- seasonal::udg(m)
        cat(sprintf("  %-10s %-16s %s\n", nm,
                    as.character(u[["arimamdl"]])[1],
                    as.character(u[["aictrans"]])[1]))
      } else {
        cat(sprintf("  %-10s FAILED: %s\n", nm, conditionMessage(m)))
      }
    }
  })
}
