MODULE MF_InitializationModule_Relativistic_IDEAL

  ! --- AMReX Modules ---

  USE amrex_fort_module,      ONLY: &
    AR => amrex_real
  USE amrex_box_module,       ONLY: &
    amrex_box
  USE amrex_multifab_module,  ONLY: &
    amrex_multifab,     &
    amrex_mfiter,       &
    amrex_mfiter_build, &
    amrex_mfiter_destroy
  USE amrex_parallel_module,  ONLY: &
    amrex_parallel_ioprocessor, &
    amrex_parallel_reduce_sum
  USE amrex_parmparse_module, ONLY: &
    amrex_parmparse,       &
    amrex_parmparse_build, &
    amrex_parmparse_destroy

  ! --- thornado Modules ---

  USE ProgramHeaderModule,            ONLY: &
    nDOFX,   &
    nX,      &
    nNodesX, &
    swX,     &
    nDimsX
  USE ReferenceElementModuleX,        ONLY: &
    NodeNumberTableX
  USE MeshModule,                     ONLY: &
    MeshType,    &
    CreateMesh,  &
    DestroyMesh, &
    NodeCoordinate
  USE GeometryFieldsModule,           ONLY: &
    nGF,          &
    iGF_Gm_dd_11, &
    iGF_Gm_dd_22, &
    iGF_Gm_dd_33
  USE FluidFieldsModule,              ONLY: &
    nCF,    &
    iCF_D,  &
    iCF_S1, &
    iCF_S2, &
    iCF_S3, &
    iCF_E,  &
    iPF_Ne, &
    nPF,    &
    iPF_D,  &
    iPF_V1, &
    iPF_V2, &
    iPF_V3, &
    iPF_E,  &
    iCF_Ne, &
    nAF,    &
    iAF_P
  USE Euler_UtilitiesModule,          ONLY: &
    ComputeConserved_Euler
  USE EquationOfStateModule,          ONLY: &
    ComputePressureFromPrimitive
  USE UnitsModule,                    ONLY: &
    Kilometer,    &
    Second,       &
    SolarMass,    &
    SpeedOfLight
  USE UtilitiesModule,                ONLY: &
    NodeNumberX
  USE Euler_ErrorModule,              ONLY: &
    DescribeError_Euler

  ! --- Local Modules ---

  USE MyAmrModule, ONLY: &
    nLevels,            &
    xL,                 &
    xR,                 &
    Gamma_IDEAL,        &
    InitializeFromFile, &
    OutputDataFileName

  IMPLICIT NONE
  PRIVATE

  PUBLIC :: MF_InitializeFields_Relativistic_IDEAL

  REAL(AR), PARAMETER :: Zero     = 0.0_AR
  REAL(AR), PARAMETER :: SqrtTiny = SQRT( TINY( 1.0_AR ) )
  REAL(AR), PARAMETER :: Half     = 0.5_AR
  REAL(AR), PARAMETER :: One      = 1.0_AR
  REAL(AR), PARAMETER :: Two      = 2.0_AR
  REAL(AR), PARAMETER :: Three    = 3.0_AR
  REAL(AR), PARAMETER :: Four     = 4.0_AR
  REAL(AR), PARAMETER :: Pi       = ACOS( -1.0_AR )
  REAL(AR), PARAMETER :: TwoPi    = 2.0_AR * Pi
  REAL(AR), PARAMETER :: FourPi   = 4.0_AR * Pi


CONTAINS


  SUBROUTINE MF_InitializeFields_Relativistic_IDEAL &
    ( ProgramName, MF_uGF, MF_uCF )

    CHARACTER(LEN=*),     INTENT(in)    :: ProgramName
    TYPE(amrex_multifab), INTENT(in)    :: MF_uGF(0:nLevels-1)
    TYPE(amrex_multifab), INTENT(inout) :: MF_uCF(0:nLevels-1)

    IF( amrex_parallel_ioprocessor() )THEN

      WRITE(*,*)
      WRITE(*,'(A4,A,A)') '', 'Initializing: ', TRIM( ProgramName )

    END IF

    SELECT CASE ( TRIM( ProgramName ) )

      CASE( 'Advection1D' )

        CALL InitializeFields_Advection1D( MF_uGF, MF_uCF )

      CASE( 'Advection2D' )

        CALL InitializeFields_Advection2D( MF_uGF, MF_uCF )

      CASE( 'RiemannProblem1D' )

        CALL InitializeFields_RiemannProblem1D( MF_uGF, MF_uCF )

      CASE( 'RiemannProblem2D' )

        CALL InitializeFields_RiemannProblem2D( MF_uGF, MF_uCF )

      CASE( 'KelvinHelmholtz' )

        CALL InitializeFields_KelvinHelmholtz( MF_uGF, MF_uCF )

      CASE( 'KelvinHelmholtz3D' )

        CALL InitializeFields_KelvinHelmholtz3D( MF_uGF, MF_uCF )

      CASE( 'StandingAccretionShock_Relativistic' )

        CALL InitializeFields_StandingAccretionShock_Relativistic &
               ( MF_uGF, MF_uCF )

      CASE DEFAULT

        IF( amrex_parallel_ioprocessor() )THEN
          WRITE(*,*)
          WRITE(*,'(4x,A,A)') 'Unknown Program: ', TRIM( ProgramName )
          WRITE(*,'(4x,A)')   'Valid Options:'
          WRITE(*,'(6x,A)')     'Advection1D'
          WRITE(*,'(6x,A)')     'Advection2D'
          WRITE(*,'(6x,A)')     'RiemannProblem1D'
          WRITE(*,'(6x,A)')     'RiemannProblem2D'
          WRITE(*,'(6x,A)')     'KelvinHelmholtz'
          WRITE(*,'(6x,A)')     'KelvinHelmholtz3D'
          WRITE(*,'(6x,A)')     'StandingAccretionShock_Relativistic'
        END IF

        CALL DescribeError_Euler( 99 )

    END SELECT

  END SUBROUTINE MF_InitializeFields_Relativistic_IDEAL


  SUBROUTINE InitializeFields_Advection1D( MF_uGF, MF_uCF )

    TYPE(amrex_multifab), INTENT(in)    :: MF_uGF(0:nLevels-1)
    TYPE(amrex_multifab), INTENT(inout) :: MF_uCF(0:nLevels-1)

    ! --- thornado ---
    INTEGER        :: iX1, iX2, iX3
    INTEGER        :: iNodeX, iNodeX1
    REAL(AR)       :: X1
    REAL(AR)       :: uGF_K(nDOFX,nGF)
    REAL(AR)       :: uCF_K(nDOFX,nCF)
    REAL(AR)       :: uPF_K(nDOFX,nPF)
    REAL(AR)       :: uAF_K(nDOFX,nAF)
    INTEGER        :: iDim
    TYPE(MeshType) :: MeshX(3)

    ! --- AMReX ---
    INTEGER                       :: iLevel
    INTEGER                       :: lo_G(4), hi_G(4)
    INTEGER                       :: lo_F(4), hi_F(4)
    TYPE(amrex_box)               :: BX
    TYPE(amrex_mfiter)            :: MFI
    TYPE(amrex_parmparse)         :: PP
    REAL(AR), CONTIGUOUS, POINTER :: uGF(:,:,:,:)
    REAL(AR), CONTIGUOUS, POINTER :: uCF(:,:,:,:)

    ! --- Problem-dependent Parameters ---
    CHARACTER(LEN=:), ALLOCATABLE :: AdvectionProfile

    AdvectionProfile = 'SineWave'
    CALL amrex_parmparse_build( PP, 'thornado' )
      CALL PP % query( 'AdvectionProfile', AdvectionProfile )
    CALL amrex_parmparse_destroy( PP )

    IF( TRIM( AdvectionProfile ) .NE. 'SineWave' )THEN

      IF( amrex_parallel_ioprocessor() )THEN

        WRITE(*,*)
        WRITE(*,'(A,A)') &
          'Invalid choice for AdvectionProfile: ', &
          TRIM( AdvectionProfile )
        WRITE(*,'(A)') 'Valid choices:'
        WRITE(*,'(A)') '  SineWave'
        WRITE(*,*)
        WRITE(*,'(A)') 'Stopping...'

      END IF

      CALL DescribeError_Euler( 99 )

    END IF

    IF( amrex_parallel_ioprocessor() )THEN

      WRITE(*,'(4x,A,A)') 'Advection Profile: ', TRIM( AdvectionProfile )

    END IF

    uGF_K = Zero
    uCF_K = Zero
    uPF_K = Zero
    uAF_K = Zero

    DO iDim = 1, 3

      CALL CreateMesh &
             ( MeshX(iDim), nX(iDim), nNodesX(iDim), 0, &
               xL(iDim), xR(iDim) )

    END DO

    DO iLevel = 0, nLevels-1

      CALL amrex_mfiter_build( MFI, MF_uGF(iLevel), tiling = .TRUE. )

      DO WHILE( MFI % next() )

        uGF => MF_uGF(iLevel) % DataPtr( MFI )
        uCF => MF_uCF(iLevel) % DataPtr( MFI )

        BX = MFI % tilebox()

        lo_G = LBOUND( uGF )
        hi_G = UBOUND( uGF )

        lo_F = LBOUND( uCF )
        hi_F = UBOUND( uCF )

        DO iX3 = BX % lo(3), BX % hi(3)
        DO iX2 = BX % lo(2), BX % hi(2)
        DO iX1 = BX % lo(1), BX % hi(1)

          uGF_K &
            = RESHAPE( uGF(iX1,iX2,iX3,lo_G(4):hi_G(4)), [ nDOFX, nGF ] )

          DO iNodeX = 1, nDOFX

            iNodeX1 = NodeNumberTableX(1,iNodeX)

            X1 = NodeCoordinate( MeshX(1), iX1, iNodeX1 )

            IF     ( TRIM( AdvectionProfile ) .EQ. 'SineWave' )THEN

              uPF_K(iNodeX,iPF_D ) = One + 0.1_AR * SIN( TwoPi * X1 )
              uPF_K(iNodeX,iPF_V1) = 0.1_AR
              uPF_K(iNodeX,iPF_V2) = Zero
              uPF_K(iNodeX,iPF_V3) = Zero
              uPF_K(iNodeX,iPF_E ) = One / ( Gamma_IDEAL - One )

            END IF

          END DO

          CALL ComputePressureFromPrimitive &
                 ( uPF_K(:,iPF_D), uPF_K(:,iPF_E), uPF_K(:,iPF_Ne), &
                   uAF_K(:,iAF_P) )

          CALL ComputeConserved_Euler &
                 ( uPF_K(:,iPF_D ), uPF_K(:,iPF_V1), uPF_K(:,iPF_V2), &
                   uPF_K(:,iPF_V3), uPF_K(:,iPF_E ), uPF_K(:,iPF_Ne), &
                   uCF_K(:,iCF_D ), uCF_K(:,iCF_S1), uCF_K(:,iCF_S2), &
                   uCF_K(:,iCF_S3), uCF_K(:,iCF_E ), uCF_K(:,iCF_Ne), &
                   uGF_K(:,iGF_Gm_dd_11), &
                   uGF_K(:,iGF_Gm_dd_22), &
                   uGF_K(:,iGF_Gm_dd_33), &
                   uAF_K(:,iAF_P) )

          uCF(iX1,iX2,iX3,lo_F(4):hi_F(4)) &
            = RESHAPE( uCF_K, [ hi_F(4) - lo_F(4) + 1 ] )

        END DO
        END DO
        END DO

      END DO

      CALL amrex_mfiter_destroy( MFI )

    END DO

    DO iDim = 1, 3

      CALL DestroyMesh( MeshX(iDim) )

    END DO

  END SUBROUTINE InitializeFields_Advection1D


  SUBROUTINE InitializeFields_Advection2D( MF_uGF, MF_uCF )

    TYPE(amrex_multifab), INTENT(in)    :: MF_uGF(0:nLevels-1)
    TYPE(amrex_multifab), INTENT(inout) :: MF_uCF(0:nLevels-1)

    ! --- thornado ---
    INTEGER        :: iDim
    INTEGER        :: iX1, iX2, iX3
    INTEGER        :: iNodeX, iNodeX1, iNodeX2
    REAL(AR)       :: X1, X2
    REAL(AR)       :: uGF_K(nDOFX,nGF)
    REAL(AR)       :: uCF_K(nDOFX,nCF)
    REAL(AR)       :: uPF_K(nDOFX,nPF)
    REAL(AR)       :: uAF_K(nDOFX,nAF)
    TYPE(MeshType) :: MeshX(3)

    ! --- AMReX ---
    INTEGER                       :: iLevel
    INTEGER                       :: lo_G(4), hi_G(4)
    INTEGER                       :: lo_F(4), hi_F(4)
    TYPE(amrex_box)               :: BX
    TYPE(amrex_mfiter)            :: MFI
    TYPE(amrex_parmparse)         :: PP
    REAL(AR), CONTIGUOUS, POINTER :: uGF(:,:,:,:)
    REAL(AR), CONTIGUOUS, POINTER :: uCF(:,:,:,:)

    ! --- Problem-dependent Parameters ---
    CHARACTER(LEN=:), ALLOCATABLE :: AdvectionProfile

    AdvectionProfile = 'SineWaveX1'
    CALL amrex_parmparse_build( PP, 'thornado' )
      CALL PP % query( 'AdvectionProfile', AdvectionProfile )
    CALL amrex_parmparse_destroy( PP )

    IF( TRIM( AdvectionProfile ) .NE. 'SineWaveX1' &
        .AND. TRIM( AdvectionProfile ) .NE. 'SineWaveX2' &
        .AND. TRIM( AdvectionProfile ) .NE. 'SineWaveX1X2' )THEN

      IF( amrex_parallel_ioprocessor() )THEN

        WRITE(*,*)
        WRITE(*,'(A,A)') &
          'Invalid choice for AdvectionProfile: ', &
          TRIM( AdvectionProfile )
        WRITE(*,'(A)') 'Valid choices:'
        WRITE(*,'(A)') '  SineWaveX1'
        WRITE(*,'(A)') '  SineWaveX2'
        WRITE(*,'(A)') '  SineWaveX1X2'
        WRITE(*,*)
        WRITE(*,'(A)') 'Stopping...'

      END IF

      CALL DescribeError_Euler( 99 )

    END IF

    IF( amrex_parallel_ioprocessor() )THEN

      WRITE(*,'(4x,A,A)') 'Advection Profile: ', TRIM( AdvectionProfile )

    END IF

    uGF_K = Zero
    uCF_K = Zero
    uPF_K = Zero
    uAF_K = Zero

    DO iDim = 1, 3

      CALL CreateMesh &
             ( MeshX(iDim), nX(iDim), nNodesX(iDim), 0, &
               xL(iDim), xR(iDim) )

    END DO

    DO iLevel = 0, nLevels-1

      CALL amrex_mfiter_build( MFI, MF_uGF(iLevel), tiling = .TRUE. )

      DO WHILE( MFI % next() )

        uGF => MF_uGF(iLevel) % DataPtr( MFI )
        uCF => MF_uCF(iLevel) % DataPtr( MFI )

        BX = MFI % tilebox()

        lo_G = LBOUND( uGF )
        hi_G = UBOUND( uGF )

        lo_F = LBOUND( uCF )
        hi_F = UBOUND( uCF )

        DO iX3 = BX % lo(3), BX % hi(3)
        DO iX2 = BX % lo(2), BX % hi(2)
        DO iX1 = BX % lo(1), BX % hi(1)

          uGF_K &
            = RESHAPE( uGF(iX1,iX2,iX3,lo_G(4):hi_G(4)), [ nDOFX, nGF ] )

          DO iNodeX = 1, nDOFX

            iNodeX1 = NodeNumberTableX(1,iNodeX)
            iNodeX2 = NodeNumberTableX(2,iNodeX)

            X1 = NodeCoordinate( MeshX(1), iX1, iNodeX1 )
            X2 = NodeCoordinate( MeshX(2), iX2, iNodeX2 )

            IF     ( TRIM( AdvectionProfile ) .EQ. 'SineWaveX1' )THEN

              uPF_K(iNodeX,iPF_D ) = One + 0.1_AR * SIN( TwoPi * X1 )
              uPF_K(iNodeX,iPF_V1) = 0.1_AR
              uPF_K(iNodeX,iPF_V2) = Zero
              uPF_K(iNodeX,iPF_V3) = Zero
              uPF_K(iNodeX,iPF_E ) = One / ( Gamma_IDEAL - One )

            ELSE IF( TRIM( AdvectionProfile ) .EQ. 'SineWaveX2' )THEN

              uPF_K(iNodeX,iPF_D ) = One + 0.1_AR * SIN( TwoPi * X2 )
              uPF_K(iNodeX,iPF_V1) = Zero
              uPF_K(iNodeX,iPF_V2) = 0.1_AR
              uPF_K(iNodeX,iPF_V3) = Zero
              uPF_K(iNodeX,iPF_E ) = One / ( Gamma_IDEAL - One )

            ELSE IF( TRIM( AdvectionProfile ) .EQ. 'SineWaveX1X2' )THEN

              uPF_K(iNodeX,iPF_D ) &
                = One + 0.1_AR * SIN( SQRT( Two ) * TwoPi * ( X1 + X2 ) )
              uPF_K(iNodeX,iPF_V1) = 0.1_AR * COS( Pi / Four )
              uPF_K(iNodeX,iPF_V2) = 0.1_AR * SIN( Pi / Four )
              uPF_K(iNodeX,iPF_V3) = Zero
              uPF_K(iNodeX,iPF_E ) = One / ( Gamma_IDEAL - One )

            END IF

          END DO

          CALL ComputePressureFromPrimitive &
                 ( uPF_K(:,iPF_D), uPF_K(:,iPF_E), uPF_K(:,iPF_Ne), &
                   uAF_K(:,iAF_P) )

          CALL ComputeConserved_Euler &
                 ( uPF_K(:,iPF_D ), uPF_K(:,iPF_V1), uPF_K(:,iPF_V2), &
                   uPF_K(:,iPF_V3), uPF_K(:,iPF_E ), uPF_K(:,iPF_Ne), &
                   uCF_K(:,iCF_D ), uCF_K(:,iCF_S1), uCF_K(:,iCF_S2), &
                   uCF_K(:,iCF_S3), uCF_K(:,iCF_E ), uCF_K(:,iCF_Ne), &
                   uGF_K(:,iGF_Gm_dd_11), &
                   uGF_K(:,iGF_Gm_dd_22), &
                   uGF_K(:,iGF_Gm_dd_33), &
                   uAF_K(:,iAF_P) )

          uCF(iX1,iX2,iX3,lo_F(4):hi_F(4)) &
            = RESHAPE( uCF_K, [ hi_F(4) - lo_F(4) + 1 ] )

        END DO
        END DO
        END DO

      END DO

      CALL amrex_mfiter_destroy( MFI )

    END DO

    DO iDim = 1, 3

      CALL DestroyMesh( MeshX(iDim) )

    END DO

  END SUBROUTINE InitializeFields_Advection2D


