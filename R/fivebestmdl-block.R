#' Five Best Models Block
#'
#' Displays the five best ARIMA models considered during seasonal adjustment.
#' Shows model specifications and their AICc values.
#'
#' @param ... Additional arguments passed to new_transform_block
#'
#' @export
new_fivebestmdl_block <- function(...) {
  blockr.core::new_transform_block(
    function(id, data) {
      moduleServer(
        id,
        function(input, output, session) {

          list(
            expr = reactive({
              # Expression to get five best models as data frame
              expr_text <- "as.data.frame(seasonal::fivebestmdl(data))"
              parse(text = expr_text)[[1]]
            }),
            # Return the fivebestmdl output as data frame
            result = reactive({
              req(data())

              tryCatch(
                {
                  model <- data()

                  # Check if input is a seas model
                  if (!inherits(model, "seas")) {
                    stop("Input must be a seas model object")
                  }

                  # Get five best models as data frame using built-in method
                  as.data.frame(seasonal::fivebestmdl(model))
                },
                error = function(e) {
                  showNotification(
                    paste("Five best models error:", e$message),
                    type = "error"
                  )
                  NULL
                }
              )
            }),
            state = list()
          )
        }
      )
    },
    class = "fivebestmdl_block",
    ...
  )
}
