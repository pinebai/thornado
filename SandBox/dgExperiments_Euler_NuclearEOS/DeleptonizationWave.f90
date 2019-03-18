PROGRAM DeleptonizationWave

  USE KindModule, ONLY: &
    DP, SqrtTiny, Third
  USE ProgramHeaderModule, ONLY: &
    nZ, nNodesZ, &
    iX_B0, iX_E0, iX_B1, iX_E1, &
    iE_B0, iE_E0, iE_B1, iE_E1, &
    iZ_B0, iZ_E0, iZ_B1, iZ_E1
  USE UnitsModule, ONLY: &
    Kilometer, &
    Millisecond, &
    MeV
  USE ProgramInitializationModule, ONLY: &
    InitializeProgram, &
    FinalizeProgram
  USE ReferenceElementModuleX, ONLY: &
    InitializeReferenceElementX, &
    FinalizeReferenceElementX
  USE ReferenceElementModuleX_Lagrange, ONLY: &
    InitializeReferenceElementX_Lagrange, &
    FinalizeReferenceElementX_Lagrange
  USE ReferenceElementModuleE, ONLY: &
    InitializeReferenceElementE, &
    FinalizeReferenceElementE
  USE ReferenceElementModuleE_Lagrange, ONLY: &
    InitializeReferenceElementE_Lagrange, &
    FinalizeReferenceElementE_Lagrange
  USE ReferenceElementModule, ONLY: &
    InitializeReferenceElement, &
    FinalizeReferenceElement
  USE ReferenceElementModule_Lagrange, ONLY: &
    InitializeReferenceElement_Lagrange, &
    FinalizeReferenceElement_Lagrange
  USE GeometryFieldsModule, ONLY: &
    uGF
  USE GeometryComputationModule, ONLY: &
    ComputeGeometryX
  USE GeometryFieldsModuleE, ONLY: &
    uGE
  USE GeometryComputationModuleE, ONLY: &
    ComputeGeometryE
  USE FluidFieldsModule, ONLY: &
    uCF, &
    uPF, iPF_D, &
    uAF, iAF_T, iAF_Ye
  USE RadiationFieldsModule, ONLY: &
    uCR, rhsCR
  USE EquationOfStateModule_TABLE, ONLY: &
    InitializeEquationOfState_TABLE, &
    FinalizeEquationOfState_TABLE
  USE OpacityModule_TABLE, ONLY: &
    InitializeOpacities_TABLE, &
    FinalizeOpacities_TABLE
  USE NeutrinoOpacitiesModule, ONLY: &
    CreateNeutrinoOpacities, &
    DestroyNeutrinoOpacities
  USE NeutrinoOpacitiesComputationModule, ONLY: &
    ComputeNeutrinoOpacities
  USE TimeSteppingModule_Castro, ONLY: &
    Update_IMEX_PDARS
  USE InitializationModule, ONLY: &
    InitializeFields_DeleptonizationWave
  USE InputOutputModuleHDF, ONLY: &
    WriteFieldsHDF
  USE TwoMoment_ClosureModule, ONLY: &
    InitializeClosure_TwoMoment
  USE TwoMoment_PositivityLimiterModule, ONLY: &
    InitializePositivityLimiter_TwoMoment, &
    FinalizePositivityLimiter_TwoMoment, &
    ApplyPositivityLimiter_TwoMoment, &
    TallyPositivityLimiter_TwoMoment

  IMPLICIT NONE

  INCLUDE 'mpif.h'

  LOGICAL  :: wrt
  INTEGER  :: iCycle, iCycleD
  INTEGER  :: nE, nX(3), nNodes, nSpecies
  REAL(DP) :: t, dt, t_end, dt_wrt, t_wrt, wTime
  REAL(DP) :: eL, eR
  REAL(DP) :: xL(3), xR(3)

  nNodes   = 2
  nSpecies = 2

  nX = [ 32, 32, 1 ]
  xL = [ - 0.0d2, - 0.0d2, - 5.0d1 ] * Kilometer
  xR = [ + 1.0d2, + 1.0d2, + 5.0d1 ] * Kilometer

  nE = 16
  eL = 0.0d0 * MeV
  eR = 3.0d2 * MeV

  CALL InitializeProgram &
         ( ProgramName_Option &
             = 'DeleptonizationWave', &
           nX_Option &
             = nX, &
           swX_Option &
             = [ 01, 01, 00 ], &
           bcX_Option &
             = [ 32, 32, 00 ], &
           xL_Option &
             = xL, &
           xR_Option &
             = xR, &
           nE_Option &
             = nE, &
           eL_Option &
             = eL, &
           eR_Option &
             = eR, &
           ZoomE_Option &
             = 1.183081754893913_DP, &
           nNodes_Option &
             = nNodes, &
           CoordinateSystem_Option &
             = 'CARTESIAN', &
           ActivateUnits_Option &
             = .TRUE., &
           nSpecies_Option &
             = nSpecies, &
           BasicInitialization_Option &
             = .TRUE. )

  ! --- Position Space Reference Element and Geometry ---

  CALL InitializeReferenceElementX

  CALL InitializeReferenceElementX_Lagrange

  CALL ComputeGeometryX &
         ( iX_B0, iX_E0, iX_B1, iX_E1, uGF )

  ! --- Energy Space Reference Element and Geometry ---

  CALL InitializeReferenceElementE

  CALL InitializeReferenceElementE_Lagrange

  CALL ComputeGeometryE &
         ( iE_B0, iE_E0, iE_B1, iE_E1, uGE )

  ! --- Phase Space Reference Element ---

  CALL InitializeReferenceElement

  CALL InitializeReferenceElement_Lagrange

  ! --- Initialize Moment Closure ---

  CALL InitializeClosure_TwoMoment

  ! --- Initialize Equation of State ---

  CALL InitializeEquationOfState_TABLE &
         ( EquationOfStateTableName_Option = 'EquationOfStateTable.h5' )

  ! --- Initialize Opacities ---

  CALL InitializeOpacities_TABLE &
         ( OpacityTableName_EmAb_Option &
             = 'wl-Op-SFHo-15-25-50-E40-B85-AbEm.h5', &
           OpacityTableName_Iso_Option  &
             = 'wl-Op-SFHo-15-25-50-E40-B85-Iso.h5', &
           Verbose_Option = .TRUE. )

  ! --- Create Neutrino Opacities ---

  CALL CreateNeutrinoOpacities( nZ, nNodesZ, nSpecies )

  ! --- Initialize Positivity Limiter ---

  CALL InitializePositivityLimiter_TwoMoment &
         ( Min_1_Option = 0.0d0 + SqrtTiny, &
           Max_1_Option = 1.0d0 - SqrtTiny, &
           Min_2_Option = 0.0d0 + SqrtTiny, &
           UsePositivityLimiter_Option &
             = .TRUE., &
           UsePositivityLimiterTally_Option &
             = .TRUE. )

  ! --- Set Initial Condition ---

  CALL InitializeFields_DeleptonizationWave

  ! --- Write Initial Condition Before Limiter ---

  CALL WriteFieldsHDF &
         ( Time = 0.0_DP, &
           WriteGF_Option = .TRUE., &
           WriteFF_Option = .TRUE., &
           WriteRF_Option = .TRUE., &
           WriteOP_Option = .TRUE. )

  CALL ApplyPositivityLimiter_TwoMoment &
         ( iZ_B0, iZ_E0, iZ_B1, iZ_E1, uGE, uGF, uCR )

  CALL TallyPositivityLimiter_TwoMoment( 0.0_DP )

  CALL ComputeNeutrinoOpacities &
         ( iZ_B0, iZ_E0, iZ_B1, iZ_E1, &
           uPF(:,:,:,:,iPF_D), &
           uAF(:,:,:,:,iAF_T), &
           uAF(:,:,:,:,iAF_Ye) )

  ! --- Write Initial Condition After Limiter ---

  CALL WriteFieldsHDF &
         ( Time = 0.0_DP, &
           WriteGF_Option = .TRUE., &
           WriteFF_Option = .TRUE., &
           WriteRF_Option = .TRUE., &
           WriteOP_Option = .TRUE. )

  ! --- Evolve ---

  wTime = MPI_WTIME( )

  t       = 0.0_DP
  t_end   = 1.0d-0 * Millisecond
  dt_wrt  = 1.0d-1 * Millisecond
  t_wrt   = dt_wrt
  wrt     = .FALSE.
  iCycleD = 1

  WRITE(*,*)
  WRITE(*,'(A6,A,ES8.2E2,A8,ES8.2E2)') &
    '', 'Evolving from t = ', t / Millisecond, &
    ' to t = ', t_end / Millisecond
  WRITE(*,*)

  iCycle = 0
  DO WHILE( t < t_end )

    iCycle = iCycle + 1

    dt = Third * MINVAL( (xR-xL) / DBLE( nX ) ) &
           / ( 2.0_DP * DBLE( nNodes - 1 ) + 1.0_DP )

    IF( t + dt > t_end )THEN

      dt = t_end - t

    END IF

    IF( t + dt > t_wrt )THEN

      dt    = t_wrt - t
      t_wrt = t_wrt + dt_wrt
      wrt   = .TRUE.

    END IF

    IF( MOD( iCycle, iCycleD ) == 0 )THEN

      WRITE(*,'(A8,A8,I8.8,A2,A4,ES12.6E2,A1,A5,ES12.6E2)') &
          '', 'Cycle = ', iCycle, &
          '', 't = ',  t / Millisecond, &
          '', 'dt = ', dt / Millisecond

    END IF

    CALL Update_IMEX_PDARS &
           ( dt, uCF, uCR, &
             Explicit_Option = .TRUE., &
             Implicit_Option = .TRUE., &
             SingleStage_Option = .FALSE., &
             CallFromThornado_Option = .TRUE. )

    t = t + dt

    CALL TallyPositivityLimiter_TwoMoment( t )

    IF( wrt )THEN

      CALL WriteFieldsHDF &
             ( Time = t, &
               WriteGF_Option = .TRUE., &
               WriteFF_Option = .TRUE., &
               WriteRF_Option = .TRUE., &
               WriteOP_Option = .TRUE. )

      wrt = .FALSE.

    END IF

  END DO

  ! --- Write Final Solution ---

  CALL WriteFieldsHDF &
         ( Time = t, &
           WriteGF_Option = .TRUE., &
           WriteFF_Option = .TRUE., &
           WriteRF_Option = .TRUE., &
           WriteOP_Option = .TRUE. )

  wTime = MPI_WTIME( ) - wTime

  WRITE(*,*)
  WRITE(*,'(A6,A,I6.6,A,ES12.6E2,A)') &
    '', 'Finished ', iCycle, ' Cycles in ', wTime, ' s'
  WRITE(*,*)

  ! --- Finalize ---

  CALL FinalizeReferenceElementX

  CALL FinalizeReferenceElementX_Lagrange

  CALL FinalizeReferenceElementE

  CALL FinalizeReferenceElementE_Lagrange

  CALL FinalizeReferenceElement

  CALL FinalizeReferenceElement_Lagrange

  CALL FinalizeEquationOfState_TABLE

  CALL FinalizeOpacities_TABLE

  CALL DestroyNeutrinoOpacities

  CALL FinalizePositivityLimiter_TwoMoment

  CALL FinalizeProgram

END PROGRAM DeleptonizationWave