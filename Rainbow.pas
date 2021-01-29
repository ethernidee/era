unit Rainbow;
(*
  DESCRIPTION: Adds markup language support to all Heroes texts (EML - Era Markup Language).
  AUTHOR:      Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
*)

(***)  interface  (***)
uses
  Math, SysUtils, Windows,
  Utils, Crypto, Lists, AssocArrays, TextScan, ApiJack, PatchApi, DataLib, StrLib, TypeWrappers,
  Core, GameExt, Heroes, Graph, Memory, EventMan, DlgMes;

type
  (* Import *)
  TList   = DataLib.TList;
  TDict   = DataLib.TDict;
  TString = TypeWrappers.TString;

const
  MAX_CHINESE_LATIN_CHARACTER = #160;

  TEXTMODE_15BITS = $3E0;
  TEXTMODE_16BITS = $7E0;

  DEF_COLOR     = 0;
  DEF_ALIGNMENT = -1;

  TextColorMode: pword = Ptr($694DB0);


type
  TColor32To16Func       = function (Color32: integer): integer;
  TGraphemWidthEstimator = function (Font: Heroes.PFontItem): integer; stdcall;

var
  (* Chinese loader support: {~color}...{~} => {...} *)
  ChineseLoaderOpt:             boolean;
  ChineseHandler:               pointer;
  ChineseGraphemWidthEstimator: TGraphemWidthEstimator;


procedure NameColor (Color32: integer; const Name: string); stdcall;

function  ChineseGetCharColor: integer; stdcall;
procedure ChineseGotoNextChar; stdcall;
procedure ChineseSetTextAlignmentParamPtr (NewParamPtr: pinteger); stdcall;
procedure SetChineseGraphemWidthEstimator (Estimator: TGraphemWidthEstimator); stdcall;


(***) implementation (***)


exports
  (* Chinese only: temporal *)
  ChineseGetCharColor,
  ChineseGotoNextChar,
  ChineseSetTextAlignmentParamPtr,
  SetChineseGraphemWidthEstimator;


