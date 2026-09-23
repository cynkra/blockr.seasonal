#' Pull one series out of a fitted X-13 model
#'
#' A `seas` model in, one series out, as a frame the rest of the ecosystem can
#' read. One control: which series.
#'
#' @details
#' THE CATALOGUE IS THE BLOCK. `inst/extdata/series_codes.rds` is scraped from
#' the `?series` table in the seasonal package by
#' `inst/scripts/update-series-data.R`, so the codes, their descriptions and
#' the spec they belong to all come from the X-13 manual rather than from a
#' list maintained here. 212 of them survive the two exclusions below.
#'
#' THE DESCRIPTION IS THE LABEL AND THE CODE IS THE SMALL PART. Choosing from
#' `a10`, `dor`, `ao` is choosing from nothing; the row reads "regARIMA
#' user-defined seasonal factors" with `a10` trailing in mono for the reader
#' who already knows what they want. The description is also in the search
#' index, which is what makes the list searchable at all: "trend" finds `dtr`
#' and `ltt` only through their sentences.
#'
#' NO BASIC/ADVANCED SPLIT. The obvious partition is by spec, and it does not
#' track usefulness: `spectrum` runs on every model while some of its tables
#' exist only to produce a number, and `history` and `slidingspans` do not run
#' by default while being the ones you reach for. One list, and search does the
#' work. Christoph's call, 2026-09-22.
#'
#' WHAT IS OFFERED DEPENDS ON THE MODEL, not on a fixed list. `series(m,
#' "d10")` against a SEATS model errors with "x11 is not activated", so X11
#' codes are absent from a SEATS model's list and SEATS codes from an X11
#' model's. Same rule the interval and component controls in blockr.ts follow:
#' a question the block cannot answer is a question it does not ask.
#'
#' PICKING RE-RUNS X-13, and that is the right design rather than a cost to
#' work around. `seas()` saves seven tables; anything else makes `series()`
#' rebuild the spec and run the binary again, about 0.08s on AirPassengers
#' against 0.00s for a saved one. You cannot know in advance which diagnostic
#' you will want, so paying at the moment you ask beats deciding at fit time.
#' `series.save` on the `seas()` call is the escape hatch when you have
#' decided.
#'
#' SEVERAL SERIES AT ONCE, because `series()` takes a vector and one X-13 run
#' answers the whole request: two unsaved tables cost the same 0.12s as one.
#' Original against adjusted against trend is the seasonal adjustment view,
#' and it should not be three blocks.
#'
#' The expression stays the call a reader would have written for a single
#' pick, `seasonal::final(data)`. Several picks go through [seas_series()],
#' which fetches them in one run, names them, and refuses to hand back a
#' quietly shortened result -- ask for `s10` and a missing `tc` together and
#' `series()` returns ONE unnamed series with nothing to say that half the
#' request vanished.
#'
#' @param series One or more X-13 series codes, e.g. `"final"`, `"s10"`, or
#'   `c("original", "final", "trend")`.
#' @param ... Forwarded to [blockr.core::new_transform_block()].
#'
#' @examples
#' new_seas_series_block()
#' new_seas_series_block(series = c("original", "final", "trend"))
#'
#' @export
new_seas_series_block <- function(series = "final", ...) {

  blockr.core::new_transform_block(
    function(id, data) {
      shiny::moduleServer(
        id,
        function(input, output, session) {

          r_series <- shiny::reactiveVal(as.character(series))

          # What THIS model can be asked for. Rebuilt when the model changes,
          # never when the pick does: re-rendering the control from our own
          # echo of the user's click is the loop that eats the next one.
          choices <- shiny::reactive(seas_series_choices(data()))

          output$pick <- shiny::renderUI({
            seas_series_ui(session$ns, choices(),
                           shiny::isolate(r_series()))
          })

          # `ignoreNULL = FALSE` so clearing the last tag is reported, and
          # `ignoreInit = TRUE` because without it the observer fires once at
          # startup with `input$series` still NULL, writes `character(0)` over
          # the constructor's value, and the block comes up asking you to set
          # inputs it was given. The same pair is what the multi-selects in
          # blockr.ts need.
          shiny::observeEvent(input$series, {
            v <- as.character(unlist(input$series))
            r_series(v[nzchar(v)])
          }, ignoreNULL = FALSE, ignoreInit = TRUE)

          list(
            expr = shiny::reactive({
              seas_series_call(
                seas_series_pick(r_series(), choices()),
                seas_series_method(data())
              )
            }),
            state = list(series = r_series)
          )
        }
      )
    },
    function(id) {
      shiny::tagList(
        blockr_select_catalog_dep(),
        blockr.dplyr::blockr_blocks_css_dep(),
        shiny::div(
          class = "block-container",
          shiny::uiOutput(shiny::NS(id, "pick"))
        )
      )
    },
    dat_val = function(data) seas_series_validate(data),
    class = "seas_series_block",
    # See `seas_series_call()`: the expression carries `.(data)` so the
    # exported chunk names the block it reads from.
    expr_type = "bquoted",
    ...
  )
}

