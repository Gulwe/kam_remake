unit KM_GameAppSettings;
{$I KaM_Remake.inc}
interface
uses
  Generics.Collections,
  KM_IoXML,
  KM_Settings;


type
  // Common implementation for settings stored and loaded from XML
  TKMSettingsXML = class(TKMSettings)
  private
    fXML: TKMXmlDocument;
  protected
    fRoot: TKMXmlNode;
    procedure LoadFromFile(const aPath: string); override;
    procedure SaveToFile(const aPath: string); override;
  public
    constructor Create;
    destructor Destroy; override;
  end;


  TKMGameAppSettingsPart = class;


  // GameApp settings, stored in the XML
  // Loaded and saved only once
  TKMGameAppSettings = class(TKMSettingsXML)
  private
    fSettingParts: TList<TKMGameAppSettingsPart>;

    procedure RegisterSettingPart(aSettingPart: TKMGameAppSettingsPart);
    procedure UnRegisterSettingPart(aSettingPart: TKMGameAppSettingsPart);
  protected
    procedure LoadFromFile(const aPath: string); override;
    procedure SaveToFile(const aPath: string); override;
    function GetDefaultSettingsName: string; override;
    function GetSettingsName: string; override;
  public
    constructor Create;
    destructor Destroy; override;

    property Root: TKMXmlNode read fRoot;
  end;


  // Part of GameApp settings, which are stored in the XML
  TKMGameAppSettingsPart = class abstract
  private
    function GetRoot: TKMXmlNode;
  protected
    function GetDefaultSettingsName: string;

    property Root: TKMXmlNode read GetRoot;
  public
    constructor Create;
    destructor Destroy; override;

    procedure SaveToXML; virtual; abstract;
    procedure LoadFromXML; virtual; abstract;
    procedure SaveSettings; virtual;
  end;

var
  gGameAppSettings: TKMGameAppSettings;


implementation
uses
  SysUtils, INIfiles, Math,
  KM_Defaults;


{ TKMSettingsXML }
constructor TKMSettingsXML.Create;
begin
  // Prefer to store XML settings in the shared folder
  inherited Create(slShared);
end;


destructor TKMSettingsXML.Destroy;
begin
//  fXML.Free;

  inherited;
end;


procedure TKMSettingsXML.LoadFromFile(const aPath: string);
begin
  inherited;

  fXML.LoadFromFile(aPath);
  fRoot := fXML.Root;
end;


procedure TKMSettingsXML.SaveToFile(const aPath: string);
begin
  inherited;

  fXML.SaveToFile(aPath);
end;


{ TKMGameAppSettings }
constructor TKMGameAppSettings.Create;
begin
  fXML := TKMXmlDocument.Create;
  fSettingParts := TList<TKMGameAppSettingsPart>.Create;

  inherited;
end;


destructor TKMGameAppSettings.Destroy;
begin
  inherited;

  fSettingParts.Free;
  fXML.Free;
end;


procedure TKMGameAppSettings.RegisterSettingPart(aSettingPart: TKMGameAppSettingsPart);
begin
  fSettingParts.Add(aSettingPart);
end;


procedure TKMGameAppSettings.UnRegisterSettingPart(aSettingPart: TKMGameAppSettingsPart);
begin
  fSettingParts.Remove(aSettingPart);
end;


procedure TKMGameAppSettings.LoadFromFile(const aPath: string);
var
  I: Integer;
begin
  inherited;

  for I := 0 to fSettingParts.Count - 1 do
    fSettingParts[I].LoadFromXML;
end;


procedure TKMGameAppSettings.SaveToFile(const aPath: string);
var
  I: Integer;
begin
  for I := 0 to fSettingParts.Count - 1 do
    fSettingParts[I].SaveToXML;

  inherited;
end;


function TKMGameAppSettings.GetDefaultSettingsName: string;
begin
  Result := SETTINGS_FILE;
end;


function TKMGameAppSettings.GetSettingsName: string;
const
  GAME_APP_SETTINGS_NAME = 'GameApp settings';
begin
  Result := GAME_APP_SETTINGS_NAME;
end;


{ TKMGameAppSettingsPart }
constructor TKMGameAppSettingsPart.Create;
begin
  inherited;

  LoadFromXML;
  gGameAppSettings.RegisterSettingPart(Self);
end;


destructor TKMGameAppSettingsPart.Destroy;
begin
  SaveToXML;
  gGameAppSettings.UnRegisterSettingPart(Self);

  inherited;
end;


function TKMGameAppSettingsPart.GetDefaultSettingsName: string;
begin
  Result := SETTINGS_FILE;
end;


function TKMGameAppSettingsPart.GetRoot: TKMXmlNode;
begin
  Result := gGameAppSettings.fRoot;
end;


procedure TKMGameAppSettingsPart.SaveSettings;
begin
  if SKIP_SETTINGS_SAVE then Exit;

  gGameAppSettings.SaveSettings;
end;


end.

