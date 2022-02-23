unit KM_HouseWatchTower;
{$I KaM_Remake.inc}
interface
uses
  KM_Houses,

  KM_CommonClasses, KM_Defaults, 
  KM_ResTypes;

const
  WT_MAX_STONE_VALUE = 10;

type
  TKMHouseTower = class(TKMHouse)
  private
    fStoneCnt: Word;
    fStoneMaxCnt: Word;

    procedure SetStoneCnt(aValue: Word); overload;
    procedure SetStoneCnt(aValue: Word; aLimitMaxStoneCnt: Boolean); overload;
    procedure UpdateDemands;

    procedure SetStoneMaxCnt(aValue: Word);
    

    function GetStoneDeliveryCnt: Word;
    procedure SetStoneDeliveryCnt(aCount: Word);

    property StoneDeliveryCnt: Word read GetStoneDeliveryCnt write SetStoneDeliveryCnt;
  protected
   // function GetFlagPointTexId: Word; override;
    procedure AddDemandsOnActivate(aWasBuilt: Boolean); override;
    function GetResIn(aI: Byte): Word; override;

    procedure SetResIn(aI: Byte; aValue: Word); override;
  public
    constructor Create(aUID: Integer; aHouseType: TKMHouseType; PosX, PosY: Integer; aOwner: TKMHandID; aBuildState: TKMHouseBuildState);
    constructor Load(LoadStream: TKMemoryStream); override;
    procedure Save(SaveStream: TKMemoryStream); override;

    procedure Paint; override; //Render debug radius overlay

    procedure DecResourceDelivery(aWare: TKMWareType); override;

    property StoneCnt: Word read fStoneCnt write SetStoneCnt;
    property StoneMaxCnt: Word read fStoneMaxCnt write SetStoneMaxCnt;

    function ShouldAbandonDeliveryTo(aWareType: TKMWareType): Boolean; override;


 //   function CanEquip(aUnitType: TKMUnitType): Boolean;

    procedure PostLoadMission; override;

    procedure ResAddToIn(aWare: TKMWareType; aCount: Integer = 1; aFromScript: Boolean = False); override;
    procedure ResTakeFromIn(aWare: TKMWareType; aCount: Word = 1; aFromScript: Boolean = False); override;
    procedure ResTakeFromOut(aWare: TKMWareType; aCount: Word = 1; aFromScript: Boolean = False); override;
    function CheckResIn(aWare: TKMWareType): Word; override;
    function ResCanAddToIn(aRes: TKMWareType): Boolean; override;
  end;


implementation
uses
  Math,
  KM_Hand, KM_HandsCollection, KM_HandLogistics,
  KM_UnitWarrior, KM_ResUnits, KM_ScriptingEvents,  
  KM_RenderPool, 
  KromUtils,
  KM_GameParams,
  KM_InterfaceGame;

{TKMHouseTower}
constructor TKMHouseTower.Create(aUID: Integer; aHouseType: TKMHouseType; PosX, PosY: Integer; aOwner: TKMHandID; aBuildState: TKMHouseBuildState);
var
  M: Integer;
begin
  inherited;
  
  M := MAX_WARES_IN_HOUSE;
  fStoneCnt := 0;
  fStoneMaxCnt := M;
end;


constructor TKMHouseTower.Load(LoadStream: TKMemoryStream);
begin
  inherited;
  LoadStream.CheckMarker('WatchTower');
  LoadStream.Read(fStoneCnt);
  LoadStream.Read(fStoneMaxCnt);
end;


procedure TKMHouseTower.Save(SaveStream: TKMemoryStream);
begin
  inherited;

  SaveStream.PlaceMarker('WatchTower');
  SaveStream.Write(fStoneCnt);
  SaveStream.Write(fStoneMaxCnt);
end;


procedure TKMHouseTower.SetStoneCnt(aValue: Word);
begin
  SetStoneCnt(aValue, True);
end;


procedure TKMHouseTower.SetStoneCnt(aValue: Word; aLimitMaxStoneCnt: Boolean);
var
  oldValue: Integer;
begin
  oldValue := fStoneCnt;

  fStoneCnt := EnsureRange(aValue, 0, IfThen(aLimitMaxStoneCnt, fStoneMaxCnt, High(Word)));

  if oldValue <> fStoneCnt then
    gScriptEvents.ProcHouseWareCountChanged(Self, wtStone, fStoneCnt, fStoneCnt - oldValue);
end;


procedure TKMHouseTower.DecResourceDelivery(aWare: TKMWareType);
begin
  StoneDeliveryCnt := StoneDeliveryCnt - 1;
end;


procedure TKMHouseTower.SetStoneMaxCnt(aValue: Word);
begin
  fStoneMaxCnt := EnsureRange(aValue, 0, WT_MAX_STONE_VALUE);
  UpdateDemands;
end;

procedure TKMHouseTower.PostLoadMission;
begin
  UpdateDemands;
end;


procedure TKMHouseTower.AddDemandsOnActivate(aWasBuilt: Boolean);
begin
  if aWasBuilt then
    UpdateDemands;
end;


function TKMHouseTower.GetResIn(aI: Byte): Word;
begin
  Result := 0;
  if aI = 1 then //Resources are 1 based
    Result := fStoneCnt;
