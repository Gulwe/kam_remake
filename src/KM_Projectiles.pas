unit KM_Projectiles;
{$I KaM_Remake.inc}
interface
uses
  KM_Units, KM_Houses,
  KM_CommonClasses, KM_Points;


type
  TKMProjectileType = (ptArrow, ptBolt, ptSlingRock, ptTowerRock); {ptBallistaRock, }

const //Corresponding indices in units.rx //ptArrow, ptBolt are unused
  ProjectileBounds: array [TKMProjectileType, 1..2] of word = ((0,0), (0,0), (0,0), (4186,4190));

type
  //Projectiles in-game: arrows, bolts, rocks, etc..
  //Once launched they are on their own
  TKMProjectiles = class
  private
    fItems: array of record //1..n
      fScreenStart: TKMPointF; //Screen-space trajectory start
      fScreenEnd: TKMPointF;   //Screen-space trajectory end

      fAim: TKMPointF;  //Where we were aiming to hit
      fTarget: TKMPointF; //Where projectile will hit
      fShotFrom: TKMPointF; //Where the projectile was launched from

      fType: TKMProjectileType; //type of projectile (arrow, bolt, rocks, etc..)
      fOwner: TKMUnit; //The projectiles owner, used for kill statistics and script events
      fSpeed: Single; //Each projectile speed may vary a little bit
      fArc: Single; //Thats how high projectile will go along parabola (varies a little more)
      fPosition: Single; //Projectiles position along the route Start>>End
      fLength: Single; //Route length to look-up for hit
      fMaxLength: Single; //Maximum length the archer could have shot
    end;

    function AddItem(const aStart,aAim,aEnd: TKMPointF; aSpeed, aArc, aMaxLength: Single; aProjType: TKMProjectileType; aOwner: TKMUnit):word;
    procedure RemItem(aIndex: Integer);
    function ProjectileVisible(aIndex: Integer): Boolean;
  public
    constructor Create;
    function AimTarget(const aStart: TKMPointF; aTarget: TKMUnit; aProjType: TKMProjectileType; aOwner: TKMUnit; aMaxRange,aMinRange: Single):word; overload;
    function AimTarget(const aStart: TKMPointF; aTarget: TKMHouse; aProjType: TKMProjectileType; aOwner: TKMUnit; aMaxRange,aMinRange: Single):word; overload;

    procedure UpdateState;
    procedure Paint(aTickLag: Single);

    procedure Save(SaveStream: TKMemoryStream);
    procedure Load(LoadStream: TKMemoryStream);
    procedure SyncLoad;
  end;


var
  gProjectiles: TKMProjectiles;


implementation
uses
  Math, KromUtils,
  KM_Terrain, KM_RenderPool, KM_RenderAux,
  KM_Resource, KM_ResSound, KM_ResUnits,
  KM_Hand, KM_HandsCollection, KM_Sound,
  KM_CommonUtils, KM_Defaults;


const
  ProjectileLaunchSounds:array[TKMProjectileType] of TSoundFX = (sfxBowShoot, sfxCrossbowShoot, sfxNone, sfxRockThrow);
  ProjectileHitSounds:   array[TKMProjectileType] of TSoundFX = (sfxArrowHit, sfxArrowHit, sfxArrowHit, sfxNone);
  ProjectileSpeeds:array[TKMProjectileType] of Single = (0.75, 0.75, 0.6, 0.8);
  ProjectileArcs:array[TKMProjectileType,1..2] of Single = ((1.6, 0.5), (1.4, 0.4), (2.5, 1), (1.2, 0.2)); //Arc curve and random fraction
  ProjectileJitter:array[TKMProjectileType] of Single = (0.26, 0.29, 0.26, 0.2); //Fixed Jitter added every time
  ProjectileJitterHouse:array[TKMProjectileType] of Single = (0.6, 0.6, 0.6, 0); //Fixed Jitter added every time
  //Jitter added according to target's speed (moving target harder to hit) Note: Walking = 0.1, so the added jitter is 0.1*X
  ProjectilePredictJitter:array[TKMProjectileType] of Single = (2, 2, 2, 3);


{ TKMProjectiles }
constructor TKMProjectiles.Create;
begin
  inherited Create;
  //Nothing here yet
end;


procedure TKMProjectiles.RemItem(aIndex: Integer);
begin
  gHands.CleanUpUnitPointer(fItems[aIndex].fOwner);
  fItems[aIndex].fSpeed := 0;
end;


