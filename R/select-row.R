#' A row of labelled single-selects
#'
#' Several blocks here need two or three small dropdowns side by side: which
#' column holds the series, which year to compare from. `shiny::selectInput()`
#' would work and would look like Bootstrap in the middle of a block that does
#' not, so these mount `Blockr.Select.single` instead, from one script that
#' serves the whole row.
#'
#' The R side stays authoritative about what is selected. `setOptions()` does
#' not fire `onChange`, so a value pushed from R cannot come back as if the
#' user had chosen it, which is the loop that bites every select binding
#' sooner or later.
#'
#' @name select-row
#' @keywords internal
NULL

#' UI for a row of selects
#'
#' @param id Block namespace.
#' @param fields List of `list(name =, label =)`, left to right.
#' @param msg Custom message id the server pushes options on. Must be unique
#'   per block class, since Shiny dispatches handlers by name globally.
#' @return A `tagList`.
#' @noRd
select_row_ui <- function(id, fields, msg) {
  ns <- shiny::NS(id)

  spec <- lapply(fields, function(f) {
    list(container = ns(paste0("cont_", f$name)),
         input = ns(paste0("sel_", f$name)))
  })

  htmltools::tagList(
    # blockr.dplyr OWNS Blockr.Select and the CSS under it. This package
    # carried a copy for a while and it drifted: 540 lines against 1086.
    blockr.dplyr::blockr_select_dep(),
    select_row_css(),
    shiny::div(
      class = "blockr-select-row",
      lapply(fields, function(f) {
        shiny::div(
          class = "blockr-select-row__field",
          shiny::tags$label(class = "blockr-select-row__label", f$label),
          shiny::div(id = ns(paste0("cont_", f$name)))
        )
      })
    ),
    shiny::tags$script(shiny::HTML(sprintf("
      $(function() {
        var spec = %s;
        var sels = {};
        var iv = setInterval(function() {
          if (typeof Blockr === 'undefined' || !Blockr.Select) return;
          if (!spec.every(function(s) {
            return document.getElementById(s.container);
          })) return;
          clearInterval(iv);
          spec.forEach(function(s) {
            sels[s.input] = Blockr.Select.single(
              document.getElementById(s.container),
              {
                options: [],
                onChange: function(v) {
                  Shiny.setInputValue(s.input, v, {priority: 'event'});
                }
              }
            );
          });
        }, 100);

        Shiny.addCustomMessageHandler(%s, function(msg) {
          var s = sels[msg.input];
          if (!s) return;
          s.setOptions(msg.options, msg.value);
        });
      });
    ",
      jsonlite::toJSON(spec, auto_unbox = TRUE),
      jsonlite::toJSON(msg, auto_unbox = TRUE)
    )))
  )
}

#' Push a select's options and current value
#'
#' @param session The module session.
#' @param msg The message id used in `select_row_ui()`.
#' @param name Field name.
#' @param options Character vector of choices.
#' @param value Current value.
#' @noRd
select_row_set <- function(session, msg, name, options, value) {
  session$sendCustomMessage(
    msg,
    list(
      input = session$ns(paste0("sel_", name)),
      options = as.list(as.character(options)),
      value = if (is.null(value)) NULL else as.character(value)
    )
  )
}

#' @noRd
select_row_css <- function() {
  shiny::tags$style(shiny::HTML("
    .blockr-select-row {
      display: flex;
      gap: 12px;
      margin-bottom: 8px;
    }
    .blockr-select-row__field { flex: 1 1 0; min-width: 0; }
    .blockr-select-row__label {
      display: block;
      font-size: 11px;
      text-transform: uppercase;
      letter-spacing: .04em;
      color: #67676c;
      margin-bottom: 2px;
    }
  "))
}