end;


procedure TKMHouseTower.SetResIn(aI: Byte; aValue: Word);
begin
  if aI = 1 then
    StoneCnt := aValue;
end;


function TKMHouseTower.ShouldAbandonDeliveryTo(aWareType: TKMWareType): Boolean;
begin
  Result := inherited or (aWareType <> wtStone);
  if not Result then
    Result := StoneCnt + gHands[Owner].Deliveries.Queue.GetDeliveriesToHouseCnt(Self, wtStone) > StoneMaxCnt;
end;


procedure TKMHouseTower.ResAddToIn(aWare: TKMWareType; aCount: Integer = 1; aFromScript: Boolean = False);
var
  ordersRemoved : Integer;
begin
  Assert(aWare = wtStone, 'Invalid resource added to TownHall');

  // Allow to enlarge StoneMaxCnt from script (either from .dat or from .script)
  if aFromScript and (fStoneMaxCnt < fStoneCnt + aCount) then
    SetStoneMaxCnt(fStoneCnt + aCount);

  SetStoneCnt(fStoneCnt + aCount, False);

  if aFromScript then
  begin
    StoneDeliveryCnt := StoneDeliveryCnt + aCount;
    ordersRemoved := gHands[Owner].Deliveries.Queue.TryRemoveDemand(Self, aWare, aCount);
    StoneDeliveryCnt := StoneDeliveryCnt - ordersRemoved;
  end;

  UpdateDemands;
end;


function TKMHouseTower.GetStoneDeliveryCnt: Word;
begin
  Result := ResDeliveryCnt[1];
end;


procedure TKMHouseTower.SetStoneDeliveryCnt(aCount: Word);
begin
  ResDeliveryCnt[1] := aCount;
end;


procedure TKMHouseTower.UpdateDemands;
const
  MAX_Stone_DEMANDS = 10; //Limit max number of demands by townhall to not to overfill demands list
var
  StoneToOrder, ordersRemoved: Integer;
begin
  StoneToOrder := Min(MAX_Stone_DEMANDS - (StoneDeliveryCnt - fStoneCnt), fStoneMaxCnt - StoneDeliveryCnt);
  if StoneToOrder > 0 then
  begin
    gHands[Owner].Deliveries.Queue.AddDemand(Self, nil, wtStone, StoneToOrder, dtOnce, diNorm);
    StoneDeliveryCnt := StoneDeliveryCnt + StoneToOrder;
  end
  else
  if StoneToOrder < 0 then
  begin
    ordersRemoved := gHands[Owner].Deliveries.Queue.TryRemoveDemand(Self, wtStone, -StoneToOrder);
    StoneDeliveryCnt := StoneDeliveryCnt - ordersRemoved;
  end;
end;


procedure TKMHouseTower.ResTakeFromIn(aWare: TKMWareType; aCount: Word = 1; aFromScript: Boolean = False);
begin
  Assert(aWare = wtStone, 'Invalid resource taken from TownHall');
  aCount := EnsureRange(aCount, 0, fStoneCnt);
  if aFromScript then
    gHands[Owner].Stats.WareConsumed(aWare, aCount);

  SetStoneCnt(fStoneCnt - aCount, False);
  UpdateDemands;
end;


procedure TKMHouseTower.ResTakeFromOut(aWare: TKMWareType; aCount: Word = 1; aFromScript: Boolean = False);
begin
  Assert(aWare = wtStone, 'Invalid resource taken from TownHall');
  if aFromScript then
  begin
    aCount := EnsureRange(aCount, 0, fStoneCnt);
    if aCount > 0 then
    begin
      gHands[Owner].Stats.WareConsumed(aWare, aCount);
      gHands[Owner].Deliveries.Queue.RemOffer(Self, aWare, aCount);
    end;
  end;
  Assert(aCount <= fStoneCnt);
  SetStoneCnt(fStoneCnt - aCount, False);

  //Keep track of how many are ordered
  StoneDeliveryCnt := StoneDeliveryCnt - aCount;

  UpdateDemands;
end;


function TKMHouseTower.CheckResIn(aWare: TKMWareType): Word;
begin
  Result := 0; //Including Wood/stone in building stage
  if aWare = wtStone then
    Result := fStoneCnt;
end;


function TKMHouseTower.ResCanAddToIn(aRes: TKMWareType): Boolean;
begin
  Result := (aRes = wtStone) and (fStoneCnt < fStoneMaxCnt);
end;


 procedure TKMHouseTower.Paint;
var
  fillColor, lineColor: Cardinal;
begin
  inherited;

  if SHOW_ATTACK_RADIUS or (mlTowersAttackRadius in gGameParams.VisibleLayers) then
  begin
    fillColor := $40FFFFFF;
    lineColor := icWhite;
    if gMySpectator.Selected = Self then
    begin
      fillColor := icRed and fillColor;
      lineColor := icCyan;
    end;

    gRenderPool.RenderDebug.RenderTiledArea(Position, RANGE_WATCHTOWER_MIN, RANGE_WATCHTOWER_MAX, GetLength, fillColor, lineColor);
  end;
end;  


end.