function TKMProjectiles.AimTarget(const aStart: TKMPointF; aTarget: TKMUnit; aProjType: TKMProjectileType; aOwner: TKMUnit; aMaxRange,aMinRange: Single): Word;
var
  TargetVector,Target,TargetPosition: TKMPointF;
  A,B,C,D: Single;
  TimeToHit, Time1, Time2, DistanceToHit, DistanceInRange: Single;
  Jitter, Speed, Arc: Single;
  U: TKMUnit;
begin
  //Now we know projectiles speed and aim, we can predict where target will be at the time projectile hits it

  //I wonder if medieval archers knew about vectors and quadratic equations

  TargetPosition.X := (aTarget.PositionF.X - aStart.X);
  TargetPosition.Y := (aTarget.PositionF.Y - aStart.Y);
  TargetVector := aTarget.GetMovementVector;

  { This comment explains how we came to final ABC equation

    Target = TargetPosition + TargetVector * Time;
    FlightDistance := ArrowSpeed * Time;

    sqr(Target) = sqr(FlightDistance);

    sqr(TargetPosition + TargetVector * Time) = sqr(ArrowSpeed * Time)

    sqr(TargetPosition.X) + 2 * Time * TargetPosition.X * TargetVector.X + sqr(Time) * sqr(TargetVector.X) +
    sqr(ArrowSpeed) * sqr(Time)

    sqr(Time) * (sqr(TargetVector.X) + sqr(TargetVector.Y) - sqr(ArrowSpeed)) +
    2 * Time * (TargetPosition.X * TargetVector.X + TargetPosition.Y * TargetVector.Y) +
    sqr(TargetPosition.X) + sqr(TargetPosition.Y) = 0

    //Lets try to solve this quadratic equation
    //ATT + BT + C = 0
    //by using formulae X = (-B +- sqrt(B*B - 4*A*C)) / 2*A
    A = sqr(TargetVector.X) + sqr(TargetVector.Y) - sqr(ArrowSpeed)
    B = 2 * (TargetPosition.X * TargetVector.X + TargetPosition.Y * TargetVector.Y)
    C = sqr(TargetPosition.X) + sqr(TargetPosition.Y) }

  Speed := ProjectileSpeeds[aProjType] + KaMRandomS2(0.05, 'TKMProjectiles.AimTarget');

  A := sqr(TargetVector.X) + sqr(TargetVector.Y) - sqr(Speed);
  B := 2 * (TargetPosition.X * TargetVector.X + TargetPosition.Y * TargetVector.Y);
  C := sqr(TargetPosition.X) + sqr(TargetPosition.Y);

  D := sqr(B) - 4 * A * C;

  if (D >= 0) and (A <> 0) then
  begin
    Time1 := (-B + sqrt(D)) / (2 * A);
    Time2 := (-B - sqrt(D)) / (2 * A);

    //Choose smallest positive time
    if (Time1 > 0) and (Time2 > 0) then
      TimeToHit := Math.min(Time1, Time2)
    else
    if (Time1 < 0) and (Time2 < 0) then
      TimeToHit := 0
    else
      TimeToHit := Math.max(Time1, Time2);
  end
  else
    TimeToHit := 0;

  if TimeToHit <> 0 then
  begin
    Jitter := ProjectileJitter[aProjType]
            + KMLength(KMPOINTF_ZERO, TargetVector) * ProjectilePredictJitter[aProjType];

    //Calculate the target position relative to start position (the 0;0)
    Target.X := TargetPosition.X + TargetVector.X*TimeToHit + KaMRandomS2(Jitter, 'TKMProjectiles.AimTarget 2');
    Target.Y := TargetPosition.Y + TargetVector.Y*TimeToHit + KaMRandomS2(Jitter, 'TKMProjectiles.AimTarget 3');

    //We can try and shoot at a target that is moving away,
    //but the arrows can't flight any further than their max_range
    DistanceToHit := GetLength(Target.X, Target.Y);
    DistanceInRange := EnsureRange(DistanceToHit, aMinRange, aMaxRange);
    Target.X := aStart.X + Target.X / DistanceToHit * DistanceInRange;
    Target.Y := aStart.Y + Target.Y / DistanceToHit * DistanceInRange;

    //Calculate the arc, less for shorter flights
    Arc := ((DistanceInRange-aMinRange)/(aMaxRange-aMinRange))*(ProjectileArcs[aProjType, 1] + KaMRandomS2(ProjectileArcs[aProjType, 2], 'TKMProjectiles.AimTarget 4'));

    //Check whether this predicted target will hit a friendly unit
    if gTerrain.TileInMapCoords(Round(Target.X), Round(Target.Y)) then //Arrows may fly off map, UnitsHitTest doesn't like negative coordinates
    begin
      U := gTerrain.UnitsHitTest(Round(Target.X), Round(Target.Y));
      if (U <> nil) and (gHands.CheckAlliance(aOwner.Owner, U.Owner) = atAlly) then
        Target := aTarget.PositionF; //Shoot at the target's current position instead
    end;

    Result := AddItem(aStart, aTarget.PositionF, Target, Speed, Arc, aMaxRange, aProjType, aOwner);

    //Tell the Opponent that he is under attack (when arrows are in the air)
    gHands[aTarget.Owner].AI.UnitAttackNotification(aTarget, aOwner);
  end else
    Result := 0;
