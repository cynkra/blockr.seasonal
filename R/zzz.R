.onLoad <- function(libname, pkgname) {
  register_seasonal_blocks()
  invisible(NULL)
}
