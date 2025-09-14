#' Get seas() function categories for autocompletion
#' @noRd
get_seas_categories <- function() {
  list(
    # Most common complete patterns - ready to use
    common_patterns = c(
      'x11 = list()',
      'seats = list()',
      'transform.function = "log"',
      'transform.function = "auto"',
      'regression.variables = c("td")',
      'regression.variables = c("td", "easter[8]")',
      'regression.variables = c("td", "easter[8]", "outlier")',
      'regression.aictest = c("td", "easter")',
      'arima.model = "(0 1 1)(0 1 1)"',
      'arima.model = "(0 1 1)(0 1 1)12"',
      'outlier.types = c("ao", "ls", "tc")',
      'outlier.types = c("ao", "ls")',
      'outlier.critical = 3',
      'outlier.critical = 3.5',
      'outlier.critical = 4',
      'forecast.maxlead = 12',
      'forecast.maxlead = 24',
      'forecast.maxback = 12',
      'x11.seasonalma = "s3x9"',
      'x11.seasonalma = "msr"',
      'x11.trendma = 13',
      'x11.trendma = 23',
      'x11.mode = "mult"',
      'x11.mode = "add"',
      'x11.mode = "pseudoadd"',
      'x11.mode = "logadd"',
      'check.maxlag = 24',
      'estimate.tol = 1e-5',
      'transform.power = 0',
      'transform.power = 0.5',
      'transform.adjust = "lom"',
      'transform.adjust = "lpyear"'
    ),

    # Main specs (most commonly used)
    main_specs = c(
      "x11", "seats", "transform.function", "regression.variables",
      "regression.aictest", "outlier", "outlier.types", "outlier.critical",
      "arima.model", "forecast.maxlead", "forecast.maxback", "automdl", "check"
    ),

    # Transform spec arguments
    transform_spec = c(
      "transform.function", "transform.power", "transform.adjust",
      "transform.aicdiff", "transform.mode", "transform.data",
      "transform.file", "transform.format", "transform.name",
      "transform.precision", "transform.start", "transform.title",
      "transform.type", "transform.print", "transform.save"
    ),

    # Regression spec arguments
    regression_spec = c(
      "regression.variables", "regression.aictest", "regression.aicdiff",
      "regression.user", "regression.usertype", "regression.data",
      "regression.file", "regression.format", "regression.start",
      "regression.chi2test", "regression.chi2testcv", "regression.tlimit",
      "regression.print", "regression.save", "regression.savelog"
    ),

    # X11 spec arguments
    x11_spec = c(
      "x11.mode", "x11.seasonalma", "x11.trendma", "x11.sigmalim",
      "x11.appendfcst", "x11.appendbcst", "x11.final", "x11.title",
      "x11.print", "x11.save", "x11.savelog", "x11.calendarsigma",
      "x11.excludefcst", "x11.type", "x11.sfshort"
    ),

    # SEATS spec arguments
    seats_spec = c(
      "seats.noadmiss", "seats.appendfcst", "seats.appendbcst",
      "seats.finite", "seats.hpcycle", "seats.qmax", "seats.rmod",
      "seats.out", "seats.print", "seats.save", "seats.savelog",
      "seats.statseas", "seats.tabtables", "seats.bias"
    ),

    # ARIMA spec arguments
    arima_spec = c(
      "arima.model", "arima.ar", "arima.ma", "arima.title"
    ),

    # Transform values (with quotes for strings)
    transform_values = c(
      '"log"', '"auto"', '"none"', '"sqrt"', '"inverse"', '"logistic"'
    ),

    # ARIMA model examples (common specifications)
    arima_examples = c(
      '"(0 1 1)(0 1 1)"', '"(0 1 1)(0 1 1)12"', '"(1 1 0)(0 1 1)"',
      '"(0 1 2)(0 1 1)"', '"(2 1 0)(0 1 1)"', '"(1 1 1)(0 1 1)"',
      '"(0 1 1)(0 1 1)4"', '"(1 0 0)(0 1 1)"', '"(0 1 1)(1 0 0)"',
      '"(0 1 1)"', '"(1 0 1)"', '"(2 1 2)"'
    ),

    # Regression variables (predefined, from Census documentation)
    regression_vars = c(
      '"const"', '"seasonal"', '"sincos"',
      '"td"', '"tdnolpyear"', '"tdstock"', '"td1coef"', '"td1nolpyear"', '"tdstock1coef"',
      '"lom"', '"loq"', '"lpyear"',
      '"easter[1]"', '"easter[8]"', '"easter[15]"',
      '"sceaster[1]"', '"sceaster[8]"',
      '"easterstock[1]"', '"easterstock[8]"',
      '"labor[1]"', '"labor[8]"', '"labor[15]"',
      '"thank[1]"', '"thank[8]"',
      '"ao"', '"ls"', '"tc"', '"so"', '"rp"', '"tl"',
      '"outlier"'
    ),

    # Outlier type values (quoted)
    outlier_values = c(
      '"ao"', '"ls"', '"tc"', '"so"', '"rp"', '"tl"', '"all"'
    ),

    # X11 seasonal moving average options
    x11_seasonalma_values = c(
      '"s3x3"', '"s3x5"', '"s3x9"', '"s3x15"', '"msr"', '"stable"',
      '"x11default"', '"s3x1"', '"s3x3x3"', '"s3x3x5"', '"s3x3x9"'
    ),

    # Outlier critical values (common thresholds)
    outlier_critical_values = c(
      '3', '3.5', '4', '4.5', '5', '2.5', '2.8', '3.2', '3.8'
    ),

    # Automdl maxorder values
    automdl_maxorder_values = c(
      '(2 1)', '(3 1)', '(4 1)', '(2 2)', '(3 2)', '(4 2)'
    ),

    # Automdl maxdiff values
    automdl_maxdiff_values = c(
      '(1 0)', '(1 1)', '(2 0)', '(2 1)'
    ),

    # Check qtype values
    check_qtype_values = c(
      '"ljungbox"', '"boxpierce"'
    ),

    # Estimate exact values
    estimate_exact_values = c(
      '"arma"', '"ma"', '"none"', '"all"'
    ),

    # History estimates values
    history_estimates_values = c(
      '"fcst"', '"concurrent"', '"trend"', '"seasonal"', '"sadjchng"',
      '"trendchng"', '"seasadj"', '"aic"', '"sadj"', '"ratio"'
    ),

    # Spectrum series values
    spectrum_series_values = c(
      '"original"', '"seasonaladj"', '"irregular"', '"residual"',
      '"regresidual"', '"irreg"', '"res"', '"rsd"'
    ),

    # Series period values
    series_period_values = c(
      '1', '2', '4', '12', '52'
    ),

    # Common numeric values
    numeric_values = c(
      '0', '0.5', '1', '2', '3', '3.5', '4', '4.5', '5', '6', '7', '8',
      '9', '10', '11', '12', '13', '15', '20', '23', '24',
      '36', '48', '60', '120'
    ),

    # Boolean values
    boolean_values = c(
      'TRUE', 'FALSE', 'T', 'F'
    ),

    # Helper functions
    helper_functions = c(
      'list()', 'c()'
    ),

    # X11 mode options
    x11_mode_values = c(
      '"mult"', '"add"', '"pseudoadd"', '"logadd"'
    ),

    # Automdl spec arguments
    automdl_spec = c(
      "automdl.maxorder", "automdl.maxdiff", "automdl.diff",
      "automdl.acceptdefault", "automdl.checkmu", "automdl.ljungboxlimit",
      "automdl.mixed", "automdl.balanced", "automdl.exactdiff",
      "automdl.fcstlim", "automdl.hrinitial", "automdl.reducecv",
      "automdl.rejectfcst", "automdl.urfinal", "automdl.armalimit",
      "automdl.print", "automdl.savelog"
    ),

    # Outlier spec arguments
    outlier_spec = c(
      "outlier.types", "outlier.critical", "outlier.span", "outlier.method",
      "outlier.lsrun", "outlier.print", "outlier.save", "outlier.savelog",
      "outlier.tcrate"
    ),

    # Forecast spec arguments
    forecast_spec = c(
      "forecast.maxlead", "forecast.maxback", "forecast.probability",
      "forecast.exclude", "forecast.print", "forecast.save"
    ),

    # Check spec arguments
    check_spec = c(
      "check.maxlag", "check.print", "check.save", "check.qtype",
      "check.acflimit", "check.qlimit", "check.savelog"
    ),

    # Estimate spec arguments
    estimate_spec = c(
      "estimate.tol", "estimate.maxiter", "estimate.exact",
      "estimate.outofsample", "estimate.print", "estimate.save",
      "estimate.savelog", "estimate.file"
    ),

    # Series spec arguments
    series_spec = c(
      "series.data", "series.file", "series.format", "series.period",
      "series.start", "series.span", "series.title", "series.name",
      "series.decimals", "series.modelspan", "series.comptype",
      "series.compwt", "series.appendbcst", "series.appendfcst",
      "series.type", "series.divpower", "series.missingcode",
      "series.missingval", "series.save", "series.print", "series.savelog"
    ),

    # History spec arguments
    history_spec = c(
      "history.estimates", "history.fixmdl", "history.fixreg",
      "history.outlier", "history.sadjlags", "history.trendlags",
      "history.start", "history.target", "history.fixx11reg",
      "history.print", "history.save", "history.savelog"
    ),

    # Slidingspans spec arguments
    slidingspans_spec = c(
      "slidingspans.fixmdl", "slidingspans.fixreg", "slidingspans.length",
      "slidingspans.numspans", "slidingspans.outlier", "slidingspans.start",
      "slidingspans.additivesa", "slidingspans.cutat", "slidingspans.cutchng",
      "slidingspans.cuttd", "slidingspans.print", "slidingspans.save",
      "slidingspans.savelog"
    ),

    # Spectrum spec arguments
    spectrum_spec = c(
      "spectrum.start", "spectrum.print", "spectrum.save", "spectrum.savelog",
      "spectrum.series", "spectrum.type", "spectrum.qcheck",
      "spectrum.logqs", "spectrum.tukey.m"
    ),

    # Force spec arguments
    force_spec = c(
      "force.start", "force.round", "force.lambda", "force.mode",
      "force.type", "force.target", "force.usefcst", "force.print",
      "force.save"
    ),

    # Identify spec arguments
    identify_spec = c(
      "identify.diff", "identify.sdiff", "identify.maxlag",
      "identify.print", "identify.save"
    ),

    # Pickmdl spec arguments
    pickmdl_spec = c(
      "pickmdl.mode", "pickmdl.method", "pickmdl.fcstlim",
      "pickmdl.qlim", "pickmdl.bcstlim", "pickmdl.identify",
      "pickmdl.outofsample", "pickmdl.print", "pickmdl.savelog",
      "pickmdl.file"
    ),

    # Composite spec arguments
    composite_spec = c(
      "composite.title", "composite.decimals", "composite.modelspan",
      "composite.type", "composite.name", "composite.appendbcst",
      "composite.appendfcst", "composite.print", "composite.save",
      "composite.savelog"
    ),

    # Metadata spec arguments
    metadata_spec = c(
      "metadata.keys", "metadata.values"
    ),

    # X11regression spec arguments
    x11regression_spec = c(
      "x11regression.variables", "x11regression.user", "x11regression.usertype",
      "x11regression.data", "x11regression.file", "x11regression.format",
      "x11regression.start", "x11regression.span", "x11regression.aictest",
      "x11regression.prior", "x11regression.b", "x11regression.centeruser",
      "x11regression.eastermeans", "x11regression.noapply", "x11regression.print",
      "x11regression.save", "x11regression.savelog", "x11regression.sigma",
      "x11regression.forcecal", "x11regression.critical", "x11regression.outlierspan",
      "x11regression.outliermethod", "x11regression.reweight", "x11regression.tdprior",
      "x11regression.umfile"
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
              // Common patterns - highest priority
              meta = "pattern";
              score = 1500;
            } else if (category === "main_specs") {
              // Main specs - high priority, add " = " suffix
              value = item + " = ";
              meta = "main spec";
              score = 1400;
            } else if (category.endsWith("_spec")) {
              // Specification parameters - add " = " suffix
              value = item + " = ";
              meta = category.replace("_spec", "");
              score = 1200;
            } else if (category.endsWith("_values") || category.endsWith("_examples") ||
                       category.endsWith("_vars")) {
              // Values are already quoted in the list
              meta = "value";
              score = 1000;
            } else if (category === "helper_functions") {
              meta = "function";
              score = 1100;
            } else if (category === "numeric_values") {
              meta = "number";
              score = 900;
            } else if (category === "boolean_values") {
              meta = "boolean";
              score = 900;
            } else {
              // Default handling
              meta = "option";
              score = 800;
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
          // Add keyboard shortcut for submit (Ctrl/Cmd+Enter)
          editor.commands.addCommand({
            name: "submitSeasCall",
            bindKey: {win: "Ctrl-Enter", mac: "Command-Enter"},
            exec: function(editor) {
              // Find and click the submit button
              var submitBtn = document.querySelector("#" + "%s".replace("seas_call", "submit"));
              if (submitBtn) {
                submitBtn.click();
              }
            }
          });

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
    id,  # Line 413: getElementById for editor
    id,  # Line 424: ID for submit button (seas_call -> submit)
    id,  # Line 443: container ID for resizing
    id   # Line 473: getElementById for autocomplete setup
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