end;


function TKMProjectiles.AimTarget(const aStart: TKMPointF; aTarget: TKMHouse; aProjType: TKMProjectileType; aOwner: TKMUnit; aMaxRange,aMinRange: Single): Word;
var
  Speed, Arc: Single;
  DistanceToHit, DistanceInRange: Single;
  Aim, Target: TKMPointF;
begin
  Speed := ProjectileSpeeds[aProjType] + KaMRandomS2(0.05, 'TKMProjectiles.AimTarget 5');

  Aim := KMPointF(aTarget.GetRandomCellWithin);
  Target.X := Aim.X + KaMRandomS2(ProjectileJitterHouse[aProjType], 'TKMProjectiles.AimTarget 6'); //So that arrows were within house area, without attitude to tile corners
  Target.Y := Aim.Y + KaMRandomS2(ProjectileJitterHouse[aProjType], 'TKMProjectiles.AimTarget 7');

  //Calculate the arc, less for shorter flights
  DistanceToHit := GetLength(Target.X, Target.Y);
  DistanceInRange := EnsureRange(DistanceToHit, aMinRange, aMaxRange);
  Arc := (DistanceInRange/DistanceToHit)*(ProjectileArcs[aProjType, 1] + KaMRandomS2(ProjectileArcs[aProjType, 2], 'TKMProjectiles.AimTarget 8'));

  Result := AddItem(aStart, Aim, Target, Speed, Arc, aMaxRange, aProjType, aOwner);
end;


{ Return flight time (archers like to know when they hit target before firing again) }
function TKMProjectiles.AddItem(const aStart,aAim,aEnd: TKMPointF; aSpeed,aArc,aMaxLength: Single; aProjType: TKMProjectileType; aOwner: TKMUnit): Word;
const //TowerRock position is a bit different for reasons said below
  OffsetX: array [TKMProjectileType] of Single = (0.5, 0.5, 0.5, -0.25); //Recruit stands in entrance, Tower middleline is X-0.75
  OffsetY: array [TKMProjectileType] of Single = (0.2, 0.2, 0.2, -0.5); //Add towers height
var
  I: Integer;
begin
  I := -1;
  repeat
    Inc(I);
    if I >= Length(fItems) then
      SetLength(fItems, I+8); //Add new
  until(fItems[I].fSpeed = 0);

  //Fill in basic info
  fItems[I].fType   := aProjType;
  fItems[I].fSpeed  := aSpeed;
  fItems[I].fArc    := aArc;
  fItems[I].fOwner  := aOwner.GetPointer;
  fItems[I].fAim    := aAim;
  //Don't allow projectile to land off map, (we use fTaret for hit tests, FOW, etc.) but on borders is fine
  fItems[I].fTarget.X := EnsureRange(aEnd.X, 0, gTerrain.MapX-0.01);
  fItems[I].fTarget.Y := EnsureRange(aEnd.Y, 0, gTerrain.MapY-0.01);
  fItems[I].fShotFrom := aStart;

  fItems[I].fScreenStart.X := aStart.X + OffsetX[aProjType];
  fItems[I].fScreenStart.Y := gTerrain.FlatToHeight(aStart).Y + OffsetY[aProjType];
  fItems[I].fScreenEnd.X := fItems[I].fTarget.X + 0.5; //projectile hits on Unit's chest height
  fItems[I].fScreenEnd.Y := gTerrain.FlatToHeight(fItems[I].fTarget).Y + 0.5;

  fItems[I].fPosition := 0; //projectile position on its route
  fItems[I].fLength   := KMLength(fItems[I].fScreenStart, fItems[I].fScreenEnd); //route length
  fItems[I].fMaxLength:= aMaxLength;

  if (gMySpectator.FogOfWar.CheckTileRevelation(KMPointRound(aStart).X, KMPointRound(aStart).Y) >= 255) then
    gSoundPlayer.Play(ProjectileLaunchSounds[aProjType], aStart);

  Result := Round(fItems[I].fLength / fItems[I].fSpeed);
