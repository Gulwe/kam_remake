unit KM_ResExporter;
{$I KaM_Remake.inc}
interface
uses
  SysUtils,
  KM_ResTypes,
  KM_WorkerThread,
  KM_Defaults;


type
  // Resource exporter class
  TKMResExporter = class
  private
    fExportWorker: TKMWorkerThread;

    function GetOrCreateExportWorker: TKMWorkerThread;
  public
    destructor Destroy; override;

    procedure ExportTreeAnim(aOnDone: TProc<String> = nil);
    procedure ExportHouseAnim(aOnDone: TProc<String> = nil);
    procedure ExportUnitAnim(aUnitFrom, aUnitTo: TKMUnitType; aExportUnused: Boolean = False; aOnDone: TProc<String> = nil);
    procedure ExportSpritesToPNG(aRT: TRXType; aOnDone: TProc<String> = nil);
  end;

var
  gResExporter: TKMResExporter;


implementation
uses
  Classes, TypInfo,
  KromUtils,
  KM_Resource, KM_ResSprites, KM_ResUnits, KM_ResHouses, KM_ResMapElements, KM_ResWares, KM_ResTexts,
  KM_Points, KM_CommonTypes;


{ TKMResExporter }
destructor TKMResExporter.Destroy;
begin
  if fExportWorker <> nil then
    //This will ensure all queued work is completed before destruction
    FreeAndNil(fExportWorker);

  inherited;
end;


function TKMResExporter.GetOrCreateExportWorker: TKMWorkerThread;
begin
  if fExportWorker = nil then
    fExportWorker := TKMWorkerThread.Create('ExportWorker');

  Result := fExportWorker;
end;


procedure TKMResExporter.ExportSpritesToPNG(aRT: TRXType; aOnDone: TProc<String> = nil);
begin
  GetOrCreateExportWorker.QueueWork(procedure
  var
    sprites: TKMResSprites;
  begin
    sprites := TKMResSprites.Create(nil, nil, True);
    try
      if sprites.LoadSprites(aRT, False) then
      begin
        sprites[aRT].ExportAll(ExeDir + 'Export' + PathDelim + RXInfo[aRT].FileName + '.rx' + PathDelim);
        sprites.ClearTemp;
      end;
    finally
      sprites.Free;
    end;
  end, aOnDone, 'Export ' + GetEnumName(TypeInfo(TRXType), Integer(aRT)));
end;


