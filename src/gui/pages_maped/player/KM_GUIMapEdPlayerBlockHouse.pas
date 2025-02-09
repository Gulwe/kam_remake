unit KM_GUIMapEdPlayerBlockHouse;
{$I KaM_Remake.inc}
interface
uses
   Classes,
   KM_Controls, KM_Pics, KM_InterfaceGame;

type
  TKMMapEdPlayerBlockHouse = class
  private
    procedure Player_BlockHouseClick(Sender: TObject; Shift: TShiftState);
    procedure Player_BlockHouseRefresh;
  protected
    Panel_BlockHouse: TKMPanel;
    Button_BlockHouse: array [1..GUI_HOUSE_COUNT] of TKMButtonFlat;
    Image_BlockHouse: array [1..GUI_HOUSE_COUNT] of TKMImage;
  public
    constructor Create(aParent: TKMPanel);

    procedure Show;
    function Visible: Boolean;
    procedure Hide;
  end;


implementation
uses
  KM_HandsCollection, KM_ResTexts, KM_HandLocks,
  KM_Resource, KM_ResHouses, KM_RenderUI, KM_ResFonts,
  KM_ResTypes;


{ TKMMapEdPlayerBlockHouse }
constructor TKMMapEdPlayerBlockHouse.Create(aParent: TKMPanel);
var
  I: Integer;
begin
  inherited Create;

  Panel_BlockHouse := TKMPanel.Create(aParent, 9, 28, aParent.Width - 9, 400);
  with TKMLabel.Create(Panel_BlockHouse, 0, PAGE_TITLE_Y, Panel_BlockHouse.Width, 0, gResTexts[TX_MAPED_BLOCK_HOUSES], fntOutline, taCenter) do
    Anchors := [anLeft, anTop, anRight];
  for I := 1 to GUI_HOUSE_COUNT do
  if GUIHouseOrder[I] <> htNone then
  begin
    Button_BlockHouse[I] := TKMButtonFlat.Create(Panel_BlockHouse, 9 + ((I-1) mod 5)*37, 30 + ((I-1) div 5)*37,33,33,gRes.Houses[GUIHouseOrder[I]].GUIIcon);
    Button_BlockHouse[I].Hint := gRes.Houses[GUIHouseOrder[I]].HouseName;
    Button_BlockHouse[I].OnClickShift := Player_BlockHouseClick;
    Button_BlockHouse[I].Tag := I;
    Image_BlockHouse[I] := TKMImage.Create(Panel_BlockHouse, 9 + ((I-1) mod 5)*37 + 15, 30 + ((I-1) div 5)*37 + 15, 16, 16, 0, rxGuiMain);
    Image_BlockHouse[I].Hitable := False;
    Image_BlockHouse[I].ImageCenter;
  end;
end;


procedure TKMMapEdPlayerBlockHouse.Player_BlockHouseClick(Sender: TObject; Shift: TShiftState);
var
  I: Integer;
  H: TKMHouseType;
  locks: TKMHandLocks;
begin
  I := TKMButtonFlat(Sender).Tag;
  H := GUIHouseOrder[I];

  locks := gMySpectator.Hand.Locks;

  if ssLeft in Shift then
  begin
    //Loop through states CanBuild > CantBuild > Released
    if not locks.HouseBlocked[H] and not locks.HouseGranted[H] then
    begin
      locks.HouseBlocked[H] := True;
      locks.HouseGranted[H] := False;
    end else
    if locks.HouseBlocked[H] and not locks.HouseGranted[H] then
    begin
      locks.HouseBlocked[H] := False;
      locks.HouseGranted[H] := True;
    end else
    begin
      locks.HouseBlocked[H] := False;
      locks.HouseGranted[H] := False;
    end;
  end
  else
  if ssRight in Shift then
  begin
    //Loop through states CanBuild < CantBuild < Released
    if not locks.HouseBlocked[H] and not locks.HouseGranted[H] then
    begin
      locks.HouseBlocked[H] := False;
      locks.HouseGranted[H] := True;
    end else
    if locks.HouseBlocked[H] and not locks.HouseGranted[H] then
    begin
      locks.HouseBlocked[H] := False;
      locks.HouseGranted[H] := False;
    end else
    begin
      locks.HouseBlocked[H] := True;
      locks.HouseGranted[H] := False;
    end;
  end;

  Player_BlockHouseRefresh;
end;


procedure TKMMapEdPlayerBlockHouse.Player_BlockHouseRefresh;
var
  I: Integer;
  H: TKMHouseType;
  locks: TKMHandLocks;
begin
  locks := gMySpectator.Hand.Locks;

  for I := 1 to GUI_HOUSE_COUNT do
  begin
    H := GUIHouseOrder[I];
    if locks.HouseBlocked[H] and not locks.HouseGranted[H] then
      Image_BlockHouse[I].TexID := 32
    else
    if locks.HouseGranted[H] and not locks.HouseBlocked[H] then
      Image_BlockHouse[I].TexID := 33
    else
    if not locks.HouseGranted[H] and not locks.HouseBlocked[H] then
      Image_BlockHouse[I].TexID := 0
    else
      Image_BlockHouse[I].TexID := 24; //Some erroneous value
  end;
end;


procedure TKMMapEdPlayerBlockHouse.Hide;
begin
  Panel_BlockHouse.Hide;
end;


procedure TKMMapEdPlayerBlockHouse.Show;
begin
  Player_BlockHouseRefresh;
  Panel_BlockHouse.Show;
end;


function TKMMapEdPlayerBlockHouse.Visible: Boolean;
begin
  Result := Panel_BlockHouse.Visible;
end;


end.