end;


//Update all items positions and kill some targets
procedure TKMProjectiles.UpdateState;
const
  HTicks = 6; //The number of ticks before hitting that an arrow will make the hit noise
var
  I: Integer;
  U: TKMUnit;
  H: TKMHouse;
  Damage: Smallint;
begin
  for I := 0 to Length(fItems) - 1 do
    with fItems[I] do
      if fSpeed <> 0 then
      begin
        fPosition := fPosition + fSpeed;

        //Will hit the target in X..X-1 ticks (this ensures it only happens once)
        //Can't use InRange cos it might get called twice due to <= X <= comparison
        if gMySpectator.FogOfWar.CheckRevelation(fTarget) >= 255 then
          if (fLength - HTicks*fSpeed <= fPosition) and (fPosition < fLength - (HTicks - 1) * fSpeed) then
            gSoundPlayer.Play(ProjectileHitSounds[fType], fTarget);

        if fPosition >= fLength then
        begin
          U := gTerrain.UnitsHitTestF(fTarget);
          //Projectile can miss depending on the distance to the unit
          if (U = nil) or ((1 - Math.Min(KMLength(U.PositionF, fTarget), 1)) > KaMRandom('TKMProjectiles.UpdateState')) then
          begin
            case fType of
              ptArrow,
              ptSlingRock,
              ptBolt:      if (U <> nil) and not U.IsDeadOrDying and U.Visible and not (U is TKMUnitAnimal)
                            //Can't hit units past max range because that's unintuitive/confusing to player
                            and (KMLengthSqr(fShotFrom, U.PositionF) <= Sqr(fMaxLength)) then
                            begin
                              Damage := 0;
                              if fType = ptArrow then Damage := gRes.Units[utBowman].Attack;
                              if fType = ptBolt then Damage := gRes.Units[utArbaletman].Attack;
                              if fType = ptSlingRock then Damage := gRes.Units[utSlingshot].Attack;
                              Damage := Round(Damage / Math.max(gRes.Units[U.UnitType].GetDefenceVsProjectiles(fType = ptBolt), 1)); //Max is not needed, but animals have 0 defence
                              if (FRIENDLY_FIRE or (gHands.CheckAlliance(fOwner.Owner, U.Owner)= atEnemy))
                              and (Damage >= KaMRandom(101, 'TKMProjectiles.UpdateState')) then
                                U.HitPointsDecrease(1, fOwner);
                            end
                            else
                            begin
                              H := gHands.HousesHitTest(Round(fTarget.X), Round(fTarget.Y));
                              if (H <> nil)
                              and (FRIENDLY_FIRE or (gHands.CheckAlliance(fOwner.Owner, H.Owner)= atEnemy))
                              then
                                H.AddDamage(1, fOwner);
                            end;
              ptTowerRock: if (U <> nil) and not U.IsDeadOrDying and U.Visible
                            and not (U is TKMUnitAnimal)
                            and (FRIENDLY_FIRE or (gHands.CheckAlliance(fOwner.Owner, U.Owner)= atEnemy)) then
                              U.HitPointsDecrease(U.HitPointsMax, fOwner); //Instant death
            end;
          end;
          RemItem(I);
        end;
      end;
end;


//Test wherever projectile is visible (used by rocks thrown from Towers)
function TKMProjectiles.ProjectileVisible(aIndex: Integer): Boolean;
begin
  if (fItems[aIndex].fType = ptTowerRock)
  and ((fItems[aIndex].fScreenEnd.Y - fItems[aIndex].fScreenStart.Y) < 0) then
    Result := fItems[aIndex].fPosition >= 0.2 //fly behind a Tower
  else
    Result := True;
end;


procedure TKMProjectiles.Paint(aTickLag: Single);
var
  I: Integer;
  MixValue, MixValueMax, TickLagOffset, LaggedPosition: Single;
  MixArc: Single; //mix Arc shape
  P: TKMPointF; //Arrows and bolts send 2 points for head and tail
  PTileBased: TKMPointF;
  Dir: TKMDirection;
