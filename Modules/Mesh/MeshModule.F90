MODULE MeshModule

  USE KindModule, ONLY: &
    DP
  USE QuadratureModule, ONLY: &
    GetQuadrature

  IMPLICIT NONE
  PRIVATE

  TYPE, PUBLIC :: MeshType
    REAL(DP)                            :: Length
    REAL(DP), DIMENSION(:), ALLOCATABLE :: Center
    REAL(DP), DIMENSION(:), ALLOCATABLE :: Width
    REAL(DP), DIMENSION(:), ALLOCATABLE :: Nodes
  END type MeshType

  TYPE(MeshType), DIMENSION(3), PUBLIC :: MeshX ! Spatial  Mesh
  TYPE(MeshType),               PUBLIC :: MeshE ! Spectral Mesh

  PUBLIC :: CreateMesh
  PUBLIC :: DestroyMesh
  PUBLIC :: NodeCoordinate

CONTAINS


  SUBROUTINE CreateMesh( Mesh, N, nN, SW, xL, xR, ZoomOption )

    TYPE(MeshType)                 :: Mesh
    INTEGER, INTENT(in)            :: N, nN, SW
    REAL(DP), INTENT(in)           :: xL, xR
    REAL(DP), INTENT(in), OPTIONAL :: ZoomOption

    REAL(DP) :: Zoom
    REAL(DP) :: xQ(nN), wQ(nN)

    IF( PRESENT( ZoomOption ) )THEN
      Zoom = ZoomOption
    ELSE
      Zoom = 1.0_DP
    END IF

    Mesh % Length = xR - xL

    ALLOCATE( Mesh % Center(1-SW:N+SW) )
    ALLOCATE( Mesh % Width (1-SW:N+SW) )

    IF( Zoom > 1.0_DP )THEN

      CALL CreateMesh_Geometric &
             ( N, SW, xL, xR, Mesh % Center, Mesh % Width, Zoom )

    ELSE

      CALL CreateMesh_Equidistant &
             ( N, SW, xL, xR, Mesh % Center, Mesh % Width )

    END IF

    CALL GetQuadrature( nN, xQ, wQ )

    ALLOCATE( Mesh % Nodes(1:nN) )
    Mesh % Nodes = xQ

  END SUBROUTINE CreateMesh


  SUBROUTINE CreateMesh_Equidistant( N, SW, xL, xR, Center, Width )

    INTEGER,                        INTENT(in)    :: N, SW
    REAL(DP),                       INTENT(in)    :: xL, xR
    REAL(DP), DIMENSION(1-SW:N+SW), INTENT(inout) :: Center, Width

    INTEGER :: i

    Width(:) = ( xR - xL ) / REAL( N )

    Center(1) = xL + 0.5_DP * Width(1)
    DO i = 2, N
      Center(i) = Center(i-1) + Width(i-1)
    END DO

    DO i = 0, 1 - SW, - 1
      Center(i) = Center(i+1) - Width(i+1)
    END DO

    DO i = N + 1, N + SW
      Center(i) = Center(i-1) + Width(i-1)
    END DO

  END SUBROUTINE CreateMesh_Equidistant


  SUBROUTINE CreateMesh_Geometric( N, SW, xL, xR, Center, Width, Zoom )

    INTEGER,                        INTENT(in)    :: N, SW
    REAL(DP),                       INTENT(in)    :: xL, xR, Zoom
    REAL(DP), DIMENSION(1-SW:N+SW), INTENT(inout) :: Center, Width

    INTEGER :: i

    Width (1) = ( xR - xL ) * ( Zoom - 1.0_DP ) / ( Zoom**N - 1.0_DP )
    Center(1) = xL + 0.5_DP * Width(1)
    DO i = 2, N
      Width (i) = Width(i-1) * Zoom
      Center(i) = xL + SUM( Width(1:i-1) ) + 0.5_DP * Width(i)
    END DO

    DO i = 0, 1 - SW, - 1
      Width (i) = Width(1)
      Center(i) = xL - SUM( Width(i+1:1-SW) ) - 0.5_DP * Width(i)
    END DO

    DO i = N + 1, N + SW
      Width (i) = Width(N)
      Center(i) = xL + SUM( Width(1:i-1) ) + 0.5_DP * Width(i)
    END DO

  END SUBROUTINE CreateMesh_Geometric


  SUBROUTINE CreateMesh_Custom &
    ( N, SW, nEquidistant, MinWidth, xL, xR, Center, Width )

    INTEGER,  INTENT(in)    :: N,  SW
    INTEGER,  INTENT(in)    :: nEquidistant
    REAL(DP), INTENT(in)    :: MinWidth
    REAL(DP), INTENT(in)    :: xL, xR
    REAL(DP), INTENT(inout) :: Center(1-SW:N+SW)
    REAL(DP), INTENT(inout) :: Width (1-SW:N+SW)

  END SUBROUTINE CreateMesh_Custom


  SUBROUTINE DestroyMesh( Mesh )

    TYPE(MeshType) :: Mesh

    IF (ALLOCATED( Mesh % Center )) THEN
       DEALLOCATE( Mesh % Center )
    END IF

    IF (ALLOCATED( Mesh % Width  )) THEN
       DEALLOCATE( Mesh % Width  )
    END IF

    IF (ALLOCATED( Mesh % Nodes  )) THEN
       DEALLOCATE( Mesh % Nodes  )
    END IF

  END SUBROUTINE DestroyMesh


  PURE REAL(DP) FUNCTION NodeCoordinate( Mesh, iC, iN )

    TYPE(MeshType), INTENT(in) :: Mesh
    INTEGER,        INTENT(in) :: iC, iN

    NodeCoordinate &
      = Mesh % Center(iC) + Mesh % Width(iC) * Mesh % Nodes(iN)

    RETURN
  END FUNCTION NodeCoordinate


END MODULE MeshModule
