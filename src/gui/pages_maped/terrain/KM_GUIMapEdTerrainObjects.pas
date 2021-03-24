unit KM_GUIMapEdTerrainObjects;
{$I KaM_Remake.inc}
interface
uses
  {$IFDEF MSWindows} Windows, {$ENDIF}
  {$IFDEF Unix} LCLIntf, LCLType, {$ENDIF}
  Classes, Math, SysUtils,
  KM_InterfaceDefaults,
  KM_Controls, KM_Defaults, KM_Pics, KM_GameCursor, KM_Points, KM_CommonTypes;

type
  TKMTerrainObjectAttribute = (toaBlockDiagonal, toaBlockAllExceptBuild, toaBlockBuild, toaChoppableTree);

  TKMTerrainObjectAttributeSet = set of TKMTerrainObjectAttribute;

  TKMMapEdTerrainObjects = class(TKMMapEdSubMenuPage)
  private
    fHideAllPages: TEvent;
    //Objects in MapElem are placed sparsely, so we need to compact them
    //to use in MapEd palette
    fLastObjectIndex: Integer;
    fCountCompact: Integer;
    fCompactToMapElem: array [Byte] of Byte; //Pointers to valid MapElem's
    fMapElemToCompact: array [Byte] of Byte; //Pointers of valid MapElem's back to map objects. (reverse lookup to one above) 256 is no object.

    fObjPaletteTableSize: TKMPoint;
    fObjPaletteAttr: array of TKMTerrainObjectAttributeSet;

    function GetObjPaletteTableHeight: Integer;
    function GetObjPaletteTableWidth: Integer;

    procedure UpdatePaletteButton(aBtnID: Integer);
    function UpdateObjAttributesAndDesc(aBtn: TKMButtonFlat; aObjID: Integer): TKMTerrainObjectAttributeSet;
    procedure CompactMapElements;
    procedure ObjectsUpdate(aObjIndex: Integer);
    procedure UpdateObjectsScrollPosToIndex(aObjIndex: Integer);
    procedure ObjectsChange(Sender: TObject);
    procedure ObjectsRefresh(Sender: TObject);

    procedure ObjectsPalette_Refresh(Sender: TObject);
    procedure ObjPalette_UpdateControlsPosition;
    procedure ObjectsPalette_OnShow(Sender: TObject; aVisible: Boolean);
    procedure ObjPalette_ClickShift(Sender: TObject; Shift: TShiftState);

    procedure ObjectsPaletteButton_Click(Sender: TObject);
    procedure ObjectsPaletteClose_Click(Sender: TObject);
  protected
    Panel_Objects: TKMPanel;
      ObjectErase: TKMButtonFlat;
      ObjectBlock: TKMButtonFlat;
      ObjectsPalette_Button: TKMButtonFlat;
      ObjectsTable: array [0..8] of TKMButtonFlat;
      ObjectsScroll: TKMScrollBar;
    PopUp_ObjectsPalette: TKMPopUpMenu;
      Bevel_ObjectsPalette: TKMBevel;
      Image_ObjectsPalette: TKMImage;
      Label_ObjectsPalette: TKMLabel;
      Button_ClosePalette: TKMButton;
      Button_ObjPaletteErase: TKMButtonFlat;
      Button_ObjPaletteBlock: TKMButtonFlat;
      ObjectsPaletteTable: array of TKMButtonFlat;
      Image_ObjectAttributes: array[0..2] of array of TKMImage;

      //Objects brush
      ForestDensity,ForestAge,BrushSize: TKMTrackBar;
      ObjectTypeSet:array [0..9] of  TKMButtonFlat;
      BrushCircle,BrushSquare: TKMButtonFlat;
      CleanBrush: TKMButtonFlat;

      Scroll_ObjectsPalette: TKMScrollBar;
  public
    constructor Create(aParent: TKMPanel; aHideAllPages: TEvent);

    procedure KeyDown(Key: Word; Shift: TShiftState; var aHandled: Boolean);
    procedure KeyUp(Key: Word; Shift: TShiftState; var aHandled: Boolean);

    procedure Show;
    function Visible: Boolean; override;
    procedure Hide;
    procedure Resize;
    procedure Cancel_Clicked(var aHandled: Boolean);
    procedure UpdateState;
  end;


implementation
uses
  KM_Resource, KM_ResFonts, KM_ResMapElements, KM_ResTexts, KM_ResKeys, KM_Terrain,
  KM_HandsCollection, KM_RenderUI, KM_InterfaceGame, KM_Utils,
  KM_ResTypes;

const
  OBJECTS_PALETTE_MAX_COLS_CNT = 17;
  OBJ_CELL_W = 68;
  OBJ_CELL_H = 84;

  OBJ_CELL_PALETTE_W = 68;
  OBJ_CELL_PALETTE_H = 84;

  OBJ_NONE_TAG = -100;
  OBJ_BLOCK_TAG = -200;
  //Objects brush bins
  BTN_BRUSH_SIZE = 36;


{ TKMMapEdTerrainObjects }
constructor TKMMapEdTerrainObjects.Create(aParent: TKMPanel; aHideAllPages: TEvent);
var
  I, J: Integer;
