## ---- include = FALSE---------------------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  eval = FALSE,
  comment = "#>"
)
set.seed(100) # to make it reproducible
options(rmarkdown.html_vignette.check_title = FALSE)

## ----setup--------------------------------------------------------------------
#  library(ppdiag)
#  library(rstan)
#  library(cmdstanr)
#  library(tidyverse)
#  library(bayesplot)

## ----mmpp-stan-code-----------------------------------------------------------
#  mmpp_stan_code <- "
#  data{
#    int<lower=1> num_events; //maximum of number of events for each pair each window => max(unlist(lapply(return_df$event.times,length))))
#    vector[num_events+1] time_matrix; // include termination time in the last entry
#  }
#  parameters{
#    real<lower=0> lambda0; //baseline rate for each pair
#    real<lower=0> c; //baseline rate for each pair
#    real<lower=0,upper=1> w1; //CTMC transition rate
#    real<lower=0,upper=1> w2; //CTMC transition rate
#  }
#  transformed parameters{
#    real<lower=0> q1;
#    real<lower=0> q2;
#    q1 = (lambda0).*w1;
#    q2 = (lambda0).*w2;
#  }
#  model{
#    real integ; // Placeholder variable for calculating integrals
#    row_vector[2] forward[num_events]; // Forward variables from forward-backward algorithm
#    row_vector[2] forward_termination;
#    row_vector[2] probs_1[num_events+1]; // Probability vector for transition to state 1 (active state)
#    row_vector[2] probs_2[num_events+1]; // Probability vector for transition to state 2 (inactive state)
#    vector[num_events+1] interevent;
#  
#    //priors
#    c ~ lognormal(0,1);
#    w1 ~ beta(0.5,0.5);
#    w2 ~ beta(0.5,0.5);
#  
#    lambda0 ~ gamma(1, 1);
#    interevent = time_matrix;
#    // ---- prepare for forward algorithm
#    // --- log probability of Markov transition logP_ij(t)
#    for(n in 1:(num_events + 1)){
#      probs_1[n][1] = log(q2/(q1+q2)+q1/(q1+q2)*exp(-(q1+q2)*interevent[n])); //1->1
#      probs_2[n][2] = log(q1/(q1+q2)+q2/(q1+q2)*exp(-(q1+q2)*interevent[n])); //2->2
#      probs_1[n][2] = log1m_exp(probs_2[n][2]); //2->1
#      probs_2[n][1] = log1m_exp(probs_1[n][1]); //1->2
#    }
#    //consider n = 1
#    integ = interevent[1]*lambda0;
#    forward[1][1] = log_sum_exp(probs_1[1]) + log(lambda0*(1+c)) - integ*(1+c);
#    forward[1][2] = log_sum_exp(probs_2[1]) + log(lambda0) - integ;
#  
#    if(num_events>1){
#      for(n in 2:num_events){
#        integ = interevent[n]*lambda0;
#        forward[n][1] = log_sum_exp(forward[n-1] + probs_1[n]) + log(lambda0*(1+c))- integ*(1+c);
#        forward[n][2] = log_sum_exp(forward[n-1] + probs_2[n]) + log(lambda0) - integ;
#      }
#    }
#  
#    integ = interevent[num_events]*lambda0;
#    forward_termination[1] = log_sum_exp(forward[num_events] + probs_1[num_events]) - integ*(1+c);
#    forward_termination[2] = log_sum_exp(forward[num_events] + probs_2[num_events]) - integ;
#  
#    target += log_sum_exp(forward_termination);
#  }
#  "
#  

