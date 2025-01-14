#' Analysis for binary data using the MAP Prior approach
#'
#' @description This function performs analysis of binary data using the Meta-Analytic-Predictive (MAP) Prior approach. The method borrows data from non-concurrent controls to obtain the prior distribution for the control response in the concurrent periods.
#'
#' @param data Trial data, e.g. result from the `datasim_bin()` function. Must contain columns named 'treatment', 'response' and 'period'.
#' @param arm Indicator of the treatment arm under study to perform inference on (vector of length 1). This arm is compared to the control group.
#' @param alpha Significance level. Default=0.025
#' @param opt Binary. If opt==1, all former periods are used as one source; if opt==2, periods get separately included into the final analysis. Default=2.
#' @param prior_prec_tau Dispersion parameter of the half normal prior, the prior for the between study heterogeneity. Default=4.
#' @param prior_prec_mu Dispersion parameter of the normal prior, the prior for the control log-odds. Default=0.001.
#' @param n.samples Number of how many random samples will get drawn for the calculation of the posterior mean, the p-value and the CI's. Default=1000.
#' @param n.chains Number of parallel chains for the rjags model. Default=4.
#' @param n.iter Number of iterations to monitor of the jags.model. Needed for coda.samples. Default=4000.
#' @param n.adapt Number of iterations for adaptation, an initial sampling phase during which the samplers adapt their behavior to maximize their efficiency. Needed for jags.model. Default=1000.
#' @param robustify Boolean. Indicates whether a robust prior is to be used. If TRUE, a mixture prior is considered combining a MAP prior and a weakly non-informative component prior. Default=TRUE.
#' @param weight Weight given to the non-informative component (0 < weight < 1) for the robustification of the MAP prior according to Schmidli (2014). Default=0.1.
#' @param check Boolean. Indicates whether the input parameters should be checked by the function. Default=TRUE, unless the function is called by a simulation function, where the default is FALSE.
#' @param ... Further arguments for simulation function.
#'
#' @importFrom RBesT automixfit
#' @importFrom RBesT postmix
#' @importFrom RBesT mixbeta
#' @importFrom RBesT robustify
#' @importFrom RBesT rmix
#' @importFrom stats quantile
#' @importFrom rjags jags.model
#' @importFrom rjags coda.samples
#'
#' @export
#'
#' @details
#'
#' In this function, the argument `alpha` corresponds to \eqn{1-\gamma}, where \eqn{\gamma} is the decision boundary. Specifically, the posterior probability of the difference distribution under the null hypothesis is such that:
#' \eqn{P(p_{treatment}-p_{control}>0) \ge 1-}`alpha`.
#' In case of a non-informative prior this coincides with the frequentist type I error.
#'
#' @examples
#'
#' trial_data <- datasim_bin(num_arms = 3, n_arm = 100, d = c(0, 100, 250),
#' p0 = 0.7, OR = rep(1.8, 3), lambda = rep(0.15, 4), trend="stepwise")
#'
#' MAPprior_bin(data = trial_data, arm = 3)
#'
#'
#' @return List containing the following elements regarding the results of comparing `arm` to control:
#'
#' - `p-val` - p-value (one-sided) obtained by drawing `n.samples` random samples from each posterior distribution
#' - `treat_effect` - estimated treatment effect in terms of the log-odds ratio obtained by drawing `n.samples` random samples from each posterior distribution
#' - `lower_ci` - lower limit of the 95% confidence interval obtained by drawing `n.samples` random samples from each posterior distribution
#' - `upper_ci` - upper limit of the 95% confidence interval obtained by drawing `n.samples` random samples from each posterior distribution
#' - `reject_h0` - indicator of whether the null hypothesis was rejected or not (`p_val` < `alpha`)
#'
#' @author Katharina Hees
#'
#' @references Robust meta-analytic-predictive priors in clinical trials with historical control information. Schmidli, H., et al. Biometrics 70.4 (2014): 1023-1032.



