#' Expression builders for the seas argument builder
#'
#' @name seas-expr-builders
#' @keywords internal
NULL

#' Coerce the argument builder's rows into named call arguments
#'
#' One row of the builder is a name and a value, both strings from the client.
#' The X-13 catalog says what the argument's type is, and that decides what the
#' value becomes in the call: a bare `list()` for a spec, a number, a `c(...)`
#' for a multi-enum, a string otherwise. A row whose value does not survive its
#' declared type is dropped rather than emitted as something `seas()` will
#' reject.
#'
#' @param args List of `list(name =, value =)` rows.
#' @return A named list suitable for splicing into a `seasonal::seas()` call.
#' @noRd
seas_call_args <- function(args) {
  catalog <- get_x13_catalog()
  out <- list()

  for (a in args) {
    name <- a$name
    value <- a$value
    if (is.null(name) || !nzchar(name)) next
    if (is.null(value)) next

    entry <- catalog[[name]]

    # A ROW WITH NO VALUE IS A ROW BEING FILLED IN. The client keeps it on
    # screen from the moment it is added until a value is picked, so the call
    # has to tolerate the gap rather than the control disappearing.
    #
    # A SPEC IS THE EXCEPTION AND ALWAYS WILL BE: `seas(x, x11 = list())`
    # names a spec, and naming it IS the whole argument, so its row is empty
    # by design rather than unfinished.
    if (!identical(entry$type, "spec")) {
      if (!length(unlist(value))) next
      if (is.character(value) && length(value) == 1L && !nzchar(value)) next
    }
    if (!is.null(entry)) {
      coerced <- switch(entry$type,
        spec = quote(list()),
        enum = as.character(value),
        `multi-enum` = {
          vals <- as.character(unlist(value))
          if (length(vals) == 0L) next
          # One value is a string, not `c("td")`. The block shows this call,
          # and a `c()` around a single element is noise in it.
          if (length(vals) == 1L) vals else as.call(c(quote(c), vals))
        },
        numeric = {
          n <- suppressWarnings(as.numeric(value))
          if (is.na(n)) next
          n
        },
        text = as.character(value),
        as.character(value)
      )
    } else {
      # Unknown argument -- pass value as string
      coerced <- as.character(value)
    }
    out[[name]] <- coerced
  }

  out
}

#' Build a `seasonal::seas()` expression from the argument rows
#'
#' @param args List of argument objects from JS, each with `name` and `value`.
#' @param has_xreg Logical, whether xreg input is connected.
#' @param has_xtrans Logical, whether xtrans input is connected.
#' @param arg_names Named character vector mapping "x", "xreg" and "xtrans"
#'   onto the symbols the variadic inputs are bound to.
#' @return A language object wrapping a `seasonal::seas()` call.
#' @noRd
make_seas_expr <- function(args, has_xreg = FALSE, has_xtrans = FALSE,
                           arg_names = c(x = ".arg1")) {
  # Build the seas() call: seasonal::seas(x, ...)
  # arg_names maps semantic names ("x", "xreg", "xtrans") to the symbols
  # blockr.core binds the variadic inputs to (".arg1", ".arg2", ".arg3" for
  # unnamed links)
  # NO local() WRAPPER. It used to bind `x <- tsbox::ts_ts(.arg1)` and then
  # call `seas(x = x)`, which is four lines and an indent for a variable used
  # exactly once. The conversion goes where it is used, and the expression is
  # one call -- which matters because the block shows it.
  x_sym <- as.name(arg_names[["x"]])
  call_args <- list(
    str2lang("seasonal::seas"),
    x = as.call(list(str2lang("tsbox::ts_ts"), call(".", x_sym)))
  )

  if (has_xreg && "xreg" %in% names(arg_names)) {
    call_args[["xreg"]] <- call(".", as.name(arg_names[["xreg"]]))
  }
  if (has_xtrans && "xtrans" %in% names(arg_names)) {
    call_args[["xtrans"]] <- call(".", as.name(arg_names[["xtrans"]]))
  }

  call_args <- c(call_args, seas_call_args(args))

  as.call(call_args)
}

#' The expression, as the block shows it
#'
#' The strip under the arguments prints what the block hands to core, not a
#' tidied `seas()` call: a display that can disagree with what runs is the one
#' thing the block must not have.
#'
#' ONE ARGUMENT PER LINE, always, rather than whatever width `deparse()`
#' happens to wrap at. The call is a list of choices and reads as one; a
#' wrapped line puts two of them on a row and breaks the third in the middle,
#' and the shape changes every time an argument is added. This is also how
#' seasonal.website prints it.
#'
#' The only edit to the call itself is `.(.arg1)` to `.arg1` -- `.()` is
#' blockr's substitution marker rather than part of the call, and `.arg1` is
#' the symbol core binds the input to.
#'
#' @param expr The block's expression.
#' @return A single string, one argument per line.
#' @noRd
seas_expr_text <- function(expr) {
  if (is.null(expr) || !is.call(expr)) {
    return("")
  }

  fn <- paste(deparse(expr[[1L]]), collapse = "")
  args <- as.list(expr)[-1L]

  if (!length(args)) {
    return(paste0(fn, "()"))
  }

  nms <- names(args)
  if (is.null(nms)) nms <- rep("", length(args))

  parts <- vapply(seq_along(args), function(i) {
    val <- paste(deparse(args[[i]]), collapse = " ")
    if (nzchar(nms[[i]])) paste0(nms[[i]], " = ", val) else val
  }, character(1))

  txt <- paste0(fn, "(\n  ", paste(parts, collapse = ",\n  "), "\n)")
  gsub("\\.\\((\\.arg[0-9]+)\\)", "\\1", txt)
}
