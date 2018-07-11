## Functions for updating the preferential pairing model

#' Function to update the parameters in the preferential pairing model.
#'
#' @inheritParams flex_update_pivec
#'
#' @return A list with the following elements:
#' \describe{
#' \item{\code{p1_pair_weights}}{A list with the mixing weights for the
#'     bivalent components of parent 1.}
#' \item{\code{p2_pair_weights}}{A list with the mixing weights for the
#'     bivalent components of parent 2.}
#' \item{\code{obj}}{The maximized objective.}
#' \item{\code{p1geno}}{The estimated genotype for parent 1.}
#' \item{\code{p2geno}}{The estimated genotype for parent 2.}
#' \item{\code{pivec}}{The estimated genotype distribution for the
#'     offspring.}
#' }
#'
#' @author David Gerard
update_pp <- function(weight_vec,
                      model = c("f1pp", "s1pp"),
                      control) {
  model <- match.arg(model)
  assertthat::assert_that(!is.null(control$blist))
  assertthat::assert_that(!is.null(control$fs1_alpha))
  assertthat::assert_that(!is.null(control$p1_pair_weights))
  assertthat::assert_that(!is.null(control$pivec))
  if (model == "f1pp") {
    stopifnot(!is.null(control$p2_pair_weights))
  } else {
    control$p2_pair_weights <- control$p1_pair_weights
  }

  ploidy <- length(weight_vec) - 1

  ## number of mixing components for each genotype
  num_comp <- table(control$blist$lvec)
  return_list <- list()
  return_list$p1_pair_weights <- control$p1_pair_weights
  return_list$p2_pair_weights <- control$p2_pair_weights
  return_list$obj             <- -Inf
  return_list$p1geno          <- NA
  return_list$p2geno          <- NA
  return_list$pivec           <- rep(NA, length = ploidy + 1)

  for (p1geno in 0:ploidy) {
    if (model == "f1pp" & (!is.null(control$p1_lbb) | !is.null(control$p2_lbb))) {
      p2geno_vec <- 0:ploidy
    } else if (model == "f1pp") {
      p2geno_vec <- p1geno:ploidy
    } else {
      p2geno_vec <- p1geno
    }
    ## for pivec, I don't mix with uniform until very end ----
    for(p2geno in p2geno_vec) {
      temp_list <- list()
      if ((num_comp[p1geno + 1] == 1) & (num_comp[p2geno + 1] == 1)) {
        ## Just return likelihood
        p1_seg_prob <- control$blist$probmat[control$blist$lvec == p1geno, , drop = TRUE]
        p2_seg_prob <- control$blist$probmat[control$blist$lvec == p2geno, , drop = TRUE]
        temp_list$pivec <- c(convolve(p1_seg_prob, p2_seg_prob))
        temp_list$obj <- f1_obj(alpha = control$fs1_alpha,
                                pvec = temp_list$pivec,
                                weight_vec = weight_vec)
      } else if ((num_comp[p1geno + 1] == 1) & (num_comp[p2geno + 1] == 2)) {
        ## Brent on 2
        p1_seg_prob <- control$blist$probmat[control$blist$lvec == p1geno, , drop = TRUE]
        p2_seg_prob_mat <- control$blist$probmat[control$blist$lvec == p2geno, , drop = FALSE]
        firstmixweight <- control$p2_pair_weights[[p2geno + 1]][1]
        oout <- stats::optim(par        = firstmixweight,
                             method     = "Brent",
                             lower      = 10^-6,
                             upper      = 1 - 10^-6,
                             control    = list(fnscale = -1),
                             fn         = pp_brent_obj,
                             probmat    = p2_seg_prob_mat,
                             pvec       = p1_seg_prob,
                             weight_vec = weight_vec,
                             alpha      = control$fs1_alpha)
        return_list$p2_pair_weights[[p2geno + 1]][1] <- oout$par
        return_list$p2_pair_weights[[p2geno + 1]][2] <- 1 - oout$par

        temp_list$obj <- oout$value
        temp_list$pivec <- c(convolve(colSums(return_list$p2_pair_weights[[p2geno + 1]] * p2_seg_prob_mat), p1_seg_prob))
      } else if ((num_comp[p1geno + 1] == 1) & (num_comp[p2geno + 1] > 2)) {
        ## EM on 2.
        p1_seg_prob <- control$blist$probmat[control$blist$lvec == p1geno, , drop = TRUE]
        p2_seg_prob_mat <- control$blist$probmat[control$blist$lvec == p2geno, , drop = FALSE]

        lmat <- get_conv_inner_weights(psegprob = p1_seg_prob,
                                       psegmat  = p2_seg_prob_mat)

        initial_comp_weights <- control$p2_pair_weights[[p2geno + 1]]

        return_list$p2_pair_weights[[p2geno + 1]] <-
          c(uni_em_const(weight_vec = weight_vec,
                         lmat       = lmat,
                         pi_init    = initial_comp_weights,
                         alpha      = control$fs1_alpha,
                         lambda     = 0,
                         itermax    = 100,
                         obj_tol    = 10^-5))

        temp_list$pivec <- pivec_from_segmats(p1segmat = matrix(p1_seg_prob, nrow = 1),
                                              p2segmat = p2_seg_prob_mat,
                                              p1weight = 1,
                                              p2weight = return_list$p2_pair_weights[[p2geno + 1]])
        temp_list$obj <- uni_obj_const(pivec = return_list$p2_pair_weights[[p2geno + 1]],
                                       alpha = control$fs1_alpha,
                                       weight_vec = weight_vec,
                                       lmat = lmat,
                                       lambda = 0);
      } else if ((num_comp[p1geno + 1] == 2) & (num_comp[p2geno + 1] == 1)) {
        ## Brent on 1.
        p1_seg_prob_mat <- control$blist$probmat[control$blist$lvec == p1geno, , drop = FALSE]
        p2_seg_prob <- control$blist$probmat[control$blist$lvec == p2geno, , drop = TRUE]
        firstmixweight <- control$p1_pair_weights[[p1geno + 1]][1]
        oout <- stats::optim(par        = firstmixweight,
                             method     = "Brent",
                             lower      = 10^-6,
                             upper      = 1 - 10^-6,
                             control    = list(fnscale = -1),
                             fn         = pp_brent_obj,
                             probmat    = p1_seg_prob_mat,
                             pvec       = p2_seg_prob,
                             weight_vec = weight_vec,
                             alpha      = control$fs1_alpha)
        return_list$p1_pair_weights[[p1geno + 1]][1] <- oout$par
        return_list$p1_pair_weights[[p1geno + 1]][2] <- 1 - oout$par

        temp_list$obj <- oout$value
        temp_list$pivec <- c(convolve(colSums(return_list$p1_pair_weights[[p1geno + 1]] * p1_seg_prob_mat), p2_seg_prob))
      } else if ((num_comp[p1geno + 1] == 2) & (num_comp[p2geno + 1] == 2)) {
        ## Brent on both
        p1_seg_prob_mat <- control$blist$probmat[control$blist$lvec == p1geno, , drop = FALSE]
        p2_seg_prob_mat <- control$blist$probmat[control$blist$lvec == p2geno, , drop = FALSE]
        firstmixweight_p1 <- control$p1_pair_weights[[p1geno + 1]][1]
        firstmixweight_p2 <- control$p2_pair_weights[[p2geno + 1]][1]

        brent_obj     <- -Inf
        brent_tol     <- 10^-5
        brent_err     <- brent_tol + 1
        brent_iter    <- 1
        brent_itermax <- 100
        while ((brent_err > brent_tol) & (brent_iter < brent_itermax)) {
          brent_obj_old <- brent_obj

          ## Update firstmixweight_p1
          p2_seg_prob <- colSums(c(firstmixweight_p2, 1 - firstmixweight_p2) * p2_seg_prob_mat)
          oout <- stats::optim(par        = firstmixweight_p1,
                               method     = "Brent",
                               lower      = 10^-6,
                               upper      = 1 - 10^-6,
                               control    = list(fnscale = -1),
                               fn         = pp_brent_obj,
                               probmat    = p1_seg_prob_mat,
                               pvec       = p2_seg_prob,
                               weight_vec = weight_vec,
                               alpha      = control$fs1_alpha)
          firstmixweight_p1 <- oout$par

          ## Update firstmixweight_p2
          p1_seg_prob <- colSums(c(firstmixweight_p1, 1 - firstmixweight_p1) * p1_seg_prob_mat)
          oout <- stats::optim(par        = firstmixweight_p2,
                               method     = "Brent",
                               lower      = 10^-6,
                               upper      = 1 - 10^-6,
                               control    = list(fnscale = -1),
                               fn         = pp_brent_obj,
                               probmat    = p2_seg_prob_mat,
                               pvec       = p1_seg_prob,
                               weight_vec = weight_vec,
                               alpha      = control$fs1_alpha)
          firstmixweight_p2 <- oout$par
          brent_obj <- oout$value
          brent_err <- abs(brent_obj - brent_obj_old)
          brent_iter <- brent_iter + 1
        }

        temp_list$obj <- brent_obj

        return_list$p1_pair_weights[[p1geno + 1]][1] <- firstmixweight_p1
        return_list$p1_pair_weights[[p1geno + 1]][2] <- 1 - firstmixweight_p1

        return_list$p2_pair_weights[[p2geno + 1]][1] <- firstmixweight_p2
        return_list$p2_pair_weights[[p2geno + 1]][2] <- 1 - firstmixweight_p2

        p1_seg_prob <- colSums(c(firstmixweight_p1, 1 - firstmixweight_p1) * p1_seg_prob_mat)
        p2_seg_prob <- colSums(c(firstmixweight_p2, 1 - firstmixweight_p2) * p2_seg_prob_mat)

        temp_list$pivec <- convolve(p1_seg_prob, p2_seg_prob)

      } else if ((num_comp[p1geno + 1] == 2) & (num_comp[p2geno + 1] > 2)) {
        ## Brent on 1, EM on 2
        p1_seg_prob_mat   <- control$blist$probmat[control$blist$lvec == p1geno, , drop = FALSE]
        p2_seg_prob_mat   <- control$blist$probmat[control$blist$lvec == p2geno, , drop = FALSE]
        firstmixweight_p1 <- control$p1_pair_weights[[p1geno + 1]][1]
        p2_weight_vec     <- control$p2_pair_weights[[p2geno + 1]]

        brent_obj     <- -Inf
        brent_tol     <- 10^-5
        brent_err     <- brent_tol + 1
        brent_iter    <- 1
        brent_itermax <- 100
        while ((brent_err > brent_tol) & (brent_iter < brent_itermax)) {
          brent_obj_old <- brent_obj

          ## Update firstmixweight_p1
          p2_seg_prob <- colSums(p2_weight_vec * p2_seg_prob_mat)
          oout <- stats::optim(par        = firstmixweight_p1,
                               method     = "Brent",
                               lower      = 10^-6,
                               upper      = 1 - 10^-6,
                               control    = list(fnscale = -1),
                               fn         = pp_brent_obj,
                               probmat    = p1_seg_prob_mat,
                               pvec       = p2_seg_prob,
                               weight_vec = weight_vec,
                               alpha      = control$fs1_alpha)
          firstmixweight_p1 <- oout$par

          # Update p2_weight_vec
          p1_seg_prob <- colSums(c(firstmixweight_p1, 1 - firstmixweight_p1) * p1_seg_prob_mat)

          lmat <- get_conv_inner_weights(psegprob = p1_seg_prob,
                                         psegmat  = p2_seg_prob_mat)

          p2_weight_vec <- c(uni_em_const(weight_vec = weight_vec,
                                          lmat       = lmat,
                                          pi_init    = p2_weight_vec,
                                          alpha      = control$fs1_alpha,
                                          lambda     = 0,
                                          itermax    = 100,
                                          obj_tol    = 10^-5))

          brent_obj <- uni_obj_const(pivec = p2_weight_vec,
                                     alpha = control$fs1_alpha,
                                     weight_vec = weight_vec,
                                     lmat = lmat,
                                     lambda = 0);
          brent_err <- abs(brent_obj - brent_obj_old)
          brent_iter <- brent_iter + 1
        }

        temp_list$obj <- brent_obj

        return_list$p1_pair_weights[[p1geno + 1]][1] <- firstmixweight_p1
        return_list$p1_pair_weights[[p1geno + 1]][2] <- 1 - firstmixweight_p1

        return_list$p2_pair_weights[[p2geno + 1]] <- p2_weight_vec

        temp_list$pivec <- pivec_from_segmats(p1segmat = p1_seg_prob_mat,
                                              p2segmat = p2_seg_prob_mat,
                                              p1weight = return_list$p1_pair_weights[[p1geno + 1]],
                                              p2weight = return_list$p2_pair_weights[[p2geno + 1]])

      } else if ((num_comp[p1geno + 1] > 2) & (num_comp[p2geno + 1] == 1)) {
        ## EM on on 1.
        p1_seg_prob_mat <- control$blist$probmat[control$blist$lvec == p1geno, , drop = FALSE]
        p2_seg_prob     <- control$blist$probmat[control$blist$lvec == p2geno, , drop = TRUE]

        lmat <- get_conv_inner_weights(psegprob = p2_seg_prob,
                                       psegmat  = p1_seg_prob_mat)

        initial_comp_weights <- control$p1_pair_weights[[p1geno + 1]]

        return_list$p1_pair_weights[[p1geno + 1]] <-
          c(uni_em_const(weight_vec = weight_vec,
                         lmat       = lmat,
                         pi_init    = initial_comp_weights,
                         alpha      = control$fs1_alpha,
                         lambda     = 0,
                         itermax    = 100,
                         obj_tol    = 10^-5))

        temp_list$pivec <- pivec_from_segmats(p1segmat = p1_seg_prob_mat,
                                              p2segmat = matrix(p2_seg_prob, nrow = 1),
                                              p1weight = return_list$p1_pair_weights[[p1geno + 1]],
                                              p2weight = 1)
        temp_list$obj <- uni_obj_const(pivec = return_list$p1_pair_weights[[p1geno + 1]],
                                       alpha = control$fs1_alpha,
                                       weight_vec = weight_vec,
                                       lmat = lmat,
                                       lambda = 0);
      } else if ((num_comp[p1geno + 1] > 2) & (num_comp[p2geno + 1] == 2)) {
        ## EM on 1, Brent on 2
        p1_seg_prob_mat   <- control$blist$probmat[control$blist$lvec == p1geno, , drop = FALSE]
        p2_seg_prob_mat   <- control$blist$probmat[control$blist$lvec == p2geno, , drop = FALSE]
        firstmixweight_p2 <- control$p2_pair_weights[[p2geno + 1]][1]
        p1_weight_vec     <- control$p1_pair_weights[[p1geno + 1]]

        brent_obj     <- -Inf
        brent_tol     <- 10^-5
        brent_err     <- brent_tol + 1
        brent_iter    <- 1
        brent_itermax <- 100
        while ((brent_err > brent_tol) & (brent_iter < brent_itermax)) {
          brent_obj_old <- brent_obj

          ## Update firstmixweight_p2
          p1_seg_prob <- colSums(p1_weight_vec * p1_seg_prob_mat)
          oout <- stats::optim(par        = firstmixweight_p2,
                               method     = "Brent",
                               lower      = 10^-6,
                               upper      = 1 - 10^-6,
                               control    = list(fnscale = -1),
                               fn         = pp_brent_obj,
                               probmat    = p2_seg_prob_mat,
                               pvec       = p1_seg_prob,
                               weight_vec = weight_vec,
                               alpha      = control$fs1_alpha)
          firstmixweight_p2 <- oout$par

          # Update p1_weight_vec
          p2_seg_prob <- colSums(c(firstmixweight_p2, 1 - firstmixweight_p2) * p2_seg_prob_mat)

          lmat <- get_conv_inner_weights(psegprob = p2_seg_prob,
                                         psegmat  = p1_seg_prob_mat)

          p1_weight_vec <- c(uni_em_const(weight_vec = weight_vec,
                                          lmat       = lmat,
                                          pi_init    = p1_weight_vec,
                                          alpha      = control$fs1_alpha,
                                          lambda     = 0,
                                          itermax    = 100,
                                          obj_tol    = 10^-5))

          brent_obj <- uni_obj_const(pivec = p1_weight_vec,
                                     alpha = control$fs1_alpha,
                                     weight_vec = weight_vec,
                                     lmat = lmat,
                                     lambda = 0)
          brent_err <- abs(brent_obj - brent_obj_old)
          brent_iter <- brent_iter + 1
        }

        temp_list$obj <- brent_obj

        return_list$p2_pair_weights[[p2geno + 1]][1] <- firstmixweight_p2
        return_list$p2_pair_weights[[p2geno + 1]][2] <- 1 - firstmixweight_p2

        return_list$p1_pair_weights[[p1geno + 1]] <- p1_weight_vec

        temp_list$pivec <- pivec_from_segmats(p1segmat = p1_seg_prob_mat,
                                              p2segmat = p2_seg_prob_mat,
                                              p1weight = return_list$p1_pair_weights[[p1geno + 1]],
                                              p2weight = return_list$p2_pair_weights[[p2geno + 1]])

      } else if ((num_comp[p1geno + 1] > 2) & (num_comp[p2geno + 1] > 2)) {
        ## EM on both
        p1_seg_prob_mat   <- control$blist$probmat[control$blist$lvec == p1geno, , drop = FALSE]
        p2_seg_prob_mat   <- control$blist$probmat[control$blist$lvec == p2geno, , drop = FALSE]
        p1_weight_vec     <- control$p1_pair_weights[[p1geno + 1]]
        p2_weight_vec     <- control$p2_pair_weights[[p2geno + 1]]

        brent_obj     <- -Inf
        brent_tol     <- 10^-5
        brent_err     <- brent_tol + 1
        brent_iter    <- 1
        brent_itermax <- 100
        while ((brent_err > brent_tol) & (brent_iter < brent_itermax)) {
          brent_obj_old <- brent_obj

          # Update p1_weight_vec
          p2_seg_prob <- colSums(p2_weight_vec * p2_seg_prob_mat)

          lmat <- get_conv_inner_weights(psegprob = p2_seg_prob,
                                         psegmat  = p1_seg_prob_mat)

          p1_weight_vec <- c(uni_em_const(weight_vec = weight_vec,
                                          lmat       = lmat,
                                          pi_init    = p1_weight_vec,
                                          alpha      = control$fs1_alpha,
                                          lambda     = 0,
                                          itermax    = 100,
                                          obj_tol    = 10^-5))
          # Update p2_weight_vec
          p1_seg_prob <- colSums(p1_weight_vec * p1_seg_prob_mat)

          lmat <- get_conv_inner_weights(psegprob = p1_seg_prob,
                                         psegmat  = p2_seg_prob_mat)

          p1_weight_vec <- c(uni_em_const(weight_vec = weight_vec,
                                          lmat       = lmat,
                                          pi_init    = p2_weight_vec,
                                          alpha      = control$fs1_alpha,
                                          lambda     = 0,
                                          itermax    = 100,
                                          obj_tol    = 10^-5))


          brent_obj <- uni_obj_const(pivec = p2_weight_vec,
                                     alpha = control$fs1_alpha,
                                     weight_vec = weight_vec,
                                     lmat = lmat,
                                     lambda = 0)
          brent_err <- abs(brent_obj - brent_obj_old)
          brent_iter <- brent_iter + 1
        }

        temp_list$obj <- brent_obj

        return_list$p1_pair_weights[[p1geno + 1]] <- p1_weight_vec
        return_list$p2_pair_weights[[p2geno + 1]] <- p2_weight_vec

        temp_list$pivec <- pivec_from_segmats(p1segmat = p1_seg_prob_mat,
                                              p2segmat = p2_seg_prob_mat,
                                              p1weight = return_list$p1_pair_weights[[p1geno + 1]],
                                              p2weight = return_list$p2_pair_weights[[p2geno + 1]])

      } else {
        stop("update_pp: how did you get here?")
      }

      ## Add parental contributions -------------------
      if (!is.null(control$p1_lbb)) {
        temp_list$obj <- temp_list$obj + control$p1_lbb[p1geno + 1]
      }
      if (!is.null(control$p2_lbb)) {
        temp_list$obj <- temp_list$obj + control$p2_lbb[p2geno + 1]
      }

      ## Check to see what has the highest likelihood ----
      if (temp_list$obj > return_list$obj) {
        return_list$pivec  <- temp_list$pivec
        return_list$obj    <- temp_list$obj
        return_list$p1geno <- p1geno
        return_list$p2geno <- p2geno
      }
    }
  }

  return_list$pivec <- (1 - control$fs1_alpha) * return_list$pivec +
    control$fs1_alpha / (ploidy + 1)
  return(return_list)
}


