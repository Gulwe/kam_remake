﻿unit Form_Generator;
{$I ..\..\KaM_Remake.inc}
interface
uses
  {$IFDEF WDC} Windows, {$ENDIF} //Declared first to get TBitmap overriden with VCL version
  {$IFDEF FPC} lconvencoding, {$ENDIF}
  SysUtils, Classes, Graphics, Controls, Forms, Dialogs, ExtCtrls, StdCtrls, Spin, StrUtils, Vcl.ComCtrls,
  KM_CommonTypes, KM_Defaults, KM_ResFonts, KM_ResFontsEdit,
  KM_FontXGenerator;


type
  TForm1 = class(TForm)
    Label4: TLabel;
    Image1: TImage;
    btnSave: TButton;
    dlgSave: TSaveDialog;
    btnExportTex: TButton;
    dlgOpen: TOpenDialog;
    btnImportTex: TButton;
    GroupBox2: TGroupBox;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    btnGenerate: TButton;
    Memo1: TMemo;
    seFontSize: TSpinEdit;
    cbBold: TCheckBox;
    cbItalic: TCheckBox;
    btnCollectChars: TButton;
    cbAntialias: TCheckBox;
    cbFontName: TComboBox;
    btnChnRange: TButton;
    tbAtlas: TTrackBar;
    Label6: TLabel;
    rgSizeX: TRadioGroup;
    rgSizeY: TRadioGroup;
    Label5: TLabel;
    sePadding: TSpinEdit;
    cbCells: TCheckBox;
    Label7: TLabel;
    btnJpnRange: TButton;
    btnKorRange: TButton;
    procedure btnGenerateClick(Sender: TObject);
    procedure btnSaveClick(Sender: TObject);
    procedure btnExportTexClick(Sender: TObject);
    procedure btnImportTexClick(Sender: TObject);
    procedure btnCollectCharsClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure UpdateCaption(const aString: UnicodeString);
    procedure btnChnRangeClick(Sender: TObject);
    procedure tbAtlasChange(Sender: TObject);
    procedure btnJpnRangeClick(Sender: TObject);
    procedure btnKorRangeClick(Sender: TObject);
  private
    fFontSpec: TKMFontSpecEdit;
    fFontGenerator: TKMFontXGenerator;
  end;


var
  Form1: TForm1;


implementation

{$R *.dfm}

{ TForm1 }
procedure TForm1.FormCreate(Sender: TObject);
begin
  Caption := 'KaM FontX Generator (' + GAME_REVISION + ')';
  ExeDir := ExtractFilePath(ParamStr(0));

  fFontGenerator := TKMFontXGenerator.Create;

  fFontGenerator.LoadPresetsXML(ExeDir + 'fonts.xml');

  TKMFontXGenerator.ListFonts(Self, cbFontName.Items);
end;


procedure TForm1.FormDestroy(Sender: TObject);
begin
  FreeAndNil(fFontSpec);
  FreeAndNil(fFontGenerator);
end;


procedure TForm1.btnGenerateClick(Sender: TObject);
var
  chars: UnicodeString;
  useChars: TWideCharArray;
  fntStyle: TFontStyles;
begin
  FreeAndNil(fFontSpec);
  fFontSpec := TKMFontSpecEdit.Create(fntArial); //fntArial, why not, it looks like we dont care

  {$IFDEF WDC}
  chars := Memo1.Text;
  {$ENDIF}
  {$IFDEF FPC}
  chars := UTF8Decode(Memo1.Text);
  {$ENDIF}
  SetLength(useChars, Length(chars));
  Move(chars[1], useChars[0], Length(chars) * SizeOf(WideChar));

  fntStyle := [];
  if cbBold.Checked then
    fntStyle := fntStyle + [fsBold];
  if cbItalic.Checked then
    fntStyle := fntStyle + [fsItalic];

  fFontSpec.TexPadding := sePadding.Value;
  fFontSpec.TexSizeX := StrToInt(rgSizeX.Items[rgSizeX.ItemIndex]);
  fFontSpec.TexSizeY := StrToInt(rgSizeY.Items[rgSizeY.ItemIndex]);
  fFontSpec.CreateFont(cbFontName.Text, seFontSize.Value, fntStyle, cbAntialias.Checked, useChars);
  tbAtlas.Max := fFontSpec.AtlasCount - 1;

  fFontSpec.ExportAtlasBmp(Image1.Picture.Bitmap, tbAtlas.Position, cbCells.Checked);
  Image1.Repaint;