//  TOA: TKMTerrainObjectAttribute;
  //For brushes
  RxIndex,K:Integer;
  ObjectsHint:String;
begin
  inherited Create;

  fHideAllPages := aHideAllPages;
  fLastObjectIndex := -1;

  CompactMapElements;

  Panel_Objects := TKMScrollPanel.Create(aParent, 0, 28, aParent.Width, aParent.Height - 40, [saVertical], bsMenu, ssCommon);
  Panel_Objects.AnchorsStretch;
  with TKMLabel.Create(Panel_Objects, 0, TERRAIN_PAGE_TITLE_Y, Panel_Objects.Width, 0, gResTexts[TX_MAPED_OBJECTS], fntOutline, taCenter) do
    Anchors := [anLeft, anTop, anRight];
  ObjectsScroll := TKMScrollBar.Create(Panel_Objects, 9, 295, Panel_Objects.Width - 9, 20, saHorizontal, bsGame);
  ObjectsScroll.Anchors := [anLeft, anTop, anRight];
  ObjectsScroll.MinValue := 0;
  ObjectsScroll.MaxValue := (fCountCompact - 1) div 3 - 2;
  ObjectsScroll.Position := 0;
  ObjectsScroll.OnChange := ObjectsRefresh;
  for I := 0 to 2 do
    for J := 0 to 2 do
    begin
      ObjectsTable[I*3+J] := TKMButtonFlat.Create(Panel_Objects, 9 + I*(OBJ_CELL_W + 1), 40 + J*(OBJ_CELL_H + 1),
                                                  OBJ_CELL_W, OBJ_CELL_H, 1, rxTrees); //RXid=1  // 1 2
      ObjectsTable[I*3+J].CapOffsetY := 15;
      ObjectsTable[I*3+J].Tag := I*3+J; //Store ID
      ObjectsTable[I*3+J].OnClick := ObjectsChange;
      ObjectsTable[I*3+J].OnMouseWheel := ObjectsScroll.MouseWheel;
    end;
  ObjectErase := TKMButtonFlat.Create(Panel_Objects, 9, 4, 32, 32, 340);
  ObjectErase.Hint := GetHintWHotkey(TX_MAPED_TERRAIN_OBJECTS_REMOVE, kfMapedSubMenuAction1);
  ObjectErase.Tag := OBJ_NONE_TAG; //no object
  ObjectErase.OnClick := ObjectsChange;

  ObjectBlock := TKMButtonFlat.Create(Panel_Objects, Panel_Objects.Width - 32, 4, 32, 32, 254,rxTrees);
  ObjectBlock.Anchors := [anTop, anRight];
  ObjectBlock.Hint := GetHintWHotkey(TX_MAPED_TERRAIN_OBJECTS_BLOCK, kfMapedSubMenuAction2);
  ObjectBlock.Tag := OBJ_BLOCK_TAG; //block object
  ObjectBlock.OnClick := ObjectsChange;

  ObjectsPalette_Button := TKMButtonFlat.Create(Panel_Objects, 9, 320, Panel_Objects.Width - 9, 21, 0);
  ObjectsPalette_Button.Anchors := [anLeft, anTop, anRight];
  ObjectsPalette_Button.Caption := gResTexts[TX_MAPED_TERRAIN_OBJECTS_PALETTE];
  ObjectsPalette_Button.CapOffsetY := -11;
  ObjectsPalette_Button.Hint := GetHintWHotKey(TX_MAPED_TERRAIN_OBJECTS_PALETTE, kfMapedObjPalette);
  ObjectsPalette_Button.OnClick := ObjectsPaletteButton_Click;

  PopUp_ObjectsPalette := TKMPopUpMenu.Create(aParent.MasterParent, aParent.MasterParent.Width - 50);
  PopUp_ObjectsPalette.Height := aParent.MasterParent.Height - 50;
  PopUp_ObjectsPalette.OnChangeVisibility := ObjectsPalette_OnShow;
  // Keep the pop-up centered
  PopUp_ObjectsPalette.AnchorsCenter;
  PopUp_ObjectsPalette.Left := 25;
  PopUp_ObjectsPalette.Top := 25;

    Bevel_ObjectsPalette := TKMBevel.Create(PopUp_ObjectsPalette, -2000,  -2000, 5000, 5000);
    Bevel_ObjectsPalette.BackAlpha := 0.7;
    Bevel_ObjectsPalette.EdgeAlpha := 0.9;
    Bevel_ObjectsPalette.OnClickShift := ObjPalette_ClickShift;

    Image_ObjectsPalette := TKMImage.Create(PopUp_ObjectsPalette, 0, 0, PopUp_ObjectsPalette.Width, PopUp_ObjectsPalette.Height, 18, rxGuiMain);
    Image_ObjectsPalette.ImageStretch;
    Image_ObjectsPalette.OnClickShift := ObjPalette_ClickShift;

    Scroll_ObjectsPalette := TKMScrollBar.Create(PopUp_ObjectsPalette, PopUp_ObjectsPalette.Width - 20, 25, 20, PopUp_ObjectsPalette.Height - 75, saVertical, bsGame);
    Scroll_ObjectsPalette.MinValue := 0;
    Scroll_ObjectsPalette.Position := 0;
    Scroll_ObjectsPalette.OnChange := ObjectsPalette_Refresh;

    // Add event handlers after Scroll is created
    Image_ObjectsPalette.OnMouseWheel := Scroll_ObjectsPalette.MouseWheel;
    Bevel_ObjectsPalette.OnMouseWheel := Scroll_ObjectsPalette.MouseWheel;

    SetLength(ObjectsPaletteTable, fCountCompact);
    for I := 0 to fCountCompact - 1 do
    begin
      ObjectsPaletteTable[I] := TKMButtonFlat.Create(PopUp_ObjectsPalette, 0, 0, OBJ_CELL_PALETTE_W, OBJ_CELL_PALETTE_H, 1, rxTrees); // Left and Top will update later
      ObjectsPaletteTable[I].Tag := I; //Store ID
      ObjectsPaletteTable[I].CapOffsetY := 15;
