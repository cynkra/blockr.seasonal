#' Series Explorer CSS
#'
#' Returns inline styles for the series explorer block.
#' Selectize dropdown styled to match blockr.dock's block selector.
#'
#' @return shiny tags$style element
#' @noRd
sx_explorer_css <- function() {
  shiny::tags$style(shiny::HTML('
/* --- Block container ----------------------- */
.sx-block {
  padding: 12px;
  font-family: "Open Sans", system-ui, -apple-system, sans-serif;
  font-size: 14px;
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
.sx-select-wrap .form-group {
  margin-bottom: 0;
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

/* --- Selectize dropdown (matches dock block selector) --- */
.sx-block .selectize-dropdown-content {
  max-height: 400px !important;
  padding: 8px 0;
}
.sx-block .selectize-dropdown .optgroup-header {
  font-size: 10px;
  font-weight: 600;
  color: #6b7280;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  padding: 10px 12px 4px;
  background: transparent;
  border-top: 1px solid #f0f0f0;
}
.sx-block .selectize-dropdown .optgroup:first-child .optgroup-header {
  border-top: none;
  padding-top: 4px;
}

/* Option items — icon + name + description layout */
.sx-block .selectize-dropdown .sx-option {
  padding: 10px 16px;
  display: flex;
  align-items: flex-start;
  gap: 12px;
  margin: 2px 8px;
  border-radius: 6px;
  transition: background-color 0.15s ease;
}
.sx-block .selectize-dropdown .sx-option:hover,
.sx-block .selectize-dropdown .sx-option.active {
  background-color: #f3f4f6;
}
.sx-option-icon {
  flex-shrink: 0;
  width: 36px;
  height: 36px;
  border-radius: 7px;
  display: flex;
  align-items: center;
  justify-content: center;
}
.sx-option-content {
  flex: 1;
  min-width: 0;
}
.sx-option-header {
  display: flex;
  align-items: baseline;
  gap: 8px;
}
.sx-option-name {
  font-weight: 600;
  font-size: 14px;
  color: #111827;
}
.sx-option-cat {
  display: inline-block;
  padding: 1px 6px;
  font-size: 10px;
  border-radius: 4px;
  background: rgba(148, 163, 184, 0.1);
  color: rgba(100, 116, 139, 0.9);
  border: 1px solid rgba(100, 116, 139, 0.1);
  white-space: nowrap;
  flex-shrink: 0;
}
.sx-option-desc {
  font-size: 12px;
  color: #6b7280;
  line-height: 1.4;
  margin-top: 2px;
}

/* Selected item display — compact badge */
.sx-item-selected {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  padding: 2px 6px;
}
.sx-item-icon {
  flex-shrink: 0;
  width: 22px;
  height: 22px;
  border-radius: 4px;
  display: flex;
  align-items: center;
  justify-content: center;
}
.sx-item-name {
  font-weight: 600;
  font-size: 13px;
  color: #111827;
}
.sx-item-desc {
  font-size: 11px;
  color: #9ca3af;
}

/* --- Chart wrapper ------------------------- */
.sx-chart-wrap {
  margin-top: 8px;
}
'))
}
