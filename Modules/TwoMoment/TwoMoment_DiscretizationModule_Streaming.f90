MODULE TwoMoment_DiscretizationModule_Streaming

  USE KindModule, ONLY: &
    DP, Zero, Half, One, &
    TwoPi, SqrtTiny
  USE ProgramHeaderModule, ONLY: &
    nNodesX, nDOFX, &
    nNodesE, nDOFE, &
    nDOF
  USE ReferenceElementModuleX, ONLY: &
    nDOFX_X1, &
    nDOFX_X2, &
    nDOFX_X3
  USE ReferenceElementModuleX_Lagrange, ONLY: &
    LX_X1_Dn, &
    LX_X1_Up, &
    LX_X2_Dn, &
    LX_X2_Up, &
    LX_X3_Dn, &
    LX_X3_Up
  USE ReferenceElementModule, ONLY: &
    nDOF_X1, &
    nDOF_X2, &
    nDOF_X3, &
    Weights_q, &
    Weights_X1, &
    Weights_X2, &
    Weights_X3, &
    NodeNumberTable, &
    OuterProduct1D3D
  USE ReferenceElementModule_Lagrange, ONLY: &
    dLdX1_q, &
    dLdX2_q, &
    dLdX3_q, &
    L_X1_Dn, &
    L_X1_Up, &
    L_X2_Dn, &
    L_X2_Up, &
    L_X3_Dn, &
    L_X3_Up
  USE MeshModule, ONLY: &
    MeshX, &
    MeshE, &
    NodeCoordinate
  USE GeometryFieldsModule, ONLY: &
    nGF, &
    iGF_h_1, &
    iGF_h_2, &
    iGF_h_3, &
    iGF_Gm_dd_11, &
    iGF_Gm_dd_22, &
    iGF_Gm_dd_33, &
    iGF_SqrtGm, &
    iGF_Alpha
  USE GeometryComputationModule, ONLY: &
    ComputeGeometryX_FromScaleFactors
  USE GeometryFieldsModuleE, ONLY: &
    nGE, &
    iGE_Ep0, &
    iGE_Ep2
  USE RadiationFieldsModule, ONLY: &
    nSpecies, &
    nCR, iCR_N, iCR_G1, iCR_G2, iCR_G3, &
    nPR, iPR_D, iPR_I1, iPR_I2, iPR_I3
  USE TwoMoment_ClosureModule, ONLY: &
    FluxFactor, &
    EddingtonFactor
  USE TwoMoment_BoundaryConditionsModule, ONLY: &
    ApplyBoundaryConditions_TwoMoment
  USE TwoMoment_UtilitiesModule, ONLY: &
    ComputePrimitive_TwoMoment, &
    Flux_X1, &
    Flux_X2, &
    Flux_X3, &
    NumericalFlux_LLF

  !$ USE OMP_LIB

  IMPLICIT NONE
  PRIVATE

  REAL(DP), PARAMETER :: Ones(16) = One
  REAL(DP) :: wTime_X1 = Zero
  !$OMP THREADPRIVATE(wTime_X1)

  PUBLIC :: ComputeIncrement_TwoMoment_Explicit

