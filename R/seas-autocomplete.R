#' Get seas() function categories for autocompletion
#' @noRd
get_seas_categories <- function() {
  list(
    # Common parameter combinations
    common_patterns = c(
      'x11 = list()',
      'seats = list()',
      'transform.function = "log"',
      'transform.function = "auto"',
      'transform.power = 0',
      'regression.variables = c("td")',
      'regression.variables = c("td", "easter[8]")',
      'regression.aictest = c("td", "easter")',
      'arima.model = "(0 1 1)(0 1 1)"',
      'arima.model = c(0, 1, 1, 0, 1, 1)',
      'outlier.types = c("ao", "ls")',
      'outlier.types = c("ao", "ls", "tc")',
      'forecast.maxlead = 12',
      'forecast.maxlead = 24',
      'x11.seasonalma = "S3X9"',
      'x11.trendma = 23'
    ),

    # Main parameters (most common)
    main_params = c(
      "x", "xreg", "transform.function", "regression.variables",
      "regression.aictest", "outlier", "outlier.types", "arima.model",
      "x11", "seats", "forecast.maxlead", "na.action"
    ),

    # X-11 specifications
    x11_spec = c(
      "x11.mode", "x11.seasonalma", "x11.trendma", "x11.sigmalim",
      "x11.appendfcst", "x11.appendbcst", "x11.calendarsigma",
      "x11.final", "x11.type"
    ),

    # SEATS specifications
    seats_spec = c(
      "seats.noadmiss", "seats.appendfcst", "seats.appendbcst",
      "seats.finite", "seats.hpcycle", "seats.qmax", "seats.rmod"
    ),

    # Transform values (with quotes for strings)
    transform_values = c(
      '"log"', '"auto"', '"none"', '"sqrt"', '"inverse"', '"logistic"'
    ),

    # ARIMA model examples (common specifications)
    arima_examples = c(
      '"(0 1 1)(0 1 1)"', '"(1 1 0)(0 1 1)"', '"(0 1 2)(0 1 1)"',
      '"(2 1 0)(0 1 1)"', '"(1 1 1)(0 1 1)"', '"(0 1 1)(0 1 1)12"'
    ),

    # Regression variables (from Census documentation)
    regression_vars = c(
      '"td"', '"easter[1]"', '"easter[8]"', '"easter[15]"',
      '"tdnolpyear"', '"tl"', '"ao"', '"ls"', '"tc"',
      '"seasonal"', '"const"', '"lom"', '"loq"', '"lpyear"',
      '"thank"', '"labor"', '"sceaster"', '"easterstock"'
    ),

    # Outlier types (with quotes)
    outlier_values = c(
      '"ao"', '"ls"', '"tc"', '"so"', '"rp"', '"tl"'
    ),

    # X11 seasonal moving average options
    x11_seasonalma_values = c(
      '"S3X3"', '"S3X5"', '"S3X9"', '"S3X15"', '"Msr"', '"Stable"'
    ),

    # X11 mode options
    x11_mode_values = c(
      '"mult"', '"add"', '"pseudoadd"', '"logadd"'
    ),

    # Automdl parameters
    automdl_spec = c(
      "automdl", "automdl.maxorder", "automdl.maxdiff",
      "automdl.ljungboxlimit", "automdl.reduce", "automdl.acceptdefault"
    ),

    # Forecast parameters
    forecast_spec = c(
      "forecast.maxback", "forecast.probability", "forecast.save"
    ),

    # Check parameters
    check_spec = c(
      "check.maxlag", "check.print", "check.qtype", "check.save"
    )
  )
}