SUBROUTINE InitializeFields_RiemannProblem1D( MF_uGF, MF_uCF )

    TYPE(amrex_multifab), INTENT(in)    :: MF_uGF(0:nLevels-1)
    TYPE(amrex_multifab), INTENT(inout) :: MF_uCF(0:nLevels-1)

    ! --- thornado ---
    INTEGER        :: iX1, iX2, iX3
    INTEGER        :: iNodeX, iNodeX1
    REAL(AR)       :: X1
    REAL(AR)       :: uGF_K(nDOFX,nGF)
    REAL(AR)       :: uCF_K(nDOFX,nCF)
    REAL(AR)       :: uPF_K(nDOFX,nPF)
    REAL(AR)       :: uAF_K(nDOFX,nAF)
    INTEGER        :: iDim
    TYPE(MeshType) :: MeshX(3)

    ! --- AMReX ---
    INTEGER                       :: iLevel
    INTEGER                       :: lo_G(4), hi_G(4)
    INTEGER                       :: lo_F(4), hi_F(4)
    TYPE(amrex_box)               :: BX
    TYPE(amrex_parmparse)         :: PP
    TYPE(amrex_mfiter)            :: MFI
    REAL(AR), CONTIGUOUS, POINTER :: uGF(:,:,:,:)
    REAL(AR), CONTIGUOUS, POINTER :: uCF(:,:,:,:)

    ! --- Problem-Specific Parameters ---
    CHARACTER(LEN=:), ALLOCATABLE :: RiemannProblemName
    REAL(AR) :: XD, Vs
    REAL(AR) :: LeftState(nPF), RightState(nPF)

    RiemannProblemName = 'Sod'
    CALL amrex_parmparse_build( PP, 'thornado' )
      CALL PP % query( 'RiemannProblemName', RiemannProblemName )
    CALL amrex_parmparse_destroy( PP )

    uGF_K = Zero
    uCF_K = Zero
    uPF_K = Zero
    uAF_K = Zero

    DO iDim = 1, 3

      CALL CreateMesh &
             ( MeshX(iDim), nX(iDim), nNodesX(iDim), 0, &
               xL(iDim), xR(iDim) )

    END DO

    IF( amrex_parallel_ioprocessor() )THEN

      WRITE(*,*)
      WRITE(*,'(A4,A,A)') &
        '', 'Riemann Problem Name: ', TRIM( RiemannProblemName )
      WRITE(*,*)

    END IF

    SELECT CASE( TRIM( RiemannProblemName ) )

      CASE( 'Sod' )

        XD = Half

        LeftState(iPF_D ) = 1.0_AR
        LeftState(iPF_V1) = 0.0_AR
        LeftState(iPF_V2) = 0.0_AR
        LeftState(iPF_V3) = 0.0_AR
        LeftState(iPF_E ) = 1.0_AR / ( Gamma_IDEAL - One )

        RightState(iPF_D ) = 0.125_AR
        RightState(iPF_V1) = 0.0_AR
        RightState(iPF_V2) = 0.0_AR
        RightState(iPF_V3) = 0.0_AR
        RightState(iPF_E ) = 0.1_AR / ( Gamma_IDEAL - One )

      CASE( 'IsolatedShock' )

        XD = Half

        Vs = 0.01_AR

        RightState(iPF_D)  = 1.0_AR
        RightState(iPF_V1) = -0.9_AR
        RightState(iPF_V2) = 0.0_AR
        RightState(iPF_V3) = 0.0_AR
        RightState(iPF_E)  = 1.0_AR / ( Gamma_IDEAL - One )

        CALL ComputeLeftState &
               ( Vs,                 &
                 RightState(iPF_D ), &
                 RightState(iPF_V1), &
                 RightState(iPF_E ) * ( Gamma_IDEAL - One ), &
                 LeftState (iPF_D ), &
                 LeftState (iPF_V1), &
                 LeftState (iPF_E ) )

        LeftState(iPF_V2) = 0.0_AR
        LeftState(iPF_V3) = 0.0_AR

      CASE( 'IsolatedContact' )

        Vs = 0.01_AR
        XD = Half

        LeftState(iPF_D ) = 5.9718209694880811e0_AR
        LeftState(iPF_V1) = Vs
        LeftState(iPF_V2) = 0.0_AR
        LeftState(iPF_V3) = 0.0_AR
        LeftState(iPF_E ) = 1.0_AR / ( Gamma_IDEAL - One )

        RightState(iPF_D ) = 1.0_AR
        RightState(iPF_V1) = Vs
        RightState(iPF_V2) = 0.0_AR
        RightState(iPF_V3) = 0.0_AR
        RightState(iPF_E ) = 1.0_AR / ( Gamma_IDEAL - One )

      CASE( 'MBProblem1' )

        XD = Half

        LeftState(iPF_D ) = 1.0_AR
        LeftState(iPF_V1) = 0.9_AR
        LeftState(iPF_V2) = 0.0_AR
        LeftState(iPF_V3) = 0.0_AR
        LeftState(iPF_E ) = 1.0_AR / ( Gamma_IDEAL - One )

        RightState(iPF_D ) = 1.0_AR
        RightState(iPF_V1) = 0.0_AR
        RightState(iPF_V2) = 0.0_AR
        RightState(iPF_V3) = 0.0_AR
        RightState(iPF_E ) = 10.0_AR / ( Gamma_IDEAL - One )

      CASE( 'MBProblem4' )

        XD = Half

        LeftState(iPF_D ) = 1.0_AR
        LeftState(iPF_V1) = 0.0_AR
        LeftState(iPF_V2) = 0.0_AR
        LeftState(iPF_V3) = 0.0_AR
        LeftState(iPF_E ) = 1.0e3_AR / ( Gamma_IDEAL - One )

        RightState(iPF_D ) = 1.0_AR
        RightState(iPF_V1) = 0.0_AR
        RightState(iPF_V2) = 0.0_AR
        RightState(iPF_V3) = 0.0_AR
        RightState(iPF_E ) = 1.0e-2_AR / ( Gamma_IDEAL - One )

      CASE( 'PerturbedShockTube' )

        XD = Half

        LeftState(iPF_D ) = 5.0_AR
        LeftState(iPF_V1) = 0.0_AR
        LeftState(iPF_V2) = 0.0_AR
        LeftState(iPF_V3) = 0.0_AR
        LeftState(iPF_E ) = 50.0_AR / ( Gamma_IDEAL - One )

        RightState(iPF_D ) = 0.0_AR ! --- Dummy ---
        RightState(iPF_V1) = 0.0_AR
        RightState(iPF_V2) = 0.0_AR
        RightState(iPF_V3) = 0.0_AR
        RightState(iPF_E ) = 5.0_AR / ( Gamma_IDEAL - One )

      CASE( 'ShockReflection' )

        XD = One

        LeftState(iPF_D ) = 1.0_AR
        LeftState(iPF_V1) = 0.99999_AR
        LeftState(iPF_V2) = 0.0_AR
        LeftState(iPF_V3) = 0.0_AR
        LeftState(iPF_E ) = 0.01_AR / ( Gamma_IDEAL - One )

        ! --- All of these are dummies ---
        RightState(iPF_D ) = 0.0_AR
        RightState(iPF_V1) = 0.0_AR
        RightState(iPF_V2) = 0.0_AR
        RightState(iPF_V3) = 0.0_AR
        RightState(iPF_E ) = 0.0_AR

      CASE DEFAULT

        IF( amrex_parallel_ioprocessor() )THEN

          WRITE(*,*)
          WRITE(*,'(A,A)') &
            'Invalid choice for RiemannProblemName: ', &
            TRIM( RiemannProblemName )
          WRITE(*,'(A)') 'Valid choices:'
          WRITE(*,'(A)') &
            "  'Sod' - &
            Sod's shock tube"
          WRITE(*,'(A)') &
            "  'MBProblem1' - &
            Mignone & Bodo (2005) MNRAS, 364, 126, Problem 1"
          WRITE(*,'(A)') &
            "  'MBProblem4' - &
            Mignone & Bodo (2005) MNRAS, 364, 126, Problem 4"
          WRITE(*,'(A)') &
            "  'PerturbedShockTube' - &
            Del Zanna & Bucciantini (2002) AA, 390, 1177, &
            Sinusoidal density perturbation"
          WRITE(*,'(A)') &
            "  'ShockReflection' - &
            Del Zanna & Bucciantini (2002) AA, 390, 1177, &
            Planar shock reflection"
          WRITE(*,*)
          WRITE(*,'(A)') 'Stopping...'

        END IF

        CALL DescribeError_Euler( 99 )

    END SELECT

    IF( amrex_parallel_ioprocessor() )THEN

      IF( TRIM( RiemannProblemName ) .EQ. 'IsolatedShock' )THEN

        WRITE(*,'(6x,A,ES14.6E3)') 'Shock Velocity = ', Vs
        WRITE(*,*)

      END IF

      WRITE(*,'(6x,A,F8.6)') 'Gamma_IDEAL = ', Gamma_IDEAL
      WRITE(*,*)
      WRITE(*,'(6x,A,F8.6)') 'XD = ', XD
      WRITE(*,*)
      WRITE(*,'(6x,A)') 'Right State:'
      WRITE(*,*)
      WRITE(*,'(8x,A,ES14.6E3)') 'PF_D  = ', RightState(iPF_D )
      WRITE(*,'(8x,A,ES14.6E3)') 'PF_V1 = ', RightState(iPF_V1)
      WRITE(*,'(8x,A,ES14.6E3)') 'PF_V2 = ', RightState(iPF_V2)
      WRITE(*,'(8x,A,ES14.6E3)') 'PF_V3 = ', RightState(iPF_V3)
      WRITE(*,'(8x,A,ES14.6E3)') 'PF_E  = ', RightState(iPF_E )
      WRITE(*,*)
      WRITE(*,'(6x,A)') 'Left State:'
      WRITE(*,*)
      WRITE(*,'(8x,A,ES14.6E3)') 'PF_D  = ', LeftState(iPF_D )
      WRITE(*,'(8x,A,ES14.6E3)') 'PF_V1 = ', LeftState(iPF_V1)
      WRITE(*,'(8x,A,ES14.6E3)') 'PF_V2 = ', LeftState(iPF_V2)
      WRITE(*,'(8x,A,ES14.6E3)') 'PF_V3 = ', LeftState(iPF_V3)
      WRITE(*,'(8x,A,ES14.6E3)') 'PF_E  = ', LeftState(iPF_E )
      WRITE(*,*)

    END IF

    DO iLevel = 0, nLevels-1

      CALL amrex_mfiter_build( MFI, MF_uGF(iLevel), tiling = .TRUE. )

      DO WHILE( MFI % next() )

        uGF => MF_uGF(iLevel) % DataPtr( MFI )
        uCF => MF_uCF(iLevel) % DataPtr( MFI )

        BX = MFI % tilebox()

        lo_G = LBOUND( uGF )
        hi_G = UBOUND( uGF )

        lo_F = LBOUND( uCF )
        hi_F = UBOUND( uCF )

        DO iX3 = BX % lo(3), BX % hi(3)
        DO iX2 = BX % lo(2), BX % hi(2)
        DO iX1 = BX % lo(1), BX % hi(1)

          uGF_K &
            = RESHAPE( uGF(iX1,iX2,iX3,lo_G(4):hi_G(4)), [ nDOFX, nGF ] )

          DO iNodeX = 1, nDOFX

            iNodeX1 = NodeNumberTableX(1,iNodeX)

            X1 = NodeCoordinate( MeshX(1), iX1, iNodeX1 )

            IF( X1 .LE. XD ) THEN

              uPF_K(iNodeX,iPF_D)  = LeftState(iPF_D )
              uPF_K(iNodeX,iPF_V1) = LeftState(iPF_V1)
              uPF_K(iNodeX,iPF_V2) = LeftState(iPF_V2)
              uPF_K(iNodeX,iPF_V3) = LeftState(iPF_V3)
              uPF_K(iNodeX,iPF_E)  = LeftState(iPF_E )

            ELSE

              uPF_K(iNodeX,iPF_D)  = RightState(iPF_D )
              uPF_K(iNodeX,iPF_V1) = RightState(iPF_V1)
              uPF_K(iNodeX,iPF_V2) = RightState(iPF_V2)
              uPF_K(iNodeX,iPF_V3) = RightState(iPF_V3)
              uPF_K(iNodeX,iPF_E)  = RightState(iPF_E )

              IF( TRIM( RiemannProblemName ) .EQ. 'PerturbedShockTube' ) &
                uPF_k(iNodeX,iPF_D) &
                  = 2.0_AR + 0.3_AR * SIN( 50.0_AR * X1 )

            END IF

          END DO

          CALL ComputePressureFromPrimitive &
                 ( uPF_K(:,iPF_D), uPF_K(:,iPF_E), uPF_K(:,iPF_Ne), &
                   uAF_K(:,iAF_P) )

          CALL ComputeConserved_Euler &
                 ( uPF_K(:,iPF_D ), uPF_K(:,iPF_V1), uPF_K(:,iPF_V2), &
                   uPF_K(:,iPF_V3), uPF_K(:,iPF_E ), uPF_K(:,iPF_Ne), &
                   uCF_K(:,iCF_D ), uCF_K(:,iCF_S1), uCF_K(:,iCF_S2), &
                   uCF_K(:,iCF_S3), uCF_K(:,iCF_E ), uCF_K(:,iCF_Ne), &
                   uGF_K(:,iGF_Gm_dd_11), &
                   uGF_K(:,iGF_Gm_dd_22), &
                   uGF_K(:,iGF_Gm_dd_33), &
                   uAF_K(:,iAF_P) )

          uCF(iX1,iX2,iX3,lo_F(4):hi_F(4)) &
            = RESHAPE( uCF_K, [ hi_F(4) - lo_F(4) + 1 ] )

        END DO
        END DO
        END DO

      END DO

      CALL amrex_mfiter_destroy( MFI )

    END DO

    DO iDim = 1, 3

      CALL DestroyMesh( MeshX(iDim) )

    END DO

  END SUBROUTINE InitializeFields_RiemannProblem1D


  SUBROUTINE InitializeFields_RiemannProblem2D( MF_uGF, MF_uCF )

    TYPE(amrex_multifab), INTENT(in)    :: MF_uGF(0:nLevels-1)
    TYPE(amrex_multifab), INTENT(inout) :: MF_uCF(0:nLevels-1)

    ! --- thornado ---
    INTEGER        :: iDim
    INTEGER        :: iX1, iX2, iX3
    INTEGER        :: iNodeX, iNodeX1, iNodeX2
    REAL(AR)       :: X1, X2
    REAL(AR)       :: uGF_K(nDOFX,nGF)
    REAL(AR)       :: uCF_K(nDOFX,nCF)
    REAL(AR)       :: uPF_K(nDOFX,nPF)
    REAL(AR)       :: uAF_K(nDOFX,nAF)
    TYPE(MeshType) :: MeshX(3)

    ! --- AMReX ---
    INTEGER                       :: iLevel
    INTEGER                       :: lo_G(4), hi_G(4)
    INTEGER                       :: lo_F(4), hi_F(4)
    TYPE(amrex_box)               :: BX
    TYPE(amrex_mfiter)            :: MFI
    TYPE(amrex_parmparse)         :: PP
    REAL(AR), CONTIGUOUS, POINTER :: uGF(:,:,:,:)
    REAL(AR), CONTIGUOUS, POINTER :: uCF(:,:,:,:)

    ! --- Problem-specific parameters ---
    CHARACTER(LEN=:), ALLOCATABLE :: RiemannProblemName
    REAL(AR) :: X1D, X2D, Vs, V2
    REAL(AR) :: NE(nPF), NW(nPF), SE(nPF), SW(nPF)

    RiemannProblemName = 'DzB2002'
    CALL amrex_parmparse_build( PP, 'thornado' )
      CALL PP % query( 'RiemannProblemName', RiemannProblemName )
    CALL amrex_parmparse_destroy( PP )

    uGF_K = Zero
    uCF_K = Zero
    uPF_K = Zero
    uAF_K = Zero

    DO iDim = 1, 3

      CALL CreateMesh &
             ( MeshX(iDim), nX(iDim), nNodesX(iDim), 0, &
               xL(iDim), xR(iDim) )

    END DO

    IF( amrex_parallel_ioprocessor() )THEN

      WRITE(*,*)
      WRITE(*,'(A4,A,A)') &
        '', 'Riemann Problem Name: ', TRIM( RiemannProblemName )
      WRITE(*,*)

    END IF

    SELECT CASE( TRIM( RiemannProblemName ) )

      CASE( 'DzB2002' )

        X1D = Half
        X2D = Half

        NE(iPF_D ) = 0.1_AR
        NE(iPF_V1) = 0.0_AR
        NE(iPF_V2) = 0.0_AR
        NE(iPF_V3) = 0.0_AR
        NE(iPF_E ) = 0.01_AR / ( Gamma_IDEAL - One )

        NW(iPF_D ) = 0.1_AR
        NW(iPF_V1) = 0.99_AR
        NW(iPF_V2) = 0.0_AR
        NW(iPF_V3) = 0.0_AR
        NW(iPF_E ) = 1.0_AR / ( Gamma_IDEAL - One )

        SW(iPF_D ) = 0.5_AR
        SW(iPF_V1) = 0.0_AR
        SW(iPF_V2) = 0.0_AR
        SW(iPF_V3) = 0.0_AR
        SW(iPF_E ) = 1.0_AR / ( Gamma_IDEAL - One )

        SE(iPF_D ) = 0.1_AR
        SE(iPF_V1) = 0.0_AR
        SE(iPF_V2) = 0.99_AR
        SE(iPF_V3) = 0.0_AR
        SE(iPF_E ) = 1.0_AR / ( Gamma_IDEAL - One )

      CASE( 'IsolatedShock' )

        X1D = Half
        X2D = Half

        Vs  = 0.01_AR

        NE(iPF_D ) = 1.0_AR
        NE(iPF_V1) = -0.9_AR
        NE(iPF_V2) = 0.0_AR
        NE(iPF_V3) = 0.0_AR
        NE(iPF_E ) = 1.0_AR / ( Gamma_IDEAL - One )

        CALL ComputeLeftState &
               ( Vs, &
                 NE(iPF_D ), &
                 NE(iPF_V1), &
                 NE(iPF_E ) * ( Gamma_IDEAL - One ), &
                 NW(iPF_D ), &
                 NW(iPF_V1), &
                 NW(iPF_E ) )

        NW(iPF_V2) = 0.0_AR
        NW(iPF_V3) = 0.0_AR

        SE(iPF_D ) = 1.0_AR
        SE(iPF_V1) = -0.9_AR
        SE(iPF_V2) = 0.0_AR
        SE(iPF_V3) = 0.0_AR
        SE(iPF_E ) = 1.0_AR / ( Gamma_IDEAL - One )

        CALL ComputeLeftState &
               ( Vs, &
                 SE(iPF_D ), &
                 SE(iPF_V1), &
                 SE(iPF_E ) * ( Gamma_IDEAL - One ), &
                 SW(iPF_D ), &
                 SW(iPF_V1), &
                 SW(iPF_E ) )

        SW(iPF_V2) = 0.0_AR
        SW(iPF_V3) = 0.0_AR

      CASE DEFAULT

        IF( amrex_parallel_ioprocessor() )THEN

          WRITE(*,*)
          WRITE(*,'(A,A)') &
            'Invalid choice for RiemannProblemName: ', &
            TRIM( RiemannProblemName )
          WRITE(*,'(A)') 'Valid choices:'
          WRITE(*,'(A)') &
            "  'DzB2002' - &
            Del Zanna & Bucciantini (2002) AA, 390, 1177, Figure 6"
          WRITE(*,'(A)') '  IsolatedShock'
          WRITE(*,*)
          WRITE(*,'(A)') 'Stopping...'

        END IF

        CALL DescribeError_Euler( 99 )

    END SELECT

    IF( amrex_parallel_ioprocessor() )THEN

      IF( TRIM( RiemannProblemName ) .EQ. 'IsolatedShock' )THEN

        WRITE(*,'(6x,A,ES14.6E3)') 'Shock Velocity = ', Vs
        WRITE(*,*)

      END IF

      WRITE(*,'(6x,A,F8.6)') 'Gamma_IDEAL = ', Gamma_IDEAL
      WRITE(*,*)
      WRITE(*,'(6x,A,F8.6)') 'X1D = ', X1D
      WRITE(*,'(6x,A,F8.6)') 'X2D = ', X2D
      WRITE(*,*)
      WRITE(*,'(6x,A)') 'NE:'
      WRITE(*,*)
      WRITE(*,'(8x,A,ES14.6E3)') 'PF_D  = ', NE(iPF_D )
      WRITE(*,'(8x,A,ES14.6E3)') 'PF_V1 = ', NE(iPF_V1)
      WRITE(*,'(8x,A,ES14.6E3)') 'PF_V2 = ', NE(iPF_V2)
      WRITE(*,'(8x,A,ES14.6E3)') 'PF_V3 = ', NE(iPF_V3)
      WRITE(*,'(8x,A,ES14.6E3)') 'PF_E  = ', NE(iPF_E )
      WRITE(*,*)
      WRITE(*,'(6x,A)') 'NW:'
      WRITE(*,*)
      WRITE(*,'(8x,A,ES14.6E3)') 'PF_D  = ', NW(iPF_D )
      WRITE(*,'(8x,A,ES14.6E3)') 'PF_V1 = ', NW(iPF_V1)
      WRITE(*,'(8x,A,ES14.6E3)') 'PF_V2 = ', NW(iPF_V2)
      WRITE(*,'(8x,A,ES14.6E3)') 'PF_V3 = ', NW(iPF_V3)
      WRITE(*,'(8x,A,ES14.6E3)') 'PF_E  = ', NW(iPF_E )
      WRITE(*,*)
      WRITE(*,'(6x,A)') 'SW:'
      WRITE(*,*)
      WRITE(*,'(8x,A,ES14.6E3)') 'PF_D  = ', SW(iPF_D )
      WRITE(*,'(8x,A,ES14.6E3)') 'PF_V1 = ', SW(iPF_V1)
      WRITE(*,'(8x,A,ES14.6E3)') 'PF_V2 = ', SW(iPF_V2)
      WRITE(*,'(8x,A,ES14.6E3)') 'PF_V3 = ', SW(iPF_V3)
      WRITE(*,'(8x,A,ES14.6E3)') 'PF_E  = ', SW(iPF_E )
      WRITE(*,*)
      WRITE(*,'(6x,A)') 'SE:'
      WRITE(*,*)
      WRITE(*,'(8x,A,ES14.6E3)') 'PF_D  = ', SE(iPF_D )
      WRITE(*,'(8x,A,ES14.6E3)') 'PF_V1 = ', SE(iPF_V1)
      WRITE(*,'(8x,A,ES14.6E3)') 'PF_V2 = ', SE(iPF_V2)
      WRITE(*,'(8x,A,ES14.6E3)') 'PF_V3 = ', SE(iPF_V3)
      WRITE(*,'(8x,A,ES14.6E3)') 'PF_E  = ', SE(iPF_E )
      WRITE(*,*)

    END IF

    DO iLevel = 0, nLevels-1

      CALL amrex_mfiter_build( MFI, MF_uGF(iLevel), tiling = .TRUE. )

      DO WHILE( MFI % next() )

        uGF => MF_uGF(iLevel) % DataPtr( MFI )
        uCF => MF_uCF(iLevel) % DataPtr( MFI )

        BX = MFI % tilebox()

        lo_G = LBOUND( uGF )
        hi_G = UBOUND( uGF )

        lo_F = LBOUND( uCF )
        hi_F = UBOUND( uCF )

        DO iX3 = BX % lo(3), BX % hi(3)
        DO iX2 = BX % lo(2), BX % hi(2)
        DO iX1 = BX % lo(1), BX % hi(1)

          uGF_K &
            = RESHAPE( uGF(iX1,iX2,iX3,lo_G(4):hi_G(4)), [ nDOFX, nGF ] )

          DO iNodeX = 1, nDOFX

            iNodeX1 = NodeNumberTableX(1,iNodeX)
            iNodeX2 = NodeNumberTableX(2,iNodeX)

            X1 = NodeCoordinate( MeshX(1), iX1, iNodeX1 )
            X2 = NodeCoordinate( MeshX(2), iX2, iNodeX2 )

            ! --- NE ---
            IF     ( X1 .GT. X1D .AND. X2 .GT. X2D )THEN

              uPF_K(iNodeX,iPF_D ) = NE(iPF_D )
              uPF_K(iNodeX,iPF_V1) = NE(iPF_V1)
              uPF_K(iNodeX,iPF_V2) = NE(iPF_V2)
              uPF_K(iNodeX,iPF_V3) = NE(iPF_V3)
              uPF_K(iNodeX,iPF_E ) = NE(iPF_E )

            ! --- NW ---
            ELSE IF( X1 .LE. X1D .AND. X2 .GT. X2D )THEN

              uPF_K(iNodeX,iPF_D ) = NW(iPF_D )
              uPF_K(iNodeX,iPF_V1) = NW(iPF_V1)
              uPF_K(iNodeX,iPF_V2) = NW(iPF_V2)
              uPF_K(iNodeX,iPF_V3) = NW(iPF_V3)
              uPF_K(iNodeX,iPF_E ) = NW(iPF_E )

            ! --- SW ---
            ELSE IF( X1 .LE. X1D .AND. X2 .LE. X2D )THEN

              uPF_K(iNodeX,iPF_D ) = SW(iPF_D )
              uPF_K(iNodeX,iPF_V1) = SW(iPF_V1)
              uPF_K(iNodeX,iPF_V2) = SW(iPF_V2)
              uPF_K(iNodeX,iPF_V3) = SW(iPF_V3)
              uPF_K(iNodeX,iPF_E ) = SW(iPF_E )

            ! --- SE ---
            ELSE

              uPF_K(iNodeX,iPF_D ) = SE(iPF_D )
              uPF_K(iNodeX,iPF_V1) = SE(iPF_V1)
              uPF_K(iNodeX,iPF_V2) = SE(iPF_V2)
              uPF_K(iNodeX,iPF_V3) = SE(iPF_V3)
              uPF_K(iNodeX,iPF_E ) = SE(iPF_E )

            END IF

            IF( TRIM( RiemannProblemName ) .EQ. 'IsolatedShock' )THEN

              ! --- Perturb velocity in X2-direction ---
              CALL RANDOM_NUMBER( V2 )
              uPF_K(iNodeX,iPF_V2) = 1.0e-13_AR * ( Two * V2 - One )

            END IF

          END DO

          CALL ComputePressureFromPrimitive &
                 ( uPF_K(:,iPF_D), uPF_K(:,iPF_E), uPF_K(:,iPF_Ne), &
                   uAF_K(:,iAF_P) )

          CALL ComputeConserved_Euler &
                 ( uPF_K(:,iPF_D ), uPF_K(:,iPF_V1), uPF_K(:,iPF_V2), &
                   uPF_K(:,iPF_V3), uPF_K(:,iPF_E ), uPF_K(:,iPF_Ne), &
                   uCF_K(:,iCF_D ), uCF_K(:,iCF_S1), uCF_K(:,iCF_S2), &
                   uCF_K(:,iCF_S3), uCF_K(:,iCF_E ), uCF_K(:,iCF_Ne), &
                   uGF_K(:,iGF_Gm_dd_11), &
                   uGF_K(:,iGF_Gm_dd_22), &
                   uGF_K(:,iGF_Gm_dd_33), &
                   uAF_K(:,iAF_P) )

          uCF(iX1,iX2,iX3,lo_F(4):hi_F(4)) &
            = RESHAPE( uCF_K, [ hi_F(4) - lo_F(4) + 1 ] )

        END DO
        END DO
        END DO

      END DO

      CALL amrex_mfiter_destroy( MFI )

    END DO

    DO iDim = 1, 3

      CALL DestroyMesh( MeshX(iDim) )

    END DO

  END SUBROUTINE InitializeFields_RiemannProblem2D


    ! --- Relativistic 2D Kelvin-Helmholtz instability a la
  !     Radice & Rezzolla, (2012), AA, 547, A26 ---
  SUBROUTINE InitializeFields_KelvinHelmholtz( MF_uGF, MF_uCF )

    TYPE(amrex_multifab), INTENT(in)    :: MF_uGF(0:nLevels-1)
    TYPE(amrex_multifab), INTENT(inout) :: MF_uCF(0:nLevels-1)

    ! --- thornado ---
    INTEGER        :: iDim
    INTEGER        :: iX1, iX2, iX3
    INTEGER        :: iNodeX, iNodeX1, iNodeX2
    REAL(AR)       :: X1, X2
    REAL(AR)       :: uGF_K(nDOFX,nGF)
    REAL(AR)       :: uCF_K(nDOFX,nCF)
    REAL(AR)       :: uPF_K(nDOFX,nPF)
    REAL(AR)       :: uAF_K(nDOFX,nAF)
    TYPE(MeshType) :: MeshX(3)

    ! --- AMReX ---
    INTEGER                       :: iLevel
    INTEGER                       :: lo_G(4), hi_G(4)
    INTEGER                       :: lo_F(4), hi_F(4)
    TYPE(amrex_box)               :: BX
    TYPE(amrex_mfiter)            :: MFI
    REAL(AR), CONTIGUOUS, POINTER :: uGF(:,:,:,:)
    REAL(AR), CONTIGUOUS, POINTER :: uCF(:,:,:,:)

    ! --- Problem-dependent Parameters ---
    REAL(AR) :: a      = 0.01_AR
    REAL(AR) :: Vshear = Half
    REAL(AR) :: A0     = 0.1_AR ! --- Perturbation amplitude ---
    REAL(AR) :: sigma  = 0.1_AR
    REAL(AR) :: rho0   = 0.505_AR
    REAL(AR) :: rho1   = 0.495_AR

    uGF_K = Zero
    uCF_K = Zero
    uPF_K = Zero
    uAF_K = Zero

    DO iDim = 1, 3

      CALL CreateMesh &
             ( MeshX(iDim), nX(iDim), nNodesX(iDim), 0, &
               xL(iDim), xR(iDim) )

    END DO

    DO iLevel = 0, nLevels-1

      CALL amrex_mfiter_build( MFI, MF_uGF(iLevel), tiling = .TRUE. )

      DO WHILE( MFI % next() )

        uGF => MF_uGF(iLevel) % DataPtr( MFI )
        uCF => MF_uCF(iLevel) % DataPtr( MFI )

        BX = MFI % tilebox()

        lo_G = LBOUND( uGF )
        hi_G = UBOUND( uGF )

        lo_F = LBOUND( uCF )
        hi_F = UBOUND( uCF )

        DO iX3 = BX % lo(3), BX % hi(3)
        DO iX2 = BX % lo(2), BX % hi(2)
        DO iX1 = BX % lo(1), BX % hi(1)

          uGF_K &
            = RESHAPE( uGF(iX1,iX2,iX3,lo_G(4):hi_G(4)), [ nDOFX, nGF ] )

          DO iNodeX = 1, nDOFX

            iNodeX1 = NodeNumberTableX(1,iNodeX)
            iNodeX2 = NodeNumberTableX(2,iNodeX)

            X1 = NodeCoordinate( MeshX(1), iX1, iNodeX1 )
            X2 = NodeCoordinate( MeshX(2), iX2, iNodeX2 )

            ! --- V1 ---
            IF( X2 .GT. Zero )THEN

              uPF_K(iNodeX,iPF_V1) &
                = +Vshear * TANH( ( X2 - Half ) / a )

            ELSE

              ! --- Paper has a typo here, the minus sign is required ---
              uPF_K(iNodeX,iPF_V1) &
                = -Vshear * TANH( ( X2 + Half ) / a )

            END IF

            ! --- V2 ---
            IF( X2 .GT. Zero )THEN

              uPF_K(iNodeX,iPF_V2) &
                =  A0 * Vshear * SIN( TwoPi * X1 ) &
                    * EXP( -( ( X2 - Half )**2 / sigma ) )

            ELSE

              uPF_K(iNodeX,iPF_V2) &
                = -A0 * Vshear * SIN( TwoPi * X1 ) &
                    * EXP( -( ( X2 + Half )**2 / sigma ) )

            END IF

            ! --- rho ---
            IF( X2 .GT. Zero )THEN

              uPF_K(iNodeX,iPF_D) &
                = rho0 + rho1 * TANH( ( X2 - Half ) / a )

            ELSE

              uPF_K(iNodeX,iPF_D) &
                = rho0 - rho1 * TANH( ( X2 + Half ) / a )

            END IF

            uPF_K(iNodeX,iPF_V3) = Zero
            uPF_K(iNodeX,iPF_E)  = One / ( Gamma_IDEAL - One )

          END DO

          CALL ComputePressureFromPrimitive &
                 ( uPF_K(:,iPF_D), uPF_K(:,iPF_E), uPF_K(:,iPF_Ne), &
                   uAF_K(:,iAF_P) )

          CALL ComputeConserved_Euler &
                 ( uPF_K(:,iPF_D ), uPF_K(:,iPF_V1), uPF_K(:,iPF_V2), &
                   uPF_K(:,iPF_V3), uPF_K(:,iPF_E ), uPF_K(:,iPF_Ne), &
                   uCF_K(:,iCF_D ), uCF_K(:,iCF_S1), uCF_K(:,iCF_S2), &
                   uCF_K(:,iCF_S3), uCF_K(:,iCF_E ), uCF_K(:,iCF_Ne), &
                   uGF_K(:,iGF_Gm_dd_11), &
                   uGF_K(:,iGF_Gm_dd_22), &
                   uGF_K(:,iGF_Gm_dd_33), &
                   uAF_K(:,iAF_P) )

          uCF(iX1,iX2,iX3,lo_F(4):hi_F(4)) &
            = RESHAPE( uCF_K, [ hi_F(4) - lo_F(4) + 1 ] )

        END DO
        END DO
        END DO

      END DO

      CALL amrex_mfiter_destroy( MFI )

    END DO

    DO iDim = 1, 3

      CALL DestroyMesh( MeshX(iDim) )

    END DO

  END SUBROUTINE InitializeFields_KelvinHelmholtz


  ! --- Relativistic 3D Kelvin-Helmholtz instability a la
  !     Radice & Rezzolla, (2012), AA, 547, A26 ---
  SUBROUTINE InitializeFields_KelvinHelmholtz3D( MF_uGF, MF_uCF )

    TYPE(amrex_multifab), INTENT(in)    :: MF_uGF(0:nLevels-1)
    TYPE(amrex_multifab), INTENT(inout) :: MF_uCF(0:nLevels-1)

    ! --- thornado ---
    INTEGER        :: iDim
    INTEGER        :: iX1, iX2, iX3
    INTEGER        :: iNodeX, iNodeX1, iNodeX2
    REAL(AR)       :: X1, X2
    REAL(AR)       :: uGF_K(nDOFX,nGF)
    REAL(AR)       :: uCF_K(nDOFX,nCF)
    REAL(AR)       :: uPF_K(nDOFX,nPF)
    REAL(AR)       :: uAF_K(nDOFX,nAF)
    TYPE(MeshType) :: MeshX(3)

    ! --- AMReX ---
    INTEGER                       :: iLevel
    INTEGER                       :: lo_G(4), hi_G(4)
    INTEGER                       :: lo_F(4), hi_F(4)
    TYPE(amrex_box)               :: BX
    TYPE(amrex_mfiter)            :: MFI
    REAL(AR), CONTIGUOUS, POINTER :: uGF(:,:,:,:)
    REAL(AR), CONTIGUOUS, POINTER :: uCF(:,:,:,:)

    ! --- Problem-dependent Parameters ---
    REAL(AR) :: a      = 0.01_AR
    REAL(AR) :: Vshear = Half
    REAL(AR) :: A0     = 0.1_AR ! --- Perturbation amplitude ---
    REAL(AR) :: sigma  = 0.1_AR
    REAL(AR) :: rho0   = 0.505_AR
    REAL(AR) :: rho1   = 0.495_AR
    REAL(AR) :: Vz

    uGF_K = Zero
    uCF_K = Zero
    uPF_K = Zero
    uAF_K = Zero

    DO iDim = 1, 3

      CALL CreateMesh &
             ( MeshX(iDim), nX(iDim), nNodesX(iDim), 0, &
               xL(iDim), xR(iDim) )

    END DO

    DO iLevel = 0, nLevels-1

      CALL amrex_mfiter_build( MFI, MF_uGF(iLevel), tiling = .TRUE. )

      DO WHILE( MFI % next() )

        uGF => MF_uGF(iLevel) % DataPtr( MFI )
        uCF => MF_uCF(iLevel) % DataPtr( MFI )

        BX = MFI % tilebox()

        lo_G = LBOUND( uGF )
        hi_G = UBOUND( uGF )

        lo_F = LBOUND( uCF )
        hi_F = UBOUND( uCF )

        DO iX3 = BX % lo(3), BX % hi(3)
        DO iX2 = BX % lo(2), BX % hi(2)
        DO iX1 = BX % lo(1), BX % hi(1)

          uGF_K &
            = RESHAPE( uGF(iX1,iX2,iX3,lo_G(4):hi_G(4)), [ nDOFX, nGF ] )

          DO iNodeX = 1, nDOFX

            iNodeX1 = NodeNumberTableX(1,iNodeX)
            iNodeX2 = NodeNumberTableX(2,iNodeX)

            X1 = NodeCoordinate( MeshX(1), iX1, iNodeX1 )
            X2 = NodeCoordinate( MeshX(2), iX2, iNodeX2 )

            ! --- V1 ---
            IF( X2 .GT. Zero )THEN

              uPF_K(iNodeX,iPF_V1) &
                = +Vshear * TANH( ( X2 - Half ) / a )

            ELSE

              ! --- Paper has a typo here, the minus sign is required ---
              uPF_K(iNodeX,iPF_V1) &
                = -Vshear * TANH( ( X2 + Half ) / a )

            END IF

            ! --- V2 ---
            IF( X2 .GT. Zero )THEN

              uPF_K(iNodeX,iPF_V2) &
                =  A0 * Vshear * SIN( TwoPi * X1 ) &
                    * EXP( -( ( X2 - Half )**2 / sigma ) )

            ELSE

              uPF_K(iNodeX,iPF_V2) &
                = -A0 * Vshear * SIN( TwoPi * X1 ) &
                    * EXP( -( ( X2 + Half )**2 / sigma ) )

            END IF

            ! --- rho ---
            IF( X2 .GT. Zero )THEN

              uPF_K(iNodeX,iPF_D) &
                = rho0 + rho1 * TANH( ( X2 - Half ) / a )

            ELSE

              uPF_K(iNodeX,iPF_D) &
                = rho0 - rho1 * TANH( ( X2 + Half ) / a )

            END IF

            CALL RANDOM_NUMBER( Vz )

            uPF_K(iNodeX,iPF_V3) = 0.01_AR * Vz

            uPF_K(iNodeX,iPF_E)  = One / ( Gamma_IDEAL - One )

          END DO

          CALL ComputePressureFromPrimitive &
                 ( uPF_K(:,iPF_D), uPF_K(:,iPF_E), uPF_K(:,iPF_Ne), &
                   uAF_K(:,iAF_P) )

          CALL ComputeConserved_Euler &
                 ( uPF_K(:,iPF_D ), uPF_K(:,iPF_V1), uPF_K(:,iPF_V2), &
                   uPF_K(:,iPF_V3), uPF_K(:,iPF_E ), uPF_K(:,iPF_Ne), &
                   uCF_K(:,iCF_D ), uCF_K(:,iCF_S1), uCF_K(:,iCF_S2), &
                   uCF_K(:,iCF_S3), uCF_K(:,iCF_E ), uCF_K(:,iCF_Ne), &
                   uGF_K(:,iGF_Gm_dd_11), &
                   uGF_K(:,iGF_Gm_dd_22), &
                   uGF_K(:,iGF_Gm_dd_33), &
                   uAF_K(:,iAF_P) )

          uCF(iX1,iX2,iX3,lo_F(4):hi_F(4)) &
            = RESHAPE( uCF_K, [ hi_F(4) - lo_F(4) + 1 ] )

        END DO
        END DO
        END DO

      END DO

      CALL amrex_mfiter_destroy( MFI )

    END DO

    DO iDim = 1, 3

      CALL DestroyMesh( MeshX(iDim) )

    END DO

  END SUBROUTINE InitializeFields_KelvinHelmholtz3D


  SUBROUTINE InitializeFields_StandingAccretionShock_Relativistic &
    ( MF_uGF, MF_uCF )

    TYPE(amrex_multifab), INTENT(in)    :: MF_uGF(0:nLevels-1)
    TYPE(amrex_multifab), INTENT(inout) :: MF_uCF(0:nLevels-1)

    ! --- thornado ---
    INTEGER        :: iDim
    INTEGER        :: iX1, iX2, iX3
    INTEGER        :: iNodeX, iNodeX1, iNodeX2, iNodeX3
    REAL(AR)       :: X1, X2
    REAL(AR)       :: uGF_K(nDOFX,nGF)
    REAL(AR)       :: uCF_K(nDOFX,nCF)
    REAL(AR)       :: uPF_K(nDOFX,nPF)
    REAL(AR)       :: uAF_K(nDOFX,nAF)
    TYPE(MeshType) :: MeshX(3)

    ! --- AMReX ---
    INTEGER                       :: iLevel
    INTEGER                       :: lo_G(4), hi_G(4)
    INTEGER                       :: lo_F(4), hi_F(4)
    TYPE(amrex_box)               :: BX
    TYPE(amrex_mfiter)            :: MFI
    REAL(AR), CONTIGUOUS, POINTER :: uGF(:,:,:,:)
    REAL(AR), CONTIGUOUS, POINTER :: uCF(:,:,:,:)
    TYPE(amrex_parmparse)         :: PP

    ! --- Problem-dependent Parameters ---
    INTEGER               :: iX1_1, iX1_2, iNodeX1_1, iNodeX1_2
    REAL(AR)              :: X1_1, X1_2, D_1, D_2, V_1, V_2, P_2
    REAL(AR)              :: Alpha, Psi, V0, VSq, W
    REAL(AR)              :: dX1, PolytropicConstant, MassConstant
    REAL(AR)              :: MassPNS, ShockRadius, AccretionRate, MachNumber
    LOGICAL               :: FirstPreShockElement = .FALSE.
    INTEGER               :: iX_B0(3), iX_E0(3), iX_B1(3), iX_E1(3)
    REAL(AR), ALLOCATABLE :: D(:,:), V(:,:), P(:,:)
    LOGICAL               :: ApplyPerturbation
    INTEGER               :: PerturbationOrder
    REAL(AR)              :: PerturbationAmplitude, &
                             rPerturbationInner, rPerturbationOuter

    ApplyPerturbation     = .FALSE.
    PerturbationOrder     = 0
    PerturbationAmplitude = Zero
    rPerturbationInner    = Zero
    rPerturbationOuter    = Zero
    CALL amrex_parmparse_build( PP, 'SAS' )
      CALL PP % get  ( 'Mass'                 , MassPNS               )
      CALL PP % get  ( 'AccretionRate'        , AccretionRate         )
      CALL PP % get  ( 'ShockRadius'          , ShockRadius           )
      CALL PP % get  ( 'MachNumber'           , MachNumber            )
      CALL PP % query( 'ApplyPerturbation'    , ApplyPerturbation     )
      CALL PP % query( 'PerturbationOrder'    , PerturbationOrder     )
      CALL PP % query( 'PerturbationAmplitude', PerturbationAmplitude )
      CALL PP % query( 'rPerturbationInner'   , rPerturbationInner    )
      CALL PP % query( 'rPerturbationOuter'   , rPerturbationOuter    )
    CALL amrex_parmparse_destroy( PP )

    MassPNS            = MassPNS            * SolarMass
    AccretionRate      = AccretionRate      * SolarMass / Second
    ShockRadius        = ShockRadius        * Kilometer
    rPerturbationInner = rPerturbationInner * Kilometer
    rPerturbationOuter = rPerturbationOuter * Kilometer

    IF( amrex_parallel_ioprocessor() )THEN

      WRITE(*,*)

      WRITE(*,'(6x,A,ES9.2E3,A)') &
        'Shock radius:   ', ShockRadius / Kilometer, ' km'

      WRITE(*,'(6x,A,ES9.2E3,A)') &
        'PNS Mass:       ', MassPNS / SolarMass, ' Msun'

      WRITE(*,'(6x,A,ES9.2E3,A)') &
        'Accretion Rate: ', AccretionRate / ( SolarMass / Second ), &
        ' Msun/s'

      WRITE(*,'(6x,A,ES9.2E3)') &
        'Mach number:    ', MachNumber

      WRITE(*,*)

      WRITE(*,'(6x,A,L)') &
        'Apply Perturbation: ', ApplyPerturbation

      WRITE(*,'(6x,A,I1)') &
        'Perturbation order: ', PerturbationOrder

      WRITE(*,'(6x,A,ES9.2E3)') &
        'Perturbation amplitude: ', PerturbationAmplitude

      WRITE(*,'(6x,A,ES9.2E3,A)') &
        'Inner radius of perturbation: ', rPerturbationInner / Kilometer, ' km'

      WRITE(*,'(6x,A,ES9.2E3,A)') &
        'Outer radius of perturbation: ', rPerturbationOuter / Kilometer, ' km'

    END IF

    uGF_K = Zero
    uCF_K = Zero
    uPF_K = Zero
    uAF_K = Zero

    DO iDim = 1, 3

      CALL CreateMesh &
             ( MeshX(iDim), nX(iDim), nNodesX(iDim), swX(iDim), &
               xL(iDim), xR(iDim) )

    END DO

    iX_B1 = [1,1,1] - swX
    iX_E1 = nX      + swX

    ALLOCATE( D(1:nNodesX(1),iX_B1(1):iX_E1(1)) )
    ALLOCATE( V(1:nNodesX(1),iX_B1(1):iX_E1(1)) )
    ALLOCATE( P(1:nNodesX(1),iX_B1(1):iX_E1(1)) )

    IF( InitializeFromFile )THEN

      CALL ReadFluidFieldsFromFile( iX_B1, iX_E1, D, V, P )

    ELSE

      ! --- Locate first element with un-shocked fluid ---

      X1 = Zero

      DO iX1 = iX_B1(1), iX_E1(1)

        DO iNodeX1 = 1, nNodesX(1)

          dX1 = NodeCoordinate( MeshX(1), iX1, iNodeX1 ) - X1
          X1  = NodeCoordinate( MeshX(1), iX1, iNodeX1 )

          IF( X1 .LE. ShockRadius ) CYCLE

          IF( X1 .GT. ShockRadius .AND. .NOT. FirstPreShockElement )THEN

            iX1_1     = iX1
            iNodeX1_1 = iNodeX1
            X1_1      = X1
            X1_2      = X1 - dX1

            IF( iNodeX1_1 .EQ. 1 )THEN

              iX1_2     = iX1_1 - 1
              iNodeX1_2 = nNodesX(1)

            ELSE

              iX1_2     = iX1_1
              iNodeX1_2 = iNodeX1_1 - 1

            END IF

            FirstPreShockElement = .TRUE.

          END IF

        END DO

      END DO

      ! --- Compute fields, pre-shock ---

      DO iX1 = iX_E1(1), iX1_1, -1

        DO iNodeX1 = nNodesX(1), 1, -1

          X1 = NodeCoordinate( MeshX(1), iX1, iNodeX1 )

          IF( X1 .LE. ShockRadius ) CYCLE

          Alpha = LapseFunction  ( X1, MassPNS )
          Psi   = ConformalFactor( X1, MassPNS )

          V(iNodeX1,iX1) &
            = -Psi**(-2) * SpeedOfLight * SQRT( One - Alpha**2 )

          D(iNodeX1,iX1) &
            = Psi**(-6) * AccretionRate &
                / ( FourPi * X1**2 * ABS( V(iNodeX1,iX1) ) )

          IF( iNodeX1 .EQ. nNodesX(1) .AND. iX1 .EQ. iX_E1(1) )THEN

            VSq = Psi**4 * V(iNodeX1,iX1)**2

            P(iNodeX1,iX1) &
              = D(iNodeX1,iX1) * VSq &
                  / ( MachNumber**2 * Gamma_IDEAL &
                        - Gamma_IDEAL / ( Gamma_IDEAL - One ) &
                        * VSq / SpeedOfLight**2 )

            PolytropicConstant &
              = P(iNodeX1,iX1) * D(iNodeX1,iX1)**( -Gamma_IDEAL )

          END IF

          P(iNodeX1,iX1) &
            = PolytropicConstant * D(iNodeX1,iX1)**( Gamma_IDEAL )

