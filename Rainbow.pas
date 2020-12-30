unit Rainbow;
(*
  DESCRIPTION: Adds markup language support to all Heroes texts (EML - Era Markup Language).
  AUTHOR:      Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
*)

(***)  interface  (***)
uses
  Math, SysUtils, Windows,
  Utils, Crypto, Lists, AssocArrays, TextScan, ApiJack, PatchApi, DataLib, StrLib, TypeWrappers,
  Core, GameExt, Heroes, Memory, EventMan, DlgMes;

type
  (* Import *)
  TList   = DataLib.TList;
  TDict   = DataLib.TDict;
  TString = TypeWrappers.TString;

const
  MAX_CHINESE_LATIN_CHARACTER = #160;

  TEXTMODE_15BITS = $3E0;
  TEXTMODE_16BITS = $7E0;

  DEF_COLOR = -1;
  
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

(* Chinese only: temporal *)
function  ChineseGetCharColor: integer; stdcall;
procedure ChineseGotoNextChar; stdcall;
procedure SetChineseGraphemWidthEstimator (Estimator: TGraphemWidthEstimator); stdcall;


(***) implementation (***)


exports
  ChineseGetCharColor,
  ChineseGotoNextChar,
  SetChineseGraphemWidthEstimator;


const
  BLANKS = [#0..#32];

  TOKEN_HASH_TOP    = 517545930;
  TOKEN_HASH_MIDDLE = -1635771697;
  TOKEN_HASH_BOTTOM = -1990233436;

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
{O} ColorStack:        {U} Lists.TList {of Color32: integer};
{O} TextScanner:       TextScan.TTextScanner;
{O} TaggedLineBuilder: StrLib.TStrBuilder;
    Color32To16:       TColor32To16Func;
    Color16To32:       function (Color16: integer): integer;

{O} CurrParsedText:   TParsedText = nil;
{U} CurrTextBlock:    PTextBlock  = nil;
    CurrTextNumLines: integer     = 1;

    CurrBlockInd:   integer;
    CurrBlockPos:   integer;
    CurrColor:      integer = DEF_COLOR;
    
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
  result := (({BLUE} (Color16 and $1F) shl 3) or ({GREEN} (Color16 and $7E0) shl 5) or ({RED} (Color16 and $F800) shl 8)) and $FFF8FCF8;
end;

function Color15To32Func (Color15: integer): integer;
begin
  result := (({BLUE} (Color15 and $1F) shl 3) or ({GREEN} (Color15 and $3E0) shl 6) or ({RED} (Color15 and $F800) shl 9)) and $FFF8F8F8;
end;

procedure NameStdColors;
begin
  NamedColors['AliceBlue']            := Ptr($F0F8FF);
  NamedColors['AntiqueWhite']         := Ptr($FAEBD7);
  NamedColors['Aqua']                 := Ptr($00FFFF);
  NamedColors['Aquamarine']           := Ptr($7FFFD4);
  NamedColors['Azure']                := Ptr($F0FFFF);
  NamedColors['Beige']                := Ptr($F5F5DC);
  NamedColors['Bisque']               := Ptr($FFE4C4);
  NamedColors['Black']                := Ptr($000000);
  NamedColors['BlanchedAlmond']       := Ptr($FFEBCD);
  NamedColors['Blue']                 := Ptr($0000FF);
  NamedColors['BlueViolet']           := Ptr($8A2BE2);
  NamedColors['Brown']                := Ptr($A52A2A);
  NamedColors['BurlyWood']            := Ptr($DEB887);
  NamedColors['CadetBlue']            := Ptr($5F9EA0);
  NamedColors['Chartreuse']           := Ptr($7FFF00);
  NamedColors['Chocolate']            := Ptr($D2691E);
  NamedColors['Coral']                := Ptr($FF7F50);
  NamedColors['CornflowerBlue']       := Ptr($6495ED);
  NamedColors['Cornsilk']             := Ptr($FFF8DC);
  NamedColors['Crimson']              := Ptr($DC143C);
  NamedColors['Cyan']                 := Ptr($00FFFF);
  NamedColors['DarkBlue']             := Ptr($00008B);
  NamedColors['DarkCyan']             := Ptr($008B8B);
  NamedColors['DarkGoldenRod']        := Ptr($B8860B);
  NamedColors['DarkGray']             := Ptr($A9A9A9);
  NamedColors['DarkGreen']            := Ptr($006400);
  NamedColors['DarkGrey']             := Ptr($A9A9A9);
  NamedColors['DarkKhaki']            := Ptr($BDB76B);
  NamedColors['DarkMagenta']          := Ptr($8B008B);
  NamedColors['DarkOliveGreen']       := Ptr($556B2F);
  NamedColors['Darkorange']           := Ptr($FF8C00);
  NamedColors['DarkOrchid']           := Ptr($9932CC);
  NamedColors['DarkRed']              := Ptr($8B0000);
  NamedColors['DarkSalmon']           := Ptr($E9967A);
  NamedColors['DarkSeaGreen']         := Ptr($8FBC8F);
  NamedColors['DarkSlateBlue']        := Ptr($483D8B);
  NamedColors['DarkSlateGrey']        := Ptr($2F4F4F);
  NamedColors['DarkTurquoise']        := Ptr($00CED1);
  NamedColors['DarkViolet']           := Ptr($9400D3);
  NamedColors['DeepPink']             := Ptr($FF1493);
  NamedColors['DeepSkyBlue']          := Ptr($00BFFF);
  NamedColors['DimGray']              := Ptr($696969);
  NamedColors['DodgerBlue']           := Ptr($1E90FF);
  NamedColors['FireBrick']            := Ptr($B22222);
  NamedColors['FloralWhite']          := Ptr($FFFAF0);
  NamedColors['ForestGreen']          := Ptr($228B22);
  NamedColors['Fuchsia']              := Ptr($FF00FF);
  NamedColors['Gainsboro']            := Ptr($DCDCDC);
  NamedColors['GhostWhite']           := Ptr($F8F8FF);
  NamedColors['Gold']                 := Ptr($FFD700);
  NamedColors['GoldenRod']            := Ptr($DAA520);
  NamedColors['Gray']                 := Ptr($808080);
  NamedColors['Green']                := Ptr($008000);
  NamedColors['GreenYellow']          := Ptr($ADFF2F);
  NamedColors['Grey']                 := Ptr($808080);
  NamedColors['HoneyDew']             := Ptr($F0FFF0);
  NamedColors['HotPink']              := Ptr($FF69B4);
  NamedColors['IndianRed']            := Ptr($CD5C5C);
  NamedColors['Indigo']               := Ptr($4B0082);
  NamedColors['Ivory']                := Ptr($FFFFF0);
  NamedColors['Khaki']                := Ptr($F0E68C);
  NamedColors['Lavender']             := Ptr($E6E6FA);
  NamedColors['LavenderBlush']        := Ptr($FFF0F5);
  NamedColors['LawnGreen']            := Ptr($7CFC00);
  NamedColors['LemonChiffon']         := Ptr($FFFACD);
  NamedColors['LightBlue']            := Ptr($ADD8E6);
  NamedColors['LightCoral']           := Ptr($F08080);
  NamedColors['LightCyan']            := Ptr($E0FFFF);
  NamedColors['LightGoldenRodYellow'] := Ptr($FAFAD2);
  NamedColors['LightGray']            := Ptr($D3D3D3);
  NamedColors['LightGreen']           := Ptr($90EE90);
  NamedColors['LightGrey']            := Ptr($D3D3D3);
  NamedColors['LightPink']            := Ptr($FFB6C1);
  NamedColors['LightSalmon']          := Ptr($FFA07A);
  NamedColors['LightSeaGreen']        := Ptr($20B2AA);
  NamedColors['LightSkyBlue']         := Ptr($87CEFA);
  NamedColors['LightSlateGray']       := Ptr($778899);
  NamedColors['LightSteelBlue']       := Ptr($B0C4DE);
  NamedColors['LightYellow']          := Ptr($FFFFE0);
  NamedColors['Lime']                 := Ptr($00FF00);
  NamedColors['LimeGreen']            := Ptr($32CD32);
  NamedColors['Linen']                := Ptr($FAF0E6);
  NamedColors['Magenta']              := Ptr($FF00FF);
  NamedColors['Maroon']               := Ptr($800000);
  NamedColors['MediumAquaMarine']     := Ptr($66CDAA);
  NamedColors['MediumBlue']           := Ptr($0000CD);
  NamedColors['MediumOrchid']         := Ptr($BA55D3);
  NamedColors['MediumPurple']         := Ptr($9370D8);
  NamedColors['MediumSeaGreen']       := Ptr($3CB371);
  NamedColors['MediumSlateBlue']      := Ptr($7B68EE);
  NamedColors['MediumSpringGreen']    := Ptr($00FA9A);
  NamedColors['MediumTurquoise']      := Ptr($48D1CC);
  NamedColors['MediumVioletRed']      := Ptr($C71585);
  NamedColors['MidnightBlue']         := Ptr($191970);
  NamedColors['MintCream']            := Ptr($F5FFFA);
  NamedColors['MistyRose']            := Ptr($FFE4E1);
  NamedColors['Moccasin']             := Ptr($FFE4B5);
  NamedColors['NavajoWhite']          := Ptr($FFDEAD);
  NamedColors['Navy']                 := Ptr($000080);
  NamedColors['OldLace']              := Ptr($FDF5E6);
  NamedColors['Olive']                := Ptr($808000);
  NamedColors['OliveDrab']            := Ptr($6B8E23);
  NamedColors['Orange']               := Ptr($FFA500);
  NamedColors['OrangeRed']            := Ptr($FF4500);
  NamedColors['Orchid']               := Ptr($DA70D6);
  NamedColors['PaleGoldenRod']        := Ptr($EEE8AA);
  NamedColors['PaleGreen']            := Ptr($98FB98);
  NamedColors['PaleTurquoise']        := Ptr($AFEEEE);
  NamedColors['PaleVioletRed']        := Ptr($D87093);
  NamedColors['PapayaWhip']           := Ptr($FFEFD5);
  NamedColors['PeachPuff']            := Ptr($FFDAB9);
  NamedColors['Peru']                 := Ptr($CD853F);
  NamedColors['Pink']                 := Ptr($FFC0CB);
  NamedColors['Plum']                 := Ptr($DDA0DD);
  NamedColors['PowderBlue']           := Ptr($B0E0E6);
  NamedColors['Purple']               := Ptr($800080);
  NamedColors['Red']                  := Ptr($FF0000);
  NamedColors['RosyBrown']            := Ptr($BC8F8F);
  NamedColors['RoyalBlue']            := Ptr($4169E1);
  NamedColors['SaddleBrown']          := Ptr($8B4513);
  NamedColors['Salmon']               := Ptr($FA8072);
  NamedColors['SandyBrown']           := Ptr($F4A460);
  NamedColors['SeaGreen']             := Ptr($2E8B57);
  NamedColors['SeaShell']             := Ptr($FFF5EE);
  NamedColors['Sienna']               := Ptr($A0522D);
  NamedColors['Silver']               := Ptr($C0C0C0);
  NamedColors['SkyBlue']              := Ptr($87CEEB);
  NamedColors['SlateBlue']            := Ptr($6A5ACD);
  NamedColors['SlateGray']            := Ptr($708090);
  NamedColors['Snow']                 := Ptr($FFFAFA);
  NamedColors['SpringGreen']          := Ptr($00FF7F);
  NamedColors['SteelBlue']            := Ptr($4682B4);
  NamedColors['Tan']                  := Ptr($D2B48C);
  NamedColors['Teal']                 := Ptr($008080);
  NamedColors['Thistle']              := Ptr($D8BFD8);
  NamedColors['Tomato']               := Ptr($FF6347);
  NamedColors['Turquoise']            := Ptr($40E0D0);
  NamedColors['Violet']               := Ptr($EE82EE);
  NamedColors['Wheat']                := Ptr($F5DEB3);
  NamedColors['White']                := Ptr($FFFFFF);
  NamedColors['WhiteSmoke']           := Ptr($F5F5F5);
  NamedColors['Yellow']               := Ptr($FFFF00);
  NamedColors['YellowGreen']          := Ptr($9ACD32);
  NamedColors['r']                    := Ptr($F2223E);
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

// var
//   List: TList;

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
  c      := TextScanner.c;

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
  LINE_END_MARKER = #10;
  NBSP            = #160;

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
     
     NativeTag:    char;
     NbspWidth:    integer;
     NumFillChars: integer;
     CharInfo:     Heroes.PFontCharInfo;
     CurrColor:    integer;
     ResLen:       integer;
     i:            integer;

  procedure BeginNewColorBlock;
  begin
    if (TextBlock.BlockType <> TEXT_BLOCK_CHARS) or (TextBlock.BlockLen > 0) then begin
      New(TextBlock);
      Self.Blocks.Add(TextBlock);
      TextBlock.BlockLen  := 0;
      TextBlock.BlockType := TEXT_BLOCK_CHARS;
    end;
  end;

  procedure PopColor;
  begin
    case ColorStack.Count of
      0: CurrColor := DEF_COLOR;
      1: begin
           ColorStack.Pop;
           CurrColor := DEF_COLOR;
         end;
    else
      ColorStack.Pop;
      CurrColor := integer(ColorStack.Top);
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
  CurrColor                    := DEF_COLOR;
  NativeTag                    := #0;

  FontName := pchar(@Font.Name);
  
  if LoadedResources[FontName] = nil then begin
    LoadedResources[FontName] := Font;
    Inc(Font.RefCount);
  end;
  
  if Length(OrigText) <= sizeof(GlobalBuffer) - 1 then begin
    ColorStack.Clear;
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
          Include(TextBlock.ImgBlock.DrawFlags, Heroes.DFL_MIRROR);
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
          PopColor;
        end else begin
          CurrColor := HEROES_GOLD_COLOR_CODE;
          ColorStack.Add(Ptr(CurrColor));
        end;

        TextBlock.CharsBlock.Color32 := CurrColor;
        TextScanner.GotoNextChar;
      // Handle other ERL open/close tags
      end else if TextScanner.GotoRelPos(+2) and TextScanner.ReadTokenTillDelim(['}'], ColorName) then begin
        BeginNewColorBlock;
        
        if ColorName = '' then begin
          PopColor;
        end else begin
          CurrColor := 0;
          
          if NamedColors.GetExistingValue(ColorName, pointer(CurrColor)) then begin
            // Ok
          end else if SysUtils.TryStrToInt('$' + ColorName, CurrColor) then begin
            // Ok
          end else begin
            CurrColor := DEF_COLOR;
          end;
          
          ColorStack.Add(Ptr(CurrColor));
        end; // .else
        
        TextBlock.CharsBlock.Color32 := CurrColor;
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
  Text:       pchar;
  TextEnd:    pchar;
  SliceStart: pchar;
  SliceLen:   integer;
  BlockInd:   integer;
  BlockPos:   integer;
  CurrBlock:  PTextBlock;
  NumBlocks:  integer;

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

  // Process each physical line character
  while Text < TextEnd do begin
    {!} Assert(BlockPos < CurrBlock.BlockLen);
    SliceStart := Text;

    // Output block opening tag, if necessary
    case CurrBlock.BlockType of
      TEXT_BLOCK_CHARS: begin
        if CurrBlock.CharsBlock.Color32 <> DEF_COLOR then begin
          Res.Append('{~');
          Res.Append(SysUtils.Format('%.8x', [CurrBlock.CharsBlock.Color32]));
          Res.Append('}');
        end;
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

        if  CurrBlock.ImgBlock.IsBlock then begin
          Res.Append(' block');
        end;

        Res.Append('}');
      end;
    else
      {!} Assert(false, 'ToTaggedText: unsupported BlockType = ' + SysUtils.IntToStr(ord(CurrBlock.BlockType)));
    end; // .switch CurrBlock.BlockType

    // Skip block meaningful characters
    while (Text < TextEnd) and (BlockPos < CurrBlock.BlockLen) do begin
      if not (Text^ in [#10, ' ']) then begin
        Inc(BlockPos);

        if ChineseLoaderOpt and (Text^ > MAX_CHINESE_LATIN_CHARACTER) and (Text[1] > MAX_CHINESE_LATIN_CHARACTER) then begin
          Inc(Text);
        end;
      end;

      Inc(Text);
    end;

    // Skip out-of-block spacy characters
    while (Text < TextEnd) and (Text^ in [#10, ' ']) do begin
      Inc(Text);
    end;

    SliceLen := integer(Text) - integer(SliceStart);
    Res.AppendBuf(SliceLen, SliceStart);

    // Output closing block tag if necessary
    case CurrBlock.BlockType of
      TEXT_BLOCK_CHARS: begin
        if CurrBlock.CharsBlock.Color32 <> DEF_COLOR then begin
          Res.Append('{~}');
        end;
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
   Automatically skips/applies empty blocks. Updates current color if necessary.
   Synchronizes current color with HD mod variables *)
procedure UpdateCurrBlock; stdcall;
begin
  if (CurrParsedText <> nil) and (CurrTextBlock <> nil) then begin
    if CurrBlockPos < CurrTextBlock.BlockLen then begin
      if CurrTextBlock.BlockType = TEXT_BLOCK_CHARS then begin
        CurrColor := CurrTextBlock.CharsBlock.Color32;
      end;
    end else begin
      while CurrBlockPos >= CurrTextBlock.BlockLen do begin
        CurrBlockPos := 0;
        Inc(CurrBlockInd);

        // Normal, valid case
        if CurrBlockInd < CurrParsedText.NumBlocks then begin
          CurrTextBlock := CurrParsedText.Blocks[CurrBlockInd];

          if CurrTextBlock.BlockType = TEXT_BLOCK_CHARS then begin
            CurrColor := CurrTextBlock.CharsBlock.Color32;
          end;
        // Something is broken, like invalid GBK character (missing second part of code point), mixed language, etc.
        // Empty string, probably. Recover to use the last color.
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

  CurrColor     := DEF_COLOR;
  CurrTextBlock := CurrParsedText.Blocks[0];
  CurrBlockPos  := 0;
  CurrBlockInd  := 0;

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

procedure SetChineseGraphemWidthEstimator (Estimator: TGraphemWidthEstimator); stdcall;
begin
  ChineseGraphemWidthEstimator := Estimator;
end;

procedure SetupColorMode;
begin
  if TextColorMode^ = TEXTMODE_15BITS then begin
    Color32To16    := Color32To15Func;
    Color16To32    := Color15To32Func;
  end else if TextColorMode^ = TEXTMODE_16BITS then begin
    Color32To16    := Color32To16Func;
    Color16To32    := Color16To32Func;
  end else begin
    {!} Assert(false, Format('Invalid text color mode: %d', [TextColorMode^]));
  end;
  
  NameStdColors;
end; // .function Hook_SetupColorMode

function DrawCharacterToPcx (Font: Heroes.PFontItem; Ch: integer; Canvas: Heroes.PPcx16Item; x, y: integer; ColorInd: integer): Heroes.PPcx16Item;
var
  CharWidth:      integer;
  FontHeight:     integer;
  CharPixelPtr:   pbyte;
  OutRowStartPtr: pword;
  OutPixelPtr:    pword;
  BytesPerPixel:  integer;
  CharPixel:      integer;
  Color32:        integer;
  CurrColor32:    integer;
  ShadowColor32:  integer;
  i, j:           integer;
  c:              char;

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
              Color32 := ShadowColor32;
            end;

            if BytesPerPixel = sizeof(integer) then begin
              pinteger(OutPixelPtr)^ := Color32;
            end else begin
              pword(OutPixelPtr)^ := Color32To16(Color32);
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
  ColorStack        := Lists.NewSimpleList;
  TextScanner       := TextScan.TTextScanner.Create;
  TaggedLineBuilder := StrLib.TStrBuilder.Create;
  
  EventMan.GetInstance.On('OnAfterWoG',          OnAfterWoG);
  EventMan.GetInstance.On('OnAfterCreateWindow', OnAfterCreateWindow);
end.
