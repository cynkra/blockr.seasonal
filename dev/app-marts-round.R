# The MARTS round, as a board.
#
#   Rscript blockr.seasonal/dev/app-marts-round.R
#
# US Census Advance Monthly Retail Trade: 21 retail categories, monthly since
# 1992, and Census's OWN X-13 adjustment of every one of them in the same file.
# So the board can adjust all 21 itself and check each against the office's
# published answer, which is what the triage table's last two columns are.
#
# Nothing is preloaded. The first block downloads the publisher's zip.
for (p in c("blockr.core", "blockr.dag", "blockr.dock", "blockr.dplyr",
            "blockr.extra", "blockr.io", "blockr.seasonal")) {
  pkgload::load_all(file.path("/workspace", p), quiet = TRUE)
}

options(blockr.dock_is_locked = FALSE)

# ---- the read ---------------------------------------------------------------
# TWO BLOCKS, AND THE SPLIT BETWEEN THEM IS THE POINT: the fixed block fetches
# the publisher's file, the code block turns what comes out into a table.
#
# WHY NOT `blockr.io::new_read_block()`. It picks its reader from the path's
# EXTENSION, and this URL has none (`econ_getzippedfile/?programCode=MARTS`).
# Neither does any modern statistical API: ECB, Eurostat and Bundesbank all
# name the format in a query parameter. Filed in `_inbox/`.
#
# WHY NOT `new_fixed_block()` EITHER, which is what aedes-ivm reaches for in
# the same spot. It is a TRANSFORM block, so with nothing linked into it the
# board leaves it on "Waiting for a data input" and the whole chain stays
# dormant. Verified in the app, 2026-09-20. Also filed: there is no block that
# puts a hand-written call at the ROOT of a board.
#
# So the root is four lines of `new_data_block()` here. The expression is
# emitted verbatim either way, so the exported document is the same document.
#
# It returns the file's LINES, not a table, because `read.csv()` dies on this
# file outright: Census ships eight sections in one CSV, separated by blank
# lines and with different column counts.
marts_fetch <- quote({
  url <- "https://www.census.gov/econ_getzippedfile/?programCode=MARTS"

  zip <- tempfile(fileext = ".zip")
  utils::download.file(url, zip, quiet = TRUE, mode = "wb")
  dir <- tempfile()
  dir.create(dir)
  utils::unzip(zip, exdir = dir)

  data.frame(line = readLines(file.path(dir, "MARTS-mf.csv")))
})

new_marts_block <- function(...) {
  blockr.core::new_data_block(
    function(id) {
      shiny::moduleServer(id, function(input, output, session) {
        list(expr = shiny::reactive(marts_fetch), state = list())
      })
    },
    class = "marts_block",
    allow_empty_state = TRUE,
    ...
  )
}

# The twelve lines that know what the sections mean, written where a reader of
# the report can see them instead of hiding in a package.
#
# The value column arrives as character because suppressed cells carry "(S)".
# Coercing in the open, one line from the read, is the difference between a
# suppressed observation and a silently missing one.
marts_script <- '
ln <- data$line

section <- function(name) {
  i <- which(ln == name)
  blanks <- which(ln == "")
  end <- min(c(blanks[blanks > i], length(ln) + 1))
  utils::read.csv(text = paste(ln[(i + 1):(end - 1)], collapse = "\\n"),
                  stringsAsFactors = FALSE)
}

i <- which(ln == "DATA")
dat <- utils::read.csv(text = paste(ln[(i + 1):length(ln)], collapse = "\\n"),
                       stringsAsFactors = FALSE)
dat$val <- suppressWarnings(as.numeric(dat$val))
dat <- dat[dat$dt_idx == 1, ]

dat <- merge(dat, section("CATEGORIES")[c("cat_idx", "cat_code", "cat_desc")],
             by = "cat_idx")
dat <- merge(dat, section("TIME PERIODS"), by = "per_idx")
dat$time <- as.Date(paste0("01-", dat$per_name), format = "%d-%b-%Y")

dat[order(dat$cat_code, dat$time),
    c("cat_code", "cat_desc", "time", "is_adj", "val")]
'

board <- blockr.dock::new_dock_board(
  blocks = c(
    file = new_marts_block(block_name = "Census MARTS"),
    marts = blockr.extra::new_code_block(
      script = marts_script, block_name = "Reshape"
    ),

    # Two views of the same frame: what Census measured, and what Census
    # published after adjusting it.
    nsa = blockr.dplyr::new_filter_block(
      conditions = list(
        list(type = "values", column = "is_adj",
             values = list(0), mode = "include")
      ),
      block_name = "Unadjusted"
    ),
    sa = blockr.dplyr::new_filter_block(
      conditions = list(
        list(type = "values", column = "is_adj",
             values = list(1), mode = "include")
      ),
      block_name = "Census adjusted"
    ),

    # The round. One specification, 21 series, about ten seconds.
    round = new_seas_multi_block(
      series = "cat_code", time = "time", value = "val",
      block_name = "Adjust all 21"
    ),

    # The product. Sorted worst first.
    # `ref_cols` is not optional here and the panel shows why: the reference
    # still carries `is_adj`, so resolving the value column by type picks the
    # 0/1 flag and every series reads as millions of percent off.
    triage = new_seas_triage_block(
      since = "2015-01-01",
      ref_cols = list(series = "cat_code", time = "time", value = "val"),
      block_name = "Triage"
    )
  ),
  links = blockr.core::links(
    from = c("file", "marts", "marts", "nsa", "round", "sa"),
    to   = c("marts", "nsa", "sa", "round", "triage", "triage")
  ),
  extensions = list(blockr.dag::new_dag_extension())
)

port <- if (exists("blockr_port")) blockr_port() else 3838L
message("http://localhost:", port)
shiny::runApp(serve(board, "marts_round"),
              port = port, host = "0.0.0.0", launch.browser = FALSE)
