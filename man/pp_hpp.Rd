% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/pp_hpp.R
\name{pp_hpp}
\alias{pp_hpp}
\title{Create a homogeneous Poisson process object}
\usage{
pp_hpp(lambda, events = NULL)
}
\arguments{
\item{lambda}{rate of the Poisson process}

\item{events}{event times, optional}
}
\value{
hpp object
}
\description{
Create a homogeneous Poisson object according to given parameters:
lambda, and events.
If events are missing, then it means that data will be
added later(simulated from this process).
}
\examples{
pp_hpp(lambda = 1)
}