!!$          VSq = Psi**4 * V(iNodeX1,iX1)**2
!!$
!!$          P(iNodeX1,iX1) &
!!$            = D(iNodeX1,iX1) * VSq &
!!$                / ( Gamma_IDEAL * MachNumber**2 ) &
!!$                / ( One - ( VSq / SpeedOfLight**2 ) &
!!$                / ( MachNumber**2 * ( Gamma_IDEAL - One ) ) )

        END DO

      END DO

      ! --- Apply jump conditions ---

      D_1 = D(iNodeX1_1,iX1_1)
      V_1 = V(iNodeX1_1,iX1_1)

      CALL ApplyJumpConditions &
             ( iX1_1, iNodeX1_1, X1_1, D_1, V_1, &
               iX1_2, iNodeX1_2, X1_2, &
               D_2, V_2, P_2, MassPNS, PolytropicConstant )

      IF( amrex_parallel_ioprocessor() )THEN

        WRITE(*,*)
        WRITE(*,'(6x,A)') 'Shock location:'
        WRITE(*,'(8x,A)') 'Pre-shock:'
        WRITE(*,'(10x,A,I4.4)')       'iX1     = ', iX1_1
        WRITE(*,'(10x,A,I2.2)')       'iNodeX1 = ', iNodeX1_1
        WRITE(*,'(10x,A,ES13.6E3,A)') 'X1      = ', X1_1 / Kilometer, ' km'
        WRITE(*,'(8x,A)') 'Post-shock:'
        WRITE(*,'(10x,A,I4.4)')       'iX1     = ', iX1_2
        WRITE(*,'(10x,A,I2.2)')       'iNodeX1 = ', iNodeX1_2
        WRITE(*,'(10x,A,ES13.6E3,A)') 'X1      = ', X1_2 / Kilometer, ' km'
        WRITE(*,*)
        WRITE(*,'(6x,A,ES13.6E3)') &
          'Compression Ratio LOG10(D_2/D_1) = ', LOG( D_2 / D_1 ) / LOG( 1.0d1 )
        WRITE(*,*)

      END IF

      ! --- Compute fields, post-shock ---

      Alpha = LapseFunction  ( X1_1, MassPNS )
      Psi   = ConformalFactor( X1_1, MassPNS )
      W     = LorentzFactor( Psi, V_1 )

      MassConstant = Psi**6 * Alpha * X1_1**2 * D_1 * W * V_1

      V0 = V_2

      DO iX1 = iX1_2, iX_B1(1), -1

        DO iNodeX1 = nNodesX(1), 1, -1

          X1 = NodeCoordinate( MeshX(1), iX1, iNodeX1 )

          IF( X1 .GT. ShockRadius ) CYCLE

          Alpha = LapseFunction  ( X1, MassPNS )
          Psi   = ConformalFactor( X1, MassPNS )

          CALL NewtonRaphson_PostShockVelocity &
                 ( Alpha, Psi, MassConstant, PolytropicConstant, &
                   MassPNS, AccretionRate, X1, V0  )

          V(iNodeX1,iX1) = V0

          W = LorentzFactor( Psi, V0 )

          D(iNodeX1,iX1) &
            = MassConstant / ( Psi**6 * Alpha * X1**2  * W * V0 )

          P(iNodeX1,iX1) &
            = PolytropicConstant * D(iNodeX1,iX1)**( Gamma_IDEAL )

        END DO

      END DO

    END IF

    ! --- Map to 3D domain ---

    DO iLevel = 0, nLevels-1

      CALL amrex_mfiter_build( MFI, MF_uGF(iLevel), tiling = .TRUE. )

      DO WHILE( MFI % next() )

        uGF => MF_uGF(iLevel) % DataPtr( MFI )
        uCF => MF_uCF(iLevel) % DataPtr( MFI )

        BX = MFI % tilebox()

        lo_G = LBOUND( uGF )
        hi_G = UBOUND( uGF )

        lo_F = LBOUND( uCF )
        hi_F = UBOUND( uCF )

        iX_B0 = BX % lo
        iX_E0 = BX % hi
        iX_B1 = BX % lo - swX
        iX_E1 = BX % hi + swX

        DO iX3 = iX_B0(3), iX_E0(3)
        DO iX2 = iX_B0(2), iX_E0(2)
        DO iX1 = iX_B1(1), iX_E1(1)

          uGF_K &
            = RESHAPE( uGF(iX1,iX2,iX3,lo_G(4):hi_G(4)), [ nDOFX, nGF ] )

          DO iNodeX3 = 1, nNodesX(3)
          DO iNodeX2 = 1, nNodesX(2)
          DO iNodeX1 = 1, nNodesX(1)

            iNodeX = NodeNumberX( iNodeX1, iNodeX2, iNodeX3 )

            IF( ApplyPerturbation )THEN

              X1 = NodeCoordinate( MeshX(1), iX1, iNodeX1 )
              X2 = NodeCoordinate( MeshX(2), iX2, iNodeX2 )

              IF( X1 .GE. rPerturbationInner &
                    .AND. X1 .LE. rPerturbationOuter )THEN

                IF( PerturbationOrder .EQ. 0 ) &
                  uPF_K(iNodeX,iPF_D) &
                    = D(iNodeX1,iX1) &
                        * ( One + PerturbationAmplitude )

                IF( PerturbationOrder .EQ. 1 ) &
                  uPF_K(iNodeX,iPF_D) &
                    = D(iNodeX1,iX1) &
                        * ( One + PerturbationAmplitude * COS( X2 ) )

              ELSE

                uPF_K(iNodeX,iPF_D) = D(iNodeX1,iX1)

              END IF

            ELSE

              uPF_K(iNodeX,iPF_D) = D(iNodeX1,iX1)

            END IF

            uPF_K(iNodeX,iPF_V1) = V(iNodeX1,iX1)
            uPF_K(iNodeX,iPF_V2) = Zero
            uPF_K(iNodeX,iPF_V3) = Zero
            uPF_K(iNodeX,iPF_E ) = P(iNodeX1,iX1) / ( Gamma_IDEAL - One )

          END DO
          END DO
          END DO

          CALL ComputePressureFromPrimitive &
                 ( uPF_K(:,iPF_D), uPF_K(:,iPF_E), uPF_K(:,iPF_Ne), &
                   uAF_K(:,iAF_P) )

          CALL ComputeConserved_Euler &
                 ( uPF_K(:,iPF_D ), uPF_K(:,iPF_V1), uPF_K(:,iPF_V2), &
                   uPF_K(:,iPF_V3), uPF_K(:,iPF_E ), uPF_K(:,iPF_Ne), &
                   uCF_K(:,iCF_D ), uCF_K(:,iCF_S1), uCF_K(:,iCF_S2), &
                   uCF_K(:,iCF_S3), uCF_K(:,iCF_E ), uCF_K(:,iCF_Ne), &
                   uGF_K(:,iGF_Gm_dd_11), &
                   uGF_K(:,iGF_Gm_dd_22), &
                   uGF_K(:,iGF_Gm_dd_33), &
                   uAF_K(:,iAF_P) )

          uCF(iX1,iX2,iX3,lo_F(4):hi_F(4)) &
            = RESHAPE( uCF_K, [ hi_F(4) - lo_F(4) + 1 ] )

        END DO
        END DO
        END DO

      END DO

    END DO

    DEALLOCATE( P )
    DEALLOCATE( V )
    DEALLOCATE( D )

    DO iDim = 1, 3

      CALL DestroyMesh( MeshX(iDim) )

    END DO


  END SUBROUTINE InitializeFields_StandingAccretionShock_Relativistic


  ! --- Auxiliary functions/subroutines for SAS problem ---


  SUBROUTINE ReadFluidFieldsFromFile( iX_B1, iX_E1, D, V, P )

    INTEGER,  INTENT(in)  :: iX_B1(3), iX_E1(3)
    REAL(AR), INTENT(out) :: D(1:,iX_B1(1):), V(1:,iX_B1(1):), P(1:,iX_B1(1):)

    CHARACTER(LEN=16) :: FMT
    INTEGER           :: iX1

    OPEN( UNIT = 100, FILE = TRIM( OutputDataFileName ) )

    READ(100,*) FMT

    DO iX1 = iX_B1(1), iX_E1(1)

      READ(100,TRIM(FMT)) D(:,iX1)
      READ(100,TRIM(FMT)) V(:,iX1)
      READ(100,TRIM(FMT)) P(:,iX1)

    END DO

    CLOSE( 100 )

  END SUBROUTINE ReadFluidFieldsFromFile


  SUBROUTINE ApplyJumpConditions &
    ( iX1_1, iNodeX1_1, X1_1, D_1, V_1, &
      iX1_2, iNodeX1_2, X1_2, &
      D_2, V_2, P_2, MassPNS, PolytropicConstant )

    INTEGER,  INTENT(in)  :: iX1_1, iNodeX1_1, iX1_2, iNodeX1_2
    REAL(AR), INTENT(in)  :: X1_1, X1_2, D_1, V_1, MassPNS
    REAL(AR), INTENT(out) :: D_2, V_2, P_2, PolytropicConstant

    REAL(AR) :: Alpha, Psi
    REAL(AR) :: C1, C2, C3, a0, a1, a2, a3, a4
    REAL(AR) :: W

    REAL(AR), PARAMETER :: ShockTolerance     = 0.1_AR
    LOGICAL             :: FoundShockVelocity = .FALSE.

    ! --- Constants from three jump conditions ---

    Alpha = LapseFunction  ( X1_1, MassPNS )
    Psi   = ConformalFactor( X1_1, MassPNS )

    C1 = D_1 * V_1 / Alpha

    C2 = D_1 * SpeedOfLight**2 / Alpha**2 * ( V_1 / SpeedOfLight )**2

    C3 = D_1 * SpeedOfLight**2 / Alpha**2 * V_1

    ! --- Five constants for post-shock fluid three-velocity ---

    a4 = Psi**8 &
          * One / ( Gamma_IDEAL - One )**2 * C3**2 / SpeedOfLight**6
    a3 = -Two * Psi**8 &
          * Gamma_IDEAL / ( Gamma_IDEAL - One )**2 * C2 * C3 / SpeedOfLight**4
    a2 = Psi**4 &
          / SpeedOfLight**2 * ( Psi**4 * Gamma_IDEAL**2 &
          / ( Gamma_IDEAL - One )**2 * C2**2 + Two * One &
          / ( Gamma_IDEAL - One ) &
          * C3**2 / SpeedOfLight**2 + C1**2 * SpeedOfLight**2 )
    a1 = -Two * Psi**4 &
          * Gamma_IDEAL / ( Gamma_IDEAL - One ) * C2 * C3 / SpeedOfLight**2
    a0 = One / SpeedOfLight**2 * ( C3**2 - C1**2 * SpeedOfLight**4 )

    ! --- Use Newton-Raphson method to get post-shock fluid-velocity ---

    V_2 = Two * V_1

    ! --- Ensure that shocked velocity is obtained
    !     instead of smooth solution ---

    FoundShockVelocity = .FALSE.
    DO WHILE( .NOT. FoundShockVelocity )

      V_2 = Half * V_2
      CALL NewtonRaphson_JumpConditions( a0, a1, a2, a3, a4, V_2 )

      IF( ABS( V_2 - V_1 ) / ABS( V_1 ) .GT. ShockTolerance ) &
        FoundShockVelocity = .TRUE.

    END DO

    ! --- Post-shock density, velocity, pressure, and polytropic constant ---

    Psi = ConformalFactor( X1_2, MassPNS )
    W   = LorentzFactor( Psi, V_2 )

    D_2 = ABS( C1 ) * SQRT( One / V_2**2 - Psi**4 / SpeedOfLight**2 )

    P_2 = ( Gamma_IDEAL - One ) / Gamma_IDEAL &
            * ( C3 - D_2 * SpeedOfLight**2 * W**2 * V_2 ) / ( W**2 * V_2 )

    PolytropicConstant = P_2 / D_2**( Gamma_IDEAL )

  END SUBROUTINE ApplyJumpConditions


  SUBROUTINE NewtonRaphson_JumpConditions( a0, a1, a2, a3, a4, V )

    REAL(AR), INTENT(in)    :: a0, a1, a2, a3, a4
    REAL(AR), INTENT(inout) :: V

    REAL(AR) :: f, df, dV
    LOGICAL  :: CONVERGED
    INTEGER  :: ITERATION

    INTEGER,  PARAMETER :: MAX_ITER  = 10
    REAL(AR), PARAMETER :: TOLERANCE = 1.0d-15

    CONVERGED = .FALSE.
    ITERATION = 0
    DO WHILE( .NOT. CONVERGED .AND. ITERATION .LT. MAX_ITER )

      ITERATION = ITERATION + 1

      f  = a4 * V**4 + a3 * V**3 + a2 * V**2 + a1 * V + a0
      df = Four * a4 * V**3 + Three * a3 * V**2 + Two * a2 * V + a1

      dV = -f / df
      V = V + dV

      IF( ABS( dV / V ) .LT. TOLERANCE ) &
        CONVERGED = .TRUE.

    END DO

  END SUBROUTINE NewtonRaphson_JumpConditions


  SUBROUTINE NewtonRaphson_PostShockVelocity &
    ( Alpha, Psi, MassConstant, PolytropicConstant, &
      MassPNS, AccretionRate, X1, V )

    REAL(AR), INTENT(in)    :: Alpha, Psi, MassConstant, &
                               PolytropicConstant, MassPNS, AccretionRate, X1
    REAL(AR), INTENT(inout) :: V

    REAL(AR) :: f, df, dV, W
    INTEGER  :: ITERATION
    LOGICAL  :: CONVERGED

    INTEGER,  PARAMETER :: MAX_ITER  = 20
    REAL(AR), PARAMETER :: TOLERANCE = 1.0d-15

    CONVERGED = .FALSE.
    ITERATION = 0
    DO WHILE( .NOT. CONVERGED .AND. ITERATION .LT. MAX_ITER )

      ITERATION = ITERATION + 1

      W = LorentzFactor( Psi, V )

      f  = Gamma_IDEAL / ( Gamma_IDEAL - One ) &
             * PolytropicConstant / SpeedOfLight**2 * ( MassConstant &
             / ( Psi**6 * Alpha * X1**2 * W * V ) )**( Gamma_IDEAL - One ) &
             - One / ( Alpha * W ) + One

      df = -Gamma_IDEAL * PolytropicConstant / SpeedOfLight**2 &
             * ( MassConstant &
                 / ( Psi**6 * Alpha * X1**2 * W * V ) )**( Gamma_IDEAL - One ) &
                 * ( Psi**4 * V / SpeedOfLight**2 * W**2 + One / V ) &
                 + W / Alpha * Psi**4 * V / SpeedOfLight**2

      dV = -f / df
      V = V + dV

      IF( ABS( dV / V ) .LT. TOLERANCE ) &
        CONVERGED = .TRUE.

    END DO

  END SUBROUTINE NewtonRaphson_PostShockVelocity


  REAL(AR) FUNCTION LapseFunction( R, M )

    REAL(AR), INTENT(in) :: R, M

    ! --- Schwarzschild Metric in Isotropic Coordinates ---

    LapseFunction = ABS( ( MAX( ABS( R ), SqrtTiny ) - Half * M ) &
                       / ( MAX( ABS( R ), SqrtTiny ) + Half * M ) )

    RETURN
  END FUNCTION LapseFunction


  REAL(AR) FUNCTION ConformalFactor( R, M )

    REAL(AR), INTENT(in) :: R, M

    ! --- Schwarzschild Metric in Isotropic Coordinates ---

    ConformalFactor = One + Half * M / MAX( ABS( R ), SqrtTiny )

    RETURN
  END FUNCTION ConformalFactor


  REAL(AR) FUNCTION LorentzFactor( Psi, V )

    REAL(AR), INTENT(in) :: Psi, V

    LorentzFactor = One / SQRT( One - Psi**4 * ( V / SpeedOfLight )**2 )

    RETURN
  END FUNCTION LorentzFactor


  ! --- Auxiliary functions/subroutines for computine left state ---


  SUBROUTINE ComputeLeftState( Vs, DR, VR, PR, DL, VL, PL )

    REAL(AR), INTENT(in)  :: Vs, DR, VR, PR
    REAL(AR), INTENT(out) ::     DL, VL, PL

    CALL ApplyJumpConditions_LeftState( Vs, DR, VR, PR, DL, VL, PL )

    ! --- Return energy-density instead of pressure ---
    PL = PL / ( Gamma_IDEAL - One )

  END SUBROUTINE ComputeLeftState


  SUBROUTINE ApplyJumpConditions_LeftState( Vs, DR, VR, PR, DL, VL, PL )

    REAL(AR), INTENT(in)  :: Vs, DR, VR, PR
    REAL(AR), INTENT(out) ::     DL, VL, PL

    REAL(AR), PARAMETER :: EPS = 1.0e-15_AR

    REAL(AR), PARAMETER :: ToldV = EPS
    REAL(AR), PARAMETER :: TolF  = EPS
    INTEGER,  PARAMETER :: nMaxIter = 1000

    INTEGER :: ITERATION
    REAL(AR) :: D, V, P, F
    REAL(AR) :: Vmin, Vmax, Fmin, Fmax, VV, FF

    IF( VR .LT. Zero )THEN

      Vmin = VR   + EPS
      Vmax = +One - EPS

    ELSE

      Vmin = -One + EPS
      Vmax = VR   - EPS

    END IF

    D = Density ( Vs, DR, VR, Vmin )
    P = Pressure( Vs, DR, VR, PR, D, Vmin )
    Fmin = PostShockVelocity( Vs, DR, VR, PR, D, Vmin, P )

    D = Density ( Vs, DR, VR, Vmax )
    P = Pressure( Vs, DR, VR, PR, D, Vmax )
    Fmax = PostShockVelocity( Vs, DR, VR, PR, D, Vmax, P )

    IF( .NOT. Fmin * Fmax .LT. Zero )THEN

      WRITE(*,*) 'Root not bracketed. Stopping...'
      WRITE(*,*) 'Fmin = ', Fmin
      WRITE(*,*) 'Fmax = ', Fmax

      CALL DescribeError_Euler( 10 )

    END IF

    IF( Fmin .GT. Zero )THEN

      VV = Vmax
      FF = Fmax

      Vmax = Vmin
      Vmin = VV

      Fmax = Fmin
      Fmin = FF

    END IF

    ITERATION = 0
    DO WHILE( ITERATION .LT. nMaxIter )

      ITERATION = ITERATION + 1

      V = ( Vmin + Vmax ) / Two

      D = Density ( Vs, DR, VR, V )
      P = Pressure( Vs, DR, VR, PR, D, V )

      F = PostShockVelocity( Vs, DR, VR, PR, D, V, P )

      IF( ABS( V - Vmin ) / MAX( ABS( Vmax ), ABS( Vmin ) ) .LT. ToldV ) EXIT

      IF( F .GT. Zero )THEN

        Vmax = V
        Fmax = F

     ELSE

        Vmin = V
        Fmin = F

     END IF

    END DO

