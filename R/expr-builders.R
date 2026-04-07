#' Expression builders for the seas argument builder
#'
#' @name seas-expr-builders
#' @keywords internal
NULL

#' Build a seasonal::seas() expression from argument list
#'
#' @param args List of argument objects from JS, each with `name` and `value`.
#' @param has_xreg Logical, whether xreg input is connected.
#' @param has_xtrans Logical, whether xtrans input is connected.
#' @return A language object wrapping a seasonal::seas() call.
#' @noRd
make_seas_expr <- function(args, has_xreg = FALSE, has_xtrans = FALSE) {
  catalog <- get_x13_catalog()

  # Build the seas() call: seasonal::seas(x, ...)
  call_args <- list(
    str2lang("seasonal::seas"),
    x = quote(.(x))
  )

  if (has_xreg) call_args[["xreg"]] <- quote(.(xreg))
  if (has_xtrans) call_args[["xtrans"]] <- quote(.(xtrans))

  # Add each user argument with type coercion
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
      # Unknown argument — pass value as string
      coerced <- as.character(value)
    }
    call_args[[name]] <- coerced
  }

  seas_call <- as.call(call_args)

  # Wrap in local() with ts conversion
  blockr.core::bbquote(
    local({
      x <- tsbox::ts_ts(.(x))
      .(seas_call)
    }),
    list(seas_call = seas_call)
  )
}