//      ObjectsPaletteTable[I].TexOffsetY := 0;
      ObjectsPaletteTable[I].Enable;
      ObjectsPaletteTable[I].Hide;
      ObjectsPaletteTable[I].OnMouseWheel := Scroll_ObjectsPalette.MouseWheel;
      ObjectsPaletteTable[I].OnClickShift := ObjPalette_ClickShift;

    end;

    SetLength(fObjPaletteAttr, fCountCompact);
    for J := Low(Image_ObjectAttributes) to High(Image_ObjectAttributes) do
    begin
      SetLength(Image_ObjectAttributes[J], fCountCompact);
      for I := 0 to fCountCompact - 1 do
      begin
        Image_ObjectAttributes[J, I] := TKMImage.Create(PopUp_ObjectsPalette, 0, 0, 0, 0, 0);
        Image_ObjectAttributes[J, I].Hide;
        Image_ObjectAttributes[J, I].Hitable := False;
      end;
    end;

    Label_ObjectsPalette := TKMLabel.Create(PopUp_ObjectsPalette, PopUp_ObjectsPalette.Center.X, 0, gResTexts[TX_MAPED_TERRAIN_OBJECTS_PALETTE], fntOutline, taCenter);

    Button_ObjPaletteErase := TKMButtonFlat.Create(PopUp_ObjectsPalette, 0, 0, OBJ_CELL_W, 32, 340);
    Button_ObjPaletteErase.Hint := gResTexts[TX_MAPED_TERRAIN_OBJECTS_REMOVE];
    Button_ObjPaletteErase.Tag := OBJ_NONE_TAG; //no object
    Button_ObjPaletteErase.OnClickShift := ObjPalette_ClickShift;

    Button_ObjPaletteBlock := TKMButtonFlat.Create(PopUp_ObjectsPalette, 0, 0, OBJ_CELL_W, 32, 254, rxTrees);
    Button_ObjPaletteBlock.Hint := gResTexts[TX_MAPED_TERRAIN_OBJECTS_BLOCK];
    Button_ObjPaletteBlock.Tag := OBJ_BLOCK_TAG; //block object
    Button_ObjPaletteBlock.OnClickShift := ObjPalette_ClickShift;

    Button_ClosePalette  := TKMButton.Create(PopUp_ObjectsPalette, PopUp_ObjectsPalette.Center.X - 100, PopUp_ObjectsPalette.Bottom - 50,
                                             200, 30, gResTexts[TX_MAPED_TERRAIN_CLOSE_PALETTE], bsGame);
    Button_ClosePalette.Anchors := [anLeft,anBottom];
    Button_ClosePalette.OnClick := ObjectsPaletteClose_Click;

    ObjPalette_UpdateControlsPosition;

  fSubMenuActionsEvents[0] := ObjectsChange;
  fSubMenuActionsEvents[1] := ObjectsChange;
  fSubMenuActionsEvents[2] := ObjectsPaletteButton_Click;

  fSubMenuActionsCtrls[0,0] := ObjectErase;
  fSubMenuActionsCtrls[1,0] := ObjectBlock;
  fSubMenuActionsCtrls[2,0] := ObjectsPalette_Button;


  with TKMLabel.Create(Panel_Objects, 9, 345, Panel_Objects.Width, 0, gResTexts[TX_MAPED_OBJECTS_BRUSH], fntOutline, taCenter) do
  Anchors := [anLeft, anTop, anRight];

  BrushSize   := TKMTrackBar.Create(Panel_Objects, 9, 373, (Panel_Objects.Width - (BTN_BRUSH_SIZE * 2) - 18) - 18, 4, 20);
  BrushSize.Anchors := [anLeft, anTop, anRight];
  BrushSize.Position := 1;
  BrushSize.OnChange := ObjectsChange;
  BrushSize.Hint := GetHintWHotKey(TX_MAPED_TERRAIN_HEIGHTS_SIZE_HINT, gResTexts[TX_KEY_CTRL_MOUSEWHEEL]);


  CleanBrush := TKMButtonFlat.Create(Panel_Objects, 15, 400, 34, 34, 673, rxGui);
  CleanBrush.Anchors := [anTop];
  CleanBrush.Hint := gResTexts[TX_MAPED_OBJECTS_BRUSH_CLEAN];
  CleanBrush.OnClick := ObjectsChange;

  BrushCircle := TKMButtonFlat.Create(Panel_Objects, Panel_Objects.Width - (BTN_BRUSH_SIZE * 2) - 18, 370, BTN_BRUSH_SIZE, BTN_BRUSH_SIZE, 592);
  BrushCircle.Anchors := [anTop, anRight];
  BrushCircle.Hint := GetHintWHotkey(TX_MAPED_TERRAIN_HEIGHTS_CIRCLE, kfMapedSubMenuAction1);
  BrushCircle.OnClick := ObjectsChange;
  BrushCircle.TexOffsetX := 1;
  BrushCircle.TexOffsetY := 1;

  BrushSquare := TKMButtonFlat.Create(Panel_Objects, Panel_Objects.Width - BTN_BRUSH_SIZE - 9, 370, BTN_BRUSH_SIZE, BTN_BRUSH_SIZE, 593);
  BrushSquare.Anchors := [anTop, anRight];
  BrushSquare.Hint := GetHintWHotkey(TX_MAPED_TERRAIN_HEIGHTS_SQUARE, kfMapedSubMenuAction2);
  BrushSquare.OnClick := ObjectsChange;
  BrushSquare.TexOffsetX := 1;
  BrushSquare.TexOffsetY := 1;
  J:=0;
  K:=0;
  RxIndex:=226;
  for I := 0 to 9 do begin
    case I of
       0: begin RxIndex:=226;ObjectsHint:= gResTexts[TX_MAPED_OBJECTS_BRUSH_TREES];end;
       1: begin RxIndex:=34;ObjectsHint:= gResTexts[TX_MAPED_OBJECTS_BRUSH_ALL];end;
       2: begin RxIndex:=14;ObjectsHint:= gResTexts[TX_MAPED_OBJECTS_BRUSH_FLOWERS];end;
       3: begin RxIndex:=4;ObjectsHint:= gResTexts[TX_MAPED_OBJECTS_BRUSH_MUSHROOMS];end;
       4: begin RxIndex:=26;ObjectsHint:= gResTexts[TX_MAPED_OBJECTS_BRUSH_TRUNKS];end;

       5: begin RxIndex:=39;ObjectsHint:= gResTexts[TX_MAPED_OBJECTS_BRUSH_DEAD];end;
       6: begin RxIndex:=21;ObjectsHint:= gResTexts[TX_MAPED_OBJECTS_BRUSH_STONES];end;
       7: begin RxIndex:=143;ObjectsHint:= gResTexts[TX_MAPED_OBJECTS_BRUSH_BUSH];end;
       8: begin RxIndex:=173;ObjectsHint:= gResTexts[TX_MAPED_OBJECTS_BRUSH_CACTUS];end;
       9: begin RxIndex:=245;ObjectsHint:= gResTexts[TX_MAPED_OBJECTS_BRUSH_RUINS];end;
    end;
    if I=5 then begin
    J:=0;
    K:=1;
    end;
    ObjectTypeSet[I] := TKMButtonFlat.Create(Panel_Objects, 9+BTN_BRUSH_SIZE*J, 450+BTN_BRUSH_SIZE*K, 34, 34, RxIndex, rxTrees);

    ObjectTypeSet[I].OnClick := ObjectsChange;
    ObjectTypeSet[I].Hint := ObjectsHint;
    J:=J+1;
  end;
   with TKMLabel.Create(Panel_Objects, 9, 520, Panel_Objects.Width - 9, 20, gResTexts[TX_MAPED_OBJECTS_BRUSH_DENSITY], fntMetal, taLeft) do
    Hint := gResTexts[TX_MAPED_OBJECTS_BRUSH_DENSITY_HINT];

  ForestDensity   := TKMTrackBar.Create(Panel_Objects, 9, 545, (Panel_Objects.Width) - 18, 1, 30);
  ForestDensity.Anchors := [anLeft, anTop, anRight];
  ForestDensity.Position := 10;
  ForestDensity.OnChange := ObjectsChange;
  ForestDensity.Hint := gResTexts[TX_MAPED_OBJECTS_BRUSH_DENSITY_HINT];

  with TKMLabel.Create(Panel_Objects, 9, 570, Panel_Objects.Width - 9, 20, gResTexts[TX_MAPED_OBJECTS_BRUSH_AGE], fntMetal, taLeft) do
  Hint := gResTexts[TX_MAPED_OBJECTS_BRUSH_AGE_HINT];

  ForestAge   := TKMTrackBar.Create(Panel_Objects, 9, 595, (Panel_Objects.Width) - 18, 1, 3);
  ForestAge.Anchors := [anLeft, anTop, anRight];
  ForestAge.Position := 1;
  ForestAge.OnChange := ObjectsChange;
  ForestAge.Hint := gResTexts[TX_MAPED_OBJECTS_BRUSH_AGE_HINT];


  gGameCursor.MapEdObjectsType[0]:=true;
  gGameCursor.MapEdObjectsType[1]:=true;

  If  gGameCursor.MapEdObjectsType[0] then ObjectTypeSet[1].Down:=true else  ObjectTypeSet[1].Down:=false;
  If  gGameCursor.MapEdObjectsType[1] then ObjectTypeSet[0].Down:=true else  ObjectTypeSet[0].Down:=false;
  gGameCursor.MapEdForestAge:=1;
  If gGameCursor.MapEdShape = hsCircle then BrushCircle.Down:=true;
  If gGameCursor.MapEdShape = hsSquare then BrushSquare.Down:=true;
  gGameCursor.MapEdCleanBrush:=false;

