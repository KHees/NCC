#' Time machine analysis for binary data
#'
#' @description This function performs analysis of binary data using the Time Machine approach. It takes into account all data until the investigated arm leaves the trial. It is based on logsitic regression with treatment as a categorical variable and covariate adjustment for time via a second-order Bayesian normal dynamic linear model (separating the trial into buckets of pre-defined size).
#'
#' @param data Trial data, e.g. result from the `datasim_bin()` function. Must contain columns named 'treatment', 'response' and 'period'.
#' @param arm Indicator of the treatment arm under study to perform inference on (vector of length 1). This arm is compared to the control group.
#' @param alpha Significance level. Default=0.025.
#' @param prec_theta Precision (\eqn{1/\sigma^2_{\theta}}) of the prior regarding the treatment effect \eqn{\theta}. I.e. \eqn{\theta \sim N(0, \sigma^2_{\theta})} . Default=0.001.
#' @param prec_eta Precision (\eqn{1/\sigma^2_{\eta_0}}) of the prior regarding the control log-odds \eqn{\eta_0} (corresponds to `p0` in the `datasim_bin()` function). I.e. \eqn{\eta_0 \sim N(0, \sigma^2_{\eta_0})}. Default=0.001.
#' @param tau_a Parameter \eqn{a} of the Gamma distribution for the precision parameter \eqn{\tau} in the model for the time trend. I.e., \eqn{\tau \sim Gamma(a,b)}. Default=0.1.
#' @param tau_b Parameter \eqn{b} of the Gamma distribution for the precision parameter \eqn{\tau} in the model for the time trend. I.e., \eqn{\tau \sim Gamma(a,b)}. Default=0.01.
#' @param bucket_size Number of patients per time bucket. Default=25.
#' @param check Boolean. Indicates whether the input parameters should be checked by the function. Default=TRUE, unless the function is called by a simulation function, where the default is FALSE.
#' @param ... Further arguments for simulation function.
#'
#' @importFrom stats aggregate
#' @importFrom stats quantile
#' @importFrom rjags jags.model
#' @importFrom rjags coda.samples
#'
#' @export
#'
#' @examples
#'
#' trial_data <- datasim_bin(num_arms = 3, n_arm = 100, d = c(0, 100, 250),
#' p0 = 0.7, OR = rep(1.8, 3), lambda = rep(0.15, 4), trend="stepwise")
#'
#' timemachine_bin(data = trial_data, arm = 3)
#'
#'
#' @return List containing the following elements regarding the results of comparing `arm` to control:
#'
#' - `p-val` - posterior probability that the log-odds ratio is less than zero
#' - `treat_effect` - posterior mean of log-odds ratio
#' - `lower_ci` - lower limit of the 95% credible interval for log-odds ratio
#' - `upper_ci` - upper limit of the 95% credible interval for log-odds ratio
#' - `reject_h0` - indicator of whether the null hypothesis was rejected or not (`p_val` < `alpha`)
#'
#' @author Dominic Magirr, Peter Jacko
#'
#' @references The Bayesian Time Machine: Accounting for Temporal Drift in Multi-arm Platform Trials. Saville, B. R., Berry, D. A., et al. Clinical Trials 19.5 (2022): 490-501.