#' Refuse anything that is not a fitted model, and say what makes one
#' @noRd
seas_series_validate <- function(data) {
  if (inherits(data, "seas")) {
    return(invisible(TRUE))
  }
  stop(
    "This block takes a fitted X-13 model, not a frame. Connect it to a ",
    "seasonal adjustment block.",
    call. = FALSE
  )
}

#' The series this model can be asked for
#'
#' @param model A `seas` model, or anything else.
#' @return A data frame with `code`, `description` and `spec`, in catalogue
#'   order, or zero rows.
#' @noRd
seas_series_choices <- function(model) {
  d <- seas_series_catalog()
  if (!nrow(d) || !inherits(model, "seas")) {
    return(d[0L, , drop = FALSE])
  }
  # X11 tables against a SEATS model error with "x11 is not activated", and
  # the reverse. The method is read off the fitted spec, so switching a board
  # from SEATS to X11 changes the list rather than the error message.
  method <- seas_series_method(model)
  keep <- d$method == "any" | d$method == method
  d[keep, , drop = FALSE]
}

#' Which adjustment this model used
#'
#' The `x11` spec being present is the whole test; a SEATS fit has `seats`
#' there instead. It decides both which codes are offered and which table
#' `"seasonal"` resolves to.
#'
#' @noRd
seas_series_method <- function(model) {
  if (inherits(model, "seas") && !is.null(model$spc$x11)) "x11" else "seats"
}

#' The catalogue, read once
#'
#' Two exclusions, both about what the block can actually draw or run:
#' `Composite` and `X11regression` need model configurations this block cannot
#' guarantee, and five codes return objects that are not series at all.
#'
#' @noRd
seas_series_catalog <- local({
  cache <- NULL
  function() {
    if (!is.null(cache)) {
      return(cache)
    }
    f <- system.file("extdata", "series_codes.rds", package = "blockr.seasonal")
    # NO FALLBACK. An empty catalogue here is a block that offers no series
    # and says nothing about why, which reads as a model with nothing in it.
    # The file ships with the package; if it is not there the install is
    # broken and should say so.
    if (!nzchar(f) || !file.exists(f)) {
      stop("series_codes.rds is missing from blockr.seasonal's extdata. ",
           "The install is incomplete: the series picker has no catalogue.",
           call. = FALSE)
    }
    d <- as.data.frame(readRDS(f), stringsAsFactors = FALSE)
    d <- d[!d$spec %in% c("Composite", "X11regression"), , drop = FALSE]
    d <- d[!d$short_name %in% c("acm", "rcm", "rts", "iac", "ipc"), , drop = FALSE]
    out <- data.frame(
      code = as.character(d$short_name),
      description = as.character(d$description),
      spec = as.character(d$spec),
      method = vapply(as.character(d$spec), function(s) {
        switch(s, X11 = "x11", Seats = "seats", "any")
      }, character(1L), USE.NAMES = FALSE),
      stringsAsFactors = FALSE
    )
    cache <<- out
    out
  }
})

#' Keep the stored picks this model still offers
#'
#' A board saved against an X11 model and reopened against a SEATS one holds
#' codes that now error. Dropping them is right; passing them through gives a
#' red block and no way to see why. An empty result falls back to the adjusted
#' series rather than to nothing, because a block with no pick has nothing to
#' draw and no way to say so.
#'
#' @noRd
seas_series_pick <- function(value, choices) {
  keep <- intersect(as.character(value), choices$code)
  if (length(keep)) keep else "final"
}

