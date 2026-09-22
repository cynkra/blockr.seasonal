#' Triage Table
#'
#' Turns a round of seasonal adjustments into one sorted table: what X-13 chose
#' for each series, whether seasonality survives in the adjusted series, and
#' how far each adjustment is from a reference you already trust.
#'
#' Variadic, in order: the first input is the `seas_multi` that
#' [new_seas_block()] returns when its input holds several series -- `seas()`
#' takes an `mts` and answers with one model per column -- and the optional
#' second is a long data frame holding
#' the adjustment to compare against, typically the statistical office's own
#' published series.
#'
#' See [seas_triage()] for what the columns mean and what trips a flag. The
#' block is a thin wrapper: everything it does is one call, so the exported
#' document gets `seas_triage(models, reference = ref)` rather than a pipeline.
#'
#' @param since Compare against the reference from this date on. A string, a
#'   Date, or `NULL` for the whole overlap.
#' @param ref_cols Named list with `series`, `time` and `value`, naming the
#'   reference's columns. Empty resolves them by type on arrival.
#' @param ref_crit Percent. Worst-month gap from the reference above which a
#'   series is flagged.
#' @param qs_crit QS critical value for residual seasonality. Left off the
#'   panel on purpose: `7.81` is the 5 percent point of a chi-squared with two
#'   degrees of freedom, which is what QS is tested against, and it is a
#'   constant rather than a knob.
#' @param ... Forwarded to [blockr.core::new_transform_block()].
#'
#' @return A transform block of class `seas_triage_block`.
#'
#' @export
new_seas_triage_block <- function(since = NULL,
                                  ref_cols = list(),
                                  ref_crit = 5,
                                  qs_crit = 7.81,
                                  ...) {
  blockr.core::new_transform_block(
    server = function(id, ...args) {
      shiny::moduleServer(id, function(input, output, session) {

        r_since <- shiny::reactiveVal(if (is.null(since)) "" else as.character(since))
        r_ref_crit <- shiny::reactiveVal(ref_crit)
        r_qs_crit <- shiny::reactiveVal(qs_crit)

        has_ref <- shiny::reactive(length(...args) >= 2L)

        r_ref_cols <- shiny::reactiveVal(ref_cols)

        reference <- shiny::reactive({
          shiny::req(has_ref())
          d <- ...args[[2]]
          shiny::req(is.data.frame(d))
          d
        })

        # Resolve the reference's three roles the moment it arrives, and keep
        # the resolved names in state. Type alone is not enough here: a
        # published file that keeps an `is_adj` flag beside the value has two
        # numeric columns and the flag comes first.
        shiny::observeEvent(reference(), {
          cur <- r_ref_cols()
          picks <- resolve_series_columns(
            reference(),
            series = cur$series, time = cur$time, value = cur$value
          )
          r_ref_cols(picks)
        })

        shiny::observe({
          shiny::req(has_ref())
          nms <- names(reference())
          cur <- r_ref_cols()
          for (role in c("series", "time", "value")) {
            select_row_set(session, "seas-triage-opts",
                           paste0("ref_", role), nms, cur[[role]])
          }
        })

        shiny::observeEvent(input$sel_ref_series, {
          r_ref_cols(utils::modifyList(r_ref_cols(),
                                       list(series = input$sel_ref_series)))
        })
        shiny::observeEvent(input$sel_ref_time, {
          r_ref_cols(utils::modifyList(r_ref_cols(),
                                       list(time = input$sel_ref_time)))
        })
        shiny::observeEvent(input$sel_ref_value, {
          r_ref_cols(utils::modifyList(r_ref_cols(),
                                       list(value = input$sel_ref_value)))
        })

        # Offer the years the models actually cover, so "compare since" cannot
        # be set to a year with no overlap.
        year_choices <- shiny::reactive({
          models <- if (length(...args) >= 1L) ...args[[1]] else NULL
          if (!is.list(models) || !length(models)) return(SINCE_ANY)
          ok <- Filter(function(m) inherits(m, "seas"), models)
          if (!length(ok)) return(SINCE_ANY)
          yrs <- vapply(ok, function(m) {
            floor(min(as.numeric(stats::time(seasonal::final(m)))))
          }, numeric(1))
          c(SINCE_ANY, rev(as.character(seq(min(yrs), max(yrs)))))
        })

        shiny::observe({
          yrs <- unique(year_choices())
          cur <- r_since()
          shown <- if (!nzchar(cur)) SINCE_ANY else substr(cur, 1, 4)
          # The widget falls back to its first option when told to select one
          # it does not have, and never reports that back, so a year set in the
          # constructor would silently read as "all" until the models arrive.
          # Carrying the pick into the list keeps what R holds and what the
          # panel shows the same thing at every moment.
          if (!shown %in% yrs) yrs <- c(yrs, shown)
          select_row_set(session, "seas-triage-opts", "since", yrs, shown)
          select_row_set(session, "seas-triage-opts", "ref_crit",
                         REF_CRIT_CHOICES, as.character(r_ref_crit()))
        })

        shiny::observeEvent(input$sel_since, {
          r_since(
            if (identical(input$sel_since, SINCE_ANY)) {
              ""
            } else {
              paste0(input$sel_since, "-01-01")
            }
          )
        })

        shiny::observeEvent(input$sel_ref_crit, {
          r_ref_crit(as.numeric(input$sel_ref_crit))
        })

        list(
          expr = shiny::reactive({
            refs <- dot_refs(...args)
            shiny::req(length(refs) >= 1L)
            make_triage_expr(
              models_ref = refs[[1]],
              reference_ref = if (has_ref()) refs[[2]] else NULL,
              ref_cols = r_ref_cols(),
              since = r_since(),
              ref_crit = r_ref_crit(),
              qs_crit = r_qs_crit()
            )
          }),
          state = list(
            since = r_since,
            ref_cols = r_ref_cols,
            ref_crit = r_ref_crit,
            qs_crit = r_qs_crit
          )
        )
      })
    },
    ui = function(id) {
      htmltools::tagList(
        select_row_ui(
          id,
          list(
            list(name = "since", label = "Compare since"),
            list(name = "ref_crit", label = "Flag above %"),
            list(name = "ref_series", label = "Reference series"),
            list(name = "ref_time", label = "Reference time"),
            list(name = "ref_value", label = "Reference value")
          ),
          msg = "seas-triage-opts"
        )
      )
    },
    class = "seas_triage_block",
    expr_type = "bquoted",
    allow_empty_state = c("since", "ref_cols", "ref_crit", "qs_crit"),
    ...
  )
}

