% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/RcppExports.R
\name{flexdog_obj}
\alias{flexdog_obj}
\title{Log-likelihood that \code{\link{flexdog}} maximizes.}
\usage{
flexdog_obj(probk_vec, refvec, sizevec, ploidy, seq, bias, od, mean_bias,
  var_bias, mean_seq, var_seq)
}
\arguments{
\item{probk_vec}{The kth element is the prior probability of genotype k (when starting to count from 0).}

\item{refvec}{A vector of counts of reads of the reference allele.}

\item{sizevec}{A vector of total counts.}

\item{ploidy}{The ploidy of the species. Assumed to be the same for each
individual.}

\item{seq}{The starting value of the sequencing error rate.}

\item{bias}{The starting value of the bias.}

\item{od}{The starting value of the overdispersion parameter.}

\item{mean_bias}{The prior mean of the log-bias.}

\item{var_bias}{The prior variance of the log-bias.}

\item{mean_seq}{The prior mean of the logit of the sequencing
error rate.}

\item{var_seq}{The prior variance of the logit of the sequencing
error rate.}
}
\value{
The objective (marginal log-likelihood) used in
    \code{\link{flexdog_full}}.
}
\description{
Log-likelihood that \code{\link{flexdog}} maximizes.
}
\author{
David Gerard
}
