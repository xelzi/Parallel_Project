PROGRAM tester
USE oneD_module
IMPLICIT NONE
DOUBLE PRECISION, ALLOCATABLE, DIMENSION(:) :: x,w
INTEGER :: N=4

CALL GaussLegendre(x,w,N)


END PROGRAM tester