end;


procedure TKMMapEdTerrainObjects.ObjectsPalette_OnShow(Sender: TObject; aVisible: Boolean);
begin
  if aVisible then
    ObjPalette_UpdateControlsPosition;
end;


function TKMMapEdTerrainObjects.GetObjPaletteTableHeight: Integer;
begin
  Result := (OBJ_CELL_PALETTE_H + 1)*Min(fObjPaletteTableSize.Y, ((fCountCompact - 1) div fObjPaletteTableSize.X) + 1);
end;


function TKMMapEdTerrainObjects.GetObjPaletteTableWidth: Integer;
begin
  Result := (OBJ_CELL_PALETTE_W + 1)*fObjPaletteTableSize.X;
end;


procedure TKMMapEdTerrainObjects.UpdatePaletteButton(aBtnID: Integer);
const
  ATTR_IMG_SIZE = 25;
  IMG_ATTR_TEXID: array[TKMTerrainObjectAttribute] of Integer = (677, 340, 40, 371 {395});
  IMG_ATTR_W: array[TKMTerrainObjectAttribute] of Integer = (14, 19, 23, 18);
  IMG_ATTR_H: array[TKMTerrainObjectAttribute] of Integer = (14, 19, 22, 14);
var
  I, index: Integer;
  TOA: TKMTerrainObjectAttribute;
  attributes: TKMTerrainObjectAttributeSet;
