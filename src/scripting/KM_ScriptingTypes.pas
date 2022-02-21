unit KM_ScriptingTypes;
{$I KaM_Remake.inc}
interface
uses
  KM_Defaults, KM_AITypes, KM_Points;

type
  TKMScriptEventType = (
    evtBeacon,
    evtFieldBuilt,
    evtHouseAfterDestroyed,
    evtHouseAfterDestroyedEx,
    evtHouseBuilt,
    evtHousePlanDigged,
    evtHousePlanPlaced,
    evtHousePlanPlacedEx,
    evtHousePlanRemoved,
    evtHousePlanRemovedEx,
    evtHouseDamaged,
    evtHouseDestroyed,
    evtHouseRepaired,
    evtHouseWareCountChanged,
    evtGameSpeedChanged,
    evtGroupHungry,
    evtGroupOrderAttackHouse,
    evtGroupOrderAttackUnit,
    evtGroupBeforeOrderSplit,
    evtGroupOrderMove,
    evtGroupOrderLink,
    evtGroupOrderSplit,
    evtMarketTrade,
    evtMarketTradeEx,
    evtMissionStart,
    evtPeacetimeEnd,
    evtPlanRoadDigged,
    evtPlanRoadPlaced,
    evtPlanRoadRemoved,
    evtPlanFieldPlaced,
    evtPlanFieldRemoved,
    evtPlanWinefieldDigged,
    evtPlanWinefieldPlaced,
    evtPlanWinefieldRemoved,
    evtPlayerDefeated,
    evtPlayerVictory,
    evtRoadBuilt,
    evtTick,
    evtUnitAfterDied,
    evtUnitAfterDiedEx,
    evtUnitDied,
    evtUnitTrained,
    evtUnitWounded,
    evtUnitAttacked,
    evtWareProduced,
    evtWarriorEquipped,
    evtWarriorWalked,
    evtWinefieldBuilt
  );


  TKMScriptFileInfo = record
    FullFilePath: UnicodeString;
    FileName: UnicodeString;
    FileText: AnsiString;
  end;

  // Script error message
  TKMScriptErrorMessage = record
    GameMessage: UnicodeString; // Shown in game as Message box
    LogMessage: UnicodeString;  // Printed to Log (could be more detailed)
  end;

  TKMScriptErrorType = (seInvalidParameter, seException, sePreprocessorError, seCompileError, seCompileWarning, seCompileHint, seLog);

  TKMScriptErrorEvent = procedure (aType: TKMScriptErrorType; const aErrorString: UnicodeString; const aDetailedErrorString: UnicodeString = '') of object;

  // Set exported to PascalScript record type as packed.
  // PascalScript use packed records alignment by default,
  // thus without it in Delphi we could get garbage in the fields if they are not aligned same way as in PS
  TKMDefencePositionInfo = packed record
    UID: Integer;
    X, Y: Integer;
    Radius: Integer;
    GroupID: Integer;
    Dir: TKMDirection;
    GroupType: TKMGroupType;
    PositionType: TKMAIDefencePosType;
    function ToStr: string;
  end;

  TKMAIAttackInfo = packed record
    UID: Integer;
    AttackType: TKMAIAttackType;
    HasOccured: Boolean;
    Delay: Cardinal;
    TotalMen: Integer;
    MeleeGroupCount: Integer;
    AntiHorseGroupCount: Integer;
    RangedGroupCount: Integer;
    MountedGroupCount: Integer;
    RandomGroups: Boolean;
    Target: TKMAIAttackTarget;
    CustomPosition: TKMPoint;
    function ToStr: string;
  end;

const
  SCRIPT_LOG_EXT = '.log.txt';


implementation
uses
  SysUtils, TypInfo;


{ TKMDefencePositionInfo }
function TKMDefencePositionInfo.ToStr: string;
begin
  Result := Format('[%d:%d R=%d %s %s %s]',
                   [X, Y, Radius,
                    GetEnumName(TypeInfo(TKMDirection), Integer(Dir)),
                    GetEnumName(TypeInfo(TKMGroupType), Integer(GroupType)),
                    GetEnumName(TypeInfo(TKMAIDefencePosType), Integer(PositionType))]);
end;


{ TKMAIAttackInfo }
function TKMAIAttackInfo.ToStr: string;
begin
  Result := Format('[%d: Type=%s Occured=%s, Delay=%d, TotalMen=%d, GroupsCount: %d, %d, %d, %d, RandomGroups=%s, Target=%s, Pos=%s]',
                   [UID,
                    GetEnumName(TypeInfo(TKMAIAttackType), Integer(AttackType)),
                    BoolToStr(HasOccured), Delay, TotalMen,
                    MeleeGroupCount, AntiHorseGroupCount, RangedGroupCount, MountedGroupCount,
                    BoolToStr(RandomGroups),
                    GetEnumName(TypeInfo(TKMAIAttackTarget), Integer(Target)),
                    CustomPosition.ToString]);
end;


end.