!!$    WRITE(*,*) 'Converged at iteration ', ITERATION
!!$    WRITE(*,*) '|F|:  ' , ABS( F )
!!$    WRITE(*,*) 'dV/V: ', ABS( V - Vmax ) / ABS( Vmax )

    VL = V
    DL = Density ( Vs, DR, VR, VL )
    PL = Pressure( Vs, DR, VR, PR, DL, VL )

  END SUBROUTINE ApplyJumpConditions_LeftState


  REAL(AR) FUNCTION Density( Vs, DR, VR, VL )

    REAL(AR), INTENT(in) :: Vs, DR, VR, VL

    REAL(AR) :: WR, WL

    WR = LorentzFactor( One, VR )
    WL = LorentzFactor( One, VL )

    Density = DR * ( WR * ( VR - Vs ) ) / ( WL * ( VL - Vs ) )

    RETURN
  END FUNCTION Density


  REAL(AR) FUNCTION Pressure( Vs, DR, VR, PR, DL, VL )

    REAL(AR), INTENT(in) :: Vs, DR, VR, PR, DL, VL

    REAL(AR) :: WR, WL, tau

    WR = LorentzFactor( One, VR )
    WL = LorentzFactor( One, VL )

    tau = Gamma_IDEAL / ( Gamma_IDEAL - One )

    Pressure = ( PR * ( One + tau * WR**2 * VR * ( VR - Vs ) ) &
                 - DL * WL**2 * VL**2 + DR * WR**2 * VR**2 &
                 + Vs * ( DL * WL**2 * VL - DR * WR**2 * VR ) ) &
               / ( One + tau * WL**2 * VL * ( VL - Vs ) )

    RETURN
  END FUNCTION Pressure


  REAL(AR) FUNCTION PostShockVelocity( Vs, DR, VR, PR, DL, VL, PL )

    REAL(AR), INTENT(in) :: Vs, DR, VR, PR, DL, VL, PL

    REAL(AR) :: WR, WL, tau

    WR = LorentzFactor( One, VR )
    WL = LorentzFactor( One, VL )

    tau = Gamma_IDEAL / ( Gamma_IDEAL - One )

    PostShockVelocity &
      = ( DL + tau * PL ) * WL**2 * ( VL - Vs ) &
          - ( DR + tau * PR ) * WR**2 * ( VR - Vs ) + Vs * ( PL - PR )

    RETURN
  END FUNCTION PostShockVelocity


END MODULE MF_InitializationModule_Relativistic_IDEAL
