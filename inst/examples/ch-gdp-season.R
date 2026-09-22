# blockr.seasonal -- ch-gdp-season: is the Swiss economy growing, or is it
# just the season?
#
# ONE QUESTION, ONE PUBLIC SOURCE, AND A CHECK ANYONE CAN REPEAT.
#
# Swiss quarterly GDP is published twice: as it happened, and seasonally
# adjusted. The adjusted series is the one every commentary quotes, and almost
# nobody looks at how it was made. This board makes it: it takes SECO's
# unadjusted series, runs X-13ARIMA-SEATS on it in one block, and puts the
# result next to SECO's own published adjustment.
#
#   Over 186 quarters, 1980 to 2026, the two agree to a median of 0.12 percent
#   and never differ by more than 0.44. X-13 chose ARIMA (1 1 2)(0 1 1) with a
#   log transform on its own; nobody told it what to do.
#
# WHAT IS LEFT OF THE DIFFERENCE IS AN AGGREGATION CHOICE, not a disagreement
# about seasonality. SECO adjusts the ~20 components of the production account
# and adds the adjusted parts up; this board adjusts the total. Their published
# adjusted GDP equals the sum of their published adjusted components exactly,
# over all 146 quarters where every component exists, which an independently
# adjusted total would not -- adjustment is not additive. And adjusting the
# nineteen components separately here and summing them lands a median 0.078
# percent from their series against 0.194 for adjusting the total, in nominal
# terms because chain-linked volumes do not add.
#
# That is the whole argument of the board. The seasonal adjustment behind the
# headline number is not a black box, it is one block, and you can check it
# against the official figure in the same window.
#
# The data is dataseries.org, which serves Swiss official statistics as tidy
# CSV over plain https with no key and no registration:
#
#   https://dataseries.org/series.csv?dataset=ch_seco_gdp&dims=type=real;structure=gdp
#
# NOTHING IS PRELOADED. Every number on the board is fetched when it runs, and
# the document it exports downloads the same URLs when it renders.
#
# FIVE views, one series:
#
#   Data        the URL, and the four versions of GDP it hands back. The
#               picker chooses among them by shape, not by code.
#   Adjustment  the fit. The unadjusted series, X-13's model of it, the
#               adjusted series that comes out, and the season it removed.
#   Check       ours against SECO's, and the year-on-year growth rate the
#               whole exercise exists to produce.
#   Report      the document builder. What it downloads is a quarto file
#               whose chunks are ordinary R against a public URL.
#   Workflow    the outline, and the assistant beside it.
#
# Run the shipped copy:
#   source(system.file("examples/ch-gdp-season.R", package = "blockr.seasonal"))
# Run it against local source checkouts instead:
#   dev_local <- TRUE; source("blockr.seasonal/inst/examples/ch-gdp-season.R")

if (!exists("dev_local")) dev_local <- FALSE

blockr_pkgs <- c(
  "blockr.core",
  "blockr.ui",
  "blockr.dock",
  "blockr.io",       # the read block, pointed at the dataseries.org API
  "blockr.dplyr",    # the select that cuts the CSV down to a series
  "blockr.ts",       # pick, transform, combine
  "blockr.ggplot",   # the figures the report carries
  "blockr.seasonal", # seas, final, summary, monthplot
  "blockr.outline",  # the outline and the report builder
  "blockr.assistant"
)

for (pkg in blockr_pkgs) {
  if (dev_local) pkgload::load_all(file.path("/workspace", pkg), quiet = TRUE)
  else library(pkg, character.only = TRUE)
}

for (p in c("readr", "seasonal")) {
  if (!requireNamespace(p, quietly = TRUE)) {
    stop("ch-gdp-season needs the ", p, " package: install.packages('", p,
         "')", call. = FALSE)
  }
}

options(
  blockr.dock_is_locked = FALSE,
  # The time series preview: any frame tsbox can read draws as a chart, and
  # everything else keeps the app's ordinary table.
  blockr.tabular_display = blockr.ts::ts_display,
  blockr.background_construction_delay = 0,
  blockr.visible_extensions = "outline",
  blockr.gate_visibility = FALSE
)

if (dev_local) options(blockr.outline.execute = "in-process")

if (is.null(getOption("blockr.chat_function")) &&
    nzchar(Sys.getenv("OPENAI_API_KEY"))) {
  options(blockr.chat_function = list(
    openai = function(system_prompt = NULL, params = NULL) {
      ellmer::chat_openai(model = Sys.getenv("BLOCKR_LLM_MODEL", "gpt-5.1"))
    }
  ))
}


# ---- the import ------------------------------------------------------------
#
# `blockr.io::new_read_block(source = "path")` pointed straight at the API.
# The URL names its format before the query string, which `tools::file_ext()`
# could not see until blockr.io 5d3d02e; a board built a day earlier had to
# carry a hand-written data block instead.
#
# The block reads the URL directly rather than downloading it first, because
# readr's readers declare `url_ok`, so the expression the report exports is
# the API call itself.
ds_url <- function(dims, dataset = "ch_seco_gdp") {
  paste0("https://dataseries.org/series.csv?dataset=", dataset, "&dims=", dims)
}


