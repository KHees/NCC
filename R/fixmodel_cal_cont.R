#' Frequentist linear regression model analysis for continuous data adjusting for calendar time units
#'
#' @description This function performs linear regression taking into account all trial data until the arm under study leaves the trial and adjusting for calendar time units as factors.
#'
#' @param data Trial data, e.g. result from the `datasim_cont()` function. Must contain columns named 'treatment' and 'response'.
#' @param arm Indicator of the treatment arm under study to perform inference on (vector of length 1). This arm is compared to the control group.
#' @param alpha Significance level. Default=0.025.
#' @param unit_size Number of patients per calendar time unit. Default=25.
#' @param ncc Boolean. Whether to include NCC data into the analysis. Default=TRUE.
#' @param check Boolean. Indicates whether the input parameters should be checked by the function. Default=TRUE, unless the function is called by a simulation function, where the default is FALSE.
#' @param ... Further arguments for simulation function.
#'
#' @importFrom stats lm
#' @importFrom stats pt
#' @importFrom stats coef
#' @importFrom stats confint
#'
#' @export
#'
#' @examples
#'
#' trial_data <- datasim_cont(num_arms = 3, n_arm = 100, d = c(0, 100, 250),
#' theta = rep(0.25, 3), lambda = rep(0.15, 4), sigma = 1, trend = "linear")
#'
#' fixmodel_cal_cont(data = trial_data, arm = 3)
#'
#' @return List containing the following elements regarding the results of comparing `arm` to control:
#'
#' - `p-val` - p-value (one-sided)
#' - `treat_effect` - estimated treatment effect in terms of the difference in means
#' - `lower_ci` - lower limit of the 95% confidence interval
#' - `upper_ci` - upper limit of the 95% confidence interval
#' - `reject_h0` - indicator of whether the null hypothesis was rejected or not (`p_val` < `alpha`)
#' - `model` - fitted model
#'
#' @author Pavla Krotka

fixmodel_cal_cont <- function(data, arm, alpha=0.025, unit_size=25, ncc=TRUE, check=TRUE, ...){

  if (check) {
    if (!is.data.frame(data) | sum(c("treatment", "response") %in% colnames(data))!=2) {
      stop("The data frame with trial data must contain the columns 'treatment' and 'response'!")
    }

    if(!is.numeric(arm) | length(arm)!=1){
      stop("The evaluated treatment arm (`arm`) must be one number!")
    }

    if(!is.numeric(alpha) | length(alpha)!=1){
      stop("The significance level (`alpha`) must be one number!")
    }

    if(!is.numeric(unit_size) | length(unit_size)!=1){
      stop("The length of calendar time unit (`unit_size`) must be one number!")
    }

    if(!is.logical(ncc) | length(ncc)!=1){
      stop("The indicator of including NCC data to the analysis (`ncc`) must be TRUE or FALSE!")
    }
  }

  data$cal_time <- rep(c(1:ceiling((nrow(data)/unit_size))), each=unit_size)[1:nrow(data)]

  min_unit <- min(data[data$treatment==arm,]$cal_time)
  max_unit <- max(data[data$treatment==arm,]$cal_time)

  if (ncc) {
    data_new <- data[data$cal_time %in% c(1:max_unit),]
  } else {
    data_new <- data[data$cal_time %in% c(min_unit:max_unit),]
  }

  # fit linear model
  if(length(unique(data_new$cal_time))==1){ # if only one calendar time unit in the data, don't use unit as covariate
    mod <- lm(response ~ as.factor(treatment), data_new)
  } else {

    mod <- lm(response ~ as.factor(treatment) + as.factor(cal_time), data_new)
  }
  res <- summary(mod)

  # one-sided p-value
  p_val <- pt(coef(res)[paste0("as.factor(treatment)", arm), "t value"], mod$df, lower.tail = FALSE)

  # metrics
  treat_effect <- res$coefficients[paste0("as.factor(treatment)", arm), "Estimate"]
  lower_ci <- confint(mod)[paste0("as.factor(treatment)", arm), 1]
  upper_ci <- confint(mod)[paste0("as.factor(treatment)", arm), 2]
  reject_h0 <- (p_val < alpha)

  return(list(p_val = p_val,
              treat_effect = treat_effect,
              lower_ci = lower_ci,
              upper_ci = upper_ci,
              reject_h0 = reject_h0,
              model = mod))
}
