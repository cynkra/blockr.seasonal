#' Generate static seasonal adjustment code
#'
#' Takes a seas() call and data, evaluates it, and returns the static version
#' that includes all automatically detected parameters.
#'
#' @param seas_call String containing the seas() call
#' @param x Time series data
#' @param xreg Optional external regressors
#' @param xtrans Optional transformation variables
#' @return Character string with the static seas() call
#' @noRd
generate_static_seas_call <- function(seas_call, x, xreg = NULL, xtrans = NULL) {
  tryCatch({
    # Convert inputs to time series if needed
    x_ts <- tsbox::ts_ts(x)

    # Prepare optional inputs if provided
    if (!is.null(xreg)) {
      xreg_ts <- tsbox::ts_ts(xreg)
    }
    if (!is.null(xtrans)) {
      xtrans_ts <- tsbox::ts_ts(xtrans)
    }

    # Parse and evaluate the seas call
    # Auto-prefix seas with seasonal:: if not already present
    if (!grepl("seasonal::", seas_call)) {
      seas_call <- gsub("seas\\(", "seasonal::seas(", seas_call)
    }

    # Create a temporary environment with the data
    env <- new.env(parent = globalenv())
    env$x <- x_ts
    if (!is.null(xreg)) env$xreg <- xreg_ts
    if (!is.null(xtrans)) env$xtrans <- xtrans_ts

    # Parse and evaluate the seas() call
    expr <- parse(text = seas_call)[[1]]
    model <- eval(expr, envir = env)

    # Get the static specification
    static_output <- capture.output(print(seasonal::static(model)))

    # Combine all lines into one string
    static_string <- paste(static_output, collapse = " ")

    # Clean up the string - remove extra spaces
    static_string <- gsub("\\s+", " ", static_string)
    static_string <- trimws(static_string)

    # Ensure it starts with seas( and not seasonal::seas(
    # (for consistency with user expectations)
    static_string <- gsub("^seasonal::seas\\(", "seas(", static_string)

    # Format the static call nicely
    formatted_static <- format_seas_call(static_string)

    return(formatted_static)

  }, error = function(e) {
    # Return error message that can be shown to user
    stop(paste("Error generating static specification:", e$message))
  })
}