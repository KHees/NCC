% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/get_ss_matrix.R
\name{get_ss_matrix}
\alias{get_ss_matrix}
\title{Sample size matrix for a platform trial with an arbitrary number of treatment arms}
\usage{
get_ss_matrix(num_arms, n_arm, d)
}
\arguments{
\item{num_arms}{Number of experimental treatment arms in the trial.}

\item{n_arm}{Sample size per experimental treatment arm.}

\item{d}{Vector with timings of adding new arms in terms of number of patients recruited to the trial so far (of length \code{num_arms}). The first entry must be 0, as the trial is supposed to start with at least one treatment.}
}
\value{
Sample size matrix, consisting of the sample size per arm and per period, where the arms are represented in the rows (with the control arm in the first row and the experimental arms coming after ordered by entry time) and the periods are represented in the columns.
}
\description{
This function computes the sample size matrix necessary for the functions \code{datasim_bin()} and \code{datasim_cont()}.
}
\examples{

get_ss_matrix(num_arms = 3, n_arm = 100, d = c(0, 100, 250))

}
\author{
Pavla Krotka
}
