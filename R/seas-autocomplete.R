#' Get seas() function categories for autocompletion
#' @noRd
get_seas_categories <- function() {
  list(
    # Main seas() parameters
    main_params = c(
      "x", "xreg", "xtrans", "seats.noadmiss", "transform.function",
      "regression.aictest", "outlier", "automdl", "composite",
      "na.action", "out", "dir", "multimode"
    ),

    # X-11 specifications
    x11 = c(
      "x11", "x11.mode", "x11.seasonalma", "x11.trendma", "x11.sigmalim",
      "x11.appendfcst", "x11.appendbcst", "x11.calendarsigma", "x11.sigmaiter",
      "x11.final", "x11.title", "x11.type"
    ),

    # SEATS specifications
    seats = c(
      "seats", "seats.appendfcst", "seats.appendbcst", "seats.finite",
      "seats.hpcycle", "seats.noadmiss", "seats.out", "seats.qmax",
      "seats.rmod", "seats.statsea", "seats.tabtables", "seats.save"
    ),

    # Transform specifications
    transform = c(
      "transform.function", "transform.power", "transform.adjust",
      "transform.aicdiff", "transform.type", "transform.units"
    ),

    # Regression specifications
    regression = c(
      "regression.variables", "regression.aictest", "regression.user",
      "regression.usertype", "regression.critical", "regression.span",
      "regression.tcrate", "regression.tlimit"
    ),

    # ARIMA specifications
    arima = c(
      "arima.model", "arima.ar", "arima.ma", "arima.diff",
      "arima.sdiff", "arima.title"
    ),

    # Automdl specifications
    automdl = c(
      "automdl", "automdl.maxorder", "automdl.maxdiff", "automdl.diff",
      "automdl.ljungboxlimit", "automdl.reduce", "automdl.acceptdefault"
    ),

    # Outlier specifications
    outlier = c(
      "outlier", "outlier.types", "outlier.critical", "outlier.span",
      "outlier.method", "outlier.tcrate"
    ),

    # Common function values
    transform_functions = c("auto", "none", "log"),
    modes = c("mult", "add", "logadd", "pseudoadd"),
    outlier_types = c("AO", "LS", "TC", "SO"),
    regression_variables = c("td", "easter", "const", "seasonal"),
    boolean_values = c("yes", "no"),

    # Common seasonal patterns
    seasonal_patterns = c(
      "seasonal", "trend", "irregular", "sa", "sf", "final",
      "forecasts", "backcasts", "residuals"
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
          categories[category].forEach(function(fn) {
            var meta = category;
            var value = fn;
            var caption = fn;
            var score = 1000;

            // Special handling for different types
            if (category === "main_params") {
              value = fn + " = ";
              meta = "parameter";
              score = 1100;
            } else if (category.endsWith("_functions") || category.endsWith("_values") ||
                      category === "boolean_values" || category === "modes" ||
                      category === "outlier_types" || category === "regression_variables") {
              value = "\\"" + fn + "\\"";
              meta = "value";
              score = 900;
            } else if (category === "seasonal_patterns") {
              meta = "pattern";
              score = 950;
            } else {
              // Spec.argument parameters
              value = fn + " = ";
              meta = "spec";
              score = 1050;
            }

            wordList.push({
              caption: caption,
              value: value,
              meta: meta,
              score: score
            });
          });
        });

        // Add common seas() examples
        var examples = [
          {
            caption: "seas(x = x, x11 = list())",
            value: "seas(x = x, x11 = list())",
            meta: "example",
            score: 1200
          },
          {
            caption: "seas(x = x, seats = list())",
            value: "seas(x = x, seats = list())",
            meta: "example",
            score: 1200
          },
          {
            caption: "transform.power = 0",
            value: "transform.power = 0",
            meta: "example",
            score: 1150
          },
          {
            caption: "list()",
            value: "list()",
            meta: "function",
            score: 1000
          }
        ];

        wordList = wordList.concat(examples);

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
    # CSS for resizable editor
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