end;


procedure TForm1.tbAtlasChange(Sender: TObject);
begin
  fFontSpec.ExportAtlasBmp(Image1.Picture.Bitmap, tbAtlas.Position, cbCells.Checked);
  Image1.Repaint;
end;


procedure TForm1.btnSaveClick(Sender: TObject);
begin
  dlgSave.DefaultExt := TKMFontSpec.DEFAULT_EXT;
  dlgSave.FileName := cbFontName.Text;
  dlgSave.InitialDir := ExpandFileName(ExeDir + '..\..\' + TKMFontSpec.FONTS_FOLDER);
  if not dlgSave.Execute then Exit;

  fFontSpec.SaveToFontX(dlgSave.FileName);
end;


procedure TForm1.UpdateCaption(const aString: UnicodeString);
begin
  btnCollectChars.Caption := aString;
end;


procedure TForm1.btnChnRangeClick(Sender: TObject);
const
  //Chinese punctuation marks as reported by JiZong
  CN_CHARS: array [0..13] of Word =
    (183, 8212, 8216, 8217, 8220, 8221, 8230, 12289, 12290, 65281, 65292, 65306, 65307, 65311);
var
  uniText: UnicodeString;
  I: Word;
begin
  uniText := '';

  for I := Low(CN_CHARS) to High(CN_CHARS) do
    uniText := uniText + WideChar(CN_CHARS[I]);

  //Chinese
  for I := 19968 to 40870 do
    uniText := uniText + WideChar(I);

  {$IFDEF WDC}
    Memo1.Text := uniText;
  {$ENDIF}
  {$IFDEF FPC}
    //FPC controls need utf8 strings
    Memo1.Text := UTF8Encode(uniText);
  {$ENDIF}
end;


procedure TForm1.btnJpnRangeClick(Sender: TObject);
var
  uniText: UnicodeString;
  I: Word;
begin
  uniText := '';

  //Japanese
  //Punctuations (3000 - 303f)   12288 -
  //Hiragana (3040 - 309f)
  //Katakana (30a0 - 30ff)       - 12543

  for I := $3000 to $30ff do
    uniText := uniText + WideChar(I);

  {$IFDEF WDC}
    Memo1.Text := uniText;
  {$ENDIF}
  {$IFDEF FPC}
    //FPC controls need utf8 strings
    Memo1.Text := UTF8Encode(uniText);
  {$ENDIF}
end;


procedure TForm1.btnKorRangeClick(Sender: TObject);
var
  uniText: UnicodeString;
  I: Word;
begin
  uniText := '';

  //Hangul Jamo
  for I := $1100 to $11FF do
    uniText := uniText + WideChar(I);

  //Hangul Compatibility Jamo
  for I := $3130 to $318F do
    uniText := uniText + WideChar(I);

  //Hangul Syllables
  for I := $AC00 to $D7A3 do
    uniText := uniText + WideChar(I);

  //Punctuation
  uniText := uniText + WideChar($302E);
  uniText := uniText + WideChar($302F);

  {$IFDEF WDC}
    Memo1.Text := uniText;
  {$ENDIF}
  {$IFDEF FPC}
    //FPC controls need utf8 strings
    Memo1.Text := UTF8Encode(uniText);
  {$ENDIF}
end;

procedure TForm1.btnCollectCharsClick(Sender: TObject);
var
  prevCaption: string;
  uniText: UnicodeString;
begin
  prevCaption := btnCollectChars.Caption;
  try
    uniText := TKMFontXGenerator.CollectChars(ExeDir, UpdateCaption);

    {$IFDEF WDC}
      Memo1.Text := uniText;
    {$ENDIF}
    {$IFDEF FPC}
      //FPC controls need utf8 strings
      Memo1.Text := UTF8Encode(uniText);
    {$ENDIF}
  finally
    btnCollectChars.Caption := prevCaption;
  end;
end;


procedure TForm1.btnExportTexClick(Sender: TObject);
begin
  dlgSave.DefaultExt := 'png';
  if not dlgSave.Execute then Exit;

  fFontSpec.ExportAtlasPng(dlgSave.FileName, tbAtlas.Position);
end;


procedure TForm1.btnImportTexClick(Sender: TObject);
begin
  if not dlgOpen.Execute then Exit;

  fFontSpec.ImportPng(dlgOpen.FileName, tbAtlas.Position);
end;


end.
