program md

  ! Molecular Dynamics code for equilibration of Liquid Argon
  ! Author: Alex Pacheco
  ! Date  : Jan 30, 2014

  ! This program simulates the equilibration of Liquid Argon 
  ! starting from a FCC crystal structure using Lennard-Jones
  ! potential and velocity verlet algorithm
  ! This program is hard coded for 4000 atoms equilibrated at 
  ! 10K with a time step of 0.001 time units and 1000 time steps
  ! Lets assume that time units is femtoseconds, so total simulation
  ! time is 1 femtosecond
  
  ! This program is an exercise for Modern Fortran Training and can 
  ! be used for OpenMP, OpenACC and Makefile Tutorials.
  ! Your objective for
  ! Modern Fortran Training:
  ! Modify this code using the Fortran Concepts learned, viz, 
  !   1. split code into smaller subunits, modules and/or subroutines
  !   2. generalize, so that the following parameters can be read from a input file
  !       a. number of atoms or number of unit cells (you can't do both)
  !       b. equilibration temperature
  !       c. time step
  !       d. number of time steps i.e. how long in fs do you want the simulation to run
  !       e. read input parameters using namelists 
  !      You will need to make use allocatable arrays. If you do not know why, review
  !      training slides or ask
  !   3. Extra: Program another potential such as Morse potential 
  !   4. Can you use Modern Fortran Concepts such as derived types? If yes, program it
  !      If you use derived types, can you overload operators? If yes, program it
  ! OpenMP/OpenACC Training:
  !   Lets assume that you have completed upto step 2 from Modern Fortran objective
  !   Parallelize the code for OpenMP/OpenACC (can also be done from step 3 or 4)
  ! Makefile Training:
  !   If you have completed at least step 1 from Modern Fortran objective, write a 
  !   Makefile to compile this code.
  
  ! As an additional exercise, use other potentials such as Morse potential and 
  ! read from input file which potential you want to use.
  ! All Lennard-Jones Potential parameters are set to 1.

  ! There is no time limit for completing this exercise. This exercise is for measuring
  ! how much you have gotten from the training.
  ! There are several version of the code that you can compare your work to.
  ! md-v1.f90 : objective 1
  ! md-v2.f90 : objective 2
  ! md-v3.f90 : objective 3
  ! md-v4.f90 : objective 4
  ! Hints are provided in this version only

  ! Disclaimer: 
  ! This is code can be used as an introduction to molecular dynamics. There are lot more
  ! concepts in MD that are not covered here. 

  ! Parameters:
  ! npartdim : number of unit cells, uniform in all directions. change to nonuniform if you desire
  ! natom : number of atoms
  ! nstep : nummber of simulation time steps
  ! tempK : equilibration temperature
  ! dt : simulation time steps
  ! boxl : length of simulation box in all directions
  ! alat : lattice constant for fcc crystal
  ! kb : boltzmann constant, set to 1 for simplicity
  ! mass : mass of Ar atom, set to 1 for simplicity
  ! epsilon, sigma : LJ parameters, set to 1 for simplicity 
  ! rcell : FCC unit cell 
  ! coord, coord_t0 : nuclear positions for each step, current and initial
  ! vel, vel_t0 : nuclear velocities for each step
  ! acc, acc_t0 : nuclear acceleration for each step
  ! force, pener : force and potential energy at current step
  ! avtemp : average temperature at current time step
  ! scale : scaling factor to set current temperature to desired temperature
  ! gasdev : Returns a normally distributed deviate with zero mean and unit variance from Numerical recipes

  implicit none
  ! Use either kind function or selected_real_kind
  integer,parameter :: npartdim = 4 
  integer,parameter :: natom = 4.d0 * npartdim ** 3
  integer,parameter :: nstep = 2
  real*8, parameter :: tempK = 10, dt = 1d-3
  integer :: istep
  real*8 :: boxl(3), alat
  integer :: n, i, j, k, l

! Can you use derived types for coord, vel, acc and force
  real*8 :: coord_t0(natom,3), coord(natom,3)
  real*8 :: vel_t0(natom,3), vel(natom,3)
  real*8 :: acc_t0(natom,3), acc(natom,3)
  real*8 :: force(natom,3), pener, mass

  real*8 :: vcm(3), r(3), rr, r2, r6, f(3)
  real*8 :: avtemp, ke, kb, epsilon, sigma, rcell(3,4), scale
  real*8 :: gasdev
  ! For timing analysis
  real*8 :: init_time, start_time, end_time
  integer :: value(8)
  integer :: seed(8) = (/ 0, 0, 0, 0, 0, 0, 0, 0 /)
  integer :: s

  alat = 2d0 ** (2d0/3d0)
  ! Hint: Array operations
  do i = 1, 3
     boxl(i) = npartdim * alat
  end do
  kb = 1.d0
  mass = 1.d0
  epsilon = 1.d0
  sigma = 1.d0

  ! Create FCC unit cell
  ! Hint: Simplify unit cell creation, maybe in variable declaration
  rcell(1,1) = 0d0
  rcell(2,1) = 0d0
  rcell(3,1) = 0d0
  rcell(1,2) = 0.5d0 * alat
  rcell(2,2) = 0.5d0 * alat
  rcell(3,2) = 0d0
  rcell(1,3) = 0d0
  rcell(2,3) = 0.5d0 * alat
  rcell(3,3) = 0.5d0 * alat
  rcell(1,4) = 0.5d0 * alat
  rcell(2,4) = 0d0
  rcell(3,4) = 0.5d0 * alat

  !=================================================
  ! Initialize coordinates and random velocities
  !=================================================
  call date_and_time(VALUES=value)
  init_time = dble(value(5)*3600) + dble(value(6)*60) + dble(value(7)) + dble(value(8))/1000d0
  ! Set initial coordinates, velocity and acceleration to zero
  ! Hint: Use Array operations
  do i = 1, natom
     do j = 1, 3
        coord_t0(i,j) = 0d0
        vel_t0(i,j) = 0d0
        acc_t0(i,j) =  0d0
     end do
  end do

  ! Put initialization in a seperate subroutine
  ! call initialize(coord_t0, vel_t0, ...) 
  ! Create a FCC crystal structure
  n = 1
  do i = 1, npartdim
     do j = 1, npartdim
        do k = 1, npartdim
           do l = 1, 4
              coord_t0(n,1) = alat * dble(i - 1) + rcell(1,l)
              coord_t0(n,2) = alat * dble(j - 1) + rcell(2,l)
              coord_t0(n,3) = alat * dble(k - 1) + rcell(3,l)
              n = n + 1
           end do
        end do
     end do
  end do
  
  ! Assign initial random velocities
  call srand(0)
  do i = 1, natom
     do j = 1, 3
        vel_t0(i,j) = mod(i, 2) - 0.5d0 !gasdev()
     end do
  end do

  open(unit=1,file='atom.xyz',status='unknown')
  write(1,'(i8)') natom
  write(1,*)
  do i = 1, natom
     write(1,'(a2,2x,3f12.6)') 'Ar', coord_t0(i,1), coord_t0(i,2), coord_t0(i,3)
  end do
  
  ! Set Linear Momentum to zero
  ! Hint: This is needed again below so put in a subroutine
  ! call linearmom(vel_t0, ...)
  ! First get center of mass velocity
  vcm = 0d0
  do i = 1, natom
     do j = 1, 3
        vcm(j) = vcm(j) + vel_t0(i,j)/natom
     end do
  end do
  ! Now remove center of mass velocity from all atoms
  do i = 1, natom
     do j = 1, 3
        vel_t0(i,j) = vel_t0(i,j) - vcm(j)
     end do
  end do

  ! scale velocity to desired tempearture
  ! call get_temp( vel_t0, ... ) will be needed again
  ke = 0d0
  do i = 1, natom
     do j = 1, 3
        ! Hint: Use dot_product function to calculate vel**2
        ! If using derived types, overload dot_product function
        ke = ke + mass * vel_t0(i,j)**2
     end do
  end do
  avtemp = mass * ke / ( 3d0 * kb * ( natom - 1))

  print '(a,2x,e15.8)', 'Initial Average Temperature: ', avtemp

  ! scale initial velocity to desired temperature
  scale = sqrt( tempK / avtemp )
  ke = 0d0 
  do i = 1, natom
     do j = 1, 3
        vel_t0(i,j) = vel_t0(i,j) * scale
        ! See Hint above on dot_product and function overloading
        ke = ke + mass * vel_t0(i,j)**2
     end do
  end do
  avtemp = mass * ke / ( 3d0 * kb * ( natom - 1))
  print '(a,2x,e15.8)', 'Initial Scaled Average Temperature: ', avtemp

  call date_and_time(VALUES=value)
  start_time = dble(value(5)*3600) + dble(value(6)*60) + dble(value(7)) + dble(value(8))/1000d0

  !=================================================
  ! MD Simulation
  !=================================================

  do istep = 1, nstep
     
     ! Set coordinates, velocity, acceleration and force at next time step to zero
     ! Hint: Use Array properties
     do i = 1, natom
        do j = 1, 3
           coord(i,j) = 0d0
           vel(i,j) = 0d0
           acc(i,j) =  0d0
           force(i,j) =  0d0
        end do
     end do
     pener = 0d0
     
     ! Get new atom positions from Velocity Verlet Algorithm
     ! Hint: create a subroutine to do velocity verlet
     ! Hint: OpenMP/OpenACC
     do i = 1, natom
        do j = 1, 3
           coord(i,j) = coord_t0(i,j) + vel_t0(i,j) * dt + 0.5d0 * acc_t0(i,j) * dt ** 2
           ! Apply PBC to coordinates
           if ( coord(i,j) > boxl(j) ) then
              coord(i,j) = coord(i,j) - boxl(j)
           else if ( coord(i,j) < 0d0 ) then
              coord(i,j) = coord(i,j) + boxl(j)
           endif
        end do
     end do
    
     
     ! Get force at new atom positions
     ! Using Lennard Jones Potential
     ! Hint: you might want to also seperate the potential and force calculation into a separate subroutine
     ! this will be useful if you want to use other potentials

     do i = 1, natom - 1
        do j = i + 1, natom
           do k = 1, 3
              r(k) = coord(i,k) - coord(j,k)
              ! minimum image criterion
              ! interaction of an atom with another atom or its image within the unit cell
              r(k) = r(k) - nint( r(k) / boxl(k) ) * boxl(k)
           end do
           ! Hint: Use dot_product
           rr = r(1) ** 2 + r(2) ** 2 + r(3) ** 2
           r2 = 1.d0 / rr
           r6 = r2 ** 3
           ! Lennard Jones Potential
           ! V = 4 * epsilon * [ (sigma/r)**12 - (sigma/r)**6 ]
           !   = 4 * epsilon * (sigma/r)**6 * [ (sigma/r)**2 - 1 ]
           !   = 4 * r**(-6) * [ r**(-2) - 1 ] for epsilon=sigma=1
           ! F_i = 48 * epsilon * (sigma/r)**6 * (1/r**2) * [ ( sigma/r)** 6 - 0.5 ] * i where i = x,y,z
           !     = 48 * r**(-8) * [ r**(-6) - 0.5 ] * i  for epsilon=sigma=1
           pener = pener + 4d0 * r6 * ( r6 - 1.d0 )
           f = 48d0 * r2 * r6 * ( r6 - 0.5d0 ) * r
           do k = 1, 3
              ! use array function to obtain r(k)*f
              force(i,k) = force(i,k) + f(k)
              force(j,k) = force(j,k) - f(k)
           end do
        end do
     end do
    

     ! Calculate Acceleration and Velocity  at current time step
     do i = 1, natom
        do j = 1, 3
           acc(i,j) = force(i,j) / mass
           vel(i,j) = vel_t0(i,j) + 0.5d0 * (acc(i,j) + acc_t0(i,j)) * dt
        end do
     end do
    
     ! Set Linear Momentum to zero
     ! First get center of mass velocity
     ! See Hint above on Linear Momentum
     vcm = 0d0
     do i = 1, natom
        do j = 1, 3
           vcm(j) = vcm(j) + vel(i,j)/natom
        end do
     end do
     ! Now remove center of mass velocity from all atoms
     do i = 1, natom
        do j = 1, 3
           vel(i,j) = vel(i,j) - vcm(j)
        end do
     end do
    
    

     ! compute average temperature
     ! See Hint above on calculating average temperature
     ke = 0d0
     do i = 1, natom
        do j = 1, 3
           ke = ke + vel(i,j) ** 2
        end do
     end do
     avtemp = mass * ke / ( 3d0 * kb * ( natom - 1))

     print '(a,2x,i8,2x,e15.8,1x,e15.8)', 'Average Temperature: ' , istep, avtemp, pener

     scale = sqrt ( tempk/ avtemp )
     ! Reset for next time step
     ! Hint:  Use Array properties
     do i = 1, natom
        do j = 1, 3
           acc_t0(i,j) = acc(i,j)
           coord_t0(i,j) = coord(i,j)
           ! scale velocity to desired temperature
           vel_t0(i,j) = vel(i,j) * scale
        end do
     end do
    
    if (istep == nstep) then
        do i = 1, natom
            write(2,*) vel_t0(i,:)
        end do
    endif

    

     ! Write current coordinates to xyz file for visualization
     write(1,'(i8)') natom
     write(1,*)
     do i = 1, natom
        write(1,'(a2,2x,3f12.6)') 'Ar', coord_t0(i,1), coord_t0(i,2), coord_t0(i,3)
     end do
  end do
  close(1)
  call date_and_time(VALUES=value)
  end_time = dble(value(5)*3600) + dble(value(6)*60) + dble(value(7)) + dble(value(8))/1000d0
  write(6,'(a,f12.3,/,a,f12.3)') 'Init Time: ', start_time - init_time, &
       'Sim  Time: ', end_time - start_time

end program md

double precision function gasdev()
  implicit none
  real*8 :: v1, v2, fac, rsq
  real*8, save :: gset
  logical, save :: available = .false.
  
  if (available) then
     gasdev = gset
     available = .false.
  else
     do
        call random_number(v1)
        call random_number(v2)
        v1 = 2.d0 * v1 - 1.d0
        v2 = 2.d0 * v2 - 1.d0
        rsq = v1**2 + v2**2
        if ( rsq > 0.d0 .and. rsq < 1.d0 ) exit
     end do
     fac = sqrt(-2.d0 * log(rsq) / rsq)
     gasdev = v1 * fac
     gset = v2 * fac
     available = .true.
  end if
end function gasdev