timemachine_bin <- function(data,
                            arm,
                            alpha = 0.025,
                            prec_theta = 0.001,
                            prec_eta = 0.001,
                            tau_a = 0.1,
                            tau_b = 0.01,
                            bucket_size = 25,
                            check = TRUE, ...){

  if (check) {
    if (!is.data.frame(data) | sum(c("treatment", "response", "period") %in% colnames(data))!=3) {
      stop("The data frame with trial data must contain the columns 'treatment', 'response' and 'period'!")
    }

    if(!is.numeric(arm) | length(arm)!=1){
      stop("The evaluated treatment arm (`arm`) must be one number!")
    }

    if(!is.numeric(alpha) | length(alpha)!=1){
      stop("The significance level (`alpha`) must be one number!")
    }

    if(!is.numeric(prec_theta) | length(prec_theta)!=1){
      stop("The precision of the prior regarding the treatment effect (`prec_theta`) must be one number!")
    }

    if(!is.numeric(prec_eta) | length(prec_eta)!=1){
      stop("The precision of the prior regarding the control response (`prec_eta`) must be one number!")
    }

    if(!is.numeric(tau_a) | length(tau_a)!=1){
      stop("The parameter `tau_a` must be one number!")
    }

    if(!is.numeric(tau_b) | length(tau_b)!=1){
      stop("The parameter `tau_b` must be one number!")
    }

    if(!is.numeric(bucket_size) | length(bucket_size)!=1){
      stop("The number of patients per time bucket (`bucket_size`) must be one number!")
    }
  }

  max_period <- max(data[data$treatment==arm,]$period)
  data <- data[data$period %in% c(1:max_period),]

  model_string_time_machine_bin <- "
  model {


    for (i in 1:n_trt_buckets){


       x[i] ~ dbin(p[i], n[i])

            ## alpha[1] is current interval, alpha[10] is most distant interval
            ## time j corresponds to alpha interval Int-(j-1)
            ## e.g. time 1 corresponds to alpha interval 10-(1-1)=10 if interim #10
            ## e.g. time 2 corresponds to alpha interval 7-(2-1)=6 if interim #7

       logit(p[i]) = gamma0 + alpha[n_buckets - (time_bucket[i]-1)] + delta[trt[i]]

    }


    ## Priors for time, counting backwards from current time interval (k=1 for current, k=10 for most distant)
    alpha[1] = 0
    alpha[2] ~ dnorm(0, tau)
    for(k in 3:n_buckets) {
        alpha[k] ~ dnorm(2*alpha[k-1] - alpha[k-2], tau)  # 2*(most recent) - (more distant) puts trend in right direction
    }

    ## Other priors
    delta[1] <- 0
    for(i in 2:n_trts){
      delta[i] ~ dnorm(0, prec_theta)
    }

    tau ~  dgamma(tau_a, tau_b)

    ### Intercept
    gamma0 ~ dnorm(0, prec_eta)

  }
"

  data$time_bucket <- rep(c(1:ceiling((nrow(data)/bucket_size))), each=bucket_size)[1:nrow(data)]

  trt_bucket_n <- aggregate(data$response,
                            list(treatment = data$treatment,
                                 time_bucket = data$time_bucket),
                            "length")

  trt_bucket_x <- aggregate(data$response,
                            list(treatment = data$treatment,
                                 time_bucket = data$time_bucket),
                            "sum")

  n_trt_buckets <- dim(trt_bucket_n)[1]
  n_trts <- max(trt_bucket_n$treatment) + 1
  n_buckets <- max(trt_bucket_n$time_bucket)

  trt <- trt_bucket_n$treatment + 1 ## need index to start at 1, not 0.
  time_bucket <- trt_bucket_n$time_bucket

  x <- trt_bucket_x$x
  n <- trt_bucket_n$x

  ### Arguments to pass to jags_model
  data_list = list(x = x,
                   n = n,
                   trt = trt,
                   time_bucket = time_bucket,
                   n_trts = n_trts,
                   n_buckets = n_buckets,
                   n_trt_buckets = n_trt_buckets,
                   prec_theta = prec_theta,
                   prec_eta = prec_eta,
                   tau_a = tau_a,
                   tau_b = tau_b)

  inits_list = list(gamma0 = 0)


  ### Fit the model
  jags_model <- jags.model(textConnection(model_string_time_machine_bin),
                           data = data_list,
                           inits = inits_list,
                           n.adapt = 1000,
                           n.chains = 3,
                           quiet = T)

  ### Extract posterior samples
  mcmc_samples <- coda.samples(jags_model,
                               c("delta"),
                               n.iter = 4000)

  ### Arrange all samples together
  all_samples <- do.call(rbind.data.frame, mcmc_samples)

  ## posterior means
  post_means <- colMeans(all_samples)

  ## posterior credible intervals
  post_cis <- apply(all_samples, 2, quantile, probs = c(alpha, 1 - alpha))

  ## posterior "p-values"
  post_p <- apply(all_samples, 2, function(x) mean(x < 0))

  ## return
  list(p_val = unname(post_p[arm+1]),
       treat_effect = unname(post_means[arm+1]),
       lower_ci = post_cis[1,arm+1],
       upper_ci = post_cis[2,arm+1],
       reject_h0 = unname(post_p[arm+1] < alpha))
}