begin
  for I := 0 to Length(fItems) - 1 do
    if (fItems[I].fSpeed <> 0) and ProjectileVisible(I) then
    begin
      TickLagOffset := aTickLag*fItems[I].fSpeed;
      LaggedPosition := fItems[I].fPosition - TickLagOffset;
      //If the projectile hasn't appeared yet in lagged time
      if LaggedPosition < 0 then Continue;

      MixValue := EnsureRange(LaggedPosition / fItems[I].fLength, 0.0, 1.0); // 0 >> 1
      MixValueMax := EnsureRange(LaggedPosition / fItems[I].fMaxLength, 0.0, 1.0); // 0 >> 1
      P := KMLerp(fItems[I].fScreenStart, fItems[I].fScreenEnd, MixValue);
      PTileBased := KMLerp(fItems[I].fShotFrom, fItems[I].fTarget, MixValue);
      case fItems[I].fType of
        ptArrow, ptSlingRock, ptBolt:
          begin
            MixArc := sin(MixValue*pi);   // 0 >> 1 >> 0 Parabola
            //Looks better moved up, launches from the bow not feet and lands in target's body
            P.Y := P.Y - fItems[I].fArc * MixArc - 0.4;
            Dir := KMGetDirection(fItems[I].fScreenStart, fItems[I].fScreenEnd);
            gRenderPool.AddProjectile(fItems[I].fType, P, PTileBased, Dir, MixValueMax);
          end;

        ptTowerRock:
          begin
            MixArc := cos(MixValue*pi/2); // 1 >> 0      Half-parabola
            //Looks better moved up, lands on the target's body not at his feet
            P.Y := P.Y - fItems[I].fArc * MixArc - 0.4;
            gRenderPool.AddProjectile(fItems[I].fType, P, PTileBased, dirN, MixValue); //Direction will be ignored
          end;
      end;

      if SHOW_PROJECTILES then
      begin
        gRenderAux.Projectile(fItems[I].fScreenStart.X,
                              fItems[I].fScreenStart.Y,
                              fItems[I].fScreenEnd.X,
                              fItems[I].fScreenEnd.Y);

        gRenderAux.Projectile(fItems[I].fAim.X,
                              fItems[I].fAim.Y,
                              fItems[I].fTarget.X,
                              fItems[I].fTarget.Y);
      end;
    end;
end;


procedure TKMProjectiles.Save(SaveStream: TKMemoryStream);
var
  I, LiveCount: Integer;
begin
  SaveStream.PlaceMarker('Projectiles');

  //Strip dead projectiles
  LiveCount := 0;
  for I := 0 to Length(fItems) - 1 do
    //if fItems[I].fSpeed <> 0 then // This causes desynchronization in replay
      Inc(LiveCount);

  SaveStream.Write(LiveCount);

  for I := 0 to Length(fItems) - 1 do
    //if fItems[I].fSpeed <> 0 then // This causes desynchronization in replay
    begin
      SaveStream.Write(fItems[I].fScreenStart);
      SaveStream.Write(fItems[I].fScreenEnd);
      SaveStream.Write(fItems[I].fAim);
      SaveStream.Write(fItems[I].fTarget);
      SaveStream.Write(fItems[I].fShotFrom);
      SaveStream.Write(fItems[I].fType, SizeOf(TKMProjectileType));
      SaveStream.Write(fItems[I].fOwner.UID); //Store ID
      SaveStream.Write(fItems[I].fSpeed);
      SaveStream.Write(fItems[I].fArc);
      SaveStream.Write(fItems[I].fPosition);
      SaveStream.Write(fItems[I].fLength);
      SaveStream.Write(fItems[I].fMaxLength);
    end;
end;


procedure TKMProjectiles.Load(LoadStream: TKMemoryStream);
var
  I, NewCount: Integer;
begin
  LoadStream.CheckMarker('Projectiles');

  LoadStream.Read(NewCount);
  SetLength(fItems, NewCount);

  for I := 0 to NewCount - 1 do
  begin
    LoadStream.Read(fItems[I].fScreenStart);
    LoadStream.Read(fItems[I].fScreenEnd);
    LoadStream.Read(fItems[I].fAim);
    LoadStream.Read(fItems[I].fTarget);
    LoadStream.Read(fItems[I].fShotFrom);
    LoadStream.Read(fItems[I].fType, SizeOf(TKMProjectileType));
    LoadStream.Read(fItems[I].fOwner, 4);
    LoadStream.Read(fItems[I].fSpeed);
    LoadStream.Read(fItems[I].fArc);
    LoadStream.Read(fItems[I].fPosition);
    LoadStream.Read(fItems[I].fLength);
    LoadStream.Read(fItems[I].fMaxLength);
  end;
end;


procedure TKMProjectiles.SyncLoad;
var
  I: Integer;
begin
  inherited;

  for I := 0 to Length(fItems) - 1 do
    fItems[I].fOwner := gHands.GetUnitByUID(Cardinal(fItems[I].fOwner));
end;


end.
