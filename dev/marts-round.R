# The MARTS round, without the board: does the expression the multi-series
# block emits actually produce the table the triage block is supposed to show?
#
#   Rscript blockr.seasonal/dev/marts-round.R
#
# The reshape below is what the board carries in a code block. Census ships one
# CSV with eight sections in it, separated by blank lines, so no reader parses
# it straight and the split has to be written out.
pkgload::load_all("/workspace/blockr.seasonal", quiet = TRUE)
options(width = 180)

# ---- the data, as the board reads it ---------------------------------------
marts_read <- function(
  url = "https://www.census.gov/econ_getzippedfile/?programCode=MARTS"
) {
  zip <- tempfile(fileext = ".zip")
  utils::download.file(url, zip, quiet = TRUE, mode = "wb")
  dir <- tempfile()
  dir.create(dir)
  utils::unzip(zip, exdir = dir)

  ln <- readLines(file.path(dir, "MARTS-mf.csv"))
  section <- function(name) {
    i <- which(ln == name)
    blanks <- which(ln == "")
    end <- min(c(blanks[blanks > i], length(ln) + 1))
    utils::read.csv(
      text = paste(ln[(i + 1):(end - 1)], collapse = "\n"),
      stringsAsFactors = FALSE
    )
  }
  i <- which(ln == "DATA")
  dat <- utils::read.csv(
    text = paste(ln[(i + 1):length(ln)], collapse = "\n"),
    stringsAsFactors = FALSE
  )

  # Footnote markers live in the value column ("(S)" for suppressed), so the
  # column arrives as character. Coerce here, where it is visible, rather than
  # inside the adjustment.
  dat$val <- suppressWarnings(as.numeric(dat$val))
  dat <- dat[dat$dt_idx == 1, ]           # Sales - Monthly, millions of dollars
  dat <- merge(dat, section("CATEGORIES")[c("cat_idx", "cat_code", "cat_desc")],
               by = "cat_idx")
  dat <- merge(dat, section("TIME PERIODS"), by = "per_idx")
  dat$time <- as.Date(paste0("01-", dat$per_name), format = "%d-%b-%Y")
  dat <- dat[order(dat$cat_code, dat$time), ]

  list(
    nsa = dat[dat$is_adj == 0, c("cat_code", "time", "val")],
    sa  = dat[dat$is_adj == 1, c("cat_code", "time", "val")]
  )
}

cat("reading MARTS...\n")
marts <- marts_read()
cat(" series:", length(unique(marts$nsa$cat_code)),
    " span:", format(min(marts$nsa$time)), "to", format(max(marts$nsa$time)),
    "\n\n")

# ---- what the multi-series block emits -------------------------------------
expr <- blockr.seasonal:::make_seas_multi_expr(
  args = list(),
  id_col = "cat_code", time_col = "time", value_col = "val"
)
cat("the block's expression:\n")
print(expr)
cat("\n")

# `.(name)` is blockr.core's placeholder for a block input; the board resolves
# it when it runs the expression. Outside a board, binding `.` to identity is
# the whole of what the board does here.
dot <- function(x) x
t0 <- Sys.time()
models <- eval(expr, list(data = marts$nsa, `.` = dot))
el <- as.numeric(Sys.time() - t0, units = "secs")
cat(sprintf("\n%d models in %.1fs (%.2fs each)\n\n", length(models), el,
            el / length(models)))

# ---- what the triage block shows -------------------------------------------
cat("default seas(), against the Census published adjustment since 2015:\n\n")
print(seas_triage(models, reference = marts$sa, since = "2015-01-01"))

# ---- the one that needs a hand ---------------------------------------------
cat("\n\nDepartment Stores, with the transform forced:\n\n")
fix_expr <- blockr.seasonal:::make_seas_multi_expr(
  args = list(list(name = "transform.function", value = "log")),
  id_col = "cat_code", time_col = "time", value_col = "val"
)
one <- marts$nsa[marts$nsa$cat_code == "4522", ]
fixed <- eval(fix_expr, list(data = one, `.` = dot))
print(seas_triage(fixed, reference = marts$sa, since = "2015-01-01"))
