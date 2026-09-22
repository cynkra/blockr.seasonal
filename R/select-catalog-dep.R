
#' The version the block's own assets are served under
#'
#' Shiny serves an `htmlDependency` under a path containing its version, so a
#' browser that has seen `seas-args-js-0.0.1/seas-args.js` keeps that copy
#' until the string changes. `packageVersion()` does not change during
#' development, which is exactly when these files change, so a reinstall
#' looks like it did nothing and the browser keeps showing yesterday's UI.
#'
#' BUMP THIS BY HAND whenever anything in `inst/js` or `inst/css` changes.
#' Same reason and same shape as `blockr.ts::ts_asset_version()`.
#' @noRd
seas_asset_version <- function() {
  "0.13.0"
}

#' The catalogue select
#'
#' `Blockr.SelectCatalog`, for lists that are long, categorised and described:
#' the 217 X-13 output series, and the 306 X-13 arguments beside them. A
#' searchable single- or multi-select whose options carry a `group` and a
#' `description`, and which grows a facet rail beside the results when the
#' control is wide enough to spend the space.
#'
#' @details
#' IT IS A FORK OF `Blockr.Select`, deliberately, and it lives here rather than
#' in the shared layer. That control is loaded by every block in the ecosystem;
#' this one is new. A divergent copy is the cheap risk and a refactor of the
#' thing everything depends on is the expensive one, so the copy stands until
#' the shared layer moves to blockr.ui.
#'
#' The merge is additive and the instruction for doing it is the header comment
#' of `inst/js/blockr-select-catalog.js`, which enumerates the six changes
#' against the file it was forked from, names the one behaviour that differs
#' (`maxRendered`), and says how to tell the merge did not regress. Read that
#' before folding the two together.
#'
#' Three things worth knowing before using it:
#'
#' * **The description is searched.** It has to be: "trend" finds `dtr` and
#'   `ltt` only through their sentences, and a catalogue whose search covers
#'   only its four-character codes is one nobody can search.
#' * **The rail is not a flag.** It appears above roughly 520px of measured
#'   control width and disappears below it. A block author cannot know how wide
#'   a dock panel will be, so the control decides, from a `ResizeObserver`.
#' * **With no `group` and no `description` it is `Blockr.Select`.** Every
#'   addition sits behind two flags computed once when the options change, so a
#'   flat list pays a boolean per render.
#'
#' @return An [htmltools::htmlDependency] list.
#' @noRd
blockr_select_catalog_dep <- function() {
  htmltools::tagList(
    # `Blockr.uid`, `Blockr.escapeHtml`, `Blockr.icons`: blockr.dplyr's, not a
    # copy of them.
    blockr.dplyr::blockr_core_js_dep(),
    htmltools::htmlDependency(
      name = "blockr-select-catalog-js",
      version = seas_asset_version(),
      src = system.file("js", package = "blockr.seasonal"),
      script = "blockr-select-catalog.js"
    ),
    htmltools::htmlDependency(
      name = "blockr-select-catalog-css",
      version = seas_asset_version(),
      src = system.file("css", package = "blockr.seasonal"),
      stylesheet = "blockr-select-catalog.css"
    )
  )
}

#' The seas block's argument rows
#'
#' The control surface built on `blockr_select_catalog_dep()`: one row per
#' argument, the sentence of suggestions under them, and the console line that
#' adds one.
#' @noRd
seas_args_dep <- function() {
  htmltools::tagList(
    htmltools::htmlDependency(
      name = "seas-args-js",
      version = seas_asset_version(),
      src = system.file("js", package = "blockr.seasonal"),
      script = "seas-args.js"
    ),
    htmltools::htmlDependency(
      name = "seas-args-css",
      version = seas_asset_version(),
      src = system.file("css", package = "blockr.seasonal"),
      stylesheet = "seas-args.css"
    )
  )
}