#' Fetch one X-13 table, named, or say why it is not there
#'
#' `series()` returns `NULL` for a table X-13 did not write, and about half
#' the catalogue is in that state on any given model: 42 of 145 codes resolve
#' on a default SEATS fit, 74 of 164 on an X11 one. There is no rule that
#' predicts which. Whether the owning spec ran is not it -- active specs yield
#' 45 of 97 and inactive ones 19 of 48, because `series()` re-runs X-13 with
#' the table requested and that switches some specs on by itself.
#'
#' So the block cannot pre-filter the list. Probing is 12.7s for 145 codes at
#' 88ms each, and it cannot be batched: `series()` takes a vector, but one
#' call for all 140 real codes comes back with a single unnamed column in
#' 0.48s, so the cheap version is also the wrong answer. The block offers
#' everything and this says what happened, which is actionable where a red
#' block is not.
#'
#' NAMED ONLY WHEN IT IS ONE SERIES. Wrapping every result in
#' [blockr.ts::ts_name()] was wrong: fifteen codes return several series and
#' eleven return a matrix, and `ts_name()` refuses both, so a pick that should
#' have fallen through to the table preview became an error instead. A sliding
#' spans table IS the answer to its question; it just is not a line.
#'
#' @param model A `seas` model.
#' @param code One or more X-13 series codes, or the friendly names `"final"`,
#'   `"original"`, `"trend"`, `"irregular"` and `"seasonal"`.
#' @return The table, named after the code when it is a single series; a named
#'   multiple series when several were asked for.
#' @export
seas_series <- function(model, code) {

  code <- as.character(code)
  if (!length(code)) {
    stop("No series picked.", call. = FALSE)
  }

  # ONE X-13 RUN FOR ANY NUMBER OF CODES. `series()` takes a vector and two
  # unsaved tables cost the same 0.12s as one, so a multiple pick is not a
  # multiple of the price. Fetching them one at a time would be.
  friendly <- intersect(code, names(seas_series_friendly(model)))
  codes <- setdiff(code, friendly)

  got <- list()

  if (length(codes)) {
    raw <- suppressMessages(suppressWarnings(seasonal::series(model, codes)))

    # A CODE THAT IS NOT THERE COLLAPSES THE WHOLE RESULT. Ask for `s10` and a
    # missing `tc` together and `series()` hands back ONE unnamed `ts` -- not
    # the one that worked and a gap, but a single column with no names at all,
    # and nothing to say that half the request vanished. There is no way to
    # tell from the result which code survived, so when the shape is wrong the
    # codes are re-fetched one at a time to name the missing ones. That path
    # costs 88ms per code and only runs when something is already wrong.
    ok <- !is.null(raw) &&
      (length(codes) == 1L || identical(sort(colnames(raw)), sort(codes)))
    if (!ok) {
      missing <- codes[vapply(codes, function(k) {
        is.null(tryCatch(suppressMessages(suppressWarnings(
          seasonal::series(model, k))), error = function(e) NULL))
      }, logical(1L))]
      if (!length(missing)) missing <- codes
      stop(
        "X-13 did not write ", if (length(missing) > 1L) "tables " else "table ",
        paste0("'", missing, "'", collapse = ", "), " for this model. A table ",
        "exists only when the model has something to put in it -- there are ",
        "no temporary-change outliers to tabulate if the model found none -- ",
        "or when the spec that produces it is switched on in the seas() call.",
        call. = FALSE
      )
    }

    if (length(codes) == 1L) {
      got[[codes]] <- raw
    } else {
      for (k in codes) got[[k]] <- raw[, k]
    }
  }

  for (k in friendly) {
    got[[k]] <- seas_series_friendly(model)[[k]](model)
  }

  got <- got[code] # back into the order that was asked for

  if (length(got) == 1L) {
    named <- tryCatch(blockr.ts::ts_name(got[[1L]], code), error = function(e) NULL)
    # Several series, or a matrix, or not a series at all: hand it on as it
    # came and let the preview decide. `ts_name()` refuses both, and a sliding
    # spans table IS the answer to its question, it is just not a line.
    return(if (is.null(named)) got[[1L]] else named)
  }

  # NEVER `do.call(tsbox::ts_c, got)`. ts_c names its series by DEPARSING its
  # argument expressions, and under do.call those expressions are the values
  # themselves, so two series come back as `s101` and `s102`. Build the long
  # frame from the names we already have instead.
  out <- do.call(rbind, lapply(names(got), function(k) {
    blockr.ts::ts_name(got[[k]], k)
  }))
  out[order(match(out$id, names(got)), out$time), , drop = FALSE]
}

#' The five names that are not X-13 codes
#'
#' `series(m, "final")` fails for all five: they are a convenience of the
#' seasonal package, not tables. Four have a function of their own; the fifth
#' is the seasonal factors, which are `s10` under SEATS and `d10` under X11,
#' so it has to be resolved against the model rather than named statically.
#'
#' @noRd
seas_series_friendly <- function(model) {
  sf <- if (identical(seas_series_method(model), "x11")) "d10" else "s10"
  list(
    final = seasonal::final,
    original = seasonal::original,
    trend = seasonal::trend,
    irregular = seasonal::irregular,
    seasonal = function(m) suppressMessages(seasonal::series(m, sf))
  )
}

