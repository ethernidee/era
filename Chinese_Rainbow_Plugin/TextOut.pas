unit TextOut;

(* ERA notes
 * Chinese character code > 160
 * If next character code <= 160, it becomes 161
 * Example [170][32] => [170][161]
 * GB2312/GBK
 *)

interface
uses
  Dialogs, Windows, SysUtils, Math;

  procedure DoMyTextOut_New (str:pAnsiChar; Surface, x, y, BoxWidth, BoxHeight, ColorA, Mode, hfont, unknow:integer); stdcall;
  procedure DoMyDialog (hfont, MaxWidth: integer; s: pAnsiChar); stdcall;

implementation

uses
  H32GameFunction,Main;

const
  ALPHA_CHANNEL_MASK_32        = integer($FF000000);
  RED_BLUE_CHANNELS_MASK_32    = $00FF00FF;
  GREEN_CHANNEL_MASK_32        = $0000FF00;
  ALPHA_GREEN_CHANNELS_MASK_32 = integer(ALPHA_CHANNEL_MASK_32 or GREEN_CHANNEL_MASK_32);
  FULLY_OPAQUE_MASK32          = integer($FF000000);
  RGB_MASK_32                  = $FFFFFF;

  Font24Width:  integer = 28;
  Font24Height: integer = 25;

  Font12Width:  integer = 14;
  Font12Height: integer = 16;

  Font11Width:  integer = 11;
  Font11Height: integer = 11;

  TEXTMODE_15BITS = $3E0;
  TEXTMODE_16BITS = $7E0;

