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
    if (!is.null(entry)) {
      coerced <- switch(entry$type,
        spec = quote(list()),
        enum = as.character(value),
        `multi-enum` = {
          vals <- as.character(unlist(value))
          if (length(vals) == 0L) next
          as.call(c(quote(c), vals))
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
  x_sym <- as.name(arg_names[["x"]])
  # seas(x = x) — use the local variable created by x <- tsbox::ts_ts(...)
  call_args <- list(
    str2lang("seasonal::seas"),
    x = quote(x)
  )

  if (has_xreg && "xreg" %in% names(arg_names)) {
    call_args[["xreg"]] <- call(".", as.name(arg_names[["xreg"]]))
  }
  if (has_xtrans && "xtrans" %in% names(arg_names)) {
    call_args[["xtrans"]] <- call(".", as.name(arg_names[["xtrans"]]))
  }

  call_args <- c(call_args, seas_call_args(args))

  seas_call <- as.call(call_args)

  # Wrap in local() with ts conversion
  x_dot <- call(".", x_sym)
  blockr.core::bbquote(
    local({
      x <- tsbox::ts_ts(.(x_ref))
      .(seas_call)
    }),
    list(seas_call = seas_call, x_ref = x_dot)
  )
}
