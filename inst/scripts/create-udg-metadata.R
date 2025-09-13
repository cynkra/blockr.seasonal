# Script to create UDG metadata table
# Based on X-13ARIMA-SEATS documentation and seasonal package

# Create comprehensive metadata for UDG statistics
udg_metadata <- data.frame(
  statistic = character(),
  category = character(),
  description = character(),
  stringsAsFactors = FALSE
)

# Define metadata based on X-13ARIMA-SEATS documentation
metadata_list <- list(
  # Basic Information
  list("date", "Basic", "Date of X-13ARIMA-SEATS run"),
  list("time", "Basic", "Time of X-13ARIMA-SEATS run"),
  list("version", "Basic", "Version of X-13ARIMA-SEATS"),
  list("build", "Basic", "Build number of X-13ARIMA-SEATS"),
  list("nobs", "Basic", "Number of observations"),
  list("freq", "Basic", "Frequency of the series (e.g., 12 for monthly)"),
  list("span", "Basic", "Time span of the series"),
  list("transform", "Basic", "Transformation applied (log, none, auto)"),
  list("samode", "Basic", "Seasonal adjustment mode (mult, add, logadd, pseudoadd)"),
  
  # Model Statistics
  list("aic", "Model", "Akaike Information Criterion"),
  list("aicc", "Model", "Corrected Akaike Information Criterion"),
  list("bic", "Model", "Bayesian Information Criterion (Schwarz Criterion)"),
  list("loglikelihood", "Model", "Log-likelihood of the model"),
  list("nmodel", "Model", "Number of ARIMA model parameters"),
  list("nreg", "Model", "Number of regression variables"),
  list("constant", "Model", "Indicates if constant/mean is included"),
  list("arimamdl", "Model", "ARIMA model specification"),
  
  # QS Statistics (Test for seasonality)
  list("qslog", "QS Test", "QS statistic for log-transformed series"),
  list("qsori", "QS Test", "QS statistic for original series"),
  list("qsorievadj", "QS Test", "QS statistic for original series (adjusted for extreme values)"),
  list("qsrsd", "QS Test", "QS statistic for residuals"),
  list("qssadj", "QS Test", "QS statistic for seasonally adjusted series"),
  list("qssadjevadj", "QS Test", "QS statistic for seasonally adjusted series (adjusted for extreme values)"),
  list("qsirr", "QS Test", "QS statistic for irregular component"),
  list("qsirrevadj", "QS Test", "QS statistic for irregular component (adjusted for extreme values)"),
  
  # F-Statistics (X-11 Diagnostics)
  list("f2.a01", "F-Test", "F-test for seasonality (Table A1)"),
  list("f2.b01", "F-Test", "F-test for seasonality (Table B1)"),
  list("f2.c01", "F-Test", "F-test for seasonality (Table C1)"),
  list("f2.d", "F-Test", "F-test for seasonality in final SA series"),
  list("f2.e", "F-Test", "F-test for residual seasonality"),
  list("f2.f", "F-Test", "F-test for moving seasonality"),
  list("f2.g", "F-Test", "Combined test for identifiable seasonality"),
  list("f2.fsd8", "F-Test", "F-test for stable seasonality (D8)"),
  list("f2.fsb1", "F-Test", "F-test for stable seasonality (B1)"),
  list("f2.ic", "F-Test", "F-test for calendar effects"),
  list("f2.is", "F-Test", "F-test for stable seasonality"),
  list("f2.kw", "F-Test", "Kruskal-Wallis test for stable seasonality"),
  list("f2.msf", "F-Test", "F-test for moving seasonality factor"),
  list("f2.idseasonal", "F-Test", "Test for identifiable seasonality"),
  
  # M-Statistics (Quality Measures)
  list("f3.m01", "M-Stat", "M1: Relative contribution of irregular to stationary portion"),
  list("f3.m02", "M-Stat", "M2: Relative contribution of irregular to trend-cycle"),
  list("f3.m03", "M-Stat", "M3: Amount of period-to-period change in irregular"),
  list("f3.m04", "M-Stat", "M4: Amount of autocorrelation in irregular"),
  list("f3.m05", "M-Stat", "M5: Number of periods to cyclical dominance"),
  list("f3.m06", "M-Stat", "M6: Amount of period-to-period change in seasonal"),
  list("f3.m07", "M-Stat", "M7: Amount of moving seasonality"),
  list("f3.m08", "M-Stat", "M8: Size of fluctuations in seasonal"),
  list("f3.m09", "M-Stat", "M9: Average linear movement in seasonal"),
  list("f3.m10", "M-Stat", "M10: Size of fluctuations in seasonal compared to irregular"),
  list("f3.m11", "M-Stat", "M11: Size of fluctuations in irregular compared to seasonal"),
  list("f3.q", "M-Stat", "Q: Overall quality assessment statistic"),
  list("f3.qm2", "M-Stat", "Q-M2: Modified Q statistic"),
  list("f3.fail", "M-Stat", "Number of M-statistics that fail"),
  
  # Spectrum Analysis
  list("spectrum", "Spectrum", "Spectrum analysis performed"),
  list("spectype", "Spectrum", "Type of spectrum analysis"),
  list("startspec", "Spectrum", "Starting period for spectrum"),
  list("decibel", "Spectrum", "Spectrum in decibels"),
  list("specrobustsa", "Spectrum", "Robust spectrum for SA series"),
  list("specseries", "Spectrum", "Series used for spectrum"),
  list("showseasonalfreq", "Spectrum", "Show seasonal frequencies"),
  list("nspecfreq", "Spectrum", "Number of spectral frequencies"),
  list("ntdfreq", "Spectrum", "Number of trading day frequencies"),
  list("nsfreq", "Spectrum", "Number of seasonal frequencies"),
  
  # Trading Day Spectrum
  list("t1.freq", "TD Spectrum", "First trading day frequency"),
  list("t1.index", "TD Spectrum", "First trading day frequency index"),
  list("t2.freq", "TD Spectrum", "Second trading day frequency"),
  list("t2.index", "TD Spectrum", "Second trading day frequency index"),
  
  # Seasonal Spectrum
  list("s1.freq", "Seasonal Spectrum", "First seasonal frequency"),
  list("s1.index", "Seasonal Spectrum", "First seasonal frequency index"),
  list("s2.freq", "Seasonal Spectrum", "Second seasonal frequency"),
  list("s2.index", "Seasonal Spectrum", "Second seasonal frequency index"),
  list("s3.freq", "Seasonal Spectrum", "Third seasonal frequency"),
  list("s3.index", "Seasonal Spectrum", "Third seasonal frequency index"),
  list("s4.freq", "Seasonal Spectrum", "Fourth seasonal frequency"),
  list("s4.index", "Seasonal Spectrum", "Fourth seasonal frequency index"),
  
  # X-11 Options
  list("x11regress", "X-11", "X-11 regression performed"),
  list("x11otl", "X-11", "X-11 outlier treatment"),
  list("seasonalma", "X-11", "Seasonal moving average used"),
  list("trendma", "X-11", "Trend moving average used"),
  list("shrink", "X-11", "Shrinkage factors applied"),
  list("siglim", "X-11", "Sigma limits for extreme value detection"),
  list("finmode", "X-11", "Final decomposition mode"),
  
  # Forecasting
  list("nfcst", "Forecast", "Number of forecasts"),
  list("ciprob", "Forecast", "Confidence interval probability"),
  list("lognormal", "Forecast", "Log-normal forecast adjustment"),
  
  # AIC Tests
  list("aictest", "AIC Test", "AIC test result"),
  list("aictrans", "AIC Test", "AIC for transformation"),
  list("aictest.trans.aicc.nolog", "AIC Test", "AICc without log transformation"),
  list("aictest.trans.aicc.log", "AIC Test", "AICc with log transformation"),
  list("aictest.td", "AIC Test", "AIC test for trading day"),
  list("aictest.diff.td", "AIC Test", "AIC difference for trading day"),
  list("aictest.easter.reg", "AIC Test", "AIC test for Easter regression"),
  list("aictest.e", "AIC Test", "AIC test for Easter effect"),
  list("aictest.e.window", "AIC Test", "AIC test Easter window"),
  list("aictest.diff.e", "AIC Test", "AIC difference for Easter"),
  
  # AutoModel
  list("automdl.best5.bic01", "AutoModel", "Best ARIMA model by BIC"),
  list("automdl.best5.bic02", "AutoModel", "2nd best ARIMA model by BIC"),
  list("automdl.best5.bic03", "AutoModel", "3rd best ARIMA model by BIC"),
  list("automdl.best5.bic04", "AutoModel", "4th best ARIMA model by BIC"),
  list("automdl.best5.bic05", "AutoModel", "5th best ARIMA model by BIC"),
  
  # Other
  list("mvval", "Other", "Missing value handling"),
  list("iqtype", "Other", "Irregular/Seasonal adjustment type"),
  list("adjtot", "Other", "Total adjustment factors"),
  list("output", "Other", "Output format specification"),
  list("srstit", "Other", "Series title"),
  list("srsnam", "Other", "Series name"),
  list("altfreq", "Other", "Alternative frequency"),
  list("saveallspecfreq", "Other", "Save all spectral frequencies"),
  list("specmaxar", "Other", "Maximum AR order for spectrum")
)

