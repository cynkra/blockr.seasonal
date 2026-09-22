# Builds inst/extdata/x13-args.json, the catalog the seas block's argument
# finder runs on.
#
# TWO SOURCES, AND NEITHER IS ENOUGH ALONE.
#
#   data-raw/SPECS_ARGS.csv   284 arguments over 20 specs, parsed out of the
#                             X-13 reference manual by seasonal's
#                             `feature/spec-arg-catalog` branch
#                             (noinst/specs/args_from_pdf.R). It carries the
#                             NAMES and the DESCRIPTIONS, with the manual's
#                             floating tables taken back out of the prose.
#
#   the previous catalog      hand-curated: the TYPE of an argument, its
#                             allowed VALUES, and what each value means. That
#                             is what turns a text field into a picker, and
#                             the manual states it in prose the parser cannot
#                             reach. 41 arguments have it.
#
# The merge is: every name and description from the csv, every type and value
# list from the curated file, and the ten spec activators (`x11`, `seats`,
# `automdl`, ...) which are not arguments and so are not in the csv at all.
#
# When the seasonal branch lands on CRAN, replace the csv snapshot with the
# package's own export and delete this comment's first paragraph.
#
#   Rscript data-raw/x13-args.R

`%||%` <- function(x, y) if (is.null(x)) y else x

out_path <- "inst/extdata/x13-args.json"
curated <- jsonlite::fromJSON(out_path, simplifyVector = FALSE)
args <- utils::read.csv("data-raw/SPECS_ARGS.csv", stringsAsFactors = FALSE)

catalog <- list()

# ONE SPEC ACTIVATOR, NOT TEN. `seas(x, <spec> = "")` names a spec rather than
# setting an argument, and the curated catalog carried ten of them as if they
# were equivalent. Measured against `seas(AirPassengers)`, they are not:
#
#   x11           102 new diagnostics, ADJUSTED SERIES CHANGES. The other
#                 decomposition, and the reason this case exists at all.
#   seats         X-13 errors
#   transform     X-13 errors
#   regression    X-13 errors
#   automdl       0 new diagnostics, series identical -- `seas()` sends it
#   outlier       same
#   estimate      same
#   check         same
#   forecast      same
#   arima         101 new, series changes, and it fits (0 0 0): an empty
#                 arima spec silently switches automdl off. A trap.
#
# Two that are not in the curated list were checked as well and are also out.
# `pickmdl = ""` picks from its five built-in models and lands on the airline
# model, which is what automdl gives anyway. `slidingspans = ""` produces the
# 22 sliding-spans diagnostics, but `series()` adds the spec and re-runs on
# its own when something asks for one of its series -- seasonal's own hint is
# `slidingspans.save`, an argument. Neither earns a row.
SPEC_ACTIVATORS <- "x11"

for (nm in SPEC_ACTIVATORS) {
  catalog[[nm]] <- curated[[nm]]
  catalog[[nm]]$description <- paste(
    "Adjust with X-11 rather than SEATS. Takes no value of its own:",
    "naming the spec is what switches it on."
  )
}

for (i in seq_len(nrow(args))) {
  long <- args$long[i]
  old <- curated[[long]]
  entry <- list(
    spec = args$spec[i],
    arg = args$arg[i],
    type = if (!is.null(old)) old$type else "unknown",
    description = args$description[i]
  )
  if (length(old$values)) entry$values <- old$values
  if (length(old$default)) entry$default <- old$default
  catalog[[long]] <- entry
}

# Anything curated that the manual parse does not know about stays, rather
# than being dropped silently: a missing name is a control that disappears.
# The spec activators are the exception -- they were dropped on purpose.
for (nm in names(curated)) {
  if (is.null(catalog[[nm]]) && !identical(curated[[nm]]$type, "spec")) {
    catalog[[nm]] <- curated[[nm]]
    message("kept a curated entry the manual parse did not have: ", nm)
  }
}

# WHAT THE PICKER DOES NOT OFFER, and why. Hidden rather than dropped: a
# board saved with `outlier.save = "tests"` has to keep rendering a control
# and a description when it is restored, and so does anyone who pastes an
# argument back out of an exported script.
#
#   .print / .save / .savelog   48 arguments. They say what X-13 writes into
#     its output files, and nothing in the block reads those files by hand:
#     `series()` and `udg()` do, and they add the argument themselves. Ask a
#     model for a series it has no spec for and seasonal answers "To speed up,
#     extend the seas() call: seas(x, slidingspans.save = 'sfs')" -- a
#     performance hint the extractor issues, not a modelling choice.
#
#   composite.*, metadata.*     12. Composite adjustment needs several series
#     through `composite=`, and metadata writes keys into the spc file.
#
#   series.* except span,       17. The block passes `x = tsbox::ts_ts(data)`,
#     modelspan, appendfcst,    so a control for reading the series from a
#     appendbcst                file is a control for breaking the block.
#     `span` and `modelspan` stay: they restrict what is adjusted and what the
#     model is fitted on, which people do use.
#
# 77 hidden, 208 offered, all 18 specs still represented.
SERIES_KEPT <- c("series.span", "series.modelspan",
                 "series.appendfcst", "series.appendbcst")

nms <- names(catalog)
catalog <- stats::setNames(lapply(nms, function(nm) {
  e <- catalog[[nm]]
  arg <- sub("^.*\\.", "", nm)
  spec <- sub("\\..*$", "", nm)
  hide <- arg %in% c("print", "save", "savelog") ||
    spec %in% c("composite", "metadata") ||
    (spec == "series" && !nm %in% SERIES_KEPT)
  if (hide) e$hidden <- TRUE
  e
}), nms)

# A NULL FIELD HAS TO BE ABSENT, not empty. `write_json()` turns NULL into
# `{}`, and `{}` is truthy in the browser: an entry whose `arg` is an empty
# object renders as "[object Object]" in the finder, and one whose `values` is
# renders a chooser with nothing in it.
catalog <- lapply(catalog, function(e) e[vapply(e, length, 0L) > 0L])

jsonlite::write_json(catalog, out_path, auto_unbox = TRUE, pretty = TRUE)

n_val <- sum(vapply(catalog, function(e) !is.null(e$values), TRUE))
n_desc <- sum(vapply(catalog, function(e) nzchar(e$description %||% ""), TRUE))
message(length(catalog), " entries, ", n_val, " with a value list, ",
        n_desc, " with a description")
