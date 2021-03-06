% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/RcppExports.R
\name{dbetabinom_alpha_beta_double}
\alias{dbetabinom_alpha_beta_double}
\title{Density function of betabinomial with the shape parameterizations}
\usage{
dbetabinom_alpha_beta_double(x, size, alpha, beta, log)
}
\arguments{
\item{x}{The quantile.}

\item{size}{The total number of draws.}

\item{alpha}{The first shape parameter.}

\item{beta}{The second shape parameter.}

\item{log}{A logical. Should we return the log of the
density \code{TRUE} or not \code{FALSE}?}
}
\value{
The density of the beta-binomial.
}
\description{
Density function of betabinomial with the shape parameterizations
}
\author{
David Gerard
}