begin
  attributes := UpdateObjAttributesAndDesc(ObjectsPaletteTable[aBtnID], fCompactToMapElem[aBtnID]);
  index := 0;
//  for TOA := Low(TKMTerrainObjectAttribute) to High(TKMTerrainObjectAttribute) do
  for TOA := toaChoppableTree to toaChoppableTree do
  begin
    if TOA in attributes then
    begin
      Image_ObjectAttributes[index, aBtnID].Visible := True;
      Image_ObjectAttributes[index, aBtnID].Left := ObjectsPaletteTable[aBtnID].Left + 2 + ATTR_IMG_SIZE*index;
      Image_ObjectAttributes[index, aBtnID].Top := ObjectsPaletteTable[aBtnID].Bottom - IMG_ATTR_H[TOA] - 10;
      Image_ObjectAttributes[index, aBtnID].Width := IMG_ATTR_W[TOA];
      Image_ObjectAttributes[index, aBtnID].Height := IMG_ATTR_H[TOA];
      Image_ObjectAttributes[index, aBtnID].TexID := IMG_ATTR_TEXID[TOA];
      Inc(index);
    end;
  end;
  for I := index to High(Image_ObjectAttributes) do
    Image_ObjectAttributes[I, aBtnID].Hide;
end;


function TKMMapEdTerrainObjects.UpdateObjAttributesAndDesc(aBtn: TKMButtonFlat; aObjID: Integer): TKMTerrainObjectAttributeSet;
begin
  Result := [];

  aBtn.CapColor := icWhite;
  aBtn.Hint := aBtn.Caption;

  if ObjectIsChoppableTree(aObjID, [caAge1, caAge2, caAge3, caAgeFull]) then
  begin
    Include(Result, toaChoppableTree);
    aBtn.CapColor := icRoyalYellow;
    aBtn.Hint := aBtn.Hint + ' / ' + gResTexts[TX_MAPED_OBJ_CHOPPABLE_HINT];
  end;

  if gMapElements[aObjID].DiagonalBlocked then
  begin
    Include(Result, toaBlockDiagonal);
    aBtn.Hint := aBtn.Hint + ' / ' + gResTexts[TX_MAPED_OBJ_BLOCK_WALK_DIAG_HINT];
    aBtn.CapColor := icLightRed;
  end;

//This section is not needed, since every AllBlocked object is also blocks building
//  if gMapElements[aObjID].AllBlocked then
//  begin
//    Include(Result, toaBlockAllExceptBuild);
//    HintStr := ' / ' + gResTexts[TX_MAPED_OBJ_BLOCK_ALL_HINT];
//    aBtn.CapColor := icOrange;
//  end;

  if not gMapElements[aObjID].CanBeRemoved then
  begin
    Include(Result, toaBlockBuild);
    if gMapElements[aObjID].AllBlocked then
    begin
      Include(Result, toaBlockAllExceptBuild);
      aBtn.Hint := aBtn.Hint + ' / ' + gResTexts[TX_MAPED_OBJ_BLOCK_WALK_BUILD_HINT];
      aBtn.CapColor := icRed;
    end
    else
    begin
      aBtn.Hint := aBtn.Hint + ' / ' + gResTexts[TX_MAPED_OBJ_BLOCK_BUILD_HINT];
      if toaBlockDiagonal in Result then
        aBtn.CapColor := icOrange
      else
        aBtn.CapColor := icRoyalYellow;
    end;
  end;