#' The call the block writes
#'
#' Three shapes, and the split is about what the reader would have typed.
#'
#' * The four components with a function of their own read as themselves:
#'   `seasonal::final(data)`. They are always single series, so naming them is
#'   safe inline.
#' * `"seasonal"` is the fifth friendly name and has no function. It is the
#'   seasonal factors, which are `s10` under SEATS and `d10` under X11, so the
#'   call names the table the method actually has.
#' * Everything else goes through [seas_series()], which is where the
#'   not-written case gets a sentence instead of a stack trace.
#'
#' @noRd
seas_series_call <- function(code, method = "seats") {

  code <- as.character(code)

  # `.(data)`, not `data`. The block declares `expr_type = "bquoted"`, so
  # blockr.core substitutes the upstream block's own name into the
  # placeholder. With a bare symbol core has to bind it instead, and the
  # exported report carries
  #
  #   ours <- with(list(data = x13), blockr.ts::ts_name(seasonal::final(data),
  #                                                     "final"))
  #
  # where it should read `ours <- blockr.ts::ts_name(seasonal::final(x13),
  # "final")`. Correct either way; only one of them is code anybody writes.
  dat <- call(".", as.name("data"))

  # ONE PICK KEEPS THE CALL A READER WOULD HAVE WRITTEN. `seasonal::final(
  # data)` is the common case and it should look like itself. Several picks
  # need the fetch-and-combine that seas_series() does, and there is no
  # hand-written form of that worth imitating.
  if (length(code) == 1L) {
    if (code %in% c("final", "original", "trend", "irregular")) {
      return(as.call(list(
        call("::", quote(blockr.ts), quote(ts_name)),
        as.call(list(call("::", quote(seasonal), as.name(code)), dat)),
        code
      )))
    }
    if (identical(code, "seasonal")) {
      tbl <- if (identical(method, "x11")) "d10" else "s10"
      return(as.call(list(
        call("::", quote(blockr.ts), quote(ts_name)),
        as.call(list(call("::", quote(seasonal), quote(series)), dat, tbl)),
        "seasonal"
      )))
    }
  }

  as.call(list(
    call("::", quote(blockr.seasonal), quote(seas_series)),
    dat,
    if (length(code) == 1L) code else as.call(c(list(quote(c)), as.list(code)))
  ))
}

#' The control
#'
#' `Blockr.SelectCatalog`, mounted with the options baked into the script
#' rather than pushed over a custom message: they change only when the model
#' changes, which is exactly what re-renders this UI, so the options arrive
#' with the markup that shows them and there is no handshake to lose.
#'
#' @noRd
seas_series_ui <- function(ns, choices, selected) {

  cid <- ns("series_cont")

  opts <- lapply(seq_len(nrow(choices)), function(i) {
    list(
      value = choices$code[[i]],
      label = choices$description[[i]],
      group = choices$spec[[i]]
    )
  })

  htmltools::tagList(
    seas_series_css(),
    htmltools::div(
      class = "seas-series-field",
      htmltools::tags$label(class = "control-label", "Series"),
      htmltools::div(id = cid, class = "blockr-select--bordered"),
      htmltools::div(
        class = "seas-series-count",
        sprintf("%d series in this model", nrow(choices))
      )
    ),
    htmltools::tags$script(htmltools::HTML(sprintf(
      "(function(){var f=function(){
         if(!window.Blockr||!Blockr.SelectCatalog||!window.Shiny){return setTimeout(f,50);}
         var el=document.getElementById(%s); if(!el){return setTimeout(f,50);}
         el.innerHTML='';
         el._sel=Blockr.SelectCatalog.multi(el,{options:%s,selected:%s,
           searchAfter:0,labelFirst:true,
           placeholder:%s,
           onChange:function(v){Shiny.setInputValue(%s,v,{priority:'event'});}});
       };f();})();",
      jsonlite::toJSON(cid, auto_unbox = TRUE),
      jsonlite::toJSON(opts, auto_unbox = TRUE),
      jsonlite::toJSON(as.character(selected)),
      jsonlite::toJSON("Search the X-13 series", auto_unbox = TRUE),
      jsonlite::toJSON(ns("series"), auto_unbox = TRUE)
    )))
  )
}

#' @noRd
seas_series_css <- function() {
  htmltools::tags$style(htmltools::HTML("
    .seas-series-field { margin-bottom: 10px; }
    .seas-series-field .control-label {
      display: block;
      font-size: var(--blockr-font-size-xs, 0.75rem);
      font-weight: 500;
      color: var(--blockr-grey-500, #6b7280);
      margin-bottom: 4px;
    }
    .seas-series-count {
      font-size: 11px;
      color: var(--blockr-grey-400, #9ca3af);
      margin-top: 4px;
    }
  "))
}
