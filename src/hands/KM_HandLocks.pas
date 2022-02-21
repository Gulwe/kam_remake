unit KM_HandLocks;
{$I KaM_Remake.inc}
interface
uses
  KM_ResHouses, KM_ResWares,
  KM_CommonClasses, KM_Defaults,
  KM_ResTypes, KM_HandTypes;


type
  TKMBoolHouseType = array [TKMHouseType] of Boolean;

  // Permissions to build, trade and train
  TKMHandLocks = class
  private
    fHouseUnlocked: array [TKMHouseType] of Boolean; //If building requirements performed
    fUnitBlocked: array [TKMUnitType] of Boolean;   //Allowance derived from mission script

    fHandHouseLock: array [TKMHouseType] of TKMHandHouseLock;
    procedure UpdateReqDone(aType: TKMHouseType);

    function GetHouseBlocked(aHouseType: TKMHouseType): Boolean;
    function GetHouseGranted(aHouseType: TKMHouseType): Boolean;
    function GetHandHouseLock(aHouseType: TKMHouseType): TKMHandHouseLock;
    procedure SetHandHouseLock(aHouseType: TKMHouseType; const aValue: TKMHandHouseLock);
  public
    AllowToTrade: array [WARE_MIN..WARE_MAX] of Boolean; //Allowance derived from mission script
    constructor Create;

    property HouseBlocked[aHouseType: TKMHouseType]: Boolean read GetHouseBlocked;
    property HouseGranted[aHouseType: TKMHouseType]: Boolean read GetHouseGranted;
    property HouseLock[aHouseType: TKMHouseType]: TKMHandHouseLock read GetHandHouseLock write SetHandHouseLock;

    procedure HouseCreated(aType: TKMHouseType);
    function HouseCanBuild(aType: TKMHouseType): Boolean;

    procedure SetUnitBlocked(aIsBlocked: Boolean; aUnitType: TKMUnitType; aInTownHall: Boolean = False);
    function GetUnitBlocked(aUnitType: TKMUnitType; aInTownHall: Boolean = False): Boolean;

    procedure Save(SaveStream: TKMemoryStream);
    procedure Load(LoadStream: TKMemoryStream);
  end;


implementation
uses
  KM_Resource;


{ TKMHandLocks }
constructor TKMHandLocks.Create;
var
  W: TKMWareType;
  HT: TKMHouseType;
begin
  inherited;

  for W := WARE_MIN to WARE_MAX do
    AllowToTrade[W] := True;

  //Release Store at the start of the game by default
  fHouseUnlocked[htStore] := True;

  for HT := Low(TKMHouseType) to High(TKMHouseType) do
    fHandHouseLock[HT] := hlDefault;
end;


procedure TKMHandLocks.UpdateReqDone(aType: TKMHouseType);
var
  H: TKMHouseType;
begin
  for H := HOUSE_MIN to HOUSE_MAX do
    if gResHouses[H].ReleasedBy = aType then
      fHouseUnlocked[H] := True;
end;


// New house, either built by player or created by mission script
procedure TKMHandLocks.HouseCreated(aType: TKMHouseType);
begin
  UpdateReqDone(aType);
end;


// Get effective permission
function TKMHandLocks.HouseCanBuild(aType: TKMHouseType): Boolean;
begin
  Result := False;
  case fHandHouseLock[aType] of
    hlDefault: Result := fHouseUnlocked[aType];
    hlBlocked: Result := False;
    hlGranted: Result := True;
  end;
end;


function TKMHandLocks.GetHouseBlocked(aHouseType: TKMHouseType): Boolean;
begin
  Result := fHandHouseLock[aHouseType] = hlBlocked;
end;


function TKMHandLocks.GetHouseGranted(aHouseType: TKMHouseType): Boolean;
begin
  Result := fHandHouseLock[aHouseType] = hlGranted;
end;


function TKMHandLocks.GetHandHouseLock(aHouseType: TKMHouseType): TKMHandHouseLock;
begin
  Result := fHandHouseLock[aHouseType];
end;


procedure TKMHandLocks.SetHandHouseLock(aHouseType: TKMHouseType; const aValue: TKMHandHouseLock);
begin
  Assert(aValue <> hlNone, 'Can''t set hlNone Hand House Lock');
  fHandHouseLock[aHouseType] := aValue;
end;


//procedure TKMHandLocks.SetHouseBlocked(aHouseType: TKMHouseType; const aValue: Boolean);
//begin
//  if aValue then
//    fPlayerHouseLock[aHouseType] := phlBlocked
//  else
//    fPlayerHouseLock[aHouseType] := phlDefault;
//end;
//
//
//procedure TKMHandLocks.SetHouseGranted(aHouseType: TKMHouseType; const aValue: Boolean);
//begin
//  fPlayerHouseLock[aHouseType] := phlGranted;
//end;


function TKMHandLocks.GetUnitBlocked(aUnitType: TKMUnitType; aInTownHall: Boolean = False): Boolean;
begin
  Result := fUnitBlocked[aUnitType];
end;


procedure TKMHandLocks.SetUnitBlocked(aIsBlocked: Boolean; aUnitType: TKMUnitType; aInTownHall: Boolean = False);
begin
  fUnitBlocked[aUnitType] := aIsBlocked;
end;


procedure TKMHandLocks.Save(SaveStream: TKMemoryStream);
begin
  SaveStream.PlaceMarker('HandLocks');
  SaveStream.Write(fHandHouseLock, SizeOf(fHandHouseLock));
  SaveStream.Write(fUnitBlocked, SizeOf(fUnitBlocked));
  SaveStream.Write(AllowToTrade, SizeOf(AllowToTrade));
  SaveStream.Write(fHouseUnlocked, SizeOf(fHouseUnlocked));
end;


procedure TKMHandLocks.Load(LoadStream: TKMemoryStream);
begin
  LoadStream.CheckMarker('HandLocks');
  LoadStream.Read(fHandHouseLock, SizeOf(fHandHouseLock));
  LoadStream.Read(fUnitBlocked, SizeOf(fUnitBlocked));
  LoadStream.Read(AllowToTrade, SizeOf(AllowToTrade));
  LoadStream.Read(fHouseUnlocked, SizeOf(fHouseUnlocked));
end;


end.
