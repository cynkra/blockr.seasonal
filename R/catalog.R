#' X-13 argument catalog
#'
#' Loads and caches the X-13 argument catalog from inst/extdata/x13-args.json.
#' The catalog provides argument metadata (type, allowed values, descriptions)
#' for the seas() argument builder UI.
#'
#' @noRd

.catalog_env <- new.env(parent = emptyenv())

#' Get the X-13 argument catalog
#'
#' @return Named list of argument definitions, each with spec, arg, type,
#'   values (if enum/multi-enum), default, and description.
#' @noRd
get_x13_catalog <- function() {
  if (is.null(.catalog_env$catalog)) {
    path <- system.file("extdata", "x13-args.json", package = "blockr.seasonal")
    .catalog_env$catalog <- jsonlite::fromJSON(path, simplifyVector = FALSE)
  }
  .catalog_env$catalog
}
