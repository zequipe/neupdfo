module cobyla_mod
!--------------------------------------------------------------------------------------------------!
! COBYLA_MOD is a module providing a modern Fortran implementation of Powell's COBYLA algorithm in
!
! M. J. D. Powell, A direct search optimization method that models the objective and constraint
! functions by linear interpolation, In Advances in Optimization and Numerical Analysis, eds. S.
! Gomez and J. P. Hennart, pages 51--67, Springer Verlag, Dordrecht, Netherlands, 1994
!
! COBYLA minimizes an objective function F(X) subject to M inequality constraints on X, where X is
! a vector of variables that has N components. The algorithm employs linear approximations to the
! objective and constraint functions, the approximations being formed by linear interpolation at N+1
! points in the space of the variables. We regard these interpolation points as vertices of
! a simplex. The parameter RHO controls the size of the simplex and it is reduced automatically from
! RHOBEG to RHOEND. For each RHO the subroutine tries to achieve a good vector of variables for the
! current size, and then RHO is reduced until the value RHOEND is reached. Therefore RHOBEG and
! RHOEND should be set to reasonable initial changes to and the required accuracy in the variables
! respectively, but this accuracy should be viewed as a subject for experimentation because it is
! not guaranteed.  The subroutine has an advantage over many of its competitors, however, which is
! that it treats each constraint individually when calculating a change to the variables, instead of
! lumping the constraints together into a single penalty function. The name of the subroutine is
! derived from the phrase Constrained Optimization BY Linear Approximations.
!
! Coded by Zaikun ZHANG (www.zhangzk.net) based on Powell's Fortran 77 code and the COBYLA paper.
!
! Started: July 2021
!
! Last Modified: Monday, December 13, 2021 PM04:59:41
!--------------------------------------------------------------------------------------------------!

implicit none
private
public :: cobyla


contains


subroutine cobyla(calcfc, x, f, cstrv, &
    & constr, f0, constr0, m, &
    & nf, rhobeg, rhoend, ftarget, ctol, maxfun, iprint, &
    & xhist, fhist, conhist, chist, maxhist, info)
!& eta1, eta2, gamma1, gamma2, xhist, fhist, conhist, chist, maxhist, info)

! Generic modules
use, non_intrinsic :: consts_mod, only : RP, IK, EPS, DEBUGGING
use, non_intrinsic :: debug_mod, only : errstop
use, non_intrinsic :: infnan_mod, only : is_nan, is_posinf
use, non_intrinsic :: memory_mod, only : safealloc
use, non_intrinsic :: output_mod, only : retmssg, rhomssg, fmssg
use, non_intrinsic :: pintrf_mod, only : FUNCON

! Solver-specific modules
use, non_intrinsic :: cobylb_mod, only : cobylb

implicit none

! Compulsory arguments
procedure(FUNCON) :: calcfc
real(RP), intent(inout) :: x(:)
real(RP), intent(out) :: f
real(RP), intent(out) :: cstrv
real(RP), intent(out) :: constr(:)

! Optional inputs
integer(IK), intent(in), optional :: iprint
integer(IK), intent(in), optional :: m
integer(IK), intent(in), optional :: maxfun
integer(IK), intent(in), optional :: maxhist
integer(IK), intent(in), optional :: nf
real(RP), intent(in), optional :: constr0(:)
real(RP), intent(in), optional :: ctol
real(RP), intent(in), optional :: f0
real(RP), intent(in), optional :: ftarget
real(RP), intent(in), optional :: rhobeg
real(RP), intent(in), optional :: rhoend

! Optional outputs
integer(IK), intent(out), optional :: info
real(RP), intent(out), allocatable, optional :: chist(:)
real(RP), intent(out), allocatable, optional :: conhist(:, :)
real(RP), intent(out), allocatable, optional :: fhist(:)
real(RP), intent(out), allocatable, optional :: xhist(:, :)