# The "no cutoff" entry in the since dropdown, and the thresholds it offers.
SINCE_ANY <- "all"
REF_CRIT_CHOICES <- c("1", "2", "5", "10", "25")

#' Build the triage expression
#'
#' One call, so the report chunk is one line. `since` is emitted as a date
#' literal rather than a variable, because a reader lifting the chunk should
#' see the window it was computed over.
#'
#' @param models_ref Symbol the models input is bound to.
#' @param reference_ref Symbol the reference input is bound to, or `NULL`.
#' @param ref_cols Named list of the reference's column roles.
#' @param since Character date, or `""` for none.
#' @param ref_crit,qs_crit Thresholds.
#' @noRd
make_triage_expr <- function(models_ref, reference_ref = NULL,
                             ref_cols = list(), since = "",
                             ref_crit = 5, qs_crit = 7.81) {
  args <- list(
    str2lang("blockr.seasonal::seas_triage"),
    call(".", as.name(models_ref))
  )
  if (!is.null(reference_ref)) {
    args$reference <- call(".", as.name(reference_ref))
    for (role in c("series", "time", "value")) {
      v <- ref_cols[[role]]
      if (!is.null(v) && nzchar(v)) {
        args[[paste0("ref_", role)]] <- v
      }
    }
  }
  if (nzchar(since)) {
    args$since <- call("as.Date", since)
  }
  args$qs_crit <- qs_crit
  if (!is.null(reference_ref)) {
    args$ref_crit <- ref_crit
  }

  as.call(args)
}
