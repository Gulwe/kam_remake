unit KM_RenderTypes;
{$I KaM_Remake.inc}
interface
uses
  KM_CommonGameTypes, KM_Points;

type
  TTexFormat = (
    tfRGB5A1,
    tfRGBA8,
    tfAlpha8 //Mask used for team colors and house construction steps (GL_ALPHA)
    );

  TFilterType = (
    ftNearest,
    ftLinear
  );

  TKMRenderPoolAddProjectileEvent = procedure (aProj: TKMProjectileType; const aRenderPos, aTilePos: TKMPointF; aDir: TKMDirection; aFlight: Single) of object;

implementation


end.
