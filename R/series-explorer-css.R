#' Series Explorer CSS
#'
#' Minimal styles for the series explorer block layout.
#' The dropdown itself is styled by blockr-select-rich.css.
#'
#' @return shiny tags$style element
#' @noRd
sx_explorer_css <- function() {
  shiny::tags$style(shiny::HTML('
/* --- Block container ----------------------- */
.sx-block {
  padding: 12px;
  font-family: inherit;
  font-size: 0.875rem;
  line-height: 1.5;
  color: #111827;
}

/* --- Top row: select + advanced toggle ----- */
.sx-top-row {
  display: flex;
  align-items: flex-start;
  gap: 12px;
}
.sx-select-wrap {
  flex: 1;
  min-width: 0;
}
.sx-adv-wrap {
  flex-shrink: 0;
  padding-top: 6px;
}
.sx-adv-label {
  display: flex;
  align-items: center;
  gap: 6px;
  cursor: pointer;
  user-select: none;
  white-space: nowrap;
}
.sx-adv-check {
  width: 15px;
  height: 15px;
  accent-color: #3b82f6;
  cursor: pointer;
}
.sx-adv-text {
  font-size: 12px;
  font-weight: 500;
  color: #6b7280;
}

/* --- Chart wrapper ------------------------- */
.sx-chart-wrap {
  margin-top: 8px;
}
'))
}
