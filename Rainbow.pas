unit Rainbow;
{
DESCRIPTION:  Adds multi-color support to all Heroes texts
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
}

(***)  interface  (***)
uses
  Math, SysUtils, Utils, Crypto, Lists, AssocArrays, TextScan, ApiJack, PatchApi, DataLib,
  Core, GameExt, Heroes, EventMan, DlgMes;

type
  (* Import *)
  TList = DataLib.TList;
  TDict = DataLib.TDict;

const
  MAX_CHINESE_LATIN_CHARACTER = #160;

  TEXTMODE_15BITS = $3E0;
  TEXTMODE_16BITS = $7E0;

  DEF_COLOR        = -1;
  HD_MOD_DEF_COLOR = 0;
  
  TextColorMode: pword = Ptr($694DB0);


type
  TColor32To16Func  = function (Color32: integer): integer;

  TTextBlock = record
    BlockLen: integer;
    Color16:  integer;
    Def:      Heroes.PDefItem;
    DefFrame: integer;
  end; // .record TTextBlock
  
  
var
  (* Chinese loader support: {~color}...{~} => {...} *)
  ChineseLoaderOpt: boolean;
  ChineseHandler:   pointer;


procedure NameColor (Color32: integer; const Name: string); stdcall;

(* Chinese only: temporal *)
function  ChineseGetCharColor: integer; stdcall;
procedure ChineseGotoNextChar; stdcall;


(***) implementation (***)


exports
  ChineseGetCharColor,
  ChineseGotoNextChar;


type
  TTextBlockType = (TEXT_BLOCK_CHARS, TEXT_BLOCK_DEF);

  PTextBlock2 = ^TTextBlock2;
  TTextBlock2 = record
    BlockLen:  integer;
    BlockType: TTextBlockType;

    case TTextBlockType of
      TEXT_BLOCK_CHARS: (
        Color16: integer;
      );

      TEXT_BLOCK_DEF: (
      {U} Def:      Heroes.PDefItem;
          FrameInd: integer;
      );    
  end; // .record TTextBlock2

  TParsedText = class
   public
   {O} Blocks:        {O} TList {of PTextBlock2};
   {U} Font:          PFontItem; // Can be dangling pointer
       RefCount:      integer;
       NumBlocks:     integer;
       OrigText:      string;
       ProcessedText: string;
       CurrBlockInd:  integer;
       CurrBlockPos:  integer;

    constructor Create;
    destructor  Destroy; override;
  end; // .class TParsedText

var
{O} NamedColors:  {U} AssocArrays.TAssocArray {of Color16: integer};
{O} LoadedImages: {U} TDict {of loaded H3 def, pcx or other image};
{O} ColorStack:   {U} Lists.TList {of Color16: integer};
{O} TextScanner:  TextScan.TTextScanner;
    Color32To16:  TColor32To16Func;

    
    TextBlocks:   array [0..16 * 1024 - 1] of TTextBlock;
    TextBlockInd: integer;
    GlobalBuffer: array [0..1024 * 1024 - 1] of char;
    CurrBlockPos: integer;

    // HD mod integration
    HdModCharColor:      integer = HD_MOD_DEF_COLOR;
    HdModSafeBlackColor: integer = 1;
    HdModOrigCharColor:  integer = 0;


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

procedure NameStdColors;
begin
  NamedColors['AliceBlue']            := Ptr(Color32To16($F0F8FF));
  NamedColors['AntiqueWhite']         := Ptr(Color32To16($FAEBD7));
  NamedColors['Aqua']                 := Ptr(Color32To16($00FFFF));
  NamedColors['Aquamarine']           := Ptr(Color32To16($7FFFD4));
  NamedColors['Azure']                := Ptr(Color32To16($F0FFFF));
  NamedColors['Beige']                := Ptr(Color32To16($F5F5DC));
  NamedColors['Bisque']               := Ptr(Color32To16($FFE4C4));
  NamedColors['Black']                := Ptr(Color32To16($000000));
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
  NamedColors['g']                    := Ptr(Color32To16($FFE794));
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