# ---- the board -------------------------------------------------------------
board <- new_dock_board(
  blocks = c(
    # -- Sectors: many series, and the block for choosing among them --------
    #
    # -- The adjustment -----------------------------------------------------
    #
    # GDP itself, every version of it SECO publishes: `na` unadjusted, `csa`
    # seasonally and calendar adjusted, and the two sports-event variants.
    gdp = blockr.io::new_read_block(
      source = "path", path = ds_url("type=real;structure=gdp"),
      block_name = "Swiss GDP"
    ),
    raw = new_ts_pick_block(series = "na", block_name = "Unadjusted"),
    # X-13ARIMA-SEATS, the US Census Bureau's program and the one SECO runs.
    # Nothing is specified: the defaults choose the ARIMA model, the transform
    # and the outliers, and land on (1 1 2)(0 1 1) with logs.
    #
    # THE BLOCK HANDS ON THE MODEL, NOT A FRAME, and draws it: the original,
    # the adjusted series and the outliers on the chart side, what X-13
    # estimated on the other. Nothing downstream has to ask for a summary.
    x13 = new_seas_block(block_name = "X-13"),
    # The model holds a hundred and forty-five tables. This asks for two of
    # them by name, and each comes back as a series that draws itself.
    ours = new_seas_series_block(
      series = "final", block_name = "Adjusted series"
    ),
    season = new_seas_series_block(
      series = "s10", block_name = "The seasonal factors"
    ),

    # -- The check ----------------------------------------------------------
    #
    # SECO's own published adjustment of the same series.
    seco = new_ts_pick_block(series = "csa", block_name = "SECO's"),
    # Ours and theirs on one chart. THE TWO LINES SIT ON TOP OF EACH OTHER,
    # which is the exhibit. The legend reads `final` and `csa`, which are the
    # two programs' own names for what they produced.
    check = new_ts_combine_block(method = "c", block_name = "Ours against SECO"),
    # And the answer. A year-on-year rate off the adjusted series: what the
    # economy did, with the season taken out.
    growth = new_ts_transform_block(
      verb = "pcy", block_name = "Growth, year on year"
    ),

    # -- The figures --------------------------------------------------------
    #
    # THE PREVIEW IS NOT THE DOCUMENT. Every block above hands on a data
    # frame, and the chart you see on the board is the app drawing it --
    # uPlot, in the browser, from a payload that does not survive an export.
    # Rendered, those exhibits come out as tables of 186 rows.
    #
    # So the report's figures are ggplot blocks, and what they emit is
    # ordinary ggplot2 against the frame above them:
    #
    #   ggplot2::ggplot(data, ggplot2::aes(x = time, y = value, colour = id))
    #     + ggplot2::geom_line() + ggplot2::theme_minimal()
    #
    # which is what anyone would write and what anyone can lift out of the
    # qmd. A specialised print block for time series would be a third way to
    # draw the same thing, and `tsbox::ts_ggplot()` in a code block is a
    # fourth -- one line, better defaults, and not a block anybody can point
    # at and change. Two blocks, two figures.
    check_gg = blockr.ggplot::new_ggplot_block(
      type = "line", x = "time", y = "value", color = "id",
      block_name = "Ours against SECO, drawn"
    ),
    # No colour: one series, and a legend of one explains nothing.
    growth_gg = blockr.ggplot::new_ggplot_block(
      type = "line", x = "time", y = "value",
      block_name = "Growth, drawn"
    )
  ),
  links = links(
    from = c("gdp", "raw", "x13", "x13", "gdp", "ours", "seco", "ours",
             "check", "growth"),
    to = c("raw", "x13", "ours", "season", "seco", "check", "check", "growth",
           "check_gg", "growth_gg")
  ),
  # FIVE STACKS, one per step of the argument. Read down the outline and the
  # board explains itself: where the data comes from, which sectors were
  # chosen, what was fitted, what the fit was checked against, and the answer.
  stacks = stacks(
    source = new_dock_stack("gdp", name = "Source", color = "#2563eb"),
    adjust = new_dock_stack(
      c("raw", "x13", "ours", "season"),
      name = "Adjustment", color = "#7c3aed"
    ),
    check = new_dock_stack(
      c("seco", "check", "check_gg"), name = "The check", color = "#e8833a"
    ),
    answer = new_dock_stack(
      c("growth", "growth_gg"), name = "The answer", color = "#3fa66a"
    )
  ),
  extensions = list(
    # The outline is the pipeline view and the only one. Twenty blocks in five
    # stacks read as a list; as a graph they need panning.
    blockr.outline::new_outline_extension(),
    blockr.assistant::new_assistant_extension(),
    blockr.outline::new_report_extension(
      title = "Is the Swiss economy growing, or is it just the season?",
      settings = list(
        toc = TRUE,
        number_sections = TRUE,
        block_titles = "none",
        warnings = FALSE
      ),
      items = list(
        list(text = paste0(
          "> Swiss quarterly GDP, seasonally adjusted twice: once by the ",
          "State Secretariat for Economic Affairs, and once here, in one ",
          "block. Nothing below is preloaded. Every chunk downloads its own ",
          "data from [dataseries.org](https://dataseries.org), which serves ",
          "Swiss official statistics as tidy CSV over plain https with no ",
          "key."
        )),

        list(text = paste0(
          "## The question\n\n",
          "Swiss output falls every first quarter and rises every fourth, in ",
          "good years and bad. A number that moves for the same reason every ",
          "year cannot answer the question anyone is asking, which is why the ",
          "figure every commentary quotes is the adjusted one.\n\n",
          "SECO publishes four versions of it: unadjusted, adjusted for the ",
          "season and the calendar, and two sports-event variants. The one ",
          "below is the unadjusted series, which is where this starts."
        )),

        list(text = paste0(
          "## Adjusting it\n\n",
          "GDP itself now, and only the unadjusted series. ",
          "X-13ARIMA-SEATS is the US Census Bureau's program and the one ",
          "SECO runs. Nothing is specified below: the defaults choose the ",
          "ARIMA model, the transform and the outliers, and land on ",
          "(1 1 2)(0 1 1) with a log transform.\n\n",
          "The chart is the model. The original series, the adjusted one on ",
          "top of it, and the outliers X-13 found. What is left when the ",
          "seasonal saw flattens is the level, which is the thing a growth ",
          "rate should be computed on."
        )),
        list(block = "x13", code = TRUE, output = TRUE),

        list(text = paste0(
          "## The check\n\n",
          "SECO publishes its own adjustment of the same series. Here it is ",
          "against ours. The two lines sit on top of each other: over 186 ",
          "quarters they agree to a median of 0.12 percent and never differ ",
          "by more than 0.44.\n\n",
          "The adjustment behind the headline number is not a black box. It ",
          "is one call to a public program with its defaults, and it ",
          "reproduces the official series closely enough that the difference ",
          "does not reach the first decimal of a growth rate."
        )),
        list(block = "check_gg", code = TRUE, output = TRUE),

        list(text = paste0(
          "### Why they are not identical\n\n",
          "Because SECO does not adjust this series at all. It adjusts the ",
          "twenty-odd components of the production account and adds the ",
          "adjusted parts up; the board above adjusts the total.\n\n",
          "Their own published numbers say so. SECO's *adjusted* GDP equals ",
          "the sum of their *adjusted* components to the last digit over all ",
          "146 quarters where every component is published, and seasonal ",
          "adjustment is not additive, so an independently adjusted total ",
          "would not land there. Doing it their way closes most of the gap: ",
          "adjusting the nineteen components separately with the same ",
          "defaults lands a median 0.078 percent from the published series ",
          "against 0.194 for adjusting the total. That comparison has to be ",
          "nominal, because chain-linked volumes do not add.\n\n",
          "Which makes the agreement more convincing rather than less. Two ",
          "different aggregation choices, one program, a tenth of a percent ",
          "apart."
        )),

        list(text = paste0(
          "The season on its own, as X-13 estimated it: the factor divided ",
          "out of each quarter."
        )),
        list(block = "season", code = FALSE, output = TRUE),

        list(text = paste0(
          "## The answer\n\n",
          "Year-on-year growth of the adjusted series: what the economy did, ",
          "with the season taken out. Four blocks from a URL."
        )),
        list(block = "growth_gg", code = TRUE, output = TRUE),

        list(text = paste0(
          "> SECO's published series is adjusted for the calendar as well as ",
          "the season, which is part of why the two are not identical. ",
          "Data: SECO via dataseries.org. Method: X-13ARIMA-SEATS through the ",
          "R package **seasonal**."
        ))

      )
    )
  ),
  grids = list(
    Data = dock_grid(
      "gdp", "raw", ext("outline"),
      orientation = "horizontal", sizes = c(30, 45, 25)
    ),
    Adjustment = dock_grid(
      "x13", panels("ours", "season", active = "ours"),
      orientation = "horizontal", sizes = c(55, 45)
    ),
    Check = dock_grid(
      "seco",
      panels("check", "check_gg", active = "check_gg"),
      panels("growth", "growth_gg", active = "growth_gg"),
      orientation = "horizontal", sizes = c(20, 42, 38)
    ),
    Report = dock_grid(
      ext("report"), ext("outline"),
      orientation = "horizontal", sizes = c(2, 1)
    ),
    Workflow = dock_grid(
      ext("outline"), ext("assistant"), sizes = c(2, 1)
    )
  ),
  # OPEN ON DATA. The talk starts by pointing at a URL and at the four
  # versions of one series it hands back.
  active = "Data"
)

port <- if (exists("blockr_port")) blockr_port() else 3838L
message("http://localhost:", port)
shiny::runApp(serve(board), port = port, host = "0.0.0.0",
              launch.browser = FALSE)