#' Setup Ace editor for seas() function with custom completer
#'
#' @param id The editor ID
#' @param value Initial value (default: "")
#' @param height Editor height (default: "200px")
#' @return A tagList containing the editor setup
#' @noRd
setup_seas_ace_editor <- function(id, value = "", height = "200px") {
  # Custom completer script for seas()
  custom_completer <- sprintf(
    '
    // Define the seas completer
    var seasCompleter = {
      getCompletions: function(editor, session, pos, prefix, callback) {
        // Categories will be updated dynamically from the server
        var categories = window.seasCategories || %s;

        var wordList = [];

        // Process each category
        Object.keys(categories).forEach(function(category) {
          categories[category].forEach(function(item) {
            var meta = category.replace(/_/g, " ");
            var value = item;
            var caption = item;
            var score = 1000;

            // Special handling for different categories
            if (category === "common_patterns") {
              // Common patterns - high priority
              meta = "pattern";
              score = 1400;
            } else if (category === "main_params") {
              // Main parameters - add " = " suffix
              value = item + " = ";
              meta = "parameter";
              score = 1300;
            } else if (category.endsWith("_spec")) {
              // Specification parameters - add " = " suffix
              value = item + " = ";
              meta = category.replace("_spec", "");
              score = 1100;
            } else if (category.endsWith("_values") || category.endsWith("_examples") ||
                       category.endsWith("_vars")) {
              // Values are already quoted in the list
              meta = "value";
              score = 1000;
            } else {
              // Default handling
              meta = "option";
              score = 900;
            }

            wordList.push({
              caption: caption,
              value: value,
              meta: meta,
              score: score
            });
          });
        });

        // Add helper functions
        wordList.push({
          caption: "list()",
          value: "list()",
          meta: "function",
          score: 1200
        });

        wordList.push({
          caption: "c()",
          value: "c()",
          meta: "function",
          score: 1200
        });

        // Sort by score (examples first, parameters, specs, values, patterns)
        wordList.sort(function(a, b) {
          if (a.score !== b.score) return b.score - a.score;
          if (a.meta === b.meta) return a.caption.localeCompare(b.caption);
          return a.meta.localeCompare(b.meta);
        });

        callback(null, wordList);
      }
    };

    // Function to update categories from server
    window.updateSeasCategories = function(newCategories) {
      window.seasCategories = newCategories;
    };

    // Add custom key handler for parentheses positioning and resizing
    document.addEventListener("DOMContentLoaded", function() {
      setTimeout(function() {
        var editorEl = document.getElementById("%s");
        if (!editorEl) return;

        var editor = ace.edit(editorEl);
        if (editor) {
          // Position cursor inside list() parentheses
          editor.commands.on("afterExec", function(e) {
            if (e.command.name === "insertstring" || e.command.name === "Return") {
              var pos = editor.getCursorPosition();
              var line = editor.session.getLine(pos.row);
              if (line.substring(pos.column - 6, pos.column) === "list()") {
                editor.moveCursorTo(pos.row, pos.column - 1);
              }
            }
          });

          // Set up resizing
          var container = document.getElementById("%s_container");
          if (container) {
            var startY, startHeight;
            var resizer = container.querySelector(".seas-ace-resizer");

            if (resizer) {
              resizer.addEventListener("mousedown", initResize);
            }

            function initResize(e) {
              startY = e.clientY;
              startHeight = parseInt(document.defaultView.getComputedStyle(container).height, 10);
              document.documentElement.addEventListener("mousemove", doResize);
              document.documentElement.addEventListener("mouseup", stopResize);
            }

            function doResize(e) {
              var height = startHeight + e.clientY - startY;
              height = Math.max(100, Math.min(600, height));
              container.style.height = height + "px";
              editor.resize();
            }

            function stopResize() {
              document.documentElement.removeEventListener("mousemove", doResize);
              document.documentElement.removeEventListener("mouseup", stopResize);
            }
          }
        }
      }, 100);
    });

    // Add completer when ACE is ready - simple pattern from blockr.dplyr
    (function addSeasCompleter(){
      if (typeof ace === "undefined") {
        setTimeout(addSeasCompleter, 100);
        return;
      }
      try {
        ace.require("ace/ext/language_tools").addCompleter(seasCompleter);

        // Enable autocomplete for the editor
        setTimeout(function() {
          var editorEl = document.getElementById("%s");
          if (editorEl) {
            var editor = ace.edit(editorEl);
            editor.setOptions({
              enableLiveAutocompletion: true,
              enableBasicAutocompletion: true
            });
          }
        }, 100);
      } catch(e) {
        setTimeout(addSeasCompleter, 100);
      }
    })();
  ',
    jsonlite::toJSON(get_seas_categories(), auto_unbox = TRUE),
    id,  # Line 178: getElementById for editor
    id,  # Line 195: container ID for resizing
    id   # Line 238: getElementById for autocomplete setup
  )

  tagList(
    # CSS for resizable editor and wider autocomplete
    tags$style(HTML(sprintf(
      '
      .seas-ace-container {
        border: 1px solid #dee2e6;
        border-radius: 4px;
        overflow: hidden;
        resize: vertical;
        min-height: 100px;
        max-height: 600px;
        height: %s;
      }

      .seas-ace-container .ace_editor {
        height: calc(100%% - 8px) !important;
        font-size: 14px;
      }

      .seas-ace-resizer {
        height: 8px;
        background: #f8f9fa;
        cursor: ns-resize;
        border-top: 1px solid #dee2e6;
        display: flex;
        align-items: center;
        justify-content: center;
      }

      .seas-ace-resizer::after {
        content: "⋯";
        color: #6c757d;
        font-weight: bold;
      }

      /* Make autocomplete dropdown wider */
      .ace_autocomplete {
        width: 500px !important;
        max-width: 600px !important;
      }

      .ace_autocomplete .ace_line {
        white-space: nowrap !important;
        overflow: hidden !important;
        text-overflow: ellipsis !important;
      }
      ',
      height
    ))),

    # Initialize completer script - MUST be before creating the editor
    tags$script(HTML(custom_completer)),

    # Resizable container
    div(
      class = "seas-ace-container",
      id = paste0(id, "_container"),
      shinyAce::aceEditor(
        outputId = id,
        value = value,
        mode = "r",
        theme = "textmate",
        autoComplete = "live",
        autoCompleters = c("custom"),
        showPrintMargin = FALSE,
        highlightActiveLine = TRUE,
        tabSize = 2,
        fontSize = 14,
        showLineNumbers = TRUE,
        height = "100%",
        placeholder = "Enter seas() call, e.g., seas(x = x, x11 = list())"
      ),
      div(class = "seas-ace-resizer")
    )
  )
}