constructor TParsedText.Create;
begin
  Self.Blocks := Lists.NewList(Utils.OWNS_ITEMS, not Utils.ITEMS_ARE_OBJECTS, Utils.NO_TYPEGUARD, not Utils.ALLOW_NIL);
end;

destructor TParsedText.Destroy;
begin
  SysUtils.FreeAndNil(Self.Blocks);
end;

function IsChineseLoaderPresent (out ChineseHandler: pointer): boolean;
begin
  result := pbyte($4B5202)^ = $E9;
  
  if result then begin
    ChineseHandler  := Ptr(pinteger($4B5203)^ + integer($4B5207));
  end;
end;

(* Returns text copy with Era color tags replaced with native {...text...} tags. Such text may be passed to H3 functions to estimate its width *)
function EraTagsToNativeTags (Str: pchar): string;
var
  Buf: pchar;

begin
  if (Str = nil) or (Str^ = #0) then begin
    result := '';
    exit;
  end;

  result := Str;
  Buf    := @result[1];
  
  while Str^ <> #0 do begin
    while not (Str^ in ['{', #0]) do begin
      Buf^ := Str^;
      Inc(Str);
      Inc(Buf);
    end;

    if Str^ <> #0 then begin
      Inc(Str);

      if Str^ = '~' then begin
        if Str[1] = '}' then begin
          Buf^ := '}';
          Inc(Str, 2);
          Inc(Buf);
        end else begin
          Buf^ := '{';
          Inc(Str);
          Inc(Buf);

          while not (Str^ in ['}', #0]) do begin
            Inc(Str);
          end;

          if Str^ <> #0 then begin
            Inc(Str);
          end;
        end; // .else
      end else begin
        Buf^ := '{';
        Inc(Buf);
      end; // .else
    end; // .if
  end; // .while

  Buf^ := #0;
end; // .function EraTagsToNativeTags

(* Loads def image and caches it forever for fast drawing *)
function LoadDefImage (const FileName: string): {n} Heroes.PDefItem;
begin
  result := LoadedImages[FileName];

  if result = nil then begin
    result := Heroes.LoadDef(FileName);

    if result <> nil then begin
      LoadedImages[FileName] := result;
    end;
  end;
end;

function ParseText (const OrigText: string; {U} Font: Heroes.PFontItem): {O} TParsedText;
const
  ERR_COLOR       = $000000;
  LINE_END_MARKER = #10;
  NBSP            = #160;

var
{U} Buf:      pchar;
    StartPos: integer;
    c:        char;
    
{U} TextBlock:       PTextBlock2;
    BlockLen:        integer;
    IsBlockEnd:      boolean;
    IsEmbeddedImage: boolean;
    NumSpaceChars:   integer;
    
    ColorName:    string;
    DefName:      string;
    FrameIndStr:  string;
    NbspWidth:    integer;
    NumFillChars: integer;
    CharInfo:     Heroes.PFontCharInfo;
    Color16:      integer;
    CurrColor:    integer;
    ResLen:       integer;
    i:            integer;
    
begin
  Buf := @GlobalBuffer[0];
  // * * * * * //
  result          := TParsedText.Create;
  result.OrigText := OrigText;
  result.Font     := Font;
  New(TextBlock);
  result.Blocks.Add(TextBlock);
  
  TextBlock.BlockLen  := Length(OrigText);
  TextBlock.BlockType := TEXT_BLOCK_CHARS;
  TextBlock.Color16   := DEF_COLOR;
  CurrColor           := DEF_COLOR;
  
  if Length(OrigText) <= sizeof(GlobalBuffer) - 1 then begin
    ColorStack.Clear;
    TextScanner.Connect(OrigText, LINE_END_MARKER);
    
    while not TextScanner.EndOfText do begin
      StartPos        := TextScanner.Pos;
      NumSpaceChars   := 0;
      IsBlockEnd      := false;
      IsEmbeddedImage := false;
      
      while not IsBlockEnd and TextScanner.GetCurrChar(c) do begin
        if c = '{' then begin
          IsBlockEnd      := TextScanner.GetCharAtRelPos(+1, c) and (c = '~');
          IsEmbeddedImage := IsBlockEnd and (TextScanner.CharsRel[2] = '>');
        end else if ord(c) <= ord(' ') then begin
          Inc(NumSpaceChars);
        end else if ChineseLoaderOpt and (ord(c) > ord(MAX_CHINESE_LATIN_CHARACTER)) then begin
          Inc(NumSpaceChars);
          TextScanner.GotoNextChar;
        end;
        
        if not IsBlockEnd then begin
          TextScanner.GotoNextChar;
        end;
      end; // .while
      
      BlockLen           := TextScanner.Pos - StartPos;
      Utils.CopyMem(BlockLen, pointer(@OrigText[StartPos]), Buf);
      Buf                := Utils.PtrOfs(Buf, BlockLen);
      TextBlock.BlockLen := BlockLen - NumSpaceChars;

      if IsEmbeddedImage then begin
        TextScanner.GotoRelPos(+3);

        New(TextBlock);
        result.Blocks.Add(TextBlock);
        TextBlock.BlockLen  := 0;
        TextBlock.BlockType := TEXT_BLOCK_DEF;
        TextBlock.Def       := nil;
        TextBlock.FrameInd  := 0;
        
        if TextScanner.ReadTokenTillDelim(['}', ':'], DefName) then begin
          if TextScanner.c = ':' then begin
            TextScanner.GotoNextChar();

            if TextScanner.ReadTokenTillDelim(['}'], FrameIndStr) then begin
              SysUtils.TryStrToInt(FrameIndStr, TextBlock.FrameInd);
            end;
          end;

          TextScanner.GotoNextChar();

          TextBlock.Def := LoadDefImage(DefName);
        end;

        if TextBlock.Def <> nil then begin
          // _Fnt_->char_sizes[NBSP].width
          CharInfo           := @Font.CharInfos[NBSP];
          NbspWidth          := Math.Max(1, CharInfo.SpaceBefore + CharInfo.Width + CharInfo.SpaceAfter);
          NumFillChars       := (TextBlock.Def.Width + NbspWidth - 1) div NbspWidth;
          TextBlock.BlockLen := NumFillChars;

          New(TextBlock);
          result.Blocks.Add(TextBlock);
          TextBlock.BlockLen  := 0;
          TextBlock.BlockType := TEXT_BLOCK_CHARS;
          TextBlock.Color16   := CurrColor;

          // Output serie of non-breaking spaces to compensate image width
          for i := 0 to NumFillChars - 1 do begin
            Buf^ := NBSP;
            Inc(Buf);
          end;
        end;

        continue;
      end; // .if
      
      if not TextScanner.EndOfText and TextScanner.GotoRelPos(+2) and TextScanner.ReadTokenTillDelim(['}'], ColorName) then begin
        if (TextBlock.BlockType <> TEXT_BLOCK_CHARS) or (TextBlock.BlockLen > 0) then begin
          New(TextBlock);
          result.Blocks.Add(TextBlock);
          TextBlock.BlockLen  := 0;
          TextBlock.BlockType := TEXT_BLOCK_CHARS;
        end;
        
        if ColorName = '' then begin
          case ColorStack.Count of
            0:  CurrColor := DEF_COLOR;
            1:  begin
                  ColorStack.Pop;
                  CurrColor := DEF_COLOR;
                end;
          else
            ColorStack.Pop;
            CurrColor := integer(ColorStack.Top);
          end;
        end else begin
          Color16 := 0;
          
          if NamedColors.GetExistingValue(ColorName, pointer(Color16)) then begin
            CurrColor := Color16;
          end else if SysUtils.TryStrToInt('$' + ColorName, Color16) then begin
            Color16   := Color32To16(Color16);
            CurrColor := Color16;
          end else begin
            CurrColor := ERR_COLOR;
          end;
          
          ColorStack.Add(Ptr(Color16));
        end; // .else
        
        TextBlock.Color16 := CurrColor;
        TextScanner.GotoNextChar;
      end; // .if
    end; // .while
  end; // .if
  
  ResLen := integer(Buf) - integer(@GlobalBuffer[0]);
  {!} Assert(ResLen < sizeof(GlobalBuffer), 'Huge text exceeded ERA ParseText buffer capacity');

  SetLength(result.ProcessedText, ResLen);

  result.NumBlocks := result.Blocks.Count;
end; // .function ParseText

function Hook_BeginParseText (Context: Core.PHookContext): longbool; stdcall;
const
  ERR_COLOR       = $000000;
  LINE_END_MARKER = #10;
  NBSP            = #160;

type
  PFntCharInfo = ^TFntCharInfo;
  TFntCharInfo = packed record
    SpaceBefore: integer;
    Width:       integer;
    SpaceAfter:  integer;
  end;

var
{U} Buf:      pchar;
    Txt:      string;
    TxtLen:   integer;
    StartPos: integer;
    c:        char;
    
    BlockLen:        integer;
    IsBlockEnd:      boolean;
    IsEmbeddedImage: boolean;
    NumSpaceChars:   integer;
    
    ColorName:    string;
    DefName:      string;
    DefFrameStr:  string;
    NbspWidth:    integer;
    NumFillChars: integer;
    CharInfo:     PFntCharInfo;
    Color16:      integer;
    i:            integer;
    
begin
  Buf := @GlobalBuffer[0];
  // * * * * * //
  // Remember HD mod initial character color, which HD mod set to overwrite H3 text color
  HdModOrigCharColor := HdModCharColor;

  TxtLen := Context.ECX;
  SetLength(Txt, TxtLen);
  Utils.CopyMem(TxtLen, pchar(Context.EDX), pointer(Txt));
  
  TextBlockInd           := 0;
  TextBlocks[0].BlockLen := TxtLen;
  TextBlocks[0].Color16  := DEF_COLOR;
  TextBlocks[0].Def      := nil;
  
  if Math.InRange(TxtLen, 1, sizeof(GlobalBuffer) - 1) then begin
    ColorStack.Clear;
    TextScanner.Connect(Txt, LINE_END_MARKER);
    
    while not TextScanner.EndOfText do begin
      StartPos        := TextScanner.Pos;
      NumSpaceChars   := 0;
      IsBlockEnd      := false;
      IsEmbeddedImage := false;
      
      while not IsBlockEnd and TextScanner.GetCurrChar(c) do begin
        if c = '{' then begin
          IsBlockEnd      := TextScanner.GetCharAtRelPos(+1, c) and (c = '~');
          IsEmbeddedImage := IsBlockEnd and (TextScanner.CharsRel[2] = '>');
        end else if ord(c) <= ord(' ') then begin
          Inc(NumSpaceChars);
        end else if ChineseLoaderOpt and (ord(c) > 160) then begin
          Inc(NumSpaceChars);
          TextScanner.GotoNextChar;
        end;
        
        if not IsBlockEnd then begin
          TextScanner.GotoNextChar;
        end;
      end; // .while
      
      BlockLen := TextScanner.Pos - StartPos;
      Utils.CopyMem(BlockLen, pointer(@Txt[StartPos]), Buf);
      Buf      := Utils.PtrOfs(Buf, BlockLen);
      TextBlocks[TextBlockInd].BlockLen := BlockLen - NumSpaceChars;

      if IsEmbeddedImage then begin
        TextScanner.GotoRelPos(+3);

        Inc(TextBlockInd);
        TextBlocks[TextBlockInd].BlockLen := 0;
        TextBlocks[TextBlockInd].Color16  := TextBlocks[TextBlockInd - 1].Color16;
        TextBlocks[TextBlockInd].Def      := nil;
        TextBlocks[TextBlockInd].DefFrame := 0;
        
        if TextScanner.ReadTokenTillDelim(['}', ':'], DefName) then begin
          if TextScanner.c = ':' then begin
            TextScanner.GotoNextChar();

            if TextScanner.ReadTokenTillDelim(['}'], DefFrameStr) then begin
              SysUtils.TryStrToInt(DefFrameStr, TextBlocks[TextBlockInd].DefFrame);
            end;
          end;

          TextScanner.GotoNextChar();

          TextBlocks[TextBlockInd].Def := Heroes.LoadDef(DefName);
        end;

        if TextBlocks[TextBlockInd].Def <> nil then begin
          // _Fnt_->char_sizes[NBSP].width
          CharInfo                          := pointer(Context.EBX + $3C + ord(NBSP) * 12);
          NbspWidth                         := Math.Max(1, CharInfo.SpaceBefore + CharInfo.Width + CharInfo.SpaceAfter);
          NumFillChars                      := (TextBlocks[TextBlockInd].Def.Width + NbspWidth - 1) div NbspWidth;
          TextBlocks[TextBlockInd].BlockLen := NumFillChars;

          Inc(TextBlockInd);
          TextBlocks[TextBlockInd].BlockLen := 0;
          TextBlocks[TextBlockInd].Color16  := TextBlocks[TextBlockInd - 1].Color16;
          TextBlocks[TextBlockInd].Def      := nil;

          for i := 0 to NumFillChars - 1 do begin
            Buf^ := NBSP;
            Inc(Buf);
          end;
        end;

        continue;
      end; // .if
      
      if
        not TextScanner.EndOfText   and
        TextScanner.GotoRelPos(+2)  and
        TextScanner.ReadTokenTillDelim(['}'], ColorName)
      then begin
        Inc(TextBlockInd);
        TextBlocks[TextBlockInd].BlockLen := 0;
        TextBlocks[TextBlockInd].Def      := nil;
        
        if ColorName = '' then begin
          case ColorStack.Count of
            0:  TextBlocks[TextBlockInd].Color16 := DEF_COLOR;
            1:  begin
                  ColorStack.Pop;
                  TextBlocks[TextBlockInd].Color16 := DEF_COLOR;
                end;
          else
            ColorStack.Pop;
            TextBlocks[TextBlockInd].Color16 := integer(ColorStack.Top);
          end;
        end else begin
          Color16 :=  0;
          
          if NamedColors.GetExistingValue(ColorName, pointer(Color16)) then begin
            TextBlocks[TextBlockInd].Color16  :=  Color16;
          end else if SysUtils.TryStrToInt('$' + ColorName, Color16) then begin
            Color16                          := Color32To16(Color16);
            TextBlocks[TextBlockInd].Color16 := Color16;
          end else begin
            TextBlocks[TextBlockInd].Color16 := ERR_COLOR;
          end;
          
          ColorStack.Add(Ptr(Color16));
        end; // .else
        
        TextScanner.GotoNextChar;
      end; // .if
    end; // .while
  end; // .if
  
  CurrBlockPos                 := -1;
  TextBlockInd                 := 0;
  Context.ECX                  := integer(Buf) - integer(@GlobalBuffer[0]);
  GlobalBuffer[Context.ECX]    := #0;
  Context.EDX                  := integer(@GlobalBuffer[0]);
  pinteger(Context.EBP - $14)^ := Context.ECX;
  pinteger(Context.EBP + $8)^  := Context.EDX;
  
  if ChineseLoaderOpt then begin
    pinteger(Context.EBP - $14)^ := integer(Buf) - integer(@GlobalBuffer[0]);
    pinteger(Context.EBP + $8)^  := integer(@GlobalBuffer[0]);
    Context.ECX                  := Context.EBX;
    Context.RetAddr              := ChineseHandler;
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
  HdModCharColor := HdModOrigCharColor;
  result         := true;
end;

function Hook_GetCharColor (Context: Core.PHookContext): longbool; stdcall;
begin
  result := TextBlocks[TextBlockInd].Color16 = DEF_COLOR;
  
  if not result then begin
    Context.EAX := TextBlocks[TextBlockInd].Color16;
  end;
end;

function Hook_HandleTags (Context: Core.PHookContext): longbool; stdcall;
var
  c:  char;

begin
  c                           := PCharByte(Context.EDX)^;
  PCharByte(Context.EBP - 4)^ := c;
  Context.RetAddr             := Ptr($4B50BA);
  
  if ord(c) > 32 then begin
    Inc(CurrBlockPos);
  end;
  
  while CurrBlockPos = TextBlocks[TextBlockInd].BlockLen do begin
    CurrBlockPos := 0;
    Inc(TextBlockInd);
  end;
  
  if (TextBlocks[TextBlockInd].Color16 = DEF_COLOR) and (c in ['{', '}']) then begin
    pboolean(Context.EBP + $24)^ := c = '{';
    Context.RetAddr              := Ptr($4B5190);
  end;

  HdModCharColor := TextBlocks[TextBlockInd].Color16;

  if HdModCharColor = DEF_COLOR then begin
    HdModCharColor := HdModOrigCharColor;
  end else if HdModCharColor = HD_MOD_DEF_COLOR then begin
    HdModCharColor := HdModSafeBlackColor;
  end;

  result := not Core.EXEC_DEF_CODE;
end; // .function Hook_HandleTags

function ChineseGetCharColor: integer; stdcall;
begin
  result := TextBlocks[TextBlockInd].Color16;
end;

procedure ChineseGotoNextChar; stdcall;
begin
  Inc(CurrBlockPos);
  
  while CurrBlockPos = TextBlocks[TextBlockInd].BlockLen do begin
    CurrBlockPos := 0;
    Inc(TextBlockInd);
  end;
end;

procedure SetupColorMode;
begin
  if TextColorMode^ = TEXTMODE_15BITS then begin
    Color32To16         := Color32To15Func;
    HdModSafeBlackColor := Color32To16((8 shl 16) or (8 shl 8) or 8);
  end else if TextColorMode^ = TEXTMODE_16BITS then begin
    Color32To16         := Color32To16Func;
    HdModSafeBlackColor := Color32To16((8 shl 16) or (4 shl 8) or 8);
  end else begin
    {!} Assert(false, Format('Invalid text color mode: %d', [TextColorMode^]));
  end;
  
  NameStdColors;
end; // .function Hook_SetupColorMode

function Hook_Font_DrawCharacter (OrigFunc: pointer; Font: pointer; Ch: integer; Canvas: Heroes.PPcx16Item; x, y: integer; Color: integer): integer; stdcall;
var
  Def: Heroes.PDefItem;

begin
  if TextBlocks[TextBlockInd].Def <> nil then begin
    Def := TextBlocks[TextBlockInd].Def;

    if CurrBlockPos = 0 then begin
      Def.DrawFrameToBuf(TextBlocks[TextBlockInd].DefFrame, 0, 0, Def.Width, Def.Height, Canvas.Buffer, x, y, Canvas.Width, Canvas.Height, Canvas.ScanlineSize);
    end;

    result := integer(Canvas);
  end else begin
    result := PatchApi.Call(THISCALL_, OrigFunc, [Font, Ch, Canvas, x, y, Color]);
  end;
end; // .function Hook_Font_DrawCharacter

procedure OnAfterCreateWindow (Event: GameExt.PEvent); stdcall;
begin
  SetupColorMode; 
  ApiJack.StdSplice(Ptr($4B4F00), @Hook_Font_DrawCharacter, ApiJack.CONV_THISCALL, 6);
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

  // Support colorful texts with HD mod 32 bit modes
  Core.GlobalPatcher.VarInit('HotA.FontColor', integer(@HdModCharColor));
end; // .procedure OnAfterWoG

begin
  NamedColors  := AssocArrays.NewSimpleAssocArr(Crypto.AnsiCRC32, SysUtils.AnsiLowerCase);
  LoadedImages := DataLib.NewDict(not Utils.OWNS_ITEMS, DataLib.CASE_INSENSITIVE);
  ColorStack   := Lists.NewSimpleList;
  TextScanner  := TextScan.TTextScanner.Create;
  
  EventMan.GetInstance.On('OnAfterWoG',          OnAfterWoG);
  EventMan.GetInstance.On('OnAfterCreateWindow', OnAfterCreateWindow);
end.