# Convert list to data frame
for (item in metadata_list) {
  udg_metadata <- rbind(
    udg_metadata,
    data.frame(
      statistic = item[[1]],
      category = item[[2]],
      description = item[[3]],
      stringsAsFactors = FALSE
    )
  )
}

# Add additional common statistics that might not be in the basic list
additional_stats <- data.frame(
  statistic = c(
    "durbinwatson", "skewness", "kurtosis", "normality",
    "heteroskedasticity", "serialcorrelation", "ljungbox",
    "boxpierce", "monotonictest", "spectralpeaks",
    "residualacf", "residualpacf", "outliers", "levelshifts",
    "innovationvariance", "difforder", "ardiff", "madiff"
  ),
  category = c(
    "Diagnostics", "Diagnostics", "Diagnostics", "Diagnostics",
    "Diagnostics", "Diagnostics", "Diagnostics",
    "Diagnostics", "Diagnostics", "Spectrum",
    "Residuals", "Residuals", "Outliers", "Outliers",
    "Model", "Model", "Model", "Model"
  ),
  description = c(
    "Durbin-Watson test for autocorrelation",
    "Skewness of residuals",
    "Kurtosis of residuals",
    "Normality test of residuals",
    "Test for heteroskedasticity",
    "Test for serial correlation",
    "Ljung-Box test for residual autocorrelation",
    "Box-Pierce test for residual autocorrelation",
    "Test for monotonic trend",
    "Spectral peaks identified",
    "Residual autocorrelation function",
    "Residual partial autocorrelation function",
    "Number of outliers detected",
    "Number of level shifts detected",
    "Innovation variance estimate",
    "Differencing order",
    "AR differencing order",
    "MA differencing order"
  ),
  stringsAsFactors = FALSE
)

udg_metadata <- rbind(udg_metadata, additional_stats)

# Sort by category and then by statistic name
udg_metadata <- udg_metadata[order(udg_metadata$category, udg_metadata$statistic), ]

# Save to RDS
saveRDS(udg_metadata, "inst/extdata/udg_metadata.rds")

# Also save as CSV for reference
write.csv(udg_metadata, "inst/extdata/udg_metadata.csv", row.names = FALSE)

cat("Created UDG metadata with", nrow(udg_metadata), "statistics\n")
cat("Categories:", paste(unique(udg_metadata$category), collapse = ", "), "\n")