end;


procedure TKMMapEdTerrainObjects.ObjectsPalette_Refresh(Sender: TObject);
var
  I, J, K, LeftAdj, TopAdj: Integer;
begin
  LeftAdj := (PopUp_ObjectsPalette.Width - fObjPaletteTableSize.X*(OBJ_CELL_W + 1) - 25*Byte(Scroll_ObjectsPalette.Visible)) div 2;
  TopAdj := Image_ObjectsPalette.Top + 60;

  K := 0;

  Button_ObjPaletteErase.Left := LeftAdj;
  Button_ObjPaletteBlock.Left := LeftAdj + OBJ_CELL_W + 1;

  for I := 0 to fObjPaletteTableSize.Y - 1 do
    for J := 0 to fObjPaletteTableSize.X - 1 do
    begin
      K := (I + Scroll_ObjectsPalette.Position)*fObjPaletteTableSize.X + J;
      if K < fCountCompact then
      begin
        ObjectsPaletteTable[K].Left := J*(OBJ_CELL_PALETTE_W + 1) + LeftAdj;
        ObjectsPaletteTable[K].Top := 25 + I*(OBJ_CELL_PALETTE_H + 1)  + TopAdj;
        ObjectsPaletteTable[K].TexID := gMapElements[fCompactToMapElem[K]].Anim.Step[1] + 1;
        ObjectsPaletteTable[K].Caption := IntToStr(fCompactToMapElem[K]);

        UpdatePaletteButton(K);

        ObjectsPaletteTable[K].Visible := True;
      end;
    end;

  // Make invisible all palette buttons at the end of the list, after shown buttons 'page'
  for I := K + 1 to fCountCompact - 1 do
  begin
    ObjectsPaletteTable[I].Visible := False;
    for J := Low(Image_ObjectAttributes) to High(Image_ObjectAttributes) do
      Image_ObjectAttributes[J, I].Hide;
  end;

  // Make invisible all palette buttons at the start of the list, before shown buttons 'page'
  for I := 0 to Scroll_ObjectsPalette.Position - 1 do
    for J := 0 to fObjPaletteTableSize.X - 1 do
    begin
      K := I*fObjPaletteTableSize.X + J;
      if K < fCountCompact then
        ObjectsPaletteTable[K].Visible := False;
    end;

  // Update palette buttons Down state
  for I := 0 to fCountCompact - 1 do
    ObjectsPaletteTable[I].Down := (gGameCursor.Mode = cmObjects)
                                and (gGameCursor.Tag1 <> OBJ_NONE)
                                and (gGameCursor.Tag1 <> OBJ_BLOCK)
                                and (ObjectsPaletteTable[I].Tag = fMapElemToCompact[gGameCursor.Tag1]);
end;


procedure TKMMapEdTerrainObjects.ObjPalette_UpdateControlsPosition;
var
  RowsCnt, ColsCnt: Integer;
begin
  PopUp_ObjectsPalette.Top := 25;
  PopUp_ObjectsPalette.Left := 25;
  PopUp_ObjectsPalette.Width := PopUp_ObjectsPalette.MasterParent.Width - 50;
  PopUp_ObjectsPalette.Height := PopUp_ObjectsPalette.MasterParent.Height - 50;

  RowsCnt := Max(1, (PopUp_ObjectsPalette.Height - 80) div (OBJ_CELL_PALETTE_H + 1));
  //Calc cols count without Scroll first
  ColsCnt := EnsureRange(PopUp_ObjectsPalette.Width div (OBJ_CELL_PALETTE_W + 1), 1, OBJECTS_PALETTE_MAX_COLS_CNT);
  Scroll_ObjectsPalette.Visible := RowsCnt*ColsCnt < fCountCompact;
  //Recalc ColsCount considering possible scroll width
  ColsCnt := EnsureRange((PopUp_ObjectsPalette.Width - 25*Byte(Scroll_ObjectsPalette.Visible)) div (OBJ_CELL_W + 1), 1, OBJECTS_PALETTE_MAX_COLS_CNT);

  fObjPaletteTableSize := KMPoint(ColsCnt, RowsCnt);

  Image_ObjectsPalette.Width := GetObjPaletteTableWidth + 150;
  Image_ObjectsPalette.Height := GetObjPaletteTableHeight + 220;
  Image_ObjectsPalette.Left := (PopUp_ObjectsPalette.Width - Image_ObjectsPalette.Width) div 2;
  Image_ObjectsPalette.Top := ((PopUp_ObjectsPalette.Height - Image_ObjectsPalette.Height) div 2) - 25;

  Label_ObjectsPalette.Left := PopUp_ObjectsPalette.Center.X - 30;
  Label_ObjectsPalette.Top := Image_ObjectsPalette.Top + 60;

  Button_ClosePalette.Left := PopUp_ObjectsPalette.Center.X - 125;
  Button_ClosePalette.Top := Image_ObjectsPalette.Bottom - 110;

  Button_ObjPaletteErase.Top := Image_ObjectsPalette.Bottom - 110;
  Button_ObjPaletteBlock.Top := Image_ObjectsPalette.Bottom - 110;

  Scroll_ObjectsPalette.Left := Image_ObjectsPalette.Right - 50;
  Scroll_ObjectsPalette.Top := Image_ObjectsPalette.Top + 80;
  Scroll_ObjectsPalette.Height := Image_ObjectsPalette.Height - 150;

  Scroll_ObjectsPalette.MaxValue := ((fCountCompact - 1) div ColsCnt) + 1 - RowsCnt;

  ObjectsPalette_Refresh(nil);