const
  BLANKS = [#0..#32];

  TOKEN_HASH_TOP    = 517545930;
  TOKEN_HASH_MIDDLE = -1635771697;
  TOKEN_HASH_BOTTOM = -1990233436;
  TOKEN_HASH_LEFT   = 2053629800;
  TOKEN_HASH_CENTER = 1089530660;
  TOKEN_HASH_RIGHT  = -1261800172;


type
  TTextBlockType = (TEXT_BLOCK_CHARS, TEXT_BLOCK_DEF);

  PEmlChars = ^TEmlChars;
  TEmlChars = record
    Color32: integer;
  end;

  PEmlImg = ^TEmlImg;
  TEmlImg = record
    IsBlock:       boolean;
    DrawFlags:     Heroes.TDrawImageFlags;
    OffsetX:       integer;
    OffsetY:       integer;
    CharsPerLine:  integer;
    Height:        integer;
    NumLines:      integer;
    AttrVertAlign: integer;
  end;

  PEmlDef = ^TEmlDef;
  TEmlDef = record
  {U} Def:      Heroes.PDefItem;
      DefName:  pchar; // Pointer to persisted string
      GroupInd: integer;
      FrameInd: integer;
  end;

  PTextBlock = ^TTextBlock;
  TTextBlock = record
    BlockType:      TTextBlockType;
    BlockLen:       integer;
    HorizAlignment: integer;

    case TTextBlockType of
      TEXT_BLOCK_CHARS: (
        CharsBlock: TEmlChars;
      );

      TEXT_BLOCK_DEF: (
        ImgBlock: TEmlImg;
        DefBlock: TEmlDef;
      );    
  end; // .record TTextBlock

  TParsedText = class
   public
   {O} Blocks:        {O} TList {of PTextBlock};
   {U} Font:          PFontItem;
       RefCount:      integer;
       OrigText:      string;
       ProcessedText: string;
       NumBlocks:     integer;

    constructor Create (const OrigText: string; {U} Font: Heroes.PFontItem);
    destructor  Destroy; override;

    (* Returns list of TParsedTextLine, suitable to be displayed in the box of given size *)
    function ToLines (BoxWidth: integer): {O} TList {of TParsedTextLine};

    function CountLines (BoxWidth: integer): integer;
  end; // .class TParsedText

  TParsedTextLine = class
   public
    Offset:   integer;
    Len:      integer;
    BlockInd: integer;
    BlockPos: integer;

    procedure ToTaggedText (ParsedText: TParsedText; Res: StrLib.TStrBuilder);
  end;

var
{O} NamedColors:       {U} AssocArrays.TAssocArray {of Color32: integer};
{O} LoadedResources:   {U} TDict {of loaded H3 resource};
{O} TextAttrsStack:    {U} Lists.TList {of (Color32, HorizAlign: integer)...};
{O} TextScanner:       TextScan.TTextScanner;
{O} TaggedLineBuilder: StrLib.TStrBuilder;
    Color32To16:       TColor32To16Func;
    Color16To32:       function (Color16: integer): integer;

{O} CurrParsedText:   TParsedText = nil;
{U} CurrTextBlock:    PTextBlock  = nil;
    CurrTextNumLines: integer     = 1;
    CurrTextAlignPtr: pinteger    = nil;
    CurrTextDefAlign: integer     = 0;

    CurrBlockInd:   integer;
    CurrBlockPos:   integer;
    CurrColor:      integer = DEF_COLOR;
    CurrHorizAlign: integer = DEF_ALIGNMENT;

    GlobalBuffer: array [0..1024 * 1024 - 1] of char;


function Color32To15Func (Color32: integer): integer;
begin
  result  :=
    ((Color32 and $0000F8) shr 3) or
    ((Color32 and $00F800) shr 6) or
    ((Color32 and $F80000) shr 9);
end;

function Color32To16Func (Color32: integer): integer;
begin
  result  :=
    ((Color32 and $0000F8) shr 3) or
    ((Color32 and $00FC00) shr 5) or
    ((Color32 and $F80000) shr 8);
end;

function Color16To32Func (Color16: integer): integer;
begin
  result := (({BLUE} (Color16 and $1F) shl 3) or ({GREEN} (Color16 and $7E0) shl 5) or ({RED} (Color16 and $F800) shl 8) or Graph.FULLY_OPAQUE_MASK32) and $FFF8FCF8;
end;

function Color15To32Func (Color15: integer): integer;
begin
  result := (({BLUE} (Color15 and $1F) shl 3) or ({GREEN} (Color15 and $3E0) shl 6) or ({RED} (Color15 and $F800) shl 9) or Graph.FULLY_OPAQUE_MASK32) and $FFF8F8F8;
end;

function Color32ToCode (Color32: integer): string;
begin
  result := SysUtils.Format('%.8x', [((Color32 and Graph.RGB_MASK_32) shl 8) or ((Color32 shr 24) and $FF)]);
end;

procedure NameStdColors;
begin
  NamedColors['AliceBlue']            := Ptr($F0F8FF);
  NamedColors['AntiqueWhite']         := Ptr($FFFAEBD7);
  NamedColors['Aqua']                 := Ptr($FF00FFFF);
  NamedColors['Aquamarine']           := Ptr($FF7FFFD4);
  NamedColors['Azure']                := Ptr($FFF0FFFF);
  NamedColors['Beige']                := Ptr($FFF5F5DC);
  NamedColors['Bisque']               := Ptr($FFFFE4C4);
  NamedColors['Black']                := Ptr($FF000000);
  NamedColors['BlanchedAlmond']       := Ptr($FFFFEBCD);
  NamedColors['Blue']                 := Ptr($FF0000FF);
  NamedColors['BlueViolet']           := Ptr($FF8A2BE2);
  NamedColors['Brown']                := Ptr($FFA52A2A);
  NamedColors['BurlyWood']            := Ptr($FFDEB887);
  NamedColors['CadetBlue']            := Ptr($FF5F9EA0);
  NamedColors['Chartreuse']           := Ptr($FF7FFF00);
  NamedColors['Chocolate']            := Ptr($FFD2691E);
  NamedColors['Coral']                := Ptr($FFFF7F50);
  NamedColors['CornflowerBlue']       := Ptr($FF6495ED);
  NamedColors['Cornsilk']             := Ptr($FFFFF8DC);
  NamedColors['Crimson']              := Ptr($FFDC143C);
  NamedColors['Cyan']                 := Ptr($FF00FFFF);
  NamedColors['DarkBlue']             := Ptr($FF00008B);
  NamedColors['DarkCyan']             := Ptr($FF008B8B);
  NamedColors['DarkGoldenRod']        := Ptr($FFB8860B);
  NamedColors['DarkGray']             := Ptr($FFA9A9A9);
  NamedColors['DarkGreen']            := Ptr($FF006400);
  NamedColors['DarkGrey']             := Ptr($FFA9A9A9);
  NamedColors['DarkKhaki']            := Ptr($FFBDB76B);
  NamedColors['DarkMagenta']          := Ptr($FF8B008B);
  NamedColors['DarkOliveGreen']       := Ptr($FF556B2F);
  NamedColors['Darkorange']           := Ptr($FFFF8C00);
  NamedColors['DarkOrchid']           := Ptr($FF9932CC);
  NamedColors['DarkRed']              := Ptr($FF8B0000);
  NamedColors['DarkSalmon']           := Ptr($FFE9967A);
  NamedColors['DarkSeaGreen']         := Ptr($FF8FBC8F);
  NamedColors['DarkSlateBlue']        := Ptr($FF483D8B);
  NamedColors['DarkSlateGrey']        := Ptr($FF2F4F4F);
  NamedColors['DarkTurquoise']        := Ptr($FF00CED1);
  NamedColors['DarkViolet']           := Ptr($FF9400D3);
  NamedColors['DeepPink']             := Ptr($FFFF1493);
  NamedColors['DeepSkyBlue']          := Ptr($FF00BFFF);
  NamedColors['DimGray']              := Ptr($FF696969);
  NamedColors['DodgerBlue']           := Ptr($FF1E90FF);
  NamedColors['FireBrick']            := Ptr($FFB22222);
  NamedColors['FloralWhite']          := Ptr($FFFFFAF0);
  NamedColors['ForestGreen']          := Ptr($FF228B22);
  NamedColors['Fuchsia']              := Ptr($FFFF00FF);
  NamedColors['Gainsboro']            := Ptr($FFDCDCDC);
  NamedColors['GhostWhite']           := Ptr($FFF8F8FF);
  NamedColors['Gold']                 := Ptr($FFFFD700);
  NamedColors['GoldenRod']            := Ptr($FFDAA520);
  NamedColors['Gray']                 := Ptr($FF808080);
  NamedColors['Green']                := Ptr($FF008000);
  NamedColors['GreenYellow']          := Ptr($FFADFF2F);
  NamedColors['Grey']                 := Ptr($FF808080);
  NamedColors['HoneyDew']             := Ptr($FFF0FFF0);
  NamedColors['HotPink']              := Ptr($FFFF69B4);
  NamedColors['IndianRed']            := Ptr($FFCD5C5C);
  NamedColors['Indigo']               := Ptr($FF4B0082);
  NamedColors['Ivory']                := Ptr($FFFFFFF0);
  NamedColors['Khaki']                := Ptr($FFF0E68C);
  NamedColors['Lavender']             := Ptr($FFE6E6FA);
  NamedColors['LavenderBlush']        := Ptr($FFFFF0F5);
  NamedColors['LawnGreen']            := Ptr($FF7CFC00);
  NamedColors['LemonChiffon']         := Ptr($FFFFFACD);
  NamedColors['LightBlue']            := Ptr($FFADD8E6);
  NamedColors['LightCoral']           := Ptr($FFF08080);
  NamedColors['LightCyan']            := Ptr($FFE0FFFF);
  NamedColors['LightGoldenRodYellow'] := Ptr($FFFAFAD2);
  NamedColors['LightGray']            := Ptr($FFD3D3D3);
  NamedColors['LightGreen']           := Ptr($FF90EE90);
  NamedColors['LightGrey']            := Ptr($FFD3D3D3);
  NamedColors['LightPink']            := Ptr($FFFFB6C1);
  NamedColors['LightSalmon']          := Ptr($FFFFA07A);
  NamedColors['LightSeaGreen']        := Ptr($FF20B2AA);
  NamedColors['LightSkyBlue']         := Ptr($FF87CEFA);
  NamedColors['LightSlateGray']       := Ptr($FF778899);
  NamedColors['LightSteelBlue']       := Ptr($FFB0C4DE);
  NamedColors['LightYellow']          := Ptr($FFFFFFE0);
  NamedColors['Lime']                 := Ptr($FF00FF00);
  NamedColors['LimeGreen']            := Ptr($FF32CD32);
  NamedColors['Linen']                := Ptr($FFFAF0E6);
  NamedColors['Magenta']              := Ptr($FFFF00FF);
  NamedColors['Maroon']               := Ptr($FF800000);
  NamedColors['MediumAquaMarine']     := Ptr($FF66CDAA);
  NamedColors['MediumBlue']           := Ptr($FF0000CD);
  NamedColors['MediumOrchid']         := Ptr($FFBA55D3);
  NamedColors['MediumPurple']         := Ptr($FF9370D8);
  NamedColors['MediumSeaGreen']       := Ptr($FF3CB371);
  NamedColors['MediumSlateBlue']      := Ptr($FF7B68EE);
  NamedColors['MediumSpringGreen']    := Ptr($FF00FA9A);
  NamedColors['MediumTurquoise']      := Ptr($FF48D1CC);
  NamedColors['MediumVioletRed']      := Ptr($FFC71585);
  NamedColors['MidnightBlue']         := Ptr($FF191970);
  NamedColors['MintCream']            := Ptr($FFF5FFFA);
  NamedColors['MistyRose']            := Ptr($FFFFE4E1);
  NamedColors['Moccasin']             := Ptr($FFFFE4B5);
  NamedColors['NavajoWhite']          := Ptr($FFFFDEAD);
  NamedColors['Navy']                 := Ptr($FF000080);
  NamedColors['OldLace']              := Ptr($FFFDF5E6);
  NamedColors['Olive']                := Ptr($FF808000);
  NamedColors['OliveDrab']            := Ptr($FF6B8E23);
  NamedColors['Orange']               := Ptr($FFFFA500);
  NamedColors['OrangeRed']            := Ptr($FFFF4500);
  NamedColors['Orchid']               := Ptr($FFDA70D6);
  NamedColors['PaleGoldenRod']        := Ptr($FFEEE8AA);
  NamedColors['PaleGreen']            := Ptr($FF98FB98);
  NamedColors['PaleTurquoise']        := Ptr($FFAFEEEE);
  NamedColors['PaleVioletRed']        := Ptr($FFD87093);
  NamedColors['PapayaWhip']           := Ptr($FFFFEFD5);
  NamedColors['PeachPuff']            := Ptr($FFFFDAB9);
  NamedColors['Peru']                 := Ptr($FFCD853F);
  NamedColors['Pink']                 := Ptr($FFFFC0CB);
  NamedColors['Plum']                 := Ptr($FFDDA0DD);
  NamedColors['PowderBlue']           := Ptr($FFB0E0E6);
  NamedColors['Purple']               := Ptr($FF800080);
  NamedColors['Red']                  := Ptr($FFFF0000);
  NamedColors['RosyBrown']            := Ptr($FFBC8F8F);
  NamedColors['RoyalBlue']            := Ptr($FF4169E1);
  NamedColors['SaddleBrown']          := Ptr($FF8B4513);
  NamedColors['Salmon']               := Ptr($FFFA8072);
  NamedColors['SandyBrown']           := Ptr($FFF4A460);
  NamedColors['SeaGreen']             := Ptr($FF2E8B57);
  NamedColors['SeaShell']             := Ptr($FFFFF5EE);
  NamedColors['Sienna']               := Ptr($FFA0522D);
  NamedColors['Silver']               := Ptr($FFC0C0C0);
  NamedColors['SkyBlue']              := Ptr($FF87CEEB);
  NamedColors['SlateBlue']            := Ptr($FF6A5ACD);
  NamedColors['SlateGray']            := Ptr($FF708090);
  NamedColors['Snow']                 := Ptr($FFFFFAFA);
  NamedColors['SpringGreen']          := Ptr($FF00FF7F);
  NamedColors['SteelBlue']            := Ptr($FF4682B4);
  NamedColors['Tan']                  := Ptr($FFD2B48C);
  NamedColors['Teal']                 := Ptr($FF008080);
  NamedColors['Thistle']              := Ptr($FFD8BFD8);
  NamedColors['Tomato']               := Ptr($FFFF6347);
  NamedColors['Turquoise']            := Ptr($FF40E0D0);
  NamedColors['Violet']               := Ptr($FFEE82EE);
  NamedColors['Wheat']                := Ptr($FFF5DEB3);
  NamedColors['White']                := Ptr($FFFFFFFF);
  NamedColors['WhiteSmoke']           := Ptr($FFF5F5F5);
  NamedColors['Yellow']               := Ptr($FFFFFF00);
  NamedColors['YellowGreen']          := Ptr($FF9ACD32);
  NamedColors['r']                    := Ptr($FFF2223E);
  NamedColors['g']                    := Ptr(Heroes.HEROES_GOLD_COLOR_CODE);
  NamedColors['b']                    := NamedColors['Blue'];
  NamedColors['y']                    := NamedColors['Yellow'];
  NamedColors['w']                    := NamedColors['White'];
  NamedColors['o']                    := NamedColors['Orange'];
  NamedColors['p']                    := NamedColors['Purple'];
  NamedColors['a']                    := NamedColors['Aqua'];
end; // .procedure NameStdColors

procedure NameColor (Color32: integer; const Name: string);
begin
  NamedColors[Name] := Ptr(Color32);
end;

function IsChineseLoaderPresent (out ChineseHandler: pointer): boolean;
begin
  result := pbyte($4B5202)^ = $E9;

  if result then begin
    ChineseHandler  := Ptr(pinteger($4B5203)^ + integer($4B5207));
  end;
end;

(* Loads def image and caches it forever for fast drawing *)
function LoadDefImage (const FileName: string): {n} Heroes.PDefItem;
begin
  result := LoadedResources[FileName];

  if result = nil then begin
    result := Heroes.LoadDef(FileName);

    if result <> nil then begin
      LoadedResources[FileName] := result;
    end;
  end;
end;

function GetGraphemWidth (Font: Heroes.PFontItem; Graphem: pchar; out GraphemSize: integer): integer;
var
  CharInfo: Heroes.PFontCharInfo;

begin
  if ChineseLoaderOpt and (Graphem^ > MAX_CHINESE_LATIN_CHARACTER) and (Graphem[1] > MAX_CHINESE_LATIN_CHARACTER) then begin
    result      := ChineseGraphemWidthEstimator(Font);
    GraphemSize := 2;
  end else begin
    CharInfo    := @Font.CharInfos[Graphem^];
    result      := CharInfo.SpaceBefore + CharInfo.Width + CharInfo.SpaceAfter;
    GraphemSize := 1;
  end;
end;

function ReadEmlValue: string;
begin
  result := '';

  if TextScanner.c = '"' then begin
    TextScanner.GotoNextChar();
    TextScanner.ReadTokenTillDelim(['"'], result);
    TextScanner.GotoNextChar();
  end else begin
    TextScanner.ReadTokenTillDelim([' ', ':', '}'], result);
  end;
end;

function ReadEmlIntValue (DefValue: integer): integer;
begin
  if not SysUtils.TryStrToInt(ReadEmlValue, result) then begin
    result := DefValue;
  end;
end;

(* Either reuses existing array or creates new one if nil is passed *)
function ParseEmlAttrs ({On} Attrs: {O} TDict {of TString}): {UO} TDict {of TString};
var
  Key:   string;
  Value: string;
  c:     char;

begin
  result := Attrs;

  if result <> nil then begin
    result.Clear;
  end else begin
    result := DataLib.NewDict(Utils.OWNS_ITEMS, DataLib.CASE_SENSITIVE);
  end;

  TextScanner.SkipCharset(BLANKS);
  c := TextScanner.c;

  while not (c in [#0, '}']) do begin
    TextScanner.ReadTokenTillDelim(['}', ' ', '='], Key);
    Value := '';

    if TextScanner.c = '=' then begin
      TextScanner.GotoNextChar;
      Value := ReadEmlValue;
    end;

    result[Key] := TString.Create(Value);

    TextScanner.SkipCharset(BLANKS);
    c := TextScanner.c;
  end; // .while
end; // .function ParseEmlAttrs

// var
//   List: TList;

constructor TParsedText.Create (const OrigText: string; {U} Font: Heroes.PFontItem);
const
  LINE_END_MARKER         = #10;
  NBSP                    = #160;
  RGBA_COLOR_CODE_MIN_LEN = 7;

var
{U} Buf:      pchar;
    StartPos: integer;
    c:        char;

{U}  TextBlock:       PTextBlock;
{On} EmlAttrs:        {O} TDict {of TString};
{Un} AttrValue:       TString;
     BlockLen:        integer;
     IsTag:           boolean;
     IsEraTag:        boolean;
     IsEmbeddedImage: boolean;
     NumSpaceChars:   integer;
     VertAlignHash:   integer;
     ValueHash:       integer;
     LinesHeight:     integer;
     ImageWidth:      integer;

     TempStr:     string;
     FontName:    string absolute TempStr;
     ColorName:   string absolute TempStr;
     DefName:     string absolute TempStr;
     FrameIndStr: string absolute TempStr;
     TagName:     string;

     NativeTag:      char;
     NbspWidth:      integer;
     NumFillChars:   integer;
     CharInfo:       Heroes.PFontCharInfo;
     CurrColor:      integer;
     CurrHorizAlign: integer;
     ResLen:         integer;
     i:              integer;

  procedure BeginNewColorBlock;
  begin
    if (TextBlock.BlockType <> TEXT_BLOCK_CHARS) or (TextBlock.BlockLen > 0) then begin
      New(TextBlock);
      Self.Blocks.Add(TextBlock);
      TextBlock.BlockLen       := 0;
      TextBlock.BlockType      := TEXT_BLOCK_CHARS;
      TextBlock.HorizAlignment := CurrHorizAlign;
    end;
  end;

  procedure PopTextAttrsTuple;
  const
    TEXT_ATTRS_TUPLE_SIZE = 2;

  var
    StackSize: integer;

  begin
    StackSize := TextAttrsStack.Count;

    if StackSize > 0 then begin
      TextAttrsStack.SetCount(StackSize - TEXT_ATTRS_TUPLE_SIZE);
    end;

    if StackSize > TEXT_ATTRS_TUPLE_SIZE then begin
      CurrColor      := integer(TextAttrsStack[StackSize - TEXT_ATTRS_TUPLE_SIZE - 2]);
      CurrHorizAlign := integer(TextAttrsStack[StackSize - TEXT_ATTRS_TUPLE_SIZE - 1]);
    end else begin
      CurrColor      := DEF_COLOR;
      CurrHorizAlign := DEF_ALIGNMENT;
    end;
  end;

  procedure HandleColorTag (const ColorName: string);
  begin
    CurrColor := 0;

    if NamedColors.GetExistingValue(ColorName, pointer(CurrColor)) then begin
      // Ok
    end else if SysUtils.TryStrToInt('$' + ColorName, CurrColor) then begin
      if Length(ColorName) < RGBA_COLOR_CODE_MIN_LEN then begin
        CurrColor := CurrColor or Graph.FULLY_OPAQUE_MASK32;
      end else begin
        CurrColor := ((CurrColor and $FF) shl 24) or ((CurrColor shr 8) and Graph.RGB_MASK_32);
      end;
    end else begin
      CurrColor := DEF_COLOR;
    end;
  end;

  procedure HandleHorizAlignTag (const AttrValue: string);
  begin
    ValueHash := Crypto.AnsiCrc32(AttrValue);

    case ValueHash of
      TOKEN_HASH_LEFT:   CurrHorizAlign := Heroes.TEXT_ALIGN_LEFT;
      TOKEN_HASH_CENTER: CurrHorizAlign := Heroes.TEXT_ALIGN_CENTER;
      TOKEN_HASH_RIGHT:  CurrHorizAlign := Heroes.TEXT_ALIGN_RIGHT;
    end;
  end;

begin
  inherited Create;

  Buf       := @GlobalBuffer[0];
  EmlAttrs  := nil;
  AttrValue := nil;
  // * * * * * //
  Self.Blocks   := Lists.NewList(Utils.OWNS_ITEMS, not Utils.ITEMS_ARE_OBJECTS, Utils.NO_TYPEGUARD, not Utils.ALLOW_NIL);
  Self.OrigText := OrigText;
  Self.Font     := Font;
  New(TextBlock);
  Self.Blocks.Add(TextBlock);

  TextBlock.BlockLen           := Length(OrigText);
  TextBlock.BlockType          := TEXT_BLOCK_CHARS;
  TextBlock.CharsBlock.Color32 := DEF_COLOR;
  TextBlock.HorizAlignment     := DEF_ALIGNMENT;
  CurrColor                    := DEF_COLOR;
  CurrHorizAlign               := DEF_ALIGNMENT;
  NativeTag                    := #0;

  FontName := pchar(@Font.Name);

  if LoadedResources[FontName] = nil then begin
    LoadedResources[FontName] := Font;
    Inc(Font.RefCount);
  end;

  if Length(OrigText) <= sizeof(GlobalBuffer) - 1 then begin
    TextAttrsStack.Clear;
    TextScanner.Connect(OrigText, LINE_END_MARKER);

    while not TextScanner.EndOfText do begin
      StartPos        := TextScanner.Pos;
      NumSpaceChars   := 0;
      IsTag           := false;
      IsEraTag        := false;
      IsEmbeddedImage := false;

      while not IsTag and TextScanner.GetCurrChar(c) do begin
        if c in ['{', '}'] then begin
          IsTag           := true;
          NativeTag       := c;
          IsEraTag        := TextScanner.CharsRel[1] = '~';
          IsEmbeddedImage := IsEraTag and (TextScanner.CharsRel[2] = '>');
        end else if c in [#10, ' '] then begin
          Inc(NumSpaceChars);
        end else if ChineseLoaderOpt and (c > MAX_CHINESE_LATIN_CHARACTER) and (TextScanner.CharsRel[1] > MAX_CHINESE_LATIN_CHARACTER) then begin
          Inc(NumSpaceChars);
          TextScanner.GotoNextChar;
        end;

        if not IsTag then begin
          TextScanner.GotoNextChar;
        end;
      end; // .while

      // Output normal characters to result buffer
      BlockLen           := TextScanner.Pos - StartPos;
      Utils.CopyMem(BlockLen, pointer(@OrigText[StartPos]), Buf);
      Buf                := Utils.PtrOfs(Buf, BlockLen);
      TextBlock.BlockLen := BlockLen - NumSpaceChars;

      // Text ended
      if not IsTag then begin
        break;
      end;

      if IsEmbeddedImage then begin
        TextScanner.GotoRelPos(+3);

        New(TextBlock);
        Self.Blocks.Add(TextBlock);
        TextBlock.BlockLen               := 0;
        TextBlock.BlockType              := TEXT_BLOCK_DEF;
        TextBlock.HorizAlignment         := CurrHorizAlign;
        TextBlock.ImgBlock.IsBlock       := false;
        TextBlock.ImgBlock.DrawFlags     := [Heroes.DFL_CROP];
        TextBlock.ImgBlock.CharsPerLine  := 0;
        TextBlock.ImgBlock.OffsetX       := 0;
        TextBlock.ImgBlock.OffsetY       := 0;
        TextBlock.ImgBlock.Height        := 0;
        TextBlock.ImgBlock.NumLines      := 1;
        TextBlock.DefBlock.Def           := nil;
        TextBlock.DefBlock.GroupInd      := 0;
        TextBlock.DefBlock.FrameInd      := 0;
        TextBlock.ImgBlock.AttrVertAlign := TOKEN_HASH_MIDDLE;

        DefName := ReadEmlValue;

        if DefName <> '' then begin
          DefName                    := SysUtils.AnsiLowerCase(DefName);
          TextBlock.DefBlock.DefName := Memory.UniqueStrings[pchar(DefName)];

          if Length(DefName) <= 4096 then begin
            TextBlock.DefBlock.Def := LoadDefImage(DefName);
          end;

          if TextScanner.c = ':' then begin
            TextScanner.GotoNextChar();
            TextBlock.DefBlock.FrameInd := ReadEmlIntValue(0);

            if TextScanner.c = ':' then begin
              TextScanner.GotoNextChar();
              TextBlock.DefBlock.GroupInd := TextBlock.DefBlock.FrameInd;
              TextBlock.DefBlock.FrameInd := ReadEmlIntValue(0);
            end;
          end; // .if
        end; // .if

        EmlAttrs                   := ParseEmlAttrs(EmlAttrs);
        TextBlock.ImgBlock.IsBlock := EmlAttrs['block'] <> nil;

        if EmlAttrs['mirror'] <> nil then begin
          System.Include(TextBlock.ImgBlock.DrawFlags, Heroes.DFL_MIRROR);
        end;

        if TextBlock.DefBlock.Def <> nil then begin
          CharInfo                        := @Font.CharInfos[NBSP];
          NbspWidth                       := Math.Max(1, CharInfo.SpaceBefore + CharInfo.Width + CharInfo.SpaceAfter);
          ImageWidth                      := TextBlock.DefBlock.Def.GetFrameWidth(TextBlock.DefBlock.GroupInd, TextBlock.DefBlock.FrameInd);
          NumFillChars                    := (ImageWidth + NbspWidth - 1) div NbspWidth;
          TextBlock.ImgBlock.CharsPerLine := Math.Max(1, NumFillChars);
          TextBlock.ImgBlock.Height       := TextBlock.DefBlock.Def.GetFrameHeight(TextBlock.DefBlock.GroupInd, TextBlock.DefBlock.FrameInd);
          TextBlock.ImgBlock.OffsetX      := (NumFillChars * NbspWidth - ImageWidth) div 2;
          TextBlock.BlockLen              := NumFillChars;

          if TextBlock.ImgBlock.IsBlock then begin
            TextBlock.ImgBlock.NumLines := (TextBlock.ImgBlock.Height + Font.Height - 1) div Font.Height;
          end;

          LinesHeight   := TextBlock.ImgBlock.NumLines * Font.Height;
          VertAlignHash := TOKEN_HASH_MIDDLE;
          AttrValue     := EmlAttrs['valign'];

          if AttrValue <> nil then begin
            ValueHash := Crypto.AnsiCrc32(AttrValue.Value);

            if (ValueHash = TOKEN_HASH_TOP) or (ValueHash = TOKEN_HASH_BOTTOM) then begin
              VertAlignHash := ValueHash;
            end;
          end;

          case VertAlignHash of
            TOKEN_HASH_MIDDLE: TextBlock.ImgBlock.OffsetY := (LinesHeight - TextBlock.ImgBlock.Height) div 2;
            TOKEN_HASH_BOTTOM: TextBlock.ImgBlock.OffsetY := LinesHeight - TextBlock.ImgBlock.Height;
          end;

          TextBlock.ImgBlock.AttrVertAlign := VertAlignHash;

          BeginNewColorBlock;
          TextBlock.CharsBlock.Color32 := CurrColor;
          TextBlock.HorizAlignment     := CurrHorizAlign;

          // Output serie of non-breaking spaces to compensate image width
          for i := 0 to NumFillChars - 1 do begin
            Buf^ := NBSP;
            Inc(Buf);
          end;
        end;

        TextScanner.GotoNextChar();

        continue;
      end; // .if

      // Handle native '{', '}' tags
      if not IsEraTag then begin
        BeginNewColorBlock;

        if NativeTag = '}' then begin
          PopTextAttrsTuple;
        end else begin
          CurrColor := HEROES_GOLD_COLOR_CODE;
          TextAttrsStack.Add(Ptr(CurrColor));
          TextAttrsStack.Add(Ptr(CurrHorizAlign));
        end;

        TextBlock.CharsBlock.Color32 := CurrColor;
        TextBlock.HorizAlignment     := CurrHorizAlign;
        TextScanner.GotoNextChar;
      // Handle other ERL open/close tags
      end else if TextScanner.GotoRelPos(+2) and TextScanner.ReadTokenTillDelim(['}', ' '], TagName) then begin
        BeginNewColorBlock;

        if TagName = '' then begin
          TextScanner.FindChar('}');
          PopTextAttrsTuple;
        end else begin
          EmlAttrs := ParseEmlAttrs(EmlAttrs);

          // Treat '{~xxx' as color tag, unless it's new text tag with optional "color" attribute
          if TagName <> 'text' then begin
            HandleColorTag(TagName);
          end else begin
            AttrValue := EmlAttrs['color'];

            if AttrValue <> nil then begin
              HandleColorTag(AttrValue.Value);
            end;
          end;

          AttrValue := EmlAttrs['align'];

          if AttrValue <> nil then begin
            HandleHorizAlignTag(AttrValue.Value);
          end;

          TextAttrsStack.Add(Ptr(CurrColor));
          TextAttrsStack.Add(Ptr(CurrHorizAlign));
        end; // .else

        TextBlock.CharsBlock.Color32 := CurrColor;
        TextBlock.HorizAlignment     := CurrHorizAlign;
        TextScanner.GotoNextChar;
      end; // .elseif
    end; // .while
  end; // .if

  ResLen := integer(Buf) - integer(@GlobalBuffer[0]);
  {!} Assert(ResLen < sizeof(GlobalBuffer), 'Huge text exceeded ERA ParseText buffer capacity');

  SetLength(Self.ProcessedText, ResLen);

  if ResLen > 0 then begin
    Utils.CopyMem(ResLen, @GlobalBuffer[0], @Self.ProcessedText[1]);
  end;

  Self.NumBlocks := Self.Blocks.Count;

  // if Self.NumBlocks > 1 then begin
  //   List := Self.ToLines(400);

  //   for i := 0 to List.Count - 1 do begin
  //     TParsedTextLine(List[i]).ToTaggedText(Self, TaggedLineBuilder);
  //     VarDump(['LineN:', i + 1, TaggedLineBuilder.BuildStr()]);
  //   end;
  // end;

  // * * * * * //
  SysUtils.FreeAndNil(EmlAttrs);
end; // .function TParsedText.Create

destructor TParsedText.Destroy;
begin
  SysUtils.FreeAndNil(Self.Blocks);
end;

function TParsedText.ToLines (BoxWidth: integer): {O} TList {of TParsedTextLine};
type
  TSavepoint = record
    TextPtr:  pchar;
    BlockInd: integer;
    BlockPos: integer;
    Len:      integer;
  end;

var
{O} Line:            TParsedTextLine;
    LineStart:       TSavepoint;
    LastWordEnd:     TSavepoint;
    Cursor:          TSavepoint;
    CurrBlock:       PTextBlock;
    LineWidth:       integer;
    GraphemWidth:    integer;
    GraphemSize:     integer;
    PrevGraphemSize: integer;
    TextStart:       pchar;
    NumBlocks:       integer;
    c:               char;

begin
  Line := nil;
  // * * * * * //
  result := DataLib.NewList(Utils.OWNS_ITEMS);

  if Self.ProcessedText = '' then begin
    exit;
  end;

  NumBlocks := Self.NumBlocks;
  CurrBlock := Self.Blocks[0];

  TextStart := pchar(Self.ProcessedText);
  c         := #0;

  LineStart.TextPtr  := TextStart;
  LineStart.BlockInd := 0;
  LineStart.BlockPos := 0;
  LineStart.Len      := 0;

  LastWordEnd := LineStart;
  Cursor      := LineStart;

  // Handle all lines
  repeat
    LineWidth       := 0;
    PrevGraphemSize := 0;

    // Handle single line
    while true do begin
      c := Cursor.TextPtr^;

      // End of text/line
      if c in [#0, #10] then begin
        break;
      end;

      GraphemWidth := GetGraphemWidth(Self.Font, Cursor.TextPtr, GraphemSize);
      Inc(LineWidth, GraphemWidth);

      if LineWidth > BoxWidth then begin
        if c = ' ' then begin
          break;
        // This word should be wrapped, fallback to the previous word
        end else if LastWordEnd.TextPtr <> LineStart.TextPtr then begin
          Cursor    := LastWordEnd;
          CurrBlock := Self.Blocks[Cursor.BlockInd];
          break;
        end;
      end;

      // Track word end
      if (GraphemSize > 1) or (PrevGraphemSize > 1) or ((c = ' ') and (Cursor.TextPtr <> LineStart.TextPtr) and (Cursor.TextPtr[-1] <> ' ')) then begin
        LastWordEnd := Cursor;
      end;

      // Move position in text
      Inc(Cursor.TextPtr, GraphemSize);
      Inc(Cursor.Len,     GraphemSize);

      PrevGraphemSize := GraphemSize;

      // Move position in block
      if c <> ' ' then begin
        Inc(Cursor.BlockPos);

        while (Cursor.BlockPos >= CurrBlock.BlockLen) and (Cursor.BlockInd + 1 < NumBlocks) do begin
          Inc(Cursor.BlockInd);
          Cursor.BlockPos := 0;
          CurrBlock       := Self.Blocks[Cursor.BlockInd];
        end;
      end;
    end; // .while

    // Create new line
    Line          := TParsedTextLine.Create;
    Line.Offset   := integer(LineStart.TextPtr) - integer(TextStart);
    Line.BlockInd := LineStart.BlockInd;
    Line.BlockPos := LineStart.BlockPos;
    Line.Len      := Cursor.Len;

    // Add the line to the result
    result.Add(Line); Line := nil;

    // Skip line end character
    if c = #10 then begin
      Inc(Cursor.TextPtr);
    // Skip trailing spaces
    end else begin
      while Cursor.TextPtr^ = ' ' do begin
        Inc(Cursor.TextPtr);
      end;
    end;

    // Init next line
    Cursor.Len  := 0;
    LineStart   := Cursor;
    LastWordEnd := Cursor;
  until Cursor.TextPtr^ = #0;
  // * * * * * //
  {!} Assert(Line = nil);
end; // .function TParsedText.ToLines

function TParsedText.CountLines (BoxWidth: integer): integer;
var
  {O} Lines: {O} TList {of TParsedTextLine};

begin
  Lines  := Self.ToLines(BoxWidth);
  result := Lines.Count;
  SysUtils.FreeAndNil(Lines);
end;

procedure TParsedTextLine.ToTaggedText (ParsedText: TParsedText; Res: StrLib.TStrBuilder);
var
  Text:              pchar;
  TextEnd:           pchar;
  SliceStart:        pchar;
  SliceLen:          integer;
  BlockInd:          integer;
  BlockPos:          integer;
  CurrBlock:         PTextBlock;
  NumBlocks:         integer;
  InitialHorizAlign: integer;

begin
  Res.Clear;

  if Self.Len <= 0 then begin
    exit;
  end;

  // Init
  Text      := Utils.PtrOfs(pchar(ParsedText.ProcessedText), Self.Offset);
  TextEnd   := Utils.PtrOfs(Text, Self.Len);
  BlockInd  := Self.BlockInd;
  BlockPos  := Self.BlockPos;
  NumBlocks := ParsedText.NumBlocks;
  CurrBlock := ParsedText.Blocks[BlockInd];

  // Skip leading empty blocks
  while (BlockPos >= CurrBlock.BlockLen) and (BlockInd + 1 < NumBlocks) do begin
    Inc(BlockInd);
    BlockPos  := 0;
    CurrBlock := ParsedText.Blocks[BlockInd];
  end;

  // Always output text alignment tag as whole line wrapper tag, unless it's default alignment
  InitialHorizAlign := CurrBlock.HorizAlignment;

  if InitialHorizAlign <> DEF_ALIGNMENT then begin
    case InitialHorizAlign of
      Heroes.TEXT_ALIGN_LEFT:   Res.Append('{~text align=left}');
      Heroes.TEXT_ALIGN_CENTER: Res.Append('{~text align=center}');
      Heroes.TEXT_ALIGN_RIGHT:  Res.Append('{~text align=right}');
    end;
  end;

  // Process each physical line character
  while Text < TextEnd do begin
    {!} Assert(BlockPos < CurrBlock.BlockLen);
    SliceStart := Text;

    // Output block opening tag, if necessary
    case CurrBlock.BlockType of
      TEXT_BLOCK_CHARS: begin
        Res.Append('{~');
        Res.Append(Color32ToCode(CurrBlock.CharsBlock.Color32));

        if CurrBlock.HorizAlignment <> DEF_ALIGNMENT then begin
          case CurrBlock.HorizAlignment of
            Heroes.TEXT_ALIGN_LEFT:   Res.Append(' align=left');
            Heroes.TEXT_ALIGN_CENTER: Res.Append(' align=center');
            Heroes.TEXT_ALIGN_RIGHT:  Res.Append(' align=right');
          end;
        end;

        Res.Append('}');
      end;

      TEXT_BLOCK_DEF: begin
        Res.Append('{~>');
        Res.AppendBuf(Windows.LStrLen(CurrBlock.DefBlock.DefName), CurrBlock.DefBlock.DefName);

        if (CurrBlock.DefBlock.GroupInd <> 0) or (CurrBlock.DefBlock.FrameInd <> 0) then begin
          Res.Append(':' + SysUtils.IntToStr(CurrBlock.DefBlock.GroupInd));
          Res.Append(':' + SysUtils.IntToStr(CurrBlock.DefBlock.FrameInd));
        end;

        if CurrBlock.ImgBlock.AttrVertAlign <> TOKEN_HASH_MIDDLE then begin
          case CurrBlock.ImgBlock.AttrVertAlign of
            TOKEN_HASH_TOP:    Res.Append(' valign=top');
            TOKEN_HASH_BOTTOM: Res.Append(' valign=bottom');
          end;
        end;

        if Heroes.DFL_MIRROR in CurrBlock.ImgBlock.DrawFlags then begin
          Res.Append(' mirror');
        end;

        if CurrBlock.ImgBlock.IsBlock then begin
          Res.Append(' block');
        end;

        Res.Append('}');
      end;
    else
      {!} Assert(false, 'ToTaggedText: unsupported BlockType = ' + SysUtils.IntToStr(ord(CurrBlock.BlockType)));
    end; // .switch CurrBlock.BlockType

    // Skip block meaningful characters
    if CurrBlock.BlockType <> TEXT_BLOCK_CHARS then begin
      BlockPos   := CurrBlock.BlockLen;
      Text       := pointer(Min(cardinal(TextEnd), cardinal(Text) + cardinal(CurrBlock.BlockLen)));
      SliceStart := Text;
    end else begin
      while (Text < TextEnd) and (BlockPos < CurrBlock.BlockLen) do begin
        if not (Text^ in [#10, ' ']) then begin
          Inc(BlockPos);

          if ChineseLoaderOpt and (Text^ > MAX_CHINESE_LATIN_CHARACTER) and (Text[1] > MAX_CHINESE_LATIN_CHARACTER) then begin
            Inc(Text);
          end;
        end;

        Inc(Text);
      end;
    end; // .else

    // Skip out-of-block spacy characters
    while (Text < TextEnd) and (Text^ in [#10, ' ']) do begin
      Inc(Text);
    end;

    SliceLen := integer(Text) - integer(SliceStart);
    Res.AppendBuf(SliceLen, SliceStart);

    // Output closing block tag
    case CurrBlock.BlockType of
      TEXT_BLOCK_CHARS: begin
        Res.Append('{~}');
      end;
    end;

    // Proceed to the next non-empty block
    if Text < TextEnd then begin
      while (BlockPos >= CurrBlock.BlockLen) and (BlockInd + 1 < NumBlocks) do begin
        Inc(BlockInd);
        BlockPos  := 0;
        CurrBlock := ParsedText.Blocks[BlockInd];
      end;
    end;
  end; // .while

  // Always output text alignment tag as whole line wrapper tag, unless it's default alignment
  if InitialHorizAlign <> DEF_ALIGNMENT then begin
    Res.Append('{~}');
  end;
end; // .procedure TParsedTextLine.ToTaggedText

function UpdateCurrParsedText (Font: Heroes.PFontItem; OrigStr: pchar; OrigTextLen: integer = -1): {U} TParsedText;
var
  OrigText: string;

begin
  if OrigTextLen < 0 then begin
    OrigTextLen := Windows.LStrLen(OrigStr);
  end;

  if (CurrParsedText <> nil) and ((OrigTextLen <> Length(CurrParsedText.OrigText)) or (StrLib.ComparePchars(OrigStr, pchar(CurrParsedText.OrigText)) <> 0)) then begin
    SysUtils.FreeAndNil(CurrParsedText);
  end;

  if CurrParsedText = nil then begin
    OrigText       := '';
    SetString(OrigText, OrigStr, OrigTextLen);
    CurrParsedText := TParsedText.Create(OrigText, Font);
  end;

  result := CurrParsedText;
end; // .function UpdateCurrParsedText

(* Determines current block, based on position in block, number of blocks left and block length.
   Automatically skips/applies empty blocks. Updates current color if necessary *)
procedure UpdateCurrBlock; stdcall;
begin
  if (CurrParsedText <> nil) and (CurrTextBlock <> nil) then begin
    if CurrBlockPos < CurrTextBlock.BlockLen then begin
      CurrHorizAlign := CurrTextBlock.HorizAlignment;

      if CurrHorizAlign <> DEF_ALIGNMENT then begin
        CurrTextAlignPtr^ := (CurrTextAlignPtr^ and not Heroes.HORIZ_TEXT_ALIGNMENT_MASK) or CurrHorizAlign;
      end else begin
        CurrTextAlignPtr^ := CurrTextDefAlign;
      end;

      if CurrTextBlock.BlockType = TEXT_BLOCK_CHARS then begin
        CurrColor := CurrTextBlock.CharsBlock.Color32;
      end;
    end else begin
      while CurrBlockPos >= CurrTextBlock.BlockLen do begin
        CurrBlockPos := 0;
        Inc(CurrBlockInd);

        // Normal, valid case
        if CurrBlockInd < CurrParsedText.NumBlocks then begin
          CurrTextBlock  := CurrParsedText.Blocks[CurrBlockInd];
          CurrHorizAlign := CurrTextBlock.HorizAlignment;

          if CurrHorizAlign <> DEF_ALIGNMENT then begin
            CurrTextAlignPtr^ := (CurrTextAlignPtr^ and not Heroes.HORIZ_TEXT_ALIGNMENT_MASK) or CurrHorizAlign;
          end else begin
            CurrTextAlignPtr^ := CurrTextDefAlign;
          end;

          if CurrTextBlock.BlockType = TEXT_BLOCK_CHARS then begin
            CurrColor := CurrTextBlock.CharsBlock.Color32;
          end;
        // Something is broken, like invalid GBK character (missing second part of code point), mixed language, etc.
        // Empty string, probably. Recover to use the last attributes.
        end else begin
          CurrBlockInd := CurrParsedText.NumBlocks - 1;
          CurrBlockPos := CurrTextBlock.BlockLen;

          break;
        end;
      end; // .while
    end; // .else
  end; // .if
end; // .procedure UpdateCurrBlock

function Hook_BeginParseText (Context: Core.PHookContext): longbool; stdcall;  
begin
  UpdateCurrParsedText(Heroes.PFontItem(Context.EBX), pchar(Context.EDX), Context.ECX);
  CurrTextNumLines := CurrParsedText.CountLines(pinteger(Context.EBP + $18)^);

  CurrColor        := DEF_COLOR;
  CurrHorizAlign   := DEF_ALIGNMENT;
  CurrTextAlignPtr := Ptr(Context.EBP + $24);
  CurrTextDefAlign := CurrTextAlignPtr^;
  CurrTextBlock    := CurrParsedText.Blocks[0];
  CurrBlockPos     := 0;
  CurrBlockInd     := 0;

  UpdateCurrBlock;
  CurrBlockPos := -1;

  Context.ECX                  := Length(CurrParsedText.ProcessedText);
  Context.EDX                  := integer(pchar(CurrParsedText.ProcessedText));
  pinteger(Context.EBP - $14)^ := Context.ECX;
  pinteger(Context.EBP + $8)^  := Context.EDX;

  if ChineseLoaderOpt then begin
    Context.ECX     := Context.EBX;
    Context.RetAddr := ChineseHandler;
  end else begin
    // Overwritten Code
    if (pinteger(Context.EBP + $24)^ and 4) = 0 then begin
      Context.RetAddr := Ptr($4B52B2);
    end else begin
      Context.RetAddr := Ptr($4B525B);
    end;
  end; // .else

  result := not Core.EXEC_DEF_CODE;
end; // .function Hook_BeginParseText

function Hook_CountNumTextLines (Text: pchar; BoxWidth: integer): integer; stdcall;
begin
  result := CurrTextNumLines;
end;

function Hook_ScrollTextDlg_CreateLineTextItem: integer; stdcall; assembler;
const
  SCROLLBAR_WIDTH = 24;

asm
  sub dword [esp + $0C], SCROLLBAR_WIDTH
  mov eax, $5BC6A0
  jmp eax
end;

function Hook_Font_DrawTextToPcx16_End (Context: ApiJack.PHookContext): longbool; stdcall;
begin
  CurrColor     := DEF_COLOR;
  CurrTextBlock := nil;
  result        := true;
end;

function Hook_GetCharColor (Context: Core.PHookContext): longbool; stdcall;
begin
  result := CurrColor = DEF_COLOR;

  if not result then begin
    Context.EAX := CurrColor;
  end;
end;

function Hook_HandleTags (Context: Core.PHookContext): longbool; stdcall;
var
  c:  char;

begin
  c                           := PCharByte(Context.EDX)^;
  PCharByte(Context.EBP - 4)^ := c;
  Context.RetAddr             := Ptr($4B50BA);

  if not (c in [#10, ' ']) then begin
    Inc(CurrBlockPos);
    UpdateCurrBlock;
  end;

  result := not Core.EXEC_DEF_CODE;
end; // .function Hook_HandleTags

function New_Font_CountNumTextLines (OrigFunc: pointer; Font: Heroes.PFontItem; Text: pchar; BoxWidth: integer): integer; stdcall;
begin
  UpdateCurrParsedText(Font, Text);
  result := CurrParsedText.CountLines(BoxWidth);
end;

function New_Font_GetLineWidth (OrigFunc: pointer; Font: Heroes.PFontItem; Line: pchar): integer; stdcall;
begin
  UpdateCurrParsedText(Font, Line);

  result := PatchApi.Call(THISCALL_, OrigFunc, [Font, pchar(CurrParsedText.ProcessedText)]);
end;

function New_Font_GetMaxLineWidth (OrigFunc: pointer; Font: Heroes.PFontItem; Line: pchar): integer; stdcall;
begin
  UpdateCurrParsedText(Font, Line);

  result := PatchApi.Call(THISCALL_, OrigFunc, [Font, pchar(CurrParsedText.ProcessedText)]);
end;

function New_Font_GetMaxWordWidth (OrigFunc: pointer; Font: Heroes.PFontItem; Line: pchar): integer; stdcall;
begin
  UpdateCurrParsedText(Font, Line);

  result := PatchApi.Call(THISCALL_, OrigFunc, [Font, pchar(CurrParsedText.ProcessedText)]);
end;

function New_Font_GetTextWidthForBox (OrigFunc: pointer; Font: Heroes.PFontItem; Line: pchar; BoxWidth: integer): integer; stdcall;
begin
  UpdateCurrParsedText(Font, Line);

  result := PatchApi.Call(THISCALL_, OrigFunc, [Font, pchar(CurrParsedText.ProcessedText), BoxWidth]);
end;

function New_Font_TextToLines (OrigFunc: pointer; Font: Heroes.PFontItem; Text: pchar; BoxWidth: integer; var DlgTextLines: Heroes.TDlgTextLines): integer; stdcall;
var
{O} Lines:   {O} TList {of TParsedTextLine};
    LineStr: string;
    i:       integer;

begin
  Lines := nil;
  // * * * * * //
  UpdateCurrParsedText(Font, Text);
  Lines := CurrParsedText.ToLines(BoxWidth);
  DlgTextLines.Reset;

  for i := 0 to Lines.Count - 1 do begin
    TParsedTextLine(Lines[i]).ToTaggedText(CurrParsedText, TaggedLineBuilder);
    LineStr := TaggedLineBuilder.BuildStr();
    DlgTextLines.AppendLine(pchar(LineStr), Length(LineStr));
  end;

  result := 0;
  // * * * * * //
  SysUtils.FreeAndNil(Lines);
end; // .function New_Font_TextToLines

function ChineseGetCharColor: integer; stdcall;
begin
  result := CurrColor;
end;

procedure ChineseGotoNextChar; stdcall;
begin
  Inc(CurrBlockPos);
  UpdateCurrBlock;
end;

procedure ChineseSetTextAlignmentParamPtr (NewParamPtr: pinteger); stdcall;
begin
  CurrTextAlignPtr := NewParamPtr;
end;

procedure SetChineseGraphemWidthEstimator (Estimator: TGraphemWidthEstimator); stdcall;
begin
  ChineseGraphemWidthEstimator := Estimator;
end;

procedure SetupColorMode;
begin
  if TextColorMode^ = TEXTMODE_15BITS then begin
    Color32To16 := Color32To15Func;
    Color16To32 := Color15To32Func;
  end else if TextColorMode^ = TEXTMODE_16BITS then begin
    Color32To16 := Color32To16Func;
    Color16To32 := Color16To32Func;
  end else begin
    {!} Assert(false, Format('Invalid text color mode: %d', [TextColorMode^]));
  end;

  NameStdColors;
end; // .function Hook_SetupColorMode

function DrawCharacterToPcx (Font: Heroes.PFontItem; Ch: integer; Canvas: Heroes.PPcx16Item; x, y: integer; ColorInd: integer): Heroes.PPcx16Item;
var
  CharWidth:       integer;
  FontHeight:      integer;
  CharPixelPtr:    pbyte;
  OutRowStartPtr:  pword;
  OutPixelPtr:     pword;
  BytesPerPixel:   integer;
  CharPixel:       integer;
  Color32:         integer;
  CurrColor32:     integer;
  ShadowColor32:   integer;
  ColorOpaqueness: integer;
  i, j:            integer;
  c:               char;

begin
  result := Heroes.PPcx16Item(Ch); // Vanilla code. Like error marker?

  if (Ch >= 0) and (Ch <= 255) then begin
    BytesPerPixel := BytesPerPixelPtr^;
    c             := chr(Ch);
    CharWidth     := Font.CharInfos[c].Width;
    FontHeight    := Font.Height;
    ShadowColor32 := Color16To32(Font.Palette16.Colors[32]);
    CurrColor32   := CurrColor;

    if CurrColor32 = DEF_COLOR then begin
      CurrColor32 := Color16To32(Font.Palette16.Colors[ColorInd]);
    end;

    if (CharWidth > 0) and (FontHeight > 0) then begin
      CurrColor32     := Graph.PremultiplyColorChannelsByAlpha(CurrColor32);
      ShadowColor32   := Graph.PremultiplyColorChannelsByAlpha(ShadowColor32);
      ColorOpaqueness := (CurrColor32 and Graph.ALPHA_CHANNEL_MASK_32) shr 24;

      CharPixelPtr   := @Font.CharsDataPtr[Font.CharDataOffsets[c]];
      OutRowStartPtr := Utils.PtrOfs(Canvas.Buffer, y * Canvas.ScanlineSize + (x + Font.CharInfos[c].SpaceBefore) * BytesPerPixel);

      for j := 0 to FontHeight - 1 do begin
        OutPixelPtr := OutRowStartPtr;

        for i := 0 to CharWidth - 1 do begin
          CharPixel := CharPixelPtr^;

          if CharPixel <> 0 then begin
            if CharPixel = 255 then begin
              Color32 := CurrColor32;
            end else begin
              Color32 := (ShadowColor32 and Graph.RGB_MASK_32) or ((((256 - CharPixel) * ColorOpaqueness) and $FF00) shl 16);
            end;

            if BytesPerPixel = sizeof(integer) then begin
              pinteger(OutPixelPtr)^ := Graph.AlphaBlendWithPremultiplied32(pinteger(OutPixelPtr)^, Color32);
            end else begin
              pword(OutPixelPtr)^ := Color32To16(Graph.AlphaBlendWithPremultiplied32(Color16To32(pword(OutPixelPtr)^), Color32));
            end; 
          end; // .if   

          Inc(pbyte(OutPixelPtr), BytesPerPixel);
          Inc(CharPixelPtr);
        end; // .for

        Inc(pbyte(OutRowStartPtr), Canvas.ScanlineSize);
      end; // .for
    end; // .if

    result := Canvas;
  end; // .if
end; // .function DrawCharacterToPcx

function New_Font_DrawCharacter (OrigFunc: pointer; Font: Heroes.PFontItem; Ch: integer; Canvas: Heroes.PPcx16Item; x, y: integer; ColorInd: integer): Heroes.PPcx16Item; stdcall;
var
  Def: Heroes.PDefItem;

begin
  if (CurrParsedText <> nil) and (CurrTextBlock <> nil) and (CurrTextBlock.BlockType = TEXT_BLOCK_DEF) and (CurrTextBlock.DefBlock.Def <> nil) then begin
    Def := CurrTextBlock.DefBlock.Def;

    if CurrBlockPos = 0 then begin
      Def.DrawFrameToBuf(
        CurrTextBlock.DefBlock.GroupInd,
        CurrTextBlock.DefBlock.FrameInd,
        0, 0,
        Def.Width, Def.Height,
        Canvas.Buffer,
        x + CurrTextBlock.ImgBlock.OffsetX, y + CurrTextBlock.ImgBlock.OffsetY,
        Canvas.Width, Canvas.Height,
        Canvas.ScanlineSize,
        CurrTextBlock.ImgBlock.DrawFlags
      );
    end;

    result := Canvas;
  end else begin
    result := DrawCharacterToPcx(Font, Ch, Canvas, x, y, ColorInd);
  end;
end; // .function New_Font_DrawCharacter

procedure OnAfterCreateWindow (Event: GameExt.PEvent); stdcall;
begin
  SetupColorMode; 
  ApiJack.StdSplice(Ptr($4B4F00), @New_Font_DrawCharacter, ApiJack.CONV_THISCALL, 6);
end;

procedure OnAfterWoG (Event: GameExt.PEvent); stdcall;
begin
  ChineseLoaderOpt := IsChineseLoaderPresent(ChineseHandler);

  if ChineseLoaderOpt then begin
    (* Remove Chinese loader hook *)
    pword($4B5202)^    := word($840F); // JE
    pinteger($4B5204)^ := $02E7;       // 4B54EF
  end else begin
    Core.Hook(@Hook_HandleTags, Core.HOOKTYPE_BRIDGE, 7, Ptr($4B509B));
  end; 

  Core.Hook(@Hook_GetCharColor, Core.HOOKTYPE_BRIDGE, 8, Ptr($4B4F74));
  Core.Hook(@Hook_BeginParseText, Core.HOOKTYPE_BRIDGE, 6, Ptr($4B5255));
  Core.Hook(@Hook_CountNumTextLines, Core.HOOKTYPE_CALL, 5, Ptr($4B5275));
  Core.Hook(@Hook_CountNumTextLines, Core.HOOKTYPE_CALL, 5, Ptr($4B52CA));
  Core.Hook(@Hook_ScrollTextDlg_CreateLineTextItem, Core.HOOKTYPE_CALL, 5, Ptr($5BA547));
  ApiJack.HookCode(Ptr($4B54EF), @Hook_Font_DrawTextToPcx16_End);
  ApiJack.StdSplice(Ptr($4B5580), @New_Font_CountNumTextLines, ApiJack.CONV_THISCALL, 3);
  ApiJack.StdSplice(Ptr($4B5680), @New_Font_GetLineWidth, ApiJack.CONV_THISCALL, 2);
  ApiJack.StdSplice(Ptr($4B56F0), @New_Font_GetMaxLineWidth, ApiJack.CONV_THISCALL, 2);
  ApiJack.StdSplice(Ptr($4B5770), @New_Font_GetMaxWordWidth, ApiJack.CONV_THISCALL, 2);
  ApiJack.StdSplice(Ptr($4B57E0), @New_Font_GetTextWidthForBox, ApiJack.CONV_THISCALL, 3);
  ApiJack.StdSplice(Ptr($4B58F0), @New_Font_TextToLines, ApiJack.CONV_THISCALL, 4);

  // Fix TransformInputKey routine to allow entering "{" and "}"
  Core.p.WriteDataPatch(Ptr($5BAFB5), ['EB08']);
end; // .procedure OnAfterWoG

begin
  NamedColors       := AssocArrays.NewSimpleAssocArr(Crypto.AnsiCrc32, SysUtils.AnsiLowerCase);
  LoadedResources   := DataLib.NewDict(not Utils.OWNS_ITEMS, DataLib.CASE_INSENSITIVE);
  TextAttrsStack    := Lists.NewSimpleList;
  TextScanner       := TextScan.TTextScanner.Create;
  TaggedLineBuilder := StrLib.TStrBuilder.Create;

  EventMan.GetInstance.On('OnAfterWoG',          OnAfterWoG);
  EventMan.GetInstance.On('OnAfterCreateWindow', OnAfterCreateWindow);
end.