type
  PChars12 = ^TChars12;
  TChars12 = packed array [0..11] of char;

  {$ALIGN OFF}
  PBinaryTreeItem = ^TBinaryTreeItem;
  TBinaryTreeItem = object
   public
    VTable:   ppointer;
    Name:     TChars12;
    NameEnd:  integer;
    ItemType: integer;
    RefCount: integer;
  end; // .object TBinaryTreeItem
  {$ALIGN ON}

  PFontCharInfo = ^TFontCharInfo;
  TFontCharInfo = packed record
    SpaceBefore: integer;
    Width:       integer;
    SpaceAfter:  integer;
  end;

  {$ALIGN OFF}
  PFontItem = ^TFontItem;
  TFontItem = object (TBinaryTreeItem)
   public
    FirstChar:       char;
    LastChar:        char;
    BppDepth:        byte; // Bits per pixel, 8 for Heroes fonts
    XSpace:          byte; // 0?
    YSpace:          byte; // 0?
    Height:          byte; // In bits
    Unk1:            array [1..26] of byte;
    CharInfos:       array [#0..#255] of TFontCharInfo;
    CharDataOffsets: array [#0..#255] of integer;
    Unk2:            array [1..28] of byte;
    Color16Table:    array [0..255] of word; // 0x1058
    CharsDataPtr:    pshortint;
  end; // .object TFontItem
  {$ALIGN ON}

  TGraphemWidthEstimator = function (Font: PFontItem): integer; stdcall;

var
  BytesPerPixel:  integer = 2;
  TextColorMode:  pword   = Ptr($694DB0);
  Color16To32:    function (Color16: integer): integer;
  Color32To16:    function (Color32: integer): integer;
  PrevFont:       PFontItem;
  PrevFontWidth:  integer;
  PrevFontHeight: integer;

function  ChineseGetCharColor: integer; stdcall; external 'era.dll';
procedure ChineseGotoNextChar; stdcall; external 'era.dll';
procedure ChineseSetTextAlignmentParamPtr (NewParamPtr: pinteger); stdcall; external 'era.dll';
procedure SetChineseGraphemWidthEstimator (Estimator: TGraphemWidthEstimator); stdcall; external 'era.dll';
procedure UpdateTextAttrsFromNextChar; stdcall; external 'era.dll';

procedure UpdateBytesPerPixel;
begin
  BytesPerPixel := pbyte($5FA228 + 3)^;
end;

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
  result := (({BLUE} (Color16 and $1F) shl 3) or ({GREEN} (Color16 and $7E0) shl 5) or ({RED} (Color16 and $F800) shl 8) or FULLY_OPAQUE_MASK32) and $FFF8FCF8;
end;

function Color15To32Func (Color15: integer): integer;
begin
  result := (({BLUE} (Color15 and $1F) shl 3) or ({GREEN} (Color15 and $3E0) shl 6) or ({RED} (Color15 and $F800) shl 9) or FULLY_OPAQUE_MASK32) and $FFF8F8F8;
end;

function PremultiplyColorChannelsByAlpha (Color32: integer): integer;
var
  AlphaChannel: integer;
  ColorOpacity: integer;

begin
  AlphaChannel := Color32 and ALPHA_CHANNEL_MASK_32;
  ColorOpacity := AlphaChannel shr 24;
  result       := (((ColorOpacity * (Color32 and RED_BLUE_CHANNELS_MASK_32)) shr 8) and RED_BLUE_CHANNELS_MASK_32) or
                  (((ColorOpacity * (Color32 and GREEN_CHANNEL_MASK_32)) shr 8) and GREEN_CHANNEL_MASK_32) or
                  AlphaChannel;
end;

function AlphaBlendWithPremultiplied32 (FirstColor32, SecondColor32Premultiplied: integer): integer;
var
  SecondColorOpacity: integer;

begin
  SecondColorOpacity := 255 - ((SecondColor32Premultiplied and ALPHA_CHANNEL_MASK_32) shr 24);

  result := ((((SecondColorOpacity * (FirstColor32 and RED_BLUE_CHANNELS_MASK_32))  shr 8)  and RED_BLUE_CHANNELS_MASK_32) or
            ((SecondColorOpacity * ((FirstColor32 and ALPHA_GREEN_CHANNELS_MASK_32) shr 8)) and ALPHA_GREEN_CHANNELS_MASK_32))
            + SecondColor32Premultiplied;
end;

//返回一个汉字的区位码
// Return the qw code of a Chinese character
procedure GetQWCode(HZ:pAnsiChar;var Q,W:word);stdcall;
begin
  Q := byte(HZ[0]) - 160;

  if byte(HZ[1]) > 160 then begin
    W := byte(HZ[1]) - 160;
  end else begin
    W := 1;
  end;
end;

procedure MakeChar12 (StartY, StartX, Surface: integer; HZ: pAnsiChar; Color: integer); stdcall;
var
  OffSet:integer;
  GetStr:array [0..23] of byte;
  temp,dis:byte;
  x,y,i,j,xy:integer;
  Q,W:word;
  ScanlineSize:integer;
  OutPixelPtr: pword;

begin
  ScanlineSize:=pInteger(Surface+$2c)^;
  GetQWCode(HZ,Q,W);
  OffSet:=(94*(Q-1)+(W-1))*24;
  F12.Position:=OffSet;
  F12.Read(GetStr,sizeof(GetStr));

  x:=0;
  y:=0;
  i:=0;

  while(i<=23) do
  begin
    temp:=GetStr[i];
    for j:=0 to 7 do begin
      dis:=temp and 128;
      dis:=dis shr 7;
      if dis=1 then
      begin
        xy          := (StartY + x) * ScanlineSize + (y + StartX) * BytesPerPixel;
        OutPixelPtr := pointer(pinteger(Surface + $30)^ + xy);

        if BytesPerPixel = sizeof(integer) then begin
          pinteger(OutPixelPtr)^ := AlphaBlendWithPremultiplied32(pinteger(OutPixelPtr)^, Color);
        end else begin
          pword(OutPixelPtr)^ := Color32To16(AlphaBlendWithPremultiplied32(Color16To32(pword(OutPixelPtr)^), Color));
        end;
      end;
      Inc(x);
      if x>15 then
      begin
        x:=0;
        Inc(y);
      end;
      temp:=temp shl 1;
    end;
    Inc(i);
  end;
end;

procedure MakeChar10 (StartY, StartX, Surface: integer; HZ: pAnsiChar; Color: integer); stdcall;
var
  OffSet:integer;
  GetStr:array[0..19] of byte;
  temp,dis:byte;
  x,y,i,j,xy:integer;
  Q,W:word;
  ScanlineSize:integer;
  OutPixelPtr: pword;

begin
  ScanlineSize:=pInteger(Surface+$2c)^;
  GetQWCode(HZ,Q,W);
  OffSet:=(94*(Q-1)+(W-1))*20;
  F10.Position:=OffSet;
  F10.Read(GetStr,sizeof(GetStr));
  x:=0;
  y:=0;
  i:=0;
  while(i<=19) do
  begin
    temp:=getstr[i];
    for j:=0 to 7 do
    begin
      dis:=temp and 128;
      dis:=dis shr 7;
      if dis=1 then
      begin
        xy          := (StartY + y) * ScanlineSize + (x + StartX) * BytesPerPixel;
        OutPixelPtr := pointer(pinteger(Surface + $30)^ + xy);

        if BytesPerPixel = sizeof(integer) then begin
          pinteger(OutPixelPtr)^ := AlphaBlendWithPremultiplied32(pinteger(OutPixelPtr)^, Color);
        end else begin
          pword(OutPixelPtr)^ := Color32To16(AlphaBlendWithPremultiplied32(Color16To32(pword(OutPixelPtr)^), Color));
        end;
      end;
      Inc(x);
      if x>15 then
      begin
        x:=0;
        Inc(y);
      end;
      temp:=temp shl 1;
    end;
    Inc(i);
  end;
end;

procedure MakeChar24(StartY, StartX, Surface: integer; HZ: pAnsiChar; Color: integer); stdcall;
var
  OffSet:integer;
  GetStr:array[0..71] of byte;
  temp,dis:byte;
  x,y,i,j,xy:integer;
  Q,W:word;
  ScanlineSize:integer;
  OutPixelPtr: pword;

begin
  ScanlineSize:=pInteger(Surface+$2c)^;
  GetQWCode(HZ,Q,W);
  OffSet:=(94*(Q-1)+(W-1))*72;
  F24.Position:=OffSet;
  F24.Read(GetStr,sizeof(GetStr));
  x:=0;
  y:=0;
  i:=0;
  while(i<=71) do
  begin
    temp:=getstr[i];
    for j:=0 to 7 do
    begin
      dis:=temp and 128;
      dis:=dis shr 7;
      if dis=1 then
      begin
        xy          := (StartY + y) * ScanlineSize + (x + StartX) * BytesPerPixel;
        OutPixelPtr := pointer(pinteger(Surface + $30)^ + xy);

        if BytesPerPixel = sizeof(integer) then begin
          pinteger(OutPixelPtr)^ := AlphaBlendWithPremultiplied32(pinteger(OutPixelPtr)^, Color);
        end else begin
          pword(OutPixelPtr)^ := Color32To16(AlphaBlendWithPremultiplied32(Color16To32(pword(OutPixelPtr)^), Color));
        end;
      end;
      Inc(x);
      if x>23 then
      begin
        x:=0;
        Inc(y);
      end;
      temp:=temp shl 1;
    end;
    Inc(i);
  end;
end;

function GetEngCharWidth (Assic:byte;hfont:dword):integer;stdcall;
var
  temp:integer;
begin
  temp:=assic*$c+$3c+hfont;
  result:=pInteger(temp)^+pInteger(temp+4)^+pInteger(temp+8)^;
end;

function GetColor(ColorA: integer): word; stdcall;
begin
  if ColorA < 256 then result := ColorA + 9
  else result := ColorA - 256;
end;

procedure SetFont (Font: PFontItem; var Width, Height: integer); stdcall;
var
  Font24Diff: integer;
  Font12Diff: integer;
  Font11Diff: integer;

begin
  if Font = PrevFont then begin
    Width  := PrevFontWidth;
    Height := PrevFontHeight;
    exit;
  end;

  Font24Diff := Abs(Font.Height - Font24Height) * 1000 div Font.Height;
  Font12Diff := Abs(Font.Height - Font12Height) * 1000 div Font.Height;
  Font11Diff := Abs(Font.Height - Font11Height) * 1000 div Font.Height;

  if (Font24Diff <= Font12Diff) and (Font24Diff <= Font11Diff) then begin
    Width  := Font24Width;
    Height := Font24Height;
  end else if (Font12Diff <= Font11Diff) and (Font12Diff <= Font11Diff) then begin
    Width  := Font12Width;
    Height := Font12Height;
  end else begin
    Width  := Font11Width;
    Height := Font11Height;
  end;

  PrevFont       := Font;
  PrevFontWidth  := Width;
  PrevFontHeight := Height;
end; // .procedure SetFont

//得到文字一共要占几行
// Calculate the total number of rows
function GetStrRowCount(str:pAnsiChar;hfont,RowWidth:integer):integer;stdcall;
var
  i,Length,Row,FontWidth,FontHeight:integer;
begin
  if str[0]=#0 then
  begin
    result:=0;
    exit;
  end;
  SetFont(PFontItem(hfont),FontWidth,FontHeight);
  i:=0;
  Length:=0;
  Row:=1;

  while str[i] <> #0 do begin
    if (str[i] = '{') or (str[i] = '}') then begin
      Inc(i);
    end else if (str[i] = #10) then begin
      Inc(i);
      Length:=0;
      if str[i]<>#0 then row:=row+1;
    end else if (str[i] > #160) and (str[i+1] > #160) then begin
      Length := Length+FontWidth;
      i      := i+2;

      if Length>RowWidth then begin
        Length:=0;

        if str[i]<>#0 then begin
          row:=row+1;
        end
      end;
    end else begin
      Length:=Length+GetEngCharWidth(byte(str[i]),hfont);
      Inc(i);

      if Length>RowWidth then begin
        Length:=0;

        if str[i]<>#0 then begin
          row:=row+1;
        end;
      end;
    end;
  end;

  result:=Row;
end;

procedure DoMyDialog(hfont,MaxWidth:integer;s:pAnsiChar);stdcall;
begin
  DialogResult:=GetStrRowCount(s,hfont,MaxWidth);
end;

//输出一行文字,其中CharLength为字符个数
// Output a row of characters. CharLength is the number of characters
procedure DrawLineToPcx16 (str: pAnsiChar; StrLen, ColorA, hfont, y, x: integer; Surface: integer); stdcall;
const
  DEF_COLOR = 0;

var
  FontWidth, FontHeight, i, cy, cx: integer;
  ColorB, ColorSel: word;
  Color: integer;

begin
  SetFont(PFontItem(hfont), FontWidth, FontHeight);

  i        := 0;
  cy       := y;
  cx       := x;
  ColorB   := GetColor(ColorA);
  ColorSel := 0;

  while (i < StrLen) and not (Str[i] in [#0, #10]) do begin
    if not (Str[i] in [#10, ' ']) then begin
      ChineseGotoNextChar;
    end;

    if Str[i] = '{' then begin
      ColorSel := 1;
    end else if Str[i] = '}' then begin
      ColorSel := 0;
    end else begin
      if (str[i] > #160) and (str[i + 1] > #160) then begin
        Color := ChineseGetCharColor;

        if Color = DEF_COLOR then begin
          Color := Color16To32(pWord(hfont+(ColorB + ColorSel) * 2 + $1058)^);
        end else begin
          Color := PremultiplyColorChannelsByAlpha(Color);
        end;

        if FontWidth = Font12Width then MakeChar12(cy, cx, Surface, @str[i], Color);
        if FontWidth = Font11Width then MakeChar10(cy, cx, Surface, @str[i], Color);
        if FontWidth = Font24Width then MakeChar24(cy, cx, Surface, @str[i], Color);

        cx := cx + FontWidth;
        Inc(i);
      end else begin
        EngTextOut(hfont, byte(str[i]), Surface, cx, cy, ColorB);
        cx := cx + GetEngCharWidth(byte(str[i]), hfont);
      end;
    end; // .else

    Inc(i);
  end; // .while
end; // .procedure DrawLineToPcx16

procedure DoMyTextOut_New (str:pAnsiChar; Surface, x, y, BoxWidth, BoxHeight, ColorA, Mode, hfont, unknow: integer); stdcall;
var
  MaxRow, FontWidth, FontHeight, posStart, posEnd, l, i, row, startX, startY, space, spacerow, j:integer;

begin
  ChineseSetTextAlignmentParamPtr(@Mode);
  UpdateBytesPerPixel;

  if TextColorMode^ = TEXTMODE_15BITS then begin
    Color32To16 := Color32To15Func;
    Color16To32 := Color15To32Func;
  end else if TextColorMode^ = TEXTMODE_16BITS then begin
    Color32To16 := Color32To16Func;
    Color16To32 := Color16To32Func;
  end else begin
    {!} Assert(false, Format('Invalid text color mode: %d', [TextColorMode^]));
  end;

  //先计算一下总共要用的行数
  // Calculate the required rows
  MaxRow := GetStrRowCount(str, hfont, BoxWidth);
  SetFont(PFontItem(hfont), FontWidth, FontHeight);

  //PosStart:=0;
  PosEnd   := 0;
  Row      := -1;
  SpaceRow := -1;
  Space    := -1;

  while Str[PosEnd] <> #0 do begin
    Row      := Row + 1;
    PosStart := PosEnd;
    i        := posEnd;
    l        := 0;

    while str[i] <> #0 do begin
      if str[i] = #10 then begin
        i := i + 1;
        break;
      end else if (str[i] = '{') or (str[i] = '}') then begin
        Inc(i);
      end else if (str[i] > #160) and (str[i + 1] > #160) then begin
        Space    := i + 2;
        SpaceRow := Row;
        l        := l + FontWidth;
        i        := i + 2;

        if l>BoxWidth then begin
          //目前没有对标点符号进行处理
          // Punctuations are not managed for now
          //if byte(str[i])>160 True then
          i:=i-2;
          l:=l-FontWidth;
          break;
        end;
      end else begin
        if str[i] = ' ' then begin
          Space    := i+1;
          SpaceRow := Row;
        end;

        l := l + GetEngCharWidth(byte(str[i]), hfont);

        Inc(i);

        if l>BoxWidth then begin
          //英文必须以单词为单位，整个单词换行，以SPACE记录上个空格或汉字位置，以SPACEROW记录上个空格所在行
          // For English it must treat vacubulary (instead of character) as a whole. 
          // Use SPACE to store the position of the last Space or Chinse character. Use SPACEROW for the last row of a Space presence
          if (SpaceRow=Row)and (Space>-1) then
          begin
            for j:=Space to i-1 do
              l:=l-GetEngCharWidth(byte(str[j]),hfont);
            i:=Space;
            break;
          end else
          begin
            l:=l-GetEngCharWidth(byte(str[i]),hfont);
            i:=i-1;
            break;
          end;
        end;
      end;
    end;

    posEnd:=i;
    startX:=x;
    startY:=y+FontHeight*Row;

    UpdateTextAttrsFromNextChar;

    case mode of
      0,4,8 :startX:=x;
      1,5,9 :startX:=x+((BoxWidth-l) div 2);
      2,6,10:startX:=x+BoxWidth-l;
    end;

    case mode of
      0,1,2,3:startY:=y+(FontHeight)*Row;
      4,5,6,7:begin
                  if BoxHeight < MaxRow*(FontHeight) then
                  begin
                    if BoxHeight < (FontHeight+FontHeight) then
                      StartY:=y+(FontHeight*Row)+(BoxHeight - FontHeight)div 2
                    else startY:=y+(FontHeight)*Row;
                  end                else startY:=y+(FontHeight)*Row+(BoxHeight - MaxRow*(FontHeight))div 2;
              end;
      8,9,10,11:begin
                  if BoxHeight < MaxRow*(FontHeight) then
                  begin
                    if BoxHeight < (FontHeight+FontHeight) then
                      StartY:=y+(FontHeight*Row)+(BoxHeight - FontHeight)
                    else startY:=y+(FontHeight)*Row;
                  end
                  else startY:=y+(FontHeight)*Row+BoxHeight - MaxRow*(FontHeight);
                end;
    end;
    //如果超出显示范围，则退出
    //if StartX+l>x+BoxWidth then exit;

    if (StartY + FontHeight > y + BoxHeight) and (Row > 0) then begin
      exit
    end;

    if PosEnd - PosStart > 0 then begin
      DrawLineToPcx16(@str[PosStart], PosEnd-PosStart, ColorA, hfont, StartY, StartX, Surface);
    end;
  end;
end;

function GraphemWidthEstimator (Font: PFontItem): integer; stdcall;
var
  Height: integer;

begin
  if Font = PrevFont then begin
    result := PrevFontWidth;
  end else begin
    SetFont(Font, result, Height);
  end;
end;

begin
  SetChineseGraphemWidthEstimator(GraphemWidthEstimator);
end.
