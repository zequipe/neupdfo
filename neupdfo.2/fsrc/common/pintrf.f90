! This is a module specifying the abstract interfaces FUN and FUNCON. FUN evaluates the objective
! function for unconstrained, bound constrained, and linearly constrained problems; FUNCON evaluates
! the objective and constraint functions for nonlinearly constrained problems.
!
! Coded by Zaikun Zhang in July 2020.
!
! Last Modified: Monday, August 30, 2021 PM11:38:41
!
!!!!!! Users must provide the implementation of FUN or FUNCON. !!!!!!


module pintrf_mod

implicit none
private
public :: FUN, FUNCON

abstract interface
    subroutine FUN(x, f)
    use consts_mod, only : RP
    implicit none
    real(RP), intent(in) :: x(:)
    real(RP), intent(out) :: f
    end subroutine FUN
end interface

abstract interface
    subroutine FUNCON(x, f, constr)
    use consts_mod, only : RP
    implicit none
    real(RP), intent(in) :: x(:)
    real(RP), intent(out) :: f
    real(RP), intent(out) :: constr(:)
    end subroutine FUNCON
end interface

end module pintrf_mod
