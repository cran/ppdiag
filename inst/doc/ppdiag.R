## ---- include = FALSE---------------------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>"
)
set.seed(100) # to make it reproducible

## ----setup--------------------------------------------------------------------
# remotes::install_github("OwenWard/ppdiag")
library(ppdiag)

## -----------------------------------------------------------------------------
hpp_obj <- pp_hpp(lambda = 1)
hpp_obj

## -----------------------------------------------------------------------------
hp_obj <- pp_hp(lambda0 = 0.5, alpha = 0.2, beta = 0.5)
hp_obj

## -----------------------------------------------------------------------------
Q <- matrix(c(-0.4, 0.4, 0.2, -0.2), ncol = 2, byrow = TRUE)

mmpp_obj <- pp_mmpp(Q, delta = c(1 / 3, 2 / 3), 
          lambda0 = 0.8,
          c = 1.2)

mmpp_obj

## -----------------------------------------------------------------------------
mmhp_obj <- pp_mmhp(Q, delta = c(1 / 3, 2 / 3), 
          lambda0 = 0.2,
          lambda1 = .75,
          alpha = 0.1,
          beta = 0.2)

mmhp_obj


## -----------------------------------------------------------------------------
hpp_events <- pp_simulate(hpp_obj, end = 10)
hpp_events

## -----------------------------------------------------------------------------
hp_events <- pp_simulate(hp_obj, start = 0, n = 20)
hp_events


## -----------------------------------------------------------------------------
mmhp_events <- pp_simulate(object = mmhp_obj, n = 20)
mmhp_events

## -----------------------------------------------------------------------------
fit_hpp <- fithpp(hpp_events)
fit_hpp

## -----------------------------------------------------------------------------
hp_events <- pp_simulate(hp_obj, n = 500)
fit_hp <- fithp(hp_events)
fit_hp$lambda0
fit_hp$alpha
fit_hp$beta

## ----fig.width=4,fig.height=4-------------------------------------------------
drawHPPIntensity(fit_hpp, events = hpp_events,
                 color = "red")

## ----fig.width=4,fig.height=5-------------------------------------------------
drawHPIntensity(fit_hp, events = hp_events)

## ----fig.width=4,fig.height=5-------------------------------------------------
drawHPIntensity(events = hp_events, fit = TRUE)

## ----fig.width=4,fig.height=5-------------------------------------------------
drawUniMMHPIntensity(mmhp_obj, mmhp_events)

## ----intensityqqplot, fig.width=6, fig.height=5-------------------------------
intensityqqplot(object = fit_hp, events = hp_events )

## ----intqqpot mmhp, eval=FALSE------------------------------------------------
#  # this gives an error currently
#  intensityqqplot(object = mmhp_obj, markov_states = mmhp_events)

## ----mmhp_residual------------------------------------------------------------
pp_residual(object = mmhp_obj, events = mmhp_events$events)

pp_residual(object = fit_hp, events = hp_events)


## ----ppdiag hp, fig.width = 6, fig.height=4-----------------------------------
pp_diag(object = fit_hp, events = hp_events)

