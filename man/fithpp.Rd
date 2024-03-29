% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/fithpp.R
\name{fithpp}
\alias{fithpp}
\title{Fit a homogeneous poisson process to event data}
\usage{
fithpp(events, end = max(events))
}
\arguments{
\item{events}{vector containing the event times.}

\item{end}{end of observation period, starting from 0 (default is last event)}
}
\value{
a hpp object containing the events and the estimated parameter
}
\description{
Compute maximum likelihood estimator of the rate of a homogeneous Poisson
process for the given events.
}
\examples{
pois_y <- pp_hpp(lambda = 1)
events <- pp_simulate(pois_y, end = 10)
fithpp(events)
}