MAPprior_bin <- function(data,
                          arm,
                          alpha = 0.025,
                          opt = 2,
                          prior_prec_tau = 4,
                          prior_prec_mu=0.001,
                          n.samples = 1000,
                          n.chains = 4,
                          n.iter = 4000,
                          n.adapt = 1000,
                          robustify = TRUE,
                          weight = 0.1,
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

    if(!is.numeric(opt)| length(opt)!=1 | opt %in% c(1,2) == FALSE){
      stop("The parameter `opt` must be either 1 or 2!")
    }

    if(!is.numeric(prior_prec_tau) | length(prior_prec_tau)!=1){
      stop("The dispersion parameter of the half normal prior, the prior for the between study heterogeneity, (`prior_prec_tau`) must be one number!")
    }

    if(!is.numeric(prior_prec_tau) | length(prior_prec_mu)!=1){
      stop("The dispersion parameter of the normal prior, the prior for the control log-odds, (`prior_prec_mu`) must be one number!")
    }

    if(!is.numeric(n.samples) | length(n.samples)!=1){
      stop("The numer of random samples (`n.samples`) must be one number!")
    }

    if(!is.numeric(n.chains) | length(n.chains)!=1){
      stop("The numer of parallel chains for the rjags model (`n.chains`) must be one number!")
    }

    if(!is.numeric(n.iter) | length(n.iter)!=1){
      stop("The number of iterations to monitor of the jags.model (`n.iter`) must be one number!")
    }

    if(!is.numeric(n.adapt) | length(n.adapt)!=1){
      stop("The number of iterations for adaptation (`n.adapt`) must be one number!")
    }

    if(!is.logical(robustify) | length(robustify)!=1){
      stop("The parameter `robustify` must be  TRUE or FALSE!")
    }

    if(!is.numeric(weight) | length(weight)!=1 | weight < 0 | weight > 1){
      stop("The weight given to the non-informative component (`weight`) must be one number between 0 and 1!")
    }
  }

  # 1-alpha is here the decision boundary for the posterior probability,
  # in case that one uses a non-informative/flat prior instead of a MAP prior, the type one error is equal to alpha

  # Data preparation
  ## count number of patients for each treatment in each period
  tab_count <- table(data$treatment,data$period)

  ## count number of groups and number of periods
  number_of_groups <- dim(table(data$treatment,data$period))[1] # number of groups incl control
  number_of_periods <- dim(table(data$treatment,data$period))[2] #total number of periods


  ## get start and end period of each treatment
  treatment_start_period <- numeric(number_of_groups)
  treatment_end_period <- numeric(number_of_groups)
  for (i in 1:number_of_groups){
    treatment_start_period[i] <- min(which(table(data$treatment,data$period)[i,] > 0))
    treatment_end_period[i] <- max(which(table(data$treatment,data$period)[i,] > 0))
  }

  ## get concurrent and non-concurrent controls of treatment = arm
  cc <- data[data$treatment == 0 & data$period > treatment_start_period[arm + 1] - 1 & data$period < treatment_end_period[arm + 1] + 1, ]
  ncc <- data[data$treatment == 0 & data$period < treatment_start_period[arm + 1],]


  ## get patients treated with treatment=arm
  t_treatment <- data[data$treatment == arm,]

  if(dim(ncc)[1] !=0){

    if(opt==1){
      ncc$period <- 0
    }

    ## data for the model underlying for control data
    ncc_control_data_jags <- list(
      N_std = length(unique(ncc$period)),
      y = sapply(unique(ncc$period), function(x) sum(ncc[ncc$period == x, ]$response)),
      n = sapply(unique(ncc$period), function(x) length(ncc[ncc$period == x, ]$response)),
      prior_prec_tau = prior_prec_tau,
      prior_prec_mu = prior_prec_mu
    )



    model_text <- "model
      {
        for (i in 1:N_std) {
          # binomial likelihood
          y[i] ~ dbin(p[i], n[i])
          logit(p[i])  <-  logit_p[i]
          logit_p[i] ~ dnorm(mu, inv_tau2)
        }

        # prior distributions
        inv_tau2 <- pow(tau, -2)
        tau ~ dnorm(0, prior_prec_tau)I(0,) # HN(scale = 1 / sqrt(prior_prec_tau)), I(0,) means censoring on positive values
        mu  ~ dnorm(0, prior_prec_mu)

        # prediction for p in a new study
        logit_p.pred ~ dnorm(mu, inv_tau2)
        p.pred <- 1 / (1 + exp(-logit_p.pred))
      }"




    fit <- jags.model(file = textConnection(model_text),
                      data = ncc_control_data_jags,
                      #inits = inits,
                      n.chains = n.chains,
                      n.adapt = n.adapt,
                      quiet = TRUE
    )


    # Draw samples from the above fitted MCMC model
    help_mcmc_samples <- coda.samples(fit, "p.pred", n.iter = n.iter)
    help_samples <- do.call(rbind.data.frame, help_mcmc_samples)[,1]


    ## Fit Beta mixture to MCMC samples
    prior_control <- automixfit(help_samples,type="beta",Nc=3) # Nc=3: fixed number of mixture components, to speed the code up

    if (robustify== TRUE) {
      prior_control <- robustify(prior_control,weight=weight)
    }
  }
  else{

    prior_control <- mixbeta(c(1,0.5,0.5))

  }


  ## get summary data of treatment group and concurrent controls
  r.act <- sum(t_treatment$response)
  n.act <- length(t_treatment$response)

  r.pbo <- sum(cc$response)
  n.pbo <- length(cc$response)


  post_control <- postmix(prior_control,n=n.pbo,r=r.pbo)

  post_treatment <- mixbeta(c(1,0.5+r.act,0.5+n.act-r.act))



  samples_control <-rmix(post_control,n=n.samples)
  samples_treat <- rmix(post_treatment,n=n.samples)
  p1 <- samples_treat
  p2 <- samples_control

  ## calculate log odds ratio and with that the estimated treatment effect
  logoddsratio <- log((p1 / (1 - p1)) / (p2 / (1 - p2)))
  treat_effect <- mean(logoddsratio)

  delta_ci <- quantile(logoddsratio, probs = c(alpha, 1 - alpha))
  lower_ci <- as.numeric(delta_ci[1])
  upper_ci <- as.numeric(delta_ci[2])

  ## calculate the "p-value"
  p_value <- mean(samples_treat - samples_control < 0)
  reject_h0 <- ifelse(p_value<alpha, TRUE, FALSE)

  return(list(p_val = p_value,
              treat_effect = treat_effect,
              lower_ci = lower_ci,
              upper_ci = upper_ci,
              reject_h0 = reject_h0
  ))
}