## ----mmhp-stan-code-----------------------------------------------------------
#  mmhp_stan_code <- "
#  data{
#    int<lower=1> num_events; //number of events
#    vector[num_events+1] time_matrix; // include termination time as last entry
#  }
#  parameters{
#    real<lower=0> lambda0; //baseline rate for each pair
#    real<lower=0> w_lambda;
#    real<lower=0, upper=1> w_q1; //CTMC transition rate
#    real<lower=0, upper=1> w_q2; //
#    real<lower=0> alpha;
#    real<lower=0> beta_delta;
#    real<lower=0,upper=1> delta_1; // P(initial state = 1)
#  }
#  transformed parameters{
#    real<lower=0> lambda1;
#    real<lower=0> q1;
#    real<lower=0> q2;
#    row_vector[2] log_delta;
#    real<lower=0> beta;
#    lambda1 = (lambda0).*(1+w_lambda);
#    q2 = (lambda0).*w_q2;
#    q1 = (lambda0).*w_q1;
#    log_delta[1] = log(delta_1);
#    log_delta[2] = log(1-delta_1);
#    beta = alpha*(1+beta_delta);
#  }
#  model{
#    real integ; // Placeholder variable for calculating integrals
#    row_vector[2] forward[num_events]; // Forward variables from forward-backward algorithm
#    row_vector[2] forward_termination; // Forward variables at termination time
#    row_vector[2] probs_1[num_events+1]; // Probability vector for transition to state 1 (active state)
#    row_vector[2] probs_2[num_events+1]; // Probability vector for transition to state 2 (inactive state)
#    row_vector[2] int_1[num_events+1]; // Integration of lambda when state transit to 1 (active state)
#    row_vector[2] int_2[num_events+1]; // Integration of lambda when state transit to 2 (inactive state)
#    real R[num_events+1]; // record variable for Hawkes process
#    vector[num_events+1] interevent;
#    real K0;
#    real K1;
#    real K2;
#    real K3;
#    real K4;
#    real K5;
#    //priors
#    w_lambda ~ gamma(1,1);
#    alpha ~ gamma(1,1);//lognormal(0,1);
#    beta_delta ~ lognormal(0,2);//normal(0,10);
#    //delta_1 ~ beta(2,2);
#    w_q1 ~ beta(2,2);
#    w_q2 ~ beta(2,2);
#  
#  
#    lambda0 ~ gamma(1,1);
#    interevent = time_matrix;
#    if(num_events==0){ // there is no event occured in this period
#      //--- prepare for forward calculation
#      probs_1[1][1] = log(q2/(q1+q2)+q1/(q1+q2)*exp(-(q1+q2)*interevent[1])); //1->1
#      probs_2[1][2] = log(q1/(q1+q2)+q2/(q1+q2)*exp(-(q1+q2)*interevent[1])); //2->2
#      probs_1[1][2] = log1m_exp(probs_2[1][2]); //2->1
#      probs_2[1][1] = log1m_exp(probs_1[1][1]); //1->2
#      R[1] = 0;
#      K0 = exp(-(q1+q2)*interevent[1]);
#      K1 = (1-exp(-(q1+q2)*interevent[1]))/(q1+q2);
#      K2 = (1-exp(-(q1+q2)*interevent[1]))/(q1+q2);
#      int_1[1][1] = ((q2^2*lambda1+q2*q1*lambda0)*interevent[1] +
#                       (q1^2*lambda1+q2*q1*lambda0)*K0*interevent[1] +
#                       (lambda1-lambda0)*q2*q1*K1 + (lambda1-lambda0)*q2*q1*K2)/(q1+q2)^2/exp(probs_1[1][1]); //1->1
#      int_1[1][2] = ((q2^2*lambda1+lambda0*q1*q2)*interevent[1] -
#                       (lambda1*q1*q2+lambda0*q2^2)*K0*interevent[1] +
#                       (lambda0-lambda1)*q2^2*K1 + (lambda1-lambda0)*q1*q2*K2)/(q1+q2)^2/exp(probs_1[1][2]); //2->1
#      int_2[1][1] = ((q1*q2*lambda1+q1^2*lambda0)*interevent[1] -
#                       (q1^2*lambda1+q1*q2*lambda0)*K0*interevent[1] +
#                       (lambda1-lambda0)*q1^2*K1 + q1*q2*(lambda0-lambda1)*K2)/(q1+q2)^2/exp(probs_2[1][1]); //1->2
#      int_2[1][2] = ((q1*q2*lambda1+lambda0*q1^2)*interevent[1] +
#                       (q1*q2*lambda1+lambda0*q2^2)*K0*interevent[1] +
#                       (lambda0-lambda1)*q1*q2*K1 + (lambda0-lambda1)*q1*q2*K2)/(q1+q2)^2/exp(probs_2[1][2]); //2->2
#  
#      forward_termination[1] = log_sum_exp(log_delta + probs_1[1] - int_1[1]);
#      forward_termination[2] = log_sum_exp(log_delta + probs_2[1] - int_2[1]);
#      target += log_sum_exp(forward_termination);
#      //target += -lambda0*interevent[1]*delta_1-lambda1*interevent[1]*(1-delta_1);
#    }else{ // there is event occured
#      // ---- prepare for forward algorithm
#      // --- log probability of Markov transition logP_ij(t)
#      for(n in 1:(num_events + 1)){ //changed this
#        probs_1[n][1] = log(q2/(q1+q2)+q1/(q1+q2)*exp(-(q1+q2)*interevent[n])); //1->1
#        probs_2[n][2] = log(q1/(q1+q2)+q2/(q1+q2)*exp(-(q1+q2)*interevent[n])); //2->2
#        probs_1[n][2] = log1m_exp(probs_2[n][2]); //2->1
#        probs_2[n][1] = log1m_exp(probs_1[n][1]); //1->2
#      }
#  
#      // --- R for Hawkes
#      R[1] = 0;
#      for(n in 2:(num_events + 1)){ // and this
#        R[n] = exp(-beta*interevent[n])*(R[n-1]+1);
#      }
#  
#      // Integration of lambda
#      for(n in 1:(num_events)){ //and this
#        K0 = exp(-(q1+q2)*interevent[n]);
#        K1 = (1-exp(-(q1+q2)*interevent[n]))/(q1+q2);
#        K2 = (1-exp(-(q1+q2)*interevent[n]))/(q1+q2);
#        K3 = R[n]*(exp(beta*interevent[n])-1)/beta;
#        K4 = R[n]*(1-exp(-(beta+q1+q2)*interevent[n]))*exp(beta*interevent[n])/(beta+q1+q2);
#        K5 = R[n]*(1-exp(-(q1+q2-beta)*interevent[n]))/(q1+q2-beta);
#        int_1[n][1] = ((q2^2*lambda1+q2*q1*lambda0)*interevent[n] +
#                         (q1^2*lambda1+q2*q1*lambda0)*K0*interevent[n] +
#                         (lambda1-lambda0)*q2*q1*K1 + (lambda1-lambda0)*q2*q1*K2 +
#                         alpha*K3*(q2^2+q1^2*K0) +
#                         alpha*q1*q2*K4 + alpha*q1*q2*K5)/(q1+q2)^2/exp(probs_1[n][1]); //1->1
#        int_1[n][2] = ((q2^2*lambda1+lambda0*q1*q2)*interevent[n] -
#                         (lambda1*q1*q2+lambda0*q2^2)*K0*interevent[n] +
#                         (lambda0-lambda1)*q2^2*K1 + (lambda1-lambda0)*q1*q2*K2 +
#                         alpha*q2*K3*(q2-q1*K0) -
#                         alpha*q2^2*K4 + alpha*q1*q2*K5)/(q1+q2)^2/exp(probs_1[n][2]); //2->1
#        int_2[n][1] = ((q1*q2*lambda1+q1^2*lambda0)*interevent[n] -
#                         (q1^2*lambda1+q1*q2*lambda0)*K0*interevent[n] +
#                         (lambda1-lambda0)*q1^2*K1 + q1*q2*(lambda0-lambda1)*K2 +
#                         alpha*q1*K3*(q2-q1*K0) +
#                         alpha*q1^2*K4 - alpha*q2*q1*K5)/(q1+q2)^2/exp(probs_2[n][1]); //1->2
#        int_2[n][2] = ((q1*q2*lambda1+lambda0*q1^2)*interevent[n] +
#                         (q1*q2*lambda1+lambda0*q2^2)*K0*interevent[n] +
#                         (lambda0-lambda1)*q1*q2*K1 + (lambda0-lambda1)*q1*q2*K2 +
#                         alpha*q1*q2*K3*(1+K0) -
#                         alpha*q1*q2*K4 - alpha*q1*q2*K5)/(q1+q2)^2/exp(probs_2[n][2]); //2->2
#      }
#  
#      //consider n = 1
#      forward[1][1] = log(lambda1) + log_sum_exp(probs_1[1]-int_1[1]+log_delta);
#      forward[1][2] = log(lambda0) + log_sum_exp(probs_2[1]-int_2[1]+log_delta);
#  
#      if(num_events>1){
#        for(n in 2:num_events){
#          forward[n][1] = log_sum_exp(forward[n-1] + probs_1[n] - int_1[n]) + log(lambda1+alpha*R[n]);
#          forward[n][2] = log_sum_exp(forward[n-1] + probs_2[n] - int_2[n]) + log(lambda0);
#        }
#      }
#  
#      forward_termination[1] = log_sum_exp(forward[num_events] + probs_1[num_events] - int_1[num_events]);
#      forward_termination[2] = log_sum_exp(forward[num_events] + probs_2[num_events] - int_2[num_events]);
#      // lots of places with max_Nm and Nm got rid of the +1
#      target += log_sum_exp(forward_termination);
#    }
#  }
#  "
#  

