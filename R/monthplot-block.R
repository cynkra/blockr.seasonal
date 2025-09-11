#' Monthplot Block
#'
#' Displays seasonal patterns by month using the monthplot function.
#' Shows the seasonal subseries for each month across years.
#'
#' @param component Which component to plot ("final", "seasonal", "trend", "irregular")
#' @param ... Additional arguments passed to new_plot_block
#'
#' @export
new_monthplot_block <- function(
  component = "seasonal",
  ...
) {
  blockr.core::new_plot_block(
    function(id) {
      moduleServer(
        id,
        function(input, output, session) {
          # Initialize reactive values
          r_component <- reactiveVal(component)
          
          # Input observers
          observeEvent(input$component, {
            r_component(input$component)
          })
          
          list(
            expr = reactive({
              # Build monthplot expression
              comp <- r_component()
              expr_text <- glue::glue(
                "seasonal::monthplot(seasonal::{comp}(data))"
              )
              parse(text = expr_text)[[1]]
            }),
            # Generate the monthplot
            result = reactive({
              req(input_data())
              
              tryCatch({
                model <- input_data()
                
                # Check if input is a seas model
                if (!inherits(model, "seas")) {
                  stop("Input must be a seas model object")
                }
                
                # Extract the specified component
                comp <- r_component()
                series <- switch(
                  comp,
                  "final" = seasonal::final(model),
                  "seasonal" = seasonal::seasonal(model),
                  "trend" = seasonal::trend(model),
                  "irregular" = seasonal::irregular(model),
                  seasonal::seasonal(model)  # default
                )
                
                # Create the monthplot
                # Return the series for plotting
                series
              }, error = function(e) {
                showNotification(
                  paste("Monthplot error:", e$message),
                  type = "error"
                )
                NULL
              })
            }),
            # Custom plot function for monthplot
            plot_expr = reactive({
              comp <- r_component()
              expr_text <- glue::glue(
                "graphics::monthplot(data, main = '{comp} component by month', ylab = '{comp}')"
              )
              parse(text = expr_text)[[1]]
            }),
            state = list(
              component = r_component
            )
          )
        }
      )
    },
    function(id) {
      tagList(
        div(
          class = "monthplot-block-container",
          
          tags$style(HTML(
            "
            .monthplot-block-container {
              padding: 10px;
            }
            .monthplot-section {
              margin-bottom: 15px;
            }
            .monthplot-section label {
              font-weight: bold;
              color: #495057;
              font-size: 14px;
            }
            "
          )),
          
          div(
            class = "monthplot-section",
            selectInput(
              NS(id, "component"),
              label = "Component to Display",
              choices = c(
                "Seasonal" = "seasonal",
                "Final (Adjusted)" = "final", 
                "Trend" = "trend",
                "Irregular" = "irregular"
              ),
              selected = component,
              width = "100%"
            )
          ),
          
          helpText(
            "Displays seasonal patterns by month. ",
            "Each line represents a different year, showing how the selected component varies across months."
          )
        )
      )
    },
    class = "monthplot_block",
    allow_empty_state = character(0),
    ...
  )
}