#' Format seas() call with one argument per line
#'
#' @param code_text String containing the seas() call
#' @return Formatted code string
#' @noRd
format_seas_call <- function(code_text) {
  if (is.null(code_text) || length(code_text) == 0 || trimws(code_text) == "") {
    return(code_text %||% "")
  }

  tryCatch({
    # Clean the input
    code_text <- trimws(as.character(code_text))

    # Basic formatting for seas() calls (also handle seasonal::seas)
    if (grepl("^(seasonal::)?seas\\s*\\(", code_text)) {
      # Remove extra whitespace
      code_text <- gsub("\\s+", " ", code_text)

      # Split on commas that are not inside nested parentheses or quotes
      chars <- strsplit(code_text, "")[[1]]
      paren_level <- 0
      in_quotes <- FALSE
      quote_char <- ""
      splits <- integer(0)

      for (i in seq_along(chars)) {
        char <- chars[i]

        if (!in_quotes && (char == '"' || char == "'")) {
          in_quotes <- TRUE
          quote_char <- char
        } else if (in_quotes && char == quote_char && (i == 1 || chars[i - 1] != "\\")) {
          in_quotes <- FALSE
          quote_char <- ""
        } else if (!in_quotes) {
          if (char == "(") {
            paren_level <- paren_level + 1
          } else if (char == ")") {
            paren_level <- paren_level - 1
          } else if (char == "," && paren_level == 1) {
            # Found a top-level comma in seas()
            splits <- c(splits, i)
          }
        }
      }


      if (length(splits) > 0) {
        # Split the string at the comma positions
        parts <- character(0)
        start_pos <- 1

        for (split_pos in splits) {
          part <- substr(code_text, start_pos, split_pos - 1)
          parts <- c(parts, trimws(part))
          start_pos <- split_pos + 1
        }
        # Add the last part
        if (start_pos <= nchar(code_text)) {
          last_part <- substr(code_text, start_pos, nchar(code_text))
          parts <- c(parts, trimws(last_part))
        }


        # Reconstruct with proper formatting
        if (length(parts) > 1) {
          first_part <- parts[1]  # "seas(x = x"

          # Build list of formatted arguments (all except first)
          formatted_args <- character(0)

          # Process all arguments except the first
          for (i in 2:length(parts)) {
            part <- parts[i]
            # Check if this is the last part and has closing parenthesis
            if (i == length(parts) && grepl("\\)\\s*$", part)) {
              # Remove closing parenthesis from the argument
              arg <- trimws(gsub("\\)\\s*$", "", part))
              if (nchar(arg) > 0) {
                formatted_args <- c(formatted_args, paste0("  ", arg))
              }
            } else {
              # Regular argument
              formatted_args <- c(formatted_args, paste0("  ", trimws(part)))
            }
          }


          # Build final result
          if (grepl("\\)\\s*$", parts[length(parts)])) {
            # Has closing parenthesis
            result <- paste0(
              first_part, ",\n",
              paste(formatted_args, collapse = ",\n"),
              "\n)"
            )
          } else {
            # No closing parenthesis
            result <- paste0(
              first_part, ",\n",
              paste(formatted_args, collapse = ",\n")
            )
          }

          return(result)
        }
      }
    }

    # If no formatting needed or failed, return original
    code_text

  }, error = function(e) {
    # If formatting fails, return original
    code_text %||% ""
  })
}

#' Initialize seas-specific Ace editor in server
#'
#' This function updates the autocomplete categories dynamically from the server.
#' The actual completer is already embedded in the UI via setup_seas_ace_editor().
#'
#' @param session The Shiny session
#' @param editor_id The editor ID (not used anymore but kept for compatibility)
#' @param column_names Vector of column names (optional, for future use)
#' @noRd
initialize_seas_ace_editor <- function(session, editor_id = NULL, column_names = character(0)) {
  categories <- get_seas_categories()

  # Add column names if provided (for future extension)
  if (length(column_names) > 0) {
    categories$columns <- column_names
  }

  # Simply update the categories - the completer is already set up in the UI
  js_categories <- sprintf(
    "(function(){
      var cats = %s;
      if (typeof window.updateSeasCategories === 'function') {
        try {
          window.updateSeasCategories(cats);
          console.log('Seas categories updated');
        } catch(e) {
          window.seasCategories = cats;
          console.log('Seas categories set directly');
        }
      } else {
        window.seasCategories = cats;
        console.log('Seas categories initialized');
      }
    })();",
    jsonlite::toJSON(categories, auto_unbox = TRUE)
  )

  shinyjs::runjs(js_categories)
}