## ----sim-mmpp-----------------------------------------------------------------
#  Q <- matrix(c(-0.4, 0.4, 0.2, -0.2), ncol = 2, byrow = TRUE)
#  mmpp_obj <- pp_mmpp(Q = Q, lambda0 = 1, c = 1.5, delta = c(1/3, 2/3))
#  
#  sim_mmpp <- pp_simulate(mmpp_obj, n = 50)

## ----rstan-mmpp---------------------------------------------------------------
#  mmpp_data <- list(num_events = length(sim_mmpp$events) - 1,
#                    # as first event is start time (0)
#                    time_matrix = diff(c(sim_mmpp$events, sim_mmpp$end))
#                    #interevent arrival time
#                    )
#  
#  mmpp_rstan <- stan(model_code = mmpp_stan_code,
#                     data = mmpp_data,
#                     chains = 2)
#  mmpp_sim <- rstan::extract(mmpp_rstan)

## ----mmpp-plot----------------------------------------------------------------
#  bayesplot::mcmc_hist(as.matrix(mmpp_rstan), pars = c("lambda0", "c"))

## ----mmpp-post----------------------------------------------------------------
#  mmpp_post <- lapply(mmpp_sim, mean)

## ----sim-mmhp-----------------------------------------------------------------
#  Q <- matrix(c(-0.4, 0.4, 0.2, -0.2), ncol = 2, byrow = TRUE)
#  mmhp_obj <- pp_mmhp(Q = Q, lambda0 = 0.5, lambda1 = 1.5,
#                      alpha = 0.5, beta = 0.75, delta = c(1/3, 2/3))
#  
#  sim_mmhp <- pp_simulate(mmhp_obj, n = 50)
#  
#  
#  mmhp_data <- list(num_events = length(sim_mmhp$events) - 1,
#                    # as first event is start time (0)
#                    time_matrix = diff(c(sim_mmhp$events, sim_mmhp$end))
#                    #interevent arrival time
#                    )

## ----rstan-mmhp---------------------------------------------------------------
#  mmhp_rstan <- stan(model_code = mmhp_stan_code,
#                     data = mmhp_data,
#                     chains = 2)
#  mmhp_sim <- rstan::extract(mmhp_rstan)
#  mmhp_post <- lapply(mmhp_sim, mean)

## ----plot-draws-mmhp----------------------------------------------------------
#  bayesplot::mcmc_hist(as.matrix(mmhp_rstan),
#                       pars = c("lambda0", "lambda1", "alpha", "beta"))

## ----mmpp-fit, eval=FALSE-----------------------------------------------------
#  mmpp_file <- write_stan_file(mmpp_stan_code)
#  mmpp_stan <- cmdstan_model(stan_file = mmpp_file)
#  
#  fit_mmpp <- mmpp_stan$sample(data = mmpp_data,
#                               seed = 123,
#                               chains = 4,
#                               parallel_chains = 4,
#                               refresh = 500)

## ----compile-mmhp, eval=FALSE-------------------------------------------------
#  mmhp_file <- write_stan_file(mmhp_stan_code)
#  mmhp_stan <- cmdstan_model(stan_file = mmhp_file)
#  
#  fit_mmhp <- mmhp_stan$sample(data = mmhp_data,
#                               seed = 123,
#                               chains = 4,
#                               parallel_chains = 4,
#                               refresh = 500)

## ----mmpp-ppdiag, fig.width=8-------------------------------------------------
#  mmpp_fit_obj <- pp_mmpp(lambda0 = mmpp_post$lambda0,
#                         c = mmpp_post$c,
#                         Q = matrix( c(-mmpp_post$q1,
#                                       mmpp_post$q1,
#                                       mmpp_post$q2,
#                                       -mmpp_post$q2),
#                                     nrow = 2, ncol = 2, byrow = T) )
#  
#  
#  pp_diag(mmpp_fit_obj, events = sim_mmpp$events)
#  

## ----mmhp-ppdiag, fig.width=8-------------------------------------------------
#  mmhp_fit_obj <- pp_mmhp(lambda0 = mmhp_post$lambda0,
#                          lambda1 = mmhp_post$lambda1,
#                          alpha = mmhp_post$alpha,
#                          beta = mmhp_post$beta,
#                          Q = matrix( c(-mmhp_post$q1,
#                                        mmhp_post$q1,
#                                        mmhp_post$q2,
#                                        -mmhp_post$q2),
#                                   nrow = 2, ncol = 2, byrow = T) )
#  
#  pp_diag(mmhp_fit_obj, events = sim_mmhp$events)
#  

