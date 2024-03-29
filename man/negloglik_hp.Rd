% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/fithp.R
\name{negloglik_hp}
\alias{negloglik_hp}
\title{Fit a Hawkes process with exponential kernel to event data}
\usage{
negloglik_hp(vec, events, end = max(events))
}
\arguments{
\item{vec}{vector containing initial values for the
object parameters (lambda0,alpha,beta) to be optimized.}

\item{events}{vector containing event times.}

\item{end}{the end time of event times.}
}
\description{
Compute the negative log likelihood parameter values for hawkes process.
}
\keyword{internal}
