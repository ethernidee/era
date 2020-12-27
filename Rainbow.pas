unit Rainbow;
{
DESCRIPTION:  Adds multi-color support to all Heroes texts
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
}

(***)  interface  (***)
uses
  Math, SysUtils, Windows,
  Utils, Crypto, Lists, AssocArrays, TextScan, ApiJack, PatchApi, DataLib, StrLib,
  Core, GameExt, Heroes, Memory, EventMan, DlgMes;

type
  (* Import *)
  TList = DataLib.TList;
  TDict = DataLib.TDict;

const
  MAX_CHINESE_LATIN_CHARACTER = #160;

  TEXTMODE_15BITS = $3E0;
  TEXTMODE_16BITS = $7E0;

  DEF_COLOR          = -1;
  HD_MOD_DEF_COLOR   = 0;
  UNSAFE_BLACK_COLOR = 0; // Used as DEF_COLOR because of HD mod compatibility
  
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


type
  TTextBlockType = (TEXT_BLOCK_CHARS, TEXT_BLOCK_DEF);

  PTextBlock = ^TTextBlock;
  TTextBlock = record
    BlockLen:  integer;
    BlockType: TTextBlockType;

    case TTextBlockType of
      TEXT_BLOCK_CHARS: (
        Color16: integer;
      );

      TEXT_BLOCK_DEF: (
      {U} Def:      Heroes.PDefItem;
          DefName:  pchar; // Pointer to persisted string
          FrameInd: integer;
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
{O} NamedColors:       {U} AssocArrays.TAssocArray {of Color16: integer};
{O} LoadedResources:   {U} TDict {of loaded H3 resource};
{O} ColorStack:        {U} Lists.TList {of Color16: integer};
{O} TextScanner:       TextScan.TTextScanner;
{O} TaggedLineBuilder: StrLib.TStrBuilder;
    Color32To16:       TColor32To16Func;
    Color16To32:       function (Color16: integer): integer;

{U} CurrParsedText: TParsedText = nil;
{U} CurrTextBlock:  PTextBlock = nil;

    CurrBlockInd:   integer;
    CurrBlockPos:   integer;
    CurrColor:      integer = DEF_COLOR;
    SafeBlackColor: integer = 1;
    
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
var
  Red:   integer;
  Green: integer;
  Blue:  integer;

begin
  Red   := ((Color16 shr 11) and $1F) shl 3;
  Green := ((Color16 shr 5) and $3F) shl 2;
  Blue  := (Color16 and $1F) shl 3;

  result := (Red shl 16) or (Green shl 8) or Blue;
end;

function Color15To32Func (Color15: integer): integer;
var
  Red:   integer;
  Green: integer;
  Blue:  integer;

begin
  Red   := ((Color15 shr 10) and $1F) shl 3;
  Green := ((Color15 shr 5) and $1F) shl 3;
  Blue  := (Color15 and $1F) shl 3;

  result := (Red shl 16) or (Green shl 8) or Blue;
end;

procedure NameStdColors;
begin
  NamedColors['AliceBlue']            := Ptr(Color32To16($F0F8FF));
  NamedColors['AntiqueWhite']         := Ptr(Color32To16($FAEBD7));
  NamedColors['Aqua']                 := Ptr(Color32To16($00FFFF));
  NamedColors['Aquamarine']           := Ptr(Color32To16($7FFFD4));
  NamedColors['Azure']                := Ptr(Color32To16($F0FFFF));
  NamedColors['Beige']                := Ptr(Color32To16($F5F5DC));
  NamedColors['Bisque']               := Ptr(Color32To16($FFE4C4));
  NamedColors['Black']                := Ptr(Color32To16(SafeBlackColor));
  NamedColors['BlanchedAlmond']       := Ptr(Color32To16($FFEBCD));
  NamedColors['Blue']                 := Ptr(Color32To16($0000FF));
  NamedColors['BlueViolet']           := Ptr(Color32To16($8A2BE2));
  NamedColors['Brown']                := Ptr(Color32To16($A52A2A));
  NamedColors['BurlyWood']            := Ptr(Color32To16($DEB887));
  NamedColors['CadetBlue']            := Ptr(Color32To16($5F9EA0));
  NamedColors['Chartreuse']           := Ptr(Color32To16($7FFF00));
  NamedColors['Chocolate']            := Ptr(Color32To16($D2691E));
  NamedColors['Coral']                := Ptr(Color32To16($FF7F50));
  NamedColors['CornflowerBlue']       := Ptr(Color32To16($6495ED));
  NamedColors['Cornsilk']             := Ptr(Color32To16($FFF8DC));
  NamedColors['Crimson']              := Ptr(Color32To16($DC143C));
  NamedColors['Cyan']                 := Ptr(Color32To16($00FFFF));
  NamedColors['DarkBlue']             := Ptr(Color32To16($00008B));
  NamedColors['DarkCyan']             := Ptr(Color32To16($008B8B));
  NamedColors['DarkGoldenRod']        := Ptr(Color32To16($B8860B));
  NamedColors['DarkGray']             := Ptr(Color32To16($A9A9A9));
  NamedColors['DarkGreen']            := Ptr(Color32To16($006400));
  NamedColors['DarkGrey']             := Ptr(Color32To16($A9A9A9));
  NamedColors['DarkKhaki']            := Ptr(Color32To16($BDB76B));
  NamedColors['DarkMagenta']          := Ptr(Color32To16($8B008B));
  NamedColors['DarkOliveGreen']       := Ptr(Color32To16($556B2F));
  NamedColors['Darkorange']           := Ptr(Color32To16($FF8C00));
  NamedColors['DarkOrchid']           := Ptr(Color32To16($9932CC));
  NamedColors['DarkRed']              := Ptr(Color32To16($8B0000));
  NamedColors['DarkSalmon']           := Ptr(Color32To16($E9967A));
  NamedColors['DarkSeaGreen']         := Ptr(Color32To16($8FBC8F));
  NamedColors['DarkSlateBlue']        := Ptr(Color32To16($483D8B));
  NamedColors['DarkSlateGrey']        := Ptr(Color32To16($2F4F4F));
  NamedColors['DarkTurquoise']        := Ptr(Color32To16($00CED1));
  NamedColors['DarkViolet']           := Ptr(Color32To16($9400D3));
  NamedColors['DeepPink']             := Ptr(Color32To16($FF1493));
  NamedColors['DeepSkyBlue']          := Ptr(Color32To16($00BFFF));
  NamedColors['DimGray']              := Ptr(Color32To16($696969));
  NamedColors['DodgerBlue']           := Ptr(Color32To16($1E90FF));
  NamedColors['FireBrick']            := Ptr(Color32To16($B22222));
  NamedColors['FloralWhite']          := Ptr(Color32To16($FFFAF0));
  NamedColors['ForestGreen']          := Ptr(Color32To16($228B22));
  NamedColors['Fuchsia']              := Ptr(Color32To16($FF00FF));
  NamedColors['Gainsboro']            := Ptr(Color32To16($DCDCDC));
  NamedColors['GhostWhite']           := Ptr(Color32To16($F8F8FF));
  NamedColors['Gold']                 := Ptr(Color32To16($FFD700));
  NamedColors['GoldenRod']            := Ptr(Color32To16($DAA520));
  NamedColors['Gray']                 := Ptr(Color32To16($808080));
  NamedColors['Green']                := Ptr(Color32To16($008000));
  NamedColors['GreenYellow']          := Ptr(Color32To16($ADFF2F));
  NamedColors['Grey']                 := Ptr(Color32To16($808080));
  NamedColors['HoneyDew']             := Ptr(Color32To16($F0FFF0));
  NamedColors['HotPink']              := Ptr(Color32To16($FF69B4));
  NamedColors['IndianRed']            := Ptr(Color32To16($CD5C5C));
  NamedColors['Indigo']               := Ptr(Color32To16($4B0082));
  NamedColors['Ivory']                := Ptr(Color32To16($FFFFF0));
  NamedColors['Khaki']                := Ptr(Color32To16($F0E68C));
  NamedColors['Lavender']             := Ptr(Color32To16($E6E6FA));
  NamedColors['LavenderBlush']        := Ptr(Color32To16($FFF0F5));
  NamedColors['LawnGreen']            := Ptr(Color32To16($7CFC00));
  NamedColors['LemonChiffon']         := Ptr(Color32To16($FFFACD));
  NamedColors['LightBlue']            := Ptr(Color32To16($ADD8E6));
  NamedColors['LightCoral']           := Ptr(Color32To16($F08080));
  NamedColors['LightCyan']            := Ptr(Color32To16($E0FFFF));
  NamedColors['LightGoldenRodYellow'] := Ptr(Color32To16($FAFAD2));
  NamedColors['LightGray']            := Ptr(Color32To16($D3D3D3));
  NamedColors['LightGreen']           := Ptr(Color32To16($90EE90));
  NamedColors['LightGrey']            := Ptr(Color32To16($D3D3D3));
  NamedColors['LightPink']            := Ptr(Color32To16($FFB6C1));
  NamedColors['LightSalmon']          := Ptr(Color32To16($FFA07A));
  NamedColors['LightSeaGreen']        := Ptr(Color32To16($20B2AA));
  NamedColors['LightSkyBlue']         := Ptr(Color32To16($87CEFA));
  NamedColors['LightSlateGray']       := Ptr(Color32To16($778899));
  NamedColors['LightSteelBlue']       := Ptr(Color32To16($B0C4DE));
  NamedColors['LightYellow']          := Ptr(Color32To16($FFFFE0));
  NamedColors['Lime']                 := Ptr(Color32To16($00FF00));
  NamedColors['LimeGreen']            := Ptr(Color32To16($32CD32));
  NamedColors['Linen']                := Ptr(Color32To16($FAF0E6));
  NamedColors['Magenta']              := Ptr(Color32To16($FF00FF));
  NamedColors['Maroon']               := Ptr(Color32To16($800000));
  NamedColors['MediumAquaMarine']     := Ptr(Color32To16($66CDAA));
  NamedColors['MediumBlue']           := Ptr(Color32To16($0000CD));
  NamedColors['MediumOrchid']         := Ptr(Color32To16($BA55D3));
  NamedColors['MediumPurple']         := Ptr(Color32To16($9370D8));
  NamedColors['MediumSeaGreen']       := Ptr(Color32To16($3CB371));
  NamedColors['MediumSlateBlue']      := Ptr(Color32To16($7B68EE));
  NamedColors['MediumSpringGreen']    := Ptr(Color32To16($00FA9A));
  NamedColors['MediumTurquoise']      := Ptr(Color32To16($48D1CC));
  NamedColors['MediumVioletRed']      := Ptr(Color32To16($C71585));
  NamedColors['MidnightBlue']         := Ptr(Color32To16($191970));
  NamedColors['MintCream']            := Ptr(Color32To16($F5FFFA));
  NamedColors['MistyRose']            := Ptr(Color32To16($FFE4E1));
  NamedColors['Moccasin']             := Ptr(Color32To16($FFE4B5));
  NamedColors['NavajoWhite']          := Ptr(Color32To16($FFDEAD));
  NamedColors['Navy']                 := Ptr(Color32To16($000080));
  NamedColors['OldLace']              := Ptr(Color32To16($FDF5E6));
  NamedColors['Olive']                := Ptr(Color32To16($808000));
  NamedColors['OliveDrab']            := Ptr(Color32To16($6B8E23));
  NamedColors['Orange']               := Ptr(Color32To16($FFA500));
  NamedColors['OrangeRed']            := Ptr(Color32To16($FF4500));
  NamedColors['Orchid']               := Ptr(Color32To16($DA70D6));
  NamedColors['PaleGoldenRod']        := Ptr(Color32To16($EEE8AA));
  NamedColors['PaleGreen']            := Ptr(Color32To16($98FB98));
  NamedColors['PaleTurquoise']        := Ptr(Color32To16($AFEEEE));
  NamedColors['PaleVioletRed']        := Ptr(Color32To16($D87093));
  NamedColors['PapayaWhip']           := Ptr(Color32To16($FFEFD5));
  NamedColors['PeachPuff']            := Ptr(Color32To16($FFDAB9));
  NamedColors['Peru']                 := Ptr(Color32To16($CD853F));
  NamedColors['Pink']                 := Ptr(Color32To16($FFC0CB));
  NamedColors['Plum']                 := Ptr(Color32To16($DDA0DD));
  NamedColors['PowderBlue']           := Ptr(Color32To16($B0E0E6));
  NamedColors['Purple']               := Ptr(Color32To16($800080));
  NamedColors['Red']                  := Ptr(Color32To16($FF0000));
  NamedColors['RosyBrown']            := Ptr(Color32To16($BC8F8F));
  NamedColors['RoyalBlue']            := Ptr(Color32To16($4169E1));
  NamedColors['SaddleBrown']          := Ptr(Color32To16($8B4513));
  NamedColors['Salmon']               := Ptr(Color32To16($FA8072));
  NamedColors['SandyBrown']           := Ptr(Color32To16($F4A460));
  NamedColors['SeaGreen']             := Ptr(Color32To16($2E8B57));
  NamedColors['SeaShell']             := Ptr(Color32To16($FFF5EE));
  NamedColors['Sienna']               := Ptr(Color32To16($A0522D));
  NamedColors['Silver']               := Ptr(Color32To16($C0C0C0));
  NamedColors['SkyBlue']              := Ptr(Color32To16($87CEEB));
  NamedColors['SlateBlue']            := Ptr(Color32To16($6A5ACD));
  NamedColors['SlateGray']            := Ptr(Color32To16($708090));
  NamedColors['Snow']                 := Ptr(Color32To16($FFFAFA));
  NamedColors['SpringGreen']          := Ptr(Color32To16($00FF7F));
  NamedColors['SteelBlue']            := Ptr(Color32To16($4682B4));
  NamedColors['Tan']                  := Ptr(Color32To16($D2B48C));
  NamedColors['Teal']                 := Ptr(Color32To16($008080));
  NamedColors['Thistle']              := Ptr(Color32To16($D8BFD8));
  NamedColors['Tomato']               := Ptr(Color32To16($FF6347));
  NamedColors['Turquoise']            := Ptr(Color32To16($40E0D0));
  NamedColors['Violet']               := Ptr(Color32To16($EE82EE));
  NamedColors['Wheat']                := Ptr(Color32To16($F5DEB3));
  NamedColors['White']                := Ptr(Color32To16($FFFFFF));
  NamedColors['WhiteSmoke']           := Ptr(Color32To16($F5F5F5));
  NamedColors['Yellow']               := Ptr(Color32To16($FFFF00));
  NamedColors['YellowGreen']          := Ptr(Color32To16($9ACD32));
  NamedColors['r']                    := Ptr(Color32To16($F2223E));
  NamedColors['g']                    := Ptr(Color32To16(Heroes.HEROES_GOLD_COLOR_CODE));
  NamedColors['b']                    := NamedColors['Blue'];
  NamedColors['y']                    := NamedColors['Yellow'];
  NamedColors['w']                    := NamedColors['White'];
  NamedColors['o']                    := NamedColors['Orange'];
  NamedColors['p']                    := NamedColors['Purple'];
  NamedColors['a']                    := NamedColors['Aqua'];
end; // .procedure NameStdColors

procedure NameColor (Color32: integer; const Name: string);
begin
  NamedColors[Name] := Ptr(Color32To16(Color32));
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

constructor TParsedText.Create (const OrigText: string; {U} Font: Heroes.PFontItem);
const
  LINE_END_MARKER = #10;
  NBSP            = #160;

var
{U} Buf:      pchar;
    StartPos: integer;
    c:        char;
    
{U} TextBlock:       PTextBlock;
    BlockLen:        integer;
    IsTag:           boolean;
    IsEraTag:        boolean;
    IsEmbeddedImage: boolean;
    NumSpaceChars:   integer;
    
    NativeTag:    char;
    FontName:     string;
    ColorName:    string;
    DefName:      string;
    FrameIndStr:  string;
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

  Buf := @GlobalBuffer[0];
  // * * * * * //
  Self.Blocks   := Lists.NewList(Utils.OWNS_ITEMS, not Utils.ITEMS_ARE_OBJECTS, Utils.NO_TYPEGUARD, not Utils.ALLOW_NIL);
  Self.OrigText := OrigText;
  Self.Font     := Font;
  New(TextBlock);
  Self.Blocks.Add(TextBlock);

  TextBlock.BlockLen  := Length(OrigText);
  TextBlock.BlockType := TEXT_BLOCK_CHARS;
  TextBlock.Color16   := DEF_COLOR;
  CurrColor           := DEF_COLOR;
  NativeTag           := #0;

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
        TextBlock.BlockLen  := 0;
        TextBlock.BlockType := TEXT_BLOCK_DEF;
        TextBlock.Def       := nil;
        TextBlock.FrameInd  := 0;
        
        if TextScanner.ReadTokenTillDelim(['}', ':'], DefName) then begin
          DefName := SysUtils.AnsiLowerCase(DefName);

          if TextScanner.c = ':' then begin
            TextScanner.GotoNextChar();

            if TextScanner.ReadTokenTillDelim(['}'], FrameIndStr) then begin
              SysUtils.TryStrToInt(FrameIndStr, TextBlock.FrameInd);
            end;
          end;

          TextScanner.GotoNextChar();

          TextBlock.Def     := LoadDefImage(DefName);
          TextBlock.DefName := Memory.UniqueStrings[pchar(DefName)];
        end; // .if

        if TextBlock.Def <> nil then begin
          // _Fnt_->char_sizes[NBSP].width
          CharInfo           := @Font.CharInfos[NBSP];
          NbspWidth          := Math.Max(1, CharInfo.SpaceBefore + CharInfo.Width + CharInfo.SpaceAfter);
          NumFillChars       := (TextBlock.Def.Width + NbspWidth - 1) div NbspWidth;
          TextBlock.BlockLen := NumFillChars;

          BeginNewColorBlock;
          TextBlock.Color16 := CurrColor;

          // Output serie of non-breaking spaces to compensate image width
          for i := 0 to NumFillChars - 1 do begin
            Buf^ := NBSP;
            Inc(Buf);
          end;
        end;

        continue;
      end; // .if

      // Handle native '{', '}' tags
      if not IsEraTag then begin
        BeginNewColorBlock;

        if NativeTag = '}' then begin
          PopColor;
        end else begin
          CurrColor := Color32To16(HEROES_GOLD_COLOR_CODE);
          ColorStack.Add(Ptr(CurrColor));
        end;

        TextBlock.Color16 := CurrColor;
        TextScanner.GotoNextChar;
      // Handle Era custom color open/close tags
      end else if TextScanner.GotoRelPos(+2) and TextScanner.ReadTokenTillDelim(['}'], ColorName) then begin
        BeginNewColorBlock;
        
        if ColorName = '' then begin
          PopColor;
        end else begin
          CurrColor := 0;
          
          if NamedColors.GetExistingValue(ColorName, pointer(CurrColor)) then begin
            // Ok
          end else if SysUtils.TryStrToInt('$' + ColorName, CurrColor) then begin
            CurrColor := Color32To16(CurrColor);

            if CurrColor = UNSAFE_BLACK_COLOR then begin
              CurrColor := SafeBlackColor;
            end;
          end else begin
            CurrColor := DEF_COLOR;
          end;
          
          ColorStack.Add(Ptr(CurrColor));
        end; // .else
        
        TextBlock.Color16 := CurrColor;
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
  //   List := ParsedTextToLines(Self, 100);

  //   for i := 0 to List.Count - 1 do begin
  //     TParsedTextLine(List[i]).ToTaggedText(Self, TaggedLineBuilder);
  //     VarDump(['LineN:', i + 1, TaggedLineBuilder.BuildStr()]);
  //   end;
  // end;
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
        if CurrBlock.Color16 <> DEF_COLOR then begin
          Res.Append('{~');
          Res.Append(SysUtils.Format('%x', [Color16To32(CurrBlock.Color16)]));
          Res.Append('}');
        end;
      end;

      TEXT_BLOCK_DEF: begin
        Res.Append('{~>');
        Res.AppendBuf(Windows.LStrLen(CurrBlock.DefName), CurrBlock.DefName);

        if CurrBlock.FrameInd <> 0 then begin
          Res.Append(':' + SysUtils.IntToStr(CurrBlock.FrameInd));
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
        if CurrBlock.Color16 <> DEF_COLOR then begin
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
        CurrColor := CurrTextBlock.Color16;
      end;
    end else begin
      while CurrBlockPos >= CurrTextBlock.BlockLen do begin
        CurrBlockPos := 0;
        Inc(CurrBlockInd);

        // Normal, valid case
        if CurrBlockInd < CurrParsedText.NumBlocks then begin
          CurrTextBlock := CurrParsedText.Blocks[CurrBlockInd];

          if CurrTextBlock.BlockType = TEXT_BLOCK_CHARS then begin
            CurrColor := CurrTextBlock.Color16;
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
    SafeBlackColor := Color32To16((8 shl 16) or (8 shl 8) or 8);
  end else if TextColorMode^ = TEXTMODE_16BITS then begin
    Color32To16    := Color32To16Func;
    Color16To32    := Color16To32Func;
    SafeBlackColor := Color32To16((8 shl 16) or (4 shl 8) or 8);
  end else begin
    {!} Assert(false, Format('Invalid text color mode: %d', [TextColorMode^]));
  end;
  
  NameStdColors;
end; // .function Hook_SetupColorMode

function DrawCharacterToPcx (Font: Heroes.PFontItem; Ch: integer; Canvas: Heroes.PPcx16Item; x, y: integer; ColorInd: integer): Heroes.PPcx16Item;
var
  CharWidth:      integer;
  FontHeight:     integer;
  CharPixelPtr:   pshortint;
  OutRowStartPtr: pword;
  OutPixelPtr:    pword;
  BytesPerPixel:  integer;
  CharPixel:      integer;
  Color16:        integer;
  i, j:           integer;
  c:              char;

begin
  result := Heroes.PPcx16Item(Ch); // Vanilla code. Like error marker?

  if (Ch >= 0) and (Ch <= 255) then begin
    BytesPerPixel := BytesPerPixelPtr^;
    c             := chr(Ch);
    CharWidth     := Font.CharInfos[c].Width;
    FontHeight    := Font.Height;

    if (CharWidth > 0) and (FontHeight > 0) then begin
      CharPixelPtr   := @Font.CharsDataPtr[Font.CharDataOffsets[c]];
      OutRowStartPtr := Utils.PtrOfs(Canvas.Buffer, y * Canvas.ScanlineSize + (x + Font.CharInfos[c].SpaceBefore) * BytesPerPixel);

      for j := 0 to FontHeight - 1 do begin
        OutPixelPtr := OutRowStartPtr;

        for i := 0 to CharWidth - 1 do begin
          CharPixel := CharPixelPtr^;

          if CharPixel <> 0 then begin
            if CharPixel = -1 then begin
              if CurrColor = DEF_COLOR then begin
                Color16 := Font.Palette16.Colors[ColorInd];
              end else begin
                Color16 := CurrColor;
              end;
            end else begin
              Color16 := Font.Palette16.Colors[32];
            end;

            if BytesPerPixel = sizeof(integer) then begin
              pinteger(OutPixelPtr)^ := Color16To32(Color16);
            end else begin
              pword(OutPixelPtr)^ := Color16;
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
  if (CurrParsedText <> nil) and (CurrTextBlock <> nil) and (CurrTextBlock.BlockType = TEXT_BLOCK_DEF) and (CurrTextBlock.Def <> nil) then begin
    Def := CurrTextBlock.Def;

    if CurrBlockPos = 0 then begin
      Def.DrawFrameToBuf(CurrTextBlock.FrameInd, 0, 0, Def.Width, Def.Height, Canvas.Buffer, x, y, Canvas.Width, Canvas.Height, Canvas.ScanlineSize);
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
  NamedColors       := AssocArrays.NewSimpleAssocArr(Crypto.AnsiCRC32, SysUtils.AnsiLowerCase);
  LoadedResources   := DataLib.NewDict(not Utils.OWNS_ITEMS, DataLib.CASE_INSENSITIVE);
  ColorStack        := Lists.NewSimpleList;
  TextScanner       := TextScan.TTextScanner.Create;
  TaggedLineBuilder := StrLib.TStrBuilder.Create;
  
  EventMan.GetInstance.On('OnAfterWoG',          OnAfterWoG);
  EventMan.GetInstance.On('OnAfterCreateWindow', OnAfterCreateWindow);
end.
