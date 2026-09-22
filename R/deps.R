#' HTML dependencies for the seas argument builder
#'
#' @importFrom htmltools htmlDependency tagList
#' @noRd
NULL

#' Blockr core JS dependency (namespace + utilities)
#' Duplicated from blockr.dplyr — extract to shared package later
#' @noRd
blockr_core_js_dep <- function() {
  htmltools::htmlDependency(
    name = "blockr-core-js",
    version = utils::packageVersion("blockr.seasonal"),
    src = system.file("js", package = "blockr.seasonal"),
    script = "blockr-core.js"
  )
}

#' Shared block CSS dependency (rows, buttons, etc.)
#' Duplicated from blockr.dplyr — extract to shared package later
#' @noRd
blockr_blocks_css_dep <- function() {
  htmltools::htmlDependency(
    name = "blockr-blocks-css",
    version = utils::packageVersion("blockr.seasonal"),
    src = system.file("css", package = "blockr.seasonal"),
    stylesheet = "blockr-blocks.css"
  )
}

#' Blockr.Select component dependency
#' Duplicated from blockr.dplyr — extract to shared package later
#' @noRd
blockr_select_dep <- function() {
  htmltools::tagList(
    blockr_core_js_dep(),
    htmltools::htmlDependency(
      name = "blockr-select-js",
      version = utils::packageVersion("blockr.seasonal"),
      src = system.file("js", package = "blockr.seasonal"),
      script = "blockr-select.js"
    ),
    htmltools::htmlDependency(
      name = "blockr-select-css",
      version = utils::packageVersion("blockr.seasonal"),
      src = system.file("css", package = "blockr.seasonal"),
      stylesheet = "blockr-select.css"
    )
  )
}

#' Rich select component dependency (searchable select with descriptions)
#' Reusable — extract to blockr.core when needed
#' Seas summary CSS dependency
#' @noRd
seas_summary_css_dep <- function() {
  htmltools::htmlDependency(
    name = "seas-summary-css",
    version = utils::packageVersion("blockr.seasonal"),
    src = system.file("css", package = "blockr.seasonal"),
    stylesheet = "seas-summary.css"
  )
}

#' Seas block JS + CSS dependency