end;


//Map sparse objects into a tight lookup array
procedure TKMMapEdTerrainObjects.CompactMapElements;
var
  I: Integer;
begin
  fCountCompact := 0;
  for I := 0 to gRes.MapElements.Count - 1 do
    if (I <> OBJ_BLOCK_TAG) and (gMapElements[I].Anim.Count > 0) and (gMapElements[I].Anim.Step[1] > 0)
      and (gMapElements[I].Stump = -1) then //Hide falling trees and invisible wall (61)
    begin
      fCompactToMapElem[fCountCompact] := I; //pointer
      fMapElemToCompact[I] := fCountCompact; //Reverse lookup
      Inc(fCountCompact);
    end;
end;


//aObjIndex - Object index which should be visible after update
procedure TKMMapEdTerrainObjects.UpdateObjectsScrollPosToIndex(aObjIndex: Integer);
begin
  // Update Scroll position for objects panel in the menu
  if (aObjIndex >= 0) and not InRange(aObjIndex, ObjectsScroll.Position * 3, ObjectsScroll.Position * 3 + 8) then
    ObjectsScroll.Position := (aObjIndex div 3) - 1; // set scroll so object is in the mid of table
end;


procedure TKMMapEdTerrainObjects.ObjPalette_ClickShift(Sender: TObject; Shift: TShiftState);
var
  ObjIndex: Integer;
begin
  if ssRight in Shift then
    PopUp_ObjectsPalette.Hide
  else if (ssLeft in Shift) and (Sender is TKMButtonFlat) then
  begin
    PopUp_ObjectsPalette.Hide;
    ObjIndex := TKMButtonFlat(Sender).Tag;
    ObjectsUpdate(ObjIndex);

    if (Sender <> Button_ObjPaletteErase)
      and (Sender <> Button_ObjPaletteBlock) then
      UpdateObjectsScrollPosToIndex(ObjIndex);
  end;
end;


procedure TKMMapEdTerrainObjects.ObjectsChange(Sender: TObject);
var
  ObjIndex,I: Integer;
begin


  case TKMButtonFlat(Sender).Tag of
    OBJ_BLOCK_TAG,
    OBJ_NONE_TAG:  ObjIndex := TKMButtonFlat(Sender).Tag; // Block or Erase
    else           ObjIndex := ObjectsScroll.Position * 3 + TKMButtonFlat(Sender).Tag; //0..n-1
  end;

  ObjectsUpdate(ObjIndex);

  // Update Objects Palette scroll position
  if (ObjIndex <> OBJ_BLOCK_TAG) and (ObjIndex <> OBJ_NONE_TAG)
    and not InRange(ObjIndex,
                    Scroll_ObjectsPalette.Position*fObjPaletteTableSize.X,
                    Scroll_ObjectsPalette.Position*fObjPaletteTableSize.X + fObjPaletteTableSize.X*fObjPaletteTableSize.Y - 1) then
    Scroll_ObjectsPalette.Position := ((ObjIndex - 1) div fObjPaletteTableSize.X);


   for I:= 0 to 9 do
    if Sender=ObjectTypeSet[I] then begin
        If gGameCursor.MapEdObjectsType[I] = false then gGameCursor.MapEdObjectsType[I] := true else gGameCursor.MapEdObjectsType[I] := false;
        gGameCursor.Mode := cmObjectsBrush;
    end;

  if (Sender=ForestAge)or(Sender=ForestDensity)or(Sender=BrushSize) then
   if gGameCursor.Mode = cmObjects then
      gGameCursor.Mode :=  cmObjectsBrush;

    if Sender = CleanBrush then begin
      gGameCursor.Mode :=  cmObjectsBrush;
       If CleanBrush.Down=false then begin
        gGameCursor.MapEdCleanBrush:=true; CleanBrush.Down:=true end
         else begin gGameCursor.MapEdCleanBrush:=false; CleanBrush.Down:=false;
      end;
    end;
    if Sender = BrushCircle then
    begin
      gGameCursor.MapEdShape := hsCircle;
      gGameCursor.Mode :=  cmObjectsBrush;
      BrushCircle.Down :=true;
      BrushSquare.Down :=false;
    end
    else
    if Sender = BrushSquare then
    begin
      gGameCursor.MapEdShape := hsSquare;
      gGameCursor.Mode :=  cmObjectsBrush;
    end;
   if gGameCursor.MapEdShape = hsSquare then begin
      BrushCircle.Down :=false;
      BrushSquare.Down :=true;
   end;

  gGameCursor.MapEdSize := BrushSize.Position;

  gGameCursor.MapEdForestAge := ForestAge.Position;
  gGameCursor.MapEdObjectsDensity := ForestDensity.Position;
end;


