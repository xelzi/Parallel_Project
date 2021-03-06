MODULE sort_mod
USE MPI
CONTAINS

SUBROUTINE sort(x,indx,N,P,my_rank)
IMPLICIT NONE
DOUBLE PRECISION, ALLOCATABLE, DIMENSION(:) :: x,indx,tempx,tempindx
INTEGER, DIMENSION(MPI_STATUS_SIZE) :: myStatus
INTEGER :: N,P,my_rank,leftover,div,i,j,tempx_size,temp_rank,merge_count,place,temp,ierror, temp_core
DOUBLE PRECISION, ALLOCATABLE, DIMENSION(:,:) :: tempx_two, tempindx_two, x_two, indx_two
DOUBLE PRECISION, PARAMETER :: big = 10.d0**300
INTEGER, PARAMETER :: master = 0

leftover = MOD(N,P) !computes how many leftover elements will be distributed to remaining cores
div = N - leftover !number of elements that can be evenly distributed amongst cores

ALLOCATE(x_two(2,N), indx_two(2,N)) !allocation of recieve arrays for MPI reduce later


IF(my_rank .GE. 1 .AND. my_rank .LE. leftover) THEN !processors getting extras
  ALLOCATE(tempx(div/P+1),tempindx(div/P+1))
  tempx_size = div/P+1
ELSE
  ALLOCATE(tempx(div/P),tempindx(div/P))
  tempx_size = div/P
END IF


j=1
DO i = 1+my_rank*div/P, my_rank*div/P+div/P
    tempx(j) = x(i)
    tempindx(j) = i
  j = j + 1
END DO

IF(my_rank .LE. leftover .AND. my_rank .GE. 1) THEN
  temp = 1
  DO i = N-leftover+1,N
    IF(my_rank == temp) THEN
      tempx(tempx_size) = x(i)
      tempindx(tempx_size) = DBLE(i)
    END IF
    temp = temp + 1
  END DO
END IF



CALL MergeSort(tempx,tempx_size,tempindx)


!WRITE(*,*) ''
!IF(my_rank == 0) THEN
!  WRITE(*,*) 'The lastslast shit'
!  DO i = 1, tempx_size
!    WRITE(*,*) tempx(i)
!  END DO
!END IF


ALLOCATE(tempx_two(2,tempx_size+1),tempindx_two(2,tempx_size)) !prepping for call to mpireduce
!set each core's place
place = 1
!Put it all back together!

DO i = 1,tempx_size !create tempx_two array
  tempx_two(1,i) = tempx(i)
  tempx_two(2,i) = DBLE(my_rank)
  tempindx_two(1,i) = DBLE(tempindx(i))
  tempindx_two(2,i) = DBLE(my_rank)

END DO

tempx_two(1,tempx_size+1) = big
tempx_two(2,tempx_size+1) = DBLE(my_rank) !last entry really big

DO i = 1,N
  
  CALL MPI_Reduce(tempx_two(1:2, place), x_two(1:2,i), 1, &
    MPI_2DOUBLE_PRECISION, MPI_MINLOC, master, MPI_COMM_WORLD, ierror)
  IF(my_rank == master) THEN
    temp_core = INT(x_two(2,i))
  END IF
  
  CALL MPI_Bcast(temp_core, 1, MPI_INTEGER, master, &
    MPI_COMM_WORLD, ierror)
  
  IF(my_rank == temp_core) THEN
    !WRITE(*,*) tempindx(place)
    CALL MPI_SEND(tempindx(place), 1, MPI_DOUBLE_PRECISION, 0, my_rank*10, MPI_COMM_WORLD, ierror)
    place = place + 1
  END IF
  
  IF(my_rank == master) THEN
     CALL MPI_RECV(indx(i), 1, MPI_DOUBLE_PRECISION, temp_core, temp_core*10, MPI_COMM_WORLD, myStatus, ierror)
     x(i) = x_two(1,i) 
  END IF
   


END DO


!IF(my_rank .EQ. 0)
!  DEALLOCATE(x_two)
!END IF




DEALLOCATE(tempx,tempindx, tempx_two, x_two, tempindx_two, indx_two) !fix this when you put back the _two stuff
END SUBROUTINE sort


RECURSIVE SUBROUTINE MergeSort(tempx,tempx_size,tempindx)
IMPLICIT NONE
DOUBLE PRECISION, ALLOCATABLE, DIMENSION(:) :: tempx, tempindx, left, right, leftindx, rightindx
INTEGER tempx_size,left_size,right_size, pivot, i


IF(tempx_size .LE. 1) THEN 
  RETURN
END IF


pivot = FLOOR(DBLE(tempx_size / 2))

IF(MOD(tempx_size,2) .EQ. 0) THEN !If even number of elements in tempx
  ALLOCATE(left(pivot),right(pivot),leftindx(pivot),rightindx(pivot))
  left_size = pivot
  right_size = pivot
ELSE
  ALLOCATE(left(pivot),right(pivot+1),leftindx(pivot),rightindx(pivot+1))
  left_size = pivot
  right_size = pivot+1
END IF

DO i = 1,pivot
  left(i) = tempx(i)
  leftindx(i) = tempindx(i)
  right(i) = tempx(pivot+i)
  rightindx(i) = tempindx(pivot+i)
END DO

IF(MOD(tempx_size,2) .NE. 0) THEN !If odd number of elements add last element to right
  right(tempx_size-pivot) = tempx(tempx_size)
  rightindx(tempx_size-pivot) = tempindx(tempx_size)
END IF


CALL MergeSort(left,left_size,leftindx)
CALL MergeSort(right,right_size,rightindx)

CALL MergeIt(left,left_size,right,right_size,leftindx,rightindx,tempx,tempindx)

DEALLOCATE(left,right,leftindx,rightindx)
END SUBROUTINE MergeSort

SUBROUTINE MergeIt(left,left_size,right,right_size,leftindx,rightindx,tempx,tempindx)
IMPLICIT NONE
DOUBLE PRECISION, ALLOCATABLE, DIMENSION(:) :: tempx, tempindx, left, right, leftindx, rightindx
INTEGER :: tempx_size,left_size,right_size, i, templ, tempr, k



templ = 1
tempr = 1
k = 1

DO WHILE(templ .LE. left_size) 
  DO WHILE(tempr .LE. right_size) 
    
    IF(left(templ) .GE. right(tempr)) THEN
      
      tempx(k) = right(tempr)
      tempindx(k) = rightindx(tempr)
      k = k+1
      tempr = tempr+1
    ELSE
      tempx(k) = left(templ)
      tempindx(k) = leftindx(templ)
      k = k+1
      templ = templ+1

    END IF
    
    IF(tempr .GT. right_size) THEN
      
      DO i = templ, left_size
        tempx(k) = left(i)
        tempindx(k) = leftindx(i)
        k = k+1
      END DO
      
      templ = left_size+1

    END IF
    
    
    IF(templ .GT. left_size) THEN
      
      DO i = tempr, right_size
        tempx(k) = right(i)
        tempindx(k) = rightindx(i)
        k = k+1
      END DO
      
      tempr = right_size+1

    END IF
    
  END DO


END DO

END SUBROUTINE MergeIt





END MODULE sort_mod
