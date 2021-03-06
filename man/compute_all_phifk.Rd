% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/RcppExports.R
\name{compute_all_phifk}
\alias{compute_all_phifk}
\title{Computes \deqn{\Phi^{-1}(F(k|K,\alpha_j,\rho_i))} for all possible (i,j,k).}
\usage{
compute_all_phifk(alpha, rho, ploidy)
}
\arguments{
\item{alpha}{A vector whose jth element is the allele frequency of SNP j.}

\item{rho}{A vector whose ith element is the inbreeding coefficient of individual i.}

\item{ploidy}{The ploidy of the species.}
}
\value{
A three dimensional array. The rows index the individuals,
    the columns index the SNPs, and the third dimension indexes the
    genotypes. Computes the "continuous genotype".
}
\description{
Computes \deqn{\Phi^{-1}(F(k|K,\alpha_j,\rho_i))} for all possible (i,j,k).
}
\author{
David Gerard
}