procedure TKMMapEdTerrainObjects.ObjectsUpdate(aObjIndex: Integer);
begin
  //Skip indexes out of range
  if not InRange(aObjIndex, 0, fCountCompact - 1)
    and (aObjIndex <> OBJ_BLOCK_TAG)
    and (aObjIndex <> OBJ_NONE_TAG) then
    Exit;

  gGameCursor.Mode := cmObjects;
  case aObjIndex of
    OBJ_BLOCK_TAG:  gGameCursor.Tag1 := OBJ_BLOCK; //Block
    OBJ_NONE_TAG:   gGameCursor.Tag1 := OBJ_NONE; //Erase
    else gGameCursor.Tag1 := fCompactToMapElem[aObjIndex];
  end;

  //Remember last selected object
  fLastObjectIndex := aObjIndex;

  ObjectsRefresh(nil);
end;


procedure TKMMapEdTerrainObjects.ObjectsPaletteButton_Click(Sender: TObject);
begin
  PopUp_ObjectsPalette.Show;
end;


procedure TKMMapEdTerrainObjects.ObjectsPaletteClose_Click(Sender: TObject);
begin
  PopUp_ObjectsPalette.Hide;
end;


procedure TKMMapEdTerrainObjects.ObjectsRefresh(Sender: TObject);
var
  I: Integer;
  ObjIndex: Integer;
begin
  for I := 0 to 8 do
  begin
    ObjIndex := ObjectsScroll.Position * 3 + I;
    if ObjIndex < fCountCompact then
    begin
      ObjectsTable[I].TexID := gMapElements[fCompactToMapElem[ObjIndex]].Anim.Step[1] + 1;
      ObjectsTable[I].Caption := IntToStr(fCompactToMapElem[ObjIndex]);

      UpdateObjAttributesAndDesc(ObjectsTable[I], fCompactToMapElem[ObjIndex]);

      ObjectsTable[I].Enable;
    end
    else
    begin
      ObjectsTable[I].TexID := 0;
      ObjectsTable[I].Caption := '';
      ObjectsTable[I].Disable;
    end;
    //Mark the selected one using reverse lookup
    ObjectsTable[I].Down := (gGameCursor.Mode = cmObjects)
                             and (gGameCursor.Tag1 <> OBJ_NONE)
                             and (gGameCursor.Tag1 <> OBJ_BLOCK)
                             and (ObjIndex = fMapElemToCompact[gGameCursor.Tag1]);
  end;

  for I := 0 to 9 do
    ObjectTypeSet[I].Down:=gGameCursor.MapEdObjectsType[I];
  ObjectErase.Down := (gGameCursor.Mode = cmObjects) and (gGameCursor.Tag1 = OBJ_NONE);  //or delete button
  ObjectBlock.Down := (gGameCursor.Mode = cmObjects) and (gGameCursor.Tag1 = OBJ_BLOCK); //or block button
end;


procedure TKMMapEdTerrainObjects.Show;
begin
  case fLastObjectIndex of
    -1:   ; // Do not update Objects if no last object was selected
    OBJ_BLOCK_TAG: ObjectsChange(ObjectBlock);
    OBJ_NONE_TAG:  ObjectsChange(ObjectErase);
    else  begin
            UpdateObjectsScrollPosToIndex(fLastObjectIndex);
            ObjectsChange(ObjectsTable[fLastObjectIndex - ObjectsScroll.Position*3]);
          end;
  end;
  Panel_Objects.Show;
end;


function TKMMapEdTerrainObjects.Visible: Boolean;
begin
  Result := Panel_Objects.Visible;
end;


procedure TKMMapEdTerrainObjects.Hide;
begin
  Panel_Objects.Hide;
  PopUp_ObjectsPalette.Hide;
end;


procedure TKMMapEdTerrainObjects.KeyDown(Key: Word; Shift: TShiftState; var aHandled: Boolean);
begin
  if aHandled then Exit;

  aHandled := Key = gResKeys[kfMapedObjPalette].Key;
  if (Key = VK_ESCAPE) and PopUp_ObjectsPalette.Visible then
  begin
    PopUp_ObjectsPalette.Hide;
    aHandled := True;
  end;
end;


procedure TKMMapEdTerrainObjects.KeyUp(Key: Word; Shift: TShiftState; var aHandled: Boolean);
begin
  aHandled := Key = gResKeys[kfMapedObjPalette].Key;
  if aHandled then
  begin
    //Reset selected and hide all pages
    if Assigned(fHideAllPages) and (gMySpectator.Selected <> nil) then
    begin
      gMySpectator.Selected := nil;
      fHideAllPages;
    end;

    PopUp_ObjectsPalette.ToggleVisibility;
  end;
end;


procedure TKMMapEdTerrainObjects.Resize;
begin
  ObjPalette_UpdateControlsPosition;
end;


procedure TKMMapEdTerrainObjects.Cancel_Clicked(var aHandled: Boolean);
begin
  if aHandled then Exit;

  // Reset last object on RMB click
  if gGameCursor.Mode = cmObjects then
  begin
    fLastObjectIndex := -1;
    aHandled := True;
  end;
end;


procedure TKMMapEdTerrainObjects.UpdateState;
begin
  ObjectsRefresh(nil);
end;


end.