//Export Units graphics categorized by Unit and Action
procedure TKMResExporter.ExportUnitAnim(aUnitFrom, aUnitTo: TKMUnitType; aExportUnused: Boolean = False; aOnDone: TProc<String> = nil);
begin

  // Asynchroniously export data
  GetOrCreateExportWorker.QueueWork(procedure
    var
      FullFolder,Folder: string;
      U: TKMUnitType;
      A: TKMUnitActionType;
      Anim: TKMAnimLoop;
      D: TKMDirection;
      R: TKMWareType;
      T: TKMUnitThought;
      i,ci:integer;
      Used:array of Boolean;
      RXData: TRXData;
      SpritePack: TKMSpritePack;
      SList: TStringList;
      FolderCreated: Boolean;
      sprites: TKMResSprites;
      units: TKMResUnits;
      resTexts: TKMTextLibraryMulti;
    begin

    sprites := TKMResSprites.Create(nil, nil, True);
    sprites.LoadSprites(rxUnits, False); //BMP can't show alpha shadows anyways
    SpritePack := sprites[rxUnits];
    RXData := SpritePack.RXData;

    units := TKMResUnits.Create;
    resTexts := TKMTextLibraryMulti.Create;
    resTexts.LoadLocale(ExeDir + 'data' + PathDelim + 'text' + PathDelim + 'text.%s.libx');
    resTexts.ForceDefaultLocale := True;

    Folder := ExeDir + 'Export' + PathDelim + 'UnitAnim' + PathDelim;
    ForceDirectories(Folder);

    SList := TStringList.Create;
    try
      for U := aUnitFrom to aUnitTo do
        for A := Low(TKMUnitActionType) to High(TKMUnitActionType) do
        begin
          FolderCreated := False;
          for D := dirN to dirNW do
            if units[U].UnitAnim[A,D].Step[1] <> -1 then
              for i := 1 to units[U].UnitAnim[A, D].Count do
              begin
                ci := units[U].UnitAnim[A,D].Step[i] + 1;
                if ci <> 0 then
                begin
                  if not FolderCreated then
                  begin
                    //Use default locale for Unit GUIName, as translation could be not good for file system
                    FullFolder := Folder + resTexts.DefaultTexts[units[U].GUITextID] + PathDelim + UNIT_ACT_STR[A] + PathDelim;
                    ForceDirectories(FullFolder);
                    FolderCreated := True;
                  end;
                  SpritePack.ExportFullImageData(FullFolder, ci, SList);
                  // Stop export if async thread is terminated by application
                  if TThread.CheckTerminated then
                    Exit;
                end;
              end;
        end;

      SetLength(Used, Length(RXData.Size));

      //Exclude actions
      for U := Low(TKMUnitType) to High(TKMUnitType) do
        for A := Low(TKMUnitActionType) to High(TKMUnitActionType) do
          for D := dirN to dirNW do
            if units[U].UnitAnim[A,D].Step[1] <> -1 then
            for i := 1 to units[U].UnitAnim[A,D].Count do
            begin
              ci := units[U].UnitAnim[A,D].Step[i]+1;
              Used[ci] := ci <> 0;
            end;

      if utSerf in [aUnitFrom..aUnitTo] then
        //serfs carrying stuff
        for R := WARE_MIN to WARE_MAX do
        begin
          FolderCreated := False;
          for D := dirN to dirNW do
          begin
            Anim := units.SerfCarry[R, D];
            for i := 1 to Anim.Count do
            begin
              ci := Anim.Step[i]+1;
              if ci <> 0 then
              begin
                Used[ci] := True;
                if utSerf in [aUnitFrom..aUnitTo] then
                begin
                  if not FolderCreated then
                  begin
                    //Use default locale for Unit GUIName, as translation could be not good for file system (like russian '����������/�������' with slash in it)
                    FullFolder := Folder + resTexts.DefaultTexts[units[utSerf].GUITextID] + PathDelim + 'Delivery' + PathDelim
                                    + GetEnumName(TypeInfo(TKMWareType), Integer(R)) + PathDelim;
                    ForceDirectories(FullFolder);
                    FolderCreated := True;
                  end;
                  SpritePack.ExportFullImageData(FullFolder, ci, SList);
                  // Stop export if async thread is terminated by application
                  if TThread.CheckTerminated then
                    Exit;
                end;
              end;
            end;
          end;
        end;

      FullFolder := Folder + 'Thoughts' + PathDelim;
      ForceDirectories(FullFolder);
      for T := thEat to High(TKMUnitThought) do
        for I := THOUGHT_BOUNDS[T,1] to  THOUGHT_BOUNDS[T,2] do
        begin
          SpritePack.ExportFullImageData(FullFolder, I+1, SList);
          Used[I+1] := True;
        end;

      if not aExportUnused then Exit;

      FullFolder := Folder + '_Unused' + PathDelim;
      ForceDirectories(FullFolder);

      for ci := 1 to length(Used)-1 do
        if not Used[ci] then
        begin
          SpritePack.ExportFullImageData(FullFolder, ci, SList);
          // Stop export if async thread is terminated by application
          if TThread.CheckTerminated then
            Exit;
        end;
    finally
      sprites.ClearTemp;
      sprites.Free;
      units.Free;
      resTexts.Free;
      SList.Free;
    end;
  end, aOnDone, 'Export units anim');
end;


