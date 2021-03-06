% Generated by roxygen2 (4.1.1): do not edit by hand
% Please edit documentation in R/latent.R
\name{latent}
\alias{latent}
\title{Estimate parameters of a latent variable model}
\usage{
latent(data, min.detect, event, specific = NULL, verbose = TRUE)
}
\arguments{
\item{data}{matrix of observed counts, number of rows equal to the number of
observations and columns equal to the number of categories.}

\item{min.detect}{minimum limit of detection for the FIB assay - values
below this threshold are censored}

\item{event}{vector of event assignment labels, one entry per row of data.
Indicates the event to which each row of data belongs.}

\item{specific}{vector of TRUE/FALSE values, one entry per column of data.
Each entry indicates whether the corresponding FIB species is
human-specific.}

\item{verbose}{should the function provide verbose output about its
    progress? Defaults to TRUE.}
}
\value{
A list containing the following elements:
    \item{data}{final version of the data, where censored values have been
        imputed by the EM algorithm (see \code{\link{E.step}})}
    \item{min.detect}{a vector where each element is the minimum level of
        detection for the corresponding column of data (copied from function
        input)}
    \item{event}{vector listing the event ID associated with the
        corresponding row of the data (copied from the input)}
    \item{specific}{vector indicating whether the corresponding column of
        the data is a human-specific indicator bacteria - in which case its
        intercept is set to zero (copied from input)}
    \item{alpha}{matrix of estimated intercept parameters for each indicator
        bacteria for each event - each row is for one event, and each column
        is for one species of bacteria}
    \item{beta}{vector of estimated slope parameters for the indicator
        bacteria, representing the expected marginal increase in log-
        concentration when the contamination index increases by one unit}
    \item{gamma}{vector of estimated contamination indices, one for each row
        of the data}
}
\description{
Estimate the parameters of a latent variable model. Estimation is by the
method of maximum likelihood, with conjugate gradient descent used to
maximize likelihood. An EM algorithm is used to impute the values for
censored observations.
}
\examples{
# This script is an example of using the latent package to
# estimate the parameters of a latent variable model for the
# FIB counts in the storm sewer data set (with event 3 removed).

# Import data, drop event 3, change mei[4] from "TNTC" to 0, and then
# convert all FIB to numerics:
data("dfOptAnalysisDataSSJan2015")
indx = which(dfOptAnalysisDataSSJan2015$Event != "03")
fib = dfOptAnalysisDataSSJan2015[indx, c("mei", "modmtec", "FC",
    "Bac.human", "Lachno.2")]
fib$mei[4] = 0
for (n in names(fib))
    fib[[n]] = as.numeric(fib[[n]])

# Set the censoring values for each of the FIB (these are guesstimates)
min.detect = c('mei'=1, 'modmtec'=1, 'FC'=1, 'Bac.human'=225,
    'Lachno.2'=225)

# The human-specific FIB are Bac.human and Lachno.2, which are the fourth
# and fifth columns
specific = c(FALSE, FALSE, FALSE, TRUE, TRUE)

# Get the event IDs
event = as.integer(dfOptAnalysisDataSSJan2015$Event[indx])

# Now estimate the model parameters:
latent(fib, min.detect, event, specific)
}