! Local variables
character(len=*), parameter :: solver = 'COBYLA'
character(len=*), parameter :: srname = 'COBYLA'
integer(IK) :: constr0_loc
integer(IK) :: ctol_loc
integer(IK) :: iprint_loc
integer(IK) :: maxchist
integer(IK) :: maxconhist
integer(IK) :: maxfhist
integer(IK) :: maxfun_loc
integer(IK) :: maxhist_loc
integer(IK) :: maxxhist
integer(IK) :: nf_loc
real(RP) :: ctol_loc
real(RP) :: ftarget_loc
real(RP) :: rhoend_loc
real(RP), allocatable :: chist(:)
real(RP), allocatable :: chist_loc(:)
real(RP), allocatable :: conhist(:, :)
real(RP), allocatable :: conhist_loc(:, :)
real(RP), allocatable :: fhist(:)
real(RP), allocatable :: fhist_loc(:)
real(RP), allocatable :: xhist(:, :)
real(RP), allocatable :: xhist_loc(:, :)

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!
!     The user must set the values of N, M, RHOBEG and RHOEND, and must
!     provide an initial vector of variables in X. Further, the value of
!     IPRINT should be set to 0, 1, 2 or 3, which controls the amount of
!     printing during the calculation. Specifically, there is no output if
!     IPRINT=0 and there is output only at the end of the calculation if
!     IPRINT=1. Otherwise each new value of RHO and SIGMA is printed.
!     Further, the vector of variables and some function information are
!     given either when RHO is reduced or when each new value of F(X) is
!     computed in the cases IPRINT=2 or IPRINT=3 respectively. Here SIGMA
!     is a penalty parameter, it being assumed that a change to X is an
!     improvement if it reduces the merit function
!                F(X)+SIGMA*MAX(0.0,-C1(X),-C2(X),...,-CM(X)),
!     where C1,C2,...,CM denote the constraint functions that should become
!     nonnegative eventually, at least to the precision of RHOEND. In the
!     printed output the displayed term that is multiplied by SIGMA is
!     called MAXCV, which stands for 'MAXimum Constraint Violation'. The
!     argument MAXFUN is an integer variable that must be set by the user to a
!     limit on the number of calls of CALCFC, the purpose of this routine being
!     given below. The value of MAXFUN will be altered to the number of calls
!     of CALCFC that are made. The arguments W and IACT provide real and
!     integer arrays that are used as working space. Their lengths must be at
!     least N*(3*N+2*M+11)+4*M+6 and M+1 respectively.
!CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
!     F is the objective function value when the algorithm exit.
!     INFO is the exit flag, which can be set to:
!       0: the lower bound for the trust region radius is reached.
!       1: the target function value is reached.
!       2: a trust region step has failed to reduce the quadratic model.
!       3: the objective function has been evaluated MAXFUN times.
!       4: much cancellation in a denominator.
!       5: NPT is not in the required interval.
!       6: one of the difference XU(I)-XL(I) is less than 2*RHOBEG.
!       7: rounding errors are becoming damaging.
!       8: rounding errors prevent reasonable changes to X.
!       9: the denominator of the updating formule is zero.
!       10: N should not be less than 2.
!       11: MAXFUN is less than NPT+1.
!       12: the gradient of constraint is zero.
!       -1: NaN occurs in x.
!       -2: the objective function returns a NaN or nearly infinite
!           value.
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!
!     In order to define the objective and constraint functions, we require
!     a subroutine that has the name and arguments
!                SUBROUTINE CALCFC (N,M,X,F,CONSTR)
!                DIMENSION X(*),CONSTR(*)  .
!     The values of N and M are fixed and have been defined already, while
!     X is now the current vector of variables. The subroutine should return
!     the objective and constraint functions at X in F and CONSTR(1),CONSTR(2),
!     ...,CONSTR(M). Note that we are trying to adjust X so that F(X) is as
!     small as possible subject to the constraint functions being nonnegative.
!
!     Partition the working space array W to provide the storage that is needed
!     for the main calculation.
!
!CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
! Zaikun, 2020-05-05
! When the data is passed from the interfaces to the Fortran code, RHOBEG,
! and RHOEND may change a bit (due to rounding ???). It was observed in
! a MATLAB test that MEX passed 1 to Fortran as 0.99999999999999978.
! If we set RHOEND = RHOBEG in the interfaces, then it may happen
! that RHOEND > RHOBEG. That is why we do the following.
rhoend_loc = min(rhobeg, rhoend)
! CTOL is the tolerance for constraint violation. A point X is considered to be feasible if its
! constraint violation (CSTRV) is less than CTOL.
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
maxxhist = maxfun
maxfhist = maxfun
maxchist = maxfun
maxconhist = maxfun
call safealloc(xhist_loc, n, maxxhist)
call safealloc(fhist_loc, maxfhist)
call safealloc(conhist_loc, m, maxconhist)
call safealloc(chist_loc, maxchist)
call cobylb(calcfc, iprint, maxfun, ctol, ftarget, rhobeg, rhoend, constr, x, nf_loc, chist_loc, &
    & conhist_loc, cstrv, f, fhist_loc, xhist_loc, info)
call safealloc(xhist, n, min(nf_loc, maxxhist))
xhist = xhist_loc(:, 1:min(nf_loc, maxxhist))
deallocate (xhist_loc)
call safealloc(fhist, min(nf_loc, maxfhist))
fhist = fhist_loc(1:min(nf_loc, maxfhist))
deallocate (fhist_loc)
call safealloc(conhist, m, min(nf_loc, maxconhist))
conhist = conhist_loc(:, 1:min(nf_loc, maxconhist))
deallocate (conhist_loc)
call safealloc(chist, min(nf_loc, maxchist))
chist = chist_loc(1:min(nf_loc, maxchist))
deallocate (chist_loc)
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
end subroutine cobyla

end module cobyla_mod