//Export Houses graphics categorized by House and Action
procedure TKMResExporter.ExportHouseAnim(aOnDone: TProc<String> = nil);
begin

  // Asynchroniously export data
  GetOrCreateExportWorker.QueueWork(procedure
  var
    FullFolder,Folder: string;
    houses: TKMResHouses;
    ID: TKMHouseType;
    Ac: TKMHouseActionType;
    Q, Beast, I, K, ci: Integer;
    SpritePack: TKMSpritePack;
    SList: TStringList;

    sprites: TKMResSprites;
    resTexts: TKMTextLibraryMulti;
  begin
    sprites := TKMResSprites.Create(nil, nil, true);
    sprites.LoadSprites(rxHouses, False); //BMP can't show alpha shadows anyways
    SpritePack := sprites[rxHouses];

    Folder := ExeDir + 'Export' + PathDelim + 'HouseAnim' + PathDelim;
    ForceDirectories(Folder);

    SList := TStringList.Create;
    houses := TKMResHouses.Create;

    resTexts := TKMTextLibraryMulti.Create;
    resTexts.LoadLocale(ExeDir + 'data' + PathDelim + 'text' + PathDelim + 'text.%s.libx');
    resTexts.ForceDefaultLocale := True;
    try
      for ID := HOUSE_MIN to HOUSE_MAX do
        for Ac := haWork1 to haFlag3 do
          for K := 1 to houses[ID].Anim[Ac].Count do
          begin                                      //HouseNameTextID    resTexts.DefaultTexts
            FullFolder := Folder + resTexts.DefaultTexts[houses[ID].HouseNameTextID] + PathDelim + HOUSE_ACTION_STR[Ac] + PathDelim;
            ForceDirectories(FullFolder);
            ci := houses[ID].Anim[Ac].Step[K] + 1;
            if ci <> 0 then
              SpritePack.ExportFullImageData(FullFolder, ci, SList);
            // Stop export if async thread is terminated by application
            if TThread.CheckTerminated then
              Exit;
          end;

      for Q := 1 to 2 do
      begin
        if Q = 1 then
          ID := htSwine
        else
          ID := htStables;
        ForceDirectories(Folder + '_' + resTexts.DefaultTexts[houses[ID].HouseNameTextID] + PathDelim);
        for Beast := 1 to 5 do
          for I := 1 to 3 do
            for K := 1 to houses.BeastAnim[ID,Beast,I].Count do
            begin
              FullFolder := Folder + resTexts.DefaultTexts[houses[ID].HouseNameTextID] + PathDelim + 'Beast' + PathDelim + int2fix(Beast,2) + PathDelim;
              ForceDirectories(FullFolder);
              ci := houses.BeastAnim[ID,Beast,I].Step[K]+1;
              if ci <> 0 then
                SpritePack.ExportFullImageData(FullFolder, ci, SList);
              // Stop export if async thread is terminated by application
              if TThread.CheckTerminated then
                Exit;
            end;
      end;
    finally
      houses.Free;
      SList.Free;
      sprites.ClearTemp;
      sprites.Free;
    end;
  end, aOnDone, 'Export house anim');
end;


//Export Trees graphics categorized by ID
procedure TKMResExporter.ExportTreeAnim(aOnDone: TProc<String> = nil);
begin
  // Asynchroniously export data
  GetOrCreateExportWorker.QueueWork(procedure
  var
    FullFolder, Folder: string;
    I, K: Integer;

    sprites: TKMResSprites;
    SpriteID: Integer;
    SpritePack: TKMSpritePack;
    SList: TStringList;
  begin
    sprites := TKMResSprites.Create(nil, nil, True);
    sprites.LoadSprites(rxTrees, False);
    SpritePack := sprites[rxTrees];

    Folder := ExeDir + 'Export' + PathDelim + 'TreeAnim' + PathDelim;
    ForceDirectories(Folder);

    SList := TStringList.Create;

    try
      for I := 0 to gRes.MapElements.Count - 1 do
      if (gMapElements[I].Anim.Count > 0) and (gMapElements[I].Anim.Step[1] > 0) then
      begin
        for K := 1 to gMapElements[I].Anim.Count do
        begin
          SpriteID := gMapElements[I].Anim.Step[K] + 1;
          if SpriteID <> 0 then
          begin
            if gMapElements[I].Anim.Count > 1 then
            begin
              FullFolder := Folder + IntToStr(I) + PathDelim;
              ForceDirectories(FullFolder);
            end else
              FullFolder := Folder;
            SpritePack.ExportFullImageData(FullFolder, SpriteID, SList);
            // Stop export if async thread is terminated by application
            if TThread.CheckTerminated then
              Exit;
          end;
        end;
      end;
    finally
      sprites.ClearTemp;
      sprites.Free;
      SList.Free;
    end;
  end, aOnDone, 'Export tree anim');
end;

end.