#' Get the inner weights used for the em update in \code{\link{update_pp}}
#' when there are more than two bivalent components for one of the parents.
#'
#' @param psegprob One of the parents segregation probability vector.
#' @param psegmat The other parent's segregation matrix.
#'
#' @return A matrix. The columns index the K components (aka individuals
#'     in the context of the local problem) and the rows index
#'     the bivalent components.
#'
#' @seealso \code{\link{update_pp}} for where this is used.
#'     \code{\link{uni_em_const}} for where the weights are used
#'     (equivalent to \code{lmat} there).
#'
#' @author David Gerard
#'
get_conv_inner_weights <- function(psegprob, psegmat) {
  assertthat::are_equal(length(psegprob), ncol(psegmat))

  lmat <- matrix(NA,
                 ncol = length(psegprob) * 2 - 1,
                 nrow = nrow(psegmat))
  for (index in seq_len(nrow(psegmat))) {
    lmat[index, ] <- c(convolve(psegprob, psegmat[index, ]))
  }
  return(lmat)
}

#' Function to get the segregation probabilities from the distributions
#' of each component and the weights of each component.
#'
#' @param p1segmat The matrix of segregation probabilities for each
#'     component for parent 1. The rows index the components and the
#'     columns index the number of alleles to segregate.
#' @param p2segmat The matrix of segregation probabilities for each
#'     component for parent 2. The rows index the components and the
#'     columns index the number of alleles to segregate.
#' @param p1weight A vector of weights for each component (row) of
#'     \code{p1segmat}.
#' @param p2weight A vector of weights for each component (row) of
#'     \code{p2segmat}.
#'
#' @author David Gerard
#'
#' @return A vector. The ith element is the probability of
#'     segregating i+1 total A alleles.
#'
#' @seealso This is mostly used in \code{\link{update_pp}}.
#'
pivec_from_segmats <- function(p1segmat, p2segmat, p1weight, p2weight) {
  assertthat::are_equal(nrow(p1segmat), length(p1weight))
  assertthat::are_equal(nrow(p2segmat), length(p2weight))
  assertthat::are_equal(ncol(p1segmat), ncol(p2segmat))
  pivec <- c(convolve(colSums(p1weight * p1segmat),
                      colSums(p2weight * p2segmat)))
  return(pivec)
}