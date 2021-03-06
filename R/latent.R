#' Estimate parameters of a latent variable model
#' 
#' Estimate the parameters of a latent variable model. Estimation is by the
#' method of maximum likelihood, with conjugate gradient descent used to 
#' maximize likelihood. An EM algorithm is used to impute the values for
#' censored observations.
#' 
#' @param data matrix of observed counts, number of rows equal to the number of
#'     observations and columns equal to the number of categories.
#' @param min.detect minimum limit of detection for the FIB assay - values
#'     below this threshold are censored
#' @param event vector of event assignment labels, one entry per row of data.
#'     Indicates the event to which each row of data belongs.
#' @param specific vector of TRUE/FALSE values, one entry per column of data.
#'     Each entry indicates whether the corresponding FIB species is
#'     human-specific.
#' @param verbose should the function provide verbose output about its
#'     progress? Defaults to TRUE.
#' 
#' @return A list containing the following elements:
#'     \item{data}{final version of the data, where censored values have been
#'         imputed by the EM algorithm (see \code{\link{E.step}})}
#'     \item{min.detect}{a vector where each element is the minimum level of
#'         detection for the corresponding column of data (copied from function
#'         input)}
#'     \item{event}{vector listing the event ID associated with the
#'         corresponding row of the data (copied from the input)}
#'     \item{specific}{vector indicating whether the corresponding column of
#'         the data is a human-specific indicator bacteria - in which case its
#'         intercept is set to zero (copied from input)}
#'     \item{alpha}{matrix of estimated intercept parameters for each indicator
#'         bacteria for each event - each row is for one event, and each column
#'         is for one species of bacteria}
#'     \item{beta}{vector of estimated slope parameters for the indicator
#'         bacteria, representing the expected marginal increase in log-
#'         concentration when the contamination index increases by one unit}
#'     \item{gamma}{vector of estimated contamination indices, one for each row
#'         of the data}
#' 
#' @examples # This script is an example of using the latent package to 
#' # estimate the parameters of a latent variable model for the
#' # FIB counts in the storm sewer data set (with event 3 removed).
#' 
#' # Import data, drop event 3, change mei[4] from "TNTC" to 0, and then
#' # convert all FIB to numerics:
#' data("dfOptAnalysisDataSSJan2015")
#' indx = which(dfOptAnalysisDataSSJan2015$Event != "03")
#' fib = dfOptAnalysisDataSSJan2015[indx, c("mei", "modmtec", "FC",
#'     "Bac.human", "Lachno.2")]
#' fib$mei[4] = 0
#' for (n in names(fib))
#'     fib[[n]] = as.numeric(fib[[n]])
#' 
#' # Set the censoring values for each of the FIB (these are guesstimates)
#' min.detect = c('mei'=1, 'modmtec'=1, 'FC'=1, 'Bac.human'=225,
#'     'Lachno.2'=225)
#' 
#' # The human-specific FIB are Bac.human and Lachno.2, which are the fourth
#' # and fifth columns
#' specific = c(FALSE, FALSE, FALSE, TRUE, TRUE)
#' 
#' # Get the event IDs
#' event = as.integer(dfOptAnalysisDataSSJan2015$Event[indx])
#' 
#' # Now estimate the model parameters:
#' latent(fib, min.detect, event, specific)
#' 
#' @export
latent <- function(data, min.detect, event, specific=NULL, verbose=TRUE) {
    #Initial parameters:
    n = nrow(data)
    p = ncol(data)
    xx = c(rep(as.integer(!specific), length(unique(event))), rep(1, n+p))
    finished = FALSE
    
    f.new = log.lik(data, xx, event)
    f.old = -Inf
    tol = sqrt(.Machine$double.eps)
    tol = 1e-5
    check=Inf
    
    while (!finished) {
        #These iterations restart conjugacy:
        converged = FALSE
        while (!converged) {
            
            #Prepare to iterate conjugate gradient descent:
            i=0
            f.outer = f.old
            f.old = -Inf
            t = 1
            while(f.new>f.old && !converged && i<length(xx)) {
                i = i+1
        
                dir.new = score(data, xx, event, specific=specific)
                dir.new = dir.new / sqrt(sum(dir.new^2))
                
                #First iteration, ignore conjugacy - thereafter, use it.
                #s.new is the vector of the new step (in parameter space)
                if (i==1) {  
                    s.new = dir.new
                } else {
                    conj = (sum(dir.new^2) + sum(dir.new * dir.old)) / sum(dir.old^2)
                    s.new = dir.new + conj * s.old
                }
                
                #Find the optimal step size
                #Backtracking: stop when the loss function is majorized
                condition = (log.lik(data, xx + t*s.new, event) < f.new + sum((t*s.new)*dir.new) + 1/(2*t)*sum((t*s.new)^2))[1]
                while( condition ) {
                    condition = (log.lik(data, xx + t*s.new, event) < f.new + sum((t*s.new)*dir.new) + 1/(2*t)*sum((t*s.new)^2))[1]
                    
                    #This is the final stopping rule: t gets so small that 1/(2*t) is Inf
                    if (is.na(condition)) {
                        converged = TRUE
                        condition = FALSE
                    }
                    
                    t = 0.8*t
                }
                
                #Find the optimal step
                step = s.new * t
                
                #Make t a little bigger so next iteration has option to make larger step:
                t = t / 0.8 / 0.8
                p = xx + step
                
                #save for next iteration:
                dir.old = dir.new
                s.old = s.new
                
                #Only save the new parameters if they've decreased the loss function
                f.proposed = log.lik(data, p, event)
                if (f.proposed > f.old)
                    xx = p
                f.old = f.new
                f.new = f.proposed
            }
            
            if (verbose) cat(paste("Likelihood objective: ", f.new, "\n", sep=""))
            
            
            if ((f.new - f.outer) < tol * f.outer) converged = TRUE
        }
        
        d = length(unique(event))
        p = ncol(data)
        
        alpha = xx[1:(d*p)]
        beta = xx[d*p + 1:p]
        gamma = xx[((d+1)*p+1):length(xx)]
        data.new = E.step(alpha, beta, gamma, data, min.detect, event)
        
        check.old = check
        check = sum((data.new - data)^2, na.rm=TRUE) / sum(data^2, na.rm=TRUE)
        data = data.new
        
        if (check.old - check < (abs(check.old) + tol)*tol) {
            if (tol<=sqrt(.Machine$double.eps))
                finished = TRUE
            tol = max(tol/2, sqrt(.Machine$double.eps))
            cat(paste("Iterating with tol=", tol, "\n", sep=""))
        }
    }
    
    #Compile the results and return
    result = list()
    result$data = data
    result$min.detect = min.detect
    result$event = event
    result$specific = specific
    result$alpha = matrix(alpha, d, p, byrow=TRUE)
    colnames(result$alpha) = names(result$beta)
    result$beta = beta
    result$gamma = gamma
    
    return(result)
}