CONTAINS


  SUBROUTINE ComputeIncrement_TwoMoment_Explicit &
    ( iZ_B0, iZ_E0, iZ_B1, iZ_E1, GE, GX, U, dU )

    ! --- {Z1,Z2,Z3,Z4} = {E,X1,X2,X3} ---

    INTEGER,  INTENT(in)    :: &
      iZ_B0(4), iZ_E0(4), iZ_B1(4), iZ_E1(4)
    REAL(DP), INTENT(in)    :: &
      GE(1:,iZ_B1(1):,1:)
    REAL(DP), INTENT(in)    :: &
      GX(1:,iZ_B1(2):,iZ_B1(3):,iZ_B1(4):,1:)
    REAL(DP), INTENT(inout) :: &
      U (1:,iZ_B1(1):,iZ_B1(2):,iZ_B1(3):,iZ_B1(4):,1:,1:)
    REAL(DP), INTENT(inout) :: &
      dU(1:,iZ_B0(1):,iZ_B0(2):,iZ_B0(3):,iZ_B0(4):,1:,1:)

    INTEGER  :: iZ1, iZ2, iZ3, iZ4, iCR, iS
    REAL(DP) :: dZ(4), Tau(nDOF)

    dU = Zero

    CALL ApplyBoundaryConditions_TwoMoment &
           ( iZ_B0, iZ_E0, iZ_B1, iZ_E1, U )

    CALL ComputeIncrement_Divergence_X1_GPU &
           ( iZ_B0, iZ_E0, iZ_B1, iZ_E1, GE, GX, U, dU )

    CALL ComputeIncrement_Divergence_X2 &
           ( iZ_B0, iZ_E0, iZ_B1, iZ_E1, GE, GX, U, dU )

    CALL ComputeIncrement_Divergence_X3 &
           ( iZ_B0, iZ_E0, iZ_B1, iZ_E1, GE, GX, U, dU )

    ! --- Multiply Inverse Mass Matrix ---

    DO iZ4 = iZ_B0(4), iZ_E0(4)
      dZ(4) = MeshX(3) % Width(iZ4)
      DO iZ3 = iZ_B0(3), iZ_E0(3)
        dZ(3) = MeshX(2) % Width(iZ3)
        DO iZ2 = iZ_B0(2), iZ_E0(2)
          dZ(2) = MeshX(1) % Width(iZ2)
          DO iZ1 = iZ_B0(1), iZ_E0(1)
            dZ(1) = MeshE % Width(iZ1)

            Tau(1:nDOF) &
              = OuterProduct1D3D &
                  ( Ones(1:nDOFE), nDOFE, &
                    GX(:,iZ2,iZ3,iZ4,iGF_SqrtGm), nDOFX )

            DO iS = 1, nSpecies
              DO iCR = 1, nCR

                dU(:,iZ1,iZ2,iZ3,iZ4,iCR,iS) &
                  = dU(:,iZ1,iZ2,iZ3,iZ4,iCR,iS) &
                      / ( Weights_q(:) * Tau(:) * PRODUCT( dZ(2:4) ) )

              END DO
            END DO

          END DO
        END DO
      END DO
    END DO

  END SUBROUTINE ComputeIncrement_TwoMoment_Explicit


  SUBROUTINE ComputeIncrement_Divergence_X1_GPU &
    ( iZ_B0, iZ_E0, iZ_B1, iZ_E1, GE, GX, U, dU )

    ! --- {Z1,Z2,Z3,Z4} = {E,X1,X2,X3} ---

    INTEGER,  INTENT(in)    :: &
      iZ_B0(4), iZ_E0(4), iZ_B1(4), iZ_E1(4)
    REAL(DP), INTENT(in)    :: &
      GE(1:,iZ_B1(1):,1:)
    REAL(DP), INTENT(in)    :: &
      GX(1:,iZ_B1(2):,iZ_B1(3):,iZ_B1(4):,1:)
    REAL(DP), INTENT(in)    :: &
      U (1:,iZ_B1(1):,iZ_B1(2):,iZ_B1(3):,iZ_B1(4):,1:,1:)
    REAL(DP), INTENT(inout) :: &
      dU(1:,iZ_B0(1):,iZ_B0(2):,iZ_B0(3):,iZ_B0(4):,1:,1:)

    INTEGER  :: nZ(4), nK, nF, nF_GF
    INTEGER  :: iZ1, iZ2, iZ3, iZ4, iS
    INTEGER  :: iNode
    INTEGER  :: iGF, iCR
    REAL(DP) :: dZ1, dZ2, dZ3, dZ4
    REAL(DP) :: FF, EF
    REAL(DP), DIMENSION(nDOF_X1)     :: absLambda_L
    REAL(DP), DIMENSION(nDOF_X1)     :: absLambda_R
    REAL(DP), DIMENSION(nDOF_X1)     :: alpha
    REAL(DP), DIMENSION(nDOF)        :: Tau
    REAL(DP), DIMENSION(nDOF_X1)     :: Tau_X1
    REAL(DP), DIMENSION(nDOF_X1,nPR) :: uPR_L, uPR_R
    REAL(DP), DIMENSION(nDOF_X1,nCR) :: Flux_X1_L
    REAL(DP), DIMENSION(nDOF_X1,nCR) :: Flux_X1_R
    REAL(DP), DIMENSION(nDOF   ,nPR) :: uPR_K

    REAL(DP) :: GX_K         (nDOFX       ,iZ_B0(3):iZ_E0(3),iZ_B0(4):iZ_E0(4),iZ_B0(2)-1:iZ_E0(2)+1,nGF)
    REAL(DP) :: GX_F         (nDOFX_X1    ,iZ_B0(3):iZ_E0(3),iZ_B0(4):iZ_E0(4),iZ_B0(2)  :iZ_E0(2)+1,nGF)
    REAL(DP) :: G_K          (nDOF    ,nGF,iZ_B0(3):iZ_E0(3),iZ_B0(4):iZ_E0(4),iZ_B0(2)  :iZ_E0(2)+1)
    REAL(DP) :: G_F          (nDOF_X1 ,nGF,iZ_B0(3):iZ_E0(3),iZ_B0(4):iZ_E0(4),iZ_B0(2)  :iZ_E0(2)+1)

    REAL(DP) :: uCR_K        (nDOF    ,iZ_B0(1):iZ_E0(1),iZ_B0(3):iZ_E0(3),iZ_B0(4):iZ_E0(4),nCR,nSpecies,iZ_B0(2)-1:iZ_E0(2)+1)
    REAL(DP) :: uCR_L        (nDOF_X1 ,iZ_B0(1):iZ_E0(1),iZ_B0(3):iZ_E0(3),iZ_B0(4):iZ_E0(4),nCR,nSpecies,iZ_B0(2)  :iZ_E0(2)+1)
    REAL(DP) :: uCR_R        (nDOF_X1 ,iZ_B0(1):iZ_E0(1),iZ_B0(3):iZ_E0(3),iZ_B0(4):iZ_E0(4),nCR,nSpecies,iZ_B0(2)  :iZ_E0(2)+1)

    REAL(DP) :: dU_K         (nDOF    ,iZ_B0(1):iZ_E0(1),iZ_B0(3):iZ_E0(3),iZ_B0(4):iZ_E0(4),nCR,nSpecies,iZ_B0(2)  :iZ_E0(2)  )
    REAL(DP) :: Flux_X1_q    (nDOF    ,iZ_B0(1):iZ_E0(1),iZ_B0(3):iZ_E0(3),iZ_B0(4):iZ_E0(4),nCR,nSpecies,iZ_B0(2)  :iZ_E0(2)  )
    REAL(DP) :: NumericalFlux(nDOF_X1 ,iZ_B0(1):iZ_E0(1),iZ_B0(3):iZ_E0(3),iZ_B0(4):iZ_E0(4),nCR,nSpecies,iZ_B0(2)  :iZ_E0(2)+1)

    REAL(DP) :: wTime

    IF( iZ_E0(2) .EQ. iZ_B0(2) ) RETURN

    wTime_X1 = wTime_X1 - omp_get_wtime()

    nZ = iZ_E0 - iZ_B0 + 1
    nK = nSpecies * nCR * PRODUCT( nZ )
    nF = nSpecies * nCR * PRODUCT( nZ + [0,1,0,0] )
    nF_GF = nZ(4) * nZ(3) * ( nZ(2) + 1 )

    !---------------------
    ! --- Surface Term ---
    !---------------------

    ! --- Geometry Fields in Element Nodes ---

    DO iGF = 1, nGF
      DO iZ2 = iZ_B0(2) - 1, iZ_E0(2) + 1
        DO iZ4 = iZ_B0(4), iZ_E0(4)
          DO iZ3 = iZ_B0(3), iZ_E0(3)
            GX_K(:,iZ3,iZ4,iZ2,iGF) = GX(:,iZ2,iZ3,iZ4,iGF)
          END DO
        END DO
      END DO
    END DO

    ! --- Interpolate Geometry Fields on Shared Face ---

    ! --- Face States (Average of Left and Right States) ---

    ! --- Scale Factors ---

    DO iGF = iGF_h_1, iGF_h_3

      CALL DGEMM &
             ( 'N', 'N', nDOFX_X1, nF_GF, nDOFX, One,  LX_X1_Up, nDOFX_X1, &
               GX_K(1,iZ_B0(3),iZ_B0(4),iZ_B0(2)-1,iGF), nDOFX, Zero, &
               GX_F(1,iZ_B0(3),iZ_B0(4),iZ_B0(2)  ,iGF), nDOFX_X1 )
      CALL DGEMM &
             ( 'N', 'N', nDOFX_X1, nF_GF, nDOFX, Half, LX_X1_Dn, nDOFX_X1, &
               GX_K(1,iZ_B0(3),iZ_B0(4),iZ_B0(2)  ,iGF), nDOFX, Half, &
               GX_F(1,iZ_B0(3),iZ_B0(4),iZ_B0(2)  ,iGF), nDOFX_X1 )

      GX_F(:,:,:,:,iGF) = MAX( GX_F(:,:,:,:,iGF), SqrtTiny )

    END DO

    ! --- Lapse Function ---

    CALL DGEMM &
           ( 'N', 'N', nDOFX_X1, nF_GF, nDOFX, One,  LX_X1_Up, nDOFX_X1, &
             GX_K(1,iZ_B0(3),iZ_B0(4),iZ_B0(2)-1,iGF_Alpha), nDOFX, Zero, &
             GX_F(1,iZ_B0(3),iZ_B0(4),iZ_B0(2)  ,iGF_Alpha), nDOFX_X1 )
    CALL DGEMM &
           ( 'N', 'N', nDOFX_X1, nF_GF, nDOFX, Half, LX_X1_Dn, nDOFX_X1, &
             GX_K(1,iZ_B0(3),iZ_B0(4),iZ_B0(2)  ,iGF_Alpha), nDOFX, Half, &
             GX_F(1,iZ_B0(3),iZ_B0(4),iZ_B0(2)  ,iGF_Alpha), nDOFX_X1 )

    GX_F(:,:,:,:,iGF_Alpha) = MAX( GX_F(:,:,:,:,iGF_Alpha), SqrtTiny )

    DO iZ2 = iZ_B0(2), iZ_E0(2) + 1
      DO iZ4 = iZ_B0(4), iZ_E0(4)
        DO iZ3 = iZ_B0(3), iZ_E0(3)

          DO iGF = iGF_h_1, iGF_h_3

            G_F(1:nDOF_X1,iGF,iZ3,iZ4,iZ2) &
              = OuterProduct1D3D &
                  ( Ones(1:nDOFE), nDOFE, GX_F(1:nDOFX_X1,iZ3,iZ4,iZ2,iGF), nDOFX_X1 )

          END DO

          CALL ComputeGeometryX_FromScaleFactors( G_F(:,:,iZ3,iZ4,iZ2) )

          G_F(1:nDOF_X1,iGF_Alpha,iZ3,iZ4,iZ2) &
            = OuterProduct1D3D &
                ( Ones(1:nDOFE), nDOFE, &
                  GX_F(1:nDOFX_X1,iZ3,iZ4,iZ2,iGF_Alpha), nDOFX_X1 )

        END DO
      END DO
    END DO

    ! --- Interpolate Radiation Fields ---

    DO iZ2 = iZ_B0(2) - 1, iZ_E0(2) + 1
      DO iS = 1, nSpecies
        DO iCR = 1, nCR
          DO iZ4 = iZ_B0(4), iZ_E0(4)
            DO iZ3 = iZ_B0(3), iZ_E0(3)
              DO iZ1 = iZ_B0(1), iZ_E0(1)
                uCR_K(:,iZ1,iZ3,iZ4,iCR,iS,iZ2) = U(:,iZ1,iZ2,iZ3,iZ4,iCR,iS)
              END DO
            END DO
          END DO
        END DO
      END DO
    END DO

    ! --- Interpolate Left State ---

    CALL DGEMM &
           ( 'N', 'N', nDOF_X1, nF, nDOF, One, L_X1_Up, nDOF_X1, &
             uCR_K(1,iZ_B0(1),iZ_B0(3),iZ_B0(4),1,1,iZ_B0(2)-1), nDOF, Zero, uCR_L, nDOF_X1 )

    ! --- Interpolate Right State ---

    CALL DGEMM &
           ( 'N', 'N', nDOF_X1, nF, nDOF, One, L_X1_Dn, nDOF_X1, &
             uCR_K(1,iZ_B0(1),iZ_B0(3),iZ_B0(4),1,1,iZ_B0(2)  ), nDOF, Zero, uCR_R, nDOF_X1 )

    DO iZ2 = iZ_B0(2), iZ_E0(2) + 1
      DO iS = 1, nSpecies
        DO iZ4 = iZ_B0(4), iZ_E0(4)
          DO iZ3 = iZ_B0(3), iZ_E0(3)
            DO iZ1 = iZ_B0(1), iZ_E0(1)

              dZ3 = MeshX(2) % Width(iZ3)
              dZ4 = MeshX(3) % Width(iZ4)

              ! --- Left State Primitive, etc. ---

              CALL ComputePrimitive_TwoMoment &
                     ( uCR_L(:,iZ1,iZ3,iZ4,iCR_N ,iS,iZ2), &
                       uCR_L(:,iZ1,iZ3,iZ4,iCR_G1,iS,iZ2), &
                       uCR_L(:,iZ1,iZ3,iZ4,iCR_G2,iS,iZ2), &
                       uCR_L(:,iZ1,iZ3,iZ4,iCR_G3,iS,iZ2), &
                       uPR_L(:,iPR_D ), uPR_L(:,iPR_I1), &
                       uPR_L(:,iPR_I2), uPR_L(:,iPR_I3), &
                       G_F(:,iGF_Gm_dd_11,iZ3,iZ4,iZ2), &
                       G_F(:,iGF_Gm_dd_22,iZ3,iZ4,iZ2), &
                       G_F(:,iGF_Gm_dd_33,iZ3,iZ4,iZ2) )

              DO iNode = 1, nDOF_X1

                FF = FluxFactor &
                       ( uPR_L(iNode,iPR_D ), uPR_L(iNode,iPR_I1), &
                         uPR_L(iNode,iPR_I2), uPR_L(iNode,iPR_I3), &
                         G_F(iNode,iGF_Gm_dd_11,iZ3,iZ4,iZ2), &
                         G_F(iNode,iGF_Gm_dd_22,iZ3,iZ4,iZ2), &
                         G_F(iNode,iGF_Gm_dd_33,iZ3,iZ4,iZ2) )

                EF = EddingtonFactor( uPR_L(iNode,iPR_D), FF )

                Flux_X1_L(iNode,1:nCR) &
                  = Flux_X1 &
                      ( uPR_L(iNode,iPR_D ), uPR_L(iNode,iPR_I1), &
                        uPR_L(iNode,iPR_I2), uPR_L(iNode,iPR_I3), &
                        FF, EF, &
                        G_F(iNode,iGF_Gm_dd_11,iZ3,iZ4,iZ2), &
                        G_F(iNode,iGF_Gm_dd_22,iZ3,iZ4,iZ2), &
                        G_F(iNode,iGF_Gm_dd_33,iZ3,iZ4,iZ2) )

                absLambda_L(iNode) = 1.0_DP

              END DO

              ! --- Right State Primitive, etc. ---

              CALL ComputePrimitive_TwoMoment &
                     ( uCR_R(:,iZ1,iZ3,iZ4,iCR_N ,iS,iZ2), &
                       uCR_R(:,iZ1,iZ3,iZ4,iCR_G1,iS,iZ2), &
                       uCR_R(:,iZ1,iZ3,iZ4,iCR_G2,iS,iZ2), &
                       uCR_R(:,iZ1,iZ3,iZ4,iCR_G3,iS,iZ2), &
                       uPR_R(:,iPR_D ), uPR_R(:,iPR_I1), &
                       uPR_R(:,iPR_I2), uPR_R(:,iPR_I3), &
                       G_F(:,iGF_Gm_dd_11,iZ3,iZ4,iZ2), &
                       G_F(:,iGF_Gm_dd_22,iZ3,iZ4,iZ2), &
                       G_F(:,iGF_Gm_dd_33,iZ3,iZ4,iZ2) )

              DO iNode = 1, nDOF_X1

                FF = FluxFactor &
                       ( uPR_R(iNode,iPR_D ), uPR_R(iNode,iPR_I1), &
                         uPR_R(iNode,iPR_I2), uPR_R(iNode,iPR_I3), &
                         G_F(iNode,iGF_Gm_dd_11,iZ3,iZ4,iZ2), &
                         G_F(iNode,iGF_Gm_dd_22,iZ3,iZ4,iZ2), &
                         G_F(iNode,iGF_Gm_dd_33,iZ3,iZ4,iZ2) )

                EF = EddingtonFactor( uPR_R(iNode,iPR_D), FF )

                Flux_X1_R(iNode,1:nCR) &
                  = Flux_X1 &
                      ( uPR_R(iNode,iPR_D ), uPR_R(iNode,iPR_I1), &
                        uPR_R(iNode,iPR_I2), uPR_R(iNode,iPR_I3), &
                        FF, EF, &
                        G_F(iNode,iGF_Gm_dd_11,iZ3,iZ4,iZ2), &
                        G_F(iNode,iGF_Gm_dd_22,iZ3,iZ4,iZ2), &
                        G_F(iNode,iGF_Gm_dd_33,iZ3,iZ4,iZ2) )

                absLambda_R(iNode) = 1.0_DP

              END DO

              ! --- Volume Jacobian in Energy-Position Element ---

              Tau_X1(1:nDOF_X1) &
                = OuterProduct1D3D &
                    ( Ones(1:nDOFE), nDOFE, G_F(:,iGF_SqrtGm,iZ3,iZ4,iZ2), nDOFX_X1 )

              ! --- Numerical Flux ---

              alpha = MAX( absLambda_L, absLambda_R )

              DO iCR = 1, nCR

                NumericalFlux(:,iZ1,iZ3,iZ4,iCR,iS,iZ2) &
                  = NumericalFlux_LLF &
                      ( uCR_L    (:,iZ1,iZ3,iZ4,iCR,iS,iZ2), &
                        uCR_R    (:,iZ1,iZ3,iZ4,iCR,iS,iZ2), &
                        Flux_X1_L(:,iCR), &
                        Flux_X1_R(:,iCR), alpha(:) )

                NumericalFlux(:,iZ1,iZ3,iZ4,iCR,iS,iZ2) &
                  = dZ3 * dZ4 * Weights_X1(:) * Tau_X1(:) &
                      * G_F(:,iGF_Alpha,iZ3,iZ4,iZ2) &
                      * NumericalFlux(:,iZ1,iZ3,iZ4,iCR,iS,iZ2)

              END DO

            END DO
          END DO
        END DO
      END DO
    END DO

    ! --- Contribution from Left Face ---

    CALL DGEMM &
           ( 'T', 'N', nDOF, nK, nDOF_X1, + One, L_X1_Dn, nDOF_X1, &
             NumericalFlux(1,iZ_B0(1),iZ_B0(3),iZ_B0(4),1,1,iZ_B0(2)  ), nDOF_X1, Zero, dU_K, nDOF )

    ! --- Contribution from Right Face ---

    CALL DGEMM &
           ( 'T', 'N', nDOF, nK, nDOF_X1, - One, L_X1_Up, nDOF_X1, &
             NumericalFlux(1,iZ_B0(1),iZ_B0(3),iZ_B0(4),1,1,iZ_B0(2)+1), nDOF_X1, One,  dU_K, nDOF )

    !---------------------
    ! --- Volume Term ---
    !---------------------

    DO iZ2 = iZ_B0(2), iZ_E0(2)
      DO iZ4 = iZ_B0(4), iZ_E0(4)
        DO iZ3 = iZ_B0(3), iZ_E0(3)
          DO iGF = 1, nGF

            G_K(1:nDOF,iGF,iZ3,iZ4,iZ2) &
              = OuterProduct1D3D &
                  ( Ones(1:nDOFE), nDOFE, GX_K(1:nDOFX,iZ3,iZ4,iZ2,iGF), nDOFX )

          END DO
        END DO
      END DO
    END DO

    DO iZ2 = iZ_B0(2), iZ_E0(2)
      DO iS = 1, nSpecies
        DO iZ4 = iZ_B0(4), iZ_E0(4)
          DO iZ3 = iZ_B0(3), iZ_E0(3)
            DO iZ1 = iZ_B0(1), iZ_E0(1)

              dZ3 = MeshX(2) % Width(iZ3)
              dZ4 = MeshX(3) % Width(iZ4)

              CALL ComputePrimitive_TwoMoment &
                     ( uCR_K(:,iZ1,iZ3,iZ4,iCR_N ,iS,iZ2), &
                       uCR_K(:,iZ1,iZ3,iZ4,iCR_G1,iS,iZ2), &
                       uCR_K(:,iZ1,iZ3,iZ4,iCR_G2,iS,iZ2), &
                       uCR_K(:,iZ1,iZ3,iZ4,iCR_G3,iS,iZ2), &
                       uPR_K(:,iPR_D ), uPR_K(:,iPR_I1), &
                       uPR_K(:,iPR_I2), uPR_K(:,iPR_I3), &
                       G_K(:,iGF_Gm_dd_11,iZ3,iZ4,iZ2), &
                       G_K(:,iGF_Gm_dd_22,iZ3,iZ4,iZ2), &
                       G_K(:,iGF_Gm_dd_33,iZ3,iZ4,iZ2) )

              DO iNode = 1, nDOF

                FF = FluxFactor &
                       ( uPR_K(iNode,iPR_D ), uPR_K(iNode,iPR_I1), &
                         uPR_K(iNode,iPR_I2), uPR_K(iNode,iPR_I3), &
                         G_K(iNode,iGF_Gm_dd_11,iZ3,iZ4,iZ2), &
                         G_K(iNode,iGF_Gm_dd_22,iZ3,iZ4,iZ2), &
                         G_K(iNode,iGF_Gm_dd_33,iZ3,iZ4,iZ2) )

                EF = EddingtonFactor( uPR_K(iNode,iPR_D), FF )

                Flux_X1_q(iNode,iZ1,iZ3,iZ4,1:nCR,iS,iZ2) &
                  = Flux_X1 &
                      ( uPR_K(iNode,iPR_D ), uPR_K(iNode,iPR_I1), &
                        uPR_K(iNode,iPR_I2), uPR_K(iNode,iPR_I3), &
                        FF, EF, &
                        G_K(iNode,iGF_Gm_dd_11,iZ3,iZ4,iZ2), &
                        G_K(iNode,iGF_Gm_dd_22,iZ3,iZ4,iZ2), &
                        G_K(iNode,iGF_Gm_dd_33,iZ3,iZ4,iZ2) )

              END DO

              ! --- Volume Jacobian in Energy-Position Element ---

              Tau(1:nDOF) &
                = OuterProduct1D3D &
                    ( Ones(1:nDOFE), nDOFE, G_K(:,iGF_SqrtGm,iZ3,iZ4,iZ2), nDOFX )

              DO iCR = 1, nCR

                Flux_X1_q(:,iZ1,iZ3,iZ4,iCR,iS,iZ2) &
                  = dZ3 * dZ4 * Weights_q(:) * Tau(:) &
                      * G_K(:,iGF_Alpha,iZ3,iZ4,iZ2) &
                      * Flux_X1_q(:,iZ1,iZ3,iZ4,iCR,iS,iZ2)

              END DO

            END DO
          END DO
        END DO
      END DO
    END DO

    ! --- Contribution from Volume ---

    CALL DGEMM &
           ( 'T', 'N', nDOF, nK, nDOF, One, dLdX1_q, nDOF, &
             Flux_X1_q, nDOF, One, dU_K, nDOF )

    DO iS = 1, nSpecies
      DO iCR = 1, nCR
        DO iZ4 = iZ_B0(4), iZ_E0(4)
          DO iZ3 = iZ_B0(3), iZ_E0(3)
            DO iZ2 = iZ_B0(2), iZ_E0(2)
              DO iZ1 = iZ_B0(1), iZ_E0(1)

                dU(:,iZ1,iZ2,iZ3,iZ4,iCR,iS) &
                  =   dU  (:,iZ1,iZ2  ,iZ3,iZ4,iCR,iS) &
                    + dU_K(:,iZ1,iZ3,iZ4,iCR,iS,iZ2)

              END DO
            END DO
          END DO
        END DO
      END DO
    END DO

    wTime_X1 = wTime_X1 + omp_get_wtime()

    WRITE(*,'(A,ES12.6E2,A)') &
      '[ComputeIncrement_Divergence_X1] wTime_X1 = ', wTime_X1

  END SUBROUTINE ComputeIncrement_Divergence_X1_GPU


  SUBROUTINE ComputeIncrement_Divergence_X1 &
    ( iZ_B0, iZ_E0, iZ_B1, iZ_E1, GE, GX, U, dU )

    ! --- {Z1,Z2,Z3,Z4} = {E,X1,X2,X3} ---

    INTEGER,  INTENT(in)    :: &
      iZ_B0(4), iZ_E0(4), iZ_B1(4), iZ_E1(4)
    REAL(DP), INTENT(in)    :: &
      GE(1:,iZ_B1(1):,1:)
    REAL(DP), INTENT(in)    :: &
      GX(1:,iZ_B1(2):,iZ_B1(3):,iZ_B1(4):,1:)
    REAL(DP), INTENT(in)    :: &
      U (1:,iZ_B1(1):,iZ_B1(2):,iZ_B1(3):,iZ_B1(4):,1:,1:)
    REAL(DP), INTENT(inout) :: &
      dU(1:,iZ_B0(1):,iZ_B0(2):,iZ_B0(3):,iZ_B0(4):,1:,1:)

    INTEGER  :: iZ1, iZ2, iZ3, iZ4, iS
    INTEGER  :: iNode
    INTEGER  :: iGF, iCR
    REAL(DP) :: dZ(4)
    REAL(DP) :: FF, EF
    REAL(DP) :: GX_P(nDOFX,   nGF)
    REAL(DP) :: GX_K(nDOFX,   nGF)
    REAL(DP) :: GX_F(nDOFX_X1,nGF)
    REAL(DP) :: G_K(nDOF,nGF)
    REAL(DP) :: G_F(nDOF_X1,nGF)
    REAL(DP), DIMENSION(nDOF_X1)     :: absLambda_L
    REAL(DP), DIMENSION(nDOF_X1)     :: absLambda_R
    REAL(DP), DIMENSION(nDOF_X1)     :: alpha
    REAL(DP), DIMENSION(nDOF)        :: Tau
    REAL(DP), DIMENSION(nDOF_X1)     :: Tau_X1
    REAL(DP), DIMENSION(nDOF_X1,nCR) :: uCR_L, uCR_R
    REAL(DP), DIMENSION(nDOF_X1,nPR) :: uPR_L, uPR_R
    REAL(DP), DIMENSION(nDOF_X1,nCR) :: Flux_X1_L
    REAL(DP), DIMENSION(nDOF_X1,nCR) :: Flux_X1_R
    REAL(DP), DIMENSION(nDOF_X1,nCR) :: NumericalFlux
    REAL(DP), DIMENSION(nDOF   ,nCR) :: uCR_P, uCR_K
    REAL(DP), DIMENSION(nDOF   ,nPR) :: uPR_K
    REAL(DP), DIMENSION(nDOF   ,nCR) :: Flux_X1_q

    IF( iZ_E0(2) .EQ. iZ_B0(2) ) RETURN

    DO iS = 1, nSpecies
      DO iZ4 = iZ_B0(4), iZ_E0(4)

        dZ(4) = MeshX(3) % Width(iZ4)

        DO iZ3 = iZ_B0(3), iZ_E0(3)

          dZ(3) = MeshX(2) % Width(iZ3)

          DO iZ2 = iZ_B0(2), iZ_E0(2) + 1

            ! --- Geometry Fields in Element Nodes ---

            DO iGF = 1, nGF

              GX_P(:,iGF) = GX(:,iZ2-1,iZ3,iZ4,iGF) ! --- Previous Element
              GX_K(:,iGF) = GX(:,iZ2,  iZ3,iZ4,iGF) ! --- This     Element

              G_K(1:nDOF,iGF) &
                = OuterProduct1D3D &
                    ( Ones(1:nDOFE), nDOFE, GX_K(1:nDOFX,iGF), nDOFX )

            END DO

            ! --- Interpolate Geometry Fields on Shared Face ---

            ! --- Face States (Average of Left and Right States) ---

            ! --- Scale Factors ---

            DO iGF = iGF_h_1, iGF_h_3

              CALL DGEMV &
                     ( 'N', nDOFX_X1, nDOFX, One,  LX_X1_Up, nDOFX_X1, &
                       GX_P(:,iGF), 1, Zero, GX_F(:,iGF), 1 )
              CALL DGEMV &
                     ( 'N', nDOFX_X1, nDOFX, Half, LX_X1_Dn, nDOFX_X1, &
                       GX_K(:,iGF), 1, Half, GX_F(:,iGF), 1 )

              GX_F(1:nDOFX_X1,iGF) &
                = MAX( GX_F(1:nDOFX_X1,iGF), SqrtTiny )

              G_F(1:nDOF_X1,iGF) &
                = OuterProduct1D3D &
                    ( Ones(1:nDOFE), nDOFE, GX_F(1:nDOFX_X1,iGF), nDOFX_X1 )

            END DO

            CALL ComputeGeometryX_FromScaleFactors( G_F(:,:) )

            ! --- Lapse Function ---

            CALL DGEMV &
                   ( 'N', nDOFX_X1, nDOFX, One,  LX_X1_Up, nDOFX_X1, &
                     GX_P(:,iGF_Alpha), 1, Zero, GX_F(:,iGF_Alpha), 1 )
            CALL DGEMV &
                   ( 'N', nDOFX_X1, nDOFX, Half, LX_X1_Dn, nDOFX_X1, &
                     GX_K(:,iGF_Alpha), 1, Half, GX_F(:,iGF_Alpha), 1 )

            GX_F(1:nDOFX_X1,iGF_Alpha) &
              = MAX( GX_F(1:nDOFX_X1,iGF_Alpha), SqrtTiny )

            G_F(1:nDOF_X1,iGF_Alpha) &
              = OuterProduct1D3D &
                  ( Ones(1:nDOFE), nDOFE, &
                    GX_F(1:nDOFX_X1,iGF_Alpha), nDOFX_X1 )

            DO iZ1 = iZ_B0(1), iZ_E0(1)

              dZ(1) = MeshE % Width(iZ1)

              ! --- Volume Jacobian in Energy-Position Element ---

              Tau(1:nDOF) &
                = OuterProduct1D3D &
                    ( Ones(1:nDOFE), nDOFE, G_K(:,iGF_SqrtGm), nDOFX )

              Tau_X1(1:nDOF_X1) &
                = OuterProduct1D3D &
                    ( Ones(1:nDOFE), nDOFE, G_F(:,iGF_SqrtGm), nDOFX_X1 )

              DO iCR = 1, nCR

                uCR_P(:,iCR) = U(:,iZ1,iZ2-1,iZ3,iZ4,iCR,iS)
                uCR_K(:,iCR) = U(:,iZ1,iZ2,  iZ3,iZ4,iCR,iS)

              END DO

              !--------------------
              ! --- Volume Term ---
              !--------------------

              IF( iZ2 < iZ_E0(2) + 1 )THEN

                CALL ComputePrimitive_TwoMoment &
                       ( uCR_K(:,iCR_N ), uCR_K(:,iCR_G1), &
                         uCR_K(:,iCR_G2), uCR_K(:,iCR_G3), &
                         uPR_K(:,iPR_D ), uPR_K(:,iPR_I1), &
                         uPR_K(:,iPR_I2), uPR_K(:,iPR_I3), &
                         G_K(:,iGF_Gm_dd_11), &
                         G_K(:,iGF_Gm_dd_22), &
                         G_K(:,iGF_Gm_dd_33) )

                DO iNode = 1, nDOF

                  FF = FluxFactor &
                         ( uPR_K(iNode,iPR_D ), uPR_K(iNode,iPR_I1), &
                           uPR_K(iNode,iPR_I2), uPR_K(iNode,iPR_I3), &
                           G_K(iNode,iGF_Gm_dd_11), &
                           G_K(iNode,iGF_Gm_dd_22), &
                           G_K(iNode,iGF_Gm_dd_33) )

                  EF = EddingtonFactor( uPR_K(iNode,iPR_D), FF )

                  Flux_X1_q(iNode,1:nCR) &
                    = Flux_X1 &
                        ( uPR_K(iNode,iPR_D ), uPR_K(iNode,iPR_I1), &
                          uPR_K(iNode,iPR_I2), uPR_K(iNode,iPR_I3), &
                          FF, EF, &
                          G_K(iNode,iGF_Gm_dd_11), &
                          G_K(iNode,iGF_Gm_dd_22), &
                          G_K(iNode,iGF_Gm_dd_33) )

                END DO

                DO iCR = 1, nCR

                  Flux_X1_q(:,iCR) &
                    = dZ(3) * dZ(4) * Weights_q(:) &
                        * G_K(:,iGF_Alpha) * Tau(:) * Flux_X1_q(:,iCR)

                  CALL DGEMV &
                         ( 'T', nDOF, nDOF, One, dLdX1_q, nDOF, &
                           Flux_X1_q(:,iCR), 1, One, &
                           dU(:,iZ1,iZ2,iZ3,iZ4,iCR,iS), 1 )

                END DO

              END IF

              !---------------------
              ! --- Surface Term ---
              !---------------------

              ! --- Interpolate Radiation Fields ---

              DO iCR = 1, nCR

                ! --- Interpolate Left State ---

                CALL DGEMV &
                       ( 'N', nDOF_X1, nDOF, One, L_X1_Up, nDOF_X1, &
                         uCR_P(:,iCR), 1, Zero, uCR_L(:,iCR), 1 )

                ! --- Interpolate Right State ---

                CALL DGEMV &
                       ( 'N', nDOF_X1, nDOF, One, L_X1_Dn, nDOF_X1, &
                         uCR_K(:,iCR), 1, Zero, uCR_R(:,iCR), 1 )

              END DO

              ! --- Left State Primitive, etc. ---

              CALL ComputePrimitive_TwoMoment &
                     ( uCR_L(:,iCR_N ), uCR_L(:,iCR_G1), &
                       uCR_L(:,iCR_G2), uCR_L(:,iCR_G3), &
                       uPR_L(:,iPR_D ), uPR_L(:,iPR_I1), &
                       uPR_L(:,iPR_I2), uPR_L(:,iPR_I3), &
                       G_F(:,iGF_Gm_dd_11), &
                       G_F(:,iGF_Gm_dd_22), &
                       G_F(:,iGF_Gm_dd_33) )

              DO iNode = 1, nDOF_X1

                FF = FluxFactor &
                       ( uPR_L(iNode,iPR_D ), uPR_L(iNode,iPR_I1), &
                         uPR_L(iNode,iPR_I2), uPR_L(iNode,iPR_I3), &
                         G_F(iNode,iGF_Gm_dd_11), &
                         G_F(iNode,iGF_Gm_dd_22), &
                         G_F(iNode,iGF_Gm_dd_33) )

                EF = EddingtonFactor( uPR_L(iNode,iPR_D), FF )

                Flux_X1_L(iNode,1:nCR) &
                  = Flux_X1 &
                      ( uPR_L(iNode,iPR_D ), uPR_L(iNode,iPR_I1), &
                        uPR_L(iNode,iPR_I2), uPR_L(iNode,iPR_I3), &
                        FF, EF, &
                        G_F(iNode,iGF_Gm_dd_11), &
                        G_F(iNode,iGF_Gm_dd_22), &
                        G_F(iNode,iGF_Gm_dd_33) )

                absLambda_L(iNode) = 1.0_DP

              END DO

              ! --- Right State Primitive, etc. ---

              CALL ComputePrimitive_TwoMoment &
                     ( uCR_R(:,iCR_N ), uCR_R(:,iCR_G1), &
                       uCR_R(:,iCR_G2), uCR_R(:,iCR_G3), &
                       uPR_R(:,iPR_D ), uPR_R(:,iPR_I1), &
                       uPR_R(:,iPR_I2), uPR_R(:,iPR_I3), &
                       G_F(:,iGF_Gm_dd_11), &
                       G_F(:,iGF_Gm_dd_22), &
                       G_F(:,iGF_Gm_dd_33) )

              DO iNode = 1, nDOF_X1

                FF = FluxFactor &
                       ( uPR_R(iNode,iPR_D ), uPR_R(iNode,iPR_I1), &
                         uPR_R(iNode,iPR_I2), uPR_R(iNode,iPR_I3), &
                         G_F(iNode,iGF_Gm_dd_11), &
                         G_F(iNode,iGF_Gm_dd_22), &
                         G_F(iNode,iGF_Gm_dd_33) )

                EF = EddingtonFactor( uPR_R(iNode,iPR_D), FF )

                Flux_X1_R(iNode,1:nCR) &
                  = Flux_X1 &
                      ( uPR_R(iNode,iPR_D ), uPR_R(iNode,iPR_I1), &
                        uPR_R(iNode,iPR_I2), uPR_R(iNode,iPR_I3), &
                        FF, EF, &
                        G_F(iNode,iGF_Gm_dd_11), &
                        G_F(iNode,iGF_Gm_dd_22), &
                        G_F(iNode,iGF_Gm_dd_33) )

                absLambda_R(iNode) = 1.0_DP

              END DO

              ! --- Numerical Flux ---

              alpha = MAX( absLambda_L, absLambda_R )

              DO iCR = 1, nCR

                NumericalFlux(:,iCR) &
                  = NumericalFlux_LLF &
                      ( uCR_L    (:,iCR), &
                        uCR_R    (:,iCR), &
                        Flux_X1_L(:,iCR), &
                        Flux_X1_R(:,iCR), alpha(:) )

                NumericalFlux(:,iCR) &
                  = dZ(3) * dZ(4) * Weights_X1(:) &
                      * G_F(:,iGF_Alpha) * Tau_X1(:) * NumericalFlux(:,iCR)

              END DO

              ! --- Contribution to this Element ---

              IF( iZ2 < iZ_E0(2) + 1 )THEN

                DO iCR = 1, nCR

                  CALL DGEMV &
                         ( 'T', nDOF_X1, nDOF, + One, L_X1_Dn, &
                           nDOF_X1, NumericalFlux(:,iCR), 1, One, &
                           dU(:,iZ1,iZ2  ,iZ3,iZ4,iCR,iS), 1 )

                END DO

              END IF

              ! --- Contribution to Previous Element ---

              IF( iZ2 > iZ_B0(2) )THEN

                DO iCR = 1, nCR

                  CALL DGEMV &
                         ( 'T', nDOF_X1, nDOF, - One, L_X1_Up, &
                           nDOF_X1, NumericalFlux(:,iCR), 1, One, &
                           dU(:,iZ1,iZ2-1,iZ3,iZ4,iCR,iS), 1 )

                END DO

              END IF

            END DO ! iZ1
          END DO ! iZ2
        END DO ! iZ3
      END DO ! iZ4
    END DO ! iS

  END SUBROUTINE ComputeIncrement_Divergence_X1


  SUBROUTINE ComputeIncrement_Divergence_X2 &
    ( iZ_B0, iZ_E0, iZ_B1, iZ_E1, GE, GX, U, dU )

    ! --- {Z1,Z2,Z3,Z4} = {E,X1,X2,X3} ---

    INTEGER,  INTENT(in)    :: &
      iZ_B0(4), iZ_E0(4), iZ_B1(4), iZ_E1(4)
    REAL(DP), INTENT(in)    :: &
      GE(1:,iZ_B1(1):,1:)
    REAL(DP), INTENT(in)    :: &
      GX(1:,iZ_B1(2):,iZ_B1(3):,iZ_B1(4):,1:)
    REAL(DP), INTENT(in)    :: &
      U (1:,iZ_B1(1):,iZ_B1(2):,iZ_B1(3):,iZ_B1(4):,1:,1:)
    REAL(DP), INTENT(inout) :: &
      dU(1:,iZ_B0(1):,iZ_B0(2):,iZ_B0(3):,iZ_B0(4):,1:,1:)

    INTEGER  :: iZ1, iZ2, iZ3, iZ4, iS, iNode
    INTEGER  :: iGF, iCR
    REAL(DP) :: dE, dX1, dX3
    REAL(DP) :: Tau   (nDOF)
    REAL(DP) :: Tau_X2(nDOF_X2)
    REAL(DP) :: FF(nDOF)
    REAL(DP) :: EF(nDOF)
    REAL(DP) :: GX_P(nDOFX,   nGF)
    REAL(DP) :: GX_K(nDOFX,   nGF)
    REAL(DP) :: GX_F(nDOFX_X2,nGF)
    REAL(DP) :: G_K (nDOF,    nGF)
    REAL(DP) :: G_F (nDOF_X2, nGF)
    REAL(DP) :: uCR_P(nDOF,nCR)
    REAL(DP) :: uCR_K(nDOF,nCR)
    REAL(DP) :: uPR_K(nDOF,nPR)
    REAL(DP) :: Flux_X2_q(nDOF,nCR)
    REAL(DP) :: FF_L(nDOF_X2), EF_L(nDOF_X2)
    REAL(DP) :: FF_R(nDOF_X2), EF_R(nDOF_X2)
    REAL(DP) :: absLambda_L(nDOF_X2)
    REAL(DP) :: absLambda_R(nDOF_X2)
    REAL(DP) :: alpha(nDOF_X2)
    REAL(DP) :: uCR_L(nDOF_X2,nCR), uCR_R(nDOF_X2,nCR)
    REAL(DP) :: uPR_L(nDOF_X2,nPR), uPR_R(nDOF_X2,nPR)
    REAL(DP) :: Flux_X2_L(nDOF_X2,nCR)
    REAL(DP) :: Flux_X2_R(nDOF_X2,nCR)
    REAL(DP) :: NumericalFlux(nDOF_X2,nCR)

    IF( iZ_E0(3) .EQ. iZ_B0(3) ) RETURN

    DO iS = 1, nSpecies

      DO iZ4 = iZ_B0(4), iZ_E0(4)

        dX3 = MeshX(3) % Width(iZ4)

        DO iZ3 = iZ_B0(3), iZ_E0(3) + 1

          DO iZ2 = iZ_B0(2), iZ_E0(2)

            dX1 = MeshX(1) % Width(iZ2)

            ! --- Geometry Fields in Element Nodes ---

            DO iGF = 1, nGF

              GX_P(:,iGF) = GX(:,iZ2,iZ3-1,iZ4,iGF) ! --- Previous Element
              GX_K(:,iGF) = GX(:,iZ2,iZ3,  iZ4,iGF) ! --- This     Element

              G_K(1:nDOF,iGF) &
                = OuterProduct1D3D &
                    ( Ones(1:nDOFE), nDOFE, GX_K(1:nDOFX,iGF), nDOFX )

            END DO

            ! --- Interpolate Geometry Fields on Shared Face ---

            ! --- Face States (Average of Left and Right States) ---

            DO iGF = iGF_h_1, iGF_h_3

              CALL DGEMV &
                     ( 'N', nDOFX_X2, nDOFX, One,  LX_X2_Up, nDOFX_X2, &
                       GX_P(:,iGF), 1, Zero, GX_F(:,iGF), 1 )
              CALL DGEMV &
                     ( 'N', nDOFX_X2, nDOFX, Half, LX_X2_Dn, nDOFX_X2, &
                       GX_K(:,iGF), 1, Half, GX_F(:,iGF), 1 )

              GX_F(1:nDOFX_X2,iGF) &
                = MAX( GX_F(1:nDOFX_X2,iGF), SqrtTiny )

              G_F(1:nDOF_X2,iGF) &
                = OuterProduct1D3D &
                    ( Ones(1:nDOFE), nDOFE, GX_F(1:nDOFX_X2,iGF), nDOFX_X2 )

            END DO

            CALL ComputeGeometryX_FromScaleFactors( G_F(:,:) )

            ! --- Lapse Function ---

            CALL DGEMV &
                   ( 'N', nDOFX_X2, nDOFX, One,  LX_X2_Up, nDOFX_X2, &
                     GX_P(:,iGF_Alpha), 1, Zero, GX_F(:,iGF_Alpha), 1 )
            CALL DGEMV &
                   ( 'N', nDOFX_X2, nDOFX, Half, LX_X2_Dn, nDOFX_X2, &
                     GX_K(:,iGF_Alpha), 1, Half, GX_F(:,iGF_Alpha), 1 )

            GX_F(1:nDOFX_X2,iGF_Alpha) &
              = MAX( GX_F(1:nDOFX_X2,iGF_Alpha), SqrtTiny )

            G_F(1:nDOF_X2,iGF_Alpha) &
              = OuterProduct1D3D &
                  ( Ones(1:nDOFE), nDOFE, &
                    GX_F(1:nDOFX_X2,iGF_Alpha), nDOFX_X2 )

            DO iZ1 = iZ_B0(1), iZ_E0(1)

              dE = MeshE % Width(iZ1)

              ! --- Volume Jacobian in Energy-Position Element ---

              Tau(1:nDOF) &
                = OuterProduct1D3D &
                    ( Ones(1:nDOFE), nDOFE, G_K(:,iGF_SqrtGm), nDOFX )

              Tau_X2(1:nDOF_X2) &
                = OuterProduct1D3D &
                    ( Ones(1:nDOFE), nDOFE, G_F(:,iGF_SqrtGm), nDOFX_X2 )

              DO iCR = 1, nCR

                uCR_P(:,iCR) = U(:,iZ1,iZ2,iZ3-1,iZ4,iCR,iS)
                uCR_K(:,iCR) = U(:,iZ1,iZ2,iZ3,  iZ4,iCR,iS)

              END DO

              !--------------------
              ! --- Volume Term ---
              !--------------------

              IF( iZ3 < iZ_E0(3) + 1 )THEN

                CALL ComputePrimitive_TwoMoment &
                       ( uCR_K(:,iCR_N ), uCR_K(:,iCR_G1), &
                         uCR_K(:,iCR_G2), uCR_K(:,iCR_G3), &
                         uPR_K(:,iPR_D ), uPR_K(:,iPR_I1), &
                         uPR_K(:,iPR_I2), uPR_K(:,iPR_I3), &
                         G_K(:,iGF_Gm_dd_11), &
                         G_K(:,iGF_Gm_dd_22), &
                         G_K(:,iGF_Gm_dd_33) )

                FF = FluxFactor &
                       ( uPR_K(:,iPR_D ), uPR_K(:,iPR_I1), &
                         uPR_K(:,iPR_I2), uPR_K(:,iPR_I3), &
                         G_K(:,iGF_Gm_dd_11), &
                         G_K(:,iGF_Gm_dd_22), &
                         G_K(:,iGF_Gm_dd_33) )

                EF = EddingtonFactor &
                       ( uPR_K(:,iPR_D), FF(:) )

                DO iNode = 1, nDOF

                  Flux_X2_q(iNode,1:nCR) &
                    = Flux_X2 &
                        ( uPR_K(iNode,iPR_D ), uPR_K(iNode,iPR_I1), &
                          uPR_K(iNode,iPR_I2), uPR_K(iNode,iPR_I3), &
                          FF(iNode), EF(iNode), &
                          G_K(iNode,iGF_Gm_dd_11), &
                          G_K(iNode,iGF_Gm_dd_22), &
                          G_K(iNode,iGF_Gm_dd_33) )

                END DO

                DO iCR = 1, nCR

                  Flux_X2_q(:,iCR) &
                    = dX1 * dX3 * Weights_q(:) &
                        * G_K(:,iGF_Alpha) * Tau(:) * Flux_X2_q(:,iCR)

                  CALL DGEMV &
                         ( 'T', nDOF, nDOF, One, dLdX2_q, nDOF, &
                           Flux_X2_q(:,iCR), 1, One, &
                           dU(:,iZ1,iZ2,iZ3,iZ4,iCR,iS), 1 )

                END DO

              END IF

              !---------------------
              ! --- Surface Term ---
              !---------------------

              ! --- Interpolate Radiation Fields ---

              DO iCR = 1, nCR

                ! --- Interpolate Left State ---

                CALL DGEMV &
                       ( 'N', nDOF_X2, nDOF, One, L_X2_Up, nDOF_X2, &
                         uCR_P(:,iCR), 1, Zero, uCR_L(:,iCR), 1 )

                ! --- Interpolate Right State ---

                CALL DGEMV &
                       ( 'N', nDOF_X2, nDOF, One, L_X2_Dn, nDOF_X2, &
                         uCR_K(:,iCR), 1, Zero, uCR_R(:,iCR), 1 )

              END DO

              ! --- Left State Primitive, etc. ---

              CALL ComputePrimitive_TwoMoment &
                     ( uCR_L(:,iCR_N ), uCR_L(:,iCR_G1), &
                       uCR_L(:,iCR_G2), uCR_L(:,iCR_G3), &
                       uPR_L(:,iPR_D ), uPR_L(:,iPR_I1), &
                       uPR_L(:,iPR_I2), uPR_L(:,iPR_I3), &
                       G_F(:,iGF_Gm_dd_11), &
                       G_F(:,iGF_Gm_dd_22), &
                       G_F(:,iGF_Gm_dd_33) )

              FF_L(:) &
                = FluxFactor &
                    ( uPR_L(:,iPR_D ), uPR_L(:,iPR_I1), &
                      uPR_L(:,iPR_I2), uPR_L(:,iPR_I3), &
                      G_F(:,iGF_Gm_dd_11), &
                      G_F(:,iGF_Gm_dd_22), &
                      G_F(:,iGF_Gm_dd_33) )

              EF_L(:) &
                = EddingtonFactor &
                    ( uPR_L(:,iPR_D), FF_L(:) )

              absLambda_L(:) = One

              DO iNode = 1, nDOF_X2

                Flux_X2_L(iNode,1:nCR) &
                  = Flux_X2 &
                      ( uPR_L(iNode,iPR_D ), uPR_L(iNode,iPR_I1), &
                        uPR_L(iNode,iPR_I2), uPR_L(iNode,iPR_I3), &
                        FF_L(iNode), EF_L(iNode), &
                        G_F(iNode,iGF_Gm_dd_11), &
                        G_F(iNode,iGF_Gm_dd_22), &
                        G_F(iNode,iGF_Gm_dd_33) )

              END DO

              ! --- Right State Primitive, etc. ---

              CALL ComputePrimitive_TwoMoment &
                     ( uCR_R(:,iCR_N ), uCR_R(:,iCR_G1), &
                       uCR_R(:,iCR_G2), uCR_R(:,iCR_G3), &
                       uPR_R(:,iPR_D ), uPR_R(:,iPR_I1), &
                       uPR_R(:,iPR_I2), uPR_R(:,iPR_I3), &
                       G_F(:,iGF_Gm_dd_11), &
                       G_F(:,iGF_Gm_dd_22), &
                       G_F(:,iGF_Gm_dd_33) )

              FF_R(:) &
                = FluxFactor &
                    ( uPR_R(:,iPR_D ), uPR_R(:,iPR_I1), &
                      uPR_R(:,iPR_I2), uPR_R(:,iPR_I3), &
                      G_F(:,iGF_Gm_dd_11), &
                      G_F(:,iGF_Gm_dd_22), &
                      G_F(:,iGF_Gm_dd_33) )

              EF_R(:) &
                = EddingtonFactor &
                    ( uPR_R(:,iPR_D), FF_R(:) )

              absLambda_R(:) = One

              DO iNode = 1, nDOF_X2

                Flux_X2_R(iNode,1:nCR) &
                  = Flux_X2 &
                      ( uPR_R(iNode,iPR_D ), uPR_R(iNode,iPR_I1), &
                        uPR_R(iNode,iPR_I2), uPR_R(iNode,iPR_I3), &
                        FF_R(iNode), EF_R(iNode), &
                        G_F(iNode,iGF_Gm_dd_11), &
                        G_F(iNode,iGF_Gm_dd_22), &
                        G_F(iNode,iGF_Gm_dd_33) )

              END DO

              ! --- Numerical Flux ---

              alpha = MAX( absLambda_L, absLambda_R )

              DO iCR = 1, nCR

                NumericalFlux(:,iCR) &
                  = NumericalFlux_LLF &
                      ( uCR_L    (:,iCR), &
                        uCR_R    (:,iCR), &
                        Flux_X2_L(:,iCR), &
                        Flux_X2_R(:,iCR), alpha(:) )

                NumericalFlux(:,iCR) &
                  = dX1 * dX3 * Weights_X2(:) &
                      * G_F(:,iGF_Alpha) * Tau_X2(:) * NumericalFlux(:,iCR)

              END DO

              ! --- Contribution to this Element ---

              IF( iZ3 < iZ_E0(3) + 1 )THEN

                DO iCR = 1, nCR

                  CALL DGEMV &
                         ( 'T', nDOF_X2, nDOF, + One, L_X2_Dn, &
                           nDOF_X2, NumericalFlux(:,iCR), 1, One, &
                           dU(:,iZ1,iZ2,iZ3  ,iZ4,iCR,iS), 1 )

                END DO

              END IF

              ! --- Contribution to Previous Element ---

              IF( iZ3 > iZ_B0(3) )THEN

                DO iCR = 1, nCR

                  CALL DGEMV &
                         ( 'T', nDOF_X2, nDOF, - One, L_X2_Up, &
                           nDOF_X2, NumericalFlux(:,iCR), 1, One, &
                           dU(:,iZ1,iZ2,iZ3-1,iZ4,iCR,iS), 1 )

                END DO

              END IF

            END DO ! iZ1
          END DO ! iZ2
        END DO ! iZ3
      END DO ! iZ4
    END DO ! iS

  END SUBROUTINE ComputeIncrement_Divergence_X2


  SUBROUTINE ComputeIncrement_Divergence_X3 &
    ( iZ_B0, iZ_E0, iZ_B1, iZ_E1, GE, GX, U, dU )

    ! --- {Z1,Z2,Z3,Z4} = {E,X1,X2,X3} ---

    INTEGER,  INTENT(in)    :: &
      iZ_B0(4), iZ_E0(4), iZ_B1(4), iZ_E1(4)
    REAL(DP), INTENT(in)    :: &
      GE(1:,iZ_B1(1):,1:)
    REAL(DP), INTENT(in)    :: &
      GX(1:,iZ_B1(2):,iZ_B1(3):,iZ_B1(4):,1:)
    REAL(DP), INTENT(in)    :: &
      U (1:,iZ_B1(1):,iZ_B1(2):,iZ_B1(3):,iZ_B1(4):,1:,1:)
    REAL(DP), INTENT(inout) :: &
      dU(1:,iZ_B0(1):,iZ_B0(2):,iZ_B0(3):,iZ_B0(4):,1:,1:)

    INTEGER  :: iZ1, iZ2, iZ3, iZ4, iS, iNode
    INTEGER  :: iGF, iCR
    REAL(DP) :: dE, dX1, dX2
    REAL(DP) :: Tau   (nDOF)
    REAL(DP) :: Tau_X3(nDOF_X3)
    REAL(DP) :: FF(nDOF)
    REAL(DP) :: EF(nDOF)
    REAL(DP) :: GX_P(nDOFX,   nGF)
    REAL(DP) :: GX_K(nDOFX,   nGF)
    REAL(DP) :: GX_F(nDOFX_X3,nGF)
    REAL(DP) :: G_K (nDOF,    nGF)
    REAL(DP) :: G_F (nDOF_X3, nGF)
    REAL(DP) :: uCR_P(nDOF,nCR)
    REAL(DP) :: uCR_K(nDOF,nCR)
    REAL(DP) :: uPR_K(nDOF,nPR)
    REAL(DP) :: Flux_X3_q(nDOF,nCR)
    REAL(DP) :: FF_L(nDOF_X3), EF_L(nDOF_X3)
    REAL(DP) :: FF_R(nDOF_X3), EF_R(nDOF_X3)
    REAL(DP) :: alpha(nDOF_X3)
    REAL(DP) :: absLambda_L(nDOF_X3)
    REAL(DP) :: absLambda_R(nDOF_X3)
    REAL(DP) :: uCR_L(nDOF_X3,nCR), uCR_R(nDOF_X3,nCR)
    REAL(DP) :: uPR_L(nDOF_X3,nPR), uPR_R(nDOF_X3,nPR)
    REAL(DP) :: Flux_X3_L(nDOF_X3,nCR)
    REAL(DP) :: Flux_X3_R(nDOF_X3,nCR)
    REAL(DP) :: NumericalFlux(nDOF_X3,nCR)

    IF( iZ_E0(4) .EQ. iZ_B0(4) ) RETURN

    DO iS = 1, nSpecies

      DO iZ4 = iZ_B0(4), iZ_E0(4) + 1

        DO iZ3 = iZ_B0(3), iZ_E0(3)

          dX2 = MeshX(2) % Width(iZ3)

          DO iZ2 = iZ_B0(2), iZ_E0(2)

            dX1 = MeshX(1) % Width(iZ2)

            ! --- Geometry Fields in Element Nodes ---

            DO iGF = 1, nGF

              GX_P(:,iGF) = GX(:,iZ2,iZ3,iZ4-1,iGF) ! --- Previous Element
              GX_K(:,iGF) = GX(:,iZ2,iZ3,iZ4,  iGF) ! --- This     Element

              G_K(1:nDOF,iGF) &
                = OuterProduct1D3D &
                    ( Ones(1:nDOFE), nDOFE, GX_K(1:nDOFX,iGF), nDOFX )

            END DO

            ! --- Interpolate Geometry Fields on Shared Face ---

            ! --- Face States (Average of Left and Right States) ---

            DO iGF = iGF_h_1, iGF_h_3

              CALL DGEMV &
                     ( 'N', nDOFX_X3, nDOFX, One,  LX_X3_Up, nDOFX_X3, &
                       GX_P(:,iGF), 1, Zero, GX_F(:,iGF), 1 )
              CALL DGEMV &
                     ( 'N', nDOFX_X3, nDOFX, Half, LX_X3_Dn, nDOFX_X3, &
                       GX_K(:,iGF), 1, Half, GX_F(:,iGF), 1 )

              GX_F(1:nDOFX_X3,iGF) &
                = MAX( GX_F(1:nDOFX_X3,iGF), SqrtTiny )

              G_F(1:nDOF_X3,iGF) &
                = OuterProduct1D3D &
                    ( Ones(1:nDOFE), nDOFE, GX_F(1:nDOFX_X3,iGF), nDOFX_X3 )

            END DO

            CALL ComputeGeometryX_FromScaleFactors( G_F(:,:) )

            ! --- Lapse Function ---

            CALL DGEMV &
                   ( 'N', nDOFX_X3, nDOFX, One,  LX_X3_Up, nDOFX_X3, &
                     GX_P(:,iGF_Alpha), 1, Zero, GX_F(:,iGF_Alpha), 1 )
            CALL DGEMV &
                   ( 'N', nDOFX_X3, nDOFX, Half, LX_X3_Dn, nDOFX_X3, &
                     GX_K(:,iGF_Alpha), 1, Half, GX_F(:,iGF_Alpha), 1 )

            GX_F(1:nDOFX_X3,iGF_Alpha) &
              = MAX( GX_F(1:nDOFX_X3,iGF_Alpha), SqrtTiny )

            G_F(1:nDOF_X3,iGF_Alpha) &
              = OuterProduct1D3D &
                  ( Ones(1:nDOFE), nDOFE, &
                    GX_F(1:nDOFX_X3,iGF_Alpha), nDOFX_X3 )

            DO iZ1 = iZ_B0(1), iZ_E0(1)

              dE = MeshE % Width(iZ1)

              ! --- Volume Jacobian in Energy-Position Element ---

              Tau(1:nDOF) &
                = OuterProduct1D3D &
                    ( Ones(1:nDOFE), nDOFE, G_K(:,iGF_SqrtGm), nDOFX )

              Tau_X3(1:nDOF_X3) &
                = OuterProduct1D3D &
                    ( Ones(1:nDOFE), nDOFE, G_F(:,iGF_SqrtGm), nDOFX_X3 )

              DO iCR = 1, nCR

                uCR_P(:,iCR) = U(:,iZ1,iZ2,iZ3,iZ4-1,iCR,iS)
                uCR_K(:,iCR) = U(:,iZ1,iZ2,iZ3,iZ4,  iCR,iS)

              END DO

              !--------------------
              ! --- Volume Term ---
              !--------------------

              IF( iZ4 < iZ_E0(4) + 1 )THEN

                CALL ComputePrimitive_TwoMoment &
                       ( uCR_K(:,iCR_N ), uCR_K(:,iCR_G1), &
                         uCR_K(:,iCR_G2), uCR_K(:,iCR_G3), &
                         uPR_K(:,iPR_D ), uPR_K(:,iPR_I1), &
                         uPR_K(:,iPR_I2), uPR_K(:,iPR_I3), &
                         G_K(:,iGF_Gm_dd_11), &
                         G_K(:,iGF_Gm_dd_22), &
                         G_K(:,iGF_Gm_dd_33) )

                FF = FluxFactor &
                       ( uPR_K(:,iPR_D ), uPR_K(:,iPR_I1), &
                         uPR_K(:,iPR_I2), uPR_K(:,iPR_I3), &
                         G_K(:,iGF_Gm_dd_11), &
                         G_K(:,iGF_Gm_dd_22), &
                         G_K(:,iGF_Gm_dd_33) )

                EF = EddingtonFactor &
                       ( uPR_K(:,iPR_D), FF(:) )

                DO iNode = 1, nDOF

                  Flux_X3_q(iNode,1:nCR) &
                    = Flux_X3 &
                        ( uPR_K(iNode,iPR_D ), uPR_K(iNode,iPR_I1), &
                          uPR_K(iNode,iPR_I2), uPR_K(iNode,iPR_I3), &
                          FF(iNode), EF(iNode), &
                          G_K(iNode,iGF_Gm_dd_11), &
                          G_K(iNode,iGF_Gm_dd_22), &
                          G_K(iNode,iGF_Gm_dd_33) )

                END DO

                DO iCR = 1, nCR

                  Flux_X3_q(:,iCR) &
                    = dX1 * dX2 * Weights_q(:) &
                        * G_K(:,iGF_Alpha) * Tau(:) * Flux_X3_q(:,iCR)

                  CALL DGEMV &
                         ( 'T', nDOF, nDOF, One, dLdX3_q, nDOF, &
                           Flux_X3_q(:,iCR), 1, One, &
                           dU(:,iZ1,iZ2,iZ3,iZ4,iCR,iS), 1 )

                END DO

              END IF

              !---------------------
              ! --- Surface Term ---
              !---------------------

              ! --- Interpolate Radiation Fields ---

              DO iCR = 1, nCR

                ! --- Interpolate Left State ---

                CALL DGEMV &
                       ( 'N', nDOF_X3, nDOF, One, L_X3_Up, nDOF_X3, &
                         uCR_P(:,iCR), 1, Zero, uCR_L(:,iCR), 1 )

                ! --- Interpolate Right State ---

                CALL DGEMV &
                       ( 'N', nDOF_X3, nDOF, One, L_X3_Dn, nDOF_X3, &
                         uCR_K(:,iCR), 1, Zero, uCR_R(:,iCR), 1 )

              END DO

              ! --- Left State Primitive, etc. ---

              CALL ComputePrimitive_TwoMoment &
                     ( uCR_L(:,iCR_N ), uCR_L(:,iCR_G1), &
                       uCR_L(:,iCR_G2), uCR_L(:,iCR_G3), &
                       uPR_L(:,iPR_D ), uPR_L(:,iPR_I1), &
                       uPR_L(:,iPR_I2), uPR_L(:,iPR_I3), &
                       G_F(:,iGF_Gm_dd_11), &
                       G_F(:,iGF_Gm_dd_22), &
                       G_F(:,iGF_Gm_dd_33) )

              FF_L(:) &
                = FluxFactor &
                    ( uPR_L(:,iPR_D ), uPR_L(:,iPR_I1), &
                      uPR_L(:,iPR_I2), uPR_L(:,iPR_I3), &
                      G_F(:,iGF_Gm_dd_11), &
                      G_F(:,iGF_Gm_dd_22), &
                      G_F(:,iGF_Gm_dd_33) )

              EF_L(:) &
                = EddingtonFactor &
                    ( uPR_L(:,iPR_D), FF_L(:) )

              absLambda_L(:) = One

              DO iNode = 1, nDOF_X3

                Flux_X3_L(iNode,1:nCR) &
                  = Flux_X3 &
                      ( uPR_L(iNode,iPR_D ), uPR_L(iNode,iPR_I1), &
                        uPR_L(iNode,iPR_I2), uPR_L(iNode,iPR_I3), &
                        FF_L(iNode), EF_L(iNode), &
                        G_F(iNode,iGF_Gm_dd_11), &
                        G_F(iNode,iGF_Gm_dd_22), &
                        G_F(iNode,iGF_Gm_dd_33) )

              END DO

              ! --- Right State Primitive, etc. ---

              CALL ComputePrimitive_TwoMoment &
                     ( uCR_R(:,iCR_N ), uCR_R(:,iCR_G1), &
                       uCR_R(:,iCR_G2), uCR_R(:,iCR_G3), &
                       uPR_R(:,iPR_D ), uPR_R(:,iPR_I1), &
                       uPR_R(:,iPR_I2), uPR_R(:,iPR_I3), &
                       G_F(:,iGF_Gm_dd_11), &
                       G_F(:,iGF_Gm_dd_22), &
                       G_F(:,iGF_Gm_dd_33) )

              FF_R(:) &
                = FluxFactor &
                    ( uPR_R(:,iPR_D ), uPR_R(:,iPR_I1), &
                      uPR_R(:,iPR_I2), uPR_R(:,iPR_I3), &
                      G_F(:,iGF_Gm_dd_11), &
                      G_F(:,iGF_Gm_dd_22), &
                      G_F(:,iGF_Gm_dd_33) )

              EF_R(:) &
                = EddingtonFactor &
                    ( uPR_R(:,iPR_D), FF_R(:) )

              absLambda_R(:) = One

              DO iNode = 1, nDOF_X3

                Flux_X3_R(iNode,1:nCR) &
                  = Flux_X3 &
                      ( uPR_R(iNode,iPR_D ), uPR_R(iNode,iPR_I1), &
                        uPR_R(iNode,iPR_I2), uPR_R(iNode,iPR_I3), &
                        FF_R(iNode), EF_R(iNode), &
                        G_F(iNode,iGF_Gm_dd_11), &
                        G_F(iNode,iGF_Gm_dd_22), &
                        G_F(iNode,iGF_Gm_dd_33) )

              END DO

              ! --- Numerical Flux ---

              alpha = MAX( absLambda_L, absLambda_R )

              DO iCR = 1, nCR

                NumericalFlux(:,iCR) &
                  = NumericalFlux_LLF &
                      ( uCR_L    (:,iCR), &
                        uCR_R    (:,iCR), &
                        Flux_X3_L(:,iCR), &
                        Flux_X3_R(:,iCR), alpha(:) )

                NumericalFlux(:,iCR) &
                  = dX1 * dX2 * Weights_X3(:) &
                      * G_F(:,iGF_Alpha) * Tau_X3(:) * NumericalFlux(:,iCR)

              END DO

              ! --- Contribution to this Element ---

              IF( iZ4 < iZ_E0(4) + 1 )THEN

                DO iCR = 1, nCR

                  CALL DGEMV &
                         ( 'T', nDOF_X3, nDOF, + One, L_X3_Dn, &
                           nDOF_X3, NumericalFlux(:,iCR), 1, One, &
                           dU(:,iZ1,iZ2,iZ3  ,iZ4,iCR,iS), 1 )

                END DO

              END IF

              ! --- Contribution to Previous Element ---

              IF( iZ4 > iZ_B0(4) )THEN

                DO iCR = 1, nCR

                  CALL DGEMV &
                         ( 'T', nDOF_X3, nDOF, - One, L_X3_Up, &
                           nDOF_X3, NumericalFlux(:,iCR), 1, One, &
                           dU(:,iZ1,iZ2,iZ3,iZ4-1,iCR,iS), 1 )

                END DO

              END IF

            END DO ! iZ1
          END DO ! iZ2
        END DO ! iZ3
      END DO ! iZ4
    END DO ! iS

  END SUBROUTINE ComputeIncrement_Divergence_X3


END MODULE TwoMoment_DiscretizationModule